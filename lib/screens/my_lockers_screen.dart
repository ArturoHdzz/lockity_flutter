import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/components/locker_card.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/models/locker.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/repositories/locker_repository_impl.dart';
import 'package:lockity_flutter/screens/fingerprint_registration_screen.dart';
import 'package:lockity_flutter/screens/record_screen.dart';

import '../services/oauth_service.dart';

class MyLockersScreen extends StatefulWidget {
  const MyLockersScreen({super.key});

  @override
  State<MyLockersScreen> createState() => _MyLockersScreenState();
}

class _MyLockersScreenState extends State<MyLockersScreen> {
  final _lockerRepo = LockerRepositoryImpl();
  List<Locker> _lockers = [];
  Locker? _selectedLocker;
  bool _loadingLockers = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _waitForAuthAndFetchLockers();
  }

  Future<void> _waitForAuthAndFetchLockers() async {
    for (int i = 0; i < 10; i++) {
      final token = await OAuthService.getStoredToken();
      if (token != null) {
        await _fetchLockers();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    setState(() {
      _loadingLockers = false;
      _errorMessage = 'Failed to authenticate. Please try again.';
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchLockers() async {
    if (!mounted) return;
    
    setState(() {
      _loadingLockers = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _lockerRepo.getLockers(const LockerListRequest());
      
      if (!mounted) return;
      
      setState(() {
        _lockers = response.items;
        _selectedLocker = _lockers.isNotEmpty ? _lockers.first : null;
        _loadingLockers = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _lockers = [];
        _selectedLocker = null;
        _loadingLockers = false;
        _errorMessage = 'Failed to load lockers: ${e.toString()}';
      });
    }
  }

  void _handleLockerChange(String? serialNumber) {
    if (serialNumber == null || !mounted) return;
    
    final locker = _lockers.firstWhere(
      (l) => l.serialNumber == serialNumber, 
      orElse: () => _lockers.first
    );
    
    setState(() {
      _selectedLocker = locker;
    });
  }

  void _handleLockerAction(String lockerNumber, String action) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action action for $lockerNumber'),
        backgroundColor: AppColors.buttons,
      ),
    );
  }

  void _showFingerprintRegistration(String serialNumber, String userId, int compartmentNumber) {
    if (!mounted) return;
    
    if (serialNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid serial number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user assigned to this compartment'),
          backgroundColor: AppColors.buttons,
        ),
      );
      return;
    }

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false, 
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (BuildContext context) => FingerprintRegistrationScreen(
        serialNumber: serialNumber,
        userId: userId,
        compartmentNumber: compartmentNumber,
      ),
    ).then((result) {
      if (!mounted) return;
      
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Fingerprint registration cancelled',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: AppColors.buttons,
          ),
        );
      }
    });
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchLockers,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No lockers available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
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
    } else if (screenWidth < 600) {
      horizontalPadding = 24.0; 
    } else {
      horizontalPadding = 32.0; 
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
  Widget build(BuildContext context) {
    final responsivePadding = _getResponsivePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return SafeArea(
      child: Padding(
        padding: responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _getResponsiveSpacing(context, 20)),
            
            Flex(
              direction: screenWidth < 500 ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: screenWidth < 500 
                  ? MainAxisAlignment.start 
                  : MainAxisAlignment.spaceBetween,
              crossAxisAlignment: screenWidth < 500 
                  ? CrossAxisAlignment.start 
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'My Lockers',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (screenWidth < 500) SizedBox(height: _getResponsiveSpacing(context, 12)),
                if (_selectedLocker != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordScreen(
                            lockerSerialNumber: _selectedLocker!.serialNumber,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(
                      screenWidth < 360 ? 'Logs' : 'View Logs',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttons,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 360 ? 12 : 16, 
                        vertical: 8
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: _getResponsiveSpacing(context, 24)),
            
            if (_loadingLockers)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(_getResponsiveSpacing(context, 16)),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error, color: Colors.red.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                    if (screenWidth < 400) ...[
                      SizedBox(height: _getResponsiveSpacing(context, 12)),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _fetchLockers,
                          child: const Text('Retry'),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: _fetchLockers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            else if (_lockers.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(_getResponsiveSpacing(context, 16)),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(child: Text('No lockers available')),
                  ],
                ),
              )
            else
              CustomDropdown(
                value: _selectedLocker?.serialNumber,
                items: _lockers.map((l) => l.serialNumber).toList(),
                hint: 'Select Locker',
                onChanged: _handleLockerChange,
              ),
            
            SizedBox(height: _getResponsiveSpacing(context, 24)),
            
            Expanded(
              child: _buildCompartmentsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompartmentsList() {
    if (_loadingLockers) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }
    
    if (_lockers.isEmpty) {
      return _buildEmptyState();
    }
    
    if (_selectedLocker == null) {
      return const Center(child: Text('Please select a locker'));
    }
    
    final compartments = _selectedLocker!.compartments;
    
    if (compartments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No compartments assigned',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchLockers,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: compartments.length,
        padding: EdgeInsets.only(bottom: _getResponsiveSpacing(context, 16)),
        itemBuilder: (context, index) {
          final comp = compartments[index];
          final userId = comp.userId.toString();
          
          return Padding(
            padding: EdgeInsets.only(bottom: _getResponsiveSpacing(context, 12)),
            child: LockerCard(
              lockerNumber: 'Compartment #${comp.compartmentNumber}',
              organization: _selectedLocker?.organizationName ?? '',
              area: _selectedLocker?.areaName ?? '',
              onTap: () => _handleLockerAction(
                'Compartment #${comp.compartmentNumber}', 
                'Check'
              ),
              onBiometric: () => _showFingerprintRegistration(
                _selectedLocker!.serialNumber,
                userId,
                comp.compartmentNumber,
              ),
            ),
          );
        },
      ),
    );
  }
}