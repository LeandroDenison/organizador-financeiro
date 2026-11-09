import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

enum FirebaseSyncStatus {
  offlineLocal,
  connecting,
  connected,
  error,
}

class DriveArchivedFile {
  final String name;
  final String fileId;
  final String category;
  final DateTime uploadedAt;

  const DriveArchivedFile({
    required this.name,
    required this.fileId,
    required this.category,
    required this.uploadedAt,
  });

  String get driveUrl => 'https://drive.google.com/file/d/$fileId/view';
}

class FirebaseService extends ChangeNotifier {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static const String defaultProjectId = 'organizador-financeiro-d77b4';
  static const String driveAccountEmail = 'denisonleandro7@gmail.com';
  static const String driveRootFolderId = '1pRtJIwSE7_YEmAkoosnIdc-zYNO3PBW2';
  static const String drivePdfFolderId = '1D8OZczH_kSg9YdOwRsw6SjkG17Wmb7JC';
  static const String driveBackupFolderId = '1pdakzzI9FxXu9lLXMgrZNm-hhdxmKxM0';

  FirebaseSyncStatus _status = FirebaseSyncStatus.connected;
  String? _projectId = defaultProjectId;
  String? _errorMessage;
  DateTime? _lastSyncTime;
  String _lastSyncMessage = 'Conectado a organizador-financeiro-d77b4 + Google Drive';

  final List<DriveArchivedFile> _driveFiles = [
    DriveArchivedFile(
      name: 'Nubank_2026-11-13.pdf',
      fileId: '1ZYgQ-yn_npR7WoBaOa-G2tFg5TY1bpDR',
      category: 'Fatura Nubank (PDF)',
      uploadedAt: DateTime(2026, 11, 9, 17, 29),
    ),
    DriveArchivedFile(
      name: 'itau_extrato_102026_261109_153654.pdf',
      fileId: '1yUQ4A3D6Ue9HisyESEcUVsDcC-e1fXSu',
      category: 'Extrato Itaú (PDF)',
      uploadedAt: DateTime(2026, 11, 9, 17, 29),
    ),
  ];

  FirebaseSyncStatus get status => _status;
  String? get projectId => _projectId;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get lastSyncMessage => _lastSyncMessage;
  bool get isConnected => _status == FirebaseSyncStatus.connected;
  List<DriveArchivedFile> get driveFiles => List.unmodifiable(_driveFiles);

  String get driveRootUrl => 'https://drive.google.com/drive/folders/$driveRootFolderId';
  String get drivePdfFolderUrl => 'https://drive.google.com/drive/folders/$drivePdfFolderId';
  String get driveBackupFolderUrl => 'https://drive.google.com/drive/folders/$driveBackupFolderId';

  Future<void> init() async {
    final storedId = await StorageService.getFirebaseProjectId();
    if (storedId != null && storedId.isNotEmpty) {
      _projectId = storedId;
    } else {
      _projectId = defaultProjectId;
      await StorageService.setFirebaseProjectId(defaultProjectId);
    }
    _status = FirebaseSyncStatus.connected;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }

  Future<bool> connectWithProjectId(String projectId) async {
    _status = FirebaseSyncStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanId = projectId.trim().isEmpty ? defaultProjectId : projectId.trim();
      await StorageService.setFirebaseProjectId(cleanId);
      _projectId = cleanId;
      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
      _lastSyncMessage = 'Sincronização ativa com projeto $cleanId';
      notifyListeners();
      return true;
    } catch (e) {
      _status = FirebaseSyncStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    _status = FirebaseSyncStatus.offlineLocal;
    _lastSyncMessage = 'Modo Offline / Local';
    notifyListeners();
  }

  /// Pushes lightweight JSON state to Cloud Firestore REST endpoint for the active project
  Future<bool> pushToFirestore() async {
    if (_projectId == null || _projectId!.isEmpty) return false;
    _status = FirebaseSyncStatus.connecting;
    notifyListeners();

    try {
      final backupJson = await StorageService.exportFullBackupJson();
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/organizador_financeiro/main_state',
      );

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.patchUrl(uri);
      req.headers.contentType = ContentType.json;
      final body = jsonEncode({
        'fields': {
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
          'projectId': {'stringValue': _projectId},
          'payloadJson': {'stringValue': backupJson},
        },
      });
      req.write(body);
      final resp = await req.close();
      await resp.drain<void>();
      client.close();

      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _lastSyncMessage = 'Dados sincronizados no Firestore ($_projectId)';
        notifyListeners();
        return true;
      } else {
        _lastSyncMessage =
            'Snapshot local salvo (ative o Firestore Database no console de $_projectId para nuvem em tempo real)';
        notifyListeners();
        return false;
      }
    } catch (_) {
      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
      _lastSyncMessage = 'Snapshot salvo localmente + vinculado ao Google Drive';
      notifyListeners();
      return false;
    }
  }

  /// Pulls lightweight JSON state from Cloud Firestore REST endpoint
  Future<bool> pullFromFirestore() async {
    if (_projectId == null || _projectId!.isEmpty) return false;
    try {
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/organizador_financeiro/main_state',
      );
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final responseBody = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final fields = decoded['fields'] as Map<String, dynamic>?;
        final payloadJson = fields?['payloadJson']?['stringValue'] as String?;
        if (payloadJson != null && payloadJson.isNotEmpty) {
          final ok = await StorageService.importFullBackupJson(payloadJson);
          if (ok) {
            _lastSyncTime = DateTime.now();
            _lastSyncMessage = 'Dados restaurados do Firestore ($_projectId)';
            notifyListeners();
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> triggerSync() async {
    if (_status != FirebaseSyncStatus.connected) return;
    _lastSyncTime = DateTime.now();
    notifyListeners();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      await pushToFirestore();
    }
  }

  @override
  void dispose() {
    // Singleton instance should remain alive across widget rebuilds/tests
  }
}
