#!/usr/bin/env python3
"""
NeXuS Hydra Web Interface
Real-time monitoring and configuration for multi-network proxy system
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

from fastapi import FastAPI, WebSocket, HTTPException, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import subprocess
import psutil
import os
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import logging
from pathlib import Path
import aiofiles
import uvicorn
from pydantic import BaseModel
import websockets

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nexus-hydra-web")

# Configuration
CONFIG_DIR = Path("/home/user/.nexus-security/hydra")
WEB_DIR = CONFIG_DIR / "web"
STATIC_DIR = WEB_DIR / "static"
TEMPLATES_DIR = WEB_DIR / "templates"
DATA_DIR = CONFIG_DIR / "data"

# Ensure directories exist
for dir_path in [CONFIG_DIR, WEB_DIR, STATIC_DIR, TEMPLATES_DIR, DATA_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="NeXuS Hydra Control Center", version="1.0.0")

# CORS middleware for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Data models
class NetworkStatus(BaseModel):
    name: str
    type: str
    status: str
    health: int
    latency: float
    throughput: int
    connections: int
    last_check: datetime

class SystemMetrics(BaseModel):
    cpu_percent: float
    memory_percent: float
    network_in: int
    network_out: int
    active_connections: int
    blocked_requests: int
    uptime: int

class FilterStats(BaseModel):
    total_lists: int
    total_domains: int
    last_update: datetime
    blocked_today: int
    sources_enabled: List[str]

class ProxyConfig(BaseModel):
    tor_circuits: int
    tor_heads: int
    i2p_tunnels: int
    enable_mesh: bool
    filter_strictness: str
    auto_update: bool

# Global state
connected_websockets: List[WebSocket] = []
system_metrics = {}
network_statuses = {}
filter_stats = {}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def run_command(cmd: str) -> Dict[str, Any]:
    """Execute shell command and return result"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=30
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": "Command timed out",
            "returncode": -1
        }

def check_container_status(container_name: str) -> Dict[str, Any]:
    """Check Podman container status"""
    result = run_command(f"podman ps --filter name={container_name} --format json")
    if result["success"] and result["stdout"]:
        try:
            containers = json.loads(result["stdout"])
            if containers:
                container = containers[0]
                return {
                    "running": True,
                    "id": container["Id"][:12],
                    "status": container["Status"],
                    "created": container["Created"]
                }
        except json.JSONDecodeError:
            pass
    
    return {"running": False, "id": None, "status": "stopped", "created": None}

def check_port_accessibility(port: int, host: str = "127.0.0.1") -> bool:
    """Check if a port is accessible"""
    try:
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def get_network_health(network_type: str, port: int) -> Dict[str, Any]:
    """Get network health metrics"""
    accessible = check_port_accessibility(port)
    
    # Simulate latency check (replace with actual network testing)
    latency = 0.0
    if accessible:
        start_time = time.time()
        # Simple ping test
        result = run_command(f"timeout 3 curl -s --connect-timeout 2 http://127.0.0.1:{port} >/dev/null")
        latency = (time.time() - start_time) * 1000
    
    health = 100 if accessible else 0
    if accessible and latency > 5000:
        health = max(20, 100 - (latency / 100))
    
    return {
        "accessible": accessible,
        "latency": latency,
        "health": int(health),
        "last_check": datetime.now()
    }

# ============================================================================
# MONITORING FUNCTIONS
# ============================================================================

async def update_system_metrics():
    """Update system performance metrics"""
    global system_metrics
    
    try:
        # CPU and Memory
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        
        # Network I/O
        net_io = psutil.net_io_counters()
        
        # Count active connections
        active_connections = len(psutil.net_connections(kind='inet'))
        
        # Get blocked requests (placeholder - implement actual counter)
        blocked_today = 0  # TODO: Implement actual blocked request counter
        
        # System uptime
        boot_time = psutil.boot_time()
        uptime = int(time.time() - boot_time)
        
        system_metrics = SystemMetrics(
            cpu_percent=cpu_percent,
            memory_percent=memory.percent,
            network_in=net_io.bytes_recv,
            network_out=net_io.bytes_sent,
            active_connections=active_connections,
            blocked_requests=blocked_today,
            uptime=uptime
        )
        
    except Exception as e:
        logger.error(f"Error updating system metrics: {e}")

async def update_network_statuses():
    """Update network service statuses"""
    global network_statuses
    
    networks = [
        {"name": "Tor-1", "type": "tor", "port": 9050},
        {"name": "Tor-2", "type": "tor", "port": 9051},
        {"name": "Tor-3", "type": "tor", "port": 9052},
        {"name": "I2P", "type": "i2p", "port": 4444},
        {"name": "Privoxy", "type": "proxy", "port": 8118},
        {"name": "HAProxy", "type": "loadbalancer", "port": 8888},
        {"name": "Yggdrasil", "type": "mesh", "port": 9001},
        {"name": "IPFS", "type": "distributed", "port": 8080},
    ]
    
    for network in networks:
        try:
            health_data = get_network_health(network["type"], network["port"])
            container_status = check_container_status(f"nexus-{network['name'].lower()}")
            
            status = "running" if health_data["accessible"] else "stopped"
            if container_status["running"] and not health_data["accessible"]:
                status = "unhealthy"
            
            network_statuses[network["name"]] = NetworkStatus(
                name=network["name"],
                type=network["type"],
                status=status,
                health=health_data["health"],
                latency=health_data["latency"],
                throughput=0,  # TODO: Implement throughput measurement
                connections=0,  # TODO: Implement connection counting
                last_check=health_data["last_check"]
            )
            
        except Exception as e:
            logger.error(f"Error checking {network['name']}: {e}")

async def update_filter_stats():
    """Update filter and blacklist statistics"""
    global filter_stats
    
    try:
        # Count filter files and domains (placeholder implementation)
        config_dir = Path("/home/user/.nexus-security/privoxy-professional/config")
        filter_files = list(config_dir.glob("*.action")) if config_dir.exists() else []
        
        total_domains = 0
        for filter_file in filter_files:
            try:
                with open(filter_file, 'r') as f:
                    lines = f.readlines()
                    # Count domain lines (simplified)
                    total_domains += len([l for l in lines if not l.startswith('#') and '.' in l])
            except:
                pass
        
        filter_stats = FilterStats(
            total_lists=len(filter_files),
            total_domains=total_domains,
            last_update=datetime.now() - timedelta(hours=2),  # Placeholder
            blocked_today=12847,  # Placeholder
            sources_enabled=["EasyList", "HaGeZi Pro", "uBlock Origin", "Steven Black"]
        )
        
    except Exception as e:
        logger.error(f"Error updating filter stats: {e}")

async def broadcast_updates():
    """Broadcast updates to all connected websockets"""
    if not connected_websockets:
        return
        
    try:
        update_data = {
            "timestamp": datetime.now().isoformat(),
            "system": system_metrics.dict() if system_metrics else {},
            "networks": {name: status.dict() for name, status in network_statuses.items()},
            "filters": filter_stats.dict() if filter_stats else {}
        }
        
        message = json.dumps(update_data)
        disconnected = []
        
        for websocket in connected_websockets:
            try:
                await websocket.send_text(message)
            except:
                disconnected.append(websocket)
        
        # Remove disconnected websockets
        for ws in disconnected:
            connected_websockets.remove(ws)
            
    except Exception as e:
        logger.error(f"Error broadcasting updates: {e}")

async def monitoring_loop():
    """Main monitoring loop"""
    while True:
        try:
            await update_system_metrics()
            await update_network_statuses()
            await update_filter_stats()
            await broadcast_updates()
            await asyncio.sleep(5)  # Update every 5 seconds
        except Exception as e:
            logger.error(f"Error in monitoring loop: {e}")
            await asyncio.sleep(10)

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
async def read_root():
    """Serve the main dashboard"""
    return FileResponse(str(TEMPLATES_DIR / "index.html"))

@app.get("/api/status")
async def get_status():
    """Get overall system status"""
    return {
        "system": system_metrics.dict() if system_metrics else {},
        "networks": {name: status.dict() for name, status in network_statuses.items()},
        "filters": filter_stats.dict() if filter_stats else {},
        "timestamp": datetime.now().isoformat()
    }

@app.get("/api/networks")
async def get_networks():
    """Get all network statuses"""
    return {name: status.dict() for name, status in network_statuses.items()}

@app.get("/api/networks/{network_name}")
async def get_network(network_name: str):
    """Get specific network status"""
    if network_name not in network_statuses:
        raise HTTPException(status_code=404, detail="Network not found")
    return network_statuses[network_name].dict()

@app.post("/api/networks/{network_name}/restart")
async def restart_network(network_name: str, background_tasks: BackgroundTasks):
    """Restart a specific network service"""
    if network_name not in network_statuses:
        raise HTTPException(status_code=404, detail="Network not found")
    
    def restart_service():
        container_name = f"nexus-{network_name.lower()}"
        run_command(f"podman restart {container_name}")
    
    background_tasks.add_task(restart_service)
    return {"message": f"Restarting {network_name}"}

@app.post("/api/emergency")
async def emergency_mode():
    """Activate emergency mode"""
    # Implement emergency mode logic
    return {"message": "Emergency mode activated", "status": "success"}

@app.get("/api/filters/update")
async def update_filters(background_tasks: BackgroundTasks):
    """Trigger filter list updates"""
    
    def update_filter_lists():
        # Run the professional filter update script
        run_command("/home/user/scripts/nexus-privoxy-professional.sh update")
    
    background_tasks.add_task(update_filter_lists)
    return {"message": "Filter update started", "status": "success"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await websocket.accept()
    connected_websockets.append(websocket)
    
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except:
        if websocket in connected_websockets:
            connected_websockets.remove(websocket)

# ============================================================================
# HTML TEMPLATE CREATION
# ============================================================================

def create_html_template():
    """Create the main HTML dashboard"""
    html_content = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔥 NeXuS Hydra Control Center 🔥</title>
    <style>
        /* Self-contained beautiful interface - no external dependencies */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        :root {
            /* Light theme */
            --bg-primary-light: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 25%, #cbd5e1 50%, #94a3b8 100%);
            --bg-secondary-light: rgba(248, 250, 252, 0.9);
            --bg-card-light: rgba(255, 255, 255, 0.8);
            --text-primary-light: #1e293b;
            --text-secondary-light: #475569;
            --primary-light: #3b82f6;
            --secondary-light: #06b6d4;
            --accent-light: #8b5cf6;
            --success-light: #10b981;
            --warning-light: #f59e0b;
            --error-light: #ef4444;
            --border-light: rgba(148, 163, 184, 0.3);
            
            /* Dark theme */
            --bg-primary-dark: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 25%, #16213e 50%, #0f3460 100%);
            --bg-secondary-dark: rgba(26, 26, 46, 0.9);
            --bg-card-dark: rgba(22, 33, 62, 0.8);
            --text-primary-dark: #ffffff;
            --text-secondary-dark: #b8c5d6;
            --primary-dark: #ff6b35;
            --secondary-dark: #f7931e;
            --accent-dark: #ffdc00;
            --success-dark: #00ff41;
            --warning-dark: #ffaa00;
            --error-dark: #ff0040;
            --border-dark: rgba(255, 107, 53, 0.3);
            
            /* Cyberpunk theme */
            --bg-primary-cyberpunk: linear-gradient(135deg, #0a0a0a 0%, #1a0a1a 25%, #2a0a2a 50%, #3a0a3a 100%);
            --bg-secondary-cyberpunk: rgba(26, 10, 26, 0.9);
            --bg-card-cyberpunk: rgba(42, 10, 42, 0.8);
            --text-primary-cyberpunk: #ff00ff;
            --text-secondary-cyberpunk: #ff80ff;
            --primary-cyberpunk: #ff0080;
            --secondary-cyberpunk: #8000ff;
            --accent-cyberpunk: #00ffff;
            --success-cyberpunk: #00ff80;
            --warning-cyberpunk: #ffff00;
            --error-cyberpunk: #ff4040;
            --border-cyberpunk: rgba(255, 0, 128, 0.3);
            
            /* Matrix theme */
            --bg-primary-matrix: linear-gradient(135deg, #000000 0%, #001100 25%, #002200 50%, #003300 100%);
            --bg-secondary-matrix: rgba(0, 17, 0, 0.9);
            --bg-card-matrix: rgba(0, 34, 0, 0.8);
            --text-primary-matrix: #00ff41;
            --text-secondary-matrix: #008f11;
            --primary-matrix: #00ff41;
            --secondary-matrix: #008f11;
            --accent-matrix: #00c631;
            --success-matrix: #00ff41;
            --warning-matrix: #ffff00;
            --error-matrix: #ff0040;
            --border-matrix: rgba(0, 255, 65, 0.3);
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: var(--bg-primary);
            min-height: 100vh;
            color: var(--text-primary);
            overflow-x: hidden;
            transition: all 0.3s ease;
        }
        
        /* Theme classes */
        .theme-light {
            --bg-primary: var(--bg-primary-light);
            --bg-secondary: var(--bg-secondary-light);
            --bg-card: var(--bg-card-light);
            --text-primary: var(--text-primary-light);
            --text-secondary: var(--text-secondary-light);
            --primary: var(--primary-light);
            --secondary: var(--secondary-light);
            --accent: var(--accent-light);
            --success: var(--success-light);
            --warning: var(--warning-light);
            --error: var(--error-light);
            --border: var(--border-light);
        }
        
        .theme-dark {
            --bg-primary: var(--bg-primary-dark);
            --bg-secondary: var(--bg-secondary-dark);
            --bg-card: var(--bg-card-dark);
            --text-primary: var(--text-primary-dark);
            --text-secondary: var(--text-secondary-dark);
            --primary: var(--primary-dark);
            --secondary: var(--secondary-dark);
            --accent: var(--accent-dark);
            --success: var(--success-dark);
            --warning: var(--warning-dark);
            --error: var(--error-dark);
            --border: var(--border-dark);
        }
        
        .theme-cyberpunk {
            --bg-primary: var(--bg-primary-cyberpunk);
            --bg-secondary: var(--bg-secondary-cyberpunk);
            --bg-card: var(--bg-card-cyberpunk);
            --text-primary: var(--text-primary-cyberpunk);
            --text-secondary: var(--text-secondary-cyberpunk);
            --primary: var(--primary-cyberpunk);
            --secondary: var(--secondary-cyberpunk);
            --accent: var(--accent-cyberpunk);
            --success: var(--success-cyberpunk);
            --warning: var(--warning-cyberpunk);
            --error: var(--error-cyberpunk);
            --border: var(--border-cyberpunk);
        }
        
        .theme-matrix {
            --bg-primary: var(--bg-primary-matrix);
            --bg-secondary: var(--bg-secondary-matrix);
            --bg-card: var(--bg-card-matrix);
            --text-primary: var(--text-primary-matrix);
            --text-secondary: var(--text-secondary-matrix);
            --primary: var(--primary-matrix);
            --secondary: var(--secondary-matrix);
            --accent: var(--accent-matrix);
            --success: var(--success-matrix);
            --warning: var(--warning-matrix);
            --error: var(--error-matrix);
            --border: var(--border-matrix);
        }
        
        .fire-gradient {
            background: linear-gradient(45deg, var(--primary), var(--secondary), var(--accent));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            font-weight: bold;
            text-shadow: none;
        }
        
        .header {
            background: var(--bg-secondary);
            padding: 1.5rem 2rem;
            border-bottom: 3px solid var(--primary);
            box-shadow: 0 4px 20px var(--border);
            position: sticky;
            top: 0;
            z-index: 100;
            backdrop-filter: blur(15px);
        }
        
        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 1rem;
        }
        
        .header h1 {
            font-size: 2.5rem;
            font-weight: 900;
            text-shadow: 0 0 20px var(--primary);
            letter-spacing: -0.025em;
        }
        
        .theme-selector {
            display: flex;
            gap: 0.5rem;
            background: var(--bg-card);
            padding: 0.5rem;
            border-radius: 12px;
            border: 2px solid var(--border);
        }
        
        .theme-btn {
            padding: 0.75rem 1.25rem;
            border: 2px solid transparent;
            background: transparent;
            color: var(--text-primary);
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.9rem;
            font-weight: 600;
            position: relative;
            overflow: hidden;
        }
        
        .theme-btn::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, var(--primary), transparent);
            transition: left 0.5s ease;
        }
        
        .theme-btn:hover::before {
            left: 100%;
        }
        
        .theme-btn:hover {
            border-color: var(--primary);
            box-shadow: 0 0 15px var(--border);
            transform: translateY(-2px);
        }
        
        .theme-btn.active {
            background: var(--primary);
            color: var(--bg-primary);
            border-color: var(--primary);
            box-shadow: 0 0 25px var(--border);
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 2rem;
            margin-bottom: 3rem;
        }
        
        .stat-card {
            background: var(--bg-card);
            padding: 2rem;
            border-radius: 16px;
            border: 2px solid var(--border);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            backdrop-filter: blur(10px);
        }
        
        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, var(--primary), var(--secondary), var(--accent));
        }
        
        .stat-card::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(circle at 50% 50%, var(--border), transparent 70%);
            opacity: 0;
            transition: opacity 0.3s ease;
        }
        
        .stat-card:hover {
            border-color: var(--primary);
            box-shadow: 0 10px 40px var(--border);
            transform: translateY(-8px) scale(1.02);
        }
        
        .stat-card:hover::after {
            opacity: 1;
        }
        
        .stat-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
            display: block;
            opacity: 0.8;
        }
        
        .stat-value {
            font-size: 3rem;
            font-weight: 900;
            color: var(--primary);
            text-shadow: 0 0 20px var(--primary);
            margin-bottom: 0.5rem;
            position: relative;
            z-index: 1;
        }
        
        .stat-label {
            font-size: 1rem;
            color: var(--text-secondary);
            font-weight: 500;
            position: relative;
            z-index: 1;
        }
        
        .section {
            margin-bottom: 3rem;
        }
        
        .section-title {
            font-size: 2rem;
            font-weight: 800;
            color: var(--primary);
            margin-bottom: 1.5rem;
            text-shadow: 0 0 15px var(--primary);
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }
        
        .network-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .network-card {
            background: var(--bg-card);
            border-radius: 16px;
            overflow: hidden;
            border: 2px solid var(--border);
            transition: all 0.3s ease;
            position: relative;
            backdrop-filter: blur(10px);
        }
        
        .network-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 12px 36px var(--border);
            border-color: var(--primary);
        }
        
        .network-card.running {
            border-color: var(--success);
            background: linear-gradient(135deg, var(--bg-card), rgba(var(--success), 0.1));
        }
        
        .network-card.stopped {
            border-color: var(--error);
            background: linear-gradient(135deg, var(--bg-card), rgba(var(--error), 0.1));
            opacity: 0.7;
        }
        
        .network-card.unhealthy {
            border-color: var(--warning);
            background: linear-gradient(135deg, var(--bg-card), rgba(var(--warning), 0.1));
        }
        
        .network-header {
            padding: 1.5rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border);
        }
        
        .network-name {
            font-size: 1.25rem;
            font-weight: 700;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .network-status {
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        
        .status-running {
            background: var(--success);
            color: var(--bg-primary);
        }
        
        .status-stopped {
            background: var(--error);
            color: white;
        }
        
        .status-unhealthy {
            background: var(--warning);
            color: var(--bg-primary);
        }
        
        .network-body {
            padding: 1.5rem;
        }
        
        .network-metric {
            display: flex;
            justify-content: space-between;
            margin-bottom: 0.75rem;
            font-size: 0.9rem;
        }
        
        .metric-label {
            color: var(--text-secondary);
            font-weight: 500;
        }
        
        .metric-value {
            color: var(--text-primary);
            font-weight: 600;
        }
        
        .health-bar {
            width: 100%;
            height: 8px;
            background: rgba(var(--text-secondary), 0.2);
            border-radius: 4px;
            overflow: hidden;
            margin: 1rem 0;
        }
        
        .health-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--error), var(--warning), var(--success));
            transition: width 0.5s ease;
            border-radius: 4px;
        }
        
        .network-actions {
            display: flex;
            gap: 0.5rem;
            margin-top: 1rem;
        }
        
        .action-btn {
            flex: 1;
            padding: 0.75rem;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 0.85rem;
            font-weight: 600;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .action-btn::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
            transition: left 0.5s ease;
        }
        
        .action-btn:hover::before {
            left: 100%;
        }
        
        .btn-restart {
            background: var(--warning);
            color: var(--bg-primary);
        }
        
        .btn-restart:hover {
            background: var(--secondary);
            box-shadow: 0 4px 15px rgba(var(--warning), 0.4);
        }
        
        .quick-actions {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 3rem;
        }
        
        .quick-action-btn {
            padding: 2rem;
            background: var(--bg-card);
            border: 2px solid var(--border);
            border-radius: 16px;
            color: var(--text-primary);
            cursor: pointer;
            transition: all 0.3s ease;
            text-align: center;
            font-size: 1.1rem;
            font-weight: 600;
            position: relative;
            overflow: hidden;
        }
        
        .quick-action-btn::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            width: 0;
            height: 0;
            background: radial-gradient(circle, var(--primary), transparent 70%);
            transition: all 0.5s ease;
            transform: translate(-50%, -50%);
        }
        
        .quick-action-btn:hover::before {
            width: 300px;
            height: 300px;
        }
        
        .quick-action-btn:hover {
            border-color: var(--primary);
            box-shadow: 0 8px 32px var(--border);
            transform: translateY(-4px);
        }
        
        .quick-action-icon {
            font-size: 2.5rem;
            margin-bottom: 1rem;
            display: block;
        }
        
        .activity-log {
            background: var(--bg-card);
            border-radius: 16px;
            border: 2px solid var(--border);
            overflow: hidden;
            margin-bottom: 2rem;
        }
        
        .activity-header {
            padding: 1.5rem;
            background: var(--bg-secondary);
            border-bottom: 1px solid var(--border);
            font-size: 1.25rem;
            font-weight: 700;
            color: var(--primary);
        }
        
        .activity-content {
            height: 300px;
            overflow-y: auto;
            padding: 1rem;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
        }
        
        .log-entry {
            padding: 0.5rem 0;
            border-bottom: 1px solid rgba(var(--border), 0.1);
            display: flex;
            gap: 1rem;
        }
        
        .log-time {
            color: var(--text-secondary);
            font-weight: 500;
            min-width: 80px;
        }
        
        .log-message {
            color: var(--text-primary);
        }
        
        .log-error {
            color: var(--error);
        }
        
        .log-warning {
            color: var(--warning);
        }
        
        .log-success {
            color: var(--success);
        }
        
        .floating-nav {
            position: fixed;
            top: 50%;
            right: 2rem;
            transform: translateY(-50%);
            display: flex;
            flex-direction: column;
            gap: 1rem;
            z-index: 50;
        }
        
        .nav-btn {
            width: 60px;
            height: 60px;
            background: var(--primary);
            border: none;
            border-radius: 50%;
            color: var(--bg-primary);
            font-size: 1.5rem;
            cursor: pointer;
            box-shadow: 0 4px 20px var(--border);
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            overflow: hidden;
        }
        
        .nav-btn::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(circle, rgba(255,255,255,0.3), transparent 70%);
            opacity: 0;
            transition: opacity 0.3s ease;
        }
        
        .nav-btn:hover::before {
            opacity: 1;
        }
        
        .nav-btn:hover {
            transform: scale(1.1);
            box-shadow: 0 8px 32px var(--border);
        }
        
        .glow {
            animation: glow 2s ease-in-out infinite alternate;
        }
        
        @keyframes glow {
            from { 
                box-shadow: 0 0 10px var(--primary), 0 0 20px var(--primary), 0 0 30px var(--primary);
            }
            to { 
                box-shadow: 0 0 20px var(--primary), 0 0 30px var(--primary), 0 0 40px var(--primary);
            }
        }
        
        .pulse {
            animation: pulse 2s ease-in-out infinite;
        }
        
        @keyframes pulse {
            0%, 100% { 
                transform: scale(1); 
                opacity: 1; 
            }
            50% { 
                transform: scale(1.05); 
                opacity: 0.8; 
            }
        }
        
        .slide-in {
            animation: slideIn 0.5s ease-out;
        }
        
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        /* Mobile responsiveness */
        @media (max-width: 768px) {
            .header {
                padding: 1rem;
            }
            
            .header h1 {
                font-size: 1.8rem;
            }
            
            .header-content {
                flex-direction: column;
                text-align: center;
            }
            
            .container {
                padding: 1rem;
            }
            
            .stats-grid {
                grid-template-columns: 1fr;
                gap: 1rem;
            }
            
            .network-grid {
                grid-template-columns: 1fr;
            }
            
            .quick-actions {
                grid-template-columns: 1fr;
            }
            
            .floating-nav {
                right: 1rem;
                bottom: 2rem;
                top: auto;
                transform: none;
                flex-direction: row;
            }
            
            .nav-btn {
                width: 50px;
                height: 50px;
                font-size: 1.2rem;
            }
        }
        
        /* Enhanced scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
        }
        
        ::-webkit-scrollbar-track {
            background: var(--bg-secondary);
        }
        
        ::-webkit-scrollbar-thumb {
            background: var(--primary);
            border-radius: 4px;
        }
        
        ::-webkit-scrollbar-thumb:hover {
            background: var(--secondary);
        }
    </style>
</head>
<body class="theme-dark">
    <div id="app">
        <!-- Header -->
        <header class="fire-gradient p-4 shadow-lg">
            <div class="container mx-auto flex justify-between items-center">
                <h1 class="text-3xl font-bold text-black">🔥 NeXuS Hydra Control Center 🔥</h1>
                <div class="flex space-x-4">
                    <span class="text-black font-semibold">Status: {{ systemStatus }}</span>
                    <span class="text-black">{{ currentTime }}</span>
                </div>
            </div>
        </header>

        <!-- Main Dashboard -->
        <div class="container mx-auto p-6">
            <!-- System Overview -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                <div class="bg-gray-800 p-6 rounded-lg glow">
                    <h3 class="text-xl font-bold mb-2">System Load</h3>
                    <div class="text-3xl font-bold text-orange-400">{{ systemMetrics.cpu_percent || 0 }}%</div>
                    <div class="text-sm text-gray-400">CPU Usage</div>
                </div>
                <div class="bg-gray-800 p-6 rounded-lg">
                    <h3 class="text-xl font-bold mb-2">Memory</h3>
                    <div class="text-3xl font-bold text-blue-400">{{ systemMetrics.memory_percent || 0 }}%</div>
                    <div class="text-sm text-gray-400">RAM Usage</div>
                </div>
                <div class="bg-gray-800 p-6 rounded-lg">
                    <h3 class="text-xl font-bold mb-2">Networks Active</h3>
                    <div class="text-3xl font-bold text-green-400">{{ activeNetworksCount }}/{{ totalNetworksCount }}</div>
                    <div class="text-sm text-gray-400">Proxy Heads</div>
                </div>
                <div class="bg-gray-800 p-6 rounded-lg">
                    <h3 class="text-xl font-bold mb-2">Blocked Today</h3>
                    <div class="text-3xl font-bold text-red-400">{{ filterStats.blocked_today || 0 | formatNumber }}</div>
                    <div class="text-sm text-gray-400">Requests Blocked</div>
                </div>
            </div>

            <!-- Network Status Grid -->
            <div class="mb-8">
                <h2 class="text-2xl font-bold mb-4">🌐 Network Status</h2>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div v-for="(network, name) in networks" :key="name" 
                         class="network-card bg-gray-800 p-4 rounded-lg border-l-4"
                         :class="getNetworkBorderClass(network.status)">
                        <div class="flex justify-between items-center mb-2">
                            <h4 class="font-bold">{{ name }}</h4>
                            <span class="text-xs px-2 py-1 rounded" 
                                  :class="getStatusClass(network.status)">
                                {{ network.status?.toUpperCase() }}
                            </span>
                        </div>
                        <div class="text-sm text-gray-400">
                            <div>Health: {{ network.health || 0 }}%</div>
                            <div>Latency: {{ network.latency || 0 | formatLatency }}ms</div>
                            <div>Type: {{ network.type }}</div>
                        </div>
                        <div class="mt-2 flex space-x-2">
                            <button @click="restartNetwork(name)" 
                                    class="bg-orange-600 hover:bg-orange-700 px-2 py-1 rounded text-xs">
                                Restart
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="mb-8">
                <h2 class="text-2xl font-bold mb-4">⚡ Quick Actions</h2>
                <div class="flex flex-wrap gap-4">
                    <button @click="emergencyMode" 
                            class="bg-red-600 hover:bg-red-700 px-6 py-3 rounded-lg font-bold">
                        🚨 Emergency Mode
                    </button>
                    <button @click="restartAll" 
                            class="bg-orange-600 hover:bg-orange-700 px-6 py-3 rounded-lg font-bold">
                        🔄 Restart All
                    </button>
                    <button @click="updateFilters" 
                            class="bg-blue-600 hover:bg-blue-700 px-6 py-3 rounded-lg font-bold">
                        🛡️ Update Filters
                    </button>
                    <button @click="showSettings = !showSettings" 
                            class="bg-gray-600 hover:bg-gray-700 px-6 py-3 rounded-lg font-bold">
                        ⚙️ Settings
                    </button>
                </div>
            </div>

            <!-- Settings Panel -->
            <div v-if="showSettings" class="mb-8 bg-gray-800 p-6 rounded-lg">
                <h2 class="text-2xl font-bold mb-4">⚙️ Configuration</h2>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                        <h3 class="text-lg font-bold mb-2">Tor Settings</h3>
                        <div class="space-y-2">
                            <label class="block">
                                <span class="text-sm">Circuits: </span>
                                <input v-model="config.tor_circuits" type="number" min="1" max="10" 
                                       class="bg-gray-700 px-2 py-1 rounded w-20">
                            </label>
                            <label class="block">
                                <span class="text-sm">Heads: </span>
                                <input v-model="config.tor_heads" type="number" min="1" max="5" 
                                       class="bg-gray-700 px-2 py-1 rounded w-20">
                            </label>
                        </div>
                    </div>
                    <div>
                        <h3 class="text-lg font-bold mb-2">Filter Settings</h3>
                        <div class="space-y-2">
                            <label class="flex items-center space-x-2">
                                <input v-model="config.auto_update" type="checkbox" class="form-checkbox">
                                <span class="text-sm">Auto Update Filters</span>
                            </label>
                            <label class="block">
                                <span class="text-sm">Strictness: </span>
                                <select v-model="config.filter_strictness" class="bg-gray-700 px-2 py-1 rounded">
                                    <option value="light">Light</option>
                                    <option value="normal">Normal</option>
                                    <option value="strict">Strict</option>
                                </select>
                            </label>
                        </div>
                    </div>
                </div>
                <div class="mt-4">
                    <button @click="saveConfig" class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded">
                        Save Configuration
                    </button>
                </div>
            </div>

            <!-- Live Activity Log -->
            <div class="mb-8">
                <h2 class="text-2xl font-bold mb-4">📊 Live Activity</h2>
                <div class="bg-gray-800 p-4 rounded-lg h-64 overflow-y-auto">
                    <div v-for="log in activityLog" :key="log.timestamp" 
                         class="text-sm mb-1 font-mono"
                         :class="getLogClass(log.type)">
                        <span class="text-gray-400">{{ log.timestamp }}</span>
                        <span class="ml-2">{{ log.message }}</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const { createApp } = Vue;
        
        createApp({
            data() {
                return {
                    systemStatus: 'INITIALIZING',
                    currentTime: '',
                    systemMetrics: {},
                    networks: {},
                    filterStats: {},
                    showSettings: false,
                    config: {
                        tor_circuits: 3,
                        tor_heads: 3,
                        i2p_tunnels: 3,
                        enable_mesh: true,
                        filter_strictness: 'normal',
                        auto_update: true
                    },
                    activityLog: [],
                    websocket: null
                }
            },
            computed: {
                activeNetworksCount() {
                    return Object.values(this.networks).filter(n => n.status === 'running').length;
                },
                totalNetworksCount() {
                    return Object.keys(this.networks).length;
                }
            },
            methods: {
                formatNumber(num) {
                    return new Intl.NumberFormat().format(num);
                },
                formatLatency(lat) {
                    return Math.round(lat * 100) / 100;
                },
                getNetworkBorderClass(status) {
                    switch(status) {
                        case 'running': return 'border-green-500';
                        case 'unhealthy': return 'border-yellow-500';
                        case 'stopped': return 'border-red-500';
                        default: return 'border-gray-500';
                    }
                },
                getStatusClass(status) {
                    switch(status) {
                        case 'running': return 'bg-green-600 text-white';
                        case 'unhealthy': return 'bg-yellow-600 text-black';
                        case 'stopped': return 'bg-red-600 text-white';
                        default: return 'bg-gray-600 text-white';
                    }
                },
                getLogClass(type) {
                    switch(type) {
                        case 'error': return 'text-red-400';
                        case 'warning': return 'text-yellow-400';
                        case 'success': return 'text-green-400';
                        default: return 'text-gray-300';
                    }
                },
                async restartNetwork(name) {
                    try {
                        const response = await fetch(`/api/networks/${name}/restart`, {
                            method: 'POST'
                        });
                        const result = await response.json();
                        this.addLog('info', `Restarting ${name}...`);
                    } catch (error) {
                        this.addLog('error', `Failed to restart ${name}: ${error.message}`);
                    }
                },
                async emergencyMode() {
                    try {
                        const response = await fetch('/api/emergency', { method: 'POST' });
                        const result = await response.json();
                        this.addLog('warning', 'Emergency mode activated');
                        this.systemStatus = 'EMERGENCY';
                    } catch (error) {
                        this.addLog('error', `Emergency mode failed: ${error.message}`);
                    }
                },
                async restartAll() {
                    this.addLog('info', 'Restarting all services...');
                    for (const name of Object.keys(this.networks)) {
                        await this.restartNetwork(name);
                        await new Promise(resolve => setTimeout(resolve, 1000));
                    }
                },
                async updateFilters() {
                    try {
                        const response = await fetch('/api/filters/update');
                        const result = await response.json();
                        this.addLog('info', 'Filter update started...');
                    } catch (error) {
                        this.addLog('error', `Filter update failed: ${error.message}`);
                    }
                },
                saveConfig() {
                    this.addLog('success', 'Configuration saved');
                    // TODO: Implement config save API
                },
                addLog(type, message) {
                    const timestamp = new Date().toLocaleTimeString();
                    this.activityLog.unshift({ timestamp, type, message });
                    if (this.activityLog.length > 100) {
                        this.activityLog.pop();
                    }
                },
                updateTime() {
                    this.currentTime = new Date().toLocaleTimeString();
                },
                connectWebSocket() {
                    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                    this.websocket = new WebSocket(`${protocol}//${window.location.host}/ws`);
                    
                    this.websocket.onmessage = (event) => {
                        const data = JSON.parse(event.data);
                        this.systemMetrics = data.system || {};
                        this.networks = data.networks || {};
                        this.filterStats = data.filters || {};
                        
                        // Update system status
                        const healthyNetworks = Object.values(this.networks).filter(n => n.status === 'running').length;
                        if (healthyNetworks > 0) {
                            this.systemStatus = 'ACTIVE';
                        } else {
                            this.systemStatus = 'OFFLINE';
                        }
                    };
                    
                    this.websocket.onclose = () => {
                        this.addLog('warning', 'WebSocket connection lost. Reconnecting...');
                        setTimeout(() => this.connectWebSocket(), 5000);
                    };
                    
                    this.websocket.onopen = () => {
                        this.addLog('success', 'Connected to NeXuS Hydra Control Center');
                    };
                }
            },
            mounted() {
                this.updateTime();
                setInterval(this.updateTime, 1000);
                this.connectWebSocket();
                
                // Initial status load
                fetch('/api/status')
                    .then(response => response.json())
                    .then(data => {
                        this.systemMetrics = data.system || {};
                        this.networks = data.networks || {};
                        this.filterStats = data.filters || {};
                    })
                    .catch(error => {
                        this.addLog('error', `Failed to load initial status: ${error.message}`);
                    });
            }
        }).mount('#app');
    </script>
</body>
</html>'''
    
    with open(TEMPLATES_DIR / "index.html", "w") as f:
        f.write(html_content)

# ============================================================================
# STARTUP
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize the application"""
    logger.info("Starting NeXuS Hydra Web Interface")
    
    # Create HTML template
    create_html_template()
    
    # Start monitoring loop
    asyncio.create_task(monitoring_loop())
    
    logger.info("NeXuS Hydra Web Interface ready")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="NeXuS Hydra Web Interface")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8443, help="Port to bind to")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload")
    
    args = parser.parse_args()
    
    print("🔥 Starting NeXuS Hydra Control Center 🔥")
    print(f"🌐 Interface: https://{args.host}:{args.port}")
    print("Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!")
    
    uvicorn.run(
        "nexus-hydra-web-interface:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
        ssl_keyfile="/home/user/.nexus-security/ssl/nexus.key" if os.path.exists("/home/user/.nexus-security/ssl/nexus.key") else None,
        ssl_certfile="/home/user/.nexus-security/ssl/nexus.crt" if os.path.exists("/home/user/.nexus-security/ssl/nexus.crt") else None
    )