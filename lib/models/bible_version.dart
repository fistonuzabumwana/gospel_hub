class BibleVersion {
  final int? id;
  final String versionCode;
  final String languageCode;
  final String displayName;
  final bool isDownloaded;
  final DateTime? downloadDate;

  BibleVersion({
    this.id,
    required this.versionCode,
    required this.languageCode,
    required this.displayName,
    this.isDownloaded = false,
    this.downloadDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version_code': versionCode,
      'language_code': languageCode,
      'display_name': displayName,
      'is_downloaded': isDownloaded ? 1 : 0,
      'download_date': downloadDate?.millisecondsSinceEpoch,
    };
  }

  factory BibleVersion.fromMap(Map<String, dynamic> map) {
    return BibleVersion(
      id: map['id'],
      versionCode: map['version_code'],
      languageCode: map['language_code'],
      displayName: map['display_name'],
      isDownloaded: map['is_downloaded'] == 1,
      downloadDate: map['download_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['download_date'])
          : null,
    );
  }
}