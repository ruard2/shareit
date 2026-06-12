class UserModel {
  final int id;
  final String name;
  final String email;
  final bool isApproved;
  final bool isAdmin;
  String? sessionId; // ✅ Nieuw veld

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isApproved,
    required this.isAdmin,
    this.sessionId, // ✅ Optioneel veld in constructor
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        isApproved: json['is_approved'] ?? false,
        isAdmin: json['is_admin'] ?? false,
      );
}
