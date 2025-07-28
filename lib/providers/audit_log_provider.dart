import 'package:flutter/foundation.dart';
import 'package:lockity_flutter/models/audit_log.dart';
import 'package:lockity_flutter/models/audit_log_request.dart';
import 'package:lockity_flutter/models/audit_log_response.dart';
import 'package:lockity_flutter/use_cases/get_audit_logs_use_case.dart';

enum AuditLogState { initial, loading, loaded, loadingMore, error }

class AuditLogProvider extends ChangeNotifier {
  final GetAuditLogsUseCase _getAuditLogsUseCase;

  AuditLogProvider({
    required GetAuditLogsUseCase getAuditLogsUseCase,
  }) : _getAuditLogsUseCase = getAuditLogsUseCase;

  AuditLogState _state = AuditLogState.initial;
  List<AuditLog> _auditLogs = [];
  AuditLogRequest _currentRequest = const AuditLogRequest();
  AuditLogResponse? _lastResponse;
  String? _errorMessage;
  bool _disposed = false;

  AuditLogState get state => _state;
  List<AuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  AuditLogRequest get currentRequest => _currentRequest;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == AuditLogState.loading;
  bool get isLoadingMore => _state == AuditLogState.loadingMore;
  bool get hasError => _state == AuditLogState.error;
  bool get isEmpty => _auditLogs.isEmpty && _state == AuditLogState.loaded;
  bool get hasMore => _lastResponse?.hasNextPage ?? false;
  bool get canLoadMore => hasMore && !isLoadingMore && !isLoading;

  int get total => _lastResponse?.total ?? 0;
  int get currentPage => _lastResponse?.page ?? 1;
  int get totalPages => _lastResponse?.totalPages ?? 0;

  Future<void> loadAuditLogs({AuditLogRequest? request}) async {
    final newRequest = request ?? const AuditLogRequest();
    
    if (_state == AuditLogState.loading || _disposed) return;

    _currentRequest = newRequest;
    _setState(AuditLogState.loading);
    _clearError();
    _auditLogs.clear();

    try {
      _lastResponse = await _getAuditLogsUseCase.execute(_currentRequest);
      _auditLogs = _lastResponse?.items ?? [];
      _setState(AuditLogState.loaded);
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
    }
  }

  Future<void> loadMore() async {
    if (!canLoadMore || _disposed) return;

    _setState(AuditLogState.loadingMore);
    _clearError();

    try {
      final nextPageRequest = _currentRequest.copyWith(
        page: currentPage + 1,
      );

      final response = await _getAuditLogsUseCase.execute(nextPageRequest);
      
      _auditLogs.addAll(response.items);
      _lastResponse = response;
      _currentRequest = nextPageRequest;
      
      _setState(AuditLogState.loaded);
    } catch (e) {
      _setError(_extractUserFriendlyMessage(e.toString()));
    }
  }

  Future<void> refresh() async {
    await loadAuditLogs(request: _currentRequest.copyWith(page: 1));
  }

  Future<void> applyFilters({
    int? userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final newRequest = _currentRequest.copyWith(
      page: 1,
      userId: userId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    await loadAuditLogs(request: newRequest);
  }

  void clearFilters() {
    loadAuditLogs(request: AuditLogRequest(
      page: 1,
      limit: _currentRequest.limit,
    ));
  }

  void clearError() {
    _clearError();
    if (_state == AuditLogState.error) {
      _setState(_auditLogs.isNotEmpty ? AuditLogState.loaded : AuditLogState.initial);
    }
  }

  void reset() {
    _auditLogs.clear();
    _lastResponse = null;
    _currentRequest = const AuditLogRequest();
    _errorMessage = null;
    _setState(AuditLogState.initial);
  }

  String _extractUserFriendlyMessage(String error) {
    return error
      .replaceAll('AuditLogRepositoryException: ', '')
      .replaceAll('Exception: ', '');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setState(AuditLogState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  void _setError(String error) {
    if (_disposed) return;
    _errorMessage = error;
    _setState(AuditLogState.error);
  }

  void _clearError() {
    if (_disposed) return;
    _errorMessage = null;
  }
}