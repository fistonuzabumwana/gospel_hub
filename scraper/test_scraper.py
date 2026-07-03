#!/usr/bin/env python3
"""Quick test: scrape just 3 hymns to validate the scraper logic."""

import json
import sys
import time
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("Playwright not installed")
    sys.exit(1)

BASE_URL = "https://indirimbo.com"

def getLines_helper():
    """JS helper injected into the page for <br>-splitting."""
    return """
    function getLines(el) {
        const clone = el.cloneNode(true);
        const brs = clone.querySelectorAll('br');
        brs.forEach(br => br.replaceWith('|||BR|||'));
        const rawText = clone.textContent;
        return rawText.split('|||BR|||')
            .map(l => l.trim())
            .filter(l => l.length > 0);
    }
    """


def main():
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
        )
        page = context.new_page()

        # Step 1: Get a few hymn links from the listing page
        print("📄 Loading listing page...")
        page.goto(f"{BASE_URL}/gushimisha", wait_until="domcontentloaded", timeout=30000)
        page.wait_for_timeout(2000)

        links = page.evaluate("""
            () => {
                const results = [];
                const anchors = document.querySelectorAll('a[href]');
                for (const a of anchors) {
                    const href = a.href;
                    const match = href.match(/indirimbo\\.com\\/(?:indirimbo-zo-gushimisha|gushimisha)\\/([^\\/]+)\\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{2,4}-[0-9a-f]{4}-[0-9a-f]{12})/i);
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
        
        print(f"✅ Found {len(links)} hymn links on page 1")
        
        # Take only first 3 for testing
        test_links = links[:3]
        
        for i, link in enumerate(test_links):
            print(f"\n{'='*60}")
            print(f"🎵 [{i+1}/3] Scraping: {link['url']}")
            
            page.goto(link['url'], wait_until="domcontentloaded", timeout=30000)
            page.wait_for_timeout(2000)

            data = page.evaluate("""
                () => {
                    const result = {
                        title: '',
                        number: null,
                        category: '',
                        lyrics: [],
                        debug: {}
                    };

                    function getLines(el) {
                        const clone = el.cloneNode(true);
                        const brs = clone.querySelectorAll('br');
                        brs.forEach(br => br.replaceWith('|||BR|||'));
                        const rawText = clone.textContent;
                        return rawText.split('|||BR|||')
                            .map(l => l.trim())
                            .filter(l => l.length > 0);
                    }

                    // Title
                    const h1 = document.querySelector('h1');
                    if (h1) result.title = h1.textContent.trim();

                    // Song Number - search all text
                    const allEls = document.querySelectorAll('span, p, div, dt, dd, label');
                    for (const el of allEls) {
                        const text = el.textContent.trim();
                        if (/^Song\\s*Number:?$/i.test(text)) {
                            let numEl = el.nextElementSibling;
                            if (!numEl) numEl = el.parentElement?.nextElementSibling;
                            if (!numEl) {
                                const parent = el.closest('div, dl, li, p');
                                if (parent) {
                                    const candidates = parent.querySelectorAll('span.font-semibold, span.text-lg, dd, .font-bold');
                                    for (const c of candidates) {
                                        if (c !== el) { numEl = c; break; }
                                    }
                                }
                            }
                            if (numEl) {
                                const num = parseInt(numEl.textContent.trim(), 10);
                                if (!isNaN(num)) result.number = num;
                            }
                            break;
                        }
                    }

                    // Fallback song number
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

                    // Category
                    const headings = document.querySelectorAll('h2, h3, h4');
                    for (const heading of headings) {
                        const text = heading.textContent.trim();
                        const catMatch = text.match(/Izindi\\s+ziri\\s+Mu\\s+(.+)/i);
                        if (catMatch) {
                            result.category = catMatch[1].replace(/[""]/g, '').trim();
                            break;
                        }
                    }

                    // Lyrics
                    const lyricsContainer = document.querySelector('.song-lyrics');
                    result.debug.hasLyricsContainer = !!lyricsContainer;
                    
                    if (lyricsContainer) {
                        result.debug.childrenCount = lyricsContainer.children.length;
                        result.debug.innerHTML_preview = lyricsContainer.innerHTML.substring(0, 500);
                        
                        const verseBlocks = lyricsContainer.children;
                        for (const block of verseBlocks) {
                            const numSpan = block.querySelector('.flex-shrink-0 span');
                            const textEl = block.querySelector('.flex-1');
                            
                            if (!textEl) {
                                // Try alternate selectors
                                result.debug.blockHTML = block.innerHTML.substring(0, 300);
                                continue;
                            }
                            
                            const lines = getLines(textEl);
                            let verseLabel = numSpan ? numSpan.textContent.trim() : '';
                            
                            const isChorus = /^(ref|chorus|choeur)/i.test(verseLabel) ||
                                             verseLabel.toLowerCase().includes('ref');
                            
                            if (isChorus) {
                                result.lyrics.push({ type: 'chorus', lines: lines });
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
            
            print(f"  Title: {data.get('title')}")
            print(f"  Number: {data.get('number')}")
            print(f"  Category: {data.get('category')}")
            print(f"  Has lyrics container: {data.get('debug', {}).get('hasLyricsContainer')}")
            print(f"  Verse blocks: {data.get('debug', {}).get('childrenCount')}")
            print(f"  Lyrics sections: {len(data.get('lyrics', []))}")
            
            if data.get('debug', {}).get('innerHTML_preview'):
                print(f"  HTML preview: {data['debug']['innerHTML_preview'][:300]}")
            
            for section in data.get('lyrics', [])[:2]:
                print(f"  📝 {section['type']}" + (f" #{section.get('number')}" if section.get('number') else ""))
                for line in section.get('lines', [])[:3]:
                    print(f"      {line}")
                if len(section.get('lines', [])) > 3:
                    print(f"      ... ({len(section['lines'])} lines total)")
            
            # Save test output
            output_dir = Path(__file__).parent / "output" / "test"
            output_dir.mkdir(parents=True, exist_ok=True)
            with open(output_dir / f"test_{i+1}.json", "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            time.sleep(1)
        
        browser.close()
        print(f"\n✅ Test complete! Check scraper/output/test/ for JSON files.")


if __name__ == "__main__":
    main()
