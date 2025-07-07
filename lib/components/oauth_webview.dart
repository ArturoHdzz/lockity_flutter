import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:lockity_flutter/screens/loading_screen.dart';
import 'package:lockity_flutter/core/app_text_styles.dart';
import 'package:lockity_flutter/core/app_colors.dart';

class OAuthWebView extends StatefulWidget {
  final String authUrl;
  final Function(Map<String, dynamic>) onSuccess;
  final Function(String) onError;
  final bool isRegister;

  const OAuthWebView({
    super.key,
    required this.authUrl,
    required this.onSuccess,
    required this.onError,
    this.isRegister = false,
  });

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isExchangingTokens = false;
  bool _mfaCompleted = false;
  bool _hasRedirectedToOAuth = false;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            
            if (url.contains('/code') && !_mfaCompleted) {
            }
            
            if (url.contains('/oauth/authorize') && !_mfaCompleted && !_hasRedirectedToOAuth) {
              _mfaCompleted = true;
              _hasRedirectedToOAuth = true;
              await _redirectToOAuthWithParams();
              return;
            }
            
            if (url.contains('error=') || url.contains('Oops')) {
              widget.onError('OAuth authorization failed. Please try again.');
            }
            
            if (url.contains('/login') && _mfaCompleted && !url.contains('error')) {
              _hasRedirectedToOAuth = false;
              await Future.delayed(const Duration(seconds: 1));
              await _redirectToOAuthWithParams();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('/oauth/authorize') && !_hasRedirectedToOAuth) {
              final uri = Uri.parse(request.url);
              if (!uri.queryParameters.containsKey('client_id')) {
                _mfaCompleted = true;
                _hasRedirectedToOAuth = true;
                
                Future.delayed(const Duration(milliseconds: 500), () async {
                  await _redirectToOAuthWithParams();
                });
                
                return NavigationDecision.prevent;
              }
            }
            
            if (request.url.startsWith('myapp://')) {
              _handleDeepLink(request.url);
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  Future<void> _redirectToOAuthWithParams() async {
    try {
      final oauthUrl = await OAuthService.buildOAuthUrl();
      
      setState(() {
        _isLoading = true;
      });
      
      await _controller.loadRequest(Uri.parse(oauthUrl));
    } catch (e) {
      widget.onError('Failed to redirect to OAuth: $e');
    }
  }

  void _handleDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      
      if (url.startsWith('myapp://alo/home')) {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];
        final error = uri.queryParameters['error'];
        
        if (error != null) {
          widget.onError('Authorization error: $error');
          return;
        }
        
        if (code != null && state != null) {
          _exchangeCodeForTokens(code, state);
        } else {
          widget.onError('Invalid OAuth callback: missing code or state');
        }
      } else {
        widget.onError('Unexpected deep link: $url');
      }
    } catch (e) {
      widget.onError('Failed to process callback: $e');
    }
  }

  Future<void> _exchangeCodeForTokens(String code, String state) async {
    setState(() {
      _isExchangingTokens = true;
    });

    try {
      final tokens = await OAuthService.exchangeCodeForTokens(code, state);
      
      if (tokens != null) {
        widget.onSuccess(tokens);
      } else {
        widget.onError('Failed to exchange code for tokens');
      }
    } catch (e) {
      widget.onError('Token exchange failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExchangingTokens = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isRegister ? 'Sign Up' : 'Sign In',
          style: AppTextStyles.appBarTitle,
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.text),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          if (_isLoading)
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
      ),
    );
  }
}