import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lockity_flutter/services/fcm_token_storage.dart';
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Mensaje recibido en segundo plano: ${message.messageId}');
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

    await ButtonCooldownService().initialize();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('Error inicializando Firebase: $e');
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
      _initializeFirebaseMessagingAsync();
    });
  }

  void _initializeFirebaseMessagingAsync() async {
    try {
      await _initializeFirebaseMessaging();
    } catch (e) {
      print('Error inicializando FCM: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error configurando notificaciones: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true, 
      sound: true,
    );

    print('Permisos de notificación: ${settings.authorizationStatus}');

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await _waitForApnsTokenWithTimeout();
    }

    _setupMessageHandlers();
    
    await _getFCMTokenAsync();
  }

  Future<void> _waitForApnsTokenWithTimeout() async {
    try {
      print('Esperando token APNS...');
      String? apnsToken;
      int attempts = 0;
      const maxAttempts = 5;
      
      while (apnsToken == null && attempts < maxAttempts) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken()
            .timeout(const Duration(seconds: 2));
        if (apnsToken != null) {
          print('Token APNS obtenido correctamente');
          break;
        }
        
        attempts++;
        print('Intento $attempts/$maxAttempts - Esperando token APNS...');
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      if (apnsToken == null) {
        print('Advertencia: No se pudo obtener el token APNS después de $maxAttempts intentos');
      }
    } catch (e) {
      print('Error obteniendo APNS token: $e');
    }
  }

  Future<void> _getFCMTokenAsync() async {
    try {
      String? newToken = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 10));
          
      print('Token FCM para pruebas: $newToken');
      
      if (newToken != null) {
        _registerTokenInBackground(newToken);
      }
    } catch (e) {
      print('Error obteniendo token FCM: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      print('Token FCM actualizado: $fcmToken');
      _registerTokenInBackground(fcmToken);
    }).onError((err) {
      print('Error obteniendo token: $err');
    });
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
          print('Token FCM registrado correctamente');
        } else {
          print('Error registrando el token FCM');
        }
      }
    } catch (e) {
      print('Error registrando token FCM: $e');
    }
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje recibido en primer plano: ${message.notification?.title}');
      print('Mensaje recibido en primer plano: ${message.notification?.body}');
      print('Mensaje recibido en primer plano: ${message.notification}');
      
      if (mounted) {
        _handleForegroundMessage(message);
      }
    }, onError: (error) {
      print('Error en onMessage: $error');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App abierta desde notificación: ${message.notification?.title}');
      if (mounted) {
        _handleNotificationTap(message);
      }
    }, onError: (error) {
      print('Error en onMessageOpenedApp: $error');
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && mounted) {
        print('App iniciada desde notificación: ${message.notification?.title}');
        _handleNotificationTap(message);
      }
    }).catchError((error) {
      print('Error en getInitialMessage: $error');
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      _showInAppNotification(message);
    } else {
      print('Push recibida pero sin contenido de notificación.');
    }
  }

  void _showInAppNotification(RemoteMessage message) {
    if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.notification?.title ?? 'Nueva notificación',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Procesando tap en notificación: ${message.data}');
    
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen(
                message: 'Initializing Lockity',
                subtitle: 'Verifying security credentials...',
              );
            }
            if (snapshot.data == true) {
              NavigationService.setCurrentScreen(NavigationScreen.home);
              return const AppScaffold(
                showDrawer: true,
                body: HomeScreen(),
              );
            }
            return const AppScaffold(
              showDrawer: false,
              body: ActivityAuth(),
            );
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