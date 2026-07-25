#!/usr/bin/env python3
"""
Bibiliya Yera (Bible) Scraper
=============================
Scrapes the complete Kinyarwanda Bible from bibiliya.com
and exports it to structured JSON files.

Zero external dependencies! Uses Python's built-in urllib and html.parser.

Usage:
    python3 scrape_bible.py [--book slug] [--chapter num] [--delay seconds] [--no-resume]
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path

# ─── Configuration & Books Mapping ───────────────────────────────────────────

# 66 Books of the Bible in order with Kinyarwanda display name and total chapters.
# Order matches the standard Protestant Bible (1: Genesis, ..., 66: Revelation).
BOOKS = {
    "itangiriro": {"name": "Itangiriro", "chapters": 50},
    "kuva": {"name": "Kuva", "chapters": 40},
    "abalewi": {"name": "Abalewi", "chapters": 27},
    "kubara": {"name": "Kubara", "chapters": 36},
    "gutegeka_kwa_kabiri": {"name": "Gutegeka kwa Kabiri", "chapters": 34},
    "yosuwa": {"name": "Yosuwa", "chapters": 24},
    "abacamanza": {"name": "Abacamanza", "chapters": 21},
    "rusi": {"name": "Rusi", "chapters": 4},
    "1_samweli": {"name": "1 Samweli", "chapters": 31},
    "2_samweli": {"name": "2 Samweli", "chapters": 24},
    "1_abami": {"name": "1 Abami", "chapters": 22},
    "2_abami": {"name": "2 Abami", "chapters": 25},
    "1_ibyo_ku_ngoma": {"name": "1 Ngoma", "chapters": 29},
    "2_ibyo_ku_ngoma": {"name": "2 Ngoma", "chapters": 36},
    "ezira": {"name": "Ezira", "chapters": 10},
    "nehemiya": {"name": "Nehemiya", "chapters": 13},
    "esiteri": {"name": "Esiteri", "chapters": 10},
    "yobu": {"name": "Yobu", "chapters": 42},
    "zaburi": {"name": "Zaburi", "chapters": 150},
    "imigani": {"name": "Imigani", "chapters": 31},
    "umubwiriza": {"name": "Umubwiriza", "chapters": 12},
    "indirimbo": {"name": "Indirimbo", "chapters": 8},
    "yesaya": {"name": "Yesaya", "chapters": 66},
    "yeremiya": {"name": "Yeremiya", "chapters": 52},
    "amaganya": {"name": "Amaganya", "chapters": 5},
    "ezekiyeli": {"name": "Ezekiyeli", "chapters": 48},
    "daniyeli": {"name": "Daniyeli", "chapters": 12},
    "hoseya": {"name": "Hoseya", "chapters": 14},
    "yoweli": {"name": "Yoweli", "chapters": 4},
    "amosi": {"name": "Amosi", "chapters": 9},
    "obadiya": {"name": "Obadiya", "chapters": 1},
    "yona": {"name": "Yona", "chapters": 4},
    "mika": {"name": "Mika", "chapters": 7},
    "nahumu": {"name": "Nahumu", "chapters": 3},
    "habakuki": {"name": "Habakuki", "chapters": 3},
    "zefaniya": {"name": "Zefaniya", "chapters": 3},
    "hagayi": {"name": "Hagayi", "chapters": 2},
    "zekariya": {"name": "Zekariya", "chapters": 14},
    "malaki": {"name": "Malaki", "chapters": 3},
    "matayo": {"name": "Matayo", "chapters": 28},
    "mariko": {"name": "Mariko", "chapters": 16},
    "luka": {"name": "Luka", "chapters": 24},
    "yohana": {"name": "Yohana", "chapters": 21},
    "ibyakozwe_n_intumwa": {"name": "Ibyakozwe n'Intumwa", "chapters": 28},
    "abaroma": {"name": "Abaroma", "chapters": 16},
    "1_abakorinto": {"name": "1 Abakorinto", "chapters": 16},
    "2_abakorinto": {"name": "2 Abakorinto", "chapters": 13},
    "abagalatiya": {"name": "Abagalatiya", "chapters": 6},  # site slug
    "abefeso": {"name": "Abefeso", "chapters": 6},
    "abafilipi": {"name": "Abafilipi", "chapters": 4},      # site slug
    "abakolosayi": {"name": "Abakolosayi", "chapters": 4},
    "1_abatesalonike": {"name": "1 Abatesalonike", "chapters": 5},
    "2_abatesalonike": {"name": "2 Abatesalonike", "chapters": 3},
    "1_timoteyo": {"name": "1 Timoteyo", "chapters": 6},
    "2_timoteyo": {"name": "2 Timoteyo", "chapters": 4},
    "tito": {"name": "Tito", "chapters": 3},
    "filemoni": {"name": "Filemoni", "chapters": 1},
    "abaheburayo": {"name": "Abaheburayo", "chapters": 13},
    "yakobo": {"name": "Yakobo", "chapters": 5},
    "1_petero": {"name": "1 Petero", "chapters": 5},
    "2_petero": {"name": "2 Petero", "chapters": 3},
    "1_yohana": {"name": "1 Yohana", "chapters": 5},
    "2_yohana": {"name": "2 Yohana", "chapters": 1},
    "3_yohana": {"name": "3 Yohana", "chapters": 1},
    "yuda": {"name": "Yuda", "chapters": 1},
    "ibyahishuwe": {"name": "Ibyahishuwe", "chapters": 22}
}

# The ordered keys mapping to book numbers (1-indexed)
BOOKS_ORDER = list(BOOKS.keys())

BASE_URL = "https://bibiliya.com/yera"
OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "bible"

# ─── Robust Parser ───────────────────────────────────────────────────────────

class BibleHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_tr = False
        self.in_td = False
        
        # Heading tracking (finalized when span ends or td ends)
        self.in_heading_span = False
        self.heading_text_accumulator = []
        self.current_heading = None

        # Verse tracking
        self.in_verse_div = False
        self.current_verse_num = None
        self.verse_text_accumulator = []
        self.div_nesting_depth = 0
        
        # List of parsed verse dictionaries
        self.verses = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        tag = tag.lower()
        
        if tag == "table" and attrs_dict.get("id") == "tb":
            self.in_table = True
        elif tag == "tr" and self.in_table:
            self.in_tr = True
        elif tag == "td" and self.in_tr:
            self.in_td = True
        elif tag == "span" and self.in_td and attrs_dict.get("class") == "umutwe":
            self.in_heading_span = True
            self.heading_text_accumulator = []
        elif tag == "div" and self.in_td:
            div_id = attrs_dict.get("id", "")
            if div_id.startswith("cont-"):
                verse_num_str = div_id.replace("cont-", "")
                if verse_num_str.isdigit():
                    self.in_verse_div = True
                    self.current_verse_num = int(verse_num_str)
                    self.verse_text_accumulator = []
                    self.div_nesting_depth = 1
            elif self.in_verse_div:
                self.div_nesting_depth += 1

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "table":
            self.in_table = False
        elif tag == "tr":
            self.in_tr = False
        elif tag == "td":
            self.in_td = False
            # If td ends and we haven't closed heading span, finalize it
            if self.in_heading_span:
                self._finalize_heading()
        elif tag == "span" and self.in_heading_span:
            self._finalize_heading()
        elif tag == "div" and self.in_verse_div:
            self.div_nesting_depth -= 1
            if self.div_nesting_depth == 0:
                self.in_verse_div = False
                verse_text = "".join(self.verse_text_accumulator)
                # Clean up whitespace
                verse_text = re.sub(r"\s+", " ", verse_text).strip()
                # Clean up common typographic artifacts
                verse_text = verse_text.replace("\xa0", " ")
                
                verse_obj = {
                    "verse": self.current_verse_num,
                    "text": verse_text
                }
                if self.current_heading:
                    verse_obj["heading"] = self.current_heading
                    self.current_heading = None # consume heading
                self.verses.append(verse_obj)
                self.current_verse_num = None

    def handle_data(self, data):
        if self.in_heading_span:
            self.heading_text_accumulator.append(data)
        elif self.in_verse_div:
            self.verse_text_accumulator.append(data)

    def _finalize_heading(self):
        self.in_heading_span = False
        heading_text = "".join(self.heading_text_accumulator)
        heading_text = re.sub(r"\s+", " ", heading_text).strip()
        heading_text = heading_text.replace("\xa0", " ")
        if heading_text:
            if self.current_heading:
                self.current_heading += " / " + heading_text
            else:
                self.current_heading = heading_text
        self.heading_text_accumulator = []

# ─── Scraping Logic ──────────────────────────────────────────────────────────

def fetch_html(url: str, retries: int = 3, timeout: int = 25) -> str:
    """Fetch HTML from bibiliya.com using urllib with custom headers and retries."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    req = urllib.request.Request(url, headers=headers)
    
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                return response.read().decode("utf-8")
        except Exception as e:
            if attempt == retries:
                raise e
            print(f"    ⚠️  Fetch failed ({e}), retrying in {attempt * 2}s (attempt {attempt}/{retries})...")
            time.sleep(attempt * 2)

def scrape_chapter(book_slug: str, chapter: int) -> list[dict] | None:
    """Scrapes a single chapter, returns list of verses or None on failure."""
    url = f"{BASE_URL}/{book_slug}-{chapter}/"
    try:
        html = fetch_html(url)
        parser = BibleHTMLParser()
        parser.feed(html)
        return parser.verses
    except Exception as e:
        print(f"    ❌ Error scraping {book_slug} chapter {chapter}: {e}")
        return None

def save_chapter_json(book_slug: str, chapter: int, data: dict):
    """Saves parsed chapter data to output directory."""
    chapter_dir = OUTPUT_DIR / "yera" / book_slug
    chapter_dir.mkdir(parents=True, exist_ok=True)
    
    filepath = chapter_dir / f"{chapter}.json"
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def load_chapter_json(book_slug: str, chapter: int) -> dict | None:
    """Loads chapter data from disk if it exists."""
    filepath = OUTPUT_DIR / "yera" / book_slug / f"{chapter}.json"
    if filepath.exists():
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    return None

# ─── Dataset Compilation ──────────────────────────────────────────────────────

def compile_datasets():
    """Compiles all individual JSON files into flat and structured combined datasets."""
    print("📦 Compiling scraped chapters into combined datasets...")
    flat_data = []
    structured_data = {}
    
    total_chapters_found = 0
    total_verses_found = 0

    for book_idx, book_slug in enumerate(BOOKS_ORDER, 1):
        book_config = BOOKS[book_slug]
        book_name = book_config["name"]
        book_total_chapters = book_config["chapters"]
        testament = "Old" if book_idx <= 39 else "New"
        
        book_chapters = {}
        book_verses_flat = []
        
        for chapter in range(1, book_total_chapters + 1):
            ch_data = load_chapter_json(book_slug, chapter)
            if not ch_data:
                continue
                
            total_chapters_found += 1
            verses_list = ch_data.get("verses", [])
            book_chapters[str(chapter)] = verses_list
            
            for v in verses_list:
                total_verses_found += 1
                
                # Flat schema matching kinyarwanda_2001 (2).json
                flat_item = {
                    "language": "Kinyarwanda",
                    "version": "Yera",
                    "testament": testament,
                    "book": book_idx,
                    "chapter": chapter,
                    "verse": v["verse"],
                    "text": v["text"]
                }
                # Include heading if it exists in the scraped source
                if "heading" in v:
                    flat_item["heading"] = v["heading"]
                    
                flat_data.append(flat_item)
                book_verses_flat.append(flat_item)
                
        # Also save book-specific combined flat/structured JSON if we scraped anything
        if book_verses_flat:
            book_output_dir = OUTPUT_DIR / "yera"
            # Book-specific combined
            with open(book_output_dir / f"{book_slug}_all.json", "w", encoding="utf-8") as f:
                json.dump(book_verses_flat, f, ensure_ascii=False, indent=2)

        if book_chapters:
            structured_data[book_slug] = {
                "book_id": book_idx,
                "book_name": book_name,
                "testament": testament,
                "chapters": book_chapters
            }

    # Filter Old and New testament verses
    old_data = [item for item in flat_data if item["testament"] == "Old"]
    new_data = [item for item in flat_data if item["testament"] == "New"]

    # Save final combined flat datasets
    all_path = OUTPUT_DIR / "bible_yera_all.json"
    with open(all_path, "w", encoding="utf-8") as f:
        json.dump(flat_data, f, ensure_ascii=False, indent=2)

    old_path = OUTPUT_DIR / "bible_yera_old.json"
    with open(old_path, "w", encoding="utf-8") as f:
        json.dump(old_data, f, ensure_ascii=False, indent=2)

    new_path = OUTPUT_DIR / "bible_yera_new.json"
    with open(new_path, "w", encoding="utf-8") as f:
        json.dump(new_data, f, ensure_ascii=False, indent=2)

    # Save final combined structured dataset
    struct_path = OUTPUT_DIR / "bible_yera_structured.json"
    with open(struct_path, "w", encoding="utf-8") as f:
        json.dump({
            "metadata": {
                "source": "bibiliya.com",
                "scraped_at": datetime.now().isoformat(),
                "total_books": len(structured_data),
                "total_chapters": total_chapters_found,
                "total_verses": total_verses_found
            },
            "books": structured_data
        }, f, ensure_ascii=False, indent=2)

    print(f"✅ Compilation finished!")
    print(f"   📊 Chapters compiled: {total_chapters_found} / 1189")
    print(f"   📊 Total Verses: {total_verses_found}")
    print(f"   💾 Saved all: {all_path} ({all_path.stat().st_size / (1024*1024):.2f} MB)")
    print(f"   💾 Saved old: {old_path} ({old_path.stat().st_size / (1024*1024):.2f} MB)")
    print(f"   💾 Saved new: {new_path} ({new_path.stat().st_size / (1024*1024):.2f} MB)")


# ─── Main Execution ──────────────────────────────────────────────────────────

import concurrent.futures
import random

def main():
    parser = argparse.ArgumentParser(description="Bibiliya Yera Bible Scraper")
    parser.add_argument("--book", type=str, help="Scrape only this book slug (e.g. 'itangiriro')")
    parser.add_argument("--chapter", type=int, help="Scrape only this chapter number (requires --book)")
    parser.add_argument("--delay", type=float, default=0.2, help="Delay between processed completions in seconds")
    parser.add_argument("--workers", type=int, default=8, help="Number of concurrent scraper workers")
    parser.add_argument("--no-resume", action="store_true", help="Overwrite existing progress/scraped chapters")
    
    args = parser.parse_args()
    
    if args.chapter and not args.book:
        print("❌ Error: --chapter requires specifying --book")
        sys.exit(1)

    print("🚀 Starting Bibiliya Yera Scraper...")
    
    # Clean output if no-resume requested
    if args.no_resume:
        print("🗑️  --no-resume specified. Overwriting previous progress.")

    target_books = BOOKS_ORDER
    if args.book:
        slug = args.book.lower().strip()
        if slug not in BOOKS:
            print(f"❌ Error: Book slug '{slug}' is invalid. Choose from:\n{', '.join(BOOKS_ORDER)}")
            sys.exit(1)
        target_books = [slug]

    # Gather tasks to perform
    tasks = []
    skipped_count = 0
    
    for book_slug in target_books:
        book_config = BOOKS[book_slug]
        book_name = book_config["name"]
        chapters_count = book_config["chapters"]
        book_id = BOOKS_ORDER.index(book_slug) + 1
        testament = "Old" if book_id <= 39 else "New"
        
        chapters_range = range(1, chapters_count + 1)
        if args.chapter:
            if args.chapter < 1 or args.chapter > chapters_count:
                print(f"❌ Error: Chapter {args.chapter} is out of bounds for {book_name} (has {chapters_count} chapters).")
                sys.exit(1)
            chapters_range = [args.chapter]
            
        for chapter in chapters_range:
            # Check for resume
            if not args.no_resume:
                existing = load_chapter_json(book_slug, chapter)
                if existing and len(existing.get("verses", [])) > 0:
                    skipped_count += 1
                    continue
            
            tasks.append((book_slug, book_name, chapter, chapters_count, testament, book_id))

    total_target = len(tasks) + skipped_count
    print(f"📚 Total targeted chapters: {total_target} (Skipped/Existing: {skipped_count}, To Scrape: {len(tasks)})")
    
    scraped_count = 0
    failed_count = 0
    
    if tasks:
        print(f"⚡ Scraping {len(tasks)} chapters using {args.workers} concurrent workers (delay={args.delay}s)...")
        
        def worker_task(task):
            book_slug, book_name, chapter, chapters_count, testament, book_id = task
            # Slightly stagger thread start times to be polite
            time.sleep(random.uniform(0.0, 0.4))
            verses = scrape_chapter(book_slug, chapter)
            return task, verses

        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
                futures = {executor.submit(worker_task, t): t for t in tasks}
                
                for future in concurrent.futures.as_completed(futures):
                    task = futures[future]
                    book_slug, book_name, chapter, chapters_count, testament, book_id = task
                    try:
                        _, verses = future.result()
                        if verses is not None:
                            chapter_data = {
                                "book_id": book_id,
                                "book_name": book_name,
                                "book_slug": book_slug,
                                "chapter": chapter,
                                "testament": testament,
                                "verses": verses
                            }
                            save_chapter_json(book_slug, chapter, chapter_data)
                            scraped_count += 1
                            headings_count = sum(1 for v in verses if "heading" in v)
                            print(f"  ✅ Scraped {book_name} Ch {chapter}/{chapters_count} (Parsed {len(verses)} verses, {headings_count} headings)")
                        else:
                            failed_count += 1
                            print(f"  ❌ Failed {book_name} Ch {chapter}/{chapters_count}")
                    except Exception as e:
                        failed_count += 1
                        print(f"  ❌ Exception scraping {book_name} Ch {chapter}/{chapters_count}: {e}")
                    
                    # Small delay between processed completions
                    if args.delay > 0:
                        time.sleep(args.delay)
                        
        except KeyboardInterrupt:
            print("\n🛑 Scraping interrupted by user.")
            
    print("\n--- Scraping Run Summary ---")
    print(f"✅ Chapters Scraped: {scraped_count}")
    print(f"⏭️  Chapters Skipped: {skipped_count}")
    print(f"❌ Chapters Failed:  {failed_count}")
    
    # Run compilation if we scraped or skipped anything
    if scraped_count > 0 or skipped_count > 0:
        compile_datasets()

if __name__ == "__main__":
    main()
