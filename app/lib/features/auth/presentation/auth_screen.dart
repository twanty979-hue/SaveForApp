import 'dart:convert';
import 'dart:ui';
import 'package:app/core/localization/app_material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_background.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/auth_session.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiClient = ApiClient();
  bool _isLoginMode = true;
  bool _isLoading = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกอีเมลและรหัสผ่าน';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final path = _isLoginMode ? '/auth/login' : '/auth/register';
      final body = {'email': email, 'password': password};

      final response = await _apiClient.post(path, body: body);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String? userId = responseData['user']?['id'];
        final String? userEmail = responseData['user']?['email'];
        final String? accessToken = responseData['access_token'];
        final String? refreshToken = responseData['refresh_token'];

        if (userId != null) {
          await AuthSession.save(
            userId,
            null,
            userEmail,
            token: accessToken,
            refresh: refreshToken,
          );

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'ไม่สามารถประมวลผลข้อมูลโปรไฟล์ได้';
          });
        }
      } else {
        final rawError = responseData['error_description'] ??
                         responseData['message'] ??
                         responseData['msg'] ??
                         responseData['error'];
        
        String errorMsg = 'เกิดข้อผิดพลาดจากหลังบ้าน';
        if (rawError != null) {
          final errStr = rawError.toString();
          if (errStr.contains('Invalid login credentials') || 
              errStr.contains('invalid_grant') || 
              errStr.contains('invalid login credentials')) {
            errorMsg = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
          } else if (errStr.contains('Email not confirmed')) {
            errorMsg = 'กรุณายืนยันอีเมลของคุณก่อนเข้าสู่ระบบ';
          } else if (errStr.contains('User already exists') ||
                     errStr.contains('user already exists')) {
            errorMsg = 'อีเมลนี้ถูกใช้งานแล้ว';
          } else {
            errorMsg = errStr;
          }
        }

        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถติดต่อเซิร์ฟเวอร์หลังบ้านได้';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Ultra-Premium SaaS Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE0F2FE), // Light sky blue
                    Color(0xFFECFDF5), // Light mint green
                    Color(0xFFF8FAFC), // Off-white
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
              maxWidth: 460,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
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
                            // Logo with floating breathing float animation
                            AnimatedBuilder(
                              animation: _logoAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _logoAnimation.value),
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 92,
                                height: 92,
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
                                      color: AppTheme.primaryColor.withOpacity(0.2),
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
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        child: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: AppTheme.primaryColor,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // App Title
                            const Text(
                              'SaveFor',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF008B75),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtitle
                            Text(
                              _isLoginMode
                                  ? 'เข้าสู่ระบบเพื่อใช้งานระบบบนคลาวด์'
                                  : 'สมัครสมาชิกเพื่อเริ่มบันทึกข้อมูลบนคลาวด์',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),

                            // Error Message (if any)
                            if (_errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Inputs
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'อีเมล',
                                labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryColor, size: 20),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.75),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'รหัสผ่าน',
                                labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 20),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.75),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login/Register Button (Gradient Emerald-Teal)
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    AppTheme.primaryColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _handleSubmit,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLoginMode ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle Link
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLoginMode = !_isLoginMode;
                                  _errorMessage = null;
                                });
                              },
                              child: Text(
                                _isLoginMode
                                    ? 'ยังไม่มีบัญชี? สมัครสมาชิกที่นี่'
                                    : 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบที่นี่',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
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
