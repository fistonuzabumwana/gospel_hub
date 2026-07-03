# Indirimbo Hymnbook Scraper - Implementation Plan

## Overview
Build a Python scraper using Playwright to extract all ~552 hymns from indirimbo.com
and save them as structured JSON files.

## Architecture
```
scraper/
├── requirements.txt          # Python dependencies
├── scrape_indirimbo.py       # Main scraper script
├── output/
│   ├── gushimisha/           # 442 hymn JSON files
│   │   ├── 001.json
│   │   └── ...
│   ├── agakiza/              # ~110 hymn JSON files
│   │   ├── 001.json
│   │   └── ...
│   └── all_hymns.json        # Combined dataset
```

## Data Format
```json
{
  "number": 1,
  "book": "Gushimisha",
  "title": "Uri Uwera Uwera",
  "slug": "uri-uwera-uwera",
  "uuid": "ff8fad55-0670-11ea-9a58-deadbe058832",
  "category": "Guhimbaza",
  "url": "https://indirimbo.com/gushimisha/uri-uwera-uwera/ff8fad55-...",
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

## Scraping Strategy
1. Visit listing pages (gushimisha?page=1..12, agakiza?page=1..N)
2. Extract all hymn links from each listing page
3. Visit each hymn page and extract: title, number, category, lyrics
4. Save individual JSON files + combined dataset
5. Rate limiting: 1-2 second delay between requests
