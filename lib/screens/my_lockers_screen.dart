import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/components/locker_card.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/models/locker.dart';
import 'package:lockity_flutter/models/compartment.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/repositories/locker_repository_impl.dart';
import 'package:lockity_flutter/models/locker_response.dart';

class MyLockersScreen extends StatefulWidget {
  const MyLockersScreen({super.key});

  @override
  State<MyLockersScreen> createState() => _MyLockersScreenState();
}

class _MyLockersScreenState extends State<MyLockersScreen> {
  final _lockerRepo = LockerRepositoryImpl();
  List<Locker> _lockers = [];
  Locker? _selectedLocker;
  List<Compartment> _compartments = [];
  bool _loadingLockers = true;
  bool _loadingCompartments = false;

  @override
  void initState() {
    super.initState();
    _fetchLockers();
  }

  Future<void> _fetchLockers() async {
    setState(() {
      _loadingLockers = true;
    });
    try {
      final response = await _lockerRepo.getLockers(const LockerListRequest());
      setState(() {
        _lockers = response.items;
        _selectedLocker = _lockers.isNotEmpty ? _lockers.first : null;
      });
      // NO llames a _fetchCompartments aquí
    } catch (e) {
      setState(() {
        _lockers = [];
        _selectedLocker = null;
      });
    } finally {
      setState(() {
        _loadingLockers = false;
      });
    }
  }

  void _handleLockerChange(String? serialNumber) async {
    final locker = _lockers.firstWhere((l) => l.serialNumber == serialNumber, orElse: () => _lockers.first);
    setState(() {
      _selectedLocker = locker;
      // Ya NO llames a _fetchCompartments(locker.id);
      // Los compartimentos ya están en locker.compartments
    });
  }

  void _handleLockerAction(String lockerNumber, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action action for $lockerNumber'),
        backgroundColor: AppColors.buttons,
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
          Text(
            'My Lockers',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _loadingLockers
              ? const CircularProgressIndicator()
              : CustomDropdown(
                  value: _selectedLocker?.serialNumber,
                  items: _lockers.map((l) => l.serialNumber).toList(),
                  hint: 'Select Locker',
                  onChanged: (newValue) => _handleLockerChange(newValue),
                ),
          const SizedBox(height: 24),
          Expanded(
            child: (_selectedLocker?.compartments.isEmpty ?? true)
                ? const Center(child: Text('No compartments assigned'))
                : ListView.builder(
                    itemCount: _selectedLocker!.compartments.length,
                    itemBuilder: (context, index) {
                      final comp = _selectedLocker!.compartments[index];
                      return LockerCard(
                        lockerNumber: 'Compartment #${comp.compartmentNumber}',
                        organization: _selectedLocker?.organizationName ?? '',
                        area: _selectedLocker?.areaName ?? '',
                        onTap: () => _handleLockerAction('Compartment #${comp.compartmentNumber}', 'Check'),
                        onBiometric: () => _handleLockerAction('Compartment #${comp.compartmentNumber}', 'Biometric'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}