class HymnCategory {
  final int? id;
  final String categoryNameEn;
  final String categoryNameKinyarwanda;
  final String categoryNameFrench;

  HymnCategory({
    this.id,
    required this.categoryNameEn,
    required this.categoryNameKinyarwanda,
    required this.categoryNameFrench,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_name_en': categoryNameEn,
      'category_name_kinyarwanda': categoryNameKinyarwanda,
      'category_name_french': categoryNameFrench,
    };
  }

  factory HymnCategory.fromMap(Map<String, dynamic> map) {
    return HymnCategory(
      id: map['id'],
      categoryNameEn: map['category_name_en'],
      categoryNameKinyarwanda: map['category_name_kinyarwanda'],
      categoryNameFrench: map['category_name_french'],
    );
  }
}