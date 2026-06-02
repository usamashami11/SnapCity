import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geocoding/geocoding.dart';
import '../backend_contract.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';

Widget _buildTicketImage(String path,
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

class TicketScreen extends StatefulWidget {
  const TicketScreen({
    super.key,
    required this.imagePath,
    required this.onClose,
    required this.onSubmit,
    required this.lat,
    required this.lng,
    required this.response,
  });

  final String imagePath;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final double lat;
  final double lng;
  final AgentReportResponse response;

  @override
  State<TicketScreen> createState() => _TicketScreenStateV2();
}

class _TicketScreenStateV2 extends State<TicketScreen> {
  bool voiceAdded = false;
  bool showImagePreview = false;
  double sheetOffset = 0;
  String? _voicePath;
  final _recorder = AudioRecorder();
  String _currentArea = 'Detecting location...';

  @override
  void initState() {
    super.initState();
    _reverseGeocode();
  }

  Future<void> _reverseGeocode() async {
    try {
      final placemarks = await placemarkFromCoordinates(widget.lat, widget.lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentArea = place.subLocality ?? place.locality ?? 'Your Area';
        });
      }
    } catch (e) {
      setState(() => _currentArea =
          widget.response.area.isNotEmpty ? widget.response.area : 'Your Area');
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleVoice() async {
    if (voiceAdded) {
      setState(() {
        voiceAdded = false;
        _voicePath = null;
      });
      return;
    }

    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(const RecordConfig(), path: path);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF10091E),
            title: const Text('Recording Voice Note...',
                style: TextStyle(color: Colors.white)),
            content: const Text('Describe the issue in detail.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () async {
                  final voiceFile = await _recorder.stop();
                  if (mounted) {
                    setState(() {
                      voiceAdded = true;
                      _voicePath = voiceFile;
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Stop & Save',
                    style: TextStyle(
                        color: SnapColors.purple, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: widget.imagePath.startsWith('assets/')
              ? Image.asset(widget.imagePath, fit: BoxFit.cover)
              : Image.file(File(widget.imagePath), fit: BoxFit.cover),
        ),
        Positioned.fill(
            child: ColoredBox(color: Colors.black.withOpacity(.28))),
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() =>
                  sheetOffset = (sheetOffset + details.delta.dy).clamp(0, 260));
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 350 || sheetOffset > 90) {
                widget.onClose();
                return;
              }
              setState(() => sheetOffset = 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              transform: Matrix4.translationValues(0, sheetOffset, 0),
              margin: const EdgeInsets.fromLTRB(12, 80, 12, 0),
              child: ClipPath(
                clipper: const TicketSheetClipper(),
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                      child: TicketContentV2(
                        imagePath: widget.imagePath,
                        voiceAdded: voiceAdded,
                        onVoice: _handleVoice,
                        onImage: () => setState(() => showImagePreview = true),
                        onSubmit: widget.onSubmit,
                        response: widget.response,
                        areaName: _currentArea,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showImagePreview)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => showImagePreview = false),
              child: Container(
                color: Colors.black.withOpacity(.76),
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.imagePath.startsWith('assets/')
                        ? Image.asset(widget.imagePath, fit: BoxFit.cover)
                        : Image.file(File(widget.imagePath), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TicketContentV2 extends StatelessWidget {
  const TicketContentV2({
    super.key,
    required this.imagePath,
    required this.voiceAdded,
    required this.onVoice,
    required this.onImage,
    required this.onSubmit,
    required this.response,
    required this.areaName,
  });

  final String imagePath;
  final bool voiceAdded;
  final VoidCallback onVoice;
  final VoidCallback onImage;
  final VoidCallback onSubmit;
  final AgentReportResponse response;
  final String areaName;

  @override
  Widget build(BuildContext context) {
    final severityType = response.severity.toLowerCase();
    final actionDirective = severityType == 'high' ? 'Escalated' : 'Ready';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
            child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999)))),
        GestureDetector(
          onTap: onImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: _buildTicketImage(imagePath, fit: BoxFit.cover),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.92),
                        borderRadius: BorderRadius.circular(999)),
                    child: const Text('Captured image',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Positioned(
                    right: 10,
                    top: 10,
                    child: Icon(Icons.open_in_full_rounded,
                        color: Colors.white, size: 16)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Swarm Orchestrated',
                      style: TextStyle(
                          fontSize: 12,
                          color: SnapColors.muted,
                          fontWeight: FontWeight.w600)),
                  Text(response.issueType.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.05)),
                  const SizedBox(height: 4),
                  Text('Location: $areaName',
                      style: const TextStyle(
                          fontSize: 12, color: SnapColors.muted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SnapColors.success.withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                "Verified",
                style: TextStyle(
                  color: SnapColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        Row(
          children: [
            const TicketTopCell(
                label: 'Status', value: 'Verified', color: SnapColors.success),
            TicketTopCell(
                label: 'Cluster', value: '${response.similarReports} reports'),
            TicketTopCell(
                label: 'Action',
                value: actionDirective,
                color: severityType == 'high'
                    ? SnapColors.danger
                    : SnapColors.success),
          ],
        ),
        const SizedBox(height: 12),
        TicketField(
            icon: Icons.auto_awesome_rounded,
            label: 'Confidence',
            value: "${response.confidence}% Confidence"),
        TicketField(
            icon: Icons.cases_outlined,
            label: 'Similar reports',
            value: "${response.similarReports} reports nearby"),
        TicketField(
            icon: Icons.shield_outlined,
            label: 'Case strength',
            value: "Strength: ${response.confidence}%"),
        TicketField(
            icon: Icons.warning_amber_rounded,
            label: 'Risk Profile',
            value: response.escalationReason,
            danger: true),
        TicketField(
            icon: Icons.engineering_outlined,
            label: 'Responsible Group',
            value: response.assignedResponder),
        const SizedBox(height: 12),
        const Divider(height: 16),
        Row(
          children: [
            const Expanded(
                child: Text('Optional note',
                    style: TextStyle(
                        fontSize: 12,
                        color: SnapColors.muted,
                        fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: onVoice,
              icon: const Icon(Icons.mic_none_rounded, size: 15),
              label: Text(voiceAdded ? 'Voice added' : 'Voice note'),
              style: TextButton.styleFrom(
                foregroundColor: voiceAdded ? Colors.white : SnapColors.purple,
                backgroundColor:
                    voiceAdded ? SnapColors.purple : const Color(0xFFF3F0F7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
        TextField(
          minLines: 1,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Anything else we should know?',
            hintStyle: const TextStyle(fontSize: 12, color: SnapColors.muted),
            filled: true,
            fillColor: const Color(0xFFF8F7F8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SnapColors.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SnapColors.line)),
          ),
        ),
        if (voiceAdded)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: const Color(0xFFFBF9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1A48117F))),
            child: const Text(
                'Voice note attached\n"Recording saved and will be uploaded with your report."',
                style: TextStyle(fontSize: 12, height: 1.35)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
              backgroundColor: SnapColors.purple,
              minimumSize: const Size.fromHeight(50)),
          child: const Text('Submit Report',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class TicketSheetClipper extends CustomClipper<Path> {
  const TicketSheetClipper();

  @override
  Path getClip(Size size) {
    const radius = 20.0;
    const notch = 12.0;
    const notchY = 154.0;
    final path = Path()
      ..moveTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, notchY - notch)
      ..arcToPoint(Offset(size.width, notchY + notch),
          radius: const Radius.circular(notch), clockwise: false)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, notchY + notch)
      ..arcToPoint(const Offset(0, notchY - notch),
          radius: const Radius.circular(notch), clockwise: false)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketSheetClipper oldClipper) => false;
}

class TicketTopCell extends StatelessWidget {
  const TicketTopCell(
      {super.key,
      required this.label,
      required this.value,
      this.color = SnapColors.ink});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
            color: Color(0xFFF4F3F5),
            border: Border(left: BorderSide(color: SnapColors.line))),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: SnapColors.muted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class TicketField extends StatelessWidget {
  const TicketField(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.danger = false});

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: const Color(0xFFF3F0F7),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: SnapColors.purple),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 11,
                        color: SnapColors.muted,
                        fontWeight: FontWeight.w600)),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: danger ? FontWeight.bold : FontWeight.w800,
                        color: danger ? SnapColors.danger : SnapColors.ink,
                        height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
