import 'package:flutter/services.dart';

/// Lightweight in-memory debug logger for hackathon diagnostics.
/// Singleton — access via [DebugLogger.instance].
/// Every service call result gets recorded with a timestamp so you can
/// review or copy the full session log from the test screen.
class DebugLogger {
  DebugLogger._();
  static final DebugLogger instance = DebugLogger._();

  final List<String> _entries = [];

  /// All log entries, newest last.
  List<String> get entries => List.unmodifiable(_entries);

  /// Formatted multiline dump of all entries.
  String get fullLog => _entries.join('\n');

  /// Log a successful result from a service call.
  void logSuccess(String service, String action, String detail) {
    final ts = DateTime.now().toIso8601String();
    final entry = '[$ts] ✅ $service.$action → $detail';
    _entries.add(entry);
    // Also print so it shows up in the debug console / browser console
    // ignore: avoid_print
    print(entry);
  }

  /// Log an error from a service call.
  void logError(String service, String action, String error) {
    final ts = DateTime.now().toIso8601String();
    final entry = '[$ts] ❌ $service.$action → $error';
    _entries.add(entry);
    // ignore: avoid_print
    print(entry);
  }

  /// Log a general info message.
  void logInfo(String service, String message) {
    final ts = DateTime.now().toIso8601String();
    final entry = '[$ts] ℹ️  $service: $message';
    _entries.add(entry);
    // ignore: avoid_print
    print(entry);
  }

  /// Copy the full log to the system clipboard.
  Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: fullLog));
  }

  /// Clear all entries.
  void clear() => _entries.clear();
}
