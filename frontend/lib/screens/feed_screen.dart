import 'package:flutter/material.dart';
import '../models.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';
import '../mock_data.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.notifications,
    required this.onHome,
    required this.onCases,
    required this.onMap,
    required this.onSnap,
    required this.onCase,
  });

  final List<String> notifications;
  final VoidCallback onHome;
  final VoidCallback onCases;
  final VoidCallback onMap;
  final VoidCallback onSnap;
  final ValueChanged<CivicCase> onCase;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final cases = feedCases.where((item) {
      if (filter == 'Fixed') return item.status == 'Fixed';
      if (filter == 'Before / After') {
        return item.beforeImage != null && item.beforeImage!.isNotEmpty;
      }
      if (filter == 'Partners') {
        return item.tags.contains('Community partner') ||
            item.helper.toLowerCase().contains('partner');
      }
      return true;
    }).toList();

    return ScaffoldWithNav(
      current: 'Feed',
      onHome: widget.onHome,
      onCases: widget.onCases,
      onSnap: widget.onSnap,
      onMap: widget.onMap,
      onFeed: () {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 46, 12, 92),
        children: [
          const Text('Community activity',
              style: TextStyle(fontSize: 12, color: SnapColors.muted)),
          const Text('Feed',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Proof that reports are turning into action.',
              style: TextStyle(fontSize: 12, color: SnapColors.muted)),
          const SizedBox(height: 14),
          if (widget.notifications.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                    'No reports nearby yet.\nBe the first to snap an issue!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: SnapColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            const Text('System Alerts',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: SnapColors.purple)),
            const SizedBox(height: 8),
            ...widget.notifications.take(3).map((note) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFBF9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1A48117F))),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: SnapColors.purple),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(note,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
            const Divider(height: 24),
          ],
          FilterRow(
              items: const ['All', 'Fixed', 'Before / After', 'Partners'],
              selected: filter,
              onSelected: (value) => setState(() => filter = value)),
          const SizedBox(height: 10),
          ...cases.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FeedRow(item: item, onTap: () => widget.onCase(item)),
              )),
        ],
      ),
    );
  }
}
