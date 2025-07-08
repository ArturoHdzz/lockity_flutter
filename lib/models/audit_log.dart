class AuditLog {
  final int id;
  final UserInfo performedBy;
  final LockerInfo? locker;
  final UserInfo? targetUser;
  final String description;

  const AuditLog({
    required this.id,
    required this.performedBy,
    this.locker,
    this.targetUser,
    required this.description,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: _parseInt(json['id']),
      performedBy: UserInfo.fromJson(json['performed_by'] ?? {}),
      locker: json['locker'] != null ? LockerInfo.fromJson(json['locker']) : null,
      targetUser: json['target_user'] != null ? UserInfo.fromJson(json['target_user']) : null,
      description: _parseString(json['description']),
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
      'performed_by': performedBy.toJson(),
      'locker': locker?.toJson(),
      'target_user': targetUser?.toJson(),
      'description': description,
    };
  }

  @override
  String toString() => 'AuditLog(id: $id, description: $description)';
}

class UserInfo {
  final String fullName;
  final String email;
  final String role;

  const UserInfo({
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'email': email,
      'role': role,
    };
  }

  @override
  String toString() => 'UserInfo(name: $fullName, role: $role)';
}

class LockerInfo {
  final String serialNumber;
  final int numberInTheArea;
  final int? manipulatedCompartment;
  final String organizationName;
  final String areaName;

  const LockerInfo({
    required this.serialNumber,
    required this.numberInTheArea,
    this.manipulatedCompartment,
    required this.organizationName,
    required this.areaName,
  });

  factory LockerInfo.fromJson(Map<String, dynamic> json) {
    return LockerInfo(
      serialNumber: json['serial_number']?.toString() ?? '',
      numberInTheArea: AuditLog._parseInt(json['number_in_the_area']),
      manipulatedCompartment: json['manipulated_compartment'] != null 
        ? AuditLog._parseInt(json['manipulated_compartment']) 
        : null,
      organizationName: json['organization_name']?.toString() ?? '',
      areaName: json['area_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serial_number': serialNumber,
      'number_in_the_area': numberInTheArea,
      'manipulated_compartment': manipulatedCompartment,
      'organization_name': organizationName,
      'area_name': areaName,
    };
  }

  String get displayName => 'Locker #$numberInTheArea';
  String get fullLocation => '$organizationName - $areaName';

  @override
  String toString() => 'LockerInfo(serial: $serialNumber, area: $areaName)';
}