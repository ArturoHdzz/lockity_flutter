import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _lockers = ['Locker 1', 'Locker 2', 'Locker 3'];
  final List<String> _drawers = ['Drawer 1', 'Drawer 2', 'Drawer 3'];

  String? _selectedLocker;
  String? _selectedDrawer;

  @override
  void initState() {
    super.initState();
    _selectedLocker = _lockers.first;
    _selectedDrawer = _drawers.first;
  }

  void _handleOpen() {
    if (_selectedLocker != null && _selectedDrawer != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening $_selectedLocker - $_selectedDrawer...'),
          backgroundColor: AppColors.buttons,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
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
          const SizedBox(height: 20),
          CustomDropdown(
            value: _selectedDrawer,
            items: _drawers,
            hint: 'Select Drawer',
            onChanged: (newValue) {
              setState(() {
                _selectedDrawer = newValue;
              });
            },
          ),
          const Spacer(),
          _buildPowerButton(),
          const SizedBox(height: 20),
          Text(
            'Open',
            style: AppTextStyles.headingSmall.copyWith(color: AppColors.text),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPowerButton() {
    return GestureDetector(
      onTap: _handleOpen,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(
          Icons.power_settings_new,
          color: AppColors.text,
          size: 100,
        ),
      ),
    );
  }
}