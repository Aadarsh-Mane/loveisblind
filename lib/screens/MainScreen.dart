import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveisblind/constants/blind_theme.dart';
import 'package:loveisblind/screens/TextRecognitionScreen.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const VoiceAccessibilityApp());
}

class VoiceAccessibilityApp extends StatelessWidget {
  const VoiceAccessibilityApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Assistant for Blind',
      theme: AccessibilityTheme.theme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isListening = false;
  String _currentStatus = "Tap anywhere to start voice commands";

  // Speech recognition and TTS
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechEnabled = false;
  String _lastWords = '';

  // Loading state
  bool _isInitializing = true;

  // Main features available
  final List<AppFeature> _features = [
    AppFeature(
      name: "Text Reader",
      description: "Point camera at text to read aloud",
      icon: Icons.camera_alt,
      voiceCommand: "read text",
      action: FeatureAction.textReader,
    ),
    AppFeature(
      name: "AI Assistant",
      description: "Ask any question and get spoken answers",
      icon: Icons.psychology,
      voiceCommand: "ask question",
      action: FeatureAction.aiAssistant,
    ),
    AppFeature(
      name: "Location Helper",
      description: "Find out where you are right now",
      icon: Icons.location_on,
      voiceCommand: "where am i",
      action: FeatureAction.location,
    ),
    AppFeature(
      name: "Make Call",
      description: "Call your contacts by voice",
      icon: Icons.phone,
      voiceCommand: "make call",
      action: FeatureAction.makeCall,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeSpeechServices();
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeSpeechServices() async {
    // Request microphone permission
    await Permission.microphone.request();

    // Initialize TTS
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Initialize Speech-to-Text
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        setState(() {
          if (status == 'listening') {
            _isListening = true;
            _currentStatus = "Listening... Say your command";
          } else if (status == 'notListening') {
            _isListening = false;
            _currentStatus = "Tap anywhere to start voice commands";
          }
        });
      },
      onError: (error) {
        setState(() {
          _isListening = false;
          _currentStatus = "Error: ${error.errorMsg}";
        });
        _speak(
            "Sorry, there was an error with voice recognition. Please try again.");
      },
    );

    setState(() {
      _isInitializing = false;
    });

    // Speak welcome message after initialization
    await Future.delayed(const Duration(milliseconds: 500));
    _speakWelcomeMessage();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _speakWelcomeMessage() async {
    const welcomeMsg = "Welcome to Voice Assistant for the blind. "
        "You can tap anywhere on the screen to start voice commands. "
        "Available commands are: read text, ask question, where am I, or make call. "
        "You can also tap the buttons directly.";

    await _speak(welcomeMsg);
  }

  void _toggleListening() {
    if (!_speechEnabled) {
      _speak(
          "Speech recognition is not available. Please check your microphone permissions.");
      return;
    }

    if (_isListening) {
      _stopVoiceRecognition();
    } else {
      _startVoiceRecognition();
    }
  }

  void _startVoiceRecognition() {
    _lastWords = '';
    AccessibilityTheme.provideHapticFeedback();

    _speechToText.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });

        // Process the command when speech is finalized
        if (result.finalResult) {
          _handleVoiceCommand(_lastWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: "en_US",
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  void _stopVoiceRecognition() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
      _currentStatus = "Tap anywhere to start voice commands";
    });
  }

  Future<void> _handleVoiceCommand(String command) async {
    command = command.toLowerCase().trim();
    print("Voice command received: $command"); // Debug print

    bool commandFound = false;

    // Check for feature commands
    for (var feature in _features) {
      if (command.contains(feature.voiceCommand) ||
          _isCommandMatch(command, feature.voiceCommand)) {
        await _speak("Opening ${feature.name}");
        await Future.delayed(const Duration(milliseconds: 1000));
        _navigateToFeature(feature.action);
        commandFound = true;
        break;
      }
    }

    // Additional command variations
    if (!commandFound) {
      if (command.contains("help") || command.contains("what can you do")) {
        _speakHelpMessage();
        commandFound = true;
      } else if (command.contains("repeat") || command.contains("again")) {
        _speakWelcomeMessage();
        commandFound = true;
      }
    }

    // If no command matched, provide help
    if (!commandFound) {
      await _speak(
          "I didn't understand that command. Let me tell you what I can do.");
      await Future.delayed(const Duration(milliseconds: 1000));
      _speakHelpMessage();
    }
  }

  bool _isCommandMatch(String spokenCommand, String targetCommand) {
    // More flexible command matching
    List<String> spokenWords = spokenCommand.split(' ');
    List<String> targetWords = targetCommand.split(' ');

    int matchCount = 0;
    for (String targetWord in targetWords) {
      if (spokenWords.any(
          (word) => word.contains(targetWord) || targetWord.contains(word))) {
        matchCount++;
      }
    }

    // If at least 60% of words match, consider it a match
    return matchCount >= (targetWords.length * 0.6);
  }

  Future<void> _speakHelpMessage() async {
    const helpMsg = "Here are the available commands: "
        "Say 'read text' to scan and read text from camera. "
        "Say 'ask question' to use the AI assistant. "
        "Say 'where am I' to get your current location. "
        "Say 'make call' to call your contacts. "
        "You can also tap any button directly.";

    await _speak(helpMsg);
  }

  void _navigateToFeature(FeatureAction action) {
    switch (action) {
      case FeatureAction.textReader:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TextReaderScreen()),
        );
        break;
      case FeatureAction.aiAssistant:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const AIAssistantTextScreen()),
        );
        break;
      case FeatureAction.location:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LocationScreen()),
        );
        break;
      case FeatureAction.makeCall:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CallScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Initializing Voice Assistant...',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        centerTitle: true,
      ),
      body: GestureDetector(
        // Full screen tap to activate voice
        onTap: _toggleListening,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Voice status indicator
                Semantics(
                  label: _currentStatus,
                  child: Container(
                    padding: const EdgeInsets.all(AccessibilityTheme.spacingL),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AccessibilityTheme.successColor.withOpacity(0.1)
                          : AccessibilityTheme.surfaceColor,
                      border: Border.all(
                        color: _isListening
                            ? AccessibilityTheme.successColor
                            : AccessibilityTheme.primaryColor,
                        width: 3.0,
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 64.0,
                          color: _isListening
                              ? AccessibilityTheme.successColor
                              : AccessibilityTheme.primaryColor,
                        ),
                        const SizedBox(height: AccessibilityTheme.spacingM),
                        Text(
                          _currentStatus,
                          style: Theme.of(context).textTheme.displayMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (_isListening && _lastWords.isNotEmpty) ...[
                          const SizedBox(height: AccessibilityTheme.spacingS),
                          Text(
                            'Heard: $_lastWords',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AccessibilityTheme.spacingXL),

                // Available features list
                Semantics(
                  label: "Available features",
                  child: Text(
                    "Available Commands:",
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AccessibilityTheme.spacingL),

                // Feature buttons (also accessible via voice)
                Expanded(
                  child: ListView.builder(
                    itemCount: _features.length,
                    itemBuilder: (context, index) {
                      final feature = _features[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AccessibilityTheme.spacingS,
                        ),
                        child: AccessibleButton(
                          text: feature.name,
                          semanticLabel:
                              '${feature.name}. ${feature.description}. Say "${feature.voiceCommand}" or tap to activate.',
                          icon: feature.icon,
                          onPressed: () async {
                            await _speak("Opening ${feature.name}");
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            _navigateToFeature(feature.action);
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AccessibilityTheme.spacingL),

                // Emergency/Help button
                AccessibleButton(
                  text: "Help & Instructions",
                  semanticLabel:
                      "Help and instructions. Double tap for voice help.",
                  icon: Icons.help,
                  isPrimary: false,
                  onPressed: () {
                    _speakHelpMessage();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Data models
class AppFeature {
  final String name;
  final String description;
  final IconData icon;
  final String voiceCommand;
  final FeatureAction action;

  AppFeature({
    required this.name,
    required this.description,
    required this.icon,
    required this.voiceCommand,
    required this.action,
  });
}

enum FeatureAction {
  textReader,
  aiAssistant,
  location,
  makeCall,
}

// Placeholder screens for each feature
class TextReaderScreen extends StatelessWidget {
  const TextReaderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Reader'),
      ),
      body: const Center(
        child: Text(
          'Text Reader Feature\n(Camera + ML Kit Text Recognition)',
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class LocationScreen extends StatelessWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Helper'),
      ),
      body: const Center(
        child: Text(
          'Location Feature\n(GPS + Reverse Geocoding)',
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class CallScreen extends StatelessWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make Call'),
      ),
      body: const Center(
        child: Text(
          'Call Feature\n(Contact Access + Voice Dialing)',
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
