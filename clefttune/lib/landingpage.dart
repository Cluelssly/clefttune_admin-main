import 'package:flutter/material.dart';
import 'main.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Admin email is fixed; only the password is typed in.
const _kAdminEmail = 'elepsyen@gmail.com';

class AdminLandingPage extends StatefulWidget {
  const AdminLandingPage({super.key});

  @override
  State<AdminLandingPage> createState() => _AdminLandingPageState();
}

class _AdminLandingPageState extends State<AdminLandingPage>
    with SingleTickerProviderStateMixin {
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _error;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || _isSuccess) return;

    final password = _passCtrl.text;

    if (password.isEmpty) {
      await _fail('Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _kAdminEmail,
        password: password,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const AdminShell(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      await _fail(_messageFor(e.code));
    } catch (_) {
      await _fail('Something went wrong. Please try again.');
    }
  }

  Future<void> _fail(String message) async {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = message;
    });
    await _shakeController.forward(from: 0);
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      default:
        return 'Incorrect password.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccent.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kIndigo.withOpacity(0.06),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kBorder, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withOpacity(0.12),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const _RadioWaveIcon(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'CleftTune',
                      style: TextStyle(
                        color: kText,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                          color: kSlate, fontSize: 13, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 40),

                    // Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 32),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: kBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: hasError
                                    ? kRose
                                    : (_isSuccess ? kEmerald : kSlate),
                                fontSize: 13,
                                fontWeight: hasError
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              child: Text(
                                hasError
                                    ? _error!
                                    : _isSuccess
                                        ? 'Access granted ✓'
                                        : 'Enter admin password',
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Email (fixed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: kBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kBorder, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mail_outline,
                                      color: kSlate, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _kAdminEmail,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: kText, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextField(
                              controller: _passCtrl,
                              autofocus: true,
                              enabled: !_isLoading && !_isSuccess,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                              onSubmitted: (_) => _login(),
                              style: const TextStyle(color: kText),
                              decoration: _inputDecoration(
                                label: 'Password',
                                icon: Icons.lock_outline,
                                hasError: hasError,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: kSlate,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed:
                                    (_isLoading || _isSuccess) ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isSuccess ? kEmerald : kAccent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _isSuccess
                                      ? kEmerald
                                      : kAccent.withOpacity(0.6),
                                  disabledForegroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isSuccess ? 'Welcome' : 'Sign In',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '© ${DateTime.now().year} CleftTune · Secure Access',
                      style: const TextStyle(color: kSlate, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool hasError,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kSlate),
      floatingLabelStyle: TextStyle(color: hasError ? kRose : kAccent),
      prefixIcon: Icon(icon, color: kSlate, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: kBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(hasError ? kRose.withOpacity(0.6) : kBorder),
      disabledBorder: border(kBorder),
      focusedBorder: border(hasError ? kRose : kAccent, 2),
    );
  }
}

// ─────────────────────────────────────────────
// RADIO WAVE ICON (custom painter)
// ─────────────────────────────────────────────
class _RadioWaveIcon extends StatelessWidget {
  const _RadioWaveIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RadioWavePainter());
  }
}

class _RadioWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = Colors.white);

    final radii = [6.0, 10.0, 14.0];
    for (final r in radii) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.7,
        1.4,
        false,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14 - 0.7,
        1.4,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}