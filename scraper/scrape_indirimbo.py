#!/usr/bin/env python3
"""
Indirimbo Hymnbook Scraper
===========================
Scrapes all hymns from indirimbo.com (Gushimisha + Agakiza)
and exports them as structured JSON files.

Uses Playwright for browser automation since the site
blocks plain HTTP requests (returns 406).

Usage:
    python scrape_indirimbo.py [--book gushimisha|agakiza|all] [--delay 1.5]
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from datetime import datetime

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    print("❌ Playwright is not installed. Run:")
    print("   pip install playwright")
    print("   playwright install chromium")
    sys.exit(1)


# ─── Configuration ───────────────────────────────────────────────────────────

BASE_URL = "https://indirimbo.com"
BOOKS = {
    "gushimisha": {
        "listing_url": f"{BASE_URL}/gushimisha",
        "max_pages": 15,  # we'll auto-detect, but cap here
        "book_label": "Gushimisha",
    },
    "agakiza": {
        "listing_url": f"{BASE_URL}/agakiza",
        "max_pages": 5,
        "book_label": "Agakiza",
    },
}

OUTPUT_DIR = Path(__file__).parent / "output"


# ─── Helpers ─────────────────────────────────────────────────────────────────

def slugify_number(num: int) -> str:
    """Zero-pad a number to 3 digits: 1 -> '001'."""
    return str(num).zfill(3)


def clean_text(text: str) -> str:
    """Clean up whitespace artifacts from scraped text."""
    if not text:
        return ""
    # Normalize unicode whitespace
    text = text.replace("\xa0", " ")
    # Strip trailing/leading whitespace per line
    lines = [line.strip() for line in text.split("\n")]
    # Remove empty lines at start/end
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines)


# ─── Scraping Functions ─────────────────────────────────────────────────────

def collect_hymn_links(page, book_key: str, delay: float) -> list[dict]:
    """
    Visit all listing pages for a book and collect hymn links.
    Returns a list of dicts: { url, slug, uuid }
    """
    config = BOOKS[book_key]
    listing_url = config["listing_url"]
    all_links = []
    seen_urls = set()

    page_num = 1
    while page_num <= config["max_pages"]:
        url = f"{listing_url}?page={page_num}" if page_num > 1 else listing_url
        print(f"  📄 Listing page {page_num}: {url}")

        try:
            page.goto(url, wait_until="domcontentloaded", timeout=30000)
            page.wait_for_timeout(1500)  # Let JS render
        except PlaywrightTimeout:
            print(f"  ⚠️  Timeout on page {page_num}, retrying...")
            try:
                page.goto(url, wait_until="domcontentloaded", timeout=45000)
                page.wait_for_timeout(2000)
            except PlaywrightTimeout:
                print(f"  ❌ Failed to load page {page_num}, stopping.")
                break

        # Extract hymn links from the page using JavaScript
        links = page.evaluate("""
            () => {
                const results = [];
                // Find all links that point to individual hymn pages
                const anchors = document.querySelectorAll('a[href]');
                for (const a of anchors) {
                    const href = a.href;
                    // Match hymn detail page URLs
                    // Patterns: /gushimisha/{slug}/{uuid}
                    //           /indirimbo-zo-gushimisha/{slug}/{uuid}
                    //           /indirimbo-z'agakiza/{slug}/{uuid}
                    //           /agakiza/{slug}/{uuid}
                    const match = href.match(/indirimbo\\.com\\/(?:indirimbo-zo-gushimisha|indirimbo-z(?:'|%27)agakiza|gushimisha|agakiza)\\/([^\\/]+)\\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{2,4}-[0-9a-f]{4}-[0-9a-f]{12})/i);
                    if (match) {
                        results.push({
                            url: href,
                            slug: match[1],
                            uuid: match[2]
                        });
                    }
                }
                return results;
            }
        """)

        new_count = 0
        for link in links:
            if link["url"] not in seen_urls:
                seen_urls.add(link["url"])
                all_links.append(link)
                new_count += 1

        print(f"    Found {len(links)} links ({new_count} new)")

        if new_count == 0:
            # No new links on this page → we've gone past the last page
            print(f"  ✅ No new hymns on page {page_num}, done with listing.")
            break

        page_num += 1
        time.sleep(delay)

    print(f"  📊 Total unique hymn links for {book_key}: {len(all_links)}")
    return all_links


def scrape_hymn_page(page, hymn_url: str, book_label: str) -> dict | None:
    """
    Visit a single hymn page and extract all structured data.
    Returns a hymn dict or None on failure.
    """
    try:
        page.goto(hymn_url, wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(1500)
    except PlaywrightTimeout:
        print(f"    ⚠️  Timeout, retrying: {hymn_url}")
        try:
            page.goto(hymn_url, wait_until="domcontentloaded", timeout=45000)
            page.wait_for_timeout(2000)
        except PlaywrightTimeout:
            print(f"    ❌ Failed to load: {hymn_url}")
            return None

    # Extract all data using a single JS evaluation for speed
    data = page.evaluate("""
        () => {
            const result = {
                title: '',
                number: null,
                category: '',
                lyrics: []
            };

            // ── Helper: extract text lines from an element, splitting on <br> ──
            function getLines(el) {
                // Replace <br> tags with a unique delimiter, then split
                const clone = el.cloneNode(true);
                const brs = clone.querySelectorAll('br');
                brs.forEach(br => br.replaceWith('|||BR|||'));
                const rawText = clone.textContent;
                return rawText.split('|||BR|||')
                    .map(l => l.trim())
                    .filter(l => l.length > 0);
            }

            // ── Title ──
            const h1 = document.querySelector('h1');
            if (h1) {
                result.title = h1.textContent.trim();
            }

            // ── Song Number ──
            // Strategy 1: Look for "Song Number:" label text
            const allSpans = document.querySelectorAll('span, p, div, dt, dd, label');
            for (const el of allSpans) {
                const text = el.textContent.trim();
                if (/^Song\\s*Number:?$/i.test(text)) {
                    // Walk siblings and parent for the actual number value
                    let numEl = el.nextElementSibling;
                    if (!numEl) {
                        numEl = el.parentElement?.nextElementSibling;
                    }
                    if (!numEl) {
                        // Try within the same parent container
                        const parent = el.closest('div, dl, li, p');
                        if (parent) {
                            const candidates = parent.querySelectorAll('span.font-semibold, span.text-lg, dd, .font-bold');
                            for (const c of candidates) {
                                if (c !== el) {
                                    numEl = c;
                                    break;
                                }
                            }
                        }
                    }
                    if (numEl) {
                        const num = parseInt(numEl.textContent.trim(), 10);
                        if (!isNaN(num)) {
                            result.number = num;
                        }
                    }
                    break;
                }
            }

            // Strategy 2: Font-semibold fallback
            if (result.number === null) {
                const metaEls = document.querySelectorAll('.font-semibold, .font-bold');
                for (const el of metaEls) {
                    const txt = el.textContent.trim();
                    if (/^\\d+$/.test(txt)) {
                        const num = parseInt(txt, 10);
                        if (num > 0 && num < 1000) {
                            result.number = num;
                            break;
                        }
                    }
                }
            }

            // ── Category ──
            // Check for "Izindi ziri Mu ..." heading (related songs section)
            const headings = document.querySelectorAll('h2, h3, h4');
            for (const heading of headings) {
                const text = heading.textContent.trim();
                const catMatch = text.match(/Izindi\\s+ziri\\s+Mu\\s+(.+)/i);
                if (catMatch) {
                    result.category = catMatch[1].replace(/[""]/g, '').trim();
                    break;
                }
            }

            // Fallback: breadcrumb trail
            if (!result.category) {
                const breadcrumbs = document.querySelectorAll('nav a, ol a, .breadcrumb a');
                const bcTexts = Array.from(breadcrumbs)
                    .map(a => a.textContent.trim())
                    .filter(t => t && t !== 'Home' && !t.includes('Gushimisha') && !t.includes('Agakiza'));
                if (bcTexts.length > 0) {
                    result.category = bcTexts[bcTexts.length - 1];
                }
            }

            // ── Lyrics ──
            const lyricsContainer = document.querySelector('.song-lyrics');
            if (lyricsContainer) {
                // Each verse/chorus is a child div with class "flex gap-4" or similar
                const verseBlocks = lyricsContainer.children;
                for (const block of verseBlocks) {
                    // Verse number element: .flex-shrink-0 span
                    const numSpan = block.querySelector('.flex-shrink-0 span');
                    // Lyrics text element: .flex-1
                    const textEl = block.querySelector('.flex-1');

                    if (!textEl) continue;

                    // Use the <br>-aware line splitter
                    const lines = getLines(textEl);

                    let verseLabel = numSpan ? numSpan.textContent.trim() : '';

                    // Detect chorus/refrain
                    const isChorus = /^(ref|chorus|choeur)/i.test(verseLabel) ||
                                     verseLabel.toLowerCase().includes('ref');

                    if (isChorus) {
                        result.lyrics.push({
                            type: 'chorus',
                            lines: lines
                        });
                    } else {
                        const verseNum = parseInt(verseLabel, 10);
                        result.lyrics.push({
                            type: 'verse',
                            number: isNaN(verseNum) ? null : verseNum,
                            lines: lines
                        });
                    }
                }
            }

            return result;
        }
    """)

    if not data or not data.get("title"):
        print(f"    ⚠️  Could not extract data from: {hymn_url}")
        return None

    # Parse slug and uuid from the URL
    url_match = re.search(
        r"/([^/]+)/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{2,4}-[0-9a-f]{4}-[0-9a-f]{12})$",
        hymn_url,
        re.IGNORECASE,
    )
    slug = url_match.group(1) if url_match else ""
    uuid = url_match.group(2) if url_match else ""

    # Build the final hymn object
    hymn = {
        "number": data["number"],
        "book": book_label,
        "title": data["title"],
        "slug": slug,
        "uuid": uuid,
        "category": data.get("category", ""),
        "url": hymn_url,
        "lyrics": data.get("lyrics", []),
    }

    return hymn


def save_hymn(hymn: dict, book_key: str):
    """Save a single hymn as a JSON file."""
    book_dir = OUTPUT_DIR / book_key
    book_dir.mkdir(parents=True, exist_ok=True)

    num = hymn.get("number")
    if num:
        filename = f"{slugify_number(num)}.json"
    else:
        # Fallback: use slug
        filename = f"{hymn.get('slug', 'unknown')}.json"

    filepath = book_dir / filename
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(hymn, f, ensure_ascii=False, indent=2)

    return filepath


def save_combined(hymns: list[dict], book_key: str):
    """Save all hymns for a book into a single combined JSON file."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    filepath = OUTPUT_DIR / f"{book_key}_all.json"
    # Sort by hymn number
    sorted_hymns = sorted(hymns, key=lambda h: h.get("number") or 9999)
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(sorted_hymns, f, ensure_ascii=False, indent=2)
    return filepath


def save_full_dataset(all_hymns: dict):
    """Save the complete dataset (both books) as a single JSON file."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    filepath = OUTPUT_DIR / "all_hymns.json"

    dataset = {
        "metadata": {
            "source": "indirimbo.com",
            "scraped_at": datetime.now().isoformat(),
            "total_hymns": sum(len(v) for v in all_hymns.values()),
            "books": {k: len(v) for k, v in all_hymns.items()},
        },
        "hymns": {
            book: sorted(hymns, key=lambda h: h.get("number") or 9999)
            for book, hymns in all_hymns.items()
        },
    }

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(dataset, f, ensure_ascii=False, indent=2)

    return filepath


# ─── Progress Tracking ───────────────────────────────────────────────────────

def load_progress(book_key: str) -> set:
    """Load set of already-scraped URLs from progress file."""
    progress_file = OUTPUT_DIR / f".progress_{book_key}.json"
    if progress_file.exists():
        with open(progress_file, "r") as f:
            return set(json.load(f))
    return set()


def save_progress(book_key: str, scraped_urls: set):
    """Save scraped URLs to progress file for resume capability."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    progress_file = OUTPUT_DIR / f".progress_{book_key}.json"
    with open(progress_file, "w") as f:
        json.dump(list(scraped_urls), f)


# ─── Main ────────────────────────────────────────────────────────────────────

def scrape_book(page, book_key: str, delay: float, resume: bool = True):
    """Scrape all hymns for a given book."""
    config = BOOKS[book_key]
    book_label = config["book_label"]

    print(f"\n{'='*60}")
    print(f"📖 Scraping: {book_label}")
    print(f"{'='*60}")

    # Step 1: Collect all hymn links
    print(f"\n🔍 Step 1: Collecting hymn links from listing pages...")
    hymn_links = collect_hymn_links(page, book_key, delay)

    if not hymn_links:
        print(f"  ❌ No hymn links found for {book_label}")
        return []

    # Step 2: Check progress (for resume capability)
    scraped_urls = load_progress(book_key) if resume else set()
    remaining = [h for h in hymn_links if h["url"] not in scraped_urls]

    print(f"\n📝 Step 2: Scraping individual hymn pages...")
    print(f"  Total: {len(hymn_links)} | Already scraped: {len(scraped_urls)} | Remaining: {len(remaining)}")

    # Load already-scraped hymns from disk
    all_hymns = []
    book_dir = OUTPUT_DIR / book_key
    if book_dir.exists():
        for json_file in sorted(book_dir.glob("*.json")):
            with open(json_file, "r", encoding="utf-8") as f:
                all_hymns.append(json.load(f))

    # Step 3: Scrape remaining hymns
    for i, link in enumerate(remaining, 1):
        url = link["url"]
        print(f"  [{i}/{len(remaining)}] Scraping: {url}")

        hymn = scrape_hymn_page(page, url, book_label)

        if hymn:
            filepath = save_hymn(hymn, book_key)
            all_hymns.append(hymn)
            scraped_urls.add(url)
            save_progress(book_key, scraped_urls)
            print(f"    ✅ #{hymn.get('number', '?')}: {hymn['title']} → {filepath.name}")
        else:
            print(f"    ❌ Failed to scrape: {url}")

        # Rate limiting
        time.sleep(delay)

    # Step 4: Save combined file
    combined_path = save_combined(all_hymns, book_key)
    print(f"\n  📦 Combined file: {combined_path}")
    print(f"  📊 Total hymns scraped for {book_label}: {len(all_hymns)}")

    return all_hymns


def main():
    parser = argparse.ArgumentParser(
        description="Scrape hymns from indirimbo.com",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scrape_indirimbo.py                    # Scrape all hymns
  python scrape_indirimbo.py --book gushimisha  # Scrape only Gushimisha
  python scrape_indirimbo.py --book agakiza     # Scrape only Agakiza
  python scrape_indirimbo.py --delay 2.0        # Slower scraping (be polite)
  python scrape_indirimbo.py --no-resume        # Start fresh (ignore progress)
        """,
    )
    parser.add_argument(
        "--book",
        choices=["gushimisha", "agakiza", "all"],
        default="all",
        help="Which hymnbook to scrape (default: all)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.5,
        help="Delay in seconds between requests (default: 1.5)",
    )
    parser.add_argument(
        "--no-resume",
        action="store_true",
        help="Start fresh, ignoring previous progress",
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        default=True,
        help="Run browser in headless mode (default: True)",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Run browser in visible mode (for debugging)",
    )

    args = parser.parse_args()
    headless = not args.headed

    books_to_scrape = (
        list(BOOKS.keys()) if args.book == "all" else [args.book]
    )

    print("╔══════════════════════════════════════════════════════════════╗")
    print("║          🎵 Indirimbo Hymnbook Scraper v1.0 🎵             ║")
    print("║          Source: indirimbo.com                              ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print(f"\n📋 Configuration:")
    print(f"   Books:    {', '.join(books_to_scrape)}")
    print(f"   Delay:    {args.delay}s between requests")
    print(f"   Headless: {headless}")
    print(f"   Resume:   {not args.no_resume}")
    print(f"   Output:   {OUTPUT_DIR.resolve()}")

    all_hymns = {}

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=headless)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1280, "height": 800},
        )
        page = context.new_page()

        try:
            for book_key in books_to_scrape:
                hymns = scrape_book(
                    page,
                    book_key,
                    delay=args.delay,
                    resume=not args.no_resume,
                )
                all_hymns[book_key] = hymns
        except KeyboardInterrupt:
            print("\n\n⚠️  Interrupted! Progress has been saved. Run again to resume.")
        finally:
            # Save the full combined dataset
            if all_hymns:
                full_path = save_full_dataset(all_hymns)
                print(f"\n{'='*60}")
                print(f"🎉 DONE!")
                print(f"{'='*60}")
                print(f"📦 Full dataset: {full_path}")
                for book, hymns in all_hymns.items():
                    print(f"   {BOOKS[book]['book_label']}: {len(hymns)} hymns")
                total = sum(len(v) for v in all_hymns.values())
                print(f"   Total: {total} hymns")

            browser.close()


if __name__ == "__main__":
    main()
