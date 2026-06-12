class Item {
  final String naam;
  final String? info;
  final String? leenkosten;
  final String? imagePath;

  Item({
    required this.naam,
    this.info,
    this.leenkosten,
    this.imagePath,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      naam: json['naam'],
      info: json['info'],
      leenkosten: json['leenkosten'],
      imagePath: json['imagePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'naam': naam,
      'info': info,
      'leenkosten': leenkosten,
      'imagePath': imagePath,
    };
  }
}
