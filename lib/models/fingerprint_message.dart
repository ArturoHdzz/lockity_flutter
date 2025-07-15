class FingerprintMessage {
  final int config;
  final String userId;
  final String stage;
  final String status;
  final String message;

  const FingerprintMessage({
    required this.config,
    required this.userId,
    required this.stage,
    required this.status,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'config': config,
    'user_id': userId,
    'stage': stage,
    'status': status,
    'message': message,
  };
}