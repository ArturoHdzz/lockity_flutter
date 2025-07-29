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
    _fetchLockers();
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

  void _showFingerprintRegistration(String serialNumber, String userId) {
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
          backgroundColor: Colors.orange,
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
          const SnackBar(
            content: Text('Fingerprint registration cancelled'),
            backgroundColor: Colors.orange,
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
          Text(
            _errorMessage ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Lockers',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedLocker != null)
                IconButton(
                  icon: const Icon(Icons.list_alt, color: AppColors.buttons),
                  tooltip: 'View Logs',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecordScreen(
                          lockerSerialNumber: _selectedLocker!.serialNumber,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_loadingLockers)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchLockers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_lockers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('No lockers available'),
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
          
          const SizedBox(height: 24),
          
          Expanded(
            child: _buildCompartmentsList(),
          ),
        ],
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
            Text(
              'No compartments assigned',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
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
        itemBuilder: (context, index) {
          final comp = compartments[index];
          
          final userId = comp.userId.toString();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
              ),
            ),
          );
        },
      ),
    );
  }
}