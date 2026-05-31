

class SharedResource {
  final String id;
  final String name;
  final String path; // Local path or placeholder
  final String senderId;
  final String senderName;
  final int size; // bytes
  final DateTime timestamp;

  SharedResource({
    required this.id,
    required this.name,
    required this.path,
    required this.senderId,
    required this.senderName,
    required this.size,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'senderId': senderId,
    'senderName': senderName,
    'size': size,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SharedResource.fromJson(Map<String, dynamic> json) => SharedResource(
    id: json['id'],
    name: json['name'],
    path: json['path'] ?? '',
    senderId: json['senderId'],
    senderName: json['senderName'],
    size: json['size'] ?? 0,
    timestamp: DateTime.parse(json['timestamp']),
  );
}
