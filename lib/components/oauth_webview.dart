import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:lockity_flutter/screens/loading_screen.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/core/app_colors.dart';
import 'package:lockity_flutter/core/app_config.dart';
import 'dart:io';

class OAuthWebView extends StatefulWidget {
  final String authUrl;
  final Function(AuthToken) onSuccess;
  final Function(String) onError;
  final Function()? onRegistrationSuccess;
  final bool isRegister;

  const OAuthWebView({
    super.key,
    required this.authUrl,
    required this.onSuccess,
    required this.onError,
    this.onRegistrationSuccess,
    this.isRegister = false,
  });

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isExchangingTokens = false;
  bool _hasProcessedCallback = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() async {
    try {
      await _clearWebViewSession();
      
      final userAgent = Platform.isIOS
          ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
          : 'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
      
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(userAgent)
        ..setNavigationDelegate(_createNavigationDelegate())
        ..enableZoom(false)
        ..setBackgroundColor(Colors.white);

      await _controller!.loadRequest(Uri.parse(widget.authUrl));
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      widget.onError('Failed to initialize WebView: $e');
    }
  }

  Future<void> _clearWebViewSession() async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      // 
    }
  }

  NavigationDelegate _createNavigationDelegate() {
    return NavigationDelegate(
      onPageStarted: (url) {
        if (mounted) {
          setState(() => _isLoading = true);
        }
        
        if (_shouldHandleCallback(url)) {
          _handleAuthorizationCallback(url);
        }
      },
      onPageFinished: (url) async {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        await _handlePageFinished(url);
      },
      onNavigationRequest: (request) {
        return _handleNavigationRequest(request);
      },
      onWebResourceError: (error) {
        if (error.description.contains('Something went wrong')) {
          widget.onError('Server error. Please try again later.');
        }
      },
    );
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (_shouldHandleCallback(request.url)) {
      _handleAuthorizationCallback(request.url);
      return NavigationDecision.prevent;
    }
    
    return NavigationDecision.navigate;
  }

  bool _shouldHandleCallback(String url) {
    return url.startsWith(AppConfig.redirectUri) ||
           (url.contains('code=') && url.contains('state='));
  }

  Future<void> _handlePageFinished(String url) async {
    try {
      if (widget.isRegister && _isRegistrationSuccessful(url)) {
        widget.onRegistrationSuccess?.call();
        return;
      }

      if (_hasError(url)) {
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (!_hasProcessedCallback) {
          widget.onError('Authentication failed. Please try again.');
        }
        return;
      }

      if (_shouldHandleCallback(url)) {
        _handleAuthorizationCallback(url);
      }
    } catch (e) {
      widget.onError('Page handling failed: $e');
    }
  }

  bool _hasError(String url) {
    return url.contains('error=') || 
           url.contains('Oops') || 
           url.toLowerCase().contains('something went wrong') ||
           url.toLowerCase().contains('server error');
  }

  bool _isRegistrationSuccessful(String url) {
    return url.contains('success') ||
           url.contains('account_created') ||
           url.contains('registration_complete') ||
           url.contains('user_created') ||
           url.contains('registered') ||
           (url.contains('/login') && !url.contains('error'));
  }

  void _handleAuthorizationCallback(String url) {
    if (_hasProcessedCallback || _isExchangingTokens) {
      return;
    }

    try {
      Uri uri;
      try {
        uri = Uri.parse(url);
      } catch (e) {
        final cleanUrl = url.split('#')[0];
        uri = Uri.parse(cleanUrl);
      }
      
      final error = uri.queryParameters['error'];
      if (error != null) {
        final errorDescription = uri.queryParameters['error_description'] ?? 
                                 uri.queryParameters['error_reason'] ?? 
                                 error;
        widget.onError('Authorization error: $errorDescription');
        return;
      }

      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      
      if (code == null || code.isEmpty) {
        widget.onError('Authorization code not found in callback');
        return;
      }
      
      if (state == null || state.isEmpty) {
        widget.onError('State parameter not found in callback');
        return;
      }

      _hasProcessedCallback = true;
      _exchangeCodeForTokens(code, state);
    } catch (e) {
      widget.onError('Failed to process authorization callback: $e');
    }
  }

  Future<void> _exchangeCodeForTokens(String code, String state) async {
    if (mounted) {
      setState(() => _isExchangingTokens = true);
    }

    try {
      final token = await OAuthService.exchangeCodeForTokens(code, state);
      
      if (token.accessToken.isEmpty) {
        widget.onError('Invalid token received');
        return;
      }
      
      widget.onSuccess(token);
    } catch (e) {
      widget.onError('Token exchange failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isExchangingTokens = false);
      }
    }
  }

  @override
  void dispose() {
    _clearWebViewSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.isRegister ? 'Sign Up' : 'Sign In',
        style: AppTextStyles.appBarTitle,
      ),
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: AppColors.text),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        if (_isInitialized && _controller != null)
          WebViewWidget(controller: _controller!)
        else
          const LoadingScreen(
            message: 'Initializing authentication',
            subtitle: 'Setting up secure connection...',
          ),
        
        if (_isLoading && _isInitialized)
          const LoadingScreen(
            message: 'Loading authentication',
            subtitle: 'Connecting to security server...',
          ),
        
        if (_isExchangingTokens)
          const LoadingScreen(
            message: 'Completing authentication',
            subtitle: 'Securing your session...',
          ),
      ],
    );
  }
}