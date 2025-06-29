import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:lockity_flutter/services/oauth_service.dart';
import 'package:lockity_flutter/screens/loading_screen.dart';

class OAuthWebView extends StatefulWidget {
  final String authUrl;
  final Function(Map<String, dynamic>) onSuccess;
  final Function(String) onError;

  const OAuthWebView({
    super.key,
    required this.authUrl,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<OAuthWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isExchangingTokens = false;

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
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
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
          widget.onError('Invalid OAuth callback: missing parameters');
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
        title: const Text('Sign In', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E2D2D),
        iconTheme: const IconThemeData(color: Colors.white),
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