#!/usr/bin/env python3
"""
NeXuS Beautiful Blacklist Web Manager
Self-contained web interface with themes, emojis, and no external dependencies
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Any
import uvicorn
from nexus_blacklist_manager import blacklist_manager

app = FastAPI(title="NeXuS Blacklist Manager", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def create_beautiful_html():
    """Create a beautiful, self-contained HTML interface"""
    return '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🛡️ NeXuS Blacklist Control Center 🛡️</title>
    <style>
        /* Self-contained fonts and styles */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 25%, #16213e  50%, #0f3460 100%);
            min-height: 100vh;
            color: #ffffff;
            overflow-x: hidden;
        }
        
        .theme-cyberpunk {
            --primary: #ff6b35;
            --secondary: #f7931e;
            --accent: #ffdc00;
            --success: #00ff41;
            --warning: #ffaa00;
            --error: #ff0040;
            --bg-primary: rgba(15, 15, 35, 0.95);
            --bg-secondary: rgba(26, 26, 46, 0.9);
            --bg-card: rgba(22, 33, 62, 0.8);
            --text-primary: #ffffff;
            --text-secondary: #b8c5d6;
        }
        
        .theme-matrix {
            --primary: #00ff41;
            --secondary: #008f11;
            --accent: #00c631;
            --success: #00ff41;
            --warning: #ffff00;
            --error: #ff0040;
            --bg-primary: rgba(0, 0, 0, 0.95);
            --bg-secondary: rgba(0, 20, 0, 0.9);
            --bg-card: rgba(0, 40, 0, 0.8);
            --text-primary: #00ff41;
            --text-secondary: #008f11;
        }
        
        .theme-neon {
            --primary: #ff0080;
            --secondary: #8000ff;
            --accent: #00ffff;
            --success: #00ff80;
            --warning: #ffff00;
            --error: #ff4040;
            --bg-primary: rgba(20, 0, 20, 0.95);
            --bg-secondary: rgba(40, 0, 40, 0.9);
            --bg-card: rgba(60, 0, 60, 0.8);
            --text-primary: #ffffff;
            --text-secondary: #ff80ff;
        }
        
        .fire-gradient {
            background: linear-gradient(45deg, var(--primary), var(--secondary), var(--accent));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            font-weight: bold;
        }
        
        .header {
            background: var(--bg-primary);
            padding: 1rem 2rem;
            border-bottom: 3px solid var(--primary);
            box-shadow: 0 4px 20px rgba(255, 107, 53, 0.3);
            position: sticky;
            top: 0;
            z-index: 100;
            backdrop-filter: blur(10px);
        }
        
        .header-content {
            max-width: 1200px;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .header h1 {
            font-size: 2rem;
            text-shadow: 0 0 10px var(--primary);
        }
        
        .theme-selector {
            display: flex;
            gap: 0.5rem;
        }
        
        .theme-btn {
            padding: 0.5rem 1rem;
            border: 2px solid var(--primary);
            background: var(--bg-card);
            color: var(--text-primary);
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 0.9rem;
        }
        
        .theme-btn:hover {
            background: var(--primary);
            color: #000;
            box-shadow: 0 0 15px var(--primary);
            transform: translateY(-2px);
        }
        
        .theme-btn.active {
            background: var(--primary);
            color: #000;
            box-shadow: 0 0 20px var(--primary);
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .stat-card {
            background: var(--bg-card);
            padding: 1.5rem;
            border-radius: 12px;
            border: 2px solid transparent;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, var(--primary), var(--secondary), var(--accent));
        }
        
        .stat-card:hover {
            border-color: var(--primary);
            box-shadow: 0 8px 32px rgba(255, 107, 53, 0.2);
            transform: translateY(-4px);
        }
        
        .stat-value {
            font-size: 2.5rem;
            font-weight: bold;
            color: var(--primary);
            text-shadow: 0 0 10px var(--primary);
        }
        
        .stat-label {
            font-size: 0.9rem;
            color: var(--text-secondary);
            margin-top: 0.5rem;
        }
        
        .preset-buttons {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        
        .preset-btn {
            padding: 1rem;
            background: var(--bg-card);
            border: 2px solid var(--primary);
            border-radius: 12px;
            color: var(--text-primary);
            cursor: pointer;
            transition: all 0.3s ease;
            text-align: center;
            font-size: 1rem;
        }
        
        .preset-btn:hover {
            background: var(--primary);
            color: #000;
            box-shadow: 0 0 20px var(--primary);
            transform: scale(1.05);
        }
        
        .category-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .category-card {
            background: var(--bg-card);
            border-radius: 12px;
            overflow: hidden;
            border: 2px solid transparent;
            transition: all 0.3s ease;
        }
        
        .category-card.enabled {
            border-color: var(--success);
            box-shadow: 0 0 20px rgba(0, 255, 65, 0.2);
        }
        
        .category-card.disabled {
            border-color: var(--error);
            opacity: 0.7;
        }
        
        .category-header {
            padding: 1rem;
            background: linear-gradient(135deg, var(--bg-secondary), var(--bg-card));
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
        }
        
        .category-title {
            font-size: 1.2rem;
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .category-toggle {
            width: 60px;
            height: 30px;
            background: var(--error);
            border-radius: 15px;
            position: relative;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .category-toggle.enabled {
            background: var(--success);
        }
        
        .category-toggle::after {
            content: '';
            position: absolute;
            top: 3px;
            left: 3px;
            width: 24px;
            height: 24px;
            background: white;
            border-radius: 50%;
            transition: all 0.3s ease;
            box-shadow: 0 2px 5px rgba(0,0,0,0.3);
        }
        
        .category-toggle.enabled::after {
            transform: translateX(30px);
        }
        
        .category-stats {
            padding: 0.5rem 1rem;
            font-size: 0.9rem;
            color: var(--text-secondary);
            display: flex;
            justify-content: space-between;
        }
        
        .sources-list {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease;
        }
        
        .sources-list.expanded {
            max-height: 500px;
        }
        
        .source-item {
            padding: 0.8rem 1rem;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
            transition: all 0.3s ease;
        }
        
        .source-item:hover {
            background: rgba(255, 255, 255, 0.05);
        }
        
        .source-info {
            flex: 1;
        }
        
        .source-name {
            font-weight: bold;
            color: var(--text-primary);
            margin-bottom: 0.2rem;
        }
        
        .source-desc {
            font-size: 0.8rem;
            color: var(--text-secondary);
        }
        
        .source-meta {
            font-size: 0.7rem;
            color: var(--accent);
            margin-top: 0.2rem;
        }
        
        .source-toggle {
            width: 50px;
            height: 25px;
            background: var(--error);
            border-radius: 12px;
            position: relative;
            cursor: pointer;
            transition: all 0.3s ease;
            margin-left: 1rem;
        }
        
        .source-toggle.enabled {
            background: var(--success);
        }
        
        .source-toggle::after {
            content: '';
            position: absolute;
            top: 2px;
            left: 2px;
            width: 21px;
            height: 21px;
            background: white;
            border-radius: 50%;
            transition: all 0.3s ease;
            box-shadow: 0 2px 5px rgba(0,0,0,0.3);
        }
        
        .source-toggle.enabled::after {
            transform: translateX(25px);
        }
        
        .floating-controls {
            position: fixed;
            bottom: 2rem;
            right: 2rem;
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
            z-index: 50;
        }
        
        .floating-btn {
            width: 60px;
            height: 60px;
            background: var(--primary);
            border-radius: 50%;
            border: none;
            color: #000;
            font-size: 1.5rem;
            cursor: pointer;
            box-shadow: 0 4px 20px rgba(255, 107, 53, 0.4);
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .floating-btn:hover {
            transform: scale(1.1);
            box-shadow: 0 8px 32px rgba(255, 107, 53, 0.6);
        }
        
        .modal {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.8);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            backdrop-filter: blur(5px);
        }
        
        .modal.show {
            display: flex;
        }
        
        .modal-content {
            background: var(--bg-primary);
            border: 2px solid var(--primary);
            border-radius: 12px;
            padding: 2rem;
            max-width: 500px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
        }
        
        .modal h3 {
            color: var(--primary);
            margin-bottom: 1rem;
            text-align: center;
        }
        
        .close-btn {
            float: right;
            background: none;
            border: none;
            color: var(--text-primary);
            font-size: 1.5rem;
            cursor: pointer;
            padding: 0.5rem;
        }
        
        .notification {
            position: fixed;
            top: 1rem;
            right: 1rem;
            padding: 1rem 1.5rem;
            background: var(--success);
            color: #000;
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0, 255, 65, 0.3);
            transform: translateX(400px);
            transition: all 0.3s ease;
            z-index: 1001;
        }
        
        .notification.show {
            transform: translateX(0);
        }
        
        .notification.error {
            background: var(--error);
            color: white;
        }
        
        .category-emojis {
            ads: "🚫",
            tracking: "🕵️",
            malware: "🦠", 
            phishing: "🎣",
            social: "📱",
            annoyance: "😤",
            adult: "🔞",
            gambling: "🎰",
            fakenews: "📰",
            cryptomining: "⛏️",
            regional: "🌍",
            comprehensive: "🛡️"
        }
        
        @media (max-width: 768px) {
            .header-content {
                flex-direction: column;
                gap: 1rem;
            }
            
            .container {
                padding: 1rem;
            }
            
            .stats-grid {
                grid-template-columns: 1fr;
            }
            
            .category-grid {
                grid-template-columns: 1fr;
            }
            
            .floating-controls {
                bottom: 1rem;
                right: 1rem;
            }
        }
        
        .glow {
            animation: glow 2s ease-in-out infinite alternate;
        }
        
        @keyframes glow {
            from { box-shadow: 0 0 5px var(--primary), 0 0 10px var(--primary), 0 0 15px var(--primary); }
            to { box-shadow: 0 0 10px var(--primary), 0 0 20px var(--primary), 0 0 30px var(--primary); }
        }
        
        .pulse {
            animation: pulse 1.5s ease-in-out infinite;
        }
        
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }
    </style>
</head>
<body class="theme-cyberpunk">
    <header class="header">
        <div class="header-content">
            <h1 class="fire-gradient">🛡️ NeXuS Blacklist Control Center 🛡️</h1>
            <div class="theme-selector">
                <button class="theme-btn active" onclick="switchTheme('cyberpunk')">🔥 Cyberpunk</button>
                <button class="theme-btn" onclick="switchTheme('matrix')">🟢 Matrix</button>
                <button class="theme-btn" onclick="switchTheme('neon')">💜 Neon</button>
            </div>
        </div>
    </header>

    <div class="container">
        <!-- Statistics Overview -->
        <div class="stats-grid">
            <div class="stat-card glow">
                <div class="stat-value" id="total-sources">0</div>
                <div class="stat-label">📊 Total Sources</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="enabled-sources">0</div>
                <div class="stat-label">✅ Enabled Sources</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="blocked-domains">0</div>
                <div class="stat-label">🚫 Blocked Domains</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="active-categories">0</div>
                <div class="stat-label">🏷️ Active Categories</div>
            </div>
        </div>

        <!-- Preset Configurations -->
        <div class="preset-buttons">
            <button class="preset-btn pulse" onclick="applyPreset('minimal')">
                🛡️ <strong>MINIMAL</strong><br>
                <small>Essential protection only</small>
            </button>
            <button class="preset-btn" onclick="applyPreset('balanced')">
                ⚖️ <strong>BALANCED</strong><br>
                <small>Recommended for most users</small>
            </button>
            <button class="preset-btn" onclick="applyPreset('comprehensive')">
                🔒 <strong>COMPREHENSIVE</strong><br>
                <small>Maximum protection</small>
            </button>
            <button class="preset-btn" onclick="applyPreset('maximum')">
                🚀 <strong>MAXIMUM</strong><br>
                <small>Everything enabled (may break sites)</small>
            </button>
        </div>

        <!-- Category Management -->
        <div id="categories-container" class="category-grid">
            <!-- Categories will be loaded here -->
        </div>
    </div>

    <!-- Floating Controls -->
    <div class="floating-controls">
        <button class="floating-btn" onclick="updateAllFilters()" title="Update All Filters">
            🔄
        </button>
        <button class="floating-btn" onclick="showStats()" title="Show Statistics">
            📊
        </button>
        <button class="floating-btn" onclick="exportConfig()" title="Export Configuration">
            💾
        </button>
    </div>

    <!-- Statistics Modal -->
    <div id="stats-modal" class="modal">
        <div class="modal-content">
            <button class="close-btn" onclick="closeModal('stats-modal')">&times;</button>
            <h3>📊 Detailed Statistics</h3>
            <div id="detailed-stats">
                <!-- Stats will be loaded here -->
            </div>
        </div>
    </div>

    <!-- Notification -->
    <div id="notification" class="notification">
        <span id="notification-text"></span>
    </div>

    <script>
        // Category emoji mapping
        const categoryEmojis = {
            'ads': '🚫',
            'tracking': '🕵️',
            'malware': '🦠',
            'phishing': '🎣',
            'social': '📱',
            'annoyance': '😤',
            'adult': '🔞',
            'gambling': '🎰',
            'fakenews': '📰',
            'cryptomining': '⛏️',
            'regional': '🌍',
            'comprehensive': '🛡️'
        };

        // Global state
        let categories = {};
        let sources = {};

        // Theme switching
        function switchTheme(theme) {
            document.body.className = `theme-${theme}`;
            document.querySelectorAll('.theme-btn').forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');
            showNotification(`🎨 Switched to ${theme} theme`);
        }

        // Load data from API
        async function loadData() {
            try {
                const response = await fetch('/api/blacklist/status');
                const data = await response.json();
                
                categories = data.categories || {};
                sources = data.sources || {};
                
                updateStatistics();
                renderCategories();
            } catch (error) {
                showNotification('❌ Failed to load data', true);
                console.error('Error loading data:', error);
            }
        }

        // Update statistics display
        function updateStatistics() {
            const totalSources = Object.keys(sources).length;
            const enabledSources = Object.values(sources).filter(s => s.enabled).length;
            const blockedDomains = Object.values(sources)
                .filter(s => s.enabled)
                .reduce((sum, s) => sum + (s.estimated_domains || 0), 0);
            const activeCategories = Object.values(categories)
                .filter(c => c.enabled).length;

            document.getElementById('total-sources').textContent = totalSources;
            document.getElementById('enabled-sources').textContent = enabledSources;
            document.getElementById('blocked-domains').textContent = blockedDomains.toLocaleString();
            document.getElementById('active-categories').textContent = activeCategories;
        }

        // Render category cards
        function renderCategories() {
            const container = document.getElementById('categories-container');
            container.innerHTML = '';

            Object.entries(categories).forEach(([categoryName, categoryData]) => {
                const emoji = categoryEmojis[categoryName] || '📁';
                const categoryEnabled = categoryData.enabled || false;
                const categorySources = Object.values(sources).filter(s => s.category === categoryName);
                const enabledCount = categorySources.filter(s => s.enabled).length;

                const card = document.createElement('div');
                card.className = `category-card ${categoryEnabled ? 'enabled' : 'disabled'}`;
                card.innerHTML = `
                    <div class="category-header" onclick="toggleCategoryExpansion('${categoryName}')">
                        <div class="category-title">
                            ${emoji} ${categoryName.toUpperCase()}
                        </div>
                        <div class="category-toggle ${categoryEnabled ? 'enabled' : ''}" 
                             onclick="event.stopPropagation(); toggleCategory('${categoryName}')">
                        </div>
                    </div>
                    <div class="category-stats">
                        <span>📊 ${enabledCount}/${categorySources.length} sources</span>
                        <span>🔢 ~${categorySources.filter(s => s.enabled).reduce((sum, s) => sum + (s.estimated_domains || 0), 0).toLocaleString()} domains</span>
                    </div>
                    <div class="sources-list" id="sources-${categoryName}">
                        ${categorySources.map(source => `
                            <div class="source-item">
                                <div class="source-info">
                                    <div class="source-name">${source.name}</div>
                                    <div class="source-desc">${source.description}</div>
                                    <div class="source-meta">
                                        📅 ${source.update_frequency} • 🔢 ~${(source.estimated_domains || 0).toLocaleString()} domains
                                    </div>
                                </div>
                                <div class="source-toggle ${source.enabled ? 'enabled' : ''}" 
                                     onclick="toggleSource('${source.name}')">
                                </div>
                            </div>
                        `).join('')}
                    </div>
                `;
                container.appendChild(card);
            });
        }

        // Toggle category expansion
        function toggleCategoryExpansion(categoryName) {
            const sourcesList = document.getElementById(`sources-${categoryName}`);
            sourcesList.classList.toggle('expanded');
        }

        // Toggle entire category
        async function toggleCategory(categoryName) {
            try {
                const newState = !categories[categoryName].enabled;
                const response = await fetch('/api/blacklist/category', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ category: categoryName, enabled: newState })
                });

                if (response.ok) {
                    categories[categoryName].enabled = newState;
                    // Update all sources in this category
                    Object.values(sources).forEach(source => {
                        if (source.category === categoryName) {
                            source.enabled = newState;
                        }
                    });
                    renderCategories();
                    updateStatistics();
                    showNotification(`${newState ? '✅' : '❌'} ${categoryName.toUpperCase()} ${newState ? 'enabled' : 'disabled'}`);
                } else {
                    throw new Error('Failed to toggle category');
                }
            } catch (error) {
                showNotification(`❌ Failed to toggle ${categoryName}`, true);
            }
        }

        // Toggle individual source
        async function toggleSource(sourceName) {
            try {
                const source = Object.values(sources).find(s => s.name === sourceName);
                if (!source) return;

                const newState = !source.enabled;
                const response = await fetch('/api/blacklist/source', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ source: sourceName, enabled: newState })
                });

                if (response.ok) {
                    source.enabled = newState;
                    renderCategories();
                    updateStatistics();
                    showNotification(`${newState ? '✅' : '❌'} ${sourceName} ${newState ? 'enabled' : 'disabled'}`);
                } else {
                    throw new Error('Failed to toggle source');
                }
            } catch (error) {
                showNotification(`❌ Failed to toggle ${sourceName}`, true);
            }
        }

        // Apply preset configuration
        async function applyPreset(preset) {
            try {
                const response = await fetch('/api/blacklist/preset', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ preset })
                });

                if (response.ok) {
                    showNotification(`🎯 Applied ${preset.toUpperCase()} preset`);
                    setTimeout(loadData, 1000); // Reload data after preset
                } else {
                    throw new Error('Failed to apply preset');
                }
            } catch (error) {
                showNotification(`❌ Failed to apply ${preset} preset`, true);
            }
        }

        // Update all filters
        async function updateAllFilters() {
            try {
                showNotification('🔄 Updating all filters...');
                const response = await fetch('/api/blacklist/update', { method: 'POST' });
                
                if (response.ok) {
                    showNotification('✅ All filters updated successfully');
                } else {
                    throw new Error('Update failed');
                }
            } catch (error) {
                showNotification('❌ Failed to update filters', true);
            }
        }

        // Show detailed statistics
        async function showStats() {
            try {
                const response = await fetch('/api/blacklist/detailed-stats');
                const stats = await response.json();
                
                document.getElementById('detailed-stats').innerHTML = `
                    <div style="text-align: left;">
                        <h4>📊 Category Breakdown</h4>
                        ${Object.entries(stats.categories || {}).map(([cat, data]) => `
                            <div style="margin: 0.5rem 0; padding: 0.5rem; background: var(--bg-card); border-radius: 4px;">
                                ${categoryEmojis[cat] || '📁'} <strong>${cat.toUpperCase()}</strong><br>
                                <small>Sources: ${data.enabled_sources}/${data.total_sources} • Domains: ~${data.estimated_domains.toLocaleString()}</small>
                            </div>
                        `).join('')}
                        
                        <h4 style="margin-top: 1rem;">🕒 Last Updates</h4>
                        ${Object.values(stats.sources || {}).filter(s => s.last_updated).slice(0, 5).map(source => `
                            <div style="margin: 0.3rem 0; font-size: 0.9rem;">
                                ✅ ${source.name}: ${source.last_updated}
                            </div>
                        `).join('')}
                    </div>
                `;
                
                document.getElementById('stats-modal').classList.add('show');
            } catch (error) {
                showNotification('❌ Failed to load statistics', true);
            }
        }

        // Export configuration
        async function exportConfig() {
            try {
                const response = await fetch('/api/blacklist/export');
                const config = await response.json();
                
                const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `nexus-blacklist-config-${new Date().toISOString().split('T')[0]}.json`;
                a.click();
                URL.revokeObjectURL(url);
                
                showNotification('💾 Configuration exported');
            } catch (error) {
                showNotification('❌ Failed to export configuration', true);
            }
        }

        // Close modal
        function closeModal(modalId) {
            document.getElementById(modalId).classList.remove('show');
        }

        // Show notification
        function showNotification(message, isError = false) {
            const notification = document.getElementById('notification');
            const text = document.getElementById('notification-text');
            
            text.textContent = message;
            notification.className = `notification ${isError ? 'error' : ''} show`;
            
            setTimeout(() => {
                notification.classList.remove('show');
            }, 3000);
        }

        // Initialize on page load
        document.addEventListener('DOMContentLoaded', loadData);
    </script>
</body>
</html>'''

@app.get("/", response_class=HTMLResponse)
async def get_dashboard():
    """Serve the beautiful blacklist management dashboard"""
    return create_beautiful_html()

@app.get("/api/blacklist/status")
async def get_blacklist_status():
    """Get current blacklist status"""
    # Load current configuration
    blacklist_manager.load_sources()
    
    return {
        "categories": blacklist_manager.get_categories_summary(),
        "sources": {name: {
            "name": source.name,
            "url": source.url,
            "category": source.category,
            "description": source.description,
            "update_frequency": source.update_frequency,
            "enabled": source.enabled,
            "estimated_domains": source.estimated_domains,
            "last_updated": source.last_updated,
            "status": source.status
        } for name, source in blacklist_manager.blacklist_sources.items()}
    }

@app.post("/api/blacklist/category")
async def toggle_category(request: Request):
    """Toggle entire category on/off"""
    data = await request.json()
    category = data.get("category")
    enabled = data.get("enabled", False)
    
    if not category:
        raise HTTPException(status_code=400, detail="Category required")
    
    count = blacklist_manager.toggle_category(category, enabled)
    if count > 0:
        return {"success": True, "message": f"Toggled {count} sources in {category}"}
    else:
        raise HTTPException(status_code=404, detail="Category not found")

@app.post("/api/blacklist/source")
async def toggle_source(request: Request):
    """Toggle individual source on/off"""
    data = await request.json()
    source_name = data.get("source")
    enabled = data.get("enabled", False)
    
    if not source_name:
        raise HTTPException(status_code=400, detail="Source name required")
    
    # Find source key by name
    source_key = None
    for key, source in blacklist_manager.blacklist_sources.items():
        if source.name == source_name:
            source_key = key
            break
    
    if source_key and blacklist_manager.toggle_source(source_key, enabled):
        return {"success": True, "message": f"Toggled {source_name}"}
    else:
        raise HTTPException(status_code=404, detail="Source not found")

@app.post("/api/blacklist/preset")
async def apply_preset(request: Request):
    """Apply preset configuration"""
    data = await request.json()
    preset = data.get("preset")
    
    if not preset:
        raise HTTPException(status_code=400, detail="Preset required")
    
    if blacklist_manager.apply_recommendation(preset):
        return {"success": True, "message": f"Applied {preset} preset"}
    else:
        raise HTTPException(status_code=400, detail="Invalid preset")

@app.post("/api/blacklist/update")
async def update_filters():
    """Trigger filter updates"""
    # This would trigger the actual filter update process
    # For now, just return success
    return {"success": True, "message": "Filter update started"}

@app.get("/api/blacklist/detailed-stats")
async def get_detailed_stats():
    """Get detailed statistics"""
    blacklist_manager.load_sources()
    
    return {
        "categories": blacklist_manager.get_categories_summary(),
        "sources": {name: {
            "name": source.name,
            "enabled": source.enabled,
            "last_updated": source.last_updated,
            "estimated_domains": source.estimated_domains,
            "category": source.category
        } for name, source in blacklist_manager.blacklist_sources.items()},
        "total_enabled": len(blacklist_manager.get_enabled_sources()),
        "total_domains": sum(s.estimated_domains for s in blacklist_manager.get_enabled_sources())
    }

@app.get("/api/blacklist/export")
async def export_configuration():
    """Export current configuration"""
    return blacklist_manager.export_configuration()

if __name__ == "__main__":
    print("🛡️ Starting NeXuS Beautiful Blacklist Control Center 🛡️")
    print("🎨 Self-contained interface with multiple themes")
    print("🔥 Cyberpunk • 🟢 Matrix • 💜 Neon themes available")
    print("Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!")
    
    uvicorn.run(
        "nexus-blacklist-web-manager:app",
        host="0.0.0.0",
        port=8445,
        reload=False
    )