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
  String _entered       = '';
  bool   _isWrong       = false;
  bool   _isSuccess     = false;

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
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),    weight: 1),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Logo ──────────────────────────────────────
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: kAccent.withOpacity(0.4), width: 2),
                    boxShadow: [BoxShadow(
                      color: kAccent.withOpacity(0.15), blurRadius: 32, spreadRadius: 4)],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: kAccent, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('CleftTune',
                    style: TextStyle(color: kAccent, fontSize: 28,
                        fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('Admin Panel',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 40),

                // ── PIN dots ──────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Column(children: [
                    Text(
                      _isWrong ? 'Incorrect PIN. Try again.' : 'Enter Admin PIN',
                      style: TextStyle(
                        color:    _isWrong ? kRed : Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < _entered.length;
                        Color dotColor;
                        if (_isSuccess)      dotColor = kGreen;
                        else if (_isWrong)   dotColor = kRed;
                        else if (filled)     dotColor = kAccent;
                        else                 dotColor = Colors.white12;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width:  filled ? 18 : 14,
                          height: filled ? 18 : 14,
                          decoration: BoxDecoration(
                            color:  dotColor,
                            shape:  BoxShape.circle,
                            boxShadow: filled && !_isWrong
                                ? [BoxShadow(color: kAccent.withOpacity(0.4),
                                    blurRadius: 8)]
                                : [],
                          ),
                        );
                      }),
                    ),
                  ]),
                ),

                const SizedBox(height: 40),

                // ── Number pad ────────────────────────────────
                _buildPad(),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 80, height: 72);

              final isDel = key == 'del';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _PinKey(
                  label:   key,
                  isDel:   isDel,
                  onTap:   isDel ? _onDelete : () => _onKey(key),
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
// PIN KEY BUTTON
// ─────────────────────────────────────────────
class _PinKey extends StatelessWidget {
  final String      label;
  final bool        isDel;
  final VoidCallback onTap;

  const _PinKey({required this.label, required this.isDel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: kPanel.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: kAccent.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: isDel
              ? const Icon(Icons.backspace_outlined, color: Colors.white54, size: 22)
              : Text(label,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   26,
                    fontWeight: FontWeight.w400,
                  )),
        ),
      ),
    );
  }
}