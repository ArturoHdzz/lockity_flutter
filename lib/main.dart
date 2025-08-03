import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lockity_flutter/services/fcm_token_storage.dart';
import 'package:lockity_flutter/services/local_notification_service.dart';
import 'package:lockity_flutter/services/push_notification_service.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockity_flutter/components/app_scaffold.dart';
import 'package:lockity_flutter/components/connectivity_wrapper.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_config.dart'; 
import 'package:lockity_flutter/screens/activity_auth.dart';
import 'package:lockity_flutter/screens/home_screen.dart';
import 'package:lockity_flutter/screens/loading_screen.dart';
import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:lockity_flutter/services/navigation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lockity_flutter/services/button_cooldown_service.dart';
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📱 Mensaje en segundo plano: ${message.notification?.title}');
  
  if (message.notification != null) {
    await LocalNotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: message.notification!.title ?? 'Lockity',
      body: message.notification!.body ?? 'Nueva notificación',
      payload: jsonEncode(message.data),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: 'assets/config/.env');
    
    await Supabase.initialize(
      url: 'https://guikspbicskovcmvfvwb.supabase.co',
      anonKey: 'sb_secret_SG4tyyhGy1_1Fdmgod1a4g_VIq4pftg',
    );
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    await LocalNotificationService.initialize();
    
    await ButtonCooldownService().initialize();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    print('✅ App inicializada correctamente');
  } catch (e) {
    print('❌ Error inicializando app: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeEverything();
    });
  }

  void _initializeEverything() async {
    try {
      await LocalNotificationService.requestPermissions();
      
      await _setupFirebaseMessaging();
      
      print('✅ Inicialización completa');
    } catch (e) {
      print('❌ Error en inicialización: $e');
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      print('🔑 FCM Token: $token');
      
      if (token != null) {
        _registerTokenInBackground(token);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Mensaje en primer plano: ${message.notification?.title}');
        
        if (message.notification != null) {
          LocalNotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: message.notification!.title ?? 'Lockity',
            body: message.notification!.body ?? 'Nueva notificación',
            payload: jsonEncode(message.data),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App abierta desde notificación');
        _handleNotificationTap(message);
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
        print('🔄 Token actualizado: $fcmToken');
        _registerTokenInBackground(fcmToken);
      });
      
    } catch (e) {
      print('❌ Error configurando FCM: $e');
    }
  }

  void _registerTokenInBackground(String newToken) async {
    try {
      String? oldToken = await FcmTokenStorage.getToken();
      final accessToken = await OAuthService.getAccessToken();
      final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

      if (accessToken != null && accessToken.isNotEmpty) {
        if (oldToken != null && oldToken != newToken) {
          await PushNotificationService.unregisterToken(
            token: oldToken,
            accessToken: accessToken,
          );
        }
        
        final registered = await PushNotificationService.registerToken(
          token: newToken,
          accessToken: accessToken,
          platform: platform,
        );
        
        if (registered) {
          await FcmTokenStorage.saveToken(newToken);
          print('✅ Token FCM registrado correctamente en backend');
        } else {
          print('❌ Error registrando el token FCM en backend');
        }
      }
    } catch (e) {
      print('❌ Error registrando token FCM: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Procesando tap en notificación: ${message.data}');
    
    Future.microtask(() {
      if (message.data.containsKey('screen')) {
        switch (message.data['screen']) {
          case 'home':
            NavigationService.setCurrentScreen(NavigationScreen.home);
            break;
          case 'profile':
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.primary,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
      ),
      home: ConnectivityWrapper(
        child: FutureBuilder<bool>(
          future: _checkAuthWithTimeout(),
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return const LoadingScreen(
                  message: 'Initializing Lockity',
                  subtitle: 'Verifying security credentials...',
                );
              case ConnectionState.done:
                if (snapshot.data == true) {
                  NavigationService.setCurrentScreen(NavigationScreen.home);
                  return const AppScaffold(
                    showDrawer: true,
                    body: HomeScreen(),
                  );
                } else {
                  return const AppScaffold(
                    showDrawer: false,
                    body: ActivityAuth(showRegistrationSuccess: false),
                  );
                }
              default:
                return const AppScaffold(
                  showDrawer: false,
                  body: ActivityAuth(showRegistrationSuccess: false),
                );
            }
          },
        ),
      ),
    );
  }

  Future<bool> _checkAuthWithTimeout() async {
    try {
      return await OAuthService.isAuthenticated()
          .timeout(Duration(seconds: AppConfig.authTimeout));
    } catch (e) {
      print('Error verificando autenticación: $e');
      return false;
    }
  }
}