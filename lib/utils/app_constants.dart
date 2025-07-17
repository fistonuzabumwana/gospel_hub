class AppConstants {
  // Bible version mappings for API.Bible
  static const Map<String, String> bibleVersions = {
    'KJV_EN': 'de4e12af7f28f599-02', // KJV English
    'KJV_FR': 'bf8f1c7f7d27c9c4-01', // French Bible (placeholder)
    'KJV_RW': 'kinyarwanda-bible-id', // Kinyarwanda (placeholder - need actual ID)
  };

  static const Map<String, String> languageNames = {
    'en': 'English',
    'fr': 'Français',
    'rw': 'Kinyarwanda',
  };

  static const Map<String, String> bibleLanguageNames = {
    'KJV_EN': 'King James Version (English)',
    'KJV_FR': 'Bible Louis Segond (Français)',
    'KJV_RW': 'Bibiliya (Kinyarwanda)',
  };

  // Default hymn categories
  static const List<Map<String, String>> defaultHymnCategories = [
    {
      'category_name_en': 'Worship',
      'category_name_kinyarwanda': 'Gusengera',
      'category_name_french': 'Adoration',
    },
    {
      'category_name_en': 'Praise',
      'category_name_kinyarwanda': 'Gushima',
      'category_name_french': 'Louange',
    },
    {
      'category_name_en': 'Prayer',
      'category_name_kinyarwanda': 'Gusenga',
      'category_name_french': 'Prière',
    },
    {
      'category_name_en': 'Seasonal',
      'category_name_kinyarwanda': 'Ibihe',
      'category_name_french': 'Saisonnier',
    },
  ];
}