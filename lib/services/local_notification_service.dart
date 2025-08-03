import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      await _createNotificationChannel();
      
      print('✅ LocalNotificationService inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando LocalNotificationService: $e');
    }
  }
  
  static Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Canal para notificaciones importantes de Lockity',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );
      
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      
      print('✅ Canal de notificaciones creado: ${channel.id}');
    } catch (e) {
      print('❌ Error creando canal de notificaciones: $e');
    }
  }
  
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('👆 Notificación tocada: ${notificationResponse.payload}');
  }
  
  static Future<void> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        final bool? result = await androidImplementation?.requestNotificationsPermission();
        print('🔔 Permisos de notificaciones locales: $result');
      }
      
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      print('🔔 Permisos FCM: ${settings.authorizationStatus}');
      print('🔔 Alert: ${settings.alert}');
      print('🔔 Badge: ${settings.badge}');
      print('🔔 Sound: ${settings.sound}');
    } catch (e) {
      print('❌ Error solicitando permisos: $e');
    }
  }
  
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      print('📳 Intentando mostrar notificación: $title - $body');
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'Canal para notificaciones importantes',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        ticker: 'Nueva notificación de Lockity',
      );
      
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      
      print('✅ Notificación mostrada correctamente');
    } catch (e) {
      print('❌ Error mostrando notificación: $e');
    }
  }
}