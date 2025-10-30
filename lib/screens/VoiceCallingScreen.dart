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
    await _tts.setSpeechRate(0.8);
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
        _status = 'Tap to start voice command';
      });

      await _announceScreenOpening();
    } catch (e) {
      setState(() {
        _status = 'Error loading contacts: ${e.toString()}';
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
          _status = 'Speech recognition error. Please try again.';
        });
        _speak(_status);
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
        _status = 'Voice commands ready. Say "Call" followed by contact name.';
      });
    } else if (!_speechEnabled) {
      setState(() {
        _status = 'Speech recognition not available on this device.';
      });
      await _speak(_status);
    }
  }

  Future<void> _announceScreenOpening() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (_contactsMap.isEmpty) {
      await _speak(
          'Voice Calling Screen opened. No contacts found. Please add contacts to your phone.');
      return;
    }

    // Announce first few contacts as examples
    List<String> contactNames = _contactsMap.keys.take(5).toList();
    String contactsPreview = contactNames.join(', ');

    await _speak(
        'Voice Calling Screen opened. ${_contactsMap.length} contacts loaded. '
        'Examples: $contactsPreview. Tap the microphone button to start voice command.');
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _startListening() async {
    if (!_speechEnabled) {
      await _speak('Speech recognition not available');
      return;
    }

    if (!_contactsLoaded) {
      await _speak('Contacts not loaded yet. Please wait.');
      return;
    }

    AccessibilityTheme.provideHapticFeedback();
    await _speak('Listening for call command');

    setState(() {
      _isListening = true;
      _status = 'Listening... Say "Call" followed by contact name';
      _lastWords = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords.toLowerCase();
          _status = 'Heard: $_lastWords';
        });

        if (result.finalResult) {
          _processVoiceCommand(_lastWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _status = 'Stopped listening';
    });
    AccessibilityTheme.provideHapticFeedback();
  }

  void _processVoiceCommand(String command) async {
    // Remove common variations and clean the command
    String cleanCommand = command
        .replaceAll('please', '')
        .replaceAll('could you', '')
        .replaceAll('can you', '')
        .trim();

    // Check if command starts with "call"
    if (cleanCommand.startsWith('call ')) {
      String contactName = cleanCommand.substring(5).trim();
      await _makeCall(contactName);
    } else if (cleanCommand.contains('call ')) {
      // Handle variations like "please call mom"
      int callIndex = cleanCommand.indexOf('call ');
      String contactName = cleanCommand.substring(callIndex + 5).trim();
      await _makeCall(contactName);
    } else {
      setState(() {
        _status =
            'Command not recognized. Say "Call" followed by contact name.';
      });
      await _speak(_status);
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

      // If still not found, try word matching
      if (phoneNumber == null) {
        List<String> searchWords = contactName.toLowerCase().split(' ');
        for (String contact in _contactsMap.keys) {
          List<String> contactWords = contact.split(' ');
          for (String searchWord in searchWords) {
            for (String contactWord in contactWords) {
              if (contactWord.startsWith(searchWord) ||
                  searchWord.startsWith(contactWord)) {
                phoneNumber = _contactsMap[contact];
                foundContactName = contact;
                break;
              }
            }
            if (phoneNumber != null) break;
          }
          if (phoneNumber != null) break;
        }
      }
    }

    if (phoneNumber != null && foundContactName != null) {
      setState(() {
        _status = 'Calling $foundContactName at $phoneNumber';
      });

      await _speak('Calling $foundContactName');
      AccessibilityTheme.provideSuccessFeedback();

      // Make the actual call
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
          await _speak('Call initiated to $foundContactName');
        } else {
          throw Exception('Cannot make calls on this device');
        }
      } catch (e) {
        setState(() {
          _status = 'Error: Unable to make call';
        });
        await _speak(
            'Error: Unable to make call to $foundContactName. Please try again.');
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
        suggestion = ' Did you mean: ${similarContacts.take(3).join(', ')}?';
      }

      await _speak('Contact $contactName not found.$suggestion');
      AccessibilityTheme.provideErrorFeedback();
    }
  }

  List<String> _findSimilarContacts(String searchName) {
    List<String> similar = [];
    String lowerSearch = searchName.toLowerCase();

    for (String contact in _contactsMap.keys) {
      if (contact.contains(
          lowerSearch.substring(0, (lowerSearch.length / 2).round()))) {
        similar.add(contact);
      }
    }

    return similar;
  }

  void _showContactsList() async {
    if (_contactsMap.isEmpty) {
      await _speak('No contacts found on device');
      return;
    }

    await _speak(
        'You have ${_contactsMap.length} contacts. Reading first 10 contacts');

    List<String> contactNames = _contactsMap.keys.take(10).toList();
    String contactsList = contactNames.join(', ');
    await _speak(contactsList);

    if (_contactsMap.length > 10) {
      await _speak('And ${_contactsMap.length - 10} more contacts');
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
                    color: AccessibilityTheme.primaryColor,
                    width: 2.0,
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
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_lastWords.isNotEmpty) ...[
                      const SizedBox(height: AccessibilityTheme.spacingS),
                      Text(
                        'Last heard: $_lastWords',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      'Contacts loaded: ${_contactsMap.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AccessibilityTheme.spacingXL),

              // Main microphone button
              Semantics(
                label: _isListening
                    ? 'Stop listening for voice command'
                    : 'Start listening for voice command',
                hint:
                    'Double tap to ${_isListening ? 'stop' : 'start'} voice recognition',
                button: true,
                child: GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AccessibilityTheme.errorColor
                          : (_contactsLoaded
                              ? AccessibilityTheme.primaryColor
                              : Colors.grey),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AccessibilityTheme.focusColor,
                        width: _isListening ? 4.0 : 2.0,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      size: 60,
                      color: AccessibilityTheme.backgroundColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AccessibilityTheme.spacingXL),

              // Action buttons
              AccessibleButton(
                text: 'Show Available Contacts',
                onPressed: _showContactsList,
                icon: Icons.contacts,
                isPrimary: false,
                semanticLabel: 'Show list of available contacts',
              ),

              const SizedBox(height: AccessibilityTheme.spacingM),

              AccessibleButton(
                text: 'Refresh Contacts',
                onPressed: _refreshContacts,
                icon: Icons.refresh,
                isPrimary: false,
                semanticLabel: 'Refresh contacts from device',
              ),

              const SizedBox(height: AccessibilityTheme.spacingM),

              AccessibleButton(
                text: 'Emergency Call',
                onPressed: () => _makeEmergencyCall(),
                icon: Icons.emergency,
                isPrimary: true,
                semanticLabel: 'Make emergency call to 911',
              ),

              const SizedBox(height: AccessibilityTheme.spacingM),

              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                decoration: BoxDecoration(
                  color: AccessibilityTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AccessibilityTheme.focusColor,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AccessibilityTheme.spacingS),
                    Text(
                      '1. Tap the microphone button\n'
                      '2. Say "Call" followed by contact name\n'
                      '3. Example: "Call John" or "Call Sarah"\n'
                      '4. Wait for confirmation\n'
                      '5. Use first names or full names',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),

              // Add bottom padding to ensure content is fully visible
              const SizedBox(height: AccessibilityTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makeEmergencyCall() async {
    await _speak('Making emergency call');
    AccessibilityTheme.provideSuccessFeedback();

    final Uri phoneUri = Uri(scheme: 'tel', path: '911');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        await _speak('Emergency call initiated');
      } else {
        throw Exception('Cannot make calls on this device');
      }
    } catch (e) {
      await _speak('Error: Unable to make emergency call');
      AccessibilityTheme.provideErrorFeedback();
    }
  }
}
