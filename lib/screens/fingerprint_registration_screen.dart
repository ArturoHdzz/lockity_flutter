import 'package:flutter/material.dart';
import 'package:lockity_flutter/use_cases/register_fingerprint_use_case.dart';
import 'package:lockity_flutter/models/fingerprint_message.dart';

class FingerprintRegistrationScreen extends StatefulWidget {
  final String serialNumber;
  final String userId;
  final int compartmentNumber;

  const FingerprintRegistrationScreen({
    super.key,
    required this.serialNumber,
    required this.userId,
    required this.compartmentNumber,
  });

  @override
  State<FingerprintRegistrationScreen> createState() => _FingerprintRegistrationScreenState();
}

class _FingerprintRegistrationScreenState extends State<FingerprintRegistrationScreen> {
  final _useCase = RegisterFingerprintUseCase();
  String _message = 'Initializing...';
  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRegistration();
    });
  }

  void _startRegistration() {
    if (!mounted) return;
    setState(() {
      _message = 'Connecting to device...';
      _isProcessing = true;
      _isSuccess = false;
      _isError = false;
    });

    final userIdInt = int.tryParse(widget.userId) ?? 0;
    if (userIdInt == 0) {
      setState(() {
        _message = 'Invalid user ID provided';
        _isError = true;
        _isProcessing = false;
      });
      return;
    }

    _useCase.start(
      serialNumber: widget.serialNumber,
      userId: userIdInt,
      compartmentNumber: widget.compartmentNumber,
      onStep: (FingerprintMessage step) {
        if (!mounted) return;
        final instruction = _getInstruction(step);
        final isSuccess = _isRegistrationComplete(step);
        final isError = _isRegistrationError(step);

        setState(() {
          _message = instruction;
          _isSuccess = isSuccess;
          _isError = isError;
          _isProcessing = !isSuccess && !isError;
        });

        if (isSuccess) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _message = error;
          _isError = true;
          _isProcessing = false;
        });
      },
    );
  }

  bool _isRegistrationComplete(FingerprintMessage step) {
    final stage = step.stage.trim().toLowerCase();
    final status = step.status.trim().toLowerCase();
    final message = step.message.trim().toLowerCase();
    return (stage == 'confirm' && status == 'success') ||
           (stage == 'complete' && status == 'success') ||
           (stage == 'finished' && status == 'success') ||
           message.contains('configured') ||
           message.contains('successfully') ||
           message.contains('registered');
  }

  bool _isRegistrationError(FingerprintMessage step) {
    final status = step.status.trim().toLowerCase();
    final message = step.message.trim().toLowerCase();
    return status == 'error' ||
           status == 'failed' ||
           message.contains('error') ||
           message.contains('failed') ||
           message.contains('timeout');
  }

  @override
  void dispose() {
    _useCase.cancel(widget.serialNumber);
    _useCase.dispose();
    super.dispose();
  }

  String _getInstruction(FingerprintMessage step) {
    return step.message.isNotEmpty ? step.message : 'Processing...';
  }

  Color _getIconColor() {
    if (_isSuccess) return Colors.green;
    if (_isError) return Colors.red;
    return Colors.amber;
  }

  IconData _getIcon() {
    if (_isSuccess) return Icons.check_circle;
    if (_isError) return Icons.error;
    return Icons.fingerprint;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Text(
                  'Fingerprint Registration',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 28),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Icon(
            _getIcon(),
            size: 80,
            color: _getIconColor(),
          ),
          const SizedBox(height: 24),
          if (_isProcessing)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          if (!_isProcessing)
            const SizedBox(height: 32),
          const SizedBox(height: 16),
          Text(
            _message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_isError && !_isProcessing)
            ElevatedButton(
              onPressed: _startRegistration,
              child: const Text('Try Again'),
            ),
          if (_isSuccess || _isError)
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _isSuccess),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSuccess ? Colors.green : null,
              ),
              child: Text(_isSuccess ? 'Finish' : 'Close'),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}