class User {
  final int id;
  final String name;
  final String lastName;
  final String secondLastName;
  final String email;
  final bool hasEmailVerified;
  final String? verificationLinkSentAt;
  final String createdAt;
  final String updatedAt;
  final List<UserRole>? roles; 

  const User({
    required this.id,
    required this.name,
    required this.lastName,
    required this.secondLastName,
    required this.email,
    required this.hasEmailVerified,
    this.verificationLinkSentAt,
    required this.createdAt,
    required this.updatedAt,
    this.roles, 
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseInt(json['id']),
      name: _parseString(json['name']),
      lastName: _parseString(json['last_name']),
      secondLastName: _parseString(json['second_last_name']),
      email: _parseString(json['email']),
      hasEmailVerified: _parseBool(json['has_email_verified']),
      verificationLinkSentAt: json['verification_link_sent_at'],
      createdAt: _parseString(json['created_at']),
      updatedAt: _parseString(json['updated_at']),
      roles: _parseRoles(json['roles']), 
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _parseString(dynamic value) {
    if (value is String) return value;
    if (value != null) return value.toString();
    return '';
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }

  static List<UserRole>? _parseRoles(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    try {
      return value.map((roleData) => UserRole.fromJson(roleData)).toList();
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'last_name': lastName,
      'second_last_name': secondLastName,
      'email': email,
      'has_email_verified': hasEmailVerified,
      'verification_link_sent_at': verificationLinkSentAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (roles != null) 'roles': roles!.map((role) => role.toJson()).toList(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? lastName,
    String? secondLastName,
    String? email,
    bool? hasEmailVerified,
    String? verificationLinkSentAt,
    String? createdAt,
    String? updatedAt,
    List<UserRole>? roles,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      secondLastName: secondLastName ?? this.secondLastName,
      email: email ?? this.email,
      hasEmailVerified: hasEmailVerified ?? this.hasEmailVerified,
      verificationLinkSentAt: verificationLinkSentAt ?? this.verificationLinkSentAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roles: roles ?? this.roles,
    );
  }

  String get fullName => '$name $lastName $secondLastName'.trim();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.lastName == lastName &&
        other.secondLastName == secondLastName &&
        other.email == email;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        lastName.hashCode ^
        secondLastName.hashCode ^
        email.hashCode;
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email)';
  }
}

class UserRole {
  final String role;
  final String? lockerSerialNumber;
  final String? areaName;
  final String? organizationName;

  const UserRole({
    required this.role,
    this.lockerSerialNumber,
    this.areaName,
    this.organizationName,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      role: json['role']?.toString() ?? '',
      lockerSerialNumber: json['locker_serial_number']?.toString(),
      areaName: json['area_name']?.toString(),
      organizationName: json['organization_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'locker_serial_number': lockerSerialNumber,
      'area_name': areaName,
      'organization_name': organizationName,
    };
  }

  @override
  String toString() {
    return 'UserRole(role: $role, organization: $organizationName)';
  }
}