#!/bin/sh
# nexus-disk-manager.sh — LUKS + LVM disk management (Alpine)

BLU='\033[0;34m'; GRN='\033[0;32m'; YLW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { printf "${BLU}[INFO]${NC} %s\n" "$1"; }
ok()   { printf "${GRN}[ OK ]${NC} %s\n" "$1"; }
warn() { printf "${YLW}[WARN]${NC} %s\n" "$1"; }
err()  { printf "${RED}[ERR ]${NC} %s\n" "$1"; }

require_root() {
    [ "$(id -u)" -ne 0 ] && err "Run with doas: doas sh $0" && exit 1
}

# ── helpers ───────────────────────────────────────────────────────────────────

pv_exists() { pvs "$1" >/dev/null 2>&1; }
in_vg()     { pvs --noheadings -o vg_name "$1" 2>/dev/null | grep -q "[a-z]"; }
mapper_open() { [ -b "/dev/mapper/$1" ]; }
luks_device() { cryptsetup isLuks "$1" 2>/dev/null; }

# ── status ────────────────────────────────────────────────────────────────────

status() {
    echo ""
    info "=== Block Devices ==="
    lsblk -f
    echo ""
    info "=== Physical Volumes ==="
    pvs
    echo ""
    info "=== Volume Groups ==="
    vgs
    echo ""
    info "=== Logical Volumes ==="
    lvs
    echo ""
    info "=== Disk Usage ==="
    df -h
    echo ""
    info "=== Boot APPEND ==="
    grep APPEND /boot/extlinux.conf 2>/dev/null || echo "(extlinux.conf not found)"
}

# ── LUKS ──────────────────────────────────────────────────────────────────────

luks_format() {
    echo ""; lsblk
    printf "\nEnter disk to format (e.g. /dev/sda): "; read DISK
    [ -z "$DISK" ] && err "No disk specified" && return 1
    [ ! -b "$DISK" ] && err "$DISK is not a block device" && return 1
    if luks_device "$DISK"; then
        warn "$DISK already has a LUKS header"
        printf "Re-format and DESTROY existing data? Type YES: "; read CONFIRM
    else
        warn "This will DESTROY all data on $DISK"
        printf "Type YES to confirm: "; read CONFIRM
    fi
    [ "$CONFIRM" != "YES" ] && info "Aborted" && return 0
    info "Formatting $DISK with LUKS (sector-size 512 to avoid block-size mismatch)..."
    cryptsetup luksFormat --sector-size 512 "$DISK" && ok "LUKS format complete on $DISK"
}

luks_open() {
    echo ""; lsblk
    printf "\nEnter LUKS disk (e.g. /dev/sda): "; read DISK
    printf "Enter mapper name (e.g. sda_extend): "; read NAME
    [ -z "$DISK" ] || [ -z "$NAME" ] && err "Disk and name required" && return 1
    if mapper_open "$NAME"; then
        ok "/dev/mapper/$NAME already open — skipping"
        return 0
    fi
    ! luks_device "$DISK" && err "$DISK has no LUKS header — format it first (option 2)" && return 1
    cryptsetup open "$DISK" "$NAME" && ok "Opened as /dev/mapper/$NAME"
}

luks_close() {
    echo ""; ls /dev/mapper/
    printf "\nEnter mapper name to close: "; read NAME
    cryptsetup close "$NAME" && ok "Closed /dev/mapper/$NAME"
}

# ── LVM ───────────────────────────────────────────────────────────────────────

pv_create() {
    echo ""; ls /dev/mapper/
    printf "\nEnter mapper device (e.g. /dev/mapper/sda_extend): "; read DEV
    [ ! -b "$DEV" ] && err "$DEV not found — open the LUKS container first (option 3)" && return 1
    if pv_exists "$DEV"; then
        ok "$DEV is already a PV — skipping pvcreate"
        return 0
    fi
    pvcreate "$DEV" && ok "PV created on $DEV"
}

vg_extend() {
    echo ""; pvs; vgs
    printf "\nEnter VG name (e.g. vg0): "; read VG
    printf "Enter PV mapper device (e.g. /dev/mapper/sda_extend): "; read PV
    [ ! -b "$PV" ] && err "$PV not found — run pvcreate first (option 5)" && return 1
    if in_vg "$PV"; then
        ok "$PV is already in a VG — skipping vgextend"
        pvs "$PV"; return 0
    fi
    if ! pv_exists "$PV"; then
        err "$PV is not a PV yet — run pvcreate first (option 5)" && return 1
    fi
    vgextend --config 'devices{allow_mixed_block_sizes=1}' "$VG" "$PV" && ok "VG $VG extended with $PV"
}

lv_extend() {
    echo ""; lvs
    printf "\nEnter LV path (e.g. /dev/vg0/lv_root): "; read LV
    printf "Extend by how much? (e.g. +100%%FREE or +50G): "; read SIZE
    [ ! -b "$LV" ] && err "$LV not found — check lvs output above" && return 1
    lvextend -l "$SIZE" "$LV" && ok "LV extended" && lvs
}

fs_resize() {
    echo ""; lvs
    printf "\nEnter LV path (e.g. /dev/vg0/lv_root): "; read LV
    [ ! -b "$LV" ] && err "$LV not found — check lvs output above" && return 1
    info "Running online resize2fs on $LV (ext4 live resize supported)..."
    if ! command -v resize2fs >/dev/null 2>&1; then
        err "resize2fs not found — install with: apk add e2fsprogs-extra"
        return 1
    fi
    resize2fs "$LV" && ok "Filesystem resized" && df -h "$LV"
}

# ── lvm.conf fixes ────────────────────────────────────────────────────────────

fix_lvm_conf() {
    CONF=/etc/lvm/lvm.conf
    cp "$CONF" "${CONF}.bak" && ok "Backed up to ${CONF}.bak"

    if ! grep -q "^[[:space:]]*global_filter" "$CONF"; then
        printf "\nWhich raw disk to exclude from LVM scan? (e.g. sda): "; read RAWDISK
        RAWDISK="${RAWDISK:-sda}"
        awk "/# global_filter = \[ \"a\|.*\|\" \]/ {
            print
            print \"\tglobal_filter = [ \\\"r|/dev/${RAWDISK}|\\\", \\\"a|.*|\\\" ]\"
            next
        }{ print }" "$CONF" > /tmp/lvm.conf.new && cp /tmp/lvm.conf.new "$CONF"
        ok "global_filter added for /dev/$RAWDISK"
    else
        ok "global_filter already present"
    fi

    if ! grep -q "allow_mixed_block_sizes" "$CONF"; then
        sed -i '/^[[:space:]]*global_filter/a\\tallow_mixed_block_sizes = 1' "$CONF"
        ok "allow_mixed_block_sizes = 1 added (fixes 4096/512 sector mismatch)"
    else
        ok "allow_mixed_block_sizes already present"
    fi

    info "Current filter settings:"
    grep -E "global_filter|allow_mixed_block_sizes" "$CONF"
}

# ── boot persistence (Alpine: extlinux.conf + mkinitfs) ───────────────────────

fix_extlinux() {
    EXTLINUX=/boot/extlinux.conf
    [ ! -f "$EXTLINUX" ] && err "$EXTLINUX not found" && return 1

    cp "$EXTLINUX" "${EXTLINUX}.bak" && ok "Backed up to ${EXTLINUX}.bak"

    printf "\nEnter raw LUKS disk for second device (e.g. /dev/sda): "; read DISK
    printf "Enter mapper name for second device (e.g. sda_extend): "; read NAME
    [ -z "$DISK" ] || [ -z "$NAME" ] && err "Both required" && return 1

    UUID=$(cryptsetup luksUUID "$DISK" 2>/dev/null)
    [ -z "$UUID" ] && err "Cannot read UUID from $DISK — is it LUKS formatted?" && return 1

    if grep -q "cryptroot2" "$EXTLINUX"; then
        ok "cryptroot2 already present in extlinux.conf — skipping"
        grep APPEND "$EXTLINUX"
        return 0
    fi

    sed -i "s|cryptdm=root quiet|cryptdm=root cryptroot2=UUID=${UUID} cryptdm2=${NAME} quiet|" "$EXTLINUX"
    info "Updated APPEND line:"; grep APPEND "$EXTLINUX"
    ok "extlinux.conf updated"
}

rebuild_initramfs() {
    info "Rebuilding initramfs with mkinitfs..."
    mkinitfs && ok "initramfs rebuilt — changes take effect on next boot"
}

boot_persist() {
    info "=== Boot Persistence Setup ==="
    echo "This adds the second LUKS device to extlinux.conf and rebuilds initramfs."
    echo "Required so both LUKS volumes open at boot (needed for LVM root to mount)."
    printf "Continue? (y/N): "; read C
    [ "$C" != "y" ] && [ "$C" != "Y" ] && return 0
    fix_extlinux || return 1
    rebuild_initramfs
}

# ── full workflow ─────────────────────────────────────────────────────────────

full_workflow() {
    info "=== Full Add-Disk Workflow ==="
    echo ""
    echo "Order of operations:"
    echo "  1. Fix lvm.conf        (prevents hang on raw disk scan)"
    echo "  2. LUKS format disk    (--sector-size 512 to match existing VG)"
    echo "  3. LUKS open           (create /dev/mapper/<name>)"
    echo "  4. pvcreate            (initialize as LVM physical volume)"
    echo "  5. vgextend            (add to existing volume group)"
    echo "  6. lvextend            (grow logical volume)"
    echo "  7. resize2fs           (expand filesystem online)"
    echo "  8. extlinux.conf       (add cryptroot2 for boot)"
    echo "  9. mkinitfs            (rebuild initramfs)"
    echo ""
    printf "Continue? (y/N): "; read C
    [ "$C" != "y" ] && [ "$C" != "Y" ] && return 0

    fix_lvm_conf || return 1
    luks_format  || return 1
    luks_open    || return 1
    pv_create    || return 1
    vg_extend    || return 1
    lv_extend    || return 1
    fs_resize    || return 1
    boot_persist

    ok "=== Full workflow complete ==="
    echo ""
    df -h /
    echo ""
    warn "Reboot to verify both LUKS volumes open at boot"
}

# ── menu ──────────────────────────────────────────────────────────────────────

require_root

while true; do
    echo ""
    echo "================================="
    echo "  NeXuS Disk Manager"
    echo "================================="
    echo "  1) Status overview"
    echo "  --- LUKS ---"
    echo "  2) Format disk with LUKS"
    echo "  3) Open LUKS container"
    echo "  4) Close LUKS container"
    echo "  --- LVM ---"
    echo "  5) Create physical volume (pvcreate)"
    echo "  6) Extend volume group   (vgextend)"
    echo "  7) Extend logical volume (lvextend)"
    echo "  8) Resize filesystem     (resize2fs)"
    echo "  --- System ---"
    echo "  9) Fix lvm.conf (filter + mixed block sizes)"
    echo " 10) Add 2nd LUKS to boot  (extlinux + mkinitfs)"
    echo " 11) Full workflow         (all steps in order)"
    echo "  q) Quit"
    echo "================================="
    printf "Choose: "; read OPT

    case "$OPT" in
        1) status ;;
        2) luks_format ;;
        3) luks_open ;;
        4) luks_close ;;
        5) pv_create ;;
        6) vg_extend ;;
        7) lv_extend ;;
        8) fs_resize ;;
        9) fix_lvm_conf ;;
       10) boot_persist ;;
       11) full_workflow ;;
        q|Q) echo "Bye."; exit 0 ;;
        *) warn "Invalid option" ;;
    esac
done
