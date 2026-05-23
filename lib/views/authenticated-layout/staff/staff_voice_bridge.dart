import 'dart:async';

import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/staff_heartbeat_service.dart';
import 'package:e_response_app_nemsu/services/twilio_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';

/// Wraps the staff/admin shell so authenticated responders can receive citizen
/// VoIP legs routed by Laravel/Twilio to this device's Twilio Client identity
/// (`GET /api/v1/voice/token` → sanitized `identity` + Twilio registration).
enum _StaffIncomingUi { hidden, ringing, inCall }

/// Brackets [child] (typically [StaffAppShell]) with full-screen incoming /
/// active-call UI driven by [TwilioVoice.instance.callEventsListener].
class StaffVoiceBridge extends StatefulWidget {
  const StaffVoiceBridge({
    super.key,
    required this.child,
    required this.onUserActivity,
  });

  final Widget child;
  final VoidCallback onUserActivity;

  @override
  State<StaffVoiceBridge> createState() => _StaffVoiceBridgeState();
}

class _StaffVoiceBridgeState extends State<StaffVoiceBridge>
    with WidgetsBindingObserver {
  static const Duration _heartbeatEvery = Duration(seconds: 30);

  StreamSubscription<CallEvent>? _callSub;
  Timer? _heartbeatTimer;
  final SharedPreferencesService _prefs = SharedPreferencesService();
  final StaffHeartbeatService _heartbeat = StaffHeartbeatService();
  final TwilioService _twilio = TwilioService();
  _StaffIncomingUi _ui = _StaffIncomingUi.hidden;
  bool _muted = false;
  bool _speakerOn = false;
  int _secondsConnected = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callSub = TwilioService().callEvents.listen(
      _onCallEvent,
      onError: (Object e, StackTrace st) {
        debugPrint('[StaffVoiceBridge] callEvents error: $e');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreFromNative();
      _startHeartbeat();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    unawaited(_pulseHeartbeat());
    _heartbeatTimer = Timer.periodic(_heartbeatEvery, (_) {
      unawaited(_pulseHeartbeat());
    });
  }

  Future<void> _pulseHeartbeat() async {
    if (!mounted) return;
    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (token.isEmpty) return;
    await _heartbeat.ping(
      bearerToken: token,
      twilioVoiceReady: _twilio.isReady ? true : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreFromNative());
    }
  }

  /// Dispatch operators may receive ringing before direction is parsed as incoming.
  bool _shouldShowStaffIncomingOverlay() {
    if (_incomingContext()) return true;
    if (_twilio.lastVoiceIncomingAllow != true) return false;
    final ac = TwilioVoice.instance.call.activeCall;
    if (ac == null) return false;
    return ac.callDirection != CallDirection.outgoing;
  }

  Future<void> _restoreFromNative() async {
    final onCall = await TwilioVoice.instance.call.isOnCall();
    final ac = TwilioVoice.instance.call.activeCall;
    if (!mounted) return;
    if (ac?.callDirection == CallDirection.incoming) {
      setState(() {
        _ui = onCall ? _StaffIncomingUi.inCall : _StaffIncomingUi.ringing;
      });
      if (onCall) _startTick();
    }
  }

  bool _incomingContext() {
    final ac = TwilioVoice.instance.call.activeCall;
    return ac?.callDirection == CallDirection.incoming;
  }

  void _onCallEvent(CallEvent event) {
    if (!mounted) return;
    TwilioService.incomingDebug('StaffVoiceBridge event=$event incomingUi=$_ui');

    switch (event) {
      case CallEvent.incoming:
        setState(() {
          _ui = _StaffIncomingUi.ringing;
        });
        break;
      case CallEvent.ringing:
        if (_shouldShowStaffIncomingOverlay()) {
          setState(() {
            _ui = _StaffIncomingUi.ringing;
          });
        }
        break;
      case CallEvent.answer:
      case CallEvent.connected:
      case CallEvent.reconnected:
        if (_incomingContext()) {
          setState(() {
            _ui = _StaffIncomingUi.inCall;
          });
          _startTick();
        }
        break;
      case CallEvent.callEnded:
      case CallEvent.declined:
      case CallEvent.missedCall:
        _clearOverlay();
        break;
      case CallEvent.mute:
        setState(() => _muted = true);
        break;
      case CallEvent.unmute:
        setState(() => _muted = false);
        break;
      case CallEvent.speakerOn:
        setState(() => _speakerOn = true);
        break;
      case CallEvent.speakerOff:
        setState(() => _speakerOn = false);
        break;
      default:
        break;
    }
  }

  void _startTick() {
    _tick?.cancel();
    _secondsConnected = 0;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsConnected++);
    });
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
    _secondsConnected = 0;
  }

  void _clearOverlay() {
    _stopTick();
    if (!mounted) return;
    setState(() {
      _ui = _StaffIncomingUi.hidden;
      _muted = false;
      _speakerOn = false;
    });
  }

  Future<void> _answer() async {
    widget.onUserActivity();
    try {
      await TwilioVoice.instance.call.answer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not answer: $e')),
      );
    }
  }

  Future<void> _declineOrHangUp() async {
    widget.onUserActivity();
    await TwilioService().hangUp();
    _clearOverlay();
  }

  Future<void> _toggleMute() async {
    widget.onUserActivity();
    try {
      final currently =
          await TwilioVoice.instance.call.isMuted() ?? _muted;
      final next = !currently;
      await TwilioVoice.instance.call.toggleMute(next);
      if (mounted) setState(() => _muted = next);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    widget.onUserActivity();
    try {
      final on =
          await TwilioVoice.instance.call.isOnSpeaker() ?? _speakerOn;
      final next = !on;
      await TwilioVoice.instance.call.toggleSpeaker(next);
      if (mounted) setState(() => _speakerOn = next);
    } catch (_) {}
  }

  String _callerLine() {
    final ac = TwilioVoice.instance.call.activeCall;
    final formatted = ac?.fromFormatted.trim();
    if (formatted != null && formatted.isNotEmpty) {
      return formatted;
    }
    return 'Citizen caller';
  }

  String _formatDuration() {
    final s = _secondsConnected;
    final m = s ~/ 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _callSub?.cancel();
    _stopTick();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_ui != _StaffIncomingUi.hidden)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.92),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Icon(
                        Icons.phone_in_talk_rounded,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _ui == _StaffIncomingUi.ringing
                            ? 'Incoming emergency call'
                            : 'On call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _callerLine(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_ui == _StaffIncomingUi.inCall) ...[
                        const SizedBox(height: 16),
                        Text(
                          _formatDuration(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_ui == _StaffIncomingUi.ringing) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _RoundCallButton(
                              icon: Icons.call_end_rounded,
                              label: 'Decline',
                              color: Colors.redAccent,
                              onPressed: _declineOrHangUp,
                            ),
                            _RoundCallButton(
                              icon: Icons.call_rounded,
                              label: 'Answer',
                              color: Colors.green,
                              onPressed: _answer,
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _RoundCallButton(
                              icon:
                                  _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              label: _muted ? 'Unmute' : 'Mute',
                              color: AppColors.primary,
                              onPressed: _toggleMute,
                            ),
                            _RoundCallButton(
                              icon:
                                  _speakerOn
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_down_rounded,
                              label: _speakerOn ? 'Speaker' : 'Earpiece',
                              color: AppColors.secondary,
                              onPressed: _toggleSpeaker,
                            ),
                            _RoundCallButton(
                              icon: Icons.call_end_rounded,
                              label: 'End',
                              color: Colors.redAccent,
                              onPressed: _declineOrHangUp,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundCallButton extends StatelessWidget {
  const _RoundCallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
