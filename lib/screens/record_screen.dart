import 'package:flutter/material.dart';
import 'package:lockity_flutter/components/custom_dropdown.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final List<String> _descriptions = [
    'Access Log',
    'Error Log',
    'Security Log',
    'System Log',
    'User Activity',
  ];

  String? _selectedDescription2;

  @override
  void initState() {
    super.initState();
    _selectedDescription2 = _descriptions.first;
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
            'Record',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 40),
          CustomDropdown(
            value: _selectedDescription2,
            items: _descriptions,
            hint: 'Select Description',
            onChanged: (newValue) {
              setState(() {
                _selectedDescription2 = newValue;
              });
            },
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: AppColors.text.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    color: AppColors.text.withValues(alpha: 0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No records found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.text.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select filters and search to view records',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.text.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}