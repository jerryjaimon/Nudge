// lib/utils/ui_utils.dart
import 'package:flutter/material.dart';

class UIUtils {
  /// Condenses and sanitizes error messages.
  /// Strips HTML tags and picks a user-friendly summary.
  static String sanitizeError(dynamic e) {
    if (e == null) return 'Unknown error';
    String msg = e.toString();

    // 1. Strip HTML tags using regex
    msg = msg.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');

    // 2. Handle common Firebase/Backend prefixes
    if (msg.contains('FirebaseException:')) {
      msg = msg.split('FirebaseException:').last.trim();
    }
    
    // 3. Condense long messages
    if (msg.length > 150) {
      msg = '${msg.substring(0, 147)}...';
    }

    return msg.trim();
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
