import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    this.currentArea = 'your area',
    required this.notificationCount,
    this.fixedIssuesCount = 5,
    this.neighborCount = 128,
    this.impactScore = '4,250',
    this.localRank = 'Top 8%',
    this.verifiedCount = '23',
    this.fixedNearbyCount = '5',
    required this.onFeed,
    required this.onMap,
    required this.onCases,
    required this.onSnap,
    required this.onCase,
    this.nearestCase,
    this.currentPosition,
    required this.onGoConfirm,
    required this.activeCases,
    required this.recentFixes,
  });

  final String userName;
  final String currentArea;
  final int notificationCount;
  final int fixedIssuesCount;
  final int neighborCount;
  final String impactScore;
  final String localRank;
  final String verifiedCount;
  final String fixedNearbyCount;
  final VoidCallback onFeed;
  final VoidCallback onMap;
  final VoidCallback onCases;
  final VoidCallback onSnap;
  final ValueChanged<CivicCase> onCase;
  final CivicCase? nearestCase;
  final Position? currentPosition;
  final ValueChanged<CivicCase> onGoConfirm;
  final List<CivicCase> activeCases;
  final List<CivicCase> recentFixes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 330,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF30035C),
                  SnapColors.purple,
                  SnapColors.purple.withOpacity(.45),
                  SnapColors.bg.withOpacity(0),
                ],
                stops: const [0, .36, .66, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hey $userName',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              'Making $currentArea\nbetter',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  height: 1.02),
                            ),
                          ],
                        ),
                      ),
                      RoundIconButton(
                          icon: Icons.notification_important_outlined,
                          onTap: onFeed,
                          dot: notificationCount > 0),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: onFeed,
                    child: Container(
                      height: 168,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Transform.rotate(
                              angle: 3.14159,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'assets/Garbage 2.jpeg',
                                  fit: BoxFit.cover,
                                  color: const Color(0xAA10091E),
                                  colorBlendMode: BlendMode.darken,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24.0,
                            right: 20.0,
                            top: 20.0,
                            bottom: 16.0,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const StatusPill('This week',
                                          color: SnapColors.yellow),
                                      const SizedBox(height: 8),
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              height: 1.02),
                                          children: [
                                            TextSpan(
                                                text: '$fixedIssuesCount',
                                                style: const TextStyle(
                                                    color: SnapColors.yellow)),
                                            const TextSpan(
                                                text: ' issues fixed\nnear you'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Thanks to $neighborCount neighbors who spoke up.',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.25),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.chevron_right_rounded,
                                      color: SnapColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImpactStrip(
                    impactScore: impactScore,
                    localRank: localRank,
                    verifiedCount: verifiedCount,
                    fixedNearbyCount: fixedNearbyCount,
                    currentArea: currentArea,
                  ),
                  const SizedBox(height: 8),
                  TaskCta(
                    onTap: () {
                      if (nearestCase != null) {
                        onGoConfirm(nearestCase!);
                      } else if (activeCases.isNotEmpty) {
                        onGoConfirm(activeCases.first);
                      } else {
                        onMap();
                      }
                    },
                    location: currentArea,
                    distance: 'Near you',
                  ),
                  const SizedBox(height: 10),
                  SectionHeader(title: 'Your Active Cases', onAction: onCases),
                  if (activeCases.isEmpty)
                    const AppCard(
                      padding:
                          EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      child: Center(
                        child: Text(
                          'No active infrastructure issues reported\nin your immediate area.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: SnapColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          ...activeCases.take(2).map((item) {
                            final isLast = item == activeCases.take(2).last;
                            return Column(
                              children: [
                                ActiveCaseRow(
                                    item: item, onTap: () => onCase(item)),
                                if (!isLast)
                                  const Divider(
                                      height: 1, color: SnapColors.line),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  SectionHeader(
                      title: "What's happening nearby", onAction: onMap),
                  if (activeCases.isEmpty && recentFixes.isEmpty)
                    const AppCard(
                      padding:
                          EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      child: Center(
                        child: Text(
                          'All clear! Your neighbors haven\'t\nreported any issues yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: SnapColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          if (activeCases.isNotEmpty)
                            NearbyRow(
                                item: activeCases[0],
                                label: activeCases[0].status == 'Critical' ? 'Critical' : 'Verified',
                                onTap: () => onCase(activeCases[0])),
                          if (recentFixes.isNotEmpty) ...[
                            const Divider(height: 1, color: SnapColors.line),
                            NearbyRow(
                                item: recentFixes[0],
                                label: 'Fixed',
                                onTap: () => onCase(recentFixes[0])),
                          ],
                          if (activeCases.length > 1) ...[
                            const Divider(height: 1, color: SnapColors.line),
                            NearbyRow(
                                item: activeCases[1],
                                label: activeCases[1].status == 'Critical' ? 'Critical' : 'Action needed',
                                onTap: () => onCase(activeCases[1])),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  SectionHeader(title: 'Recently Fixed', onAction: onFeed),
                  if (recentFixes.isEmpty)
                    const AppCard(
                      padding:
                          EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      child: Center(
                        child: Text(
                          'No recent fixes reported.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: SnapColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    ...recentFixes.take(2).map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FeedRow(item: item, onTap: () => onCase(item)),
                        )),
                ],
              ),
            ),
          ),
        ),
        if (nearestCase != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 86,
            child: AppCard(
              radius: 16,
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: nearestCase!.image.startsWith('http')
                          ? Image.network(nearestCase!.image, fit: BoxFit.cover)
                          : nearestCase!.image.startsWith('/') || nearestCase!.image.contains(':/')
                              ? Image.file(File(nearestCase!.image), fit: BoxFit.cover)
                              : Image.asset(nearestCase!.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusPill(
                              nearestCase!.severity.toLowerCase() == 'high' ? 'Critical' : 'Nearest Hazard',
                              color: nearestCase!.severity.toLowerCase() == 'high' ? SnapColors.danger : SnapColors.purple,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                nearestCase!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          getDistanceText(currentPosition, nearestCase!.lat, nearestCase!.lng),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: SnapColors.muted, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          getConfirmationsText(nearestCase!.reports),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => onGoConfirm(nearestCase!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SnapColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Confirm', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 4),
                      OutlinedButton(
                        onPressed: () => onCase(nearestCase!),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SnapBottomNav(
            current: 'Home',
            onHome: () {},
            onCases: onCases,
            onSnap: onSnap,
            onMap: onMap,
            onFeed: onFeed,
          ),
        ),
      ],
    );
  }
}

class ImpactStrip extends StatelessWidget {
  const ImpactStrip({
    super.key,
    required this.impactScore,
    required this.localRank,
    required this.verifiedCount,
    required this.fixedNearbyCount,
    required this.currentArea,
  });

  final String impactScore;
  final String localRank;
  final String verifiedCount;
  final String fixedNearbyCount;
  final String currentArea;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 9, 12, 2),
            child: Text('Your Civic Impact',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          Row(
            children: [
              ImpactCell(
                  icon: Icons.auto_awesome_rounded,
                  value: impactScore,
                  label: 'Impact score',
                  note: '+320 this week'),
              ImpactCell(
                  icon: Icons.emoji_events_rounded,
                  value: localRank,
                  label: 'Local rank',
                  note: 'In $currentArea'),
              ImpactCell(
                  icon: Icons.check_circle_rounded,
                  value: verifiedCount,
                  label: 'Verified',
                  note: 'This week'),
              ImpactCell(
                  icon: Icons.location_on_rounded,
                  value: fixedNearbyCount,
                  label: 'Fixed nearby',
                  note: 'Within 1 km'),
            ],
          ),
        ],
      ),
    );
  }
}

class ImpactCell extends StatelessWidget {
  const ImpactCell(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      required this.note});

  final IconData icon;
  final String value;
  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: SnapColors.line))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: SnapColors.purple),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w700)),
            Text(note,
                maxLines: 1,
                style: const TextStyle(fontSize: 8.5, color: SnapColors.muted)),
          ],
        ),
      ),
    );
  }
}

class TaskCta extends StatelessWidget {
  const TaskCta({
    super.key,
    required this.onTap,
    required this.location,
    required this.distance,
  });

  final VoidCallback onTap;
  final String location;
  final String distance;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: SnapColors.yellow, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.assignment_turned_in_outlined, size: 19),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Confirm nearby issue',
                      maxLines: 1,
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('$location - $distance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xB317151C))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                  color: SnapColors.purple,
                  borderRadius: BorderRadius.circular(999)),
              child: const Text('Confirm now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
