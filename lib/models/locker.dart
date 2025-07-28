import 'compartment.dart';

class Locker {
  final int id;
  final int organizationId;
  final int areaId;
  final int lockerNumber;
  final String organizationName;
  final String areaName;
  final String serialNumber;
  final String status;
  final List<Compartment> compartments;

  const Locker({
    required this.id,
    required this.organizationId,
    required this.areaId,
    required this.lockerNumber,
    required this.organizationName,
    required this.areaName,
    required this.serialNumber,
    required this.status,
    this.compartments = const [],
  });

  factory Locker.fromJson(Map<String, dynamic> json) {
    final id = json['locker_id'] ?? json['id'];
    final serial = json['serial_number'] ?? json['locker_serial_number'] ?? '';
    final compartmentsList = json['compartments'] as List<dynamic>? ?? [];
    final userId = _parseInt(json['user_id']);
    return Locker(
      id: _parseInt(id),
      organizationId: _parseInt(json['organization_id']),
      areaId: _parseInt(json['area_id']),
      lockerNumber: _parseInt(json['locker_number']),
      organizationName: _parseString(json['organization_name']),
      areaName: _parseString(json['area_name']),
      serialNumber: _parseString(serial),
      status: _parseString(json['status']),
      compartments: compartmentsList.map((c) => Compartment.fromJson(c, userId)).toList(),
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
      'organization_id': organizationId,
      'area_id': areaId,
      'locker_number': lockerNumber,
      'organization_name': organizationName,
      'area_name': areaName,
      'serial_number': serialNumber,
    };
  }

  String get displayName => 'Locker #$lockerNumber';
  String get fullLocation => '$organizationName - $areaName';
  bool get canOperate => status != 'error' && status != 'maintenance';

  @override
  String toString() => 'Locker(id: $id, number: $lockerNumber, area: $areaName)';
}