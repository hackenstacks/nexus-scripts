#!/bin/sh
# NeXuS Shell launcher — DankMaterialShell (dms)
# dms wraps quickshell with the DMS config
# QT_QUICK_BACKEND=software — Intel HD 3000 (no VAAPI/hardware accel)
# LANG=C.UTF-8               — fixes Qt locale warning on Alpine

export LANG=C.UTF-8
export QT_QUICK_BACKEND=software

# If labwc is running, tell DMS we're in labwc (not niri).
# labwc inherits NIRI_SOCKET from its niri parent, which fools DMS
# into thinking it's running under niri. Unset it and set LABWC_PID
# so DMS reaches the labwc detection branch in CompositorService.qml.
if pgrep -x labwc > /dev/null 2>&1; then
    unset NIRI_SOCKET
    export LABWC_PID=$(pgrep -n labwc)
fi

# labwc takes ~10s to register outputs after login — wait for it
# Without this dms exits immediately with "no outputs"
sleep 8

exec dms run >> /tmp/dms-labwc.log 2>&1
