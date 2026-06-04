#!/usr/bin/env python3
"""
NeXuS HTTP to HTTPS Redirect Server
Transparent redirection for secure connections
Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!
"""

from fastapi import FastAPI, Request
from fastapi.responses import RedirectResponse
import uvicorn
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nexus-redirect")

app = FastAPI(title="NeXuS HTTPS Redirect", version="1.0.0")

@app.middleware("http")
async def redirect_to_https(request: Request, call_next):
    """Redirect all HTTP requests to HTTPS"""
    # Get the host from the request
    host = request.headers.get("host", "localhost")
    
    # Remove port if present and add HTTPS port
    if ":" in host:
        host = host.split(":")[0]
    
    # Redirect to HTTPS version
    https_url = f"https://{host}:8443{request.url.path}"
    if request.url.query:
        https_url += f"?{request.url.query}"
    
    logger.info(f"🔄 Redirecting {request.url} → {https_url}")
    return RedirectResponse(url=https_url, status_code=301)

@app.get("/")
async def root():
    """This should never be reached due to middleware redirect"""
    return RedirectResponse(url="https://localhost:8443", status_code=301)

if __name__ == "__main__":
    print("🔄 NeXuS HTTP → HTTPS Redirect Server")
    print("🌐 HTTP: http://localhost:8080 → https://localhost:8443")
    print("Sane • Simple • Secure NeXuS - Because everyone together achieves MORE!")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        access_log=True
    )