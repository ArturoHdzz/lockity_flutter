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
  
  @override
  void initState() {
    super.initState();
    _initializeProvider();
    _setupScrollListener();
    _loadAuditLogs();
  }

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
      lockerSerialNumber: widget.lockerSerialNumber,
    );
    await _provider.loadAuditLogs(request: request);
  }

  Future<void> _loadMoreIfPossible() async {
    if (_provider.canLoadMore) {
      await _provider.loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    await _provider.refresh();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.black), 
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.black,
          onPressed: () {
            _provider.clearError();
            _loadAuditLogs();
          },
        ),
      ),
    );
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    double horizontalPadding;
    if (screenWidth < 360) {
      horizontalPadding = 16.0;
    } else if (screenWidth < 400) {
      horizontalPadding = 20.0;
    } else {
      horizontalPadding = 24.0;
    }
    
    double verticalPadding;
    if (screenHeight < 600) {
      verticalPadding = 12.0;
    } else if (screenHeight < 700) {
      verticalPadding = 16.0;
    } else {
      verticalPadding = 20.0;
    }
    
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );
  }

  double _getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (screenHeight < 600) {
      return baseSpacing * 0.7;
    } else if (screenHeight < 700) {
      return baseSpacing * 0.85;
    } else {
      return baseSpacing;
    }
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
    final responsivePadding = _getResponsivePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: screenWidth < 360 ? Text(
          'Logs',
          style: AppTextStyles.headingSmall.copyWith(color: AppColors.text),
        ) : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: responsivePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: _getResponsiveSpacing(context, 8)),
              _buildHeader(),
              SizedBox(height: _getResponsiveSpacing(context, 16)),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return screenWidth < 500
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Access Logs',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: screenWidth < 360 ? 20 : null,
                ),
              ),
              if (_provider.total > 0) ...[
                SizedBox(height: _getResponsiveSpacing(context, 4)),
                Text(
                  '${_provider.total} records',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          )
        : Row(
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

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppColors.text.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: _buildContentBody(),
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              color: AppColors.text.withOpacity(0.5),
              size: screenWidth < 360 ? 40 : 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No audit logs found',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.text.withOpacity(0.7),
                fontSize: screenWidth < 360 ? 14 : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No audit logs available',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.text.withOpacity(0.5),
                fontSize: screenWidth < 360 ? 11 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.buttons,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(screenWidth < 360 ? 12 : 16),
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(bottom: _getResponsiveSpacing(context, 12)),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.background.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(
          horizontal: screenWidth < 360 ? 12 : 16,
          vertical: screenWidth < 360 ? 6 : 8,
        ),
        childrenPadding: EdgeInsets.symmetric(
          horizontal: screenWidth < 360 ? 12 : 16,
          vertical: screenWidth < 360 ? 6 : 8,
        ),
        title: screenWidth < 500
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: screenWidth < 360 ? 70 : 80,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth < 360 ? 6 : 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getActionColor(action),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          action.toUpperCase(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: screenWidth < 360 ? 9 : 10,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timestamp.split('T').first,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.text.withOpacity(0.7),
                              fontSize: screenWidth < 360 ? 11 : null,
                            ),
                          ),
                          if (timestamp.contains('T'))
                            Text(
                              timestamp.split('T')[1].substring(0, 5),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.text.withOpacity(0.6),
                                fontSize: screenWidth < 360 ? 10 : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w500,
                      fontSize: screenWidth < 360 ? 13 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getActionColor(action),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      action.toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
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
                        timestamp.split('T').first,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.text.withOpacity(0.7),
                        ),
                      ),
                      if (timestamp.contains('T'))
                        Text(
                          timestamp.split('T')[1].substring(0, 5),
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
          _buildExpandedContent(auditLog, screenWidth),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(AuditLog auditLog, double screenWidth) {
    final locker = auditLog.locker;
    final photoPath = auditLog.photoPath;
    final timestamp = auditLog.timestamp ?? '';
    final serial = locker?.serialNumber ?? '';
    final user = auditLog.performedBy.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Full Name:', user, screenWidth),
        _buildDetailRow('Source:', auditLog.source ?? "", screenWidth),
        _buildDetailRow('Compartment:', (locker?.manipulatedCompartment ?? "-").toString(), screenWidth),
        _buildDetailRow('Serial:', serial, screenWidth),
        _buildDetailRow('Organization:', locker?.organizationName ?? "", screenWidth),
        _buildDetailRow('Area:', locker?.areaName ?? "", screenWidth),
        _buildDetailRow('Email:', auditLog.performedBy.email, screenWidth),
        _buildDetailRow('Date:', timestamp, screenWidth),
        
        if (photoPath != null && photoPath.isNotEmpty) ...[
          SizedBox(height: _getResponsiveSpacing(context, 8)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.image, size: screenWidth < 360 ? 16 : 18),
              label: Text(
                'See image',
                style: TextStyle(fontSize: screenWidth < 360 ? 12 : 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttons,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 360 ? 8 : 12,
                  vertical: screenWidth < 360 ? 6 : 8,
                ),
              ),
              onPressed: () => _showImageDialog(photoPath),
            ),
          ),
        ],
        
        SizedBox(height: _getResponsiveSpacing(context, 8)),
        _buildCardDescription(auditLog, screenWidth),
        
        if (locker != null) ...[
          SizedBox(height: _getResponsiveSpacing(context, 8)),
          _buildCardLocation(locker, screenWidth),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(bottom: _getResponsiveSpacing(context, 4)),
      child: screenWidth < 400
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth < 360 ? 11 : null,
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: screenWidth < 360 ? 11 : null,
                  ),
                ),
              ],
            )
          : RichText(
              text: TextSpan(
                text: '$label ',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.normal,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showImageDialog(String photoPath) async {
    final signedUrl = await _getSupabaseSignedUrl(photoPath);
    if (signedUrl != null && mounted) {
      final screenSize = MediaQuery.of(context).size;
      
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
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width < 360 ? 12 : 16,
                          vertical: screenSize.width < 360 ? 24 : 32,
                        ),
                        child: InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              signedUrl,
                              fit: BoxFit.contain,
                              width: screenSize.width * (screenSize.width < 360 ? 0.9 : 0.85),
                              height: screenSize.height * (screenSize.width < 360 ? 0.7 : 0.6),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width: screenSize.width < 360 ? 100 : 120,
                                  height: screenSize.width < 360 ? 100 : 120,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: screenSize.width < 360 ? 60 : 80,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: screenSize.width < 360 ? 16 : 24,
                      right: screenSize.width < 360 ? 16 : 24,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: screenSize.width < 360 ? 28 : 32,
                        ),
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image not available')),
      );
    }
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

  Widget _buildCardDescription(AuditLog auditLog, double screenWidth) {
    return Text(
      auditLog.description,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.text.withOpacity(0.9),
        height: 1.4,
        fontSize: screenWidth < 360 ? 13 : null,
      ),
    );
  }

  Widget _buildCardLocation(LockerInfo locker, double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth < 360 ? 6 : 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: AppColors.buttons,
            size: screenWidth < 360 ? 14 : 16,
          ),
          SizedBox(width: screenWidth < 360 ? 3 : 4),
          Expanded(
            child: Text(
              '${locker.displayName} - ${locker.fullLocation}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.text.withOpacity(0.8),
                fontSize: screenWidth < 360 ? 11 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'opening':
      case 'open':
        return Colors.green;
      case 'closing':
      case 'close':
      case 'closed':
        return Colors.red;
      case 'alarm':
        return Colors.orange;
      case 'picture':
      case 'photo':
        return Colors.blue;
      default:
        return AppColors.buttons;
    }
  }
}