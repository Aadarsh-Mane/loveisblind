import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveisblind/screens/GestureScreen.dart';
import 'package:loveisblind/screens/LocationScreen.dart';
import 'package:loveisblind/screens/MainNavigationScreen.dart';
import 'package:loveisblind/screens/TextRecognitionScreen.dart';
import 'package:loveisblind/screens/VoiceCallingScreen.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const VoiceAssistantApp());
}

class VoiceAssistantApp extends StatelessWidget {
  const VoiceAssistantApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Assistant',
      theme: _buildAppTheme(),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF6750A4),
        foregroundColor: Colors.white,
        elevation: 2.0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1C1B1F),
        ),
        displayMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1B1F),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF1C1B1F),
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF49454F),
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: const Color(0xFF6750A4),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 2.0,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          foregroundColor: const Color(0xFF6750A4),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: Color(0xFF6750A4), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        margin: const EdgeInsets.all(8),
      ),
      iconTheme: const IconThemeData(
        size: 24,
        color: Color(0xFF6750A4),
      ),
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
  String _currentStatus = "Tap to start voice commands";

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
    // AppFeature(
    //   name: "AI Assistant",
    //   description: "Ask any question and get spoken answers",
    //   icon: Icons.psychology,
    //   voiceCommand: "ask question",
    //   action: FeatureAction.aiAssistant,
    // ),
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
    AppFeature(
      name: "Gesture",
      description: "Gesture Detection",
      icon: Icons.gesture,
      voiceCommand: "gesture",
      action: FeatureAction.gesture,
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
            _currentStatus = "Tap to start voice commands";
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
    const welcomeMsg = "Welcome to Voice Assistant. "
        "You can tap the microphone to start voice commands. "
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
    HapticFeedback.lightImpact();

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
      _currentStatus = "Tap to start voice commands";
    });
  }

  Future<void> _handleVoiceCommand(String command) async {
    command = command.toLowerCase().trim();
    print("Voice command received: $command");

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
    List<String> spokenWords = spokenCommand.split(' ');
    List<String> targetWords = targetCommand.split(' ');

    int matchCount = 0;
    for (String targetWord in targetWords) {
      if (spokenWords.any(
          (word) => word.contains(targetWord) || targetWord.contains(word))) {
        matchCount++;
      }
    }

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
          MaterialPageRoute(builder: (context) => const VoiceCallingScreen()),
        );
        break;
      case FeatureAction.gesture:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Voice status indicator
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.green.withOpacity(0.2)
                              : Theme.of(context).colorScheme.primaryContainer,
                          border: Border.all(
                            color: _isListening
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                            width: 2.0,
                          ),
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 40.0,
                          color: _isListening
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentStatus,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_isListening && _lastWords.isNotEmpty) ...[
                      const SizedBox(height: 8),
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

            const SizedBox(height: 24),

            // Available features title
            Text(
              "Available Features",
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Feature buttons
            Expanded(
              child: ListView.builder(
                itemCount: _features.length,
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(
                        feature.icon,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        feature.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      subtitle: Text(
                        feature.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await _speak("Opening ${feature.name}");
                        await Future.delayed(const Duration(milliseconds: 500));
                        _navigateToFeature(feature.action);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Help button
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _speakHelpMessage();
              },
              icon: const Icon(Icons.help),
              label: const Text("Help & Instructions"),
            ),
          ],
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

enum FeatureAction { textReader, aiAssistant, location, makeCall, gesture }

// Feature screens
class TextReaderScreen extends StatefulWidget {
  const TextReaderScreen({Key? key}) : super(key: key);

  @override
  State<TextReaderScreen> createState() => _TextReaderScreenState();
}

class _TextReaderScreenState extends State<TextReaderScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _announceScreen();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _announceScreen() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _flutterTts.speak("Opening Text Reader Screen");
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Reader'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt,
                size: 80,
                color: Color(0xFF6750A4),
              ),
              SizedBox(height: 24),
              Text(
                'Text Reader Feature',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Camera + ML Kit Text Recognition functionality will be implemented here',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
