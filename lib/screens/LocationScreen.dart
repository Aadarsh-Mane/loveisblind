import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:loveisblind/constants/blind_theme.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

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
  bool _isSendingEmail = false;
  String _locationText = 'Location not retrieved yet';
  String _statusMessage = 'Ready to get your location';
  Position? _currentPosition;
  String? _currentAddress;

  // Contact details
  final String _recipientEmail = 'onlyaddy68@gmail.com';
  final String _whatsappNumber = '919326050990'; // Without + for WhatsApp

  // Email configuration - Using Gmail SMTP
  final String _senderEmail = 'your_app_email@gmail.com'; // Your app's email
  final String _senderPassword = 'your_app_password'; // App-specific password

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeSpeech();
    _announceScreenOpening();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speechToText.initialize(
      onError: (error) {
        _speak('Speech recognition error: ${error.errorMsg}');
        // Stop listening on error
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
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
        'Opening Location Screen. Say "get location" to find your current position, '
        '"email location" to send by email, or "whatsapp location" to send via WhatsApp.');
  }

  Future<void> _startListening() async {
    // Stop any existing listening session first
    if (_isListening) {
      await _stopListening();
      return;
    }

    if (await _speechToText.hasPermission) {
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening for commands...';
      });

      AccessibilityTheme.provideHapticFeedback();
      await _speak('Listening');

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 5), // Reduced from 10 to 5
        pauseFor: const Duration(seconds: 2), // Reduced from 3 to 2
        partialResults: false,
        localeId: 'en_US',
        cancelOnError: true, // Important: Cancel on error
      );

      // Auto-stop after timeout
      Future.delayed(const Duration(seconds: 6), () {
        if (_isListening) {
          _stopListening();
        }
      });
    } else {
      await _speak(
          'Cannot start listening. Please check microphone permissions.');
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechResult(result) async {
    String command = result.recognizedWords.toLowerCase().trim();

    setState(() {
      _statusMessage = 'Processing command: $command';
    });

    // Stop listening immediately after getting result
    await _stopListening();

    // Process the command
    await _processVoiceCommand(command);
  }

  Future<void> _processVoiceCommand(String command) async {
    if (command.contains('get location') ||
        command.contains('location') ||
        command.contains('where am i')) {
      await _getCurrentLocation();
    } else if (command.contains('whatsapp')) {
      await _shareLocationViaWhatsApp();
    } else if (command.contains('email') || command.contains('mail')) {
      await _shareLocationViaEmail();
    } else if (command.contains('emergency')) {
      await _sendEmergency();
    } else if (command.contains('repeat') || command.contains('say again')) {
      await _repeatLocation();
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
        throw 'Location services are disabled. Please enable them in settings.';
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
      await _speak(
          'Location found: $_locationText. Say "whatsapp location" or "email location" to share.');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
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

  Future<void> _shareLocationViaWhatsApp() async {
    if (_currentPosition == null) {
      await _speak('Please get your location first. Say "get location"');
      return;
    }

    setState(() {
      _statusMessage = 'Opening WhatsApp...';
    });

    String message = 'My current location:\n'
        '$_locationText\n\n'
        'Google Maps: https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';

    try {
      // Try WhatsApp Web URL first (most reliable)
      final Uri whatsappUrl = Uri.parse(
          'https://api.whatsapp.com/send?phone=$_whatsappNumber&text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(whatsappUrl)) {
        bool launched = await launchUrl(
          whatsappUrl,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          await _speak(
              'Opening WhatsApp with your location. Tap send to share.');
          AccessibilityTheme.provideSuccessFeedback();
          setState(() {
            _statusMessage = 'WhatsApp opened';
          });
          return;
        }
      }

      // Try alternative WhatsApp URL
      final Uri whatsappAlt = Uri.parse(
          'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(whatsappAlt)) {
        bool launched = await launchUrl(
          whatsappAlt,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          await _speak(
              'Opening WhatsApp with your location. Tap send to share.');
          AccessibilityTheme.provideSuccessFeedback();
          return;
        }
      }

      // If WhatsApp can't be opened, copy to clipboard
      await _copyLocationToClipboard();
      await _speak(
          'WhatsApp could not be opened. Location copied to clipboard. '
          'Open WhatsApp manually and paste to share.');
    } catch (e) {
      await _copyLocationToClipboard();
      await _speak('Could not open WhatsApp. Location copied to clipboard.');
    }
  }

  Future<void> _shareLocationViaEmail() async {
    if (_currentPosition == null) {
      await _speak('Please get your location first. Say "get location"');
      return;
    }

    bool emailSent = await _sendEmailViaUrlLauncher();

    if (!emailSent) {
      await _copyLocationToClipboard();
      await _speak(
          'Email app could not be opened. Location copied to clipboard. '
          'Open your email app and paste to share.');
    }
  }

  Future<bool> _sendEmailViaUrlLauncher() async {
    try {
      final String subject = Uri.encodeComponent('My Current Location');
      final String body = Uri.encodeComponent('Hello,\n\n'
          'My current location is:\n'
          '$_locationText\n\n'
          'Google Maps Link:\n'
          'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}\n\n'
          'Coordinates:\n'
          'Latitude: ${_currentPosition!.latitude}\n'
          'Longitude: ${_currentPosition!.longitude}\n\n'
          'Sent from Love is Blind App');

      final Uri emailUri =
          Uri.parse('mailto:$_recipientEmail?subject=$subject&body=$body');

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        await _speak('Opening email app with your location. Just tap send.');
        AccessibilityTheme.provideSuccessFeedback();
        setState(() {
          _statusMessage = 'Email app opened';
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error with URL launcher email: $e');
      return false;
    }
  }

  Future<void> _sendEmergency() async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    setState(() {
      _statusMessage = 'Sending EMERGENCY location...';
    });

    await _speak('Sending emergency location via WhatsApp and email');

    // Try both WhatsApp and Email
    await _shareLocationViaWhatsApp();
    await Future.delayed(const Duration(seconds: 2));
    await _shareLocationViaEmail();
  }

  Future<void> _copyLocationToClipboard() async {
    if (_currentPosition == null) {
      await _speak('No location to copy. Get location first.');
      return;
    }

    String message = 'My current location: $_locationText\n'
        'Google Maps: https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';

    await Clipboard.setData(ClipboardData(text: message));

    AccessibilityTheme.provideSuccessFeedback();
    setState(() {
      _statusMessage = 'Location copied to clipboard';
    });
  }

  Future<void> _repeatLocation() async {
    if (_currentAddress != null) {
      await _speak(
          'Your location is: $_currentAddress. Say "whatsapp location" or "email location" to share.');
    } else {
      await _speak('No location available. Say "get location" first.');
    }
  }

  Future<void> _provideHelp() async {
    String helpText = 'Available voice commands: '
        '"Get location" to find where you are. '
        '"WhatsApp location" to send via WhatsApp. '
        '"Email location" to send via email. '
        '"Emergency" to share via both WhatsApp and email. '
        '"Repeat" to hear your location again. '
        '"Back" to exit this screen.';

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
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_isSendingEmail || _isLoadingLocation)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(),
                      ),
                  ],
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
                    if (_currentPosition != null) ...[
                      const SizedBox(height: AccessibilityTheme.spacingM),
                      Text(
                        'Ready to share',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
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
              onPressed: _startListening,
              semanticLabel: _isListening
                  ? 'Currently listening for voice commands'
                  : 'Tap to start voice command',
              isLarge: true,
            ),

            const SizedBox(height: AccessibilityTheme.spacingM),

            // Quick action buttons - Row 1
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    text: 'Get Location',
                    icon: Icons.my_location,
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    isPrimary: false,
                    semanticLabel: 'Get current location',
                  ),
                ),
                const SizedBox(width: AccessibilityTheme.spacingS),
                Expanded(
                  child: AccessibleButton(
                    text: 'WhatsApp',
                    icon: Icons.chat,
                    onPressed: _currentPosition == null
                        ? null
                        : _shareLocationViaWhatsApp,
                    isPrimary: true,
                    isWhatsApp: true,
                    semanticLabel: 'Send location via WhatsApp',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AccessibilityTheme.spacingS),

            // Quick action buttons - Row 2
            Row(
              children: [
                Expanded(
                  child: AccessibleButton(
                    text: 'Email',
                    icon: Icons.email,
                    onPressed: _currentPosition == null
                        ? null
                        : _shareLocationViaEmail,
                    isPrimary: true,
                    semanticLabel: 'Send location via email',
                  ),
                ),
                const SizedBox(width: AccessibilityTheme.spacingS),
                Expanded(
                  child: AccessibleButton(
                    text: 'EMERGENCY',
                    icon: Icons.warning,
                    onPressed: _sendEmergency,
                    isPrimary: false,
                    isEmergency: true,
                    semanticLabel: 'Emergency location sharing',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AccessibilityTheme.spacingS),

            AccessibleButton(
              text: 'Help',
              icon: Icons.help_outline,
              onPressed: _provideHelp,
              isPrimary: false,
              semanticLabel: 'Get help with voice commands',
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced AccessibleButton widget
class AccessibleButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isEmergency;
  final bool isWhatsApp;
  final bool isLarge;
  final String semanticLabel;

  const AccessibleButton({
    Key? key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.isEmergency = false,
    this.isWhatsApp = false,
    this.isLarge = false,
    required this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;

    if (isEmergency) {
      backgroundColor = Colors.red;
      foregroundColor = Colors.white;
    } else if (isWhatsApp) {
      backgroundColor = const Color(0xFF25D366); // WhatsApp green
      foregroundColor = Colors.white;
    } else if (isPrimary) {
      backgroundColor = AccessibilityTheme.primaryColor;
      foregroundColor = Colors.white;
    } else {
      backgroundColor = AccessibilityTheme.surfaceColor;
      foregroundColor = AccessibilityTheme.primaryColor;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: isLarge ? 32 : 24),
        label: Text(
          text,
          style: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(
            horizontal: AccessibilityTheme.spacingM,
            vertical: isLarge
                ? AccessibilityTheme.spacingL
                : AccessibilityTheme.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isEmergency
                  ? Colors.red
                  : isWhatsApp
                      ? const Color(0xFF25D366)
                      : AccessibilityTheme.primaryColor,
              width: (isPrimary || isEmergency || isWhatsApp) ? 0 : 2,
            ),
          ),
        ),
      ),
    );
  }
}
