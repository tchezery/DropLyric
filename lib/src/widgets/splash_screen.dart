import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// Uma Splash Screen estilo Spotify que apresenta o logo centralizado
/// e realiza uma transição suave e fluida (fade + scale) ao liberar o app.
class SpotifySplashScreen extends StatefulWidget {
  const SpotifySplashScreen({
    super.key,
    required this.onFinish,
    this.isReady = true,
    this.minimumDuration = const Duration(milliseconds: 1200),
  });

  final VoidCallback onFinish;
  final bool isReady;
  final Duration minimumDuration;

  @override
  State<SpotifySplashScreen> createState() => _SpotifySplashScreenState();
}

class _SpotifySplashScreenState extends State<SpotifySplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _minDurationTimer;
  bool _minDurationPassed = false;
  bool _exitStarted = false;

  @override
  void initState() {
    super.initState();

    // Remove o splash nativo do Android/iOS assim que o widget do Flutter entra em tela
    FlutterNativeSplash.remove();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinish();
      }
    });

    _minDurationTimer = Timer(widget.minimumDuration, () {
      if (!mounted) return;
      _minDurationPassed = true;
      _checkAndStartExit();
    });
  }

  @override
  void didUpdateWidget(covariant SpotifySplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) {
      _checkAndStartExit();
    }
  }

  void _checkAndStartExit() {
    if (_minDurationPassed && widget.isReady && !_exitStarted && mounted) {
      _exitStarted = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Ignora toques enquanto a splash está ativa
        return IgnorePointer(
          ignoring: _exitStarted,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/logo.png',
        width: 110,
        height: 110,
        fit: BoxFit.contain,
      ),
    );
  }
}
