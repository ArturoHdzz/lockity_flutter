class LockerConfigResponse {
  final String lockerId;
  final Map<String, String> topics;

  LockerConfigResponse({
    required this.lockerId,
    required this.topics,
  });

  factory LockerConfigResponse.fromJson(Map<String, dynamic> json) {
    final config = json['initial_config'];
    return LockerConfigResponse(
      lockerId: config['id_locker'],
      topics: Map<String, String>.from(config['topics']),
    );
  }
}