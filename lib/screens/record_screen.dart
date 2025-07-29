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
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordScreen extends StatefulWidget {
  final String? lockerSerialNumber;

  const RecordScreen({super.key, this.lockerSerialNumber});

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
    print('[RecordScreen] Serial recibido: ${widget.lockerSerialNumber}');
    final request = AuditLogRequest(
      dateFrom: _selectedDateFrom,
      dateTo: _selectedDateTo,
      lockerSerialNumber: widget.lockerSerialNumber,
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: 16), 
            _buildFilterDropdown(),
            const SizedBox(height: 16),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Access Logs',
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
    final locker = auditLog.locker;
    final photoPath = auditLog.photoPath;
    final timestamp = auditLog.timestamp ?? '';
    final action = auditLog.action ?? '';
    final serial = locker?.serialNumber ?? '';
    final user = auditLog.performedBy.fullName;
    final role = auditLog.performedBy.role;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.background.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(role),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                role.toUpperCase(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  action,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text.withOpacity(0.7),
                  ),
                ),
                Text(
                  timestamp.split('T').first,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(),
          Text('Full Name: $user', style: AppTextStyles.bodySmall),
          Text('Source: ${auditLog.source}', style: AppTextStyles.bodySmall),
          Text('Compartment: ${locker?.manipulatedCompartment ?? "-"}', style: AppTextStyles.bodySmall),
          Text('Serial: $serial', style: AppTextStyles.bodySmall),
          Text('Organization: ${locker?.organizationName ?? ""}', style: AppTextStyles.bodySmall),
          Text('Area: ${locker?.areaName ?? ""}', style: AppTextStyles.bodySmall),
          Text('Email: ${auditLog.performedBy.email}', style: AppTextStyles.bodySmall),
          Text('Date: $timestamp', style: AppTextStyles.bodySmall),
          if (photoPath != null && photoPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('See image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttons,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  final signedUrl = await _getSupabaseSignedUrl(photoPath);
                  if (signedUrl != null) {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Image',
                      transitionDuration: const Duration(milliseconds: 250),
                      pageBuilder: (context, anim1, anim2) {
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            color: Colors.black.withOpacity(0.85),
                            child: Center(
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                                    child: InteractiveViewer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Image.network(
                                          signedUrl,
                                          fit: BoxFit.contain,
                                          width: MediaQuery.of(context).size.width * 0.85,
                                          height: MediaQuery.of(context).size.height * 0.6,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return SizedBox(
                                              width: 120,
                                              height: 120,
                                              child: Center(child: CircularProgressIndicator()),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image, color: Colors.white, size: 80),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 24,
                                    right: 24,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image not available')),
                    );
                  }
                },
              ),
            ),
          const SizedBox(height: 8),
          _buildCardDescription(auditLog),
          if (locker != null) ...[
            const SizedBox(height: 8),
            _buildCardLocation(locker),
          ],
        ],
      ),
    );
  }

  Future<String?> _getSupabaseSignedUrl(String photoPath) async {
    try {
      final response = await Supabase.instance.client.storage
        .from('lockity-images')
        .createSignedUrl(photoPath, 60 * 2);
      return response;
    } catch (e) {
      print('Error getting URL from Supabase: $e');
      return null;
    }
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