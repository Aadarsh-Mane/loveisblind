import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:loveisblind/constants/blind_theme.dart';

class AIAssistantTextScreen extends StatefulWidget {
  final String? recognizedText;

  const AIAssistantTextScreen({
    Key? key,
    this.recognizedText,
  }) : super(key: key);

  @override
  State<AIAssistantTextScreen> createState() => _AIAssistantTextScreenState();
}

class _AIAssistantTextScreenState extends State<AIAssistantTextScreen> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Camera functionality
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _showCameraView = false;
  bool _showOverlay = true;

  // Text recognition
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Voice recognition
  bool _isListening = false;
  bool _speechEnabled = false;
  String _lastWords = '';

  // Gemini API configuration
  static const String _geminiApiKey = 'AIzaSyDq-rmWnZuGVrjg7G1iLCjD_qFDul7ybR0';
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // State variables
  bool _isProcessing = false;
  bool _isCapturingText = false;
  String _processedText = '';
  String _originalText = '';
  List<String> _processingHistory = [];
  bool _isSpeaking = false;
  String _lastError = '';

  // Voice commands
  final Map<String, Function> _voiceCommands = {};

  // Improved Gemini prompt for better context understanding
  static const String _geminiPrompt = '''
You are an AI assistant helping a visually impaired user understand text captured from a photo. Your goal is to provide complete context and understanding of what's written.

IMPORTANT INSTRUCTIONS:
1. First, describe WHAT TYPE of document/text this is (menu, sign, letter, form, receipt, book page, etc.)
2. Describe the LAYOUT and structure (headings, columns, sections, tables)
3. Read ALL text content in logical order (top to bottom, left to right)
4. Explain any VISUAL elements that provide context (logos, images, formatting, colors mentioned)
5. Highlight IMPORTANT information (prices, dates, contact info, instructions)
6. Fix any OCR errors and clarify unclear text
7. Organize the content in a clear, structured way that's easy to understand when read aloud

Format your response like this:
**Document Type**: [What kind of document this is]
**Layout**: [Brief description of how it's organized]
**Content**: [All text organized clearly]
**Key Information**: [Important details highlighted]

Make everything clear and accessible for audio reading.

Text to analyze:
''';

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _initializeSpeech();
    _initializeCamera();
    _setupVoiceCommands();
    _announceScreenOpening();

    if (widget.recognizedText != null && widget.recognizedText!.isNotEmpty) {
      _inputController.text = widget.recognizedText!;
      _originalText = widget.recognizedText!;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _cameraController?.dispose();
    _textRecognizer.close();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupVoiceCommands() {
    _voiceCommands.addAll({
      'open camera': () => _toggleCameraView(true),
      'close camera': () => _toggleCameraView(false),
      'capture image': () => _captureAndRecognizeText(),
      'capture photo': () => _captureAndRecognizeText(),
      'take picture': () => _captureAndRecognizeText(),
      'analyze text': () => _processTextWithGemini(),
      'process text': () => _processTextWithGemini(),
      'read text': () => _speak(
          _processedText.isNotEmpty ? _processedText : _inputController.text),
      'read analysis': () => _speak(_processedText),
      'summarize': () => _summarizeText(),
      'stop reading': () => _stopSpeaking(),
      'clear all': () => _clearAll(),
      'copy text': () => _copyToClipboard(
          _processedText.isNotEmpty ? _processedText : _inputController.text),
      'help': () => _speakHelpCommands(),
      'commands': () => _speakHelpCommands(),
    });
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.7);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _tts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
      // Auto-start listening after TTS finishes
      if (_speechEnabled && !_isListening) {
        _startListening();
      }
    });
  }

  Future<void> _initializeSpeech() async {
    _speechEnabled = await _speech.initialize(
      onStatus: (val) {
        setState(() {
          _isListening = val == 'listening';
        });
      },
      onError: (val) {
        setState(() {
          _isListening = false;
        });
        _speak("Voice recognition error. Please try again.");
      },
    );

    if (_speechEnabled) {
      // Start listening immediately
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isSpeaking) {
          _startListening();
        }
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras[0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      await _speak(
          "Error initializing camera. Please check camera permissions.");
    }
  }

  Future<void> _announceScreenOpening() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _speak(
        "AI Assistant ready. I'm listening for voice commands. Say 'help' to hear all available commands, or say 'open camera' to start capturing text.");
  }

  void _startListening() async {
    if (!_isListening && _speechEnabled && !_isSpeaking) {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords.toLowerCase();
          });

          if (result.finalResult) {
            _processVoiceCommand(_lastWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: "en_US",
      );
    }
  }

  void _processVoiceCommand(String command) {
    command = command.toLowerCase().trim();

    // Check for exact matches first
    if (_voiceCommands.containsKey(command)) {
      _voiceCommands[command]!();
      return;
    }

    // Check for partial matches
    for (String key in _voiceCommands.keys) {
      if (command.contains(key)) {
        _voiceCommands[key]!();
        return;
      }
    }

    // No command found
    _speak("Command not recognized. Say 'help' to hear available commands.");

    // Restart listening
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isSpeaking) {
        _startListening();
      }
    });
  }

  Future<void> _speakHelpCommands() async {
    final helpText = '''
Available voice commands:
Open camera - Opens the camera view
Capture image - Takes a photo and extracts text
Close camera - Closes the camera view
Analyze text - Processes text with AI for better understanding
Read text - Reads the current text aloud
Read analysis - Reads the AI analysis
Summarize - Creates a brief summary
Stop reading - Stops text-to-speech
Clear all - Clears all content
Copy text - Copies text to clipboard
Help - Repeats these commands
''';
    await _speak(helpText);
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      // Stop listening while speaking
      if (_isListening) {
        await _speech.stop();
      }

      AccessibilityTheme.provideHapticFeedback();
      await _tts.speak(text);
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() {
      _isSpeaking = false;
    });
    // Resume listening
    if (_speechEnabled) {
      _startListening();
    }
  }

  void _toggleCameraView([bool? forceState]) {
    setState(() {
      _showCameraView = forceState ?? !_showCameraView;
    });

    if (_showCameraView) {
      _speak("Camera opened. Say 'capture image' when ready to take a photo.");
    } else {
      _speak("Camera closed.");
    }

    // Resume listening
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isSpeaking) {
        _startListening();
      }
    });
  }

  Future<void> _captureAndRecognizeText() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _speak("Camera not ready. Say 'open camera' first.");
      return;
    }

    if (!_showCameraView) {
      await _speak("Camera is not open. Say 'open camera' first.");
      return;
    }

    setState(() {
      _isCapturingText = true;
    });

    AccessibilityTheme.provideHapticFeedback();
    await SystemSound.play(SystemSoundType.click);
    await _speak("Photo captured. Analyzing text...");

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      final extractedText = recognizedText.text;

      setState(() {
        _inputController.text = extractedText;
        _originalText = extractedText;
        _isCapturingText = false;
        _showCameraView = false;
      });

      File(imageFile.path).delete();
      AccessibilityTheme.provideSuccessFeedback();

      if (extractedText.isNotEmpty) {
        await _speak(
            "Text extracted successfully. Processing with AI for better understanding...");
        await _processTextWithGemini();
      } else {
        await _speak(
            "No text found. Please try again with better lighting or positioning. Say 'open camera' to try again.");
      }
    } catch (e) {
      print('Error during text recognition: $e');
      setState(() {
        _isCapturingText = false;
        _showCameraView = false;
      });

      AccessibilityTheme.provideErrorFeedback();
      await _speak(
          "Error analyzing photo. Please say 'open camera' to try again.");
    }
  }

  Future<void> _processTextWithGemini() async {
    final textToProcess = _inputController.text.trim();

    if (textToProcess.isEmpty) {
      await _speak(
          "No text to process. Please capture a photo first or enter text manually.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastError = '';
    });

    AccessibilityTheme.provideHapticFeedback();

    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        final response = await http.post(
          Uri.parse('$_geminiBaseUrl?key=$_geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': '$_geminiPrompt\n\n"$textToProcess"'}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 3000,
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final processedText =
              data['candidates'][0]['content']['parts'][0]['text'];

          setState(() {
            _processedText = processedText;
            _processingHistory.add(
                'Original: ${textToProcess.substring(0, textToProcess.length > 50 ? 50 : textToProcess.length)}...');
            _isProcessing = false;
          });

          AccessibilityTheme.provideSuccessFeedback();
          await _speak("Analysis complete. Here's what I found:");
          _scrollToResults();

          await Future.delayed(const Duration(milliseconds: 500));
          final firstPart = _extractFirstSection(processedText);
          if (firstPart.isNotEmpty) {
            await _speak(firstPart);
          }
          return;
        } else if (response.statusCode == 503 && retryCount < maxRetries - 1) {
          retryCount++;
          await _speak("AI is busy, retrying...");
          await Future.delayed(
              Duration(seconds: baseDelay.inSeconds * retryCount));
          continue;
        } else {
          final errorData = json.decode(response.body);
          throw Exception(
              'API request failed: ${errorData['error']['message'] ?? 'Unknown error'}');
        }
      } catch (e) {
        if (retryCount < maxRetries - 1 && e.toString().contains('503')) {
          retryCount++;
          await _speak("Retrying connection...");
          await Future.delayed(
              Duration(seconds: baseDelay.inSeconds * retryCount));
          continue;
        }

        setState(() {
          _isProcessing = false;
          _lastError = e.toString();
        });

        AccessibilityTheme.provideErrorFeedback();
        await _speak(
            "Unable to analyze text right now. The raw extracted text is available. Say 'read text' to hear it.");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analysis unavailable. Raw text available.'),
              backgroundColor: AccessibilityTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }
  }

  Future<void> _summarizeText() async {
    final textToSummarize =
        _processedText.isNotEmpty ? _processedText : _inputController.text;

    if (textToSummarize.isEmpty) {
      await _speak("No text to summarize. Please capture some text first.");
      return;
    }

    // Create a quick summary from the first few key points
    final lines = textToSummarize.split('\n');
    final summary = lines
        .where((line) =>
            line.contains('Document Type') ||
            line.contains('Key Information') ||
            line.contains('**'))
        .take(3)
        .join('. ')
        .replaceAll('**', '');

    if (summary.isNotEmpty) {
      await _speak("Summary: $summary");
    } else {
      // Fallback to first 200 characters
      final fallback = textToSummarize.length > 200
          ? '${textToSummarize.substring(0, 200)}...'
          : textToSummarize;
      await _speak("Summary: $fallback");
    }
  }

  String _extractFirstSection(String text) {
    final lines = text.split('\n');
    final importantLines = lines
        .where((line) =>
            line.contains('Document Type') ||
            line.contains('Layout') ||
            (line.trim().isNotEmpty &&
                !line.startsWith('**') &&
                lines.indexOf(line) < 5))
        .take(3)
        .join('. ');

    return importantLines.length > 300
        ? '${importantLines.substring(0, 300)}...'
        : importantLines;
  }

  void _scrollToResults() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _copyToClipboard(String text) async {
    if (text.isEmpty) {
      await _speak("No text to copy.");
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    AccessibilityTheme.provideSuccessFeedback();
    await _speak("Text copied to clipboard.");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearAll() {
    setState(() {
      _inputController.clear();
      _processedText = '';
      _originalText = '';
      _processingHistory.clear();
      _lastError = '';
    });
    AccessibilityTheme.provideHapticFeedback();
    _speak("All content cleared.");
  }

  Widget _buildVoiceIndicator() {
    return Container(
      padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
      margin: const EdgeInsets.only(bottom: AccessibilityTheme.spacingM),
      decoration: BoxDecoration(
        color: _isListening
            ? AccessibilityTheme.successColor.withOpacity(0.1)
            : AccessibilityTheme.surfaceColor,
        border: Border.all(
          color: _isListening
              ? AccessibilityTheme.successColor
              : AccessibilityTheme.primaryColor,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            color: _isListening
                ? AccessibilityTheme.successColor
                : AccessibilityTheme.primaryColor,
            size: AccessibilityTheme.iconSize,
          ),
          const SizedBox(width: AccessibilityTheme.spacingS),
          Expanded(
            child: Text(
              _isListening
                  ? 'Listening for voice commands...'
                  : 'Voice commands ready',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _isListening
                        ? AccessibilityTheme.successColor
                        : AccessibilityTheme.primaryColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    if (_lastError.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
      margin: const EdgeInsets.only(top: AccessibilityTheme.spacingM),
      decoration: BoxDecoration(
        color: AccessibilityTheme.errorColor.withOpacity(0.1),
        border: Border.all(
          color: AccessibilityTheme.errorColor,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Raw Extracted Text Available',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AccessibilityTheme.primaryColor,
                ),
          ),
          const SizedBox(height: AccessibilityTheme.spacingS),
          Text(
            'AI analysis failed, but the raw text is available. Say "read text" to hear it.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        height: 300,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      height: 300,
      margin: const EdgeInsets.all(AccessibilityTheme.spacingS),
      decoration: BoxDecoration(
        border: Border.all(
          color: AccessibilityTheme.primaryColor,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_cameraController!),
            if (_showOverlay)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AccessibilityTheme.focusColor.withOpacity(0.8),
                    width: 3,
                  ),
                ),
                margin: const EdgeInsets.all(AccessibilityTheme.spacingL),
                child: Container(),
              ),
            Positioned(
              bottom: AccessibilityTheme.spacingM,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    label: _isCapturingText
                        ? 'Capturing and analyzing photo'
                        : 'Capture photo to analyze text. Say capture image to activate',
                    hint: 'Double tap to capture or say capture image',
                    button: true,
                    child: GestureDetector(
                      onTap: _isCapturingText ? null : _captureAndRecognizeText,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isCapturingText
                              ? AccessibilityTheme.primaryColor.withOpacity(0.5)
                              : AccessibilityTheme.focusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AccessibilityTheme.backgroundColor,
                            width: 4,
                          ),
                        ),
                        child: _isCapturingText
                            ? const CircularProgressIndicator(
                                color: AccessibilityTheme.backgroundColor,
                                strokeWidth: 3,
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: AccessibilityTheme.backgroundColor,
                                size: 40,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
      decoration: BoxDecoration(
        color: AccessibilityTheme.surfaceColor,
        border: Border.all(
          color: AccessibilityTheme.primaryColor,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice-Controlled Text Capture',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: AccessibilityTheme.spacingS),

          // Voice indicator
          _buildVoiceIndicator(),

          // Camera toggle button
          AccessibleButton(
            text: _showCameraView ? 'Close Camera' : 'Open Camera',
            semanticLabel: _showCameraView
                ? 'Close camera view or say close camera'
                : 'Open camera to capture text or say open camera',
            onPressed: () => _toggleCameraView(),
            icon: _showCameraView ? Icons.close : Icons.camera_alt,
            isPrimary: !_showCameraView,
          ),

          const SizedBox(height: AccessibilityTheme.spacingM),

          if (_showCameraView) ...[
            _buildCameraView(),
            const SizedBox(height: AccessibilityTheme.spacingM),
          ],

          Semantics(
            label: 'Extracted text for editing or manual input',
            hint:
                'Text from captured photos appears here, or enter text manually',
            textField: true,
            child: TextField(
              controller: _inputController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Captured text appears here or enter manually...',
                labelText: 'Text Content',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),

          const SizedBox(height: AccessibilityTheme.spacingM),

          Row(
            children: [
              Expanded(
                child: AccessibleButton(
                  text: _isProcessing ? 'Analyzing...' : 'Analyze Text',
                  semanticLabel: _isProcessing
                      ? 'Analyzing text with AI'
                      : 'Analyze text for better understanding or say analyze text',
                  onPressed: _isProcessing ? () {} : _processTextWithGemini,
                  icon:
                      _isProcessing ? Icons.hourglass_empty : Icons.psychology,
                ),
              ),
              const SizedBox(width: AccessibilityTheme.spacingS),
              Semantics(
                label: 'Clear all content or say clear all',
                hint: 'Double tap to clear everything',
                button: true,
                child: IconButton(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear_all),
                  iconSize: AccessibilityTheme.iconSize,
                  padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProcessedSection() {
    if (_processedText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
      margin: const EdgeInsets.only(top: AccessibilityTheme.spacingM),
      decoration: BoxDecoration(
        color: AccessibilityTheme.backgroundColor,
        border: Border.all(
          color: AccessibilityTheme.successColor,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI Text Analysis',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AccessibilityTheme.successColor,
                      ),
                ),
              ),
              Semantics(
                label: _isSpeaking
                    ? 'Stop reading or say stop reading'
                    : 'Read analysis aloud or say read analysis',
                hint: 'Double tap to control speech',
                button: true,
                child: IconButton(
                  onPressed: _isSpeaking
                      ? _stopSpeaking
                      : () => _speak(_processedText),
                  icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                  iconSize: AccessibilityTheme.iconSize,
                  color: AccessibilityTheme.focusColor,
                ),
              ),
              Semantics(
                label: 'Copy analysis to clipboard or say copy text',
                hint: 'Double tap to copy',
                button: true,
                child: IconButton(
                  onPressed: () => _copyToClipboard(_processedText),
                  icon: const Icon(Icons.copy),
                  iconSize: AccessibilityTheme.iconSize,
                  color: AccessibilityTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AccessibilityTheme.spacingS),
          Semantics(
            label: 'Detailed text analysis and explanation',
            hint: 'AI-processed analysis of the captured text',
            readOnly: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
              decoration: BoxDecoration(
                color: AccessibilityTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: SelectableText(
                _processedText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AccessibilityTheme.theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Voice AI Assistant'),
          leading: Semantics(
            label: 'Go back',
            hint: 'Double tap to return to previous screen',
            button: true,
            child: IconButton(
              onPressed: () {
                _speak("Closing assistant");
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AccessibilityTheme.spacingS),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputSection(),
                if (_isProcessing)
                  Container(
                    padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
                    margin:
                        const EdgeInsets.only(top: AccessibilityTheme.spacingM),
                    child: Row(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(width: AccessibilityTheme.spacingM),
                        Expanded(
                          child: Text(
                            'Analyzing text for complete understanding...',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildErrorSection(),
                _buildProcessedSection(),
                const SizedBox(height: AccessibilityTheme.spacingXL),
              ],
            ),
          ),
        ),
        floatingActionButton: _processedText.isNotEmpty
            ? Semantics(
                label: _isSpeaking
                    ? 'Stop reading analysis or say stop reading'
                    : 'Read full analysis aloud or say read analysis',
                hint: 'Double tap to control text-to-speech',
                button: true,
                child: FloatingActionButton(
                  onPressed: _isSpeaking
                      ? _stopSpeaking
                      : () => _speak(_processedText),
                  backgroundColor: _isSpeaking
                      ? AccessibilityTheme.errorColor
                      : AccessibilityTheme.focusColor,
                  child: Icon(
                    _isSpeaking ? Icons.stop : Icons.volume_up,
                    color: AccessibilityTheme.backgroundColor,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
