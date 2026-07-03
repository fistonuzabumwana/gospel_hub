# 🎵 Indirimbo Hymnbook Scraper

Scrapes the complete **Indirimbo zo Gushimisha Imana n'Agakiza** hymnbook from [indirimbo.com](https://indirimbo.com) and exports structured JSON data.

## Features

- **Complete extraction**: All ~442 Gushimisha + ~110 Agakiza hymns
- **Structured JSON**: Title, number, category, and lyrics (verses + chorus)
- **Resume capability**: Interrupted? Just run again — it picks up where it left off
- **Rate limiting**: Configurable delay between requests (default: 1.5s)
- **Progress tracking**: Real-time console output with progress indicators

## Setup

```bash
cd scraper
python3 -m venv .venv
source .venv/bin/activate
pip install playwright
python -m playwright install chromium
```

## Usage

```bash
# Scrape everything
python scrape_indirimbo.py

# Scrape only Gushimisha
python scrape_indirimbo.py --book gushimisha

# Scrape only Agakiza  
python scrape_indirimbo.py --book agakiza

# Slower scraping (be polite to the server)
python scrape_indirimbo.py --delay 2.5

# Start fresh (ignore previous progress)
python scrape_indirimbo.py --no-resume

# Run with visible browser (for debugging)
python scrape_indirimbo.py --headed
```

## Output Structure

```
output/
├── gushimisha/          # Individual hymn files
│   ├── 001.json
│   ├── 002.json
│   └── ...
├── agakiza/
│   ├── 001.json
│   └── ...
├── gushimisha_all.json  # All Gushimisha hymns combined
├── agakiza_all.json     # All Agakiza hymns combined
└── all_hymns.json       # Complete dataset with metadata
```

## JSON Format (Individual Hymn)

```json
{
  "number": 149,
  "book": "Gushimisha",
  "title": "Mbega Urukundo rw'Imana",
  "slug": "mbega-urukundo-rw-imana",
  "uuid": "ff8fad55-0670-11ea-9a58-deadbe058832",
  "category": "Urukundo rw'Imana",
  "url": "https://indirimbo.com/gushimisha/...",
  "lyrics": [
    {
      "type": "verse",
      "number": 1,
      "lines": ["Line 1", "Line 2", "..."]
    },
    {
      "type": "chorus",
      "lines": ["Chorus line 1", "..."]
    }
  ]
}
```

## Combined Dataset Format (`all_hymns.json`)

```json
{
  "metadata": {
    "source": "indirimbo.com",
    "scraped_at": "2025-07-03T04:30:00",
    "total_hymns": 552,
    "books": {
      "gushimisha": 442,
      "agakiza": 110
    }
  },
  "hymns": {
    "gushimisha": [...],
    "agakiza": [...]
  }
}
```

## Tech Stack

- **Python 3.10+**
- **Playwright** (browser automation — needed because indirimbo.com blocks plain HTTP requests)
