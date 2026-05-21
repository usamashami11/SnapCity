import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../models.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';

Widget _buildDetailImage(String path,
    {double? height, double? width, BoxFit fit = BoxFit.cover}) {
  if (path.isEmpty) return Container(color: Colors.grey[200]);
  if (path.startsWith('http')) {
    return Image.network(path, height: height, width: width, fit: fit);
  } else if (path.startsWith('/') || path.contains(':/')) {
    return Image.file(File(path), height: height, width: width, fit: fit);
  } else {
    return Image.asset(path, height: height, width: width, fit: fit);
  }
}

class CaseDetailScreen extends StatelessWidget {
  const CaseDetailScreen({
    super.key,
    required this.item,
    required this.onBack,
    required this.onHome,
    required this.onCases,
    required this.onFeed,
    required this.onMap,
    required this.onSnap,
  });

  final CivicCase item;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onCases;
  final VoidCallback onFeed;
  final VoidCallback onMap;
  final VoidCallback onSnap;

  Color _severityColor() {
    switch (item.severity.toLowerCase()) {
      case 'high':
        return SnapColors.danger;
      case 'medium':
        return SnapColors.purple;
      default:
        return SnapColors.success;
    }
  }

  List<Map<String, dynamic>> _buildAiInsights() {
    final insights = <Map<String, dynamic>>[];
    if (item.similarReportsNearby > 0) {
      insights.add({
        'icon': Icons.group_rounded,
        'label':
            '${item.similarReportsNearby} supporting reports in the cluster',
      });
    }
    insights.add({
      'icon': Icons.show_chart_rounded,
      'label': 'AI confidence at ${item.strength}% for ${item.severity} risk',
    });
    if (item.duplicateClusterId?.isNotEmpty == true) {
      insights.add({
        'icon': Icons.cloud_circle_rounded,
        'label': 'Spatial cluster identified across nearby incidents',
      });
    }
    if (item.noticeDraft?.isNotEmpty == true) {
      insights.add({
        'icon': Icons.email_outlined,
        'label': 'Authority notice draft ready to send',
      });
    }
    if (item.location.isNotEmpty) {
      insights.add({
        'icon': Icons.location_on_rounded,
        'label': 'Verified location: ${item.location}',
      });
    }
    return insights.take(3).toList();
  }

  void _showPointsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10091E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: SnapColors.yellow, size: 28),
            SizedBox(width: 12),
            Text('Action Taken!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Message formatting complete. You have earned +10 Civic Impact Points for taking action!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great!',
                style: TextStyle(
                    color: SnapColors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _buildShareSubject() {
    return 'SnapCity Report ${item.id}: ${item.title}';
  }

  String _buildShareBody({bool friendVariant = false}) {
    final authority = item.authorityName?.isNotEmpty == true
        ? item.authorityName!
        : 'the local authority';
    final contact = item.authorityWhatsapp?.isNotEmpty == true
        ? 'WhatsApp ${item.authorityWhatsapp}'
        : item.authorityEmail?.isNotEmpty == true
            ? item.authorityEmail
            : 'official contact';

    final alertPrefix = friendVariant
        ? 'Heads up! I just logged a civic issue with SnapCity and wanted to share it with you.'
        : 'SnapCity has identified the following civic issue and routed it to $authority.';

    return '$alertPrefix\n\n'
        'Case #: ${item.id}\n'
        'Issue: ${item.title}\n'
        'Location: ${item.location}\n'
        'Severity: ${item.severity}\n'
        'Authority: $authority\n'
        'Contact: $contact\n\n'
        '${item.noticeDraft ?? 'Please review the attached issue and take action.'}\n\n'
        'View it in SnapCity for live status updates and follow-up.';
  }

  String _buildOfficialEmailBody() {
    final locationInfo =
        item.location.isNotEmpty ? item.location : 'Geo-coordinates pending';
    final coordinateNote = (item.lat != null && item.lng != null)
        ? ' (Lat: ${item.lat?.toStringAsFixed(4)}, Lng: ${item.lng?.toStringAsFixed(4)})'
        : '';

    return 'Dear Authority,\n\n'
        'This is an automated civic complaint generated via SnapCity. A verified public safety issue has been reported at $locationInfo$coordinateNote.\n\n'
        'Issue Details: ${item.title}\n'
        'Severity Level: ${item.severity}\n'
        'Reports Count: ${item.reports}\n'
        'AI Confidence: ${item.strength}%\n\n'
        'Case ID: #${item.id}\n'
        'Status: ${item.status}\n\n'
        'Please review the attached evidence image and initiate swift remediation to prevent further risk to the community. We look forward to your prompt response and action.\n\n'
        'Regards,\n'
        'SnapCity Civic Portal User';
  }

  String _buildFriendlyWhatsAppMessage() {
    return 'Hi there! I was just passing from ${item.location} and encountered this civic issue: ${item.title}. I would highly suggest you bypass this path or be safe if you are out. Take care!';
  }

  bool _hasLocalImageAttachment() {
    try {
      if (item.image.isEmpty) return false;
      if (item.image.startsWith('http')) return false;
      final file = File(item.image);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendOfficialEmail(BuildContext context) async {
    try {
      final authority =
          item.authorityEmail?.isNotEmpty == true ? item.authorityEmail! : '';

      if (authority.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Authority email not available for this case. Please contact manually.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final List<String> attachmentPaths =
          _hasLocalImageAttachment() ? [item.image] : [];

      final email = Email(
        body: _buildOfficialEmailBody(),
        subject:
            'SnapCity Report [#${item.id}]: ${item.title} - ${item.severity} Priority',
        recipients: [authority],
        attachmentPaths: attachmentPaths,
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      if (context.mounted) {
        _showPointsDialog(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to send email: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    try {
      final message = _buildFriendlyWhatsAppMessage();
      final params = ShareParams(
        text: message,
        files:
            _hasLocalImageAttachment() ? [XFile(File(item.image).path)] : null,
      );

      await SharePlus.instance.share(params);
      if (context.mounted) {
        _showPointsDialog(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share on WhatsApp: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareMessageWithAttachment(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    try {
      final params = ShareParams(
        text: text,
        subject: subject,
        files:
            _hasLocalImageAttachment() ? [XFile(File(item.image).path)] : null,
      );

      await SharePlus.instance.share(params);
      if (context.mounted) {
        _showPointsDialog(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to share directly: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _copyNoticeToClipboard(BuildContext context) async {
    final notice = item.noticeDraft ?? _buildShareBody();
    await Clipboard.setData(ClipboardData(text: notice));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notice text copied to clipboard.'),
        backgroundColor: SnapColors.purple,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithNav(
      current: 'Cases',
      onHome: onHome,
      onCases: onCases,
      onSnap: onSnap,
      onMap: onMap,
      onFeed: onFeed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            12, 36, 12, 120), // Added extra padding for nav
        children: [
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onBack,
                  child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF3F0F7), shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: SnapColors.purple)),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Case #${item.id}',
                              style: const TextStyle(
                                  fontSize: 12, color: SnapColors.muted)),
                          Text(item.title,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08)),
                        ],
                      ),
                    ),
                    StatusPill(item.status),
                  ],
                ),
                const SizedBox(height: 12),
                CaseMedia(item: item, height: 142),
                if (item.status == 'Fixed' &&
                    item.beforeImage != null &&
                    item.beforeImage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Resolution Proof',
                      style: TextStyle(
                          fontSize: 12,
                          color: SnapColors.muted,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildDetailImage(item.beforeImage!,
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 4),
                            const Text('Before',
                                style: TextStyle(
                                    fontSize: 10, color: SnapColors.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildDetailImage(item.image,
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 4),
                            const Text('After',
                                style: TextStyle(
                                    fontSize: 10, color: SnapColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (item.status != 'Fixed') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCCE5FF)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty_rounded,
                            size: 18, color: Color(0xFF004085)),
                        SizedBox(width: 10),
                        Text('Awaiting Resolution Proof',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF004085))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InfoBox(label: 'Location', value: item.location),
              ],
            ),
          ),
          const SizedBox(height: 1),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          value: item.strength.clamp(0, 100) / 100,
                          strokeWidth: 8,
                          color: SnapColors.purple,
                          backgroundColor: SnapColors.line,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${item.strength}%',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1)),
                          const Text('Confidence',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: SnapColors.muted,
                                  height: 1.3)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusPill(item.severity, color: _severityColor()),
                          const SizedBox(width: 8),
                          StatusPill(item.status),
                          if (item.duplicateClusterId?.isNotEmpty == true) ...[
                            const SizedBox(width: 8),
                            const StatusPill('Clustered'),
                          ]
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(item.helper,
                          style: const TextStyle(
                              fontSize: 13,
                              color: SnapColors.muted,
                              height: 1.4)),
                      const SizedBox(height: 6),
                      Text('${item.reports} reports · ${item.updated}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: SnapColors.muted,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Analysis Summary',
                    style: TextStyle(
                        fontSize: 13,
                        color: SnapColors.purple,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildAiInsights()
                      .map((insight) => StatusPill(insight['label'] as String,
                          color: SnapColors.purple))
                      .toList(),
                ),
                const SizedBox(height: 14),
                Column(
                  children: _buildAiInsights()
                      .map((insight) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(insight['icon'] as IconData,
                                    size: 18, color: SnapColors.purple),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(insight['label'] as String,
                                      style: const TextStyle(
                                          fontSize: 14, height: 1.45)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                if (item.detail.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text('Reasoning snapshot',
                      style: TextStyle(
                          fontSize: 13,
                          color: SnapColors.purple,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    item.detail,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 1),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Action simulation',
                    style: TextStyle(
                        fontSize: 13,
                        color: SnapColors.purple,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final text in [
                  'Notice generated',
                  'Nearby users alerted',
                  'Responder suggested',
                  'Social impact card ready',
                  'Map/status updated'
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: SnapColors.purple, size: 18),
                      const SizedBox(width: 8),
                      Text(text, style: const TextStyle(fontSize: 13))
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Community Actions',
                    style: TextStyle(
                        fontSize: 13,
                        color: SnapColors.purple,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await _sendOfficialEmail(context);
                  },
                  icon: const Icon(Icons.mail_rounded, size: 20),
                  label: const Text('Official Email Report',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: SnapColors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await _shareViaWhatsApp(context);
                  },
                  icon: const Icon(Icons.message_rounded, size: 20),
                  label: const Text('Alert Friends on WhatsApp',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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

class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F7F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SnapColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: SnapColors.muted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric(
      {super.key,
      required this.label,
      required this.value,
      this.color = SnapColors.ink});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
          border: Border(
              left: BorderSide(color: SnapColors.line),
              top: BorderSide(color: SnapColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: SnapColors.muted)),
        const SizedBox(height: 6),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 17,
                color: color,
                fontWeight: FontWeight.w800,
                height: 1.08)),
      ]),
    );
  }
}
