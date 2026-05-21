// Backend contract from:
// "Copy of SNAPCITY (Suggestions regarding Repos and Antigravity usage).pdf"
//
// POST /api/v1/report
// {
//   "report_id": "rep_10293",
//   "image_url": "https://storage.mock/images/issue_01.jpg",
//   "gps": { "lat": 24.9180, "lng": 67.0971 },
//   "voice_note_transcript": "There is a deep open manhole..."
// }
//
// The UI currently uses mock data, but should later map the returned JSON fields:
// - detection.issue_type -> ticket title/category
// - detection.confidence_score -> confidence indicator
// - context.area -> location
// - context.similar_reports_nearby -> similar report count
// - reasoning.severity_level -> severity chip
// - reasoning.escalation_reason -> AI reasoning card
// - simulation_outcome.case_id -> case id
// - simulation_outcome.assigned_responder -> responsible body
// - simulation_outcome.estimated_resolution_time -> ETA/status
// - simulation_outcome.user_reward.civic_points_earned -> reward modal
// - dispatch_simulation.whatsapp_template/email_template -> copy/share actions

class ReportRequest {
  const ReportRequest({
    required this.reportId,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    required this.voiceNoteTranscript,
    this.locationName,
  });

  final String reportId;
  final String imageUrl;
  final double lat;
  final double lng;
  final String voiceNoteTranscript;
  final String? locationName;

  Map<String, dynamic> toJson() => {
        'report_id': reportId,
        'image_url': imageUrl,
        'gps': {'lat': lat, 'lng': lng},
        'voice_note_transcript': voiceNoteTranscript,
        if (locationName != null) 'location_name': locationName,
      };
}

class AgentReportResponse {
  const AgentReportResponse({
    required this.caseId,
    required this.issueType,
    required this.confidence,
    required this.area,
    required this.severity,
    required this.similarReports,
    required this.duplicateClusterId,
    required this.lat,
    required this.lng,
    required this.locationName,
    required this.escalationReason,
    required this.assignedResponder,
    required this.eta,
    required this.points,
    required this.rewardMessage,
    required this.noticeDraft,
    required this.imageUrl,
    required this.authority,
  });

  final String caseId;
  final String issueType;
  final int confidence;
  final String area;
  final String severity;
  final int similarReports;
  final String? duplicateClusterId;
  final double? lat;
  final double? lng;
  final String? locationName;
  final String escalationReason;
  final String assignedResponder;
  final String eta;
  final int points;
  final String rewardMessage;
  final String noticeDraft;
  final String imageUrl;
  final Map<String, dynamic> authority;

  factory AgentReportResponse.fromJson(Map<String, dynamic> json) {
    final detection = json['detection'] as Map<String, dynamic>? ?? {};
    final context = json['context'] as Map<String, dynamic>? ?? {};
    final reasoning = json['reasoning'] as Map<String, dynamic>? ?? {};
    final simulation =
        json['simulation_outcome'] as Map<String, dynamic>? ?? {};
    final reward = simulation['user_reward'] as Map<String, dynamic>? ?? {};
    return AgentReportResponse(
      caseId: simulation['case_id'] as String? ?? '',
      issueType: detection['issue_type'] as String? ?? '',
      confidence: detection['confidence_score'] as int? ?? 0,
      area: context['area'] as String? ?? '',
      severity: reasoning['severity_level'] as String? ?? '',
      similarReports: context['similar_reports_nearby'] as int? ?? 0,
      duplicateClusterId: context['duplicate_cluster_id'] as String? ??
          context['cluster_id'] as String?,
      lat: (json['gps'] as Map<String, dynamic>?)?['lat'] is num
          ? ((json['gps'] as Map<String, dynamic>)['lat'] as num).toDouble()
          : null,
      lng: (json['gps'] as Map<String, dynamic>?)?['lng'] is num
          ? ((json['gps'] as Map<String, dynamic>)['lng'] as num).toDouble()
          : null,
      locationName: json['location_name'] as String?,
      escalationReason: reasoning['escalation_reason'] as String? ?? '',
      assignedResponder: simulation['assigned_responder'] as String? ?? '',
      eta: simulation['estimated_resolution_time'] as String? ?? '',
      points: reward['civic_points_earned'] as int? ?? 0,
      rewardMessage: reward['message'] as String? ?? '',
      noticeDraft: simulation['notice_draft'] as String? ??
          json['notice_draft'] as String? ??
          '',
      imageUrl: json['image_url'] as String? ?? '',
      authority: simulation['authority'] as Map<String, dynamic>? ??
          json['authority'] as Map<String, dynamic>? ??
          {},
    );
  }
}
