# Gospel Hub 📖✨

Gospel Hub is a modern, high-performance, and feature-rich Flutter application designed for reading the Bible and singing hymns offline. It features a curated dark/light theme design system, parallel English/Kinyarwanda translations, voice narration, study tagging, setlist playlists, and reader-oriented swipe navigation.

---

## 🚀 Key Features

### 📖 Bible Reader & Parallel Translations
- **Bilingual Parallel Mode (Default)**: Stack Kinyarwanda and English King James Version (KJV) translations side-by-side on a per-verse basis.
- **Translation Switcher**: Instantly toggle between **Kinyarwanda**, **English KJV**, or **Parallel** modes.
- **Audio Voice Reader (TTS)**: Let the app read chapters aloud using device Text-to-Speech with correct local pronunciation models (`rw-RW` and `en-US`).
- **Sleep Timer**: Schedule reading to halt automatically (long press the audio play button to activate).
- **Study Tags & Notes**: Highlight verses in 8 customizable colors, add notes, and assign custom tags (e.g., *#Urukundo*, *#Ibyiringiro*) to build study guides.
- **Horizontal Swipe Navigation**: Swipe left/right on the reader screen to navigate smoothly to the previous or next chapter.

### 🎵 Hymns Library (Setlists & Categories)
- **Hymnbooks Included**: Native offline access to the complete *Gushimisha* and *Agakiza* hymnbooks.
- **Hymn Playlists (Setlists)**: Group your favorite songs together into folders (playlists) for choir practices, services, or personal devotions.
- **Category Explorer**: Browse hymns instantly by specific liturgical or thematic categories (e.g., *Noheli*, *Gusingiza*, *Gushimira*).
- **Horizontal Swipe Navigation**: Swipe left/right on lyrics to easily flip to the previous or next song in the book.

### 📊 Dashboard & Saved Items
- **Devotion Streaks**: Displays your reading streaks, total verses read, and current stats to maintain daily devotion goals.
- **Recently Read**: A quick-resume drawer letting you jump straight back into the exact book and chapter you last closed.
- **Search Engine**: Lightning-fast keyword and verse/song number queries indexing both the Bible and the hymnbooks.
- **JSON Backup & Restore**: Export all your tags, playlists, notes, highlights, and history to a single backup file and restore it on any device.

### 🎨 Design & Navigation
- **Persistent Bottom Navigation**: Seamlessly browse song details, playlists, and search categories without losing access to the bottom tab bar.
- **Fluid Material 3 Design**: Features sleek transitions, glassmorphic accents, and optimized typography (Merriweather Serif for Bible reading, Outfit for UI).

---

## 🛠️ Tech Stack & Configuration

- **Framework**: Flutter (Dart)
- **Database**: Offline SQLite database (`gospel_hub.db`) pre-seeded with both Kinyarwanda and English KJV translations, categories, and hymns metadata.
- **Build Details**: Updated wrapper configurations to support Gradle `8.14`, Kotlin `2.2.20`, and Android Gradle Plugin `8.11.1` to prevent version incompatibilities.

---

## ⚙️ How to Get Started

### Prerequisites
Make sure you have Flutter SDK and Android/iOS setup installed on your system.

### Build & Run
1. Clone the repository and navigate to the project directory:
   ```bash
   flutter pub get
   ```
2. Clean and run the debug bundle:
   ```bash
   flutter clean && flutter run
   ```
3. Compile production bundles:
   ```bash
   flutter build apk --release
   ```

