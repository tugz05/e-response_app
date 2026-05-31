/// Arguments for [RouteManager.situationalIncidentReportForm].
class SituationalIncidentReportFormArgs {
  const SituationalIncidentReportFormArgs({
    this.existingId,
    this.citizenReportPrefill,
  });

  /// Edit existing situational incident report.
  final int? existingId;

  /// Citizen call/message row from [ReportHistoryService] to seed the form.
  final Map<String, dynamic>? citizenReportPrefill;
}
