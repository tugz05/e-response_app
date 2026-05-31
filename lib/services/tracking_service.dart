import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

enum TrackingRole { rescuer, citizen }

/// The Firestore-backed session for a single rescue operation.
class TrackingSession {
  const TrackingSession({
    required this.reportId,
    required this.residentUserId,
    this.rescuerUserId,
    required this.status,
    this.residentLocation,
    this.rescuerLocation,
  });

  final int reportId;
  final int residentUserId;
  final int? rescuerUserId;

  /// 'en_route' | 'arrived' | 'completed'
  final String status;

  final TrackingLocation? residentLocation;
  final TrackingLocation? rescuerLocation;

  factory TrackingSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return TrackingSession(
      reportId: (m['report_id'] as num).toInt(),
      residentUserId: (m['resident_user_id'] as num).toInt(),
      rescuerUserId: (m['rescuer_user_id'] as num?)?.toInt(),
      status: m['status'] as String? ?? 'en_route',
      residentLocation: _parseLocation(m['resident_location']),
      rescuerLocation: _parseLocation(m['rescuer_location']),
    );
  }

  static TrackingLocation? _parseLocation(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return TrackingLocation(
      lat: lat,
      lng: lng,
      accuracy: (m['accuracy'] as num?)?.toDouble(),
      heading: (m['heading'] as num?)?.toDouble(),
    );
  }
}

class TrackingLocation {
  const TrackingLocation({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.heading,
  });

  final double lat;
  final double lng;
  final double? accuracy;
  final double? heading;
}

/// Route argument for the rescue tracking screen.
class TrackingArgs {
  const TrackingArgs({
    required this.reportId,
    required this.role,
    this.residentLat,
    this.residentLng,
    this.residentName,
    this.residentUserId,
    this.rescuerUserId,
  });

  final int reportId;
  final TrackingRole role;
  final double? residentLat;
  final double? residentLng;
  final String? residentName;
  final int? residentUserId;
  final int? rescuerUserId;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// All Firestore operations for the rescue tracking feature.
///
/// Document path: `tracking_sessions/report_{reportId}`
///
/// Firestore security rules (add to your Firebase Console):
/// ```
/// match /tracking_sessions/{sessionId} {
///   allow read, write: if request.auth != null;
/// }
/// ```
class TrackingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _ref(int reportId) =>
      _db.collection('tracking_sessions').doc('report_$reportId');

  // ── Session lifecycle ─────────────────────────────────────────────────────

  /// Called by the rescuer to open a new session.
  /// Sets the resident's location from the report coordinates.
  static Future<void> startSession({
    required int reportId,
    required int residentUserId,
    required int rescuerUserId,
    required double residentLat,
    required double residentLng,
  }) async {
    await _ref(reportId).set(<String, dynamic>{
      'report_id': reportId,
      'resident_user_id': residentUserId,
      'rescuer_user_id': rescuerUserId,
      'status': 'en_route',
      'resident_location': {
        'lat': residentLat,
        'lng': residentLng,
        'updated_at': FieldValue.serverTimestamp(),
      },
      'rescuer_location': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream — both sides listen to this.
  static Stream<TrackingSession?> watchSession(int reportId) {
    return _ref(reportId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return TrackingSession.fromDoc(snap);
    });
  }

  // ── Location updates ──────────────────────────────────────────────────────

  /// Rescuer broadcasts their GPS position.
  static Future<void> updateRescuerLocation(
      int reportId, Position pos) async {
    await _ref(reportId).update(<String, dynamic>{
      'rescuer_location': {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'heading': pos.heading,
        'updated_at': FieldValue.serverTimestamp(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Status ────────────────────────────────────────────────────────────────

  /// Update session status: 'en_route' | 'arrived' | 'completed'
  static Future<void> updateStatus(int reportId, String status) async {
    await _ref(reportId).update(<String, dynamic>{
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
