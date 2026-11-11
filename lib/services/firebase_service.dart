import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  String _lastSyncMessage = 'Sincronizado em tempo real (Firebase + Google Drive)';

  String? _lastSyncedUpdatedAt;
  bool _isPushing = false;
  bool _isPulling = false;
  bool _realtimeEnabled = false;
  Timer? _pollingTimer;
  Future<void> Function()? onRemoteDataReceived;

  final List<DriveArchivedFile> _driveFiles = [
    DriveArchivedFile(
      name: 'backup_organizador_financeiro.json',
      fileId: '1snfr-k-xtIa_e98U3MiWMpVG7bkDlBk7',
      category: 'Snapshot Inicial (JSON)',
      uploadedAt: DateTime(2026, 11, 9, 17, 35),
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

  Uri get _firestoreDocUri => Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/organizador_financeiro/main_state',
      );

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

  /// Starts two-way real-time synchronization between devices (e.g. Android Phone <-> Chrome Browser)
  Future<void> startRealtimeSync({
    required Future<void> Function() onRemoteUpdated,
  }) async {
    onRemoteDataReceived = onRemoteUpdated;
    _realtimeEnabled = true;

    // Perform initial reconciliation between local storage and cloud Firestore
    await _reconcileOnStartup();

    // Poll every 3 seconds for real-time cross-device updates
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_status == FirebaseSyncStatus.connected && !_isPushing && !_isPulling) {
        _pollFirestoreForUpdates();
      }
    });
  }

  Future<void> _reconcileOnStartup() async {
    try {
      final localTxs = await StorageService.loadTransactions();
      final localDebts = await StorageService.loadDebts();
      final localCount = localTxs.length + localDebts.length;

      final resp = await http.get(_firestoreDocUri).timeout(const Duration(seconds: 6));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final fields = decoded['fields'] as Map<String, dynamic>?;
        final remoteUpdatedAt = fields?['updatedAt']?['stringValue'] as String?;
        final payloadJson = fields?['payloadJson']?['stringValue'] as String?;

        if (payloadJson != null && payloadJson.isNotEmpty) {
          final remoteMap = jsonDecode(payloadJson) as Map<String, dynamic>;
          final remoteTxs = (remoteMap['transactions'] as List?)?.length ?? 0;
          final remoteDebts = (remoteMap['debts'] as List?)?.length ?? 0;
          final remoteCount = remoteTxs + remoteDebts;

          if (localCount > remoteCount) {
            // Local device (e.g., phone) has richer data than cloud -> push to cloud!
            await pushToFirestore();
          } else if (remoteCount > 0) {
            // Cloud has data (or equal/more items, e.g., fresh browser) -> pull from cloud!
            _lastSyncedUpdatedAt = remoteUpdatedAt;
            final ok = await StorageService.importFullBackupJson(payloadJson);
            if (ok) {
              _lastSyncTime = DateTime.now();
              _lastSyncMessage = 'Sincronizado em tempo real ($_projectId)';
              await onRemoteDataReceived?.call();
              notifyListeners();
            }
          }
        } else if (localCount > 0) {
          await pushToFirestore();
        }
      } else if (localCount > 0) {
        await pushToFirestore();
      }
    } catch (_) {
      // Offline or unreachable; keep local state
    }
  }

  Future<void> _pollFirestoreForUpdates() async {
    if (_isPushing || _isPulling || _projectId == null) return;
    _isPulling = true;
    try {
      final resp = await http.get(_firestoreDocUri).timeout(const Duration(seconds: 5));
      if (resp.statusCode >= 200 && resp.statusCode < 300 && !_isPushing) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final fields = decoded['fields'] as Map<String, dynamic>?;
        final remoteUpdatedAt = fields?['updatedAt']?['stringValue'] as String?;
        final payloadJson = fields?['payloadJson']?['stringValue'] as String?;

        if (remoteUpdatedAt != null &&
            payloadJson != null &&
            remoteUpdatedAt != _lastSyncedUpdatedAt) {
          _lastSyncedUpdatedAt = remoteUpdatedAt;
          final ok = await StorageService.importFullBackupJson(payloadJson);
          if (ok) {
            _lastSyncTime = DateTime.now();
            _lastSyncMessage = 'Atualizado em tempo real ($_projectId)';
            await onRemoteDataReceived?.call();
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // Ignore transient network errors during background polling
    } finally {
      _isPulling = false;
    }
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
      await pushToFirestore();
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
    _isPushing = true;

    try {
      final backupJson = await StorageService.exportFullBackupJson();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      _lastSyncedUpdatedAt = nowIso;

      final body = jsonEncode({
        'fields': {
          'updatedAt': {'stringValue': nowIso},
          'projectId': {'stringValue': _projectId},
          'payloadJson': {'stringValue': backupJson},
        },
      });

      final resp = await http
          .patch(
            _firestoreDocUri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: body,
          )
          .timeout(const Duration(seconds: 6));

      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _lastSyncMessage = 'Dados sincronizados no Firestore ($_projectId)';
        notifyListeners();
        return true;
      } else {
        _lastSyncMessage = 'Erro HTTP ${resp.statusCode} ao sincronizar com $_projectId';
        notifyListeners();
        return false;
      }
    } catch (_) {
      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
      _lastSyncMessage = 'Salvo localmente (aguardando rede para sincronizar)';
      notifyListeners();
      return false;
    } finally {
      _isPushing = false;
    }
  }

  /// Pulls lightweight JSON state from Cloud Firestore REST endpoint
  Future<bool> pullFromFirestore() async {
    if (_projectId == null || _projectId!.isEmpty) return false;
    _isPulling = true;
    try {
      final resp = await http.get(_firestoreDocUri).timeout(const Duration(seconds: 6));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final fields = decoded['fields'] as Map<String, dynamic>?;
        final remoteUpdatedAt = fields?['updatedAt']?['stringValue'] as String?;
        final payloadJson = fields?['payloadJson']?['stringValue'] as String?;
        if (payloadJson != null && payloadJson.isNotEmpty) {
          _lastSyncedUpdatedAt = remoteUpdatedAt;
          final ok = await StorageService.importFullBackupJson(payloadJson);
          if (ok) {
            _lastSyncTime = DateTime.now();
            _lastSyncMessage = 'Dados restaurados do Firestore ($_projectId)';
            await onRemoteDataReceived?.call();
            notifyListeners();
            return true;
          }
        }
      }
    } catch (_) {
    } finally {
      _isPulling = false;
    }
    return false;
  }

  Future<void> triggerSync() async {
    if (_status != FirebaseSyncStatus.connected) return;
    _lastSyncTime = DateTime.now();
    if (hasListeners) {
      notifyListeners();
    }
    if (_realtimeEnabled) {
      await pushToFirestore();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
