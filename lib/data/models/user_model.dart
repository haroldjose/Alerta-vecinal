import 'dart:isolate';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? position;
  final String? profileImage;
  final DateTime createdAt; 

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.position,
    this.profileImage,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String,dynamic> map, String id){
    return UserModel(
      id: id, 
      name: map['name'] ?? '', 
      email: map['email'] ?? '', 
      role: map['role'] ?? 'user',
      position: map['position'],
      profileImage: map['profileImage'], 
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt']?.millisecondsSinceEpoch ?? 0,
      ),);
  }

  Map<String, dynamic> toMap(){
    return{
      'name':name,
      'email':email,
      'role':role,
      'position':position,
      'profileImage':profileImage,
      'createdAt':createdAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? position,
    String? profileImage,
    DateTime? createdAt, 
  }){
    return UserModel(
      id: id ?? this.id, 
      name: name ?? this.name, 
      email: email ?? this.email, 
      role: role ?? this.role,
      position: position ?? this.position,
      profileImage: profileImage ?? this.profileImage, 
      createdAt: createdAt ?? this.createdAt
      );
  }

  bool get isAdmin => role == 'admin';




}