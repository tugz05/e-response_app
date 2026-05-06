/// Payload for `/api/v1/situational-incident-reports` (snake_case).
/// AVPU and DCAPTELS are sent as explicit booleans (`is_alert_response`, `has_deformity`, …).
///
/// **Time-only fields** ([timeOfResponse], [timeTransported]): stored for the API
/// as 24-hour **`HH:mm`** (e.g. `14:30`). The staff form presents **12-hour** times
/// with AM/PM and converts when saving. Optional seconds from the API (`14:30:00`)
/// are accepted when parsing. Use [formatTimeHm] / [parseTimeHm] at the boundary.
class SituationalIncidentReport {
  const SituationalIncidentReport({
    this.id,
    this.userId,
    this.incidentType,
    this.callerSourceOfInformation,
    this.receiver,
    this.dateTimeReceived,
    this.timeOfResponse,
    this.location,
    this.landmark,
    this.detailsOfIncident,
    this.vehiclesInvolved,
    this.isAlertResponse = false,
    this.isVerbalResponse = false,
    this.isPainResponse = false,
    this.isUnconscious = false,
    this.hasDeformity = false,
    this.hasContusion = false,
    this.hasAbrasion = false,
    this.hasPuncturePenetration = false,
    this.hasTenderness = false,
    this.hasLaceration = false,
    this.hasSwelling = false,
    this.examinationNotes,
    this.actionTaken,
    this.referToHospital,
    this.timeTransported,
    this.nameOfHospital,
    this.nameOfResponders,
    this.nameOfResponseVehicle,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int? userId;
  final String? incidentType;
  final String? callerSourceOfInformation;
  final String? receiver;
  final DateTime? dateTimeReceived;

  /// Time of response — **time only**, `HH:mm` 24h (see class doc).
  final String? timeOfResponse;
  final String? location;
  final String? landmark;
  final String? detailsOfIncident;
  final String? vehiclesInvolved;

  /// AVPU — API: `is_alert_response`, `is_verbal_response`, `is_pain_response`, `is_unconscious`.
  final bool isAlertResponse;
  final bool isVerbalResponse;
  final bool isPainResponse;
  final bool isUnconscious;

  /// DCAPTELS — API: `has_deformity`, `has_contusion`, …
  final bool hasDeformity;
  final bool hasContusion;
  final bool hasAbrasion;
  final bool hasPuncturePenetration;
  final bool hasTenderness;
  final bool hasLaceration;
  final bool hasSwelling;

  final String? examinationNotes;
  final String? actionTaken;

  /// API expects `yes` or `no`.
  final String? referToHospital;

  /// Time transported — **time only**, `HH:mm` 24h (see class doc).
  final String? timeTransported;
  final String? nameOfHospital;
  final String? nameOfResponders;
  final String? nameOfResponseVehicle;
  final String? createdAt;
  final String? updatedAt;

  /// Single-select AVPU key used by the form (`alert` | `verbal` | `pain` | `unconscious`).
  String? get avpuSelectionKey {
    if (isAlertResponse) {
      return 'alert';
    }
    if (isVerbalResponse) {
      return 'verbal';
    }
    if (isPainResponse) {
      return 'pain';
    }
    if (isUnconscious) {
      return 'unconscious';
    }
    return null;
  }

  static SituationalIncidentReport? fromJson(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }

    var isAlert = _readBool(m['is_alert_response']);
    var isVerbal = _readBool(m['is_verbal_response']);
    var isPain = _readBool(m['is_pain_response']);
    var isUnconsciousFlag = _readBool(m['is_unconscious']);

    if (isAlert == null &&
        isVerbal == null &&
        isPain == null &&
        isUnconsciousFlag == null) {
      final legacy = _readString(m['avpu'])?.toLowerCase();
      isAlert = legacy == 'alert';
      isVerbal = legacy == 'verbal';
      isPain = legacy == 'pain';
      isUnconsciousFlag = legacy == 'unconscious';
    }

    bool coalesce(bool? v) => v ?? false;

    return SituationalIncidentReport(
      id:
          _readInt(m['id']) ??
          _readInt(m['situational_incident_report_id']) ??
          _readInt(m['report_id']),
      userId: _readInt(m['user_id']),
      incidentType: _readString(m['incident_type']),
      callerSourceOfInformation: _readString(m['caller_source_of_information']),
      receiver: _readString(m['receiver']),
      dateTimeReceived: _readDateTime(m['date_time_received']),
      timeOfResponse: _readString(m['time_of_response']),
      location: _readString(m['location']),
      landmark: _readString(m['landmark']),
      detailsOfIncident: _readString(m['details_of_incident']),
      vehiclesInvolved: _readString(m['vehicles_involved']),
      isAlertResponse: coalesce(isAlert),
      isVerbalResponse: coalesce(isVerbal),
      isPainResponse: coalesce(isPain),
      isUnconscious: coalesce(isUnconsciousFlag),
      hasDeformity: coalesce(
        _readBool(m['has_deformity']) ?? _readBool(m['injury_deformity']),
      ),
      hasContusion: coalesce(
        _readBool(m['has_contusion']) ?? _readBool(m['injury_contusion']),
      ),
      hasAbrasion: coalesce(
        _readBool(m['has_abrasion']) ?? _readBool(m['injury_abrasion']),
      ),
      hasPuncturePenetration: coalesce(
        _readBool(m['has_puncture_penetration']) ??
            _readBool(m['injury_puncture_penetration']),
      ),
      hasTenderness: coalesce(
        _readBool(m['has_tenderness']) ?? _readBool(m['injury_tenderness']),
      ),
      hasLaceration: coalesce(
        _readBool(m['has_laceration']) ?? _readBool(m['injury_laceration']),
      ),
      hasSwelling: coalesce(
        _readBool(m['has_swelling']) ?? _readBool(m['injury_swelling']),
      ),
      examinationNotes: _readString(m['examination_notes']),
      actionTaken: _readString(m['action_taken']),
      referToHospital: _readString(m['refer_to_hospital']),
      timeTransported: _readString(m['time_transported']),
      nameOfHospital: _readString(m['name_of_hospital']),
      nameOfResponders: _readString(m['name_of_responders']),
      nameOfResponseVehicle: _readString(m['name_of_response_vehicle']),
      createdAt: _readString(m['created_at']),
      updatedAt: _readString(m['updated_at']),
    );
  }

  /// Merge nested Laravel `data` when present.
  static SituationalIncidentReport? fromEnvelope(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return fromJson(data);
    }
    if (data is Map) {
      return fromJson(Map<String, dynamic>.from(data));
    }
    return fromJson(json);
  }

  Map<String, dynamic> toJson({bool forCreate = false}) {
    final m = <String, dynamic>{};

    void put(String key, dynamic value) {
      if (value == null) {
        return;
      }
      if (value is String &&
          value.trim().isEmpty &&
          key != 'refer_to_hospital') {
        return;
      }
      m[key] = value;
    }

    put('incident_type', incidentType?.trim());
    put(
      'caller_source_of_information',
      callerSourceOfInformation?.trim(),
    );
    put('receiver', receiver?.trim());
    if (dateTimeReceived != null) {
      m['date_time_received'] = dateTimeReceived!.toUtc().toIso8601String();
    }
    put('time_of_response', timeOfResponse?.trim());
    put('location', location?.trim());
    put('landmark', landmark?.trim());
    put('details_of_incident', detailsOfIncident?.trim());
    put('vehicles_involved', vehiclesInvolved?.trim());

    m['is_alert_response'] = isAlertResponse;
    m['is_verbal_response'] = isVerbalResponse;
    m['is_pain_response'] = isPainResponse;
    m['is_unconscious'] = isUnconscious;
    m['has_deformity'] = hasDeformity;
    m['has_contusion'] = hasContusion;
    m['has_abrasion'] = hasAbrasion;
    m['has_puncture_penetration'] = hasPuncturePenetration;
    m['has_tenderness'] = hasTenderness;
    m['has_laceration'] = hasLaceration;
    m['has_swelling'] = hasSwelling;

    put('examination_notes', examinationNotes?.trim());
    put('action_taken', actionTaken?.trim());

    final ref = referToHospital?.trim().toLowerCase();
    if (ref == 'yes' || ref == 'no') {
      m['refer_to_hospital'] = ref;
    } else if (!forCreate &&
        referToHospital != null &&
        referToHospital!.isNotEmpty) {
      m['refer_to_hospital'] = referToHospital!.trim().toLowerCase();
    }

    put('time_transported', timeTransported?.trim());
    put('name_of_hospital', nameOfHospital?.trim());
    put('name_of_responders', nameOfResponders?.trim());
    put('name_of_response_vehicle', nameOfResponseVehicle?.trim());

    return m;
  }

  static int? _readInt(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is int) {
      return v;
    }
    return int.tryParse(v.toString());
  }

  static String? _readString(dynamic v) {
    if (v == null) {
      return null;
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool? _readBool(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is bool) {
      return v;
    }
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == '1') {
      return true;
    }
    if (s == 'false' || s == '0') {
      return false;
    }
    return null;
  }

  static DateTime? _readDateTime(dynamic v) {
    if (v == null) {
      return null;
    }
    return DateTime.tryParse(v.toString());
  }

  /// Format hour/minute from a time picker for [timeOfResponse] / [timeTransported].
  static String formatTimeHm(int hour, int minute) {
    assert(hour >= 0 && hour <= 23);
    assert(minute >= 0 && minute <= 59);
    return '${hour.toString().padLeft(2, '0')}'
        ':${minute.toString().padLeft(2, '0')}';
  }

  /// Parses `HH:mm` or `HH:mm:ss` (and trims). Returns `null` if missing/invalid.
  static ({int hour, int minute})? parseTimeHm(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) {
      return null;
    }
    final parts = s.split(':');
    if (parts.length < 2) {
      return null;
    }
    final h = int.tryParse(parts[0]);
    final minutePart = parts[1].split(RegExp(r'\s+')).first;
    final min = int.tryParse(minutePart);
    if (h == null || min == null) {
      return null;
    }
    if (h < 0 || h > 23 || min < 0 || min > 59) {
      return null;
    }
    return (hour: h, minute: min);
  }
}
