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

  factory FingerprintMessage.fromJson(Map<String, dynamic> json) {
    return FingerprintMessage(
      config: json['config'] ?? 1,
      userId: json['user_id']?.toString() ?? '',
      stage: json['stage'] ?? '',
      status: json['status'] ?? '',
      message: json['message'] ?? '',
    );
  }
 
  Map<String, dynamic> toJson() => {
    'config': config,
    'user_id': userId,
    'stage': stage,
    'status': status,
    'message': message,
  };

  @override
  String toString() {
    return 'FingerprintMessage(config: $config, userId: $userId, stage: $stage, status: $status, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is FingerprintMessage &&
        other.config == config &&
        other.userId == userId &&
        other.stage == stage &&
        other.status == status &&
        other.message == message;
  }

  @override
  int get hashCode {
    return config.hashCode ^
        userId.hashCode ^
        stage.hashCode ^
        status.hashCode ^
        message.hashCode;
  }
}