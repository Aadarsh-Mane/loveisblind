import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveisblind/constants/blind_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class VoiceCallingScreen extends StatefulWidget {
  const VoiceCallingScreen({Key? key}) : super(key: key);

  @override
  State<VoiceCallingScreen> createState() => _VoiceCallingScreenState();
}

class _VoiceCallingScreenState extends State<VoiceCallingScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _speechEnabled = false;
  bool _contactsLoaded = false;
  String _lastWords = '';
  String _status = 'Loading contacts...';

  // Device contacts
  List<Contact> _deviceContacts = [];
  Map<String, String> _contactsMap = {};

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _loadContacts();
    _initSpeech();
  }

  void _initializeTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5); // Slower for better clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _loadContacts() async {
    try {
      // Request contacts permission
      if (!await FlutterContacts.requestPermission()) {
        setState(() {
          _status = 'Contacts permission required to make calls';
        });
        await _speak(
            'Contacts permission required to access your phone contacts');
        return;
      }

      // Load contacts from device
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      setState(() {
        _deviceContacts = contacts
            .where((contact) =>
                contact.displayName.isNotEmpty && contact.phones.isNotEmpty)
            .toList();

        // Create a map for easier searching
        _contactsMap.clear();
        for (Contact contact in _deviceContacts) {
          if (contact.displayName.isNotEmpty && contact.phones.isNotEmpty) {
            String name = contact.displayName.toLowerCase();
            String phone = contact.phones.first.number;

            // Clean phone number
            phone = phone.replaceAll(RegExp(r'[^\d+]'), '');

            _contactsMap[name] = phone;

            // Also add first name for easier recognition
            List<String> nameParts = name.split(' ');
            if (nameParts.isNotEmpty) {
              String firstName = nameParts.first.toLowerCase();
              if (!_contactsMap.containsKey(firstName)) {
                _contactsMap[firstName] = phone;
              }
            }
          }
        }

        _contactsLoaded = true;
        _status = 'Ready. Tap microphone to speak';
      });

      await _announceScreenOpening();
    } catch (e) {
      setState(() {
        _status = 'Error loading contacts';
        _contactsLoaded = false;
      });
      await _speak('Error loading contacts from device');
    }
  }

  void _initSpeech() async {
    // Request microphone permission
    final microphoneStatus = await Permission.microphone.request();
    if (microphoneStatus != PermissionStatus.granted) {
      await _speak('Microphone permission required for voice commands');
      return;
    }

    _speechEnabled = await _speech.initialize(
      onError: (errorNotification) {
        setState(() {
          _status = 'Error. Tap microphone to try again';
          _isListening = false;
        });
        _speak('Error occurred. Please try again');
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
    );

    if (_speechEnabled && _contactsLoaded) {
      setState(() {
        _status = 'Ready. Say "Call" and name, or "Emergency"';
      });
    } else if (!_speechEnabled) {
      setState(() {
        _status = 'Speech recognition not available';
      });
      await _speak('Speech recognition not available on this device');
    }
  }

  Future<void> _announceScreenOpening() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (_contactsMap.isEmpty) {
      await _speak(
          'Voice Calling Screen opened. No contacts found. Please add contacts to your phone.');
      return;
    }

    await _speak(
        'Voice Calling Screen opened. ${_contactsMap.length} contacts loaded. '
        'Say "Call" and contact name, or say "Emergency" to call 112. '
        'Tap the microphone button to start.');
  }

  Future<void> _speak(String text) async {
    await _tts.stop(); // Stop any ongoing speech first
    await _tts.speak(text);
  }

  void _startListening() async {
    // Stop any existing listening session first
    if (_isListening) {
      await _stopListening();
      return;
    }

    if (!_speechEnabled) {
      await _speak('Speech recognition not available');
      return;
    }

    AccessibilityTheme.provideHapticFeedback();
    await _speak('Listening');

    setState(() {
      _isListening = true;
      _status = 'Listening...';
      _lastWords = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _status = 'Heard: $_lastWords';
        });

        // Process immediately for emergency
        String command = result.recognizedWords.toLowerCase();
        if (command.contains('emergency') ||
            command.contains('help') ||
            command.contains('112') ||
            command.contains('police') ||
            command.contains('ambulance')) {
          _stopListening();
          _makeEmergencyCall();
          return;
        }

        // Process other commands when final
        if (result.finalResult) {
          _stopListening();
          _processVoiceCommand(command);
        }
      },
      listenFor: const Duration(seconds: 5), // Reduced from 10
      pauseFor: const Duration(seconds: 2), // Reduced from 3
      cancelOnError: true,
      partialResults: true, // To catch emergency faster
    );

    // Auto-stop after timeout
    Future.delayed(const Duration(seconds: 6), () {
      if (_isListening) {
        _stopListening();
      }
    });
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    await _speech.stop();
    setState(() {
      _isListening = false;
      if (_lastWords.isEmpty) {
        _status = 'No command heard. Tap to try again';
      }
    });
    AccessibilityTheme.provideHapticFeedback();
  }

  void _processVoiceCommand(String command) async {
    // Clean the command
    String cleanCommand = command
        .replaceAll('please', '')
        .replaceAll('could you', '')
        .replaceAll('can you', '')
        .trim()
        .toLowerCase();

    // Check for emergency first (already handled in onResult, but double-check)
    if (cleanCommand.contains('emergency') ||
        cleanCommand.contains('112') ||
        cleanCommand.contains('help')) {
      await _makeEmergencyCall();
      return;
    }

    // Check for call command
    if (cleanCommand.startsWith('call ')) {
      String contactName = cleanCommand.substring(5).trim();
      await _makeCall(contactName);
    } else if (cleanCommand.contains('call ')) {
      int callIndex = cleanCommand.indexOf('call ');
      String contactName = cleanCommand.substring(callIndex + 5).trim();
      await _makeCall(contactName);
    } else if (cleanCommand == 'stop' || cleanCommand == 'cancel') {
      setState(() {
        _status = 'Cancelled. Tap microphone to start';
      });
      await _speak('Cancelled');
    } else {
      setState(() {
        _status = 'Say "Call" and name, or "Emergency"';
      });
      await _speak(
          'Please say Call followed by contact name, or say Emergency');
    }
  }

  Future<void> _makeCall(String contactName) async {
    if (_contactsMap.isEmpty) {
      setState(() {
        _status = 'No contacts available';
      });
      await _speak('No contacts found on device');
      AccessibilityTheme.provideErrorFeedback();
      return;
    }

    // Find matching contact
    String? phoneNumber;
    String? foundContactName;

    // Direct match first
    if (_contactsMap.containsKey(contactName.toLowerCase())) {
      phoneNumber = _contactsMap[contactName.toLowerCase()];
      foundContactName = contactName;
    } else {
      // Fuzzy matching for partial names
      for (String contact in _contactsMap.keys) {
        if (contact.contains(contactName.toLowerCase()) ||
            contactName.toLowerCase().contains(contact)) {
          phoneNumber = _contactsMap[contact];
          foundContactName = contact;
          break;
        }
      }
    }

    if (phoneNumber != null && foundContactName != null) {
      setState(() {
        _status = 'Calling $foundContactName';
      });

      await _speak('Calling $foundContactName');
      AccessibilityTheme.provideSuccessFeedback();

      // Make the actual call
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          throw Exception('Cannot make calls');
        }
      } catch (e) {
        setState(() {
          _status = 'Error: Unable to make call';
        });
        await _speak('Error making call. Please try again.');
        AccessibilityTheme.provideErrorFeedback();
      }
    } else {
      setState(() {
        _status = 'Contact "$contactName" not found';
      });

      // Suggest similar contacts
      List<String> similarContacts = _findSimilarContacts(contactName);
      String suggestion = '';
      if (similarContacts.isNotEmpty) {
        suggestion = ' Try saying: ${similarContacts.first}';
      }

      await _speak('Contact $contactName not found.$suggestion');
      AccessibilityTheme.provideErrorFeedback();
    }
  }

  List<String> _findSimilarContacts(String searchName) {
    List<String> similar = [];
    String lowerSearch = searchName.toLowerCase();

    for (String contact in _contactsMap.keys) {
      if (contact.contains(lowerSearch.substring(
          0, lowerSearch.length > 2 ? 3 : lowerSearch.length))) {
        similar.add(contact);
      }
    }

    return similar.take(3).toList();
  }

  void _showContactsList() async {
    if (_contactsMap.isEmpty) {
      await _speak('No contacts found on device');
      return;
    }

    await _speak(
        'You have ${_contactsMap.length} contacts. Reading first 10 contacts');

    List<String> contactNames = _contactsMap.keys.take(10).toList();
    for (int i = 0; i < contactNames.length; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _speak('${i + 1}. ${contactNames[i]}');
    }

    if (_contactsMap.length > 10) {
      await _speak('And ${_contactsMap.length - 10} more contacts');
    }
  }

  Future<void> _makeEmergencyCall() async {
    setState(() {
      _status = 'Calling Emergency 112';
    });

    await _speak('Emergency! Calling 112 now');
    AccessibilityTheme.provideSuccessFeedback();

    // Vibrate pattern for emergency
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();

    final Uri phoneUri = Uri(scheme: 'tel', path: '112');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        await _speak('Emergency call initiated to 112');
      } else {
        throw Exception('Cannot make calls');
      }
    } catch (e) {
      setState(() {
        _status = 'Error: Unable to call emergency';
      });
      await _speak(
          'Error: Unable to make emergency call. Please dial 112 manually');
      AccessibilityTheme.provideErrorFeedback();
    }
  }

  void _refreshContacts() async {
    setState(() {
      _status = 'Refreshing contacts...';
      _contactsLoaded = false;
    });
    await _speak('Refreshing contacts');
    await _loadContacts();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Calling'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _speak('Closing Voice Calling Screen');
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshContacts,
            tooltip: 'Refresh contacts',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
          child: Column(
            children: [
              // Status display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                decoration: BoxDecoration(
                  color: AccessibilityTheme.surfaceColor,
                  border: Border.all(
                    color: _isListening
                        ? Colors.green
                        : AccessibilityTheme.primaryColor,
                    width: _isListening ? 3.0 : 2.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _isListening ? Colors.green : null,
                            fontWeight: _isListening ? FontWeight.bold : null,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (_lastWords.isNotEmpty) ...[
                      const SizedBox(height: AccessibilityTheme.spacingS),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '"$_lastWords"',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      'Contacts: ${_contactsMap.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AccessibilityTheme.spacingXL),

              // Main microphone button with animation
              Semantics(
                label: _isListening
                    ? 'Listening. Tap to stop'
                    : 'Tap to start voice command',
                hint: 'Say Call and contact name, or say Emergency',
                button: true,
                child: GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isListening ? 140 : 120,
                    height: _isListening ? 140 : 120,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.red
                          : (_contactsLoaded
                              ? AccessibilityTheme.primaryColor
                              : Colors.grey),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening
                            ? Colors.red.shade900
                            : AccessibilityTheme.focusColor,
                        width: _isListening ? 4.0 : 2.0,
                      ),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: _isListening ? 70 : 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              if (_isListening) ...[
                const SizedBox(height: AccessibilityTheme.spacingM),
                LinearProgressIndicator(
                  color: Colors.red,
                  backgroundColor: Colors.red.shade100,
                ),
                const SizedBox(height: AccessibilityTheme.spacingS),
                Text(
                  'Listening... Speak now',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],

              const SizedBox(height: AccessibilityTheme.spacingXL),

              // Quick action buttons
              AccessibleButton(
                text: 'EMERGENCY (112)',
                onPressed: _makeEmergencyCall,
                icon: Icons.emergency,
                isPrimary: true,
                isEmergency: true,
                semanticLabel: 'Emergency call to 112',
              ),

              const SizedBox(height: AccessibilityTheme.spacingM),

              AccessibleButton(
                text: 'Show Contacts',
                onPressed: _showContactsList,
                icon: Icons.contacts,
                isPrimary: false,
                semanticLabel: 'Show list of available contacts',
              ),

              const SizedBox(height: AccessibilityTheme.spacingM),

              // Voice commands guide
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: Colors.blue,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Commands:',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.blue.shade900,
                              ),
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      '• "Call [name]" - Call a contact\n'
                      '• "Emergency" - Call 112 immediately\n'
                      '• "Help" - Call 112 immediately\n'
                      '• "112" - Call emergency services\n'
                      '• "Stop" or "Cancel" - Cancel command',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AccessibilityTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced AccessibleButton widget
class AccessibleButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData icon;
  final bool isPrimary;
  final bool isEmergency;
  final String semanticLabel;

  const AccessibleButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.icon,
    this.isPrimary = true,
    this.isEmergency = false,
    required this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;

    if (isEmergency) {
      backgroundColor = Colors.red;
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
        icon: Icon(icon, size: 24),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AccessibilityTheme.spacingM,
            vertical: AccessibilityTheme.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isEmergency ? Colors.red : AccessibilityTheme.primaryColor,
              width: (isPrimary || isEmergency) ? 0 : 2,
            ),
          ),
        ),
      ),
    );
  }
}
