import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/models/situational_incident_report.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:e_response_app_nemsu/services/situational_incident_report_service.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Create or edit a situational incident report (staff/rescuer or admin).
class SituationalIncidentReportFormPage extends StatefulWidget {
  const SituationalIncidentReportFormPage({
    super.key,
    this.existingId,
    this.prefillFromCitizenReport,
  });

  final int? existingId;

  /// Seeds fields from a citizen call/message row (dispatch).
  final Map<String, dynamic>? prefillFromCitizenReport;

  @override
  State<SituationalIncidentReportFormPage> createState() =>
      _SituationalIncidentReportFormPageState();
}

class _SituationalIncidentReportFormPageState
    extends State<SituationalIncidentReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = SituationalIncidentReportService();
  final _prefs = SharedPreferencesService();

  final _incidentType = TextEditingController();
  final _callerSource = TextEditingController();
  final _receiver = TextEditingController();
  final _location = TextEditingController();
  final _landmark = TextEditingController();
  final _details = TextEditingController();
  final _vehicles = TextEditingController();
  final _examNotes = TextEditingController();
  final _actionTaken = TextEditingController();
  final _hospitalName = TextEditingController();
  final _responders = TextEditingController();
  final _responseVehicle = TextEditingController();

  DateTime? _dateTimeReceived;
  TimeOfDay? _timeResponse;
  TimeOfDay? _timeTransported;
  String? _avpu;
  bool _referHospital = false;

  bool _injDeformity = false;
  bool _injContusion = false;
  bool _injAbrasion = false;
  bool _injPuncture = false;
  bool _injTenderness = false;
  bool _injLaceration = false;
  bool _injSwelling = false;

  bool _loadingExisting = false;
  bool _saving = false;
  int? _editingId;

  static const _avpuOptions = <String, String>{
    'alert': 'A — Alert',
    'verbal': 'V — Verbal',
    'pain': 'P — Pain',
    'unconscious': 'U — Unconscious',
  };

  @override
  void initState() {
    super.initState();
    _editingId = widget.existingId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardStaffAndMaybeLoad();
    });
  }

  @override
  void dispose() {
    _incidentType.dispose();
    _callerSource.dispose();
    _receiver.dispose();
    _location.dispose();
    _landmark.dispose();
    _details.dispose();
    _vehicles.dispose();
    _examNotes.dispose();
    _actionTaken.dispose();
    _hospitalName.dispose();
    _responders.dispose();
    _responseVehicle.dispose();
    super.dispose();
  }

  Future<void> _guardStaffAndMaybeLoad() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    if (!AppMobileRole.fromPrefs(prefs).canAccessIncidentWorkspace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only staff, rescuer, or administrator accounts can file this report.',
          ),
        ),
      );
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    final id = _editingId;
    if (id != null) {
      await _loadExisting(id);
    } else if (widget.prefillFromCitizenReport != null &&
        widget.prefillFromCitizenReport!.isNotEmpty) {
      _applyCitizenPrefill(widget.prefillFromCitizenReport!);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _applyCitizenPrefill(Map<String, dynamic> tx) {
    final type = (tx['type'] ?? '').toString().toLowerCase();
    final isMessage = type == 'message';
    _incidentType.text =
        isMessage
            ? 'Citizen message report'
            : 'Citizen voice / call report';

    final name =
        tx['user_name'] ??
        tx['citizen_name'] ??
        tx['name'] ??
        (tx['user'] is Map ? (tx['user'] as Map)['name'] : null);
    final uid = tx['user_id'] ?? tx['userId'];
    final rid = tx['id'];
    _callerSource.text =
        (name != null && name.toString().trim().isNotEmpty)
            ? name.toString().trim()
            : '';

    final details = tx['details']?.toString().trim() ?? '';
    final status = tx['status']?.toString().trim() ?? '';
    final buf = StringBuffer();
    if (details.isNotEmpty) {
      buf.writeln(details);
    }
    if (status.isNotEmpty) {
      buf.writeln('Citizen report status: $status');
    }
    _details.text = buf.toString().trim();

    _location.text = tx['address']?.toString().trim() ?? '';

    final createdRaw = tx['created_at']?.toString();
    if (createdRaw != null) {
      final dt = DateTime.tryParse(createdRaw);
      if (dt != null) {
        _dateTimeReceived = dt.toLocal();
      }
    }

    final meta = <String>[
      'Intake metadata (do not duplicate in caller field)',
      'Channel: ${isMessage ? 'In-app message' : 'Voice call'}',
      if (uid != null) 'User ID: $uid',
      if (rid != null) 'Citizen report #: $rid',
    ].join('\n');
    _examNotes.text = '$meta\n\nPrefilled from citizen intake.';
  }

  /// Caller field is restricted to a human full name (no IDs or channel text).
  String? _validateCallerFullName(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) {
      return 'Enter the caller\'s full name';
    }
    if (RegExp(r'\d').hasMatch(s)) {
      return 'Use letters only — move IDs to examination notes';
    }
    final tokens =
        s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 2) {
      return 'Enter first and last name';
    }
    final allowed = RegExp(r"^[\p{L}\s'.-]+$", unicode: true);
    if (!allowed.hasMatch(s)) {
      return 'Invalid characters in name';
    }
    return null;
  }

  Future<void> _loadExisting(int id) async {
    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (token.isEmpty) {
      return;
    }
    setState(() => _loadingExisting = true);
    final result = await _service.fetchOne(id, bearerToken: token);
    if (!mounted) {
      return;
    }
    setState(() => _loadingExisting = false);
    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureSnackText('Could not load report')),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    _applyReport(result.data!);
  }

  /// Prefer a bare full name when legacy rows stored "Reporter: … · User ID …".
  String _normalizeCallerFieldForEdit(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return '';
    }
    final m = RegExp(r'^Reporter:\s*([^·]+)').firstMatch(s);
    if (m != null) {
      final n = m.group(1)?.trim() ?? '';
      if (n.isNotEmpty) {
        return n;
      }
    }
    if (!RegExp(r'\d').hasMatch(s)) {
      return s;
    }
    return '';
  }

  void _applyReport(SituationalIncidentReport r) {
    _incidentType.text = r.incidentType ?? '';
    _callerSource.text = _normalizeCallerFieldForEdit(
      r.callerSourceOfInformation ?? '',
    );
    _receiver.text = r.receiver ?? '';
    final tr = SituationalIncidentReport.parseTimeHm(r.timeOfResponse);
    _timeResponse =
        tr != null ? TimeOfDay(hour: tr.hour, minute: tr.minute) : null;
    final tt = SituationalIncidentReport.parseTimeHm(r.timeTransported);
    _timeTransported =
        tt != null ? TimeOfDay(hour: tt.hour, minute: tt.minute) : null;
    _location.text = r.location ?? '';
    _landmark.text = r.landmark ?? '';
    _details.text = r.detailsOfIncident ?? '';
    _vehicles.text = r.vehiclesInvolved ?? '';
    _examNotes.text = r.examinationNotes ?? '';
    _actionTaken.text = r.actionTaken ?? '';
    _hospitalName.text = r.nameOfHospital ?? '';
    _responders.text = r.nameOfResponders ?? '';
    _responseVehicle.text = r.nameOfResponseVehicle ?? '';

    setState(() {
      _dateTimeReceived = r.dateTimeReceived;
      _avpu = r.avpuSelectionKey;
      final ref = r.referToHospital?.toLowerCase();
      _referHospital = ref == 'yes';
      _injDeformity = r.hasDeformity;
      _injContusion = r.hasContusion;
      _injAbrasion = r.hasAbrasion;
      _injPuncture = r.hasPuncturePenetration;
      _injTenderness = r.hasTenderness;
      _injLaceration = r.hasLaceration;
      _injSwelling = r.hasSwelling;
      _editingId = r.id;
    });
  }

  Future<void> _pickDateTimeReceived() async {
    final initial = _dateTimeReceived ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await _showTimePicker12h(
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _dateTimeReceived = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickTimeResponse() async {
    final initial = _timeResponse ?? TimeOfDay.now();
    final picked = await _showTimePicker12h(
      initialTime: initial,
      helpText: 'Time of response',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _timeResponse = picked);
  }

  Future<void> _pickTimeTransported() async {
    final initial = _timeTransported ?? TimeOfDay.now();
    final picked = await _showTimePicker12h(
      initialTime: initial,
      helpText: 'Time transported',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _timeTransported = picked);
  }

  /// Force 12-hour clock in the Material time picker dialog.
  Future<TimeOfDay?> _showTimePicker12h({
    required TimeOfDay initialTime,
    String? helpText,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  String _timeHmLabel(TimeOfDay? t) {
    if (t == null) {
      return 'Tap to select';
    }
    final dt = DateTime(1970, 1, 1, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_dateTimeReceived == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose date & time received')),
      );
      return;
    }

    final creds = await _prefs.getCredentials();
    if (!mounted) {
      return;
    }
    final token = creds['token'] ?? '';
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Sign in again.')),
      );
      return;
    }

    final body = SituationalIncidentReport(
      id: _editingId,
      incidentType: _incidentType.text.trim(),
      callerSourceOfInformation: _callerSource.text.trim(),
      receiver: _receiver.text.trim(),
      dateTimeReceived: _dateTimeReceived,
      timeOfResponse:
          _timeResponse != null
              ? SituationalIncidentReport.formatTimeHm(
                _timeResponse!.hour,
                _timeResponse!.minute,
              )
              : null,
      location: _location.text.trim(),
      landmark: _landmark.text.trim(),
      detailsOfIncident: _details.text.trim(),
      vehiclesInvolved: _vehicles.text.trim(),
      isAlertResponse: _avpu == 'alert',
      isVerbalResponse: _avpu == 'verbal',
      isPainResponse: _avpu == 'pain',
      isUnconscious: _avpu == 'unconscious',
      hasDeformity: _injDeformity,
      hasContusion: _injContusion,
      hasAbrasion: _injAbrasion,
      hasPuncturePenetration: _injPuncture,
      hasTenderness: _injTenderness,
      hasLaceration: _injLaceration,
      hasSwelling: _injSwelling,
      examinationNotes: _examNotes.text.trim(),
      actionTaken: _actionTaken.text.trim(),
      referToHospital: _referHospital ? 'yes' : 'no',
      timeTransported:
          _timeTransported != null
              ? SituationalIncidentReport.formatTimeHm(
                _timeTransported!.hour,
                _timeTransported!.minute,
              )
              : null,
      nameOfHospital: _hospitalName.text.trim(),
      nameOfResponders: _responders.text.trim(),
      nameOfResponseVehicle: _responseVehicle.text.trim(),
    );

    setState(() => _saving = true);

    final SituationalIncidentReportResult<SituationalIncidentReport> result;

    if (_editingId != null) {
      result = await _service.update(_editingId!, body, bearerToken: token);
    } else {
      result = await _service.create(body, bearerToken: token);
    }

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (!result.isSuccess) {
      final fallback =
          _editingId != null ? 'Update failed' : 'Submit failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureSnackText(fallback)),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editingId != null ? 'Report updated.' : 'Report submitted.',
        ),
      ),
    );
    Navigator.of(context, rootNavigator: true).pop(true);
  }

  Future<void> _confirmDelete() async {
    final id = _editingId;
    if (id == null) {
      return;
    }
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Delete report?'),
                content: const Text(
                  'This incident report will be removed from your history.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok || !mounted) {
      return;
    }

    final creds = await _prefs.getCredentials();
    final token = creds['token'] ?? '';
    if (token.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    final result = await _service.delete(id, bearerToken: token);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failureSnackText('Delete failed')),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report deleted.')),
    );
    Navigator.of(context, rootNavigator: true).pop(true);
  }

  InputDecoration _fieldDeco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  Widget _injuryChip(String code, String label, bool value, void Function(bool) onSel) {
    return FilterChip(
      label: Text('$code — $label'),
      selected: value,
      showCheckmark: true,
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primarySoft,
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: value ? AppColors.primary : AppColors.textPrimary,
        fontSize: 13,
      ),
      onSelected: onSel,
    );
  }

  Widget _schedulePickerTile({
    required ThemeData theme,
    required String label,
    required String subtitle,
    required String valueLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final hasValue = valueLabel != 'Tap to select';
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valueLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color:
                            hasValue
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.schedule_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Paper-form diagram + notes (responsive).
  Widget _headToToeDiagramAndNotes(ThemeData theme) {
    final notesField = TextFormField(
      controller: _examNotes,
      decoration: _fieldDeco(
        'Examination notes & injury locations',
        hint:
            'Body regions, findings, vitals — use diagram as reference (pinch to zoom)',
      ),
      maxLines: 5,
    );

    final diagram = _HeadToToeFigureCard(theme: theme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: diagram),
              const SizedBox(width: 16),
              Expanded(flex: 6, child: notesField),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            diagram,
            const SizedBox(height: 16),
            notesField,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dtLabel =
        _dateTimeReceived != null
            ? '${DateFormat('MMM d, y').format(_dateTimeReceived!.toLocal())} · ${DateFormat.jm().format(_dateTimeReceived!.toLocal())}'
            : 'Select date & time';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _editingId != null ? 'Edit situational report' : 'Situational incident report',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'CDRRMO structured record · ${_editingId != null ? 'Update on file' : 'New draft'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          if (_editingId != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar:
          _loadingExisting
              ? null
              : Material(
                elevation: 12,
                color: AppColors.surface,
                shadowColor: AppColors.shadowSoft,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _saving
                              ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _editingId != null
                                        ? Icons.save_rounded
                                        : Icons.send_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _editingId != null
                                        ? 'Save changes'
                                        : 'Submit report',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
      body:
          _loadingExisting
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _FormSectionCard(
                      kicker: 'SECTION 01',
                      title: 'Incident intake',
                      subtitle:
                          'Core identifiers and timeline for this response.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _incidentType,
                            decoration: _fieldDeco('Incident classification'),
                            textCapitalization: TextCapitalization.sentences,
                            validator:
                                (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _callerSource,
                            decoration: _fieldDeco(
                              'Caller full name',
                              hint: 'First and last name as stated by caller',
                            ),
                            textCapitalization: TextCapitalization.words,
                            keyboardType: TextInputType.name,
                            validator: _validateCallerFullName,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _receiver,
                            decoration: _fieldDeco(
                              'Receiving officer',
                              hint: 'Staff member who documented the report',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: _pickDateTimeReceived,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.event_available_rounded,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date & time received',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: AppColors.textMuted,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dtLabel,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _schedulePickerTile(
                            theme: theme,
                            label: 'Time of response',
                            subtitle: 'Team deployment or arrival time',
                            valueLabel: _timeHmLabel(_timeResponse),
                            icon: Icons.directions_run_rounded,
                            onTap: _pickTimeResponse,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _location,
                            decoration: _fieldDeco('Incident location'),
                            textCapitalization: TextCapitalization.sentences,
                            validator:
                                (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _landmark,
                            decoration: _fieldDeco(
                              'Nearest landmark',
                              hint: 'Optional — aids field navigation',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _details,
                            decoration: _fieldDeco(
                              'Narrative — details of incident',
                              hint:
                                  'Victims, demographics, contacts, circumstances…',
                            ),
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _vehicles,
                            decoration: _fieldDeco(
                              'Vehicles involved',
                              hint: 'Type, color, plate or distinguishing marks',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    _ExpandableClinicalSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'AVPU — assessing responsiveness',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Matches paper form: Alert, Verbal, Pain, Unconscious.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _avpuOptions.entries.map((e) {
                                  final selected = _avpu == e.key;
                                  return ChoiceChip(
                                    label: Text(e.value),
                                    selected: selected,
                                    showCheckmark: true,
                                    selectedColor: AppColors.primarySoft,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color:
                                          selected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                    ),
                                    side: BorderSide(
                                      color:
                                          selected
                                              ? AppColors.primary.withValues(
                                                alpha: 0.35,
                                              )
                                              : AppColors.border,
                                    ),
                                    onSelected: (sel) {
                                      setState(() {
                                        if (sel) {
                                          _avpu = e.key;
                                        } else if (_avpu == e.key) {
                                          _avpu = null;
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Patient head-to-toe (DCAPTELS)',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select findings below; annotate regions beside the figure.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _injuryChip(
                                'D',
                                'Deformity',
                                _injDeformity,
                                (v) => setState(() => _injDeformity = v),
                              ),
                              _injuryChip(
                                'C',
                                'Contusion',
                                _injContusion,
                                (v) => setState(() => _injContusion = v),
                              ),
                              _injuryChip(
                                'A',
                                'Abrasion',
                                _injAbrasion,
                                (v) => setState(() => _injAbrasion = v),
                              ),
                              _injuryChip(
                                'P',
                                'Puncture',
                                _injPuncture,
                                (v) => setState(() => _injPuncture = v),
                              ),
                              _injuryChip(
                                'T',
                                'Tenderness',
                                _injTenderness,
                                (v) => setState(() => _injTenderness = v),
                              ),
                              _injuryChip(
                                'L',
                                'Laceration',
                                _injLaceration,
                                (v) => setState(() => _injLaceration = v),
                              ),
                              _injuryChip(
                                'S',
                                'Swelling',
                                _injSwelling,
                                (v) => setState(() => _injSwelling = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _headToToeDiagramAndNotes(theme),
                        ],
                      ),
                    ),
                    _FormSectionCard(
                      kicker: 'SECTION 03',
                      title: 'Interventions',
                      subtitle: 'Actions performed prior to disposition.',
                      child: TextFormField(
                        controller: _actionTaken,
                        decoration: _fieldDeco(
                          'Action taken on scene',
                          hint: 'Treatments, extrication, coordination…',
                        ),
                        maxLines: 5,
                      ),
                    ),
                    _FormSectionCard(
                      kicker: 'SECTION 04',
                      title: 'Disposition & transport',
                      subtitle: 'Hospital referral and movement of patient(s).',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Hospital referral',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Sets referral flag for downstream records.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            value: _referHospital,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) => setState(() => _referHospital = v),
                          ),
                          const Divider(height: 28),
                          _schedulePickerTile(
                            theme: theme,
                            label: 'Time transported',
                            subtitle: 'When patient moved from scene',
                            valueLabel: _timeHmLabel(_timeTransported),
                            icon: Icons.local_hospital_outlined,
                            onTap: _pickTimeTransported,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _hospitalName,
                            decoration: _fieldDeco(
                              'Receiving facility',
                              hint: 'Hospital or clinic name',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ],
                      ),
                    ),
                    _FormSectionCard(
                      kicker: 'SECTION 05',
                      title: 'Resources',
                      subtitle: 'Personnel and apparatus.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _responders,
                            decoration: _fieldDeco(
                              'Responder names',
                              hint: 'Comma or line-separated',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _responseVehicle,
                            decoration: _fieldDeco(
                              'Response vehicle / unit',
                              hint: 'Designation or plate',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 8,
                    ),
                  ],
                ),
              ),
    );
  }
}

/// Section 02 — tap header to expand/collapse; strong border & tint when expanded.
class _ExpandableClinicalSection extends StatefulWidget {
  const _ExpandableClinicalSection({required this.child});

  final Widget child;

  @override
  State<_ExpandableClinicalSection> createState() =>
      _ExpandableClinicalSectionState();
}

class _ExpandableClinicalSectionState extends State<_ExpandableClinicalSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emphasized = _expanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: emphasized ? AppColors.primary : AppColors.border,
            width: emphasized ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: emphasized ? 0.14 : 0.06,
              ),
              blurRadius: emphasized ? 28 : 18,
              offset: Offset(0, emphasized ? 12 : 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color:
                  emphasized
                      ? AppColors.primary.withValues(alpha: 0.07)
                      : const Color(0xFFF8FAFC),
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 12, emphasized ? 14 : 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              emphasized
                                  ? AppColors.primary
                                  : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SECTION 02',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Clinical snapshot',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AVPU, DCAPTELS, anatomical reference — tap to ${_expanded ? 'collapse' : 'expand'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                child: widget.child,
              ),
          ],
        ),
      ),
    );
  }
}

/// Anatomical figure from official paper form (`assets/human.jpg`).
class _HeadToToeFigureCard extends StatelessWidget {
  const _HeadToToeFigureCard({required this.theme});

  final ThemeData theme;

  static const _assetPath = 'assets/human.jpg';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Anatomical reference (front / back)',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pinch to zoom. Describe injury locations in notes →',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: const Color(0xFFEEF2F7),
            child: SizedBox(
              height: 300,
              child: InteractiveViewer(
                minScale: 0.85,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    _assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Add assets/human.jpg to load the paper-form figure.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section shell — consistent elevation, typography, and spacing.
class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.kicker,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String kicker;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kicker,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

