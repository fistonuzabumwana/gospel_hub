#!/usr/bin/env python3
import json
import sqlite3
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DB_DIR = os.path.join(SCRIPT_DIR, "assets", "database")
OUTPUT_DB_PATH = os.path.join(OUTPUT_DB_DIR, "gospel_hub.db")
HYMNS_JSON_PATH = os.path.join(SCRIPT_DIR, "assets", "hymns", "all_hymns.json")

BIBLE_FILES = {
    'BY': os.path.join(SCRIPT_DIR, "assets", "bible", "bible_yera_all.json"),
    'II': os.path.join(SCRIPT_DIR, "assets", "bible", "bibiriya_ijambo_ryimana_kinyarwanda", "bible_ijambo_ryimana_all.json"),
    'KJV': os.path.join(SCRIPT_DIR, "assets", "bible", "english_kj.json"),
    'GNB': os.path.join(SCRIPT_DIR, "assets", "bible", "Holy_bible_good_news_english", "bible_good_news_all.json"),
    'BN': os.path.join(SCRIPT_DIR, "assets", "bible", "bibiriya_ntagatifu_kinyarwanda", "bible_ntagatifu_all.json"),
    'IID': os.path.join(SCRIPT_DIR, "assets", "bible", "bibiriya_ijambo_ryimana_d_kinyarwanda", "bible_ijambo_ryimana_d_all.json"),
    'CE': os.path.join(SCRIPT_DIR, "assets", "bible", "Holy_bible_catholic_english", "bible_catholic_all.json"),
    'GNC': os.path.join(SCRIPT_DIR, "assets", "bible", "Holy_bible_good_news_catholic_english", "bible_good_news_catholic_all.json")
}

def map_protestant_book(book_num):
    # Mapping 1-66 Protestant book numbers to 1-73 unified master numbers
    if book_num <= 16:
        return book_num
    elif book_num == 17:
        return 19 # Esther
    elif book_num == 18:
        return 22 # Job
    elif book_num == 19:
        return 23 # Psalms
    elif book_num == 20:
        return 24 # Proverbs
    elif book_num == 21:
        return 25 # Ecclesiastes
    elif book_num == 22:
        return 26 # Song of Solomon
    elif 23 <= book_num <= 25:
        return book_num + 6 # Isaiah to Lamentations (23->29, 24->30, 25->31)
    elif book_num == 26:
        return 33 # Ezekiel
    elif book_num == 27:
        return 34 # Daniel
    elif 28 <= book_num <= 30:
        return book_num + 7 # Hosea to Amos (28->35, 29->36, 30->37)
    elif book_num == 31:
        return 38 # Obadiah
    elif 32 <= book_num <= 39:
        return book_num + 7 # Jonah to Malachi (32->39, ..., 39->46)
    elif 40 <= book_num <= 66:
        return book_num + 7 # Matthew to Revelation (40->47, ..., 66->73)
    return book_num

def map_catholic_book(book_num):
    # Mapping 1-71 Catholic book numbers from JSON to 1-73 unified master numbers
    if book_num <= 14:
        return book_num
    elif 15 <= book_num <= 35:
        return book_num + 2 # Tobit(17), Judith(18), Esther(19), 1Mac(20), 2Mac(21), Job(22), Psalms(23)...
    elif book_num == 36:
        return 38 # Obadiah
    elif 37 <= book_num <= 71:
        return book_num + 2 # Jonah(39), ..., Malachi(46), Matthew(47), ..., Revelation(73)
    return book_num

def main():
    print("🚀 Starting Gospel Hub database compilation...")

    os.makedirs(OUTPUT_DB_DIR, exist_ok=True)

    if os.path.exists(OUTPUT_DB_PATH):
        os.remove(OUTPUT_DB_PATH)

    conn = sqlite3.connect(OUTPUT_DB_PATH)
    cursor = conn.cursor()

    # 1. Create tables
    print("Creating tables...")
    cursor.execute("""
        CREATE TABLE bible_verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            translation TEXT NOT NULL,
            book INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL,
            testament TEXT,
            heading TEXT
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

    cursor.execute("""
        CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL, -- 'bible' or 'hymn'
            item_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        )
    """)

    # Indexes
    cursor.execute("CREATE INDEX idx_bible_verses ON bible_verses(translation, book, chapter)")
    cursor.execute("CREATE INDEX idx_hymns_book ON hymns(book, number)")

    # 2. Populate Bible translations
    for translation_key, file_path in BIBLE_FILES.items():
        print(f"Loading {translation_key} Bible from {file_path}...")
        if not os.path.exists(file_path):
            print(f"❌ Error: File not found at {file_path}")
            sys.exit(1)

        with open(file_path, "r", encoding="utf-8") as f:
            bible_data = json.load(f)

        # Decide which mapper to use based on translation key
        is_catholic = translation_key in ['BN', 'IID', 'CE', 'GNC']
        mapper = map_catholic_book if is_catholic else map_protestant_book

        print(f"Inserting {len(bible_data)} verses for {translation_key}...")
        cursor.executemany("""
            INSERT INTO bible_verses (translation, book, chapter, verse, text, testament, heading)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [
            (
                translation_key,
                mapper(item["book"]),
                item["chapter"],
                item["verse"],
                item["text"],
                item.get("testament"),
                item.get("heading")
            ) for item in bible_data
        ])

    # 3. Populate Hymns
    print(f"Loading Hymns from {HYMNS_JSON_PATH}...")
    if not os.path.exists(HYMNS_JSON_PATH):
        print(f"❌ Error: Hymns JSON file not found at {HYMNS_JSON_PATH}")
        sys.exit(1)

    with open(HYMNS_JSON_PATH, "r", encoding="utf-8") as f:
        hymns_data = json.load(f)

    hymn_list = []
    hymns_map = hymns_data.get("hymns", {})
    
    for book_key, items in hymns_map.items():
        book_label = "Gushimisha" if book_key == "gushimisha" else "Agakiza"
        print(f"Processing {len(items)} hymns for {book_label}...")
        for item in items:
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

    # 4. Populate FTS Virtual Tables for fast searching (External Content Tables)
    print("Populating FTS5 Virtual Tables...")
    cursor.execute("""
        CREATE VIRTUAL TABLE bible_verses_fts USING fts5(
            translation,
            book UNINDEXED,
            chapter UNINDEXED,
            verse UNINDEXED,
            text,
            heading,
            content='bible_verses',
            content_rowid='id'
        )
    """)
    cursor.execute("""
        INSERT INTO bible_verses_fts(rowid, translation, book, chapter, verse, text, heading)
        SELECT id, translation, book, chapter, verse, text, heading FROM bible_verses;
    """)

    cursor.execute("""
        CREATE VIRTUAL TABLE hymns_fts USING fts5(
            book UNINDEXED,
            number UNINDEXED,
            title,
            category UNINDEXED,
            lyrics,
            content='hymns',
            content_rowid='id'
        )
    """)
    cursor.execute("""
        INSERT INTO hymns_fts(rowid, book, number, title, category, lyrics)
        SELECT id, book, number, title, category, lyrics FROM hymns;
    """)

    # Commit and close transaction first
    conn.commit()

    # Optimize and compact size (must be run outside a transaction block)
    print("Vacuuming and optimizing database...")
    conn.isolation_level = None
    conn.execute("VACUUM")
    conn.isolation_level = "DEFERRED" # Restore
    conn.close()

    print(f"✅ Compilation finished! Pre-populated database saved to: {OUTPUT_DB_PATH}")
    
    db_size = os.path.getsize(OUTPUT_DB_PATH) / (1024 * 1024)
    print(f"📊 Database Size: {db_size:.2f} MB")

if __name__ == "__main__":
    main()
