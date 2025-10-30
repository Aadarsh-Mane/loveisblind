import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccessibilityTheme {
  // High contrast colors for users with some vision
  static const Color primaryColor = Color(0xFF000000); // Pure black
  static const Color backgroundColor = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceColor = Color(0xFFF5F5F5); // Light gray
  static const Color errorColor = Color(0xFFD32F2F); // High contrast red
  static const Color successColor = Color(0xFF388E3C); // High contrast green
  static const Color textPrimary = Color(0xFF000000); // Black text
  static const Color textSecondary = Color(0xFF424242); // Dark gray
  static const Color focusColor =
      Color(0xFF1976D2); // High contrast blue for focus

  // Extra large text sizes for better readability
  static const double headingSize = 32.0;
  static const double titleSize = 28.0;
  static const double bodySize = 24.0;
  static const double buttonTextSize = 26.0;
  static const double captionSize = 20.0;

  // Large touch targets (minimum 48x48 dp recommended)
  static const double minTouchTargetSize = 56.0;
  static const double buttonHeight = 80.0; // Increased for multi-line text
  static const double iconSize = 32.0;

  // Generous spacing for easier navigation
  static const double spacingXS = 8.0;
  static const double spacingS = 16.0;
  static const double spacingM = 24.0;
  static const double spacingL = 32.0;
  static const double spacingXL = 48.0;

  static ThemeData get theme {
    return ThemeData(
      // High contrast color scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: backgroundColor,
        onBackground: textPrimary,
        onSurface: textPrimary,
        onError: backgroundColor,
      ),

      // Accessibility-focused app bar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        elevation: 4.0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.bold,
          color: backgroundColor,
        ),
      ),

      // Large, clear text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: headingSize,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.4,
        ),
        displayMedium: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: bodySize,
          color: textPrimary,
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          fontSize: bodySize,
          color: textSecondary,
          height: 1.6,
        ),
        labelLarge: TextStyle(
          fontSize: buttonTextSize,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: captionSize,
          color: textSecondary,
          height: 1.5,
        ),
      ),

      // Large, accessible buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
          textStyle: const TextStyle(
            fontSize: buttonTextSize,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 3.0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingM,
          ),
        ),
      ),

      // Accessible outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: buttonTextSize,
            fontWeight: FontWeight.bold,
          ),
          side: const BorderSide(color: primaryColor, width: 2.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingM,
          ),
        ),
      ),

      // Large text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTouchTargetSize, buttonHeight),
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: buttonTextSize,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingM,
          ),
        ),
      ),

      // Accessible input fields
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: primaryColor, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: primaryColor, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: focusColor, width: 3.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          borderSide: BorderSide(color: errorColor, width: 2.0),
        ),
        contentPadding: EdgeInsets.all(spacingS),
        labelStyle: TextStyle(
          fontSize: bodySize,
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          fontSize: bodySize,
          color: textSecondary,
        ),
      ),

      // Large icons
      iconTheme: const IconThemeData(
        size: iconSize,
        color: primaryColor,
      ),

      // High contrast dividers
      dividerTheme: const DividerThemeData(
        color: primaryColor,
        thickness: 2.0,
        space: spacingM,
      ),

      // Accessible card theme
      cardTheme: const CardTheme(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          side: BorderSide(color: primaryColor, width: 1.0),
        ),
        margin: EdgeInsets.all(spacingS),
      ),

      // Focus theme for keyboard navigation
      focusColor: focusColor,

      // Material 3 settings
      useMaterial3: true,
    );
  }

  // Helper method to provide haptic feedback
  static void provideHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  // Helper method for success feedback
  static void provideSuccessFeedback() {
    HapticFeedback.heavyImpact();
  }

  // Helper method for error feedback
  static void provideErrorFeedback() {
    HapticFeedback.vibrate();
  }
}

// Enhanced accessible button widget for better multi-line text support
class AccessibleButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;
  final String? semanticLabel;

  const AccessibleButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget button;

    if (isPrimary) {
      button = ElevatedButton(
        onPressed: () {
          AccessibilityTheme.provideHapticFeedback();
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          // Dynamic height based on content
          minimumSize:
              const Size(double.infinity, AccessibilityTheme.buttonHeight),
          padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
        ),
        child: _buildButtonContent(),
      );
    } else {
      button = OutlinedButton(
        onPressed: () {
          AccessibilityTheme.provideHapticFeedback();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          // Dynamic height based on content
          minimumSize:
              const Size(double.infinity, AccessibilityTheme.buttonHeight),
          padding: const EdgeInsets.all(AccessibilityTheme.spacingM),
        ),
        child: _buildButtonContent(),
      );
    }

    return Container(
      margin:
          const EdgeInsets.symmetric(vertical: AccessibilityTheme.spacingXS),
      child: Semantics(
        label: semanticLabel ?? text.replaceAll('\n', ' '),
        hint: 'Double tap to activate',
        button: true,
        enabled: true,
        child: button,
      ),
    );
  }

  Widget _buildButtonContent() {
    if (icon != null) {
      return IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: AccessibilityTheme.iconSize),
            const SizedBox(width: AccessibilityTheme.spacingS),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AccessibilityTheme.buttonTextSize,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                maxLines: null, // Allow unlimited lines
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: AccessibilityTheme.buttonTextSize,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      maxLines: null, // Allow unlimited lines
    );
  }
}
