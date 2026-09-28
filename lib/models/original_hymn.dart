import 'hymn.dart';

class OriginalHymn {
  final String songNumber;
  final String originalSearchName;
  final String language;
  final String title;
  final List<LyricsBlock> lyrics;
  final String? audioFile;
  final String? midiFile;

  OriginalHymn({
    required this.songNumber,
    required this.originalSearchName,
    required this.language,
    required this.title,
    required this.lyrics,
    this.audioFile,
    this.midiFile,
  });

  factory OriginalHymn.fromJson(Map<String, dynamic> json) {
    final rawLyrics = json['lyrics'];
    List<LyricsBlock> parsedLyrics = [];
    if (rawLyrics is List) {
      for (var item in rawLyrics) {
        if (item is Map<String, dynamic>) {
          parsedLyrics.add(LyricsBlock.fromMap(item));
        } else if (item is Map) {
          parsedLyrics.add(LyricsBlock.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return OriginalHymn(
      songNumber: json['song_number']?.toString() ?? '',
      originalSearchName: json['original_search_name']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      lyrics: parsedLyrics,
      audioFile: json['audio_file']?.toString(),
      midiFile: json['midi_file']?.toString(),
    );
  }

  /// Returns the asset path for the MIDI file suitable for AudioPlayer AssetSource
  /// e.g. "hymns/midi/277_Abide_with_me.midi"
  String? get midiAssetPath {
    if (midiFile == null || midiFile!.isEmpty) return null;
    final clean = midiFile!.startsWith('/') ? midiFile!.substring(1) : midiFile!;
    if (clean.startsWith('midi/')) {
      return 'hymns/$clean';
    }
    return 'hymns/midi/$clean';
  }
}
