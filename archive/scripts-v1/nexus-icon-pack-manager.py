#!/usr/bin/env python3
"""
NeXuS Icon Pack Manager
Manages FOSS icon packs for beautiful web interface customization
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

import os
import json
import shutil
import urllib.request
import zipfile
import tarfile
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nexus-icon-manager")

class NeXuSIconManager:
    def __init__(self):
        self.config_dir = Path("/home/user/.nexus-security/hydra")
        self.icons_dir = self.config_dir / "web" / "icons"
        self.packs_dir = self.icons_dir / "packs"
        self.config_file = self.config_dir / "icon-packs.json"
        
        # Ensure directories exist
        self.icons_dir.mkdir(parents=True, exist_ok=True)
        self.packs_dir.mkdir(parents=True, exist_ok=True)
        
        # Load configuration
        self.config = self.load_config()
        
        # Popular FOSS icon packs - ready for integration
        self.known_packs = {
            "lucide": {
                "name": "Lucide",
                "description": "Beautiful & consistent icon toolkit made by the community",
                "license": "ISC License",
                "website": "https://lucide.dev",
                "style": "outline",
                "formats": ["svg"],
                "categories": ["general", "interface", "development"]
            },
            "feather": {
                "name": "Feather",
                "description": "Simply beautiful open source icons",
                "license": "MIT License", 
                "website": "https://feathericons.com",
                "style": "outline",
                "formats": ["svg"],
                "categories": ["general", "interface"]
            },
            "heroicons": {
                "name": "Heroicons",
                "description": "Beautiful hand-crafted SVG icons by Tailwind CSS",
                "license": "MIT License",
                "website": "https://heroicons.com",
                "style": "outline/solid",
                "formats": ["svg"],
                "categories": ["interface", "general"]
            },
            "tabler": {
                "name": "Tabler Icons", 
                "description": "4500+ Free SVG icons for web design",
                "license": "MIT License",
                "website": "https://tabler-icons.io",
                "style": "outline",
                "formats": ["svg"],
                "categories": ["general", "interface", "development", "brand"]
            },
            "phosphor": {
                "name": "Phosphor Icons",
                "description": "Flexible icon family for everyone",
                "license": "MIT License",
                "website": "https://phosphoricons.com",
                "style": "thin/light/regular/bold/fill",
                "formats": ["svg"],
                "categories": ["general", "interface", "communication"]
            },
            "remix": {
                "name": "Remix Icon",
                "description": "Open source neutral style icon system",
                "license": "Apache License 2.0",
                "website": "https://remixicon.com",
                "style": "line/fill",
                "formats": ["svg"],
                "categories": ["general", "interface", "development", "brand"]
            },
            "iconify": {
                "name": "Iconify",
                "description": "Universal icon framework with 200,000+ icons",
                "license": "Various (all open source)",
                "website": "https://iconify.design",
                "style": "various",
                "formats": ["svg"],
                "categories": ["everything"]
            }
        }
    
    def load_config(self) -> Dict[str, Any]:
        """Load icon pack configuration"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.warning(f"Failed to load config: {e}")
        
        # Default configuration
        return {
            "active_pack": "lucide",
            "installed_packs": {},
            "custom_mappings": {
                "system": "cpu",
                "network": "wifi", 
                "security": "shield",
                "settings": "settings",
                "emergency": "alert-triangle",
                "restart": "refresh-cw",
                "update": "download",
                "log": "file-text",
                "stats": "bar-chart-3",
                "help": "help-circle",
                "success": "check-circle",
                "warning": "alert-triangle", 
                "error": "x-circle",
                "info": "info"
            }
        }
    
    def save_config(self):
        """Save configuration to file"""
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def list_available_packs(self) -> Dict[str, Dict[str, Any]]:
        """List all known FOSS icon packs"""
        print("🎨 Available FOSS Icon Packs:")
        print("=" * 50)
        
        for pack_id, pack_info in self.known_packs.items():
            installed = pack_id in self.config.get("installed_packs", {})
            active = pack_id == self.config.get("active_pack")
            
            status = "🟢 ACTIVE" if active else "✅ INSTALLED" if installed else "⚪ AVAILABLE"
            
            print(f"\n{status} {pack_info['name']}")
            print(f"  📝 {pack_info['description']}")
            print(f"  📄 License: {pack_info['license']}")
            print(f"  🎯 Style: {pack_info['style']}")
            print(f"  🌐 Website: {pack_info['website']}")
            print(f"  📁 Categories: {', '.join(pack_info['categories'])}")
        
        return self.known_packs
    
    def install_pack(self, pack_id: str, source_path: Optional[str] = None):
        """Install an icon pack"""
        if pack_id not in self.known_packs and not source_path:
            logger.error(f"Unknown pack: {pack_id}")
            return False
        
        pack_dir = self.packs_dir / pack_id
        pack_dir.mkdir(exist_ok=True)
        
        print(f"📦 Installing icon pack: {pack_id}")
        
        if source_path:
            # Install from local path
            if Path(source_path).exists():
                self._copy_icons(source_path, pack_dir)
            else:
                logger.error(f"Source path not found: {source_path}")
                return False
        else:
            # Install from known pack (would need specific download logic)
            print(f"⏳ Installation instructions for {pack_id}:")
            pack_info = self.known_packs[pack_id]
            print(f"  1. Download icons from: {pack_info['website']}")
            print(f"  2. Extract to a local directory")
            print(f"  3. Run: nexus-icon-pack-manager.py install {pack_id} /path/to/extracted/icons")
            return True
        
        # Update configuration
        import time
        self.config["installed_packs"][pack_id] = {
            "installed_date": str(time.ctime()),
            "icon_count": len(list(pack_dir.glob("*.svg"))),
            "path": str(pack_dir)
        }
        self.save_config()
        
        print(f"✅ Successfully installed {pack_id}")
        return True
    
    def _copy_icons(self, source: str, dest: Path):
        """Copy icons from source to destination"""
        source_path = Path(source)
        
        if source_path.is_file() and source_path.suffix in ['.zip', '.tar.gz', '.tgz']:
            # Extract archive
            self._extract_archive(source_path, dest)
        elif source_path.is_dir():
            # Copy directory
            for icon_file in source_path.rglob("*.svg"):
                shutil.copy2(icon_file, dest / icon_file.name)
        else:
            logger.error(f"Invalid source: {source}")
    
    def _extract_archive(self, archive_path: Path, dest: Path):
        """Extract icon archive"""
        if archive_path.suffix == '.zip':
            with zipfile.ZipFile(archive_path, 'r') as zip_ref:
                zip_ref.extractall(dest)
        elif archive_path.suffix in ['.tar.gz', '.tgz']:
            with tarfile.open(archive_path, 'r:gz') as tar_ref:
                tar_ref.extractall(dest)
    
    def set_active_pack(self, pack_id: str):
        """Set the active icon pack"""
        if pack_id not in self.config.get("installed_packs", {}):
            logger.error(f"Pack not installed: {pack_id}")
            return False
        
        self.config["active_pack"] = pack_id
        self.save_config()
        
        print(f"✅ Active icon pack set to: {pack_id}")
        return True
    
    def generate_icon_css(self, pack_id: Optional[str] = None) -> str:
        """Generate CSS for icon usage"""
        if not pack_id:
            pack_id = self.config.get("active_pack", "lucide")
        
        pack_dir = self.packs_dir / pack_id
        if not pack_dir.exists():
            return "/* No icon pack installed */"
        
        css_rules = []
        css_rules.append(f"/* NeXuS Icon Pack: {pack_id} */")
        css_rules.append(".nexus-icon {")
        css_rules.append("    display: inline-block;")
        css_rules.append("    width: 1em;")
        css_rules.append("    height: 1em;")
        css_rules.append("    vertical-align: middle;")
        css_rules.append("    background-size: contain;")
        css_rules.append("    background-repeat: no-repeat;")
        css_rules.append("    background-position: center;")
        css_rules.append("}")
        css_rules.append("")
        
        # Generate rules for each icon
        for icon_file in sorted(pack_dir.glob("*.svg")):
            icon_name = icon_file.stem
            css_rules.append(f".nexus-icon.{icon_name} {{")
            css_rules.append(f"    background-image: url('/static/icons/packs/{pack_id}/{icon_file.name}');")
            css_rules.append("}")
        
        return "\n".join(css_rules)
    
    def create_icon_mapping_js(self) -> str:
        """Create JavaScript mapping for easy icon usage"""
        mappings = self.config.get("custom_mappings", {})
        
        js_code = f"""
// NeXuS Icon Mapping System
const NeXuSIcons = {{
    // Custom icon mappings
    mappings: {json.dumps(mappings, indent=4)},
    
    // Get icon class for a semantic name
    get: function(semanticName) {{
        const iconName = this.mappings[semanticName] || semanticName;
        return `nexus-icon ${{iconName}}`;
    }},
    
    // Create icon element
    create: function(semanticName, extraClasses = '') {{
        const iconClass = this.get(semanticName);
        return `<i class="${{iconClass}} ${{extraClasses}}"></i>`;
    }},
    
    // Available semantic names
    available: {json.dumps(list(mappings.keys()), indent=4)}
}};

// Usage examples:
// <i class="{{{{ NeXuSIcons.get('system') }}}}"></i>
// innerHTML = NeXuSIcons.create('security', 'text-green-400');
"""
        return js_code
    
    def show_status(self):
        """Show current icon pack status"""
        print("🎨 NeXuS Icon Pack Status")
        print("=" * 30)
        
        active_pack = self.config.get("active_pack", "none")
        installed_packs = self.config.get("installed_packs", {})
        
        print(f"🟢 Active Pack: {active_pack}")
        print(f"📦 Installed Packs: {len(installed_packs)}")
        
        if installed_packs:
            print("\n📋 Installed Packs:")
            for pack_id, pack_data in installed_packs.items():
                icon_count = pack_data.get("icon_count", "unknown")
                print(f"  ✅ {pack_id} ({icon_count} icons)")
        
        # Show available mappings
        mappings = self.config.get("custom_mappings", {})
        if mappings:
            print(f"\n🗺️  Icon Mappings ({len(mappings)}):")
            for semantic, icon in mappings.items():
                print(f"  {semantic} → {icon}")

def main():
    """Main CLI interface"""
    import sys
    
    manager = NeXuSIconManager()
    
    if len(sys.argv) < 2:
        print("🎨 NeXuS Icon Pack Manager")
        print("Usage: nexus-icon-pack-manager.py <command> [args]")
        print("\nCommands:")
        print("  list                    - List available icon packs")
        print("  install <pack_id> [dir] - Install icon pack")
        print("  activate <pack_id>      - Set active icon pack")
        print("  status                  - Show current status")
        print("  generate-css [pack_id]  - Generate CSS for icons")
        print("  generate-js             - Generate JavaScript mappings")
        return
    
    command = sys.argv[1]
    
    if command == "list":
        manager.list_available_packs()
    elif command == "install" and len(sys.argv) >= 3:
        pack_id = sys.argv[2]
        source_path = sys.argv[3] if len(sys.argv) > 3 else None
        manager.install_pack(pack_id, source_path)
    elif command == "activate" and len(sys.argv) >= 3:
        pack_id = sys.argv[2]
        manager.set_active_pack(pack_id)
    elif command == "status":
        manager.show_status()
    elif command == "generate-css":
        pack_id = sys.argv[2] if len(sys.argv) > 2 else None
        print(manager.generate_icon_css(pack_id))
    elif command == "generate-js":
        print(manager.create_icon_mapping_js())
    else:
        print(f"❌ Unknown command: {command}")

if __name__ == "__main__":
    main()