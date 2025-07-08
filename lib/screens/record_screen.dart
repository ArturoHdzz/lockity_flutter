import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/models/audit_log.dart';
import 'package:lockity_flutter/models/audit_log_request.dart';
import 'package:lockity_flutter/providers/audit_log_provider.dart';
import 'package:lockity_flutter/repositories/audit_log_repository_impl.dart';
import 'package:lockity_flutter/use_cases/get_audit_logs_use_case.dart';
import 'package:lockity_flutter/repositories/audit_log_repository_mock.dart';
import 'package:lockity_flutter/core/app_config.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late final AuditLogProvider _provider;
  final _scrollController = ScrollController();
  
  final List<String> _filterOptions = [
    'All Records',
    'Last 7 days',
    'Last 30 days',
    'This month',
  ];

  String? _selectedFilter;
  DateTime? _selectedDateFrom;
  DateTime? _selectedDateTo;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
    _setupScrollListener();
    _selectedFilter = _filterOptions.first;
    _loadAuditLogs();
  }

  // void _initializeProvider() {
  //   final repository = AuditLogRepositoryImpl();
  //   _provider = AuditLogProvider(
  //     getAuditLogsUseCase: GetAuditLogsUseCase(repository),
  //   );
  //   _provider.addListener(_onProviderStateChanged);
  // }

  void _initializeProvider() {
    // SWITCH SIMPLE: Mock vs Real
    final repository = AppConfig.useMockAuditLogs 
      ? AuditLogRepositoryMock()
      : AuditLogRepositoryImpl();
      
    _provider = AuditLogProvider(
      getAuditLogsUseCase: GetAuditLogsUseCase(repository),
    );
    _provider.addListener(_onProviderStateChanged);
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreIfPossible();
      }
    });
  }

  void _onProviderStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadAuditLogs() async {
    final request = AuditLogRequest(
      dateFrom: _selectedDateFrom,
      dateTo: _selectedDateTo,
    );
    await _provider.loadAuditLogs(request: request);
  }

  Future<void> _loadMoreIfPossible() async {
    if (_provider.canLoadMore) {
      await _provider.loadMore();
    }
  }

  Future<void> _handleFilterChange(String? value) async {
    if (value == null || value == _selectedFilter) return;

    setState(() => _selectedFilter = value);

    DateTime? dateFrom;
    DateTime? dateTo;
    final now = DateTime.now();

    switch (value) {
      case 'Last 7 days':
        dateFrom = now.subtract(const Duration(days: 7));
        dateTo = now;
        break;
      case 'Last 30 days':
        dateFrom = now.subtract(const Duration(days: 30));
        dateTo = now;
        break;
      case 'This month':
        dateFrom = DateTime(now.year, now.month, 1);
        dateTo = DateTime(now.year, now.month + 1, 0);
        break;
      default:
        dateFrom = null;
        dateTo = null;
    }

    _selectedDateFrom = dateFrom;
    _selectedDateTo = dateTo;

    await _loadAuditLogs();
  }

  Future<void> _handleRefresh() async {
    await _provider.refresh();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            _provider.clearError();
            _loadAuditLogs();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderStateChanged);
    _provider.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilterDropdown(),
          const SizedBox(height: 20),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Audit Logs',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_provider.total > 0)
          Text(
            '${_provider.total} records',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.text.withOpacity(0.7),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return CustomDropdown(
      value: _selectedFilter,
      items: _filterOptions,
      hint: 'Select Time Range',
      onChanged: _handleFilterChange,
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: AppColors.text.withOpacity(0.2),
            width: 1.0,
          ),
        ),
        child: _buildContentBody(),
      ),
    );
  }

  Widget _buildContentBody() {
    if (_provider.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_provider.errorMessage != null) {
          _showErrorSnackBar(_provider.errorMessage!);
        }
      });
    }

    if (_provider.isLoading) {
      return _buildLoadingState();
    }

    if (_provider.isEmpty) {
      return _buildEmptyState();
    }

    return _buildAuditLogsList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.buttons),
          SizedBox(height: 16),
          Text(
            'Loading audit logs...',
            style: TextStyle(color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            color: AppColors.text.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No audit logs found',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.text.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All Records' 
              ? 'No audit logs available'
              : 'No records found for the selected time range',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.text.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsList() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.buttons,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _provider.auditLogs.length + (_provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _provider.auditLogs.length) {
            return _buildLoadMoreIndicator();
          }
          
          final auditLog = _provider.auditLogs[index];
          return _buildAuditLogCard(auditLog);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _provider.isLoadingMore
          ? const CircularProgressIndicator(color: AppColors.buttons)
          : TextButton(
              onPressed: _loadMoreIfPossible,
              child: Text(
                'Load More',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.buttons,
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildAuditLogCard(AuditLog auditLog) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.background.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(auditLog),
          const SizedBox(height: 8),
          _buildCardDescription(auditLog),
          if (auditLog.locker != null) ...[
            const SizedBox(height: 8),
            _buildCardLocation(auditLog.locker!),
          ],
        ],
      ),
    );
  }

  Widget _buildCardHeader(AuditLog auditLog) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(auditLog.performedBy.role),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            auditLog.performedBy.role.toUpperCase(),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            auditLog.performedBy.fullName,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          'ID: ${auditLog.id}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.text.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildCardDescription(AuditLog auditLog) {
    return Text(
      auditLog.description,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.text.withOpacity(0.9),
        height: 1.4,
      ),
    );
  }

  Widget _buildCardLocation(LockerInfo locker) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.buttons,
            size: 16,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${locker.displayName} - ${locker.fullLocation}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.text.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'user':
        return AppColors.buttons;
      case 'manager':
        return Colors.blue;
      default:
        return AppColors.background;
    }
  }
}