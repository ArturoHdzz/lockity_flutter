class Compartment {
  final int id;
  final int compartmentNumber;
  final String status;
  final List<CompartmentUser> users;

  const Compartment({
    required this.id,
    required this.compartmentNumber,
    required this.status,
    required this.users,
  });

  factory Compartment.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List<dynamic>? ?? [];
    
    return Compartment(
      id: _parseInt(json['id']),
      compartmentNumber: _parseInt(json['compartment_number']),
      status: _parseString(json['status']),
      users: usersList.map((user) => CompartmentUser.fromJson(user)).toList(),
    );
  }

  factory Compartment.fromLockerListJson(Map<String, dynamic> json) {
    return Compartment(
      id: _parseInt(json['compartment_id']),
      compartmentNumber: _parseInt(json['compartment_number']),
      status: '', 
      users: const [],
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'compartment_number': compartmentNumber,
      'status': status,
      'users': users.map((user) => user.toJson()).toList(),
    };
  }

  String get displayName => 'Compartment #$compartmentNumber';
  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get canOperate => status != 'error' && status != 'maintenance';

  @override
  String toString() => 'Compartment(id: $id, number: $compartmentNumber, status: $status)';
}

class CompartmentUser {
  final int id;
  final String name;
  final String lastName;
  final String secondLastName;
  final String email;
  final String role;

  const CompartmentUser({
    required this.id,
    required this.name,
    required this.lastName,
    required this.secondLastName,
    required this.email,
    required this.role,
  });

  factory CompartmentUser.fromJson(Map<String, dynamic> json) {
    return CompartmentUser(
      id: Compartment._parseInt(json['id']),
      name: Compartment._parseString(json['name']),
      lastName: Compartment._parseString(json['last_name']),
      secondLastName: Compartment._parseString(json['second_last_name']),
      email: Compartment._parseString(json['email']),
      role: Compartment._parseString(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'last_name': lastName,
      'second_last_name': secondLastName,
      'email': email,
      'role': role,
    };
  }

  String get fullName => '$name $lastName $secondLastName'.trim();

  @override
  String toString() => 'CompartmentUser(id: $id, name: $fullName, role: $role)';
}