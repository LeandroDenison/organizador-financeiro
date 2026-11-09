import 'package:uuid/uuid.dart';

enum NotificationStatus { pending, approved, ignored }

class NotificationEventModel {
  final String id;
  final String appPackage;
  final String bankName;
  final String rawTitle;
  final String rawText;
  final double? parsedAmount;
  final String? parsedMerchant;
  final DateTime timestamp;
  NotificationStatus status;
  final bool autoAdded;
  String? createdTransactionId;

  NotificationEventModel({
    String? id,
    required this.appPackage,
    required this.bankName,
    required this.rawTitle,
    required this.rawText,
    this.parsedAmount,
    this.parsedMerchant,
    DateTime? timestamp,
    this.status = NotificationStatus.pending,
    this.autoAdded = false,
    this.createdTransactionId,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appPackage': appPackage,
      'bankName': bankName,
      'rawTitle': rawTitle,
      'rawText': rawText,
      'parsedAmount': parsedAmount,
      'parsedMerchant': parsedMerchant,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'autoAdded': autoAdded,
      'createdTransactionId': createdTransactionId,
    };
  }

  factory NotificationEventModel.fromMap(Map<String, dynamic> map) {
    return NotificationEventModel(
      id: map['id'] as String?,
      appPackage: map['appPackage'] as String? ?? '',
      bankName: map['bankName'] as String? ?? 'Banco',
      rawTitle: map['rawTitle'] as String? ?? '',
      rawText: map['rawText'] as String? ?? '',
      parsedAmount: (map['parsedAmount'] as num?)?.toDouble(),
      parsedMerchant: map['parsedMerchant'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: NotificationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => NotificationStatus.pending,
      ),
      autoAdded: map['autoAdded'] as bool? ?? false,
      createdTransactionId: map['createdTransactionId'] as String?,
    );
  }
}
