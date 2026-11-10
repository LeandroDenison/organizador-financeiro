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
  String? matchedPersonName;
  bool isDebtAbatementCandidate;
  final bool isDdaBoleto;
  final String? ddaBeneficiary;
  final DateTime? ddaDueDate;
  final String? ddaSignature;
  bool isDuplicateDda;
  String? duplicateOfBank;
  String? duplicateOfId;
  String? notes;

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
    this.matchedPersonName,
    this.isDebtAbatementCandidate = false,
    this.isDdaBoleto = false,
    this.ddaBeneficiary,
    this.ddaDueDate,
    this.ddaSignature,
    this.isDuplicateDda = false,
    this.duplicateOfBank,
    this.duplicateOfId,
    this.notes,
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
      'matchedPersonName': matchedPersonName,
      'isDebtAbatementCandidate': isDebtAbatementCandidate,
      'isDdaBoleto': isDdaBoleto,
      'ddaBeneficiary': ddaBeneficiary,
      'ddaDueDate': ddaDueDate?.toIso8601String(),
      'ddaSignature': ddaSignature,
      'isDuplicateDda': isDuplicateDda,
      'duplicateOfBank': duplicateOfBank,
      'duplicateOfId': duplicateOfId,
      'notes': notes,
    };
  }

  factory NotificationEventModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDueDate;
    if (map['ddaDueDate'] != null) {
      parsedDueDate = DateTime.tryParse(map['ddaDueDate'] as String);
    }

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
      matchedPersonName: map['matchedPersonName'] as String?,
      isDebtAbatementCandidate: map['isDebtAbatementCandidate'] as bool? ?? false,
      isDdaBoleto: map['isDdaBoleto'] as bool? ?? false,
      ddaBeneficiary: map['ddaBeneficiary'] as String?,
      ddaDueDate: parsedDueDate,
      ddaSignature: map['ddaSignature'] as String?,
      isDuplicateDda: map['isDuplicateDda'] as bool? ?? false,
      duplicateOfBank: map['duplicateOfBank'] as String?,
      duplicateOfId: map['duplicateOfId'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
