import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/auth_session.dart';
import '../../../core/network/web_helper.dart' as web_helper;

// โลโก้ Google แบบเวกเตอร์จาก asset ภายในแอป ไม่โหลดจากอินเทอร์เน็ต
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/google_g.svg',
      width: size,
      height: size,
      semanticsLabel: 'Google',
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _apiClient = ApiClient();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _appleSignInAvailable = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    SignInWithApple.isAvailable().then((available) {
      if (mounted) {
        setState(() => _appleSignInAvailable = available);
      }
    }).catchError((_) {});

    // ตรวจสอบข้อมูลล็อกอินขากลับจาก URL Fragment หรือ Query Parameters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUrlFragment();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailPasswordSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกรหัสผ่าน');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = 'กำลังตรวจสอบบัญชี...';
    });

    try {
      final response = await _apiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final accessToken = data['access_token']?.toString();
        final refreshToken = data['refresh_token']?.toString();
        final user = data['user'] as Map<String, dynamic>?;
        final id = user?['id']?.toString();
        final userEmail = user?['email']?.toString() ?? email;
        final metadata = user?['user_metadata'] as Map<String, dynamic>?;
        final displayName =
            metadata?['full_name']?.toString() ??
            metadata?['name']?.toString() ??
            userEmail.split('@').first;

        if (id != null &&
            id.isNotEmpty &&
            accessToken != null &&
            accessToken.isNotEmpty &&
            refreshToken != null &&
            refreshToken.isNotEmpty) {
          await AuthSession.save(
            id,
            displayName,
            userEmail,
            token: accessToken,
            refresh: refreshToken,
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          }
          return;
        }
      }

      final message =
          data['error_description']?.toString() ??
          data['msg']?.toString() ??
          data['message']?.toString() ??
          'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      setState(() => _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: $message');
    } catch (_) {
      setState(() => _errorMessage = 'ไม่สามารถเชื่อมต่อระบบเข้าสู่ระบบได้');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = null;
        });
      }
    }
  }

  // ระบบดึงและวิเคราะห์ Token ขากลับที่ปลอดภัยสูง
  Future<void> _checkUrlFragment() async {
    final fullUrl = Uri.base.toString();
    debugPrint("SaveFor: Checking callback URL: $fullUrl");

    String? accessToken;
    String? refreshToken;

    // 1. วิเคราะห์ข้อมูลจาก Hash Fragment (#)
    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty) {
      debugPrint("SaveFor: Found raw fragment: $fragment");
      String cleanFragment = fragment;

      if (cleanFragment.startsWith('/')) {
        cleanFragment = cleanFragment.substring(1);
      }
      if (cleanFragment.contains('?')) {
        cleanFragment = cleanFragment.substring(cleanFragment.indexOf('?') + 1);
      }
      if (cleanFragment.contains('#')) {
        cleanFragment = cleanFragment.substring(cleanFragment.indexOf('#') + 1);
      }

      final params = Uri.splitQueryString(cleanFragment);
      accessToken = params['access_token'];
      refreshToken = params['refresh_token'];
    }

    // 2. วิเคราะห์ข้อมูลจาก Query Parameters (?)
    if (accessToken == null || accessToken.isEmpty) {
      accessToken = Uri.base.queryParameters['access_token'];
      refreshToken = Uri.base.queryParameters['refresh_token'];
    }

    debugPrint(
      "SaveFor: Extraction result -> AccessToken: ${accessToken != null ? 'FOUND' : 'NOT FOUND'}",
    );

    if (accessToken != null && accessToken.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = 'กำลังดาวน์โหลดข้อมูลโปรไฟล์ผู้ใช้...';
      });

      try {
        debugPrint("SaveFor: Fetching user profile from Go backend proxy...");
        final response = await _apiClient.get(
          '/auth/user',
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        debugPrint(
          "SaveFor: Profile API response code: ${response.statusCode}",
        );
        debugPrint("SaveFor: Profile API response body: ${response.body}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final id = data['id']?.toString();
          final email = data['email']?.toString();
          final userMetadata = data['user_metadata'] as Map<String, dynamic>?;
          final displayName =
              userMetadata?['full_name']?.toString() ??
              userMetadata?['name']?.toString();

          if (id != null && id.isNotEmpty) {
            debugPrint(
              "SaveFor: Save session and login -> ID: $id, Email: $email",
            );
            await AuthSession.save(
              id,
              displayName,
              email,
              token: accessToken,
              refresh: refreshToken,
            );

            final avatarUrl = userMetadata?['avatar_url']?.toString();
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              await AuthSession.setAvatarUrl(avatarUrl);
            }

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            }
            return;
          }
        }

        final errorData = jsonDecode(response.body);
        final errText =
            errorData['error_description'] ??
            errorData['message'] ??
            'ข้อมูลเซสชันไม่ถูกต้อง';
        setState(() {
          _errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: $errText';
        });
      } catch (e) {
        debugPrint("SaveFor: Error verifying token: $e");
        setState(() {
          _errorMessage =
              'ไม่สามารถตรวจสอบสิทธิ์การเชื่อมต่อกับเซิร์ฟเวอร์หลังบ้านได้';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _successMessage = null;
          });
        }
      }
    }
  }

  // เรียกใช้กระบวนการล็อกอิน Sign in with Apple (ตามมาตรฐาน App Store Guideline 4.8)
  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = 'กำลังเชื่อมต่อบัญชี Apple...';
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('ไม่ได้รับ Identity Token จาก Apple');
      }

      // บน Render โปรดักชัน endpoint /auth/google/android ทำหน้าที่เป็น proxy ส่งต่อไปยัง
      // Supabase /auth/v1/token?grant_type=id_token โดยตรง (รองรับ ID token ของทั้ง Google และ Apple)
      var response = await _apiClient.post(
        '/auth/google/android',
        body: {
          'provider': 'apple',
          'id_token': idToken,
        },
      );

      // สำรองกรณีที่เซิร์ฟเวอร์ในอนาคตมีการแยก endpoint /auth/apple เป็นพิเศษ
      if (response.statusCode != 200 && response.statusCode != 201) {
        final appleResp = await _apiClient.post(
          '/auth/apple',
          body: {
            'provider': 'apple',
            'id_token': idToken,
          },
        );
        if (appleResp.statusCode == 200 || appleResp.statusCode == 201) {
          response = appleResp;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final sessionData = jsonDecode(response.body);
        final accessToken = sessionData['access_token']?.toString();
        final refreshToken = sessionData['refresh_token']?.toString();
        final user = sessionData['user'] as Map<String, dynamic>?;
        final id = user?['id']?.toString();
        final email = user?['email']?.toString() ?? credential.email;
        final userMetadata = user?['user_metadata'] as Map<String, dynamic>?;

        String? displayName =
            userMetadata?['full_name']?.toString() ??
            userMetadata?['name']?.toString();

        if (displayName == null || displayName.isEmpty) {
          final parts = [credential.givenName, credential.familyName]
              .where((s) => s != null && s.trim().isNotEmpty)
              .map((s) => s!.trim())
              .toList();
          if (parts.isNotEmpty) {
            displayName = parts.join(' ');
          }
        }

        if (displayName == null || displayName.isEmpty) {
          displayName = email?.split('@').first ?? 'Apple User';
        }

        if (id != null && id.isNotEmpty && accessToken != null) {
          await AuthSession.save(
            id,
            displayName,
            email,
            token: accessToken,
            refresh: refreshToken,
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
            );
          }
          return;
        }
      }

      // ดึงรายละเอียด error จาก Supabase / Backend เพื่อแสดงข้อความที่แท้จริง
      String errDetail = response.body;
      try {
        final errJson = jsonDecode(response.body);
        errDetail = errJson['msg'] ??
            errJson['error_description'] ??
            errJson['message'] ??
            errJson['error'] ??
            response.body;
      } catch (_) {}
      throw Exception(errDetail);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        setState(() {
          _isLoading = false;
          _successMessage = null;
        });
        return;
      }
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาดในการยืนยันตัวตน Apple: ${e.message}';
        _isLoading = false;
        _successMessage = null;
      });
    } catch (e) {
      debugPrint("SaveFor: Apple Sign In error: $e");
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = 'เข้าสู่ระบบด้วย Apple ไม่สำเร็จ: $cleanMsg';
        _isLoading = false;
        _successMessage = null;
      });
    }
  }

  // เรียกใช้กระบวนการล็อกอิน Google OAuth ของจริงโดยตรงทันที
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = 'กำลังเชื่อมต่อบัญชี Google ของท่าน...';
    });

    try {
      if (kIsWeb) {
        final origin = Uri.base.origin;
        final response = await _apiClient.get(
          '/auth/google/url?redirect_to=$origin',
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final url = data['url']?.toString();
          if (url != null && url.isNotEmpty) {
            web_helper.redirectWindow(url);
            return;
          }
        }
        throw Exception('ไม่สามารถรับ URL เชื่อมต่อจากหลังบ้านได้');
      } else {
        // Native Google Sign-In on Android/iOS
        final googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? '569249732125-jqsu8h9np7n91isd5ur37ugk70drk6rd.apps.googleusercontent.com'
              : null,
          serverClientId:
              '569249732125-g3s97ooml3nbf5hvelg8mvmmfdo3h5nl.apps.googleusercontent.com',
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          setState(() {
            _isLoading = false;
            _successMessage = null;
          });
          return;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null || idToken.isEmpty) {
          throw Exception('ไม่ได้รับ ID Token จาก Google');
        }

        final response = await _apiClient.post(
          '/auth/google/android',
          body: {'provider': 'google', 'id_token': idToken},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final sessionData = jsonDecode(response.body);
          final accessToken = sessionData['access_token']?.toString();
          final refreshToken = sessionData['refresh_token']?.toString();
          final user = sessionData['user'] as Map<String, dynamic>?;
          final id = user?['id']?.toString();
          final email = user?['email']?.toString();
          final userMetadata = user?['user_metadata'] as Map<String, dynamic>?;
          final displayName =
              userMetadata?['full_name']?.toString() ??
              userMetadata?['name']?.toString();
          final avatarUrl = userMetadata?['avatar_url']?.toString();

          if (id != null && id.isNotEmpty && accessToken != null) {
            await AuthSession.save(
              id,
              displayName,
              email,
              token: accessToken,
              refresh: refreshToken,
            );
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              await AuthSession.setAvatarUrl(avatarUrl);
            }

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            }
            return;
          }
        }
        throw Exception(
          'ไม่สามารถแลกเปลี่ยนสิทธิ์ล็อกอินได้: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint("SaveFor: Google Sign In error: $e");
      setState(() {
        _errorMessage =
            'ไม่สามารถเชื่อมต่อระบบ Google ได้ กรุณาลองใหม่อีกครั้ง';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.currentPalette;
    final isCompact = MediaQuery.sizeOf(context).height < 760;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Ultra-Premium SaaS Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.secondary.withValues(alpha: 0.62),
                    palette.backgroundLight,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),

          // Main glassmorphic form card content
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 440,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 20,
                    vertical: isCompact ? 12 : 28,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 22 : 28,
                          vertical: isCompact ? 20 : 36,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.68),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Static app logo: clean and professional, without a distracting animation.
                            Container(
                              width: isCompact ? 68 : 88,
                              height: isCompact ? 68 : 88,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 20 : 26,
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.2,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 16 : 22.5,
                                ),
                                child: Image.asset(
                                  'assets/images/logo_blue.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      child: Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: AppTheme.primaryColor,
                                        size: 44,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 10 : 18),

                            // Welcome Text
                            Text(
                              'ยินดีต้อนรับสู่ SaveFor',
                              style: TextStyle(
                                fontSize: isCompact ? 21 : 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(height: isCompact ? 8 : 12),

                            // Subtitle / Instruction
                            const Text(
                              'จัดการเงินของคุณให้เป็นเรื่องง่าย',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isCompact ? 18 : 28),

                            // Display Error Message
                            if (_errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFCA5A5),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Display Success/Info Message
                            if (_successMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            TextField(
                              controller: _emailController,
                              enabled: !_isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: InputDecoration(
                                labelText: 'อีเมล',
                                hintText: 'กรอกอีเมลของคุณ',
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.72),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _handleEmailPasswordSignIn(),
                              decoration: InputDecoration(
                                labelText: 'รหัสผ่าน',
                                hintText: 'กรอกรหัสผ่านของคุณ',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'แสดงรหัสผ่าน'
                                      : 'ซ่อนรหัสผ่าน',
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.72),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _handleEmailPasswordSignIn,
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('เข้าสู่ระบบด้วยอีเมล'),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'หรือ',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Social Logins: Apple & Google Side-by-Side (Icon Buttons)
                            Builder(
                              builder: (context) {
                                final showApple = _appleSignInAvailable ||
                                    (!kIsWeb &&
                                        defaultTargetPlatform ==
                                            TargetPlatform.iOS);
                                final isAppleLoading = _isLoading &&
                                    _successMessage?.contains('Apple') == true;
                                final isGoogleLoading = _isLoading &&
                                    _successMessage?.contains('Google') == true;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (showApple) ...[
                                      _buildSocialIconButton(
                                        key: const ValueKey('apple_sign_in_button'),
                                        icon: const Icon(
                                          Icons.apple,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        backgroundColor: Colors.black,
                                        tooltip: 'Apple ID',
                                        semanticsLabel: 'เข้าสู่ระบบด้วย Apple',
                                        isLoading: isAppleLoading,
                                        onTap: _isLoading
                                            ? null
                                            : _handleAppleSignIn,
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    _buildSocialIconButton(
                                      key: const ValueKey('google_sign_in_button'),
                                      icon: const GoogleLogo(size: 24),
                                      backgroundColor: Colors.white,
                                      borderColor: const Color(0xFFE2E8F0),
                                      tooltip: 'Google',
                                      semanticsLabel: 'เข้าสู่ระบบด้วย Google',
                                      isLoading: isGoogleLoading,
                                      onTap: _isLoading
                                          ? null
                                          : _handleGoogleSignIn,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 18),

                            // Terms and Privacy Disclaimer
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'การเข้าสู่ระบบแสดงว่าคุณยอมรับ\n',
                                  ),
                                  TextSpan(
                                    text: 'ข้อตกลงการใช้งาน',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' และ '),
                                  TextSpan(
                                    text: 'นโยบายความเป็นส่วนตัว',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIconButton({
    Key? key,
    required Widget icon,
    required VoidCallback? onTap,
    required Color backgroundColor,
    Color? borderColor,
    required String tooltip,
    required String semanticsLabel,
    bool isLoading = false,
  }) {
    final isDark = backgroundColor == Colors.black ||
        backgroundColor == const Color(0xFF0F172A);
    final isDisabled = onTap == null && !isLoading;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: semanticsLabel,
        button: true,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDisabled ? 0.6 : 1.0,
          child: Material(
            key: key,
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.12),
              highlightColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
              child: Ink(
                width: 64,
                height: 52,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: borderColor != null
                      ? Border.all(color: borderColor, width: 1.2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.14 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: isDark
                                ? Colors.white
                                : AppTheme.primaryColor,
                            strokeWidth: 2.2,
                          ),
                        )
                      : icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
