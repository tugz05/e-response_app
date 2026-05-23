import 'dart:async';
import 'dart:math' as math;

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/services/call_api_service.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/twilio_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:twilio_voice/twilio_voice.dart';

/// Human-readable hint when Laravel returns busy / none available (503, etc.).
String _unavailableDetail(CallAvailabilityResponse r) {
  final block = r.blockReason?.trim();
  if (block != null && block.isNotEmpty) {
    return block;
  }
  if (r.totalOperators <= 0) {
    return 'The server reports no operator accounts configured for voice yet.';
  }
  if (r.availableOperators <= 0) {
    return 'The server sees ${r.totalOperators} operator account(s), but 0 are '
        '“online and available” right now. That usually means: dispatch dashboard '
        'not open / no staff heartbeat, Twilio client not ready, or someone is '
        'already on a call. This is decided by the API, not the app.';
  }
  return '${r.availableOperators} of ${r.totalOperators} operator slot(s) ready now.';
}

String _describeReady(CallAvailabilityResponse r) {
  final ids = r.twimlDialOperatorIdentities;
  if (ids != null && ids.isNotEmpty) {
    return '${r.availableOperators} responder(s) ready '
        '(${ids.length} line(s) in ring group).';
  }
  return '${r.availableOperators} responder(s) ready.';
}

String? _firstNonEmpty(List<String?> candidates) {
  for (final c in candidates) {
    if (c == null) continue;
    final t = c.trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

enum _CallPhase {
  checkingAvailability,
  noOperators,
  preparingConnection,
  voiceActive,
  ended,
}

/// In-app Twilio VoIP session (CDRRMO flow: availability → location → call).
class CallScreen extends StatefulWidget {
  final String to;

  const CallScreen({super.key, required this.to});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const int _availabilityPollSeconds = 15;
  static const int _rateLimitBackoffSeconds = 45;

  final TwilioService _twilio = TwilioService();
  final CallApiService _callApi = CallApiService();

  _CallPhase _phase = _CallPhase.checkingAvailability;
  String _headline = 'Checking operators…';
  String _subtitle =
      'We verify that a responder can take your call before connecting.';
  String? _availabilityDetail;
  int _pollSeconds = _availabilityPollSeconds;

  Timer? _availabilityTimer;
  Timer? _durationTimer;
  Timer? _pulseTimer;
  bool _pulseOn = false;

  int _secondsConnected = 0;
  StreamSubscription<CallEvent>? _callSub;

  int? _reportId;
  String? _bearerToken;
  int? _userId;

  bool _dialSequenceRunning = false;
  bool _postedStarted = false;
  bool _postedEnded = false;
  bool _reconnecting = false;

  bool _muted = false;
  bool _speakerOn = false;
  bool _showElapsedTimer = false;

  String? _lastError;

  /// Last availability payload when `can_connect` was true (for `twilio_dial_identity` fallback).
  CallAvailabilityResponse? _connectableAvailability;

  /// Exact `To` string last passed to Twilio (for error copy).
  String? _dialedToExact;

  @override
  void initState() {
    super.initState();
    _twilio.onLog = null;
    _callSub = _twilio.callEvents.listen(_onCallEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAuth();
      if (mounted) {
        _scheduleAvailabilityPoll(Duration.zero);
      }
    });
  }

  Future<void> _loadAuth() async {
    final creds = await SharedPreferencesService().getCredentials();
    final idStr = creds['id'];
    if (!mounted) return;
    setState(() {
      _bearerToken = creds['token'];
      _userId = int.tryParse(idStr ?? '');
    });
  }

  void _scheduleAvailabilityPoll(Duration delay) {
    _availabilityTimer?.cancel();
    if (_phase == _CallPhase.voiceActive ||
        _phase == _CallPhase.preparingConnection) {
      return;
    }
    _availabilityTimer = Timer(delay, _runAvailabilityOnce);
  }

  Future<void> _runAvailabilityOnce() async {
    if (!mounted ||
        _dialSequenceRunning ||
        _phase == _CallPhase.voiceActive ||
        _phase == _CallPhase.preparingConnection) {
      return;
    }

    setState(() {
      _headline = 'Checking operators…';
      _subtitle = 'Please wait.';
    });

    final response = await _callApi.fetchAvailability();
    if (!mounted ||
        _dialSequenceRunning ||
        _phase == _CallPhase.voiceActive ||
        _phase == _CallPhase.preparingConnection) {
      return;
    }

    if (response == null) {
      setState(() {
        _pollSeconds = _rateLimitBackoffSeconds;
        _subtitle =
            'Network or rate limit. We will retry automatically. You can also send a written report.';
        _availabilityDetail = null;
      });
      _scheduleAvailabilityPoll(Duration(seconds: _pollSeconds));
      return;
    }

    if (response.httpStatus == 429) {
      setState(() {
        _pollSeconds = _rateLimitBackoffSeconds;
        _subtitle = 'Too many checks. Waiting before trying again.';
      });
      _scheduleAvailabilityPoll(Duration(seconds: _pollSeconds));
      return;
    }

    _pollSeconds = _availabilityPollSeconds;

    if (!response.canConnect) {
      debugPrint(
        '[CallScreen] availability: HTTP ${response.httpStatus} '
        'can_connect=${response.canConnect} code=${response.code} '
        'available=${response.availableOperators} total=${response.totalOperators} '
        'apiBase=${ApiUrl.baseUrl}',
      );
      if (response.message.isNotEmpty) {
        debugPrint('[CallScreen] server message: ${response.message}');
      }
      final String detail = _unavailableDetail(response);
      setState(() {
        _connectableAvailability = null;
        _phase = _CallPhase.noOperators;
        _headline = 'No operator available';
        _subtitle = response.message.isNotEmpty
            ? response.message
            : 'No operator is marked available right now. If staff are online, '
                'confirm the dashboard is open and the heartbeat is reaching the server.';
        _availabilityDetail = detail;
        _lastError = null;
      });
      _scheduleAvailabilityPoll(Duration(seconds: _pollSeconds));
      return;
    }

    setState(() {
      _phase = _CallPhase.preparingConnection;
      _headline = 'Operator available';
      _subtitle = response.message;
      _connectableAvailability = response;
      _availabilityDetail = _describeReady(response);
      _lastError = null;
    });

    await _startDialSequence();
  }

  Future<void> _startDialSequence() async {
    if (_dialSequenceRunning) return;
    _dialSequenceRunning = true;
    _availabilityTimer?.cancel();

    try {
      if (_userId == null) {
        _failDial('You must be signed in to start a voice call.');
        return;
      }

      if (_bearerToken == null || _bearerToken!.isEmpty) {
        _failDial('You must be signed in to start a voice call.');
        return;
      }

      setState(() {
        _headline = 'Connecting…';
        _subtitle = 'Preparing secure voice link.';
      });

      final twilioResult = await _twilio.init(bearerToken: _bearerToken);
      if (!twilioResult.ok || !_twilio.isReady) {
        _failDial(
          twilioResult.failureMessage ??
              'Voice service is not ready. Try again in a moment.',
        );
        return;
      }

      LocationPermission locPerm = await Geolocator.checkPermission();
      if (locPerm == LocationPermission.denied) {
        locPerm = await Geolocator.requestPermission();
      }
      if (locPerm == LocationPermission.denied ||
          locPerm == LocationPermission.deniedForever) {
        _failDial('Location is required before placing this call.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final locResult = await _callApi.setCallerLocation(
        userId: _userId!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      if (locResult.success != true ||
          locResult.reportId == null ||
          locResult.httpStatus != 200) {
        final msg = locResult.message.isNotEmpty
            ? locResult.message
            : 'Could not register your location for this call.';
        _failDial(msg);
        return;
      }

      _reportId = locResult.reportId;

      if (!mounted) return;
      setState(() {
        _phase = _CallPhase.voiceActive;
        _headline = 'Connecting…';
        _subtitle = 'Contacting operations center.';
      });

      final toExact = _firstNonEmpty([
        _twilio.lastVoiceDialTo,
        _connectableAvailability?.twilioDialIdentity,
        widget.to,
      ]);
      if (toExact == null) {
        _failDial(
          'Server did not supply a voice dial target (dial_to / twilio_dial_identity).',
        );
        return;
      }

      _dialedToExact = toExact;
      TwilioService.incomingDebug(
        'citizen→staff dial starting toExact="$toExact" reportId=$_reportId',
      );
      await _twilio.placeOutgoingConnect(toExact);
    } catch (e) {
      _failDial('Something went wrong: $e');
    } finally {
      _dialSequenceRunning = false;
    }
  }

  void _failDial(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _CallPhase.noOperators;
      _headline = 'Call not started';
      _subtitle = message;
      _lastError = message;
      _dialSequenceRunning = false;
    });
    _scheduleAvailabilityPoll(Duration(seconds: _pollSeconds));
  }

  void _onCallEvent(CallEvent event) {
    if (!mounted) return;

    switch (event) {
      case CallEvent.ringing:
        _setVoiceLabels('Ringing', 'Waiting for an operator to answer.');
        _startPulse();
      case CallEvent.connected:
      case CallEvent.reconnected:
        _stopPulse();
        _reconnecting = false;
        _setVoiceLabels('Connected', 'You are linked to the operations center.');
        setState(() => _showElapsedTimer = true);
        _startDurationIfNeeded();
        _notifyStartedOnce();
      case CallEvent.reconnecting:
        _reconnecting = true;
        _setVoiceLabels('Reconnecting', 'Connection interrupted. Hold on…');
      case CallEvent.callEnded:
        _stopPulse();
        _stopDuration();
        _notifyEndedOnce();
        _setVoiceLabels('Disconnected', 'The voice session has ended.');
        setState(() => _phase = _CallPhase.ended);
      case CallEvent.declined:
        _stopPulse();
        _stopDuration();
        _notifyEndedOnce();
        _setVoiceLabels(
          'Call declined',
          'The operator side did not accept this VoIP leg (Twilio often reports '
          'this as 31603 / SIP 603). Open the dispatch dashboard with Twilio Voice '
          'connected for callee identity ${_dialedToExact ?? '(unknown)'} '
          'and matching TwiML.',
        );
        setState(() {
          _phase = _CallPhase.ended;
          _lastError =
              'If staff are online, confirm their browser client identity matches '
              'the dial target your API returned (verbatim To / TwiML).';
        });
      case CallEvent.missedCall:
        _stopPulse();
        _stopDuration();
        _notifyEndedOnce();
        _setVoiceLabels('Missed call', 'No answer before timeout.');
        setState(() => _phase = _CallPhase.ended);
      case CallEvent.mute:
        setState(() => _muted = true);
      case CallEvent.unmute:
        setState(() => _muted = false);
      case CallEvent.speakerOn:
        setState(() => _speakerOn = true);
      case CallEvent.speakerOff:
        setState(() => _speakerOn = false);
      default:
        break;
    }
  }

  void _setVoiceLabels(String headline, String subtitle) {
    setState(() {
      _headline = headline;
      _subtitle = subtitle;
    });
  }

  void _startPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() => _pulseOn = !_pulseOn);
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _pulseOn = false;
  }

  void _startDurationIfNeeded() {
    if (_durationTimer != null) return;
    _secondsConnected = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsConnected++);
    });
  }

  void _stopDuration() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _notifyStartedOnce() {
    final id = _reportId;
    if (id == null || _postedStarted) return;
    _postedStarted = true;
    _callApi
        .postCallStarted(id, bearerToken: _bearerToken)
        .catchError((_) {});
  }

  void _notifyEndedOnce() {
    final id = _reportId;
    if (id == null || _postedEnded) return;
    _postedEnded = true;
    _callApi.postCallEnded(id, bearerToken: _bearerToken).catchError((_) {});
  }

  String _formatDuration() {
    final s = _secondsConnected;
    final m = s ~/ 60;
    final h = m ~/ 60;
    final mm = (m % 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  Future<void> _toggleMute() async {
    if (_reconnecting) return;
    try {
      final currently =
          await TwilioVoice.instance.call.isMuted() ?? _muted;
      final next = !currently;
      await TwilioVoice.instance.call.toggleMute(next);
      if (mounted) setState(() => _muted = next);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    if (_reconnecting) return;
    try {
      final on =
          await TwilioVoice.instance.call.isOnSpeaker() ?? _speakerOn;
      final next = !on;
      await TwilioVoice.instance.call.toggleSpeaker(next);
      if (mounted) setState(() => _speakerOn = next);
    } catch (_) {}
  }

  Future<void> _hangUpAndLeave() async {
    _notifyEndedOnce();
    await _twilio.hangUp();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (_phase == _CallPhase.voiceActive &&
        _postedStarted &&
        !_postedEnded) {
      _notifyEndedOnce();
    }
    unawaited(_twilio.hangUp());
    _availabilityTimer?.cancel();
    _stopDuration();
    _stopPulse();
    _callSub?.cancel();
    _twilio.onLog = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inVoice = _phase == _CallPhase.voiceActive || _phase == _CallPhase.ended;
    final showTimer = _showElapsedTimer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency voice call'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () {
            if (_phase == _CallPhase.voiceActive) {
              _hangUpAndLeave();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryAlt],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                AnimatedScale(
                  scale: _pulseOn ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  child: Semantics(
                    label: 'Call status: $_headline',
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Icon(
                        inVoice ? Icons.headset_mic_rounded : Icons.support_agent,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
                if (_availabilityDetail != null &&
                    _phase != _CallPhase.voiceActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    _availabilityDetail!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
                if (showTimer) ...[
                  const SizedBox(height: 28),
                  Text(
                    _formatDuration(),
                    semanticsLabel: 'Call duration ${_formatDuration()}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                if (_lastError != null && _phase == _CallPhase.noOperators) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _lastError!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_phase == _CallPhase.checkingAvailability) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Operator availability is checked automatically about every $_pollSeconds seconds.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
                const Spacer(),
                if (_phase == _CallPhase.noOperators) ...[
                  Semantics(
                    label: 'Send a written report instead',
                    button: true,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(
                          RouteManager.message_report_screen,
                        );
                      },
                      icon: const Icon(Icons.message_outlined, color: Colors.white),
                      label: const Text(
                        'Use message report instead',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Checking again every $_pollSeconds seconds while you stay on this screen.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
                if (inVoice && _phase != _CallPhase.ended) ...[
                  if (_reconnecting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Controls paused while the call reconnects.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        label: _muted ? 'Unmute microphone' : 'Mute microphone',
                        button: true,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _reconnecting ? null : _toggleMute,
                          icon: Icon(_muted ? Icons.mic_off : Icons.mic_none),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Semantics(
                        label: 'Hang up',
                        button: true,
                        child: Material(
                          color: AppColors.accent,
                          shape: const CircleBorder(),
                          elevation: 6,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _reconnecting ? null : _hangUpAndLeave,
                            child: const SizedBox(
                              width: 76,
                              height: 76,
                              child: Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Semantics(
                        label: _speakerOn ? 'Turn off speaker' : 'Turn on speaker',
                        button: true,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _reconnecting ? null : _toggleSpeaker,
                          icon: Icon(
                            _speakerOn ? Icons.volume_up : Icons.volume_down,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_phase == _CallPhase.ended) ...[
                  Semantics(
                    label: 'Leave call screen',
                    button: true,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
                SizedBox(height: math.max(20, MediaQuery.paddingOf(context).bottom)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
