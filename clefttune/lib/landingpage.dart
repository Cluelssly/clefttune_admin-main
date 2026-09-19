import 'package:flutter/material.dart';
import 'main.dart';

// ─────────────────────────────────────────────
// Change this to your desired admin PIN
// ─────────────────────────────────────────────
const _kAdminPin = '9235';

class AdminLandingPage extends StatefulWidget {
  const AdminLandingPage({super.key});

  @override
  State<AdminLandingPage> createState() => _AdminLandingPageState();
}

class _AdminLandingPageState extends State<AdminLandingPage>
    with SingleTickerProviderStateMixin {
  String _entered   = ''; 
  bool   _isWrong   = false;
  bool   _isSuccess = false;

  late AnimationController _shakeController;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0,   end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end:  10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  10.0, end:  -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  -8.0, end:   8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:   8.0, end:   0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_isSuccess || _entered.length >= 4) return;
    setState(() {
      _isWrong = false;
      _entered += digit;
    });
    if (_entered.length == 4) _checkPin();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _isWrong = false;
      _entered = _entered.substring(0, _entered.length - 1);
    });
  }

  Future<void> _checkPin() async {
    if (_entered == _kAdminPin) {
      setState(() => _isSuccess = true);
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
    } else {
      await _shakeController.forward(from: 0);
      setState(() {
        _isWrong = true;
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Subtle decorative circles in background
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccent.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -60, left: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kIndigo.withOpacity(0.06),
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // ── Logo (Radio Wave) ─────────────────────
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color:  kSurface,
                        shape:  BoxShape.circle,
                        border: Border.all(color: kBorder, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color:      kAccent.withOpacity(0.12),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color:      Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 44, height: 44,
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
                        color:       kText,
                        fontSize:    28,
                        fontWeight:  FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin Panel',
                      style: TextStyle(color: kSlate, fontSize: 13, letterSpacing: 1.0),
                    ),

                    const SizedBox(height: 40),

                    // ── Card container ────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                      decoration: BoxDecoration(
                        color:        kSurface,
                        borderRadius: BorderRadius.circular(24),
                        border:       Border.all(color: kBorder),
                        boxShadow: [
                          BoxShadow(
                            color:      Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset:     const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [

                          // ── PIN dots ───────────────────────
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(_shakeAnim.value, 0),
                              child: child,
                            ),
                            child: Column(children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color:    _isWrong ? kRose : kSlate,
                                  fontSize: 13,
                                  fontWeight: _isWrong ? FontWeight.w600 : FontWeight.normal,
                                ),
                                child: Text(
                                  _isWrong   ? 'Incorrect PIN. Try again.'
                                  : _isSuccess ? 'Access granted ✓'
                                  : 'Enter Admin PIN',
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (i) {
                                  final filled = i < _entered.length;
                                  Color dotColor;
                                  if (_isSuccess)    dotColor = kEmerald;
                                  else if (_isWrong) dotColor = kRose;
                                  else if (filled)   dotColor = kAccent;
                                  else               dotColor = kBorder;

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    width:  filled ? 16 : 12,
                                    height: filled ? 16 : 12,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      boxShadow: filled && !_isWrong && !_isSuccess
                                          ? [BoxShadow(
                                              color:      kAccent.withOpacity(0.3),
                                              blurRadius: 8,
                                            )]
                                          : [],
                                    ),
                                  );
                                }),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 32),

                          // ── Number pad ─────────────────────
                          _buildPad(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Footer
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

  Widget _buildPad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['',  '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72, height: 68);
              final isDel = key == 'del';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _PinKey(
                  label: key,
                  isDel: isDel,
                  onTap: isDel ? _onDelete : () => _onKey(key),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
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
    return CustomPaint(
      painter: _RadioWavePainter(),
    );
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

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      2.5,
      Paint()..color = Colors.white,
    );

    // Draw arc waves emanating outward (left & right)
    final radii = [6.0, 10.0, 14.0];
    for (final r in radii) {
      // Right side arcs
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.7,
        1.4,
        false,
        paint,
      );
      // Left side arcs
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

// ─────────────────────────────────────────────
// PIN KEY BUTTON
// ─────────────────────────────────────────────
class _PinKey extends StatefulWidget {
  final String       label;
  final bool         isDel;
  final VoidCallback onTap;

  const _PinKey({required this.label, required this.isDel, required this.onTap});

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width:  72,
        height: 68,
        decoration: BoxDecoration(
          color: _pressed
              ? kAccent.withOpacity(0.08)
              : kBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed ? kAccent.withOpacity(0.4) : kBorder,
            width: 1.5,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset:     const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: widget.isDel
              ? Icon(
                  Icons.backspace_outlined,
                  color: _pressed ? kAccent : kSlate,
                  size: 20,
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    color:      _pressed ? kAccent : kText,
                    fontSize:   24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}