#!/usr/bin/env python3
"""
NeXuS Advanced Blacklist Manager
User-configurable blacklist activation system with web interface
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

import json
import os
import subprocess
import asyncio
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nexus-blacklist-manager")

@dataclass
class BlacklistSource:
    name: str
    url: str
    category: str
    description: str
    update_frequency: str
    enabled: bool = False
    estimated_domains: int = 0
    last_updated: Optional[str] = None
    file_size: int = 0
    status: str = "inactive"

class NeXuSBlacklistManager:
    def __init__(self):
        self.config_dir = Path("/home/user/.nexus-security/blacklist-manager")
        self.sources_file = self.config_dir / "sources.json"
        self.config_file = self.config_dir / "config.json"
        self.data_dir = self.config_dir / "data"
        self.active_dir = self.config_dir / "active"
        
        # Ensure directories exist
        for dir_path in [self.config_dir, self.data_dir, self.active_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
        
        self.blacklist_sources = self._initialize_sources()
        self.config = self._load_config()
    
    def _initialize_sources(self) -> Dict[str, BlacklistSource]:
        """Initialize comprehensive blacklist source database"""
        sources = {
            # ========== CORE ADBLOCKING ==========
            "easylist_main": BlacklistSource(
                name="EasyList Main",
                url="https://easylist.to/easylist/easylist.txt",
                category="ads",
                description="Primary international ad blocking filter",
                update_frequency="weekly",
                estimated_domains=75000
            ),
            "easylist_privacy": BlacklistSource(
                name="EasyPrivacy",
                url="https://easylist.to/easylist/easyprivacy.txt",
                category="tracking",
                description="Privacy protection and tracking removal",
                update_frequency="weekly",
                estimated_domains=25000
            ),
            "easylist_annoyance": BlacklistSource(
                name="Fanboy Annoyance",
                url="https://easylist.to/easylist/fanboy-annoyance.txt",
                category="annoyance",
                description="Removes social media widgets and annoyances",
                update_frequency="weekly",
                estimated_domains=15000
            ),
            "easylist_social": BlacklistSource(
                name="Fanboy Social",
                url="https://easylist.to/easylist/fanboy-social.txt",
                category="social",
                description="Blocks social media tracking and widgets",
                update_frequency="weekly",
                estimated_domains=8000
            ),
            "easylist_cookie": BlacklistSource(
                name="Fanboy Cookie Monster",
                url="https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
                category="privacy",
                description="Removes cookie consent notices",
                update_frequency="weekly",
                estimated_domains=5000
            ),
            
            # ========== UBLOCK ORIGIN ASSETS ==========
            "ublock_filters": BlacklistSource(
                name="uBlock Origin Filters",
                url="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
                category="ads",
                description="uBlock Origin maintained ad filters",
                update_frequency="daily",
                estimated_domains=12000
            ),
            "ublock_badware": BlacklistSource(
                name="uBlock Origin Badware",
                url="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt",
                category="malware",
                description="Malware and badware protection",
                update_frequency="daily",
                estimated_domains=3000
            ),
            "ublock_privacy": BlacklistSource(
                name="uBlock Origin Privacy",
                url="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt",
                category="tracking",
                description="Advanced privacy protection",
                update_frequency="daily",
                estimated_domains=8000
            ),
            "ublock_annoyances": BlacklistSource(
                name="uBlock Origin Annoyances",
                url="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances.txt",
                category="annoyance",
                description="UI annoyances and distractions",
                update_frequency="daily",
                estimated_domains=2000
            ),
            "ublock_resource_abuse": BlacklistSource(
                name="uBlock Resource Abuse",
                url="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/resource-abuse.txt",
                category="malware",
                description="Cryptocurrency mining and resource abuse",
                update_frequency="daily",
                estimated_domains=1500
            ),
            
            # ========== HAGEZI PROFESSIONAL ==========
            "hagezi_light": BlacklistSource(
                name="HaGeZi Light",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/light.txt",
                category="ads",
                description="Light blocking for minimal interference",
                update_frequency="daily",
                estimated_domains=50000
            ),
            "hagezi_normal": BlacklistSource(
                name="HaGeZi Normal",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/multi.txt",
                category="ads",
                description="Balanced blocking for most users",
                update_frequency="daily",
                estimated_domains=150000
            ),
            "hagezi_pro": BlacklistSource(
                name="HaGeZi Pro",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt",
                category="ads",
                description="Professional grade blocking (RECOMMENDED)",
                update_frequency="daily",
                estimated_domains=250000,
                enabled=True  # Enabled by default
            ),
            "hagezi_pro_plus": BlacklistSource(
                name="HaGeZi Pro++",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt",
                category="ads",
                description="More aggressive version of Pro",
                update_frequency="daily",
                estimated_domains=350000
            ),
            "hagezi_ultimate": BlacklistSource(
                name="HaGeZi Ultimate",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/ultimate.txt",
                category="ads",
                description="Maximum blocking (may break functionality)",
                update_frequency="daily",
                estimated_domains=500000
            ),
            "hagezi_threat_intel": BlacklistSource(
                name="HaGeZi Threat Intelligence",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt",
                category="malware",
                description="Malware, phishing, and threat protection",
                update_frequency="daily",
                estimated_domains=75000,
                enabled=True  # Enabled by default
            ),
            "hagezi_nsfw": BlacklistSource(
                name="HaGeZi NSFW",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/nsfw.txt",
                category="adult",
                description="Adult content blocking",
                update_frequency="weekly",
                estimated_domains=150000
            ),
            "hagezi_gambling": BlacklistSource(
                name="HaGeZi Gambling",
                url="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.txt",
                category="gambling",
                description="Gambling and betting sites",
                update_frequency="weekly",
                estimated_domains=25000
            ),
            
            # ========== SECURITY & MALWARE ==========
            "malware_domain_list": BlacklistSource(
                name="Malware Domain List",
                url="https://www.malwaredomainlist.com/hostslist/hosts.txt",
                category="malware",
                description="Known malware distribution domains",
                update_frequency="daily",
                estimated_domains=5000,
                enabled=True  # Enabled by default
            ),
            "stevenblack_unified": BlacklistSource(
                name="Steven Black Unified",
                url="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
                category="ads",
                description="Unified hosts file (ads + malware)",
                update_frequency="daily",
                estimated_domains=100000,
                enabled=True  # Enabled by default
            ),
            "stevenblack_fakenews": BlacklistSource(
                name="Steven Black + Fake News",
                url="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts",
                category="fakenews",
                description="Includes fake news and propaganda sites",
                update_frequency="daily",
                estimated_domains=110000
            ),
            "stevenblack_gambling": BlacklistSource(
                name="Steven Black + Gambling",
                url="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling/hosts",
                category="gambling",
                description="Includes gambling and betting sites",
                update_frequency="daily",
                estimated_domains=120000
            ),
            "stevenblack_social": BlacklistSource(
                name="Steven Black + Social",
                url="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social/hosts",
                category="social",
                description="Includes social media platforms",
                update_frequency="daily",
                estimated_domains=105000
            ),
            "stevenblack_all": BlacklistSource(
                name="Steven Black Ultimate",
                url="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn-social/hosts",
                category="comprehensive",
                description="All categories combined (may be restrictive)",
                update_frequency="daily",
                estimated_domains=180000
            ),
            
            # ========== THREAT INTELLIGENCE ==========
            "malwareworld_meta": BlacklistSource(
                name="Malware World Meta-Feed",
                url="https://malwareworld.com/textlists/blacklists.txt",
                category="malware",
                description="Carlos Polop's 70+ source aggregation (META)",
                update_frequency="daily",
                estimated_domains=500000
            ),
            "abuse_ch_urlhaus": BlacklistSource(
                name="URLhaus (abuse.ch)",
                url="https://urlhaus.abuse.ch/downloads/hostfile/",
                category="malware",
                description="Fresh malware URLs and hosting infrastructure",
                update_frequency="daily",
                estimated_domains=10000,
                enabled=True  # Enabled by default
            ),
            "abuse_ch_threatfox": BlacklistSource(
                name="ThreatFox (abuse.ch)",
                url="https://threatfox.abuse.ch/downloads/hostfile/",
                category="malware",
                description="IoCs shared by security researchers",
                update_frequency="daily",
                estimated_domains=5000
            ),
            "openphish": BlacklistSource(
                name="OpenPhish",
                url="https://openphish.com/feed.txt",
                category="phishing",
                description="Real-time phishing URL feed",
                update_frequency="hourly",
                estimated_domains=2000
            ),
            
            # ========== PRIVACY & TRACKING ==========
            "disconnect_tracking": BlacklistSource(
                name="Disconnect Tracking",
                url="https://services.disconnect.me/plaintext",
                category="tracking",
                description="Comprehensive tracking protection",
                update_frequency="weekly",
                estimated_domains=15000,
                enabled=True  # Enabled by default
            ),
            "peter_lowe_adservers": BlacklistSource(
                name="Peter Lowe's Ad Servers",
                url="https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext",
                category="ads",
                description="Classic ad server blocking list",
                update_frequency="weekly",
                estimated_domains=3500,
                enabled=True  # Enabled by default
            ),
            "someonewhocares": BlacklistSource(
                name="Someone Who Cares",
                url="https://someonewhocares.org/hosts/zero/hosts",
                category="ads",
                description="Dan Pollock's comprehensive hosts file",
                update_frequency="monthly",
                estimated_domains=15000
            ),
            
            # ========== CRYPTOCURRENCY & MINING ==========
            "nocoin": BlacklistSource(
                name="NoCoin",
                url="https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt",
                category="cryptomining",
                description="Cryptocurrency mining and cryptojacking",
                update_frequency="weekly",
                estimated_domains=800
            ),
            
            # ========== REGIONAL LISTS ==========
            "easylist_germany": BlacklistSource(
                name="EasyList Germany",
                url="https://easylist.to/easylist/easylistgermany.txt",
                category="regional",
                description="German-specific ad blocking",
                update_frequency="weekly",
                estimated_domains=8000
            ),
            "easylist_china": BlacklistSource(
                name="EasyList China",
                url="https://easylist-downloads.adblockplus.org/easylistchina.txt",
                category="regional",
                description="Chinese-specific ad blocking",
                update_frequency="weekly",
                estimated_domains=12000
            ),
            "ruadlist": BlacklistSource(
                name="RuAdList",
                url="https://easylist-downloads.adblockplus.org/ruadlist.txt",
                category="regional",
                description="Russian ad blocking filter",
                update_frequency="weekly",
                estimated_domains=20000
            ),
            "abpindo": BlacklistSource(
                name="ABPindo",
                url="https://raw.githubusercontent.com/ABPindo/indonesianadblockrules/master/subscriptions/abpindo.txt",
                category="regional",
                description="Indonesian ad blocking rules",
                update_frequency="weekly",
                estimated_domains=5000
            ),
            
            # ========== SOCIAL MEDIA SPECIFIC ==========
            "fanboy_facebook": BlacklistSource(
                name="Anti-Facebook",
                url="https://www.fanboy.co.nz/fanboy-antifacebook.txt",
                category="social",
                description="Comprehensive Facebook blocking",
                update_frequency="monthly",
                estimated_domains=200
            ),
            
            # ========== NEXT-GEN & COMMUNITY ==========
            "oisd_big": BlacklistSource(
                name="OISD Big",
                url="https://big.oisd.nl/",
                category="comprehensive",
                description="Machine learning curated comprehensive list",
                update_frequency="daily",
                estimated_domains=1000000
            ),
            "oisd_small": BlacklistSource(
                name="OISD Small",
                url="https://small.oisd.nl/",
                category="ads",
                description="Lightweight version of OISD",
                update_frequency="daily",
                estimated_domains=100000
            ),
            "energized_spark": BlacklistSource(
                name="Energized Spark",
                url="https://raw.githubusercontent.com/EnergizedProtection/block/master/spark/formats/hosts.txt",
                category="ads",
                description="Lightweight energized protection",
                update_frequency="daily",
                estimated_domains=25000
            ),
            "energized_blu": BlacklistSource(
                name="Energized Blu",
                url="https://raw.githubusercontent.com/EnergizedProtection/block/master/blu/formats/hosts.txt",
                category="comprehensive",
                description="Balanced energized protection",
                update_frequency="daily",
                estimated_domains=500000
            )
        }
        
        return sources
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration settings"""
        default_config = {
            "auto_update": True,
            "update_schedule": "0 4 * * *",  # 4 AM daily
            "max_concurrent_downloads": 5,
            "download_timeout": 30,
            "validate_domains": True,
            "remove_duplicates": True,
            "backup_before_update": True,
            "privoxy_integration": True,
            "hosts_file_integration": False,
            "categories": {
                "ads": {"enabled": True, "description": "Advertisement blocking"},
                "tracking": {"enabled": True, "description": "Privacy and tracking protection"},
                "malware": {"enabled": True, "description": "Malware and threat protection"},
                "phishing": {"enabled": True, "description": "Phishing protection"},
                "social": {"enabled": False, "description": "Social media blocking"},
                "annoyance": {"enabled": False, "description": "UI annoyances and distractions"},
                "adult": {"enabled": False, "description": "Adult content blocking"},
                "gambling": {"enabled": False, "description": "Gambling and betting sites"},
                "fakenews": {"enabled": False, "description": "Fake news and propaganda"},
                "cryptomining": {"enabled": True, "description": "Cryptocurrency mining"},
                "regional": {"enabled": False, "description": "Region-specific lists"},
                "comprehensive": {"enabled": False, "description": "Large comprehensive lists"}
            }
        }
        
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    return {**default_config, **json.load(f)}
            except:
                return default_config
        return default_config
    
    def save_config(self):
        """Save current configuration"""
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def save_sources(self):
        """Save blacklist sources configuration"""
        sources_data = {name: asdict(source) for name, source in self.blacklist_sources.items()}
        with open(self.sources_file, 'w') as f:
            json.dump(sources_data, f, indent=2)
    
    def load_sources(self):
        """Load saved blacklist sources"""
        if self.sources_file.exists():
            try:
                with open(self.sources_file, 'r') as f:
                    sources_data = json.load(f)
                    for name, data in sources_data.items():
                        if name in self.blacklist_sources:
                            # Update with saved data
                            for key, value in data.items():
                                if hasattr(self.blacklist_sources[name], key):
                                    setattr(self.blacklist_sources[name], key, value)
            except Exception as e:
                logger.error(f"Error loading sources: {e}")
    
    def get_sources_by_category(self, category: str) -> List[BlacklistSource]:
        """Get all sources in a specific category"""
        return [source for source in self.blacklist_sources.values() if source.category == category]
    
    def get_enabled_sources(self) -> List[BlacklistSource]:
        """Get all enabled sources"""
        return [source for source in self.blacklist_sources.values() if source.enabled]
    
    def toggle_source(self, source_name: str, enabled: bool) -> bool:
        """Enable or disable a specific source"""
        if source_name in self.blacklist_sources:
            self.blacklist_sources[source_name].enabled = enabled
            self.save_sources()
            return True
        return False
    
    def toggle_category(self, category: str, enabled: bool) -> int:
        """Enable or disable all sources in a category"""
        count = 0
        for source in self.blacklist_sources.values():
            if source.category == category:
                source.enabled = enabled
                count += 1
        
        if count > 0:
            self.config["categories"][category]["enabled"] = enabled
            self.save_sources()
            self.save_config()
        
        return count
    
    def get_categories_summary(self) -> Dict[str, Dict[str, Any]]:
        """Get summary of all categories with counts"""
        summary = {}
        
        for category in set(source.category for source in self.blacklist_sources.values()):
            sources = self.get_sources_by_category(category)
            enabled_sources = [s for s in sources if s.enabled]
            
            summary[category] = {
                "description": self.config["categories"].get(category, {}).get("description", ""),
                "total_sources": len(sources),
                "enabled_sources": len(enabled_sources),
                "estimated_domains": sum(s.estimated_domains for s in enabled_sources),
                "enabled": len(enabled_sources) > 0
            }
        
        return summary
    
    def get_recommendations(self) -> Dict[str, List[str]]:
        """Get recommended configurations for different use cases"""
        return {
            "minimal": [
                "hagezi_pro", "hagezi_threat_intel", "malware_domain_list", 
                "abuse_ch_urlhaus", "disconnect_tracking"
            ],
            "balanced": [
                "hagezi_pro", "hagezi_threat_intel", "easylist_main", "easylist_privacy",
                "stevenblack_unified", "malware_domain_list", "abuse_ch_urlhaus",
                "disconnect_tracking", "peter_lowe_adservers"
            ],
            "comprehensive": [
                "hagezi_pro_plus", "hagezi_threat_intel", "easylist_main", "easylist_privacy",
                "easylist_annoyance", "stevenblack_unified", "malware_domain_list",
                "abuse_ch_urlhaus", "abuse_ch_threatfox", "disconnect_tracking",
                "peter_lowe_adservers", "ublock_filters", "ublock_privacy", "nocoin"
            ],
            "maximum": [
                "hagezi_ultimate", "hagezi_threat_intel", "oisd_big", "stevenblack_all",
                "malwareworld_meta", "energized_blu"
            ]
        }
    
    def apply_recommendation(self, preset: str) -> bool:
        """Apply a recommended configuration preset"""
        recommendations = self.get_recommendations()
        
        if preset not in recommendations:
            return False
        
        # Disable all sources first
        for source in self.blacklist_sources.values():
            source.enabled = False
        
        # Enable recommended sources
        for source_name in recommendations[preset]:
            if source_name in self.blacklist_sources:
                self.blacklist_sources[source_name].enabled = True
        
        self.save_sources()
        return True
    
    async def download_source(self, source: BlacklistSource) -> bool:
        """Download a specific blacklist source"""
        try:
            import aiohttp
            import aiofiles
            
            file_path = self.data_dir / f"{source.name.lower().replace(' ', '_')}.txt"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(source.url, timeout=aiohttp.ClientTimeout(total=30)) as response:
                    if response.status == 200:
                        content = await response.text()
                        
                        async with aiofiles.open(file_path, 'w') as f:
                            await f.write(content)
                        
                        # Update source metadata
                        source.last_updated = datetime.now().isoformat()
                        source.file_size = file_path.stat().st_size
                        source.status = "active"
                        
                        # Estimate domain count (simple heuristic)
                        lines = content.split('\n')
                        domain_lines = [l for l in lines if '.' in l and not l.startswith('#')]
                        source.estimated_domains = len(domain_lines)
                        
                        return True
            
        except Exception as e:
            logger.error(f"Error downloading {source.name}: {e}")
            source.status = "error"
            return False
        
        return False
    
    def export_configuration(self) -> Dict[str, Any]:
        """Export current configuration for backup/sharing"""
        return {
            "config": self.config,
            "sources": {name: asdict(source) for name, source in self.blacklist_sources.items()},
            "export_date": datetime.now().isoformat(),
            "version": "1.0"
        }
    
    def import_configuration(self, config_data: Dict[str, Any]) -> bool:
        """Import configuration from backup/share"""
        try:
            if "config" in config_data:
                self.config = {**self.config, **config_data["config"]}
                self.save_config()
            
            if "sources" in config_data:
                for name, data in config_data["sources"].items():
                    if name in self.blacklist_sources:
                        for key, value in data.items():
                            if hasattr(self.blacklist_sources[name], key):
                                setattr(self.blacklist_sources[name], key, value)
                self.save_sources()
            
            return True
        except Exception as e:
            logger.error(f"Error importing configuration: {e}")
            return False

# Initialize global manager instance
blacklist_manager = NeXuSBlacklistManager()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="NeXuS Advanced Blacklist Manager")
    parser.add_argument("--export", help="Export configuration to file")
    parser.add_argument("--import", dest="import_file", help="Import configuration from file")
    parser.add_argument("--preset", choices=["minimal", "balanced", "comprehensive", "maximum"], 
                       help="Apply preset configuration")
    parser.add_argument("--list-categories", action="store_true", help="List all categories")
    parser.add_argument("--list-sources", help="List sources in category")
    
    args = parser.parse_args()
    
    # Load existing configuration
    blacklist_manager.load_sources()
    
    if args.export:
        config = blacklist_manager.export_configuration()
        with open(args.export, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"Configuration exported to {args.export}")
    
    elif args.import_file:
        with open(args.import_file, 'r') as f:
            config = json.load(f)
        if blacklist_manager.import_configuration(config):
            print(f"Configuration imported from {args.import_file}")
        else:
            print("Failed to import configuration")
    
    elif args.preset:
        if blacklist_manager.apply_recommendation(args.preset):
            print(f"Applied {args.preset} preset configuration")
        else:
            print(f"Unknown preset: {args.preset}")
    
    elif args.list_categories:
        summary = blacklist_manager.get_categories_summary()
        for category, info in summary.items():
            status = "✅" if info["enabled"] else "❌"
            print(f"{status} {category.upper()}: {info['enabled_sources']}/{info['total_sources']} sources, ~{info['estimated_domains']:,} domains")
    
    elif args.list_sources:
        sources = blacklist_manager.get_sources_by_category(args.list_sources)
        for source in sources:
            status = "✅" if source.enabled else "❌"
            print(f"{status} {source.name}: {source.description} (~{source.estimated_domains:,} domains)")
    
    else:
        print("NeXuS Advanced Blacklist Manager")
        print("Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!")
        print(f"\nManaging {len(blacklist_manager.blacklist_sources)} blacklist sources across {len(blacklist_manager.get_categories_summary())} categories")
        
        enabled_count = len(blacklist_manager.get_enabled_sources())
        total_domains = sum(s.estimated_domains for s in blacklist_manager.get_enabled_sources())
        
        print(f"Currently enabled: {enabled_count} sources with ~{total_domains:,} domains")
        print("\nUse --help for available commands")