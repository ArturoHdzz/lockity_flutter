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
    _provider.removeListener(_onProviderStateChanged);
    _provider.dispose();
    _mqttManager.dispose();
    super.dispose();
  }

  void _onProviderStateChanged() {
    if (mounted) {
      setState(() {});
      
      if (_provider.compartmentStatus != null && 
          !_provider.isInCooldown && 
          !_provider.isRefreshingStatus &&
          !_provider.isOperating) {
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final status = _provider.compartmentStatus!.message;
          if (ScaffoldMessenger.of(context).mounted) {
            _showInfoSnackBar('Status updated: $status');
          }
        });
      }
    }
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

    final hasStatus = await _provider.refreshCompartmentStatus();
    if (!hasStatus) {
      _showErrorSnackBar('Failed to get current compartment status');
      return;
    }

    final status = _provider.compartmentStatus!;
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
      final status = _provider.compartmentStatus!.message;
      _showSuccessSnackBar('Status updated: $status');
    } else {
      _showErrorSnackBar('Failed to refresh compartment status');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.buttons,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildLockerDropdown(),
          const SizedBox(height: 20),
          _buildCompartmentDropdown(),
          const SizedBox(height: 40), 
          const Spacer(),
          _buildActionButtons(),
          const SizedBox(height: 20),
          _buildOpenButton(), 
          const Spacer(),
        ],
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

    return Column(
      children: [
        CustomDropdown(
          value: selectedValue,
          items: compartmentNames,
          hint: 'Select Compartment',
          onChanged: (newValue) async {
            if (newValue != null) {
              await _onCompartmentSelected(newValue);
            }
          },
        ),
        if (_provider.compartmentStatus != null) ...[
          const SizedBox(height: 8),
          _buildStatusIndicator(),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator() {
    final status = _provider.compartmentStatus!;
    final isOpen = status.isOpen;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            size: 16,
            color: isOpen ? Colors.amber.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            'Status: ${status.message.toUpperCase()}',
            style: AppTextStyles.bodySmall.copyWith(
              color: isOpen ? Colors.amber.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleRefreshStatus,
            child: Icon(
              Icons.refresh,
              size: 16,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDropdown(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.buttons,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.text.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDropdown(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.text.withOpacity(0.5),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.text.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledDropdown(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.background.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.text.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_provider.selectedLocker == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.alarm,
          label: 'Alarm',
          onPressed: _provider.isOperating ? null : _handleAlarm,
          color: Colors.red,
        ),
        _buildActionButton(
          icon: Icons.camera_alt,
          label: 'Photo',
          onPressed: _provider.isOperating ? null : _handleTakePicture,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed != null ? color : Colors.grey,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 8),
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
    
    String buttonText;
    if (isInCooldown) {
      buttonText = 'Wait $cooldownTime';
    } else if (isRefreshing) {
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

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isInCooldown) ...[
              SizedBox(
                width: 190,
                height: 190,
                child: CircularProgressIndicator(
                  value: 1 - cooldownProgress,
                  strokeWidth: 5,
                  backgroundColor: Colors.orange.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300),
                ),
              ),
            ],
            
            GestureDetector(
              onTap: canOperate && !isOperating && !isRefreshing && !isInCooldown ? _handleToggleState : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 180,
                height: 180,
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
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Text(
          buttonText,
          style: AppTextStyles.headingSmall.copyWith(
            color: canOperate && !isInCooldown ? AppColors.text : AppColors.text.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        
        if (isInCooldown) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  'Auto-update when ready',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        if (_provider.compartmentStatus != null && !isInCooldown) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _handleRefreshStatus,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh Status'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
              textStyle: AppTextStyles.bodySmall,
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
  }) {
    if (isOperating || isRefreshing) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
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
            size: 60,
          ),
          const SizedBox(height: 8),
          Text(
            cooldownTime,
            style: AppTextStyles.headingSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    
    return Icon(
      Icons.power_settings_new,
      color: canOperate ? Colors.white : Colors.white.withOpacity(0.5),
      size: 100,
    );
  }
}