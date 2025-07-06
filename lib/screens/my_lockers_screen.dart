import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/components/locker_card.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class MyLockersScreen extends StatefulWidget {
  const MyLockersScreen({super.key});

  @override
  State<MyLockersScreen> createState() => _MyLockersScreenState();
}

class _MyLockersScreenState extends State<MyLockersScreen> {
  final List<String> _lockers = ['Locker 1', 'Locker 2', 'Locker 3', 'All Lockers'];
  String? _selectedLocker;

  final List<Map<String, String>> _lockerData = [
    {
      'number': 'Locker Number',
      'organization': 'Organization',
      'area': 'Area',
    },
    {
      'number': 'Locker Number',
      'organization': 'Organization',
      'area': 'Area',
    },
    {
      'number': 'Locker Number',
      'organization': 'Organization',
      'area': 'Area',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocker = _lockers.first;
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
          CustomDropdown(
            value: _selectedLocker,
            items: _lockers,
            hint: 'Select Locker',
            onChanged: (newValue) {
              setState(() {
                _selectedLocker = newValue;
              });
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _lockerData.length,
              itemBuilder: (context, index) {
                final locker = _lockerData[index];
                return LockerCard(
                  lockerNumber: locker['number']!,
                  organization: locker['organization']!,
                  area: locker['area']!,
                  onTap: () => _handleLockerAction(locker['number']!, 'Check'),
                  onBiometric: () => _handleLockerAction(locker['number']!, 'Biometric'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}