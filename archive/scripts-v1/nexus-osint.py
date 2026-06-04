#!/usr/bin/env python3
"""
nexus-osint.py — NeXuS Person Search
Sane * Simple * Secure

Searches public records for an individual and generates a markdown report.
All traffic routes through medusa-proxy (HTTP :8888) → Tor.

Usage:
    python3 nexus-osint.py --name "Vincent Fitzgerald Gibson" --state WV
    python3 nexus-osint.py --name "James Belknap" --state WV --age 55
    python3 nexus-osint.py --name "Frank Gibson" --state WV --county "Randolph County"

Options:
    --name      Full name (required)
    --state     US state abbreviation (default: WV)
    --county    County name (optional, narrows results)
    --age       Approximate age (optional)
    --age-range Age range e.g. 50-60 (optional)
    --aka       Known aliases, comma separated
    --out       Output file (default: ~/claude/brainstorming/<name>-osint.md)
    --proxy     HTTP proxy (default: http://127.0.0.1:8888)
    --no-proxy  Disable proxy (NOT recommended)
"""

import sys
import re
import os
import time
import random
import argparse
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime
from pathlib import Path


# ── Config ────────────────────────────────────────────────────
DEFAULT_PROXY = "http://127.0.0.1:8888"
UA = "Mozilla/5.0 (X11; Linux x86_64; rv:115.0) Gecko/20100101 Firefox/115.0"
DELAY_MIN = 1.5   # seconds between requests (low & slow)
DELAY_MAX = 3.5

# ── Colors ────────────────────────────────────────────────────
GRN  = "\033[0;32m"
YEL  = "\033[1;33m"
CYN  = "\033[0;36m"
RED  = "\033[0;31m"
DIM  = "\033[2m"
NC   = "\033[0m"

def ok(msg):   print(f"{GRN}[  ok ]{NC} {msg}")
def info(msg): print(f"{CYN}[nexus]{NC} {msg}")
def warn(msg): print(f"{YEL}[ warn]{NC} {msg}")
def err(msg):  print(f"{RED}[error]{NC} {msg}")


# ── HTTP ──────────────────────────────────────────────────────
def fetch(url, proxy=DEFAULT_PROXY, timeout=20):
    """Fetch URL through proxy, return text or None."""
    try:
        if proxy:
            proxy_handler = urllib.request.ProxyHandler({
                "http": proxy, "https": proxy
            })
            opener = urllib.request.build_opener(proxy_handler)
        else:
            opener = urllib.request.build_opener()

        req = urllib.request.Request(url, headers={"User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "en-US,en;q=0.9"})
        with opener.open(req, timeout=timeout) as r:
            return r.read().decode("utf-8", errors="replace")
    except Exception as e:
        warn(f"Fetch failed: {url[:60]}… ({e})")
        return None


def strip_html(html):
    """Strip HTML tags and clean whitespace."""
    if not html:
        return ""
    html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
    html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL)
    html = re.sub(r'<[^>]+>', ' ', html)
    html = re.sub(r'&amp;', '&', html)
    html = re.sub(r'&quot;', '"', html)
    html = re.sub(r'&#x27;', "'", html)
    html = re.sub(r'&[a-z]+;', ' ', html)
    html = re.sub(r'\s+', ' ', html)
    return html.strip()


def ddg_search(query, proxy=DEFAULT_PROXY):
    """Search DuckDuckGo HTML, return stripped text."""
    url = f"https://html.duckduckgo.com/html/?q={urllib.parse.quote(query)}"
    info(f"DDG: {query[:70]}")
    html = fetch(url, proxy)
    time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))
    return strip_html(html) if html else ""


def extract_snippets(text, keywords):
    """Extract sentences/fragments containing any keyword."""
    results = []
    for sentence in re.split(r'[.\n]', text):
        s = sentence.strip()
        if len(s) < 15:
            continue
        if any(kw.lower() in s.lower() for kw in keywords):
            results.append(s)
    return results


# ── Search Modules ────────────────────────────────────────────

def search_ddg_general(name, state, county, proxy):
    """General name + state DDG search."""
    results = {}
    queries = [
        f'"{name}" "{state}" OR "{state.lower()}"',
        f'"{name}" "{county}"' if county else f'"{name}" "West Virginia"',
        f'"{name}" {state} arrest OR mugshot OR booked',
        f'"{name}" {state} obituary OR "passed away" OR "survived by"',
    ]
    keywords = name.split() + [state, county or "", "arrest", "charge",
                                "born", "age", "dob", "obituary", "jail"]
    all_snippets = []
    for q in queries:
        text = ddg_search(q, proxy)
        snippets = extract_snippets(text, keywords)
        all_snippets.extend(snippets)

    # Deduplicate
    seen = set()
    unique = []
    for s in all_snippets:
        key = s[:60].lower()
        if key not in seen:
            seen.add(key)
            unique.append(s)

    results["general"] = unique
    return results


def search_arrest_records(name, state, proxy):
    """Search arrest/booking databases."""
    results = []
    first, *rest = name.split()
    last = rest[-1] if rest else ""
    name_q = urllib.parse.quote(name)

    sources = [
        f"https://html.duckduckgo.com/html/?q={name_q}+{state}+mugshot+OR+booked+OR+arrested+site:bustednewspaper.com",
        f"https://html.duckduckgo.com/html/?q={name_q}+{state}+inmate+OR+%22criminal+record%22+OR+convicted",
        f"https://html.duckduckgo.com/html/?q={name_q}+site:mugshots.com",
    ]

    keywords = name.split() + ["arrest", "charge", "booked", "convicted",
                                "felony", "misdemeanor", "jail", "prison",
                                "sentenced", "dob", "age", state.lower()]
    for url in sources:
        info(f"Arrest search: {url[50:90]}…")
        html = fetch(url, proxy)
        time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))
        if html:
            text = strip_html(html)
            snippets = extract_snippets(text, keywords)
            results.extend(snippets)

    # Deduplicate
    seen = set()
    unique = []
    for s in results:
        key = s[:60].lower()
        if key not in seen:
            seen.add(key)
            unique.append(s)
    return unique


def search_wv_doc(name, proxy):
    """Check WV Division of Corrections offender search."""
    first, *rest = name.split()
    last = rest[-1] if rest else ""
    url = f"https://dcr.wv.gov/offendersearch/Pages/default.aspx"
    info("Checking WV DCR offender search…")
    html = fetch(url, proxy)
    time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))
    # WV DCR is a form — try DDG instead
    q = f'"{name}" site:dcr.wv.gov OR site:apps.wv.gov'
    text = ddg_search(q, proxy)
    keywords = name.split() + ["inmate", "offender", "wv doc", "wvdoc", "correction"]
    return extract_snippets(text, keywords)


def search_obituary(name, state, county, proxy):
    """Search obituaries and Find A Grave."""
    results = []
    county_str = county or ""
    queries = [
        f'"{name}" obituary {state}',
        f'"{name}" "passed away" {county_str} {state}',
        f'"{name}" site:findagrave.com {state}',
        f'"{name}" site:legacy.com {state}',
    ]
    keywords = name.split() + ["born", "passed", "survived", "obituary",
                                "memorial", "grave", state.lower(), county_str.lower()]
    for q in queries:
        text = ddg_search(q, proxy)
        snippets = extract_snippets(text, keywords)
        results.extend(snippets)

    seen = set()
    unique = []
    for s in results:
        key = s[:60].lower()
        if key not in seen:
            seen.add(key)
            unique.append(s)
    return unique


def search_social_and_associates(name, state, proxy):
    """Search for social media presence and known associates."""
    results = []
    queries = [
        f'"{name}" Facebook {state}',
        f'"{name}" {state} family OR relatives OR spouse OR wife OR husband OR children',
        f'"{name}" {state} address OR phone OR "zip code"',
    ]
    keywords = name.split() + ["facebook", "family", "relative", "spouse",
                                "wife", "husband", "son", "daughter", "address",
                                "phone", "lives", "age", state.lower()]
    for q in queries:
        text = ddg_search(q, proxy)
        snippets = extract_snippets(text, keywords)
        results.extend(snippets)

    seen = set()
    unique = []
    for s in results:
        key = s[:60].lower()
        if key not in seen:
            seen.add(key)
            unique.append(s)
    return unique


def verify_tor(proxy):
    """Confirm we're going through Tor before searching."""
    info("Verifying Tor exit…")
    html = fetch("https://check.torproject.org/api/ip", proxy)
    if html and "IsTor" in html:
        m = re.search(r'"IP":"([^"]+)"', html)
        ip = m.group(1) if m else "unknown"
        is_tor = '"IsTor":true' in html
        if is_tor:
            ok(f"Tor confirmed — exit IP: {ip}")
            return ip
        else:
            warn(f"NOT going through Tor! IP: {ip}")
            return None
    warn("Could not verify Tor status")
    return None


# ── Report Generator ──────────────────────────────────────────

def generate_report(name, state, county, age, aka, findings, tor_ip):
    """Build markdown report from findings."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = []

    lines.append(f"# OSINT Report: {name}")
    lines.append(f"*Generated: {now} | Tor exit: {tor_ip or 'unverified'} | Via nexus-osint.py*")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Subject")
    lines.append(f"- **Name:** {name}")
    if aka:
        lines.append(f"- **AKA:** {aka}")
    if age:
        lines.append(f"- **Age (approx):** {age}")
    lines.append(f"- **State:** {state}")
    if county:
        lines.append(f"- **County:** {county}")
    lines.append("")

    sections = [
        ("General Records", "general"),
        ("Arrest / Criminal Records", "arrests"),
        ("WV DOC / Corrections", "wv_doc"),
        ("Obituary / Death Records", "obituary"),
        ("Associates / Social", "social"),
    ]

    for title, key in sections:
        items = findings.get(key, [])
        lines.append(f"## {title}")
        if items:
            lines.append("")
            for item in items[:20]:  # cap at 20 per section
                clean = item.strip()
                if clean:
                    lines.append(f"- {clean}")
        else:
            lines.append("- No results found")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Search Notes")
    lines.append(f"- All searches routed through HTTP proxy → medusa-proxy → Tor")
    lines.append(f"- Sources: DuckDuckGo HTML, BustedNewspaper, mugshots.com, WV DCR, FindAGrave, Legacy.com")
    lines.append(f"- Low & slow: {DELAY_MIN}-{DELAY_MAX}s delay between requests")
    lines.append("")

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="NeXuS OSINT — Person Search")
    parser.add_argument("--name",      required=True, help="Full name to search")
    parser.add_argument("--state",     default="WV",  help="State abbreviation")
    parser.add_argument("--county",    default="",    help="County name")
    parser.add_argument("--age",       default="",    help="Approximate age or range (e.g. 55 or 50-60)")
    parser.add_argument("--aka",       default="",    help="Known aliases, comma separated")
    parser.add_argument("--out",       default="",    help="Output file path")
    parser.add_argument("--proxy",     default=DEFAULT_PROXY, help="HTTP proxy URL")
    parser.add_argument("--no-proxy",  action="store_true",   help="Disable proxy (NOT recommended)")
    args = parser.parse_args()

    proxy = None if args.no_proxy else args.proxy

    print()
    print(f"  {CYN}🔍 NeXuS OSINT — Person Search{NC}")
    print(f"  {DIM}Sane • Simple • Secure • Low & Slow{NC}")
    print()

    # Verify Tor
    if proxy:
        tor_ip = verify_tor(proxy)
        if not tor_ip and not args.no_proxy:
            warn("Proceeding without Tor confirmation — traffic may not be anonymous!")
    else:
        tor_ip = None
        warn("Proxy disabled — searches are NOT anonymous!")

    print()
    info(f"Target: {args.name} | State: {args.state} | County: {args.county or 'any'}")
    print()

    # Run searches
    findings = {}

    info("--- General records ---")
    gen = search_ddg_general(args.name, args.state, args.county, proxy)
    findings["general"] = gen.get("general", [])

    info("--- Arrest records ---")
    findings["arrests"] = search_arrest_records(args.name, args.state, proxy)

    info("--- WV DOC ---")
    findings["wv_doc"] = search_wv_doc(args.name, proxy)

    info("--- Obituaries ---")
    findings["obituary"] = search_obituary(args.name, args.state, args.county, proxy)

    info("--- Associates / Social ---")
    findings["social"] = search_social_and_associates(args.name, args.state, proxy)

    # Totals
    total = sum(len(v) for v in findings.values())
    print()
    ok(f"Search complete — {total} results across {len(findings)} categories")

    # Generate report
    report = generate_report(
        name=args.name,
        state=args.state,
        county=args.county,
        age=args.age,
        aka=args.aka,
        findings=findings,
        tor_ip=tor_ip
    )

    # Save
    if args.out:
        out_path = Path(args.out)
    else:
        safe_name = re.sub(r'[^a-z0-9]+', '-', args.name.lower()).strip('-')
        out_path = Path.home() / "claude" / "brainstorming" / f"{safe_name}-osint.md"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(report)
    ok(f"Report saved: {out_path}")

    # Print summary to terminal
    print()
    print(f"  {CYN}── Quick Summary ──────────────────────────────{NC}")
    for section, items in findings.items():
        count = len(items)
        bar = GRN if count > 0 else DIM
        print(f"  {bar}{section:<25}{NC}  {count} result(s)")
    print()


if __name__ == "__main__":
    main()
