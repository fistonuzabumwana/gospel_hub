#!/usr/bin/env python3
import json
import sqlite3
import os
import sys

BIBLE_JSON_PATH = "/home/fiston/Documents/Project/gospel_hub/bible/kinyarwanda_2001 (2).json"
ENGLISH_JSON_PATH = "/home/fiston/Documents/Project/gospel_hub/bible/english_kj.json"
HYMNS_JSON_PATH = "/home/fiston/Documents/Project/gospel_hub/scraper/output/all_hymns.json"
OUTPUT_DB_DIR = "/home/fiston/Documents/Project/gospel_hub/assets/database"
OUTPUT_DB_PATH = os.path.join(OUTPUT_DB_DIR, "gospel_hub.db")

def main():
    print("🚀 Starting Gospel Hub database compilation...")

    # Create directories if needed
    os.makedirs(OUTPUT_DB_DIR, exist_ok=True)

    # Remove existing DB if any to start clean
    if os.path.exists(OUTPUT_DB_PATH):
        os.remove(OUTPUT_DB_PATH)

    conn = sqlite3.connect(OUTPUT_DB_PATH)
    cursor = conn.cursor()

    # 1. Create tables
    print("Creating tables...")
    cursor.execute("""
        CREATE TABLE bible_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            text TEXT,
            testament TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE hymns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book TEXT,
            number INTEGER,
            title TEXT,
            slug TEXT,
            uuid TEXT,
            category TEXT,
            lyrics TEXT
        )
    """)

    # Create favorites table for local bookmarking storage
    cursor.execute("""
        CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL, -- 'bible' or 'hymn'
            item_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        )
    """)

    cursor.execute("""
        CREATE TABLE english_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            text TEXT
        )
    """)

    # Indexes
    cursor.execute("CREATE INDEX idx_bible_verses ON bible_verses(book, chapter)")
    cursor.execute("CREATE INDEX idx_english_verses ON english_verses(book, chapter)")
    cursor.execute("CREATE INDEX idx_hymns_book ON hymns(book, number)")

    # 2. Populate Bible
    print(f"Loading Kinyarwanda Bible from {BIBLE_JSON_PATH}...")
    if not os.path.exists(BIBLE_JSON_PATH):
        print(f"❌ Error: Kinyarwanda Bible JSON file not found at {BIBLE_JSON_PATH}")
        sys.exit(1)

    with open(BIBLE_JSON_PATH, "r", encoding="utf-8") as f:
        bible_data = json.load(f)

    print(f"Inserting {len(bible_data)} bible verses...")
    cursor.executemany("""
        INSERT INTO bible_verses (book, chapter, verse, text, testament)
        VALUES (?, ?, ?, ?, ?)
    """, [
        (
            item["book"],
            item["chapter"],
            item["verse"],
            item["text"],
            item["testament"]
        ) for item in bible_data
    ])

    # 2.5 Populate English Bible
    print(f"Loading English Bible from {ENGLISH_JSON_PATH}...")
    if not os.path.exists(ENGLISH_JSON_PATH):
        print(f"❌ Error: English Bible JSON file not found at {ENGLISH_JSON_PATH}")
        sys.exit(1)

    with open(ENGLISH_JSON_PATH, "r", encoding="utf-8") as f:
        english_data = json.load(f)

    print(f"Inserting {len(english_data)} English bible verses...")
    cursor.executemany("""
        INSERT INTO english_verses (book, chapter, verse, text)
        VALUES (?, ?, ?, ?)
    """, [
        (
            item["book"],
            item["chapter"],
            item["verse"],
            item["text"]
        ) for item in english_data
    ])

    # 3. Populate Hymns
    print(f"Loading Hymns from {HYMNS_JSON_PATH}...")
    if not os.path.exists(HYMNS_JSON_PATH):
        print(f"❌ Error: Hymns JSON file not found at {HYMNS_JSON_PATH}")
        sys.exit(1)

    with open(HYMNS_JSON_PATH, "r", encoding="utf-8") as f:
        hymns_data = json.load(f)

    hymn_list = []
    # all_hymns.json has keys 'gushimisha' and 'agakiza' under 'hymns'
    hymns_map = hymns_data.get("hymns", {})
    
    for book_key, items in hymns_map.items():
        book_label = "Gushimisha" if book_key == "gushimisha" else "Agakiza"
        print(f"Processing {len(items)} hymns for {book_label}...")
        for item in items:
            # Stringify the lyrics blocks list to JSON
            lyrics_str = json.dumps(item.get("lyrics", []), ensure_ascii=False)
            hymn_list.append((
                book_label,
                item.get("number"),
                item.get("title"),
                item.get("slug"),
                item.get("uuid"),
                item.get("category", ""),
                lyrics_str
            ))

    cursor.executemany("""
        INSERT INTO hymns (book, number, title, slug, uuid, category, lyrics)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, hymn_list)

    # Commit and close
    conn.commit()
    conn.close()

    print(f"✅ Compilation finished! Pre-populated database saved to: {OUTPUT_DB_PATH}")
    
    # Show statistics
    db_size = os.path.getsize(OUTPUT_DB_PATH) / (1024 * 1024)
    print(f"📊 Database Size: {db_size:.2f} MB")

if __name__ == "__main__":
    main()
