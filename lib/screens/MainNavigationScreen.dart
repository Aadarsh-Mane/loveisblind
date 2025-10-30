// letter_gesture_examples.dart
import 'package:flutter/material.dart';
import 'package:loveisblind/constants/blind_theme.dart';
import 'package:loveisblind/screens/GestureScreen.dart';
import 'package:loveisblind/screens/LocationScreen.dart';
import 'package:loveisblind/screens/TextRecognitionScreen.dart';
import 'package:loveisblind/screens/VoiceCallingScreen.dart';

// Example: Main navigation screen with letter gestures
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LetterGestureScreen(
      screenName: 'Main Navigation',
      letterActions: {
        'L': () => _navigateToLocationScreen(context),
        'A': () => _navigateToAIAssistantScreen(context),
        'V': () => _navigateToVoiceCallingScreen(
            context), // Fixed: Changed from 'Z' to 'V'
        'H': () => _showHelp(context),
        'S': () => _navigateToSettings(context),
        'E': () => _exitApp(context),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Voice Assistant App'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AccessibilityTheme.primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.touch_app,
                      size: 64,
                      color: AccessibilityTheme.primaryColor,
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      'Draw Letters to Navigate',
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      'Draw anywhere on the screen:',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AccessibilityTheme.spacingL),

              // Letter action list - Fixed to match the letterActions map
              _buildLetterActionCard(
                  'L', 'Location Services', Icons.location_on),
              _buildLetterActionCard('A', 'AI Assistant', Icons.smart_toy),
              _buildLetterActionCard(
                  'V',
                  'Voice Calling',
                  Icons
                      .phone), // Fixed: Changed from 'V' display to match 'V' action
              _buildLetterActionCard('H', 'Help & Tutorial', Icons.help),
              _buildLetterActionCard('S', 'Settings', Icons.settings),
              _buildLetterActionCard('E', 'Exit App', Icons.exit_to_app),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLetterActionCard(String letter, String action, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AccessibilityTheme.spacingS),
      padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: AccessibilityTheme.primaryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AccessibilityTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AccessibilityTheme.spacingS),
          Icon(icon, size: 32, color: AccessibilityTheme.primaryColor),
          const SizedBox(width: AccessibilityTheme.spacingS),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AccessibilityTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLocationScreen(BuildContext context) {
    LetterGestureController.speak('Opening Location Services');
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LocationScreen(),
        ));
  }

  void _navigateToAIAssistantScreen(BuildContext context) {
    LetterGestureController.speak('Opening AI Assistant');
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AIAssistantTextScreen(),
        ));
  }

  void _navigateToVoiceCallingScreen(BuildContext context) {
    LetterGestureController.speak('Opening Voice Calling');
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VoiceCallingScreen(),
        ));
  }

  void _showHelp(BuildContext context) {
    LetterGestureController.speak('Opening Help and Tutorial');
    // Fixed: Navigate to a proper Help screen instead of LocationScreen
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HelpScreen(),
        ));
  }

  void _navigateToSettings(BuildContext context) {
    LetterGestureController.speak('Opening Settings');
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
        ));
  }

  void _exitApp(BuildContext context) {
    LetterGestureController.speak('Exiting application');
    // Show exit confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                LetterGestureController.speak('Exit cancelled');
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                LetterGestureController.speak('Goodbye');
                // You can use SystemNavigator.pop() to exit the app
                // SystemNavigator.pop();
                Navigator.of(context).pop();
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}

// Enhanced Location Screen with letter gestures
class EnhancedLocationScreen extends StatefulWidget {
  const EnhancedLocationScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedLocationScreen> createState() => _EnhancedLocationScreenState();
}

class _EnhancedLocationScreenState extends State<EnhancedLocationScreen> {
  String? _currentLocation;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return LetterGestureScreen(
      screenName: 'Location Services',
      letterActions: {
        'G': () => _getCurrentLocation(),
        'S': () => _shareLocation(),
        'N': () => _findNearbyPlaces(),
        'E': () => _callEmergency(),
        'B': () => Navigator.pop(context),
      },
      onBack: () => Navigator.pop(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Location Services'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              LetterGestureController.speak('Going back to main navigation');
              Navigator.pop(context);
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current location display
              Container(
                padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AccessibilityTheme.primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 64,
                      color: AccessibilityTheme.primaryColor,
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      _currentLocation ?? 'Location not available',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading)
                      const Padding(
                        padding:
                            EdgeInsets.only(top: AccessibilityTheme.spacingS),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AccessibilityTheme.spacingL),

              // Letter gesture actions
              _buildGestureActionCard(
                  'G', 'Get Current Location', Icons.my_location),
              _buildGestureActionCard('S', 'Share Location', Icons.share),
              _buildGestureActionCard('N', 'Nearby Places', Icons.place),
              _buildGestureActionCard(
                  'E', 'Emergency Services', Icons.emergency),
              _buildGestureActionCard('B', 'Back to Main', Icons.arrow_back),

              const SizedBox(height: AccessibilityTheme.spacingL),
              Container(
                padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
                decoration: BoxDecoration(
                  color: AccessibilityTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Draw letters anywhere on the screen to perform actions quickly',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestureActionCard(String letter, String action, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AccessibilityTheme.spacingS),
      padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: AccessibilityTheme.primaryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AccessibilityTheme.primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AccessibilityTheme.spacingS),
          Icon(icon, size: 24, color: AccessibilityTheme.primaryColor),
          const SizedBox(width: AccessibilityTheme.spacingS),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AccessibilityTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _getCurrentLocation() {
    setState(() => _isLoading = true);
    LetterGestureController.speak('Getting current location');

    // Simulate location fetch
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _currentLocation =
            'Mumbai, Maharashtra, India\nLatitude: 19.0760, Longitude: 72.8777';
        _isLoading = false;
      });
      LetterGestureController.speak('Location found successfully');
    });
  }

  void _shareLocation() {
    if (_currentLocation != null) {
      LetterGestureController.speak('Location shared successfully');
    } else {
      LetterGestureController.speak(
          'No location to share. Please get location first.');
    }
  }

  void _findNearbyPlaces() {
    LetterGestureController.speak('Finding nearby places');
    // Navigate to nearby places screen
  }

  void _callEmergency() {
    LetterGestureController.speak(
        'Emergency services. Stay calm. Help is on the way.');
    // Implement emergency call functionality
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LetterGestureScreen(
      screenName: 'Settings',
      letterActions: {
        'B': () => Navigator.pop(context),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              LetterGestureController.speak('Going back to main navigation');
              Navigator.pop(context);
            },
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(AccessibilityTheme.spacingM),
          child: Column(
            children: [
              Text('Settings Screen - Configure your preferences here'),
            ],
          ),
        ),
      ),
    );
  }
}

// Add a placeholder HelpScreen since it was missing
class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LetterGestureScreen(
      screenName: 'Help and Tutorial',
      letterActions: {
        'B': () => Navigator.pop(context),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help & Tutorial'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              LetterGestureController.speak('Going back to main navigation');
              Navigator.pop(context);
            },
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(AccessibilityTheme.spacingM),
          child: Column(
            children: [
              Text('Help and Tutorial Screen - Learn how to use the app'),
            ],
          ),
        ),
      ),
    );
  }
}
