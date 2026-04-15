import 'dart:async';
import 'package:e_response_app_nemsu/services/twilio_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class CallScreen extends StatefulWidget {
  final String to;
  const CallScreen({Key? key, required this.to}) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final TwilioService _twilioService = TwilioService();
  static const String _phoneAccountEnabledKey = 'phone_account_enabled';

  String _callStatus = 'Connecting…';
  Timer? _timer;
  int _secondsElapsed = 0;
  final List<String> _logs = [];
  String? _lastError;
  StreamSubscription<dynamic>? _callEventSub;

  @override
  void initState() {
    super.initState();

    _twilioService.onLog = (msg) {
      if (mounted) setState(() => _logs.add(msg));
    };

    _addLog('Starting call to "${widget.to}"…');

    _callEventSub = _twilioService.callEvents.listen((event) {
      final eventDesc = _mapCallEventToStatus(event);
      setState(() {
        _callStatus = eventDesc;
        _addLog('Twilio event: $event ($eventDesc)');
        if (event.toString() == 'CallEvent.connected') {
          _startTimer();
        } else if (event.toString().contains('callEnded') ||
            event.toString().contains('missedCall') ||
            event.toString().contains('declined')) {
          _stopTimer();
          _addLog('Call ended or missed/declined.');
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _startCallSequence());
  }

  Future<void> _startCallSequence() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyEnabled = prefs.getBool(_phoneAccountEnabledKey) ?? false;

    if (!alreadyEnabled) {
      _addLog('Prompting user to enable phone account...');
      try {
        final success = await _twilioService.promptEnablePhoneAccount(context);
        if (success == true) {
          await prefs.setBool(_phoneAccountEnabledKey, true);
          _addLog('Phone account enabled by user.');
        } else {
          _addLogError('User cancelled phone account registration.');
          Navigator.of(context).pop();
          return;
        }
      } catch (e) {
        _addLogError('Error enabling phone account: $e');
        Navigator.of(context).pop();
        return;
      }
    }

    // Always call TwilioService.init() first before making a call!
    await _twilioService.init();

    _addLog('Calling "${widget.to}" via TwilioService…');
    try {
      await _twilioService.makeCall(widget.to);
      _addLog('makeCall() triggered.');
    } catch (e) {
      _addLogError('makeCall() error: $e');
    }
  }

  void _addLog(String message) {
    final now = DateTime.now();
    setState(() {
      _logs.add("[${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}] $message");
    });
  }

  void _addLogError(String error) {
    setState(() {
      _lastError = error;
      _addLog("❌ ERROR: $error");
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final context = this.context;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  String _mapCallEventToStatus(dynamic event) {
    final String value = event.toString();
    if (value.contains('ringing')) return 'Ringing…';
    if (value.contains('connected')) return 'Connected';
    if (value.contains('callEnded')) return 'Call Ended';
    if (value.contains('missedCall')) return 'Missed Call';
    if (value.contains('declined')) return 'Call Declined';
    if (value.contains('incoming')) return 'Connecting…';
    return 'Connecting…';
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsElapsed++);
    });
    _addLog('Timer started.');
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _addLog('Timer stopped.');
  }

  String _formattedElapsed() {
    final hours = _secondsElapsed ~/ 3600;
    final minutes = (_secondsElapsed % 3600) ~/ 60;
    final seconds = _secondsElapsed % 60;
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hStr:$mStr:$sStr' : '$mStr:$sStr';
  }

  @override
  void dispose() {
    _twilioService.onLog = null;
    _stopTimer();
    _callEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryAlt],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const Icon(
                                Icons.call,
                                size: 32,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _callStatus,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _formattedElapsed(),
                      style: theme.textTheme.displayLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_lastError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _lastError!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        _addLog('End Call pressed by user.');
                        await _twilioService.hangUp();
                        Navigator.of(context).pop();
                      } catch (e) {
                        _addLogError('Error ending call: $e');
                      }
                    },
                    icon: const Icon(Icons.call_end, size: 28),
                    label: const Text(
                      'End Call',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
