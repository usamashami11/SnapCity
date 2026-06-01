class CivicCase {
  const CivicCase({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.severity,
    required this.reports,
    required this.strength,
    required this.updated,
    required this.action,
    required this.image,
    required this.detail,
    required this.helper,
    this.lat,
    this.lng,
    this.duplicateClusterId,
    this.similarReportsNearby = 0,
    this.rewardMessage,
    this.beforeImage,
    this.noticeDraft,
    this.authorityName,
    this.authorityEmail,
    this.authorityWhatsapp,
    this.tags = const [],
    this.weather,
    this.traffic,
  });

  final String id;
  final String title;
  final String location;
  final String status;
  final String severity;
  final int reports;
  final int strength;
  final String updated;
  final String action;
  final String image;
  final double? lat;
  final double? lng;
  final String? duplicateClusterId;
  final int similarReportsNearby;
  final String? rewardMessage;
  final String? beforeImage;
  final String? noticeDraft;
  final String? authorityName;
  final String? authorityEmail;
  final String? authorityWhatsapp;
  final String detail;
  final String helper;
  final List<String> tags;
  final String? weather;
  final String? traffic;
}

class MapIssue {
  const MapIssue({
    required this.caseId,
    required this.title,
    required this.status,
    required this.severity,
    required this.distance,
    required this.confirmations,
    required this.image,
    required this.x,
    required this.y,
  });

  final String caseId;
  final String title;
  final String status;
  final String severity;
  final String distance;
  final String confirmations;
  final String image;
  final double x;
  final double y;
}
