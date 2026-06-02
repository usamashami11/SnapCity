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
    this.swarmLogs = const [],
    this.weather,
    this.traffic,
    this.timestamp,
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
  final List<dynamic> swarmLogs;
  final String? weather;
  final String? traffic;
  final String? timestamp;

  factory AgentReportResponse.fromJson(Map<String, dynamic> json) {
    final detection = json['detection'] as Map<String, dynamic>? ?? {};
    final context = json['context'] as Map<String, dynamic>? ?? {};
    final reasoning = json['reasoning'] as Map<String, dynamic>? ?? {};
    final outcome = json['simulation_outcome'] as Map<String, dynamic>? ?? {};

    return AgentReportResponse(
      caseId: outcome['case_id']?.toString() ?? 'SC-UNKNOWN',
      issueType: detection['issue_type']?.toString() ?? 'Unknown Issue',
      confidence: (detection['confidence_score'] as num?)?.toInt() ?? 0,
      area: context['area']?.toString() ?? 'Unknown Area',
      severity: reasoning['severity_level']?.toString() ?? 'Medium',
      similarReports: (context['similar_reports_nearby'] as num?)?.toInt() ?? 0,
      duplicateClusterId: context['duplicate_cluster_id']?.toString(),
      lat: (json['gps'] as Map<String, dynamic>?)?['lat']?.toDouble(),
      lng: (json['gps'] as Map<String, dynamic>?)?['lng']?.toDouble(),
      locationName: json['location_name']?.toString(),
      escalationReason: reasoning['escalation_reason']?.toString() ?? '',
      assignedResponder: outcome['assigned_responder']?.toString() ?? '',
      eta: outcome['estimated_resolution_time']?.toString() ?? '',
      points: (outcome['user_reward']?['civic_points_earned'] as num?)?.toInt() ?? 0,
      rewardMessage: outcome['user_reward']?['message']?.toString() ?? '',
      noticeDraft: outcome['notice_draft']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      authority: json['authority'] as Map<String, dynamic>? ?? {},
      swarmLogs: json['swarm_logs'] as List<dynamic>? ?? [],
      weather: json['weather']?.toString(),
      traffic: json['traffic']?.toString(),
      timestamp: json['timestamp']?.toString(),
    );
  }
}
