#!/usr/bin/env python3
"""
nexus-board.py — NeXuS Self-Contained Forum/Chat/FileShare
Pure Python stdlib. Zero pip installs. Single file.
Usage: python3 nexus-board.py [port]
Sane • Simple • Secure
"""

import http.server
import socketserver
import sqlite3
import json
import os
import sys
import time
import html
import cgi
import io
import threading
import hashlib
import pathlib
from datetime import datetime, timezone
from urllib.parse import urlparse, parse_qs

# ── Config ────────────────────────────────────────────────────────────────────

PORT        = int(sys.argv[1]) if len(sys.argv) > 1 else 8095
DB_PATH     = os.path.join(os.path.dirname(__file__), "nexus-board.db")
UPLOAD_DIR  = os.path.join(os.path.dirname(__file__), "nexus-board-files")
TITLE       = "NeXuS Board"
MAX_UPLOAD  = 50 * 1024 * 1024  # 50 MB
VERSION     = "1.0"

# SSE clients list (thread-safe via lock)
sse_clients = []
sse_lock = threading.Lock()

# ── Database ──────────────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    conn = get_db()
    cur = conn.cursor()

    cur.executescript("""
        CREATE TABLE IF NOT EXISTS threads (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            title     TEXT NOT NULL,
            body      TEXT NOT NULL,
            author    TEXT NOT NULL DEFAULT 'anon',
            created   INTEGER NOT NULL,
            last_post INTEGER NOT NULL,
            post_count INTEGER NOT NULL DEFAULT 1,
            pinned    INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS posts (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            thread_id INTEGER NOT NULL REFERENCES threads(id),
            body      TEXT NOT NULL,
            author    TEXT NOT NULL DEFAULT 'anon',
            created   INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS chat (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            author    TEXT NOT NULL DEFAULT 'anon',
            message   TEXT NOT NULL,
            created   INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS files (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            filename  TEXT NOT NULL,
            orig_name TEXT NOT NULL,
            size      INTEGER NOT NULL,
            mime      TEXT NOT NULL DEFAULT 'application/octet-stream',
            uploader  TEXT NOT NULL DEFAULT 'anon',
            created   INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    """)

    # Default settings
    cur.execute("INSERT OR IGNORE INTO settings VALUES ('title', ?)", (TITLE,))
    conn.commit()
    conn.close()

# ── CSS + HTML helpers ────────────────────────────────────────────────────────

CSS = """
:root{--bg:#1e1e2e;--sf:#2a2a3e;--ac:#89b4fa;--gr:#a6e3a1;--ye:#f9e2af;--re:#f38ba8;--tx:#cdd6f4;--mu:#7f849c;--br:#45475a}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--tx);font-family:'JetBrains Mono','Courier New',monospace;font-size:14px}
a{color:var(--ac);text-decoration:none}a:hover{text-decoration:underline}
.banner{background:var(--sf);border-bottom:2px solid var(--ac);padding:14px 20px;display:flex;align-items:center;gap:16px}
.banner h1{color:var(--ac);font-size:1.2rem;letter-spacing:3px}
.banner .sub{color:var(--mu);font-size:0.78rem}
nav{display:flex;gap:4px;padding:10px 20px;background:var(--sf);border-bottom:1px solid var(--br);flex-wrap:wrap}
nav a{color:var(--tx);padding:5px 12px;border:1px solid var(--br);border-radius:4px;font-size:0.8rem}
nav a:hover,nav a.active{background:var(--ac);color:var(--bg);border-color:var(--ac);text-decoration:none}
.main{max-width:960px;margin:0 auto;padding:20px}
h2{color:var(--ac);font-size:1rem;letter-spacing:2px;border-bottom:1px solid var(--br);padding-bottom:8px;margin-bottom:16px}
h3{color:var(--ye);font-size:0.9rem;margin:12px 0 6px}
.card{background:var(--sf);border:1px solid var(--br);border-radius:6px;padding:16px;margin:8px 0}
.card.highlight{border-color:var(--ac)}
input,textarea,select{background:var(--bg);color:var(--tx);border:1px solid var(--br);border-radius:4px;padding:7px 10px;font-family:inherit;font-size:0.85rem;width:100%}
input:focus,textarea:focus{border-color:var(--ac);outline:none}
textarea{resize:vertical;min-height:80px}
button,.btn{background:var(--ac);color:var(--bg);border:none;padding:8px 18px;border-radius:4px;cursor:pointer;font-family:inherit;font-size:0.83rem;font-weight:bold}
button:hover,.btn:hover{opacity:0.85}
.btn-sm{padding:4px 10px;font-size:0.75rem}
.btn-red{background:var(--re)}
.btn-gr{background:var(--gr)}
.form-row{margin-bottom:12px}
label{display:block;color:var(--mu);font-size:0.78rem;margin-bottom:4px}
table{width:100%;border-collapse:collapse}
th{text-align:left;color:var(--mu);font-size:0.75rem;padding:6px 10px;border-bottom:1px solid var(--br)}
td{padding:8px 10px;border-bottom:1px solid var(--br);font-size:0.83rem;vertical-align:top}
tr:hover td{background:#252535}
.tag{font-size:0.7rem;padding:2px 7px;border-radius:3px;background:var(--br);color:var(--mu)}
.tag.pin{background:var(--ye);color:var(--bg)}
.badge{font-size:0.72rem;padding:2px 6px;border-radius:3px;background:var(--ac);color:var(--bg)}
.meta{color:var(--mu);font-size:0.75rem}
.body-text{line-height:1.7;white-space:pre-wrap;word-break:break-word;font-size:0.85rem}
.chat-log{height:340px;overflow-y:auto;border:1px solid var(--br);border-radius:4px;padding:10px;background:var(--bg);margin-bottom:10px}
.chat-msg{margin:4px 0;font-size:0.83rem}
.chat-msg .author{color:var(--ac);font-weight:bold}
.chat-msg .ts{color:var(--mu);font-size:0.72rem;margin-left:6px}
.chat-form{display:flex;gap:8px}
.chat-form input{flex:1}
#flash{position:fixed;top:16px;right:16px;background:var(--gr);color:var(--bg);padding:10px 18px;border-radius:4px;font-size:0.82rem;display:none;z-index:999}
.upload-area{border:2px dashed var(--br);border-radius:6px;padding:24px;text-align:center;cursor:pointer;margin:10px 0}
.upload-area:hover{border-color:var(--ac)}
.file-row td:first-child{word-break:break-all}
footer{text-align:center;padding:16px;color:var(--mu);font-size:0.72rem;border-top:1px solid var(--br);margin-top:24px}
"""

def page(title, body, active=""):
    db = get_db()
    board_title = db.execute("SELECT value FROM settings WHERE key='title'").fetchone()
    db.close()
    bt = board_title["value"] if board_title else TITLE

    nav_links = [
        ("Forum", "/", "forum"),
        ("Chat", "/chat", "chat"),
        ("Files", "/files", "files"),
        ("Admin", "/admin", "admin"),
    ]
    nav_html = "".join(
        f'<a href="{href}" class="{"active" if active==key else ""}">{label}</a>'
        for label, href, key in nav_links
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} — {html.escape(bt)}</title>
<style>{CSS}</style>
</head>
<body>
<div id="flash"></div>
<div class="banner">
  <div>
    <h1>⚡ {html.escape(bt)}</h1>
    <div class="sub">Forum • Chat • Files — No deps, no tracking</div>
  </div>
</div>
<nav>{nav_html}</nav>
<div class="main">
{body}
</div>
<footer>nexus-board v{VERSION} — python3 stdlib only — <a href="/admin">admin</a></footer>
<script>
function flash(msg){{var f=document.getElementById('flash');f.textContent=msg;f.style.display='block';setTimeout(()=>f.style.display='none',2500)}}
function copy(t){{navigator.clipboard&&navigator.clipboard.writeText(t).then(()=>flash('Copied!'))}}
</script>
</body>
</html>"""

def ts_fmt(ts):
    try:
        return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")
    except Exception:
        return "?"

def short_body(text, limit=200):
    t = text.strip()
    return (t[:limit] + "…") if len(t) > limit else t

# ── Forum views ───────────────────────────────────────────────────────────────

def view_forum_index():
    db = get_db()
    threads = db.execute(
        "SELECT * FROM threads ORDER BY pinned DESC, last_post DESC LIMIT 100"
    ).fetchall()
    db.close()

    rows = ""
    for t in threads:
        pin = '<span class="tag pin">📌 pinned</span>' if t["pinned"] else ""
        rows += f"""<tr>
            <td>{pin} <a href="/post/{t['id']}">{html.escape(t['title'])}</a>
                <div class="meta">{html.escape(t['author'])} · {ts_fmt(t['created'])}</div>
            </td>
            <td class="meta" style="text-align:center">{t['post_count']}</td>
            <td class="meta" style="white-space:nowrap">{ts_fmt(t['last_post'])}</td>
        </tr>"""

    if not rows:
        rows = '<tr><td colspan="3" style="text-align:center;color:var(--mu)">No threads yet. Start one below!</td></tr>'

    body = f"""
<h2>[ FORUM ]</h2>
<div style="text-align:right;margin-bottom:10px">
  <a href="/post/new" class="btn btn-gr">+ New Thread</a>
</div>
<table>
<thead><tr><th>Thread</th><th style="text-align:center">Replies</th><th>Last Post</th></tr></thead>
<tbody>{rows}</tbody>
</table>
"""
    return page(TITLE, body, "forum")

def view_thread(thread_id, flash_msg=""):
    db = get_db()
    t = db.execute("SELECT * FROM threads WHERE id=?", (thread_id,)).fetchone()
    if not t:
        db.close()
        return None

    posts = db.execute(
        "SELECT * FROM posts WHERE thread_id=? ORDER BY created ASC", (thread_id,)
    ).fetchall()
    db.close()

    # OP
    op_html = f"""
<div class="card highlight">
  <div style="display:flex;justify-content:space-between;align-items:baseline">
    <strong>{html.escape(t['author'])}</strong>
    <span class="meta">{ts_fmt(t['created'])}</span>
  </div>
  <div class="body-text" style="margin-top:10px">{html.escape(t['body'])}</div>
</div>"""

    replies_html = ""
    for p in posts:
        replies_html += f"""
<div class="card">
  <div style="display:flex;justify-content:space-between;align-items:baseline">
    <strong>{html.escape(p['author'])}</strong>
    <span class="meta">{ts_fmt(p['created'])}</span>
  </div>
  <div class="body-text" style="margin-top:8px">{html.escape(p['body'])}</div>
</div>"""

    reply_form = f"""
<h3>Reply</h3>
<form method="POST" action="/post/{thread_id}/reply">
  <div class="form-row"><label>Name (optional)</label>
    <input name="author" placeholder="anon" maxlength="50">
  </div>
  <div class="form-row"><label>Message</label>
    <textarea name="body" required placeholder="Write your reply..." rows="5"></textarea>
  </div>
  <button type="submit">Post Reply</button>
</form>"""

    flash_html = f'<div class="card" style="border-color:var(--gr);color:var(--gr)">{html.escape(flash_msg)}</div>' if flash_msg else ""

    body = f"""
<div style="margin-bottom:10px">
  <a href="/">← Back to forum</a>
</div>
<h2>{html.escape(t['title'])}</h2>
{flash_html}
{op_html}
{replies_html}
<div style="margin-top:20px">{reply_form}</div>
"""
    return page(t['title'], body, "forum")

def view_new_thread():
    body = """
<div style="margin-bottom:10px"><a href="/">← Back to forum</a></div>
<h2>[ NEW THREAD ]</h2>
<form method="POST" action="/post/new">
  <div class="form-row"><label>Your name (optional)</label>
    <input name="author" placeholder="anon" maxlength="50">
  </div>
  <div class="form-row"><label>Thread title</label>
    <input name="title" required placeholder="Thread title" maxlength="200">
  </div>
  <div class="form-row"><label>Post</label>
    <textarea name="body" required placeholder="Write your post..." rows="8"></textarea>
  </div>
  <button type="submit">Create Thread</button>
</form>
"""
    return page("New Thread", body, "forum")

# ── Chat views ────────────────────────────────────────────────────────────────

def view_chat():
    db = get_db()
    recent = db.execute(
        "SELECT * FROM chat ORDER BY created DESC LIMIT 50"
    ).fetchall()
    db.close()
    recent = list(reversed(recent))

    msgs_html = ""
    for m in recent:
        msgs_html += (
            f'<div class="chat-msg">'
            f'<span class="author">{html.escape(m["author"])}</span>'
            f'<span class="ts">{ts_fmt(m["created"])}</span>'
            f' {html.escape(m["message"])}</div>'
        )

    body = f"""
<h2>[ LIVE CHAT ]</h2>
<div class="card">
  <div class="chat-log" id="chat-log">{msgs_html}</div>
  <div class="chat-form">
    <input id="chat-name" placeholder="name (anon)" style="max-width:120px" maxlength="30">
    <input id="chat-msg" placeholder="Message..." maxlength="500" autofocus>
    <button onclick="sendMsg()">Send</button>
  </div>
</div>
<p class="meta" style="margin-top:8px">Real-time via Server-Sent Events. No page reload needed.</p>
<script>
var log = document.getElementById('chat-log');
log.scrollTop = log.scrollHeight;

var es = new EventSource('/chat/stream');
es.onmessage = function(e){{
  var d = JSON.parse(e.data);
  var div = document.createElement('div');
  div.className = 'chat-msg';
  div.innerHTML = '<span class="author">'+d.author+'</span>'
    +'<span class="ts">'+d.ts+'</span> '+d.message;
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
}};

function sendMsg(){{
  var name = document.getElementById('chat-name').value.trim()||'anon';
  var msg  = document.getElementById('chat-msg').value.trim();
  if(!msg) return;
  fetch('/chat/send', {{
    method:'POST',
    headers:{{'Content-Type':'application/json'}},
    body: JSON.stringify({{author:name,message:msg}})
  }});
  document.getElementById('chat-msg').value='';
}}

document.getElementById('chat-msg').addEventListener('keydown',function(e){{
  if(e.key==='Enter'&&!e.shiftKey){{e.preventDefault();sendMsg();}}
}});
</script>
"""
    return page("Chat", body, "chat")

# ── File views ────────────────────────────────────────────────────────────────

def view_files():
    db = get_db()
    files = db.execute(
        "SELECT * FROM files ORDER BY created DESC LIMIT 200"
    ).fetchall()
    db.close()

    rows = ""
    for f in files:
        size_str = (
            f"{f['size']/1024/1024:.1f} MB" if f['size'] > 1024*1024
            else f"{f['size']/1024:.1f} KB"
        )
        rows += f"""<tr class="file-row">
            <td><a href="/files/get/{html.escape(f['filename'])}">{html.escape(f['orig_name'])}</a></td>
            <td class="meta">{size_str}</td>
            <td class="meta">{html.escape(f['uploader'])}</td>
            <td class="meta">{ts_fmt(f['created'])}</td>
            <td><a href="/files/get/{html.escape(f['filename'])}" class="btn btn-sm">⬇</a></td>
        </tr>"""

    if not rows:
        rows = '<tr><td colspan="5" style="text-align:center;color:var(--mu)">No files yet</td></tr>'

    body = f"""
<h2>[ FILE SHARE ]</h2>
<div class="upload-area" onclick="document.getElementById('fu').click()"
     ondragover="event.preventDefault();this.style.borderColor='var(--ac)'"
     ondrop="handleDrop(event);this.style.borderColor='var(--br)'">
  <div style="font-size:2rem">📂</div>
  <p>Click to select files, or drag &amp; drop</p>
  <p class="meta">Max {MAX_UPLOAD//1024//1024} MB per file</p>
</div>
<input type="file" id="fu" style="display:none" multiple onchange="uploadFiles(this.files)">
<div id="upload-progress" style="margin:8px 0"></div>

<h3>Shared Files</h3>
<table>
<thead><tr><th>File</th><th>Size</th><th>By</th><th>Date</th><th></th></tr></thead>
<tbody id="file-table">{rows}</tbody>
</table>
<script>
function handleDrop(e){{
  e.preventDefault();
  uploadFiles(e.dataTransfer.files);
}}
function uploadFiles(files){{
  var prog = document.getElementById('upload-progress');
  Array.from(files).forEach(function(f){{
    var fd = new FormData();
    fd.append('file', f);
    fd.append('uploader', prompt('Your name (leave blank for anon)','') || 'anon');
    prog.textContent = 'Uploading ' + f.name + '...';
    fetch('/files/upload',{{method:'POST',body:fd}})
      .then(r=>r.json())
      .then(function(d){{
        if(d.ok) {{ prog.textContent=''; location.reload(); }}
        else prog.textContent='Error: '+d.error;
      }}).catch(function(e){{prog.textContent='Upload failed'}});
  }});
}}
</script>
"""
    return page("Files", body, "files")

# ── Admin view ────────────────────────────────────────────────────────────────

def view_admin(msg=""):
    db = get_db()
    thread_count = db.execute("SELECT COUNT(*) FROM threads").fetchone()[0]
    post_count   = db.execute("SELECT COUNT(*) FROM posts").fetchone()[0]
    chat_count   = db.execute("SELECT COUNT(*) FROM chat").fetchone()[0]
    file_count   = db.execute("SELECT COUNT(*) FROM files").fetchone()[0]
    title_val    = db.execute("SELECT value FROM settings WHERE key='title'").fetchone()
    db.close()

    cur_title = title_val["value"] if title_val else TITLE
    msg_html = f'<div class="card" style="border-color:var(--gr);color:var(--gr);margin-bottom:12px">{html.escape(msg)}</div>' if msg else ""

    body = f"""
<h2>[ ADMIN ]</h2>
{msg_html}
<div class="card">
  <h3>Stats</h3>
  <table>
    <tr><td>Threads</td><td>{thread_count}</td></tr>
    <tr><td>Posts</td><td>{post_count}</td></tr>
    <tr><td>Chat messages</td><td>{chat_count}</td></tr>
    <tr><td>Files</td><td>{file_count}</td></tr>
    <tr><td>DB path</td><td><code>{html.escape(DB_PATH)}</code></td></tr>
    <tr><td>Files dir</td><td><code>{html.escape(UPLOAD_DIR)}</code></td></tr>
  </table>
</div>

<div class="card">
  <h3>Board Title</h3>
  <form method="POST" action="/admin/set-title">
    <div class="form-row"><input name="title" value="{html.escape(cur_title)}" maxlength="100"></div>
    <button type="submit">Update Title</button>
  </form>
</div>

<div class="card" style="border-color:var(--re)">
  <h3>Danger Zone</h3>
  <div style="display:flex;gap:10px;flex-wrap:wrap;margin-top:8px">
    <form method="POST" action="/admin/wipe-chat"
          onsubmit="return confirm('Delete all chat messages?')">
      <button type="submit" class="btn btn-red">Wipe Chat</button>
    </form>
    <form method="POST" action="/admin/wipe-files"
          onsubmit="return confirm('Delete all files?')">
      <button type="submit" class="btn btn-red">Wipe Files</button>
    </form>
    <form method="POST" action="/admin/wipe-all"
          onsubmit="return confirm('DELETE ALL DATA? This cannot be undone.')">
      <button type="submit" class="btn btn-red">Wipe Everything</button>
    </form>
  </div>
</div>
"""
    return page("Admin", body, "admin")

# ── SSE broadcast ─────────────────────────────────────────────────────────────

def broadcast_chat(payload_dict):
    data = json.dumps(payload_dict)
    msg = f"data: {data}\n\n".encode()
    dead = []
    with sse_lock:
        for q in sse_clients:
            try:
                q.put(msg)
            except Exception:
                dead.append(q)
        for q in dead:
            try: sse_clients.remove(q)
            except ValueError: pass

# ── Request handler ───────────────────────────────────────────────────────────

class NexusBoard(http.server.BaseHTTPRequestHandler):
    server_version = f"nexus-board/{VERSION}"
    error_message_format = "Error %(code)d: %(message)s"

    def log_message(self, fmt, *args):
        pass  # Suppress stdout logs for privacy

    def send_html(self, content, code=200):
        body = content.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def redirect(self, url):
        self.send_response(303)
        self.send_header("Location", url)
        self.end_headers()

    def parse_form(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        from urllib.parse import parse_qs
        data = {}
        for k, v in parse_qs(raw.decode("utf-8", errors="replace")).items():
            data[k] = v[0] if v else ""
        return data

    def parse_multipart(self):
        """Return (fields_dict, files_dict). files_dict values are (filename, data)."""
        ct = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in ct:
            return {}, {}

        boundary = None
        for part in ct.split(";"):
            part = part.strip()
            if part.startswith("boundary="):
                boundary = part[9:].strip('"').encode()
                break
        if not boundary:
            return {}, {}

        length = int(self.headers.get("Content-Length", 0))
        if length > MAX_UPLOAD + 1024:
            return {}, {}

        raw = self.rfile.read(length)
        fields = {}
        file_data = {}

        for section in raw.split(b"--" + boundary):
            if not section.startswith(b"\r\n") and not section.startswith(b" "):
                continue
            if b"\r\n\r\n" not in section:
                continue
            header_part, body_part = section.split(b"\r\n\r\n", 1)
            body_part = body_part.rstrip(b"\r\n")
            headers_raw = header_part.decode("utf-8", errors="replace")

            name = None
            filename = None
            for line in headers_raw.split("\r\n"):
                if "Content-Disposition:" in line:
                    for item in line.split(";"):
                        item = item.strip()
                        if item.startswith("name="):
                            name = item[5:].strip('"')
                        elif item.startswith("filename="):
                            filename = item[9:].strip('"')

            if name is None:
                continue
            if filename is not None:
                file_data[name] = (filename, body_part)
            else:
                fields[name] = body_part.decode("utf-8", errors="replace")

        return fields, file_data

    # ── GET handler ───────────────────────────────────────────────────────────

    def do_GET(self):
        parsed = urlparse(self.path)
        path   = parsed.path.rstrip("/") or "/"
        qs     = parse_qs(parsed.query)

        # Forum index
        if path == "/":
            self.send_html(view_forum_index())
            return

        # New thread form
        if path == "/post/new":
            self.send_html(view_new_thread())
            return

        # Thread view
        if path.startswith("/post/") and path[6:].isdigit():
            tid = int(path[6:])
            flash = qs.get("flash", [""])[0]
            result = view_thread(tid, flash)
            if result:
                self.send_html(result)
            else:
                self.send_html("<h1>Not found</h1>", 404)
            return

        # Chat
        if path == "/chat":
            self.send_html(view_chat())
            return

        # Chat SSE stream
        if path == "/chat/stream":
            self._sse_stream()
            return

        # Files list
        if path == "/files":
            self.send_html(view_files())
            return

        # File download
        if path.startswith("/files/get/"):
            fname = path[11:]
            self._serve_file(fname)
            return

        # Admin
        if path == "/admin":
            self.send_html(view_admin())
            return

        self.send_html("<h1>Not found</h1>", 404)

    # ── POST handler ──────────────────────────────────────────────────────────

    def do_POST(self):
        parsed = urlparse(self.path)
        path   = parsed.path.rstrip("/")

        # New thread
        if path == "/post/new":
            form = self.parse_form()
            title  = form.get("title", "").strip()[:200]
            body   = form.get("body",  "").strip()[:10000]
            author = (form.get("author", "").strip() or "anon")[:50]
            if title and body:
                now = int(time.time())
                db = get_db()
                cur = db.execute(
                    "INSERT INTO threads(title,body,author,created,last_post) VALUES(?,?,?,?,?)",
                    (title, body, author, now, now)
                )
                db.commit()
                tid = cur.lastrowid
                db.close()
                self.redirect(f"/post/{tid}")
            else:
                self.redirect("/post/new")
            return

        # Reply to thread
        if path.startswith("/post/") and path.endswith("/reply"):
            parts = path.split("/")
            try:
                tid = int(parts[2])
            except (IndexError, ValueError):
                self.redirect("/")
                return
            form   = self.parse_form()
            body   = form.get("body",   "").strip()[:10000]
            author = (form.get("author", "").strip() or "anon")[:50]
            if body:
                now = int(time.time())
                db = get_db()
                db.execute(
                    "INSERT INTO posts(thread_id,body,author,created) VALUES(?,?,?,?)",
                    (tid, body, author, now)
                )
                db.execute(
                    "UPDATE threads SET last_post=?, post_count=post_count+1 WHERE id=?",
                    (now, tid)
                )
                db.commit()
                db.close()
                self.redirect(f"/post/{tid}?flash=Reply+posted")
            else:
                self.redirect(f"/post/{tid}")
            return

        # Chat send
        if path == "/chat/send":
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(min(length, 2048))
            try:
                data = json.loads(raw)
                message = str(data.get("message", "")).strip()[:500]
                author  = str(data.get("author",  "anon")).strip()[:30] or "anon"
            except Exception:
                self.send_json({"ok": False}, 400)
                return
            if message:
                now = int(time.time())
                db = get_db()
                db.execute(
                    "INSERT INTO chat(author,message,created) VALUES(?,?,?)",
                    (author, message, now)
                )
                db.commit()
                db.close()
                broadcast_chat({
                    "author": html.escape(author),
                    "message": html.escape(message),
                    "ts": ts_fmt(now)
                })
                self.send_json({"ok": True})
            else:
                self.send_json({"ok": False})
            return

        # File upload
        if path == "/files/upload":
            fields, files = self.parse_multipart()
            if "file" in files:
                orig_name, data = files["file"]
                orig_name = os.path.basename(orig_name.replace("\\", "/"))
                if not orig_name:
                    self.send_json({"ok": False, "error": "No filename"})
                    return
                if len(data) > MAX_UPLOAD:
                    self.send_json({"ok": False, "error": "File too large"})
                    return
                # Safe filename: hash-prefixed
                h = hashlib.sha1(data).hexdigest()[:10]
                ext = pathlib.Path(orig_name).suffix[:20]
                safe_name = f"{h}{ext}"
                dest = os.path.join(UPLOAD_DIR, safe_name)
                with open(dest, "wb") as f:
                    f.write(data)
                uploader = fields.get("uploader", "anon").strip()[:50] or "anon"
                mime = self.headers.get("Content-Type", "application/octet-stream").split(";")[0]
                now = int(time.time())
                db = get_db()
                db.execute(
                    "INSERT INTO files(filename,orig_name,size,mime,uploader,created) VALUES(?,?,?,?,?,?)",
                    (safe_name, orig_name, len(data), mime, uploader, now)
                )
                db.commit()
                db.close()
                self.send_json({"ok": True, "name": safe_name})
            else:
                self.send_json({"ok": False, "error": "No file in request"})
            return

        # Admin actions
        if path == "/admin/set-title":
            form = self.parse_form()
            t = form.get("title", "").strip()[:100]
            if t:
                db = get_db()
                db.execute("INSERT OR REPLACE INTO settings VALUES('title',?)", (t,))
                db.commit()
                db.close()
            self.redirect("/admin")
            return

        if path == "/admin/wipe-chat":
            db = get_db()
            db.execute("DELETE FROM chat")
            db.commit()
            db.close()
            self.redirect("/admin")
            return

        if path == "/admin/wipe-files":
            db = get_db()
            files = db.execute("SELECT filename FROM files").fetchall()
            for f in files:
                fp = os.path.join(UPLOAD_DIR, f["filename"])
                try: os.remove(fp)
                except Exception: pass
            db.execute("DELETE FROM files")
            db.commit()
            db.close()
            self.redirect("/admin")
            return

        if path == "/admin/wipe-all":
            db = get_db()
            files = db.execute("SELECT filename FROM files").fetchall()
            for f in files:
                fp = os.path.join(UPLOAD_DIR, f["filename"])
                try: os.remove(fp)
                except Exception: pass
            db.executescript(
                "DELETE FROM threads; DELETE FROM posts; DELETE FROM chat; DELETE FROM files;"
            )
            db.commit()
            db.close()
            self.redirect("/admin")
            return

        self.send_html("<h1>Not found</h1>", 404)

    # ── SSE stream ────────────────────────────────────────────────────────────

    def _sse_stream(self):
        import queue as Q
        q = Q.Queue()
        with sse_lock:
            sse_clients.append(q)

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()

        try:
            while True:
                try:
                    msg = q.get(timeout=25)
                    self.wfile.write(msg)
                    self.wfile.flush()
                except Q.Empty:
                    # Keepalive ping
                    self.wfile.write(b": ping\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            with sse_lock:
                try: sse_clients.remove(q)
                except ValueError: pass

    # ── File download ─────────────────────────────────────────────────────────

    def _serve_file(self, fname):
        # Only serve filenames that match hash pattern (safe)
        if not all(c in "0123456789abcdefghijklmnopqrstuvwxyz.-_" for c in fname):
            self.send_html("<h1>Forbidden</h1>", 403)
            return

        db = get_db()
        row = db.execute("SELECT * FROM files WHERE filename=?", (fname,)).fetchone()
        db.close()

        if not row:
            self.send_html("<h1>Not found</h1>", 404)
            return

        fpath = os.path.join(UPLOAD_DIR, fname)
        if not os.path.exists(fpath):
            self.send_html("<h1>File missing</h1>", 404)
            return

        size = os.path.getsize(fpath)
        safe_name = row["orig_name"].replace('"', "")

        self.send_response(200)
        self.send_header("Content-Type", row["mime"])
        self.send_header("Content-Length", size)
        self.send_header(
            "Content-Disposition",
            f'attachment; filename="{safe_name}"'
        )
        self.end_headers()

        with open(fpath, "rb") as f:
            while chunk := f.read(65536):
                self.wfile.write(chunk)

# ── ThreadedHTTPServer ────────────────────────────────────────────────────────

class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    init_db()

    server = ThreadedServer(("0.0.0.0", PORT), NexusBoard)

    print(f"""
  ╔═══════════════════════════════════════════════╗
  ║  ⚡ nexus-board v{VERSION}                        ║
  ║  Forum • Chat • FileShare                     ║
  ║  python3 stdlib only — zero deps              ║
  ╚═══════════════════════════════════════════════╝

  Forum:   http://127.0.0.1:{PORT}/
  Chat:    http://127.0.0.1:{PORT}/chat
  Files:   http://127.0.0.1:{PORT}/files
  Admin:   http://127.0.0.1:{PORT}/admin
  DB:      {DB_PATH}

  Press Ctrl+C to stop
""")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  Stopping nexus-board...")
        server.shutdown()

if __name__ == "__main__":
    main()
