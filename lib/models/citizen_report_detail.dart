import 'package:e_response_app_nemsu/helpers/api_url.dart';

/// Single citizen report from `GET /api/v1/reports/{id}`.
class CitizenReportDetail {
  const CitizenReportDetail({
    required this.id,
    this.userId,
    this.latitude,
    this.longitude,
    this.details,
    this.callStartedAt,
    this.callEndedAt,
    this.address,
    this.status,
    this.type,
    this.reportedBy,
    this.reportersAddress,
    this.accuracy,
    this.isManuallyAdded,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.reportImages = const [],
    this.user,
  });

  final int id;
  final int? userId;
  final String? latitude;
  final String? longitude;
  final String? details;
  final DateTime? callStartedAt;
  final DateTime? callEndedAt;
  final String? address;
  final String? status;
  final String? type;
  final String? reportedBy;
  final String? reportersAddress;
  final String? accuracy;
  final String? isManuallyAdded;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final List<CitizenReportImage> reportImages;
  final CitizenReportUser? user;

  /// Laravel typically serves `storage/{filename}` publicly.
  static String imageUrlFromFilename(String? filename) {
    if (filename == null || filename.trim().isEmpty) {
      return '';
    }
    final path = filename.trim().replaceFirst(RegExp(r'^/+'), '');
    return '${ApiUrl.baseUrl}/storage/$path';
  }

  bool get isMessage => (type ?? '').toLowerCase() == 'message';

  /// Matches fields consumed by [SituationalIncidentReportFormPage._applyCitizenPrefill].
  Map<String, dynamic> toCitizenFormPrefill() {
    final displayName =
        (reportedBy != null && reportedBy!.trim().isNotEmpty)
            ? reportedBy!.trim()
            : (user?.name?.trim().isNotEmpty == true ? user!.name!.trim() : null);

    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'type': type,
      'details': details,
      'address': address,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (displayName != null) 'user_name': displayName,
      if (displayName != null) 'name': displayName,
      if (user != null)
        'user': <String, dynamic>{
          if (user!.id != null) 'id': user!.id,
          if (user!.name != null) 'name': user!.name,
          if (user!.phone != null) 'phone': user!.phone,
          if (user!.email != null) 'email': user!.email,
        },
    };
  }

  static CitizenReportDetail? fromEnvelope(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final m = Map<String, dynamic>.from(decoded);
    final data = m['data'];
    if (data is Map<String, dynamic>) {
      return fromJson(data);
    }
    if (data is Map) {
      return fromJson(Map<String, dynamic>.from(data));
    }
    return fromJson(m);
  }

  static CitizenReportDetail? fromJson(Map<String, dynamic>? m) {
    if (m == null) {
      return null;
    }
    final id = _readInt(m['id']);
    if (id == null) {
      return null;
    }

    final images = <CitizenReportImage>[];
    final rawImages = m['report_images'];
    if (rawImages is List) {
      for (final e in rawImages) {
        if (e is Map<String, dynamic>) {
          final img = CitizenReportImage.fromJson(e);
          if (img != null) {
            images.add(img);
          }
        } else if (e is Map) {
          final img = CitizenReportImage.fromJson(
            Map<String, dynamic>.from(e),
          );
          if (img != null) {
            images.add(img);
          }
        }
      }
    }

    CitizenReportUser? userObj;
    final u = m['user'];
    if (u is Map<String, dynamic>) {
      userObj = CitizenReportUser.fromJson(u);
    } else if (u is Map) {
      userObj = CitizenReportUser.fromJson(Map<String, dynamic>.from(u));
    }

    return CitizenReportDetail(
      id: id,
      userId: _readInt(m['user_id']),
      latitude: _readString(m['latitude']),
      longitude: _readString(m['longitude']),
      details: _readString(m['details']),
      callStartedAt: _readDateTime(m['call_started_at']),
      callEndedAt: _readDateTime(m['call_ended_at']),
      address: _readString(m['address']),
      status: _readString(m['status']),
      type: _readString(m['type']),
      reportedBy: _readString(m['reported_by']),
      reportersAddress: _readString(m['reporters_address']),
      accuracy: _readString(m['accuracy']),
      isManuallyAdded: m['is_manually_added']?.toString(),
      createdAt: _readDateTime(m['created_at']),
      updatedAt: _readDateTime(m['updated_at']),
      deletedAt: _readDateTime(m['deleted_at']),
      reportImages: images,
      user: userObj,
    );
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

  static DateTime? _readDateTime(dynamic v) {
    if (v == null) {
      return null;
    }
    return DateTime.tryParse(v.toString());
  }
}

class CitizenReportImage {
  const CitizenReportImage({
    this.id,
    this.reportId,
    this.filename,
  });

  final int? id;
  final int? reportId;
  final String? filename;

  static CitizenReportImage? fromJson(Map<String, dynamic> m) {
    final fn = m['filename']?.toString().trim();
    if (fn == null || fn.isEmpty) {
      return null;
    }
    return CitizenReportImage(
      id: CitizenReportDetail._readInt(m['id']),
      reportId: CitizenReportDetail._readInt(m['report_id']),
      filename: fn,
    );
  }

  String get fullUrl => CitizenReportDetail.imageUrlFromFilename(filename);
}

class CitizenReportUser {
  const CitizenReportUser({
    this.id,
    this.name,
    this.phone,
    this.email,
  });

  final int? id;
  final String? name;
  final String? phone;
  final String? email;

  static CitizenReportUser? fromJson(Map<String, dynamic> m) {
    final name = m['name']?.toString().trim();
    return CitizenReportUser(
      id: CitizenReportDetail._readInt(m['id']),
      name: name != null && name.isNotEmpty ? name : null,
      phone: m['phone']?.toString().trim(),
      email: m['email']?.toString().trim(),
    );
  }
}
