# 📖 Bibiliya Yera (Bible) Scraper

Scrapes the complete Kinyarwanda Holy Bible (**Bibiliya Yera**) from [bibiliya.com](https://bibiliya.com) and exports it to structured JSON files.

## Features

- **Zero Dependencies**: Uses Python's built-in `urllib` and `html.parser`. No external library installation or heavy browser binaries needed.
- **Section Headings**: Extracts and aligns section headers with their respective verses (e.g. "Imana irema isi n'ijuru n'ibirimo byose").
- **Robust Resuming**: If the script is interrupted, running it again skips already scraped chapters.
- **Polite Crawling**: Built-in delay (default: 1s) to avoid overwhelming the server, with automatic retry mechanisms on timeouts.
- **Flexible Options**: Scrape the entire Bible, a single book, or a specific chapter.

## Setup

No setup is required other than having Python 3 installed.

```bash
cd scraper_bible
```

## Usage

```bash
# Scrape the entire Bible (all 66 books, 1189 chapters)
python3 scrape_bible.py

# Scrape only a specific book (e.g. Genesis / Itangiriro)
python3 scrape_bible.py --book itangiriro

# Scrape only a specific chapter of a book
python3 scrape_bible.py --book rusi --chapter 1

# Configure request delay (seconds)
python3 scrape_bible.py --delay 2.0

# Start fresh, ignoring previously scraped progress
python3 scrape_bible.py --no-resume
```

## Output Structure

```
output/
├── yera/                      # Chapter JSON files grouped by book
│   ├── itangiriro/
│   │   ├── 1.json
│   │   ├── 2.json
│   │   └── ...
│   └── ...
├── bible_yera_flat.json       # Combined flat array of all verses (matches app's DB builder format)
└── bible_yera_structured.json # Combined hierarchical dataset (Books -> Chapters -> Verses)
```

## JSON Format

### Flat Array (for easy SQLite compilation)
```json
[
  {
    "language": "Kinyarwanda",
    "version": "Yera",
    "testament": "Old",
    "book": 1,
    "chapter": 1,
    "verse": 1,
    "text": "Mbere na mbere Imana yaremye ijuru n'isi.",
    "heading": "Imana irema isi n'ijuru n'ibirimo byose"
  }
]
```
