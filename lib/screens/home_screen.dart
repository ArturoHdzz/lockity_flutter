import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/core/app_config.dart';
import 'package:lockity_flutter/providers/locker_provider.dart';
import 'package:lockity_flutter/repositories/locker_repository_impl.dart';
import 'package:lockity_flutter/repositories/locker_repository_mock.dart';
import 'package:lockity_flutter/use_cases/get_lockers_use_case.dart';
import 'package:lockity_flutter/use_cases/get_compartments_use_case.dart';
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

  @override
  void dispose() {
    _provider.removeListener(_onProviderStateChanged);
    _provider.dispose();
    _mqttManager.dispose();
    super.dispose();
  }

  void _initializeProvider() {
    final repository = AppConfig.useMockLockers
        ? LockerRepositoryMock()
        : LockerRepositoryImpl();

    _provider = LockerProvider(
      getLockersUseCase: GetLockersUseCase(repository),
      getCompartmentsUseCase: GetCompartmentsUseCase(repository),
      controlLockerUseCase: ControlLockerUseCase(repository),
    );

    _provider.addListener(_onProviderStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _provider.loadLockers();
      if (_provider.lockers.isNotEmpty) {
        final firstLocker = _provider.lockers.first;
        _provider.selectLocker(firstLocker);
        if (!AppConfig.useMockLockers) {
          await _mqttManager.connect(
            location: 'floor1',
            lockerId: firstLocker.id,
          );
        }
      }
    });
  }

  void _onProviderStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleOpen() async {
    if (!_provider.canOperate) {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildConnectionStatus(),
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

  Widget _buildConnectionStatus() {
    final isMock = AppConfig.useMockLockers;
    final isConnected = _mqttManager.isConnected;
    final isConnecting = _mqttManager.isConnecting;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isMock) {
      statusColor = Colors.orange;
      statusIcon = Icons.science;
      statusText = 'Mock Mode';
    } else if (isConnecting) {
      statusColor = Colors.blueGrey;
      statusIcon = Icons.sync;
      statusText = 'Connecting...';
    } else if (isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.verified_user;
      statusText = 'Connected';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.wifi_off;
      statusText = 'Disconnected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: AppTextStyles.bodySmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
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
          final selectedLocker = _provider.lockers.firstWhere(
            (locker) => '${locker.displayName} - ${locker.areaName}' == newValue,
          );
          _provider.selectLocker(selectedLocker);

          if (!AppConfig.useMockLockers) {
            await _mqttManager.connect(
              location: 'floor1', // O usa selectedLocker.areaName
              lockerId: selectedLocker.id,
            );
          }
        }
      },
    );
  }

  Widget _buildCompartmentDropdown() {
    if (_provider.selectedLocker == null) {
      return _buildDisabledDropdown('Select a locker first');
    }

    if (_provider.isLoading && _provider.compartments.isEmpty) {
      return _buildLoadingDropdown('Loading compartments...');
    }

    if (_provider.hasError) {
      return _buildErrorDropdown('Failed to load compartments');
    }

    if (_provider.compartments.isEmpty) {
      return _buildEmptyDropdown('No compartments available');
    }

    final compartmentNames = _provider.compartments.map((compartment) => 
      compartment.displayName
    ).toList();

    final selectedValue = _provider.selectedCompartment?.displayName;

    return CustomDropdown(
      value: selectedValue,
      items: compartmentNames,
      hint: 'Select Compartment',
      onChanged: (newValue) {
        if (newValue != null) {
          final selectedCompartment = _provider.compartments.firstWhere(
            (comp) => comp.displayName == newValue,
          );
          _provider.selectCompartment(selectedCompartment);
        }
      },
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
    final compartmentStatus = _provider.selectedCompartment?.status.toLowerCase();
    
    Color buttonColor;
    if (!canOperate || isOperating) {
      buttonColor = Colors.grey;
    } else if (compartmentStatus == 'open') {
      buttonColor = Colors.amber; 
    } else {
      buttonColor = Colors.grey.shade600; 
    }
    
    String buttonText;
    if (isOperating) {
      buttonText = 'Operating...';
    } else if (compartmentStatus == 'open') {
      buttonText = 'Open';
    } else if (compartmentStatus == 'closed') {
      buttonText = 'Close';
    } else {
      buttonText = 'Open';
    }

    return Column(
      children: [
        GestureDetector(
          onTap: canOperate && !isOperating ? _handleOpen : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              boxShadow: canOperate && !isOperating ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ] : [],
            ),
            child: isOperating 
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Icon(
                  Icons.power_settings_new,
                  color: canOperate ? Colors.white : Colors.white.withOpacity(0.5),
                  size: 100,
                ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          buttonText,
          style: AppTextStyles.headingSmall.copyWith(
            color: canOperate ? AppColors.text : AppColors.text.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}