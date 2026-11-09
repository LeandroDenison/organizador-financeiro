import 'package:flutter/foundation.dart';
import 'storage_service.dart';

enum FirebaseSyncStatus {
  offlineLocal,
  connecting,
  connected,
  error,
}

class FirebaseService extends ChangeNotifier {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseSyncStatus _status = FirebaseSyncStatus.offlineLocal;
  String? _projectId;
  String? _errorMessage;
  DateTime? _lastSyncTime;

  FirebaseSyncStatus get status => _status;
  String? get projectId => _projectId;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConnected => _status == FirebaseSyncStatus.connected;

  Future<void> init() async {
    _projectId = await StorageService.getFirebaseProjectId();
    if (_projectId != null && _projectId!.isNotEmpty) {
      // If configured, simulate connection test
      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
    } else {
      _status = FirebaseSyncStatus.offlineLocal;
    }
    notifyListeners();
  }

  Future<bool> connectWithProjectId(String projectId) async {
    _status = FirebaseSyncStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Save project id locally
      await StorageService.setFirebaseProjectId(projectId.trim());
      _projectId = projectId.trim();

      // In real scenario, Firebase.initializeApp(options: ...) is invoked here
      await Future.delayed(const Duration(seconds: 1));
      _status = FirebaseSyncStatus.connected;
      _lastSyncTime = DateTime.now();
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
    await StorageService.setFirebaseProjectId(null);
    _projectId = null;
    _status = FirebaseSyncStatus.offlineLocal;
    notifyListeners();
  }

  Future<void> triggerSync() async {
    if (_status != FirebaseSyncStatus.connected) return;
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }
}
