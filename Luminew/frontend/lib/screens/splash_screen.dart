// fileName: lib/screens/splash_screen.dart
// 待機畫面：登入後顯示一次，點擊任意處淡化跳轉至主頁

import 'package:flutter/material.dart';

const Color _kGooseYellow = Color(0xFFFFFDF0);

class SplashScreen extends StatefulWidget {
  final Widget destination; // 登入後應前往的頁面
  final VoidCallback? onEntered; // 進入後通知外部重置狀態

  const SplashScreen({
    super.key,
    required this.destination,
    this.onEntered,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeOut;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onTap() async {
    if (_isExiting) return;
    _isExiting = true;

    await _fadeController.forward();

    if (!mounted) return;
    widget.onEntered?.call(); // 通知外部重置 _showSplash
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.destination,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: FadeTransition(
        opacity: _fadeOut,
        child: Scaffold(
          backgroundColor: _kGooseYellow,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO 圖片，自適應寬度 60%
                Image.asset(
                  'assets/LOGO.png',
                  width: MediaQuery.of(context).size.width * 0.6,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 48),
                // 提示文字，帶輕微閃爍動畫
                _PulsingHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 輕微脈衝閃爍的提示文字
class _PulsingHint extends StatefulWidget {
  @override
  State<_PulsingHint> createState() => _PulsingHintState();
}

class _PulsingHintState extends State<_PulsingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: const Text(
        '點擊任意處繼續',
        style: TextStyle(
          color: Color(0xFF675B83),
          fontSize: 14,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
