import 'package:flutter/material.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';

class NotificationService {
  static final List<OverlayEntry> _activeEntries = [];
  
  static void showSuccess(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showNotification(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.check_circle_outline,
      backgroundColor: Colors.green.shade600,
      iconColor: Colors.white,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showNotification(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.error_outline,
      backgroundColor: Colors.red.shade600,
      iconColor: Colors.white,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showNotification(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.warning_outlined,
      backgroundColor: Colors.orange.shade600,
      iconColor: Colors.white,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? subtitle,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showNotification(
      context,
      message: message,
      subtitle: subtitle,
      icon: Icons.info_outline,
      backgroundColor: AppColors.secondary,
      iconColor: AppColors.buttons,
      duration: duration,
    );
  }

  static void showLogoutSuccess(BuildContext context) {
    showSuccess(
      context,
      'Logout Successful',
      subtitle: 'You have been safely signed out',
      duration: const Duration(seconds: 2),
    );
  }

  static void showLogoutError(BuildContext context, {String? details}) {
    showError(
      context,
      'Logout Failed',
      subtitle: details ?? 'Please try again or restart the app',
      duration: const Duration(seconds: 4),
    );
  }

  static void showLogoutPartial(BuildContext context) {
    showWarning(
      context,
      'Partial Logout',
      subtitle: 'Logged out locally, server logout may have failed',
      duration: const Duration(seconds: 3),
    );
  }

  static void _showNotification(
    BuildContext context, {
    required String message,
    String? subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required Duration duration,
  }) {
    try {
      if (!context.mounted) return;

      final overlay = Overlay.of(context);
      
      _clearActiveNotifications();
      
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => _NotificationWidget(
          message: message,
          subtitle: subtitle,
          icon: icon,
          backgroundColor: backgroundColor,
          iconColor: iconColor,
          onDismiss: () {
            _removeEntry(overlayEntry);
          },
        ),
      );

      _activeEntries.add(overlayEntry);
      overlay.insert(overlayEntry);

      Future.delayed(duration, () {
        _removeEntry(overlayEntry);
      });
      
    } catch (e) {
      // 
    }
  }

  static void _removeEntry(OverlayEntry entry) {
    try {
      if (entry.mounted) {
        entry.remove();
      }
      _activeEntries.remove(entry);
    } catch (e) {
      //
    }
  }

  static void _clearActiveNotifications() {
    try {
      for (final entry in List.from(_activeEntries)) {
        _removeEntry(entry);
      }
      _activeEntries.clear();
    } catch (e) {
      // 
    }
  }

  static void clearAll() {
    _clearActiveNotifications();
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    try {
      await _controller.reverse();
      widget.onDismiss();
    } catch (e) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.black.withOpacity(0.3),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.message,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.subtitle!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}