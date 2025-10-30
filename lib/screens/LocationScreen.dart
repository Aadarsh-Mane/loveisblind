import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:loveisblind/constants/blind_theme.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  bool _isListening = false;
  bool _isLoadingLocation = false;
  String _locationText = 'Location not retrieved yet';
  String _statusMessage = 'Ready to get your location';
  Position? _currentPosition;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeSpeech();
    _announceScreenOpening();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); // Slower speech for better comprehension
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speechToText.initialize(
      onError: (error) => _speak('Speech recognition error: ${error.errorMsg}'),
      onStatus: (status) {
        if (status == 'done') {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      _speak('Speech recognition not available on this device');
    }
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _announceScreenOpening() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _speak(
        'Opening Location Screen. Say "get location" to retrieve your current position, or "help" for available commands.');
  }

  Future<void> _startListening() async {
    if (!_isListening && await _speechToText.hasPermission) {
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening for commands...';
      });

      AccessibilityTheme.provideHapticFeedback();
      await _speak('Listening for your command');

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: 'en_US',
      );
    } else {
      await _speak(
          'Cannot start listening. Please check microphone permissions.');
    }
  }

  void _onSpeechResult(result) {
    String command = result.recognizedWords.toLowerCase().trim();

    setState(() {
      _statusMessage = 'Processing command: $command';
    });

    _processVoiceCommand(command);
  }

  Future<void> _processVoiceCommand(String command) async {
    if (command.contains('get location') ||
        command.contains('location') ||
        command.contains('where am i')) {
      await _getCurrentLocation();
    } else if (command.contains('repeat') || command.contains('say again')) {
      await _repeatLocation();
    } else if (command.contains('share') || command.contains('send')) {
      await _shareLocation();
    } else if (command.contains('help')) {
      await _provideHelp();
    } else if (command.contains('back') || command.contains('exit')) {
      await _exitScreen();
    } else {
      await _speak(
          'Command not recognized. Say "help" for available commands.');
      setState(() {
        _statusMessage = 'Command not recognized';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _statusMessage = 'Getting your location...';
    });

    await _speak('Getting your current location, please wait');
    AccessibilityTheme.provideHapticFeedback();

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled';
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _currentAddress = _buildAddressString(place);
        _locationText = _currentAddress!;
      } else {
        _locationText =
            'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
            'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}';
      }

      setState(() {
        _statusMessage = 'Location retrieved successfully';
      });

      AccessibilityTheme.provideSuccessFeedback();
      await _speak('Location found: $_locationText');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error getting location: $e';
        _locationText = 'Unable to get location';
      });

      AccessibilityTheme.provideErrorFeedback();
      await _speak('Error getting location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  String _buildAddressString(Placemark place) {
    List<String> addressParts = [];

    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }

    return addressParts.join(', ');
  }

  Future<void> _repeatLocation() async {
    if (_currentAddress != null) {
      await _speak('Your current location is: $_currentAddress');
    } else {
      await _speak('No location available. Say "get location" first.');
    }
  }

  Future<void> _shareLocation() async {
    if (_currentPosition != null) {
      String shareText = 'My current location: $_locationText\n'
          'Coordinates: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}';

      // Here you would integrate with sharing services
      await _speak('Location ready to share: $shareText');
      AccessibilityTheme.provideSuccessFeedback();
    } else {
      await _speak('No location to share. Get your location first.');
    }
  }

  Future<void> _provideHelp() async {
    String helpText = 'Available voice commands: '
        'Say "get location" to find your current position. '
        'Say "repeat" to hear the location again. '
        'Say "share" to prepare location for sharing. '
        'Say "back" to exit this screen.';

    await _speak(helpText);
  }

  Future<void> _exitScreen() async {
    await _speak('Closing location screen');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _exitScreen,
          tooltip: 'Go back',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
        child: Column(
          children: [
            // Status message
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
                decoration: BoxDecoration(
                  color: AccessibilityTheme.surfaceColor,
                  border: Border.all(color: AccessibilityTheme.primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: AccessibilityTheme.spacingL),

            // Location display
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                decoration: BoxDecoration(
                  color: AccessibilityTheme.surfaceColor,
                  border: Border.all(color: AccessibilityTheme.primaryColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 48.0,
                      color: AccessibilityTheme.primaryColor,
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingM),
                    Semantics(
                      label: 'Current location',
                      child: Text(
                        _locationText,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_isLoadingLocation) ...[
                      const SizedBox(height: AccessibilityTheme.spacingM),
                      const CircularProgressIndicator(
                        strokeWidth: 4.0,
                        color: AccessibilityTheme.primaryColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AccessibilityTheme.spacingL),

            // Voice control button
            AccessibleButton(
              text: _isListening ? 'Listening...' : 'Tap to Speak Command',
              icon: _isListening ? Icons.mic : Icons.mic_none,
              onPressed: _isListening ? () {} : _startListening,
              semanticLabel: _isListening
                  ? 'Currently listening for voice commands'
                  : 'Tap to start voice command',
            ),

            const SizedBox(height: AccessibilityTheme.spacingM),

            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    text: 'Get Location',
                    icon: Icons.my_location,
                    onPressed: _isLoadingLocation ? () {} : _getCurrentLocation,
                    isPrimary: false,
                    semanticLabel: 'Get current location',
                  ),
                ),
                const SizedBox(width: AccessibilityTheme.spacingS),
                Expanded(
                  child: AccessibleButton(
                    text: 'Help',
                    icon: Icons.help,
                    onPressed: _provideHelp,
                    isPrimary: false,
                    semanticLabel: 'Get help with voice commands',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
