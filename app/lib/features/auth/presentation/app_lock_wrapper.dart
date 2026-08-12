import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:app/core/settings/app_settings.dart';
import 'package:app/core/theme/app_theme.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkLockOnStart() {
    if (AppSettings.appLockEnabled) {
      setState(() {
        _isLocked = true;
      });
      _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      if (AppSettings.appLockEnabled && !_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isLocked) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (!AppSettings.appLockEnabled) {
      setState(() => _isLocked = false);
      return;
    }

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        // If device has no security, unlock it.
        setState(() => _isLocked = false);
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'กรุณายืนยันตัวตนเพื่อเข้าใช้งาน (Please authenticate to use the app)',
      );

      if (didAuthenticate) {
        if (mounted) {
          setState(() {
            _isLocked = false;
          });
        }
      }
    } catch (e) {
      // If error (like canceled by user), it remains locked.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'แอปถูกล็อกอยู่',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _authenticate,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('ปลดล็อก (Unlock)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
