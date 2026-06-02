import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';
import 'snapcity_theme.dart';

Widget _buildImage(String path,
    {double? height, double? width, BoxFit fit = BoxFit.cover}) {
  if (path.isEmpty) return Container(color: Colors.grey[200]);

  if (path.startsWith('http')) {
    return Image.network(path, height: height, width: width, fit: fit);
  } else if (path.startsWith('/') || path.contains(':/')) {
    // Absolute path for local file
    return Image.file(File(path), height: height, width: width, fit: fit);
  } else {
    return Image.asset(path, height: height, width: width, fit: fit);
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = 15,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SnapColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action = 'See all',
    this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: SnapColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                action,
                style: const TextStyle(
                  color: SnapColors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ??
        (label.toLowerCase().contains('fixed')
            ? SnapColors.success
            : label.toLowerCase().contains('critical') ||
                    label.toLowerCase().contains('action')
                ? SnapColors.danger
                : SnapColors.purple);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withOpacity(.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(color: tint, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class SnapBottomNav extends StatelessWidget {
  const SnapBottomNav({
    super.key,
    required this.current,
    required this.onHome,
    required this.onCases,
    required this.onSnap,
    required this.onMap,
    required this.onFeed,
  });

  final String current;
  final VoidCallback onHome;
  final VoidCallback onCases;
  final VoidCallback onSnap;
  final VoidCallback onMap;
  final VoidCallback onFeed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.96),
          border: const Border(top: BorderSide(color: SnapColors.line)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: current == 'Home',
                onTap: onHome),
            _NavItem(
                icon: Icons.cases_rounded,
                label: 'Cases',
                active: current == 'Cases',
                onTap: onCases),
            _SnapButton(onTap: onSnap),
            _NavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                active: current == 'Map',
                onTap: onMap),
            _NavItem(
                icon: Icons.shield_rounded,
                label: 'Feed',
                active: current == 'Feed',
                onTap: onFeed),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? SnapColors.purple : const Color(0xFF85818C);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SnapButton extends StatelessWidget {
  const _SnapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: SnapColors.yellow,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: SnapColors.yellow.withOpacity(.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.photo_camera_rounded,
            color: SnapColors.ink, size: 25),
      ),
    );
  }
}

class CaseMedia extends StatelessWidget {
  const CaseMedia({super.key, required this.item, this.height = 120});

  final CivicCase item;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (item.beforeImage != null && item.beforeImage!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                  child:
                      _LabeledImage(path: item.beforeImage!, label: 'Before')),
              Container(width: 1, color: Colors.white),
              Expanded(
                  child: _LabeledImage(
                      path: item.image, label: 'After', green: true)),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: _buildImage(item.image,
          height: height, width: double.infinity, fit: BoxFit.cover),
    );
  }
}

class _LabeledImage extends StatelessWidget {
  const _LabeledImage(
      {required this.path, required this.label, this.green = false});

  final String path;
  final String label;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildImage(path, fit: BoxFit.cover),
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (green ? SnapColors.success : SnapColors.ink)
                  .withOpacity(.78),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton(
      {super.key, required this.icon, required this.onTap, this.dot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: SnapColors.ink),
          ),
          if (dot)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: SnapColors.danger, shape: BoxShape.circle)),
            ),
        ],
      ),
    );
  }
}

class ActiveCaseRow extends StatelessWidget {
  const ActiveCaseRow({super.key, required this.item, required this.onTap});

  final CivicCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final danger = item.status.toLowerCase().contains('action');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _buildImage(item.image,
                  width: 52, height: 52, fit: BoxFit.cover),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusPill(item.status,
                      color: danger ? SnapColors.danger : SnapColors.purple),
                  const SizedBox(height: 4),
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: SnapColors.muted)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: item.strength.toDouble() / 100,
                          minHeight: 5,
                          color: danger ? SnapColors.danger : SnapColors.purple,
                          backgroundColor: const Color(0xFFEFEDEF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${item.strength}%',
                          style: const TextStyle(
                              fontSize: 10, color: SnapColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64, // Fixed width for button to avoid overflow
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: Color(0x3348117F)),
                ),
                child: const Text('Watch',
                    maxLines: 1,
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NearbyRow extends StatelessWidget {
  const NearbyRow(
      {super.key,
      required this.item,
      required this.label,
      required this.onTap});

  final CivicCase item;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: label.contains('Fixed')
                  ? const Color(0xFFE4F6EB)
                  : const Color(0xFFF3F0F7),
              child: Icon(
                  label.contains('Fixed')
                      ? Icons.check_rounded
                      : Icons.auto_awesome_rounded,
                  size: 17,
                  color: label.contains('Fixed')
                      ? SnapColors.success
                      : SnapColors.purple),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusPill(label),
                  const SizedBox(height: 4),
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                  Text(item.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: SnapColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImage(item.image, width: 48, height: 38),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedRow extends StatelessWidget {
  const FeedRow({super.key, required this.item, required this.onTap});

  final CivicCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(9),
      child: SizedBox(
        height: 112,
        child: Row(
          children: [
            SizedBox(
                width: 126,
                height: 112,
                child: CaseMedia(item: item, height: 112)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.06)),
                  const SizedBox(height: 4),
                  Text(item.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: SnapColors.muted,
                          height: 1.15)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: item.tags
                          .take(3)
                          .map((tag) => StatusPill(tag))
                          .toList()),
                  const SizedBox(height: 5),
                  Text(
                      '${item.reports} reports - ${item.strength}% evidence - ${item.updated}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9.5, color: SnapColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({
    super.key,
    required this.child,
    required this.current,
    required this.onHome,
    required this.onCases,
    required this.onSnap,
    required this.onMap,
    required this.onFeed,
  });

  final Widget child;
  final String current;
  final VoidCallback onHome;
  final VoidCallback onCases;
  final VoidCallback onSnap;
  final VoidCallback onMap;
  final VoidCallback onFeed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: SnapBottomNav(
            current: current,
            onHome: onHome,
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

class FilterRow extends StatelessWidget {
  const FilterRow(
      {super.key,
      required this.items,
      required this.selected,
      required this.onSelected});

  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final active = item == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text(item),
              onSelected: (_) => onSelected(item),
              selectedColor: SnapColors.purple,
              labelStyle: TextStyle(
                  color: active ? Colors.white : SnapColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                  side: BorderSide(
                      color: active ? Colors.transparent : SnapColors.line)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

String getDistanceText(Position? userPosition, double? lat, double? lng) {
  if (userPosition == null || lat == null || lng == null) {
    return "Distance unavailable";
  }
  final meters = Geolocator.distanceBetween(
    userPosition.latitude,
    userPosition.longitude,
    lat,
    lng,
  );
  if (meters < 1000) {
    return "${meters.toStringAsFixed(0)}m away from your location";
  } else {
    final km = meters / 1000;
    return "${km.toStringAsFixed(1)}km away from your location";
  }
}

String formatRelativeTime(String? timestampStr) {
  if (timestampStr == null || timestampStr.isEmpty) {
    return "Reported recently";
  }
  try {
    final parsed = DateTime.parse(timestampStr);
    final diff = DateTime.now().difference(parsed);
    if (diff.inDays > 0) {
      return "Reported ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
    } else if (diff.inHours > 0) {
      return "Reported ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
    } else if (diff.inMinutes > 0) {
      return "Reported ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago";
    } else {
      return "Reported just now";
    }
  } catch (e) {
    return "Reported recently";
  }
}

String getConfirmationsText(int reports) {
  if (reports <= 0) return "No confirmations yet";
  if (reports == 1) return "1 confirmation received";
  return "$reports confirmations received";
}

