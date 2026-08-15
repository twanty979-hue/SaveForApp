import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/auth_session.dart';
import '../../../core/network/web_helper.dart' as web_helper;

// วิดเจ็ตวาดโลโก้ Google ของแท้แบบเวกเตอร์ (ไม่มีความล่าช้าเครือข่าย ไม่ติดปัญหา CORS บนเว็บบราวเซอร์)
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final double radius = w / 2;

    // อัตราส่วนความหนาเส้นตรงตามสเปกของ Google (ประมาณ 23%)
    final double thickness = w * 0.23;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - thickness / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..isAntiAlias = true;

    // ส่วนสีแดง (ด้านบน)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.356, 1.256, false, paint);

    // ส่วนสีเหลือง (ด้านซ้าย)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.456, 1.1, false, paint);

    // ส่วนสีเขียว (ด้านล่าง)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.785, 1.57, false, paint);

    // ส่วนสีน้ำเงิน (ด้านขวา)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.1, 1.885, false, paint);

    // แท่งสีน้ำเงินแนวนอนของตัว G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final barHeight = thickness;
    canvas.drawRect(
      Rect.fromLTRB(
        w * 0.5,
        h * 0.5 - barHeight / 2,
        w,
        h * 0.5 + barHeight / 2,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _apiClient = ApiClient();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _logoAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // ตรวจสอบข้อมูลล็อกอินขากลับจาก URL Fragment หรือ Query Parameters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUrlFragment();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
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

          // 2. Animated Floating Background Icons
          const Positioned.fill(child: FloatingBackground()),

          // 3. Main Glassmorphic Form Card Content
          SafeArea(
            child: ResponsiveLayout(
              maxWidth: 440,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 36,
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
                            // Floating Logo Animation
                            AnimatedBuilder(
                              animation: _logoAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _logoAnimation.value),
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
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
                                  borderRadius: BorderRadius.circular(22.5),
                                  child: Image.asset(
                                    'assets/images/logo.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
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
                            ),
                            const SizedBox(height: 18),

                            // Welcome Text
                            const Text(
                              'ยินดีต้อนรับเข้าสู่',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // App Title
                            Text(
                              'SaveFor',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: palette.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Subtitle / Instruction
                            const Text(
                              'จัดการการเงินและบรรลุเป้าหมายของคุณ\nโปรดเข้าสู่ระบบเพื่อดำเนินการต่อ',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

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

                            // Premium Google Sign-In Button
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _handleGoogleSignIn,
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryColor,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // เวกเตอร์โลโก้ Google ของแท้ (ไม่มีปัญหา CORS, 100% Offline)
                                          GoogleLogo(size: 24),
                                          SizedBox(width: 12),
                                          Text(
                                            'เข้าสู่ระบบด้วย Google',
                                            style: TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

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
}
