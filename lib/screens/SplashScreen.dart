import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:loveisblind/screens/MainScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final FlutterTts flutterTts = FlutterTts();

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeAnimations();
    _startSplashSequence();
  }

  Future<void> _initializeTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);

    // Announce app launch
    await Future.delayed(const Duration(milliseconds: 500));
    await flutterTts.speak(
        "Welcome to Assistive Vision App. Loading your voice assistant.");
  }

  void _initializeAnimations() {
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Scale animation for the icon
    _scaleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Rotation animation for the loading indicator
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _fadeController.forward();
    _scaleController.forward();
  }

  void _startSplashSequence() async {
    setState(() {
      _isVisible = true;
    });

    // Haptic feedback for users
    HapticFeedback.mediumImpact();

    // Wait for 4 seconds total
    await Future.delayed(const Duration(seconds: 4));

    // Announce transition
    await flutterTts.speak("Opening Voice Assistant");
    await Future.delayed(const Duration(milliseconds: 500));

    // Navigate to main app
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const VoiceAssistantApp()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo/Icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Eye icon representing vision assistance
                          Icon(
                            Icons.visibility,
                            size: 80,
                            color: Colors.blue.shade700,
                            semanticLabel: 'Vision assistance icon',
                          ),
                          // Animated sound waves around the eye
                          ...List.generate(3, (index) {
                            return AnimatedBuilder(
                              animation: _fadeController,
                              builder: (context, child) {
                                return Container(
                                  width: 140 + (index * 20),
                                  height: 140 + (index * 20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(
                                        0.3 * (1 - _fadeController.value),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // App Title
                  AnimatedOpacity(
                    opacity: _isVisible ? 1.0 : 0.0,
                    duration: const Duration(seconds: 2),
                    child: Column(
                      children: [
                        Text(
                          'Assistive Vision',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            letterSpacing: 1.5,
                          ),
                          semanticsLabel: 'Assistive Vision App',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your Voice Assistant',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          semanticsLabel: 'Your Voice Assistant',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Loading indicator
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade400,
                            ),
                            semanticsLabel: 'Loading',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Loading text
                  AnimatedOpacity(
                    opacity: _isVisible ? 1.0 : 0.0,
                    duration: const Duration(seconds: 1),
                    child: Text(
                      'Initializing voice services...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      semanticsLabel: 'Initializing voice services',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
