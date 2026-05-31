import 'dart:async';
import 'dart:ui' as ui;

import 'package:e_response_app_nemsu/services/routing_service.dart';
import 'package:e_response_app_nemsu/services/tracking_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RescueTrackingScreen extends StatefulWidget {
  const RescueTrackingScreen({super.key, required this.args});

  final TrackingArgs args;

  @override
  State<RescueTrackingScreen> createState() => _RescueTrackingScreenState();
}

class _RescueTrackingScreenState extends State<RescueTrackingScreen> {
  final MapController _mapCtrl = MapController();

  StreamSubscription<TrackingSession?>? _sessionSub;
  StreamSubscription<Position>? _gpsSub;

  TrackingSession? _session;
  Position? _ownPos;
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;
  bool _mapReady = false;
  bool _isArrived = false;
  bool _markingArrived = false;
  LatLng? _lastRouteFetch;

  bool get _isRescuer => widget.args.role == TrackingRole.rescuer;

  // ── Derived locations ─────────────────────────────────────────────────────

  LatLng? get _residentLatLng {
    final lat = widget.args.residentLat;
    final lng = widget.args.residentLng;
    if (lat != null && lng != null) return LatLng(lat, lng);
    final loc = _session?.residentLocation;
    if (loc != null) return LatLng(loc.lat, loc.lng);
    return null;
  }

  LatLng? get _rescuerLatLng {
    if (_isRescuer && _ownPos != null) {
      return LatLng(_ownPos!.latitude, _ownPos!.longitude);
    }
    final loc = _session?.rescuerLocation;
    if (loc != null) return LatLng(loc.lat, loc.lng);
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _listenSession();
    _startGps();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _gpsSub?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ── Firestore session listener ────────────────────────────────────────────

  void _listenSession() {
    _sessionSub =
        TrackingService.watchSession(widget.args.reportId).listen((s) {
      if (!mounted) return;
      setState(() => _session = s);
      if (s?.status == 'arrived' || s?.status == 'completed') {
        setState(() => _isArrived = true);
      }
      // Citizen: re-route whenever the rescuer moves.
      if (!_isRescuer) _maybeRefreshRoute();
    });
  }

  // ── GPS stream ────────────────────────────────────────────────────────────

  Future<void> _startGps() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    // Quick first fix.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() => _ownPos = pos);
        _onPosition(pos);
      }
    } catch (_) {}

    // Continuous stream — rescuer updates every ~3 s, citizen every ~15 s.
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _isRescuer ? 5 : 15,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _ownPos = pos);
      _onPosition(pos);
    });
  }

  void _onPosition(Position pos) {
    if (_isRescuer) {
      TrackingService.updateRescuerLocation(widget.args.reportId, pos)
          .catchError((_) {});
      _maybeRefreshRoute();
    }
  }

  // ── Route ─────────────────────────────────────────────────────────────────

  Future<void> _maybeRefreshRoute() async {
    final resident = _residentLatLng;
    final rescuer = _rescuerLatLng;
    if (resident == null || rescuer == null || _routeLoading) return;

    // Skip if rescuer hasn't moved >30 m since last fetch.
    if (_lastRouteFetch != null &&
        RoutingService.distanceMeters(_lastRouteFetch!, rescuer) < 30) {
      return;
    }

    setState(() => _routeLoading = true);
    _lastRouteFetch = rescuer;
    final route = await RoutingService.fetchRoute(rescuer, resident);
    if (!mounted) return;
    setState(() {
      _routePoints = route;
      _routeLoading = false;
    });
  }

  // ── Map helpers ───────────────────────────────────────────────────────────

  void _centerOn(LatLng pt) {
    if (_mapReady) _mapCtrl.move(pt, 15.5);
  }

  void _fitBoth() {
    final a = _residentLatLng;
    final b = _rescuerLatLng;
    if (a == null || b == null || !_mapReady) return;
    try {
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([a, b]),
          padding: const EdgeInsets.all(72),
        ),
      );
    } catch (_) {}
  }

  // ── Rescuer action ────────────────────────────────────────────────────────

  Future<void> _markArrived() async {
    setState(() => _markingArrived = true);
    try {
      await TrackingService.updateStatus(widget.args.reportId, 'arrived');
      if (mounted) setState(() => _isArrived = true);
    } catch (_) {} finally {
      if (mounted) setState(() => _markingArrived = false);
    }
  }

  // ── Status display ────────────────────────────────────────────────────────

  String get _statusText {
    final s = _session?.status ?? 'en_route';
    if (s == 'arrived') return _isRescuer ? 'You have arrived' : 'Rescuer has arrived!';
    if (s == 'completed') return 'Rescue completed';
    if (_session == null) return _isRescuer ? 'Starting navigation…' : 'Waiting for rescuer…';
    return _isRescuer ? 'Navigating to resident' : 'Rescuer is on the way';
  }

  Color get _statusColor {
    final s = _session?.status ?? '';
    if (s == 'arrived' || s == 'completed') return AppColors.success;
    if (_session == null) return AppColors.textMuted;
    return AppColors.primaryAlt;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final resident = _residentLatLng;
    final rescuer = _rescuerLatLng;

    // Default center: Tandag, Surigao del Sur (app's home municipality).
    final initialCenter = resident ?? const LatLng(9.0820, 126.2006);

    final distText = (resident != null && rescuer != null)
        ? RoutingService.formatDistance(
            RoutingService.distanceMeters(rescuer, resident))
        : '—';
    final etaText = (resident != null && rescuer != null)
        ? RoutingService.estimateEta(
            RoutingService.distanceMeters(rescuer, resident))
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRescuer ? 'Navigate to Resident' : 'Track Rescuer'),
        actions: [
          if (resident != null && rescuer != null)
            IconButton(
              tooltip: 'Fit both markers',
              icon: const Icon(Icons.fit_screen_rounded),
              onPressed: _fitBoth,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.5,
              onMapReady: () {
                setState(() => _mapReady = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (resident != null && rescuer != null) {
                    _fitBoth();
                  } else if (resident != null) {
                    _centerOn(resident);
                  }
                  _maybeRefreshRoute();
                });
              },
            ),
            children: [
              // OSM tile layer — no API key required.
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.e_response_app_nemsu',
                maxNativeZoom: 19,
              ),
              // Driving route polyline.
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primaryAlt.withValues(alpha: 0.88),
                      strokeWidth: 5.5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),
              // Resident + rescuer markers.
              MarkerLayer(
                markers: [
                  if (resident != null)
                    Marker(
                      point: resident,
                      width: 48,
                      height: 52,
                      child: _MapPin(
                        icon: Icons.home_rounded,
                        color: AppColors.accent,
                        label: widget.args.residentName ?? 'Resident',
                      ),
                    ),
                  if (rescuer != null)
                    Marker(
                      point: rescuer,
                      width: 48,
                      height: 52,
                      child: const _MapPin(
                        icon: Icons.local_taxi_rounded,
                        color: AppColors.success,
                        label: 'Rescuer',
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Route-loading chip ────────────────────────────────────────────
          if (_routeLoading)
            const Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(child: _RouteLoadingChip()),
            ),

          // ── Re-center FAB ─────────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 192,
            child: FloatingActionButton.small(
              heroTag: 'recenter_tracking',
              tooltip: 'Centre on my location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 4,
              onPressed: () {
                final target = _isRescuer
                    ? (_ownPos != null
                        ? LatLng(_ownPos!.latitude, _ownPos!.longitude)
                        : resident)
                    : resident;
                if (target != null) _centerOn(target);
              },
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),

          // ── Bottom info / action panel ────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              statusText: _statusText,
              statusColor: _statusColor,
              distanceText: distText,
              etaText: etaText,
              isRescuer: _isRescuer,
              isArrived: _isArrived,
              markingArrived: _markingArrived,
              onMarkArrived: _markArrived,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

/// Circular pin with a small downward triangle — used as map markers.
class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        // Downward-pointing needle drawn with dart:ui Path to avoid the
        // latlong2.Path name conflict.
        CustomPaint(
          size: const Size(12, 6),
          painter: _NeedlePainter(color: color),
        ),
      ],
    );
  }
}

/// Paints a downward-pointing triangle using [dart:ui.Path] explicitly,
/// which avoids the name collision with [latlong2]'s own [Path] class.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.color != color;
}

/// Small floating chip shown while the route is being fetched.
class _RouteLoadingChip extends StatelessWidget {
  const _RouteLoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Calculating route…',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Slide-up panel at the bottom of the map with status, ETA and action button.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.statusText,
    required this.statusColor,
    required this.distanceText,
    required this.etaText,
    required this.isRescuer,
    required this.isArrived,
    required this.markingArrived,
    required this.onMarkArrived,
    required this.onClose,
  });

  final String statusText;
  final Color statusColor;
  final String distanceText;
  final String etaText;
  final bool isRescuer;
  final bool isArrived;
  final bool markingArrived;
  final VoidCallback onMarkArrived;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 22,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isArrived
                          ? Icons.check_circle_rounded
                          : Icons.navigation_rounded,
                      color: statusColor,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Distance + ETA tiles
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.straighten_rounded,
                      label: 'Distance',
                      value: distanceText,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.schedule_rounded,
                      label: 'ETA',
                      value: etaText,
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Action button
              if (isRescuer && !isArrived)
                FilledButton.icon(
                  onPressed: markingArrived ? null : onMarkArrived,
                  icon: markingArrived
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark as Arrived'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
              else if (isArrived)
                FilledButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.done_all_rounded),
                  label: Text(isRescuer
                      ? 'Done'
                      : 'Rescuer has arrived — Close'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
