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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Mensaje recibido en segundo plano: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/.env');
  await Supabase.initialize(
    url: 'https://guikspbicskovcmvfvwb.supabase.co',
    anonKey: 'sb_secret_SG4tyyhGy1_1Fdmgod1a4g_VIq4pftg',
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
      _initializeFirebaseMessaging();
    });
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
      await _waitForApnsToken();
    }

    await _getFCMToken();
  }

  Future<void> _waitForApnsToken() async {
    print('Esperando token APNS...');
    String? apnsToken;
    int attempts = 0;
    const maxAttempts = 10;
    
    while (apnsToken == null && attempts < maxAttempts) {
      apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        print('Token APNS obtenido correctamente');
        break;
      }
      
      attempts++;
      print('Intento $attempts/$maxAttempts - Esperando token APNS...');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (apnsToken == null) {
      print('Advertencia: No se pudo obtener el token APNS después de $maxAttempts intentos');
    }
  }

  Future<void> _getFCMToken() async {
    try {
      String? newToken = await FirebaseMessaging.instance.getToken();
      print('Token FCM para pruebas: $newToken');
      String? oldToken = await FcmTokenStorage.getToken();
      final accessToken = await OAuthService.getAccessToken();
      final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

      if (newToken != null && accessToken != null && accessToken.isNotEmpty) {
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
      print('Error gestionando token FCM: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      final accessToken = await OAuthService.getAccessToken();
      final oldToken = await FcmTokenStorage.getToken();
      final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';

      if (accessToken != null && accessToken.isNotEmpty) {
        if (oldToken != null && oldToken != fcmToken) {
          await PushNotificationService.unregisterToken(
            token: oldToken,
            accessToken: accessToken,
          );
        }
        await PushNotificationService.registerToken(
          token: fcmToken,
          accessToken: accessToken,
          platform: platform,
        );
        await FcmTokenStorage.saveToken(fcmToken);
      }
    }).onError((err) {
      print('Error obteniendo token: $err');
    });

    _setupMessageHandlers();
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensaje recibido en primer plano: ${message.notification?.title}');
      
      if (message.notification != null) {
        _showInAppNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App abierta desde notificación: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('App iniciada desde notificación: ${message.notification?.title}');
        _handleNotificationTap(message);
      }
    });
  }

  void _showInAppNotification(RemoteMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.notification?.title ?? 'Notificación',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (message.notification?.body != null)
              Text(message.notification!.body!),
          ],
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Procesando tap en notificación: ${message.data}');
    
    if (message.data.containsKey('screen')) {
      switch (message.data['screen']) {
        case 'home':
          NavigationService.setCurrentScreen(NavigationScreen.home);
          break;
        case 'profile':
          break;
      }
    }
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
      return false;
    }
  }
}