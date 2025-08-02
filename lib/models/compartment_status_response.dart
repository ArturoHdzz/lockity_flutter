class CompartmentStatusResponse {
  final bool success;
  final String message;
  final dynamic data;

  const CompartmentStatusResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CompartmentStatusResponse.fromJson(Map<String, dynamic> json) {
    return CompartmentStatusResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'],
    );
  }

  bool get isOpen => message.toLowerCase() == 'open';
  bool get isClosed => message.toLowerCase() == 'closed';
  int get mqttValue => isClosed ? 1 : 0;
}