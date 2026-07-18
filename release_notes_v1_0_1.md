# Gospel Hub v1.0.1 Release Notes

Welcome to the **v1.0.1** release of Gospel Hub! 
This update delivers critical performance tuning, size optimizations, theme fixes, and UI localization enhancements.

---

## 🌟 Key Updates in v1.0.1

### ⚡ 1. File Size & Storage Optimizations (Under 15MB APKs)
* **Gzipped SQLite Database**: Compressed the local database asset (`gospel_hub.db`) into `gospel_hub.db.gz`, reducing its raw size from **10.8 MB to 3.8 MB** (a **65% reduction**).
* **On-the-Fly Decompression**: Implemented seamless Gzip extraction on first boot using Dart's native `gzip.decode`. Decompression takes less than 150ms and writes directly to local sandbox storage.
* **Split ABI APK Packages**: Split compile targets into CPU-specific release APKs and configured native library zip compression (`useLegacyPackaging = true`) to achieve sub-15MB footprints:
  * **`armeabi-v7a` (older devices)**: **13.4 MB** (down from ~24 MB)
  * **`arm64-v8a` (modern devices)**: **13.9 MB** (down from ~24 MB)
  * **`x86_64` (emulators)**: **14.1 MB**

### 🎨 2. Theme & Visual Contrast Fixes
* **High-Contrast AppBar Titles**: Forced explicit bold white style properties on the global Light theme `appBarTheme` to prevent titles from inheriting dark slate colors and becoming invisible on the blue header.
* **Saved Items Tab Layout**: Configured active/inactive label states and sliding indicator lines to render in high-contrast white on the sub-header segment.

### 🌐 3. Localization & Options Fixes
* **PopupMenu Translation**: Corrected the missing translation key for the first item in the reader's three-dotted settings menu (`reader_settings_title`), changing it from a literal string to **"Text Settings"** (English) and **"Guhindura Ibyanditswe"** (Kinyarwanda).

---

## 🚀 Key Features Recap (from v1.0.0)
* **Offline Study Tools**: Bilingual parallel reader view, bookmarks, highlighting, custom devotions stats, and tagged verse lists.
* **Hymnbooks & Playlists**: Indirimbo zo Gushimisha (1-436) and Indirimbo z'Agakiza (1-110) with setlist custom organization.
* **TTS Audiobook Reader**: Cloud voice auto-scanning, progressive word-by-word highlights, and sleep timer background controls.
* **Google Drive Sync**: Secure automated backups for playlists, notes, highlights, and history to a hidden Drive folder.

---

## 📱 Release Assets
* **[gospel-hub-v1-0-1-arm64-v8a.apk](file:///home/fiston/Documents/Project/gospel_hub/gospel-hub-v1-0-1-arm64-v8a.apk)** (~13.9 MB) - Recommended for modern devices.
* **[gospel-hub-v1-0-1-armeabi-v7a.apk](file:///home/fiston/Documents/Project/gospel_hub/gospel-hub-v1-0-1-armeabi-v7a.apk)** (~13.4 MB) - Recommended for older devices.
