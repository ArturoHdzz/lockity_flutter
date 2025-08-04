import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/providers/locker_provider.dart';
import 'package:lockity_flutter/repositories/locker_repository_impl.dart';
import 'package:lockity_flutter/repositories/locker_repository_mock.dart';
import 'package:lockity_flutter/use_cases/get_lockers_use_case.dart';
import 'package:lockity_flutter/use_cases/control_locker_use_case.dart';
import 'package:lockity_flutter/services/mqtt_connection_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LockerProvider _provider;
  final MqttConnectionManager _mqttManager = MqttConnectionManager();
  
  String? _lastNotificationMessage;
  DateTime? _lastNotificationTime;
  static const Duration _notificationCooldown = Duration(seconds: 3);
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  void _initializeProvider() {
    final repository = AppConfig.useMockLockers
        ? LockerRepositoryMock()
        : LockerRepositoryImpl();

    _provider = LockerProvider(
      getLockersUseCase: GetLockersUseCase(repository),
      controlLockerUseCase: ControlLockerUseCase(repository),
    );

    _provider.addListener(_onProviderStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _provider.loadLockers();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _provider.removeListener(_onProviderStateChanged);
    _provider.dispose();
    _mqttManager.dispose();
    super.dispose();
  }

  void _onProviderStateChanged() {
    if (_isDisposed || !mounted) return;
    
    setState(() {});
    
    if (_provider.compartmentStatus != null && 
        !_provider.isInCooldown && 
        !_provider.isRefreshingStatus &&
        !_provider.isOperating &&
        _shouldShowStatusNotification()) {
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) { 
          final compartmentStatus = _provider.compartmentStatus;
          if (compartmentStatus != null) {
            final message = 'Status updated: ${compartmentStatus.message}';
            _showInfoSnackBar(message);
            _updateLastNotification(message);
          }
        }
      });
    }
  }

  bool _shouldShowStatusNotification() {
    final compartmentStatus = _provider.compartmentStatus;
    if (compartmentStatus == null) return false;
    
    final currentMessage = 'Status updated: ${compartmentStatus.message}';
    final now = DateTime.now();
    
    if (_lastNotificationMessage == currentMessage && 
        _lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < _notificationCooldown) {
      return false;
    }
    
    return true;
  }

  Future<void> _handleOpen() async {
    if (!_provider.canOperate || _provider.selectedLocker == null || _provider.selectedCompartment == null) {
      _showErrorSnackBar('Please select a locker and compartment first');
      return;
    }

    final success = await _provider.openSelectedCompartment();

    if (success) {
      _showSuccessSnackBar('Opening compartment...');
    } else if (_provider.errorMessage != null) {
      _showErrorSnackBar(_provider.errorMessage!);
    }
  }

  Future<void> _handleAlarm() async {
    if (_provider.selectedLocker == null) {
      _showErrorSnackBar('Please select a locker first');
      return;
    }

    final success = await _provider.activateAlarm();
    
    if (success) {
      _showSuccessSnackBar('Alarm activated successfully');
    } else if (_provider.errorMessage != null) {
      _showErrorSnackBar(_provider.errorMessage!);
    }
  }

  Future<void> _handleTakePicture() async {
    if (_provider.selectedLocker == null) {
      _showErrorSnackBar('Please select a locker first');
      return;
    }

    final success = await _provider.takePicture();
    
    if (success) {
      _showSuccessSnackBar('Picture taken successfully');
    } else if (_provider.errorMessage != null) {
      _showErrorSnackBar(_provider.errorMessage!);
    }
  }

  Future<void> _onLockerSelected(String newValue) async {
    final selectedLocker = _provider.lockers.firstWhere(
      (locker) => '${locker.displayName} - ${locker.areaName}' == newValue,
    );
    
    await _provider.selectLocker(selectedLocker);

    if (!AppConfig.useMockLockers) {
      await _mqttManager.connect(
        serialNumber: selectedLocker.serialNumber,
      );
    }
  }

  Future<void> _onCompartmentSelected(String newValue) async {
    final compartments = _provider.selectedLocker?.compartments ?? [];
    final selectedCompartment = compartments.firstWhere(
      (comp) => comp.displayName == newValue,
    );
    
    await _provider.selectCompartment(selectedCompartment);
  }

  Future<void> _handleToggleState() async {
    if (!_provider.canOperate) {
      if (_provider.isInCooldown) {
        _showErrorSnackBar('Please wait ${_provider.cooldownFormattedTime} before using this button again');
      } else {
        _showErrorSnackBar('Please select a locker and compartment first');
      }
      return;
    }

    _updateLastNotification('Status updated: checking...');

    final hasStatus = await _provider.refreshCompartmentStatus();
    if (!hasStatus) {
      _showErrorSnackBar('Failed to get current compartment status');
      return;
    }

    final status = _provider.compartmentStatus!;
    
    _updateLastNotification('Status updated: ${status.message}');
    
    final success = await _provider.toggleSelectedCompartment();

    if (success) {
      final action = status.isClosed ? 'Opening' : 'Closing';
      _showSuccessSnackBar('$action compartment... (Cooldown: 20s)');
    } else if (_provider.errorMessage != null) {
      _showErrorSnackBar(_provider.errorMessage!);
    }
  }

  Future<void> _handleRefreshStatus() async {
    if (_provider.selectedCompartment == null) {
      _showErrorSnackBar('Please select a compartment first');
      return;
    }

    final success = await _provider.refreshCompartmentStatus();
    if (success) {
      final compartmentStatus = _provider.compartmentStatus;
      if (compartmentStatus != null) {
        final message = 'Status refreshed: ${compartmentStatus.message}'; // 🔧 Cambiar texto
        _showSuccessSnackBar(message);
        _updateLastNotification('Status updated: ${compartmentStatus.message}');
      }
    } else {
      _showErrorSnackBar('Failed to refresh compartment status');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.buttons,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            if (_provider.hasError) {
              _provider.clearError();
              _provider.loadLockers();
            }
          },
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateLastNotification(String message) {
    _lastNotificationMessage = message;
    _lastNotificationTime = DateTime.now();
  }

  EdgeInsets _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    double horizontalPadding;
    if (screenWidth < 360) {
      horizontalPadding = 16.0;
    } else if (screenWidth < 400) {
      horizontalPadding = 24.0;
    } else if (screenWidth < 600) {
      horizontalPadding = 32.0;
    } else {
      horizontalPadding = 40.0;
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
      return baseSpacing * 0.6;
    } else if (screenHeight < 700) {
      return baseSpacing * 0.8;
    } else {
      return baseSpacing;
    }
  }

  double _getResponsiveButtonSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (screenWidth < 360 || screenHeight < 600) {
      return 140.0; 
    } else if (screenWidth < 400 || screenHeight < 700) {
      return 160.0; 
    } else {
      return 180.0; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsivePadding = _getResponsivePadding(context);
    final screenHeight = MediaQuery.of(context).size.height;
    
    return SafeArea(
      child: Padding(
        padding: responsivePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: _getResponsiveSpacing(context, 20)),
            _buildLockerDropdown(),
            SizedBox(height: _getResponsiveSpacing(context, 20)),
            _buildCompartmentDropdown(),
            SizedBox(height: _getResponsiveSpacing(context, 40)),
            
            if (screenHeight > 600) const Spacer(flex: 1),
            if (screenHeight <= 600) SizedBox(height: _getResponsiveSpacing(context, 20)),
            
            // _buildActionButtons(),
            SizedBox(height: _getResponsiveSpacing(context, 20)),
            _buildOpenButton(),
            
            if (screenHeight > 600) const Spacer(flex: 1),
            if (screenHeight <= 600) SizedBox(height: _getResponsiveSpacing(context, 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildLockerDropdown() {
    if (_provider.isLoading && _provider.lockers.isEmpty) {
      return _buildLoadingDropdown('Loading lockers...');
    }

    if (_provider.hasError) {
      return _buildErrorDropdown('Failed to load lockers');
    }

    if (_provider.isEmpty) {
      return _buildEmptyDropdown('No lockers available');
    }

    final lockerNames = _provider.lockers.map((locker) => 
      '${locker.displayName} - ${locker.areaName}'
    ).toList();

    final selectedValue = _provider.selectedLocker != null 
      ? '${_provider.selectedLocker!.displayName} - ${_provider.selectedLocker!.areaName}'
      : null;

    return CustomDropdown(
      value: selectedValue,
      items: lockerNames,
      hint: 'Select Locker',
      onChanged: (newValue) async {
        if (newValue != null) {
          await _onLockerSelected(newValue);
        }
      },
    );
  }

  Widget _buildCompartmentDropdown() {
    final locker = _provider.selectedLocker;

    if (locker == null) {
      return _buildDisabledDropdown('Select a locker first');
    }

    if (_provider.isRefreshingStatus) {
      return _buildLoadingDropdown('Loading compartment status...');
    }

    final compartments = locker.compartments;

    if (compartments.isEmpty) {
      return _buildEmptyDropdown('No compartments available');
    }

    final compartmentNames = compartments.map((compartment) => compartment.displayName).toList();
    final selectedValue = _provider.selectedCompartment?.displayName;

    return CustomDropdown(
      value: selectedValue,
      items: compartmentNames,
      hint: 'Select Compartment',
      onChanged: (newValue) async {
        if (newValue != null) {
          await _onCompartmentSelected(newValue);
        }
      },
    );
  }

  Widget _buildStatusIndicator() {
    final status = _provider.compartmentStatus!;
    final isOpen = status.isOpen;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 360 ? 8 : 12, 
        vertical: 6
      ),
      decoration: BoxDecoration(
        color: isOpen ? Colors.amber.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? Colors.amber : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.lock_open : Icons.lock,
            size: screenWidth < 360 ? 14 : 16,
            color: isOpen ? Colors.amber.shade700 : Colors.grey.shade600,
          ),
          SizedBox(width: screenWidth < 360 ? 4 : 6),
          Flexible(
            child: Text(
              'Status: ${status.message.toUpperCase()}',
              style: AppTextStyles.bodySmall.copyWith(
                color: isOpen ? Colors.amber.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: screenWidth < 360 ? 11 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: screenWidth < 360 ? 6 : 8),
          GestureDetector(
            onTap: _handleRefreshStatus,
            child: Icon(
              Icons.refresh,
              size: screenWidth < 360 ? 14 : 16,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDropdown(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 360 ? 12 : 16, 
        vertical: 12
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: screenWidth < 360 ? 14 : 16,
            height: screenWidth < 360 ? 14 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.buttons,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.text.withOpacity(0.7),
                fontSize: screenWidth < 360 ? 13 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDropdown(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 360 ? 12 : 16, 
        vertical: 12
      ),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: screenWidth < 400 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.red.shade600,
                        fontSize: screenWidth < 360 ? 13 : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    _provider.clearError();
                    _provider.loadLockers();
                  },
                  child: Text(
                    'Retry',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: Colors.red.shade600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.red.shade600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _provider.clearError();
                  _provider.loadLockers();
                },
                child: Text(
                  'Retry',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyDropdown(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 360 ? 12 : 16, 
        vertical: 12
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: screenWidth < 360 ? 14 : 16,
            color: AppColors.text.withOpacity(0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.text.withOpacity(0.7),
                fontSize: screenWidth < 360 ? 13 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledDropdown(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 360 ? 12 : 16, 
        vertical: 12
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.text.withOpacity(0.5),
          fontSize: screenWidth < 360 ? 13 : null,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_provider.selectedLocker == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = screenWidth < 360 ? 14.0 : 16.0;
    final iconSize = screenWidth < 360 ? 20.0 : 24.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.alarm,
          label: 'Alarm',
          onPressed: _provider.isOperating ? null : _handleAlarm,
          color: Colors.red,
          buttonSize: buttonSize,
          iconSize: iconSize,
        ),
        _buildActionButton(
          icon: Icons.camera_alt,
          label: 'Photo',
          onPressed: _provider.isOperating ? null : _handleTakePicture,
          color: Colors.blue,
          buttonSize: buttonSize,
          iconSize: iconSize,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required double buttonSize,
    required double iconSize,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed != null ? color : Colors.grey,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: EdgeInsets.all(buttonSize),
          ),
          child: Icon(icon, size: iconSize),
        ),
        SizedBox(height: _getResponsiveSpacing(context, 8)),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: onPressed != null ? AppColors.text : AppColors.text.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildOpenButton() {
    final canOperate = _provider.canOperate;
    final isOperating = _provider.isOperating;
    final isRefreshing = _provider.isRefreshingStatus;
    final compartmentStatus = _provider.compartmentStatus;
    final isInCooldown = _provider.isInCooldown;
    final cooldownTime = _provider.cooldownFormattedTime;
    final cooldownProgress = _provider.cooldownProgress;
    
    final buttonSize = _getResponsiveButtonSize(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    Color buttonColor;
    if (isInCooldown) {
      buttonColor = Colors.orange.shade400;
    } else if (!canOperate || isOperating || isRefreshing) {
      buttonColor = Colors.grey;
    } else if (compartmentStatus?.isOpen == true) {
      buttonColor = Colors.amber;
    } else if (compartmentStatus?.isClosed == true) {
      buttonColor = Colors.grey.shade600;
    } else {
      buttonColor = Colors.grey.shade400;
    }
    
    String? buttonText;
    if (!isInCooldown) {
      if (isRefreshing) {
        buttonText = 'Checking...';
      } else if (isOperating) {
        buttonText = 'Operating...';
      } else if (compartmentStatus?.isOpen == true) {
        buttonText = 'Open';
      } else if (compartmentStatus?.isClosed == true) {
        buttonText = 'Closed';
      } else {
        buttonText = 'Unknown';
      }
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isInCooldown) ...[
              SizedBox(
                width: buttonSize + 10,
                height: buttonSize + 10,
                child: CircularProgressIndicator(
                  value: 1 - cooldownProgress,
                  strokeWidth: screenWidth < 360 ? 4 : 5,
                  backgroundColor: Colors.orange.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300),
                ),
              ),
            ],
            
            GestureDetector(
              onTap: canOperate && !isOperating && !isRefreshing && !isInCooldown ? _handleToggleState : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: canOperate && !isOperating && !isRefreshing && !isInCooldown ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ] : [],
                ),
                child: _buildButtonContent(
                  isOperating: isOperating,
                  isRefreshing: isRefreshing,
                  isInCooldown: isInCooldown,
                  canOperate: canOperate,
                  cooldownTime: cooldownTime,
                  buttonSize: buttonSize,
                ),
              ),
            ),
          ],
        ),
        
        if (buttonText != null) ...[
          SizedBox(height: _getResponsiveSpacing(context, 16)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              buttonText,
              style: AppTextStyles.headingSmall.copyWith(
                color: canOperate && !isInCooldown ? AppColors.text : AppColors.text.withOpacity(0.5),
                fontWeight: FontWeight.w600,
                fontSize: screenWidth < 360 ? 16 : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildButtonContent({
    required bool isOperating,
    required bool isRefreshing,
    required bool isInCooldown,
    required bool canOperate,
    required String cooldownTime,
    required double buttonSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (isOperating || isRefreshing) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: screenWidth < 360 ? 2 : 3,
        ),
      );
    }
    
    if (isInCooldown) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer,
            color: Colors.white,
            size: buttonSize * 0.35, 
          ),
          SizedBox(height: buttonSize * 0.05),
          Text(
            cooldownTime,
            style: AppTextStyles.headingSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: screenWidth < 360 ? 14 : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    return Icon(
      Icons.power_settings_new,
      color: canOperate ? Colors.white : Colors.white.withOpacity(0.5),
      size: buttonSize * 0.55, 
    );
  }
}