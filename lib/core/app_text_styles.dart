import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockity_flutter/core/app_colors.dart';

class AppTextStyles {
  // ROBOTO
  
  static TextStyle get headingLarge => GoogleFonts.roboto(
    fontSize: 48,
    fontWeight: FontWeight.w300,
    color: AppColors.text,
    letterSpacing: 1.2,
  );
  
  static TextStyle get headingMedium => GoogleFonts.roboto(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    color: AppColors.background,
    letterSpacing: 1.0,
  );
  
  static TextStyle get headingSmall => GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
  
  static TextStyle get appBarTitle => GoogleFonts.roboto(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
  
  // INTER
  
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    letterSpacing: 0.5,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );
  
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.background,
  );
  
  static TextStyle get button => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  
  static TextStyle get textField => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );
  
  static TextStyle get hintText => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.background.withValues(alpha: 0.7),
  );
  
  static TextStyle get menuItem => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );
  
  static TextStyle get menuItemLogout => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.buttons,
  );
  
  static TextStyle get dividerText => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.background,
  );
  
  static TextStyle get subtitle => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.background.withValues(alpha: 0.8),
  );
}
