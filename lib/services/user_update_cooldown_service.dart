import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserUpdateCooldownService extends ChangeNotifier {
  static const String _cooldownKey = 'user_update_cooldown';
  static const int _cooldownDurationMinutes = 30;
  
  Timer? _countdownTimer;
  int _remainingMinutes = 0;
  bool _isInCooldown = false;
  bool _disposed = false;
  
  static final UserUpdateCooldownService _instance = UserUpdateCooldownService._internal();
  factory UserUpdateCooldownService() => _instance;
  UserUpdateCooldownService._internal();
  
  bool get isInCooldown => _isInCooldown;
  int get remainingMinutes => _remainingMinutes;
  String get formattedTime => _formatTime(_remainingMinutes);
  
  Future<void> initialize() async {
    await _checkExistingCooldown();
  }
  
  Future<void> startCooldown() async {
    try {
      final endTime = DateTime.now().add(const Duration(minutes: _cooldownDurationMinutes));
      await _saveCooldown(endTime);
      
      _remainingMinutes = _cooldownDurationMinutes;
      _isInCooldown = true;
      
      print('🔒 UserUpdate: Cooldown iniciado por $_cooldownDurationMinutes minutos');
      
      _startCountdown();
      _notifyIfNotDisposed();
    } catch (e) {
      print('❌ UserUpdate: Error iniciando cooldown: $e');
    }
  }
  
  Future<void> _checkExistingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(_cooldownKey);
      
      if (timestampString != null) {
        final data = json.decode(timestampString) as Map<String, dynamic>;
        final endTime = DateTime.fromMillisecondsSinceEpoch(data['endTime']);
        
        final now = DateTime.now();
        
        if (now.isBefore(endTime)) {
          final remainingMs = endTime.difference(now).inMilliseconds;
          _remainingMinutes = (remainingMs / (1000 * 60)).ceil();
          _isInCooldown = true;
          
          print('🔒 UserUpdate: Cooldown activo encontrado: $_remainingMinutes minutos restantes');
          
          _startCountdown();
        } else {
          await _clearCooldown();
        }
      }
    } catch (e) {
      print('❌ UserUpdate: Error verificando cooldown existente: $e');
      await _clearCooldown();
    }
  }
  
  void _startCountdown() {
    _countdownTimer?.cancel();
    
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      
      _remainingMinutes--;
      
      if (_remainingMinutes <= 0) {
        await _finishCooldown();
      } else {
        _notifyIfNotDisposed();
      }
    });
  }
  
  Future<void> _finishCooldown() async {
    _countdownTimer?.cancel();
    _isInCooldown = false;
    _remainingMinutes = 0;
    
    await _clearCooldown();
    
    print('✅ UserUpdate: Cooldown completado - Botón habilitado');
    _notifyIfNotDisposed();
  }
  
  Future<void> _saveCooldown(DateTime endTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'endTime': endTime.millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_cooldownKey, json.encode(data));
    } catch (e) {
      print('❌ UserUpdate: Error guardando cooldown: $e');
    }
  }
  
  Future<void> _clearCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cooldownKey);
    } catch (e) {
      print('❌ UserUpdate: Error limpiando cooldown: $e');
    }
  }
  
  String _formatTime(int minutes) {
    if (minutes <= 0) return '00:00';
    
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}h';
    } else {
      return '${mins.toString().padLeft(2, '0')}m';
    }
  }
  
  void _notifyIfNotDisposed() {
    if (!_disposed) {
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    super.dispose();
  }
}