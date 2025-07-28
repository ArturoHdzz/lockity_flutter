class LockerListRequest {
  final int page;
  final int limit;

  const LockerListRequest({
    this.page = 1,
    this.limit = 10,
  });

  Map<String, String> toQueryParameters() {
    return {
      'page': page.toString(),
      'limit': limit.toString(),
    };
  }

  LockerListRequest copyWith({int? page, int? limit}) {
    return LockerListRequest(
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

class UpdateLockerStatusRequest {
  final int lockerId;
  final String serialNumber;
  final int compartmentNumber;
  final LockerStatus status;

  const UpdateLockerStatusRequest({
    required this.lockerId,
    required this.serialNumber,
    required this.compartmentNumber,
    required this.status,
  });

  String get statusString => status.name;
}

enum LockerStatus {
  open,
  closed,
  maintenance,
  error;

  String get displayName {
    switch (this) {
      case LockerStatus.open:
        return 'Open';
      case LockerStatus.closed:
        return 'Closed';
      case LockerStatus.maintenance:
        return 'Maintenance';
      case LockerStatus.error:
        return 'Error';
    }
  }

  bool get canOperate => this != LockerStatus.error && this != LockerStatus.maintenance;
}