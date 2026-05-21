import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';
import '../mock_data.dart';

class CivicMapScreen extends StatefulWidget {
  const CivicMapScreen({
    super.key,
    this.currentPosition,
    required this.onHome,
    required this.onCases,
    required this.onFeed,
    required this.onSnap,
    required this.onCase,
  });

  final Position? currentPosition;
  final VoidCallback onHome;
  final VoidCallback onCases;
  final VoidCallback onFeed;
  final VoidCallback onSnap;
  final ValueChanged<CivicCase> onCase;

  @override
  State<CivicMapScreen> createState() => _CivicMapScreenState();
}

class _CivicMapScreenState extends State<CivicMapScreen> {
  String filter = 'Needs proof';
  late MapIssue selectedIssue;
  bool routed = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (mapIssues.isNotEmpty) {
      selectedIssue = mapIssues.first;
    }
  }

  LatLng get _center {
    if (widget.currentPosition != null) {
      return LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    }
    return const LatLng(17.3850, 78.4867); // Default to Hyderabad, India
  }

  @override
  Widget build(BuildContext context) {
    final visible = mapIssues.where((item) {
      if (filter == 'Needs proof') return item.status == 'Needs proof';
      if (filter == 'Critical') return item.status == 'Critical';
      if (filter == 'Fixed') return item.status == 'Fixed';
      return true;
    }).toList();

    return ScaffoldWithNav(
      current: 'Map',
      onHome: widget.onHome,
      onCases: widget.onCases,
      onSnap: widget.onSnap,
      onMap: () {},
      onFeed: widget.onFeed,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.snapcity',
                ),
                MarkerLayer(
                  markers: [
                    if (widget.currentPosition != null)
                      Marker(
                        point: _center,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: SnapColors.purple.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: SnapColors.purple, width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.person_pin_circle,
                                color: SnapColors.purple, size: 24),
                          ),
                        ),
                      ),
                    ...visible.map((item) {
                      // Map mockup coordinates (x, y) to relative lat/lng for Gulshan
                      // This is a placeholder mapping since mock data uses screen coordinates
                      final lat = 24.9180 + (0.5 - item.y) * 0.01;
                      final lng = 67.0971 + (item.x - 0.5) * 0.01;
                      final point = LatLng(lat, lng);

                      return Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            selectedIssue = item;
                            routed = false;
                          }),
                          child: MapPin(
                            issue: item,
                            selected: selectedIssue.caseId == item.caseId,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                if (routed)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          _center,
                          LatLng(24.9180 + (0.5 - selectedIssue.y) * 0.01,
                              67.0971 + (selectedIssue.x - 0.5) * 0.01),
                        ],
                        color: SnapColors.purple,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Map',
                            style: TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800)),
                        Text(
                            '${widget.currentPosition != null ? 'Live' : 'Global'} civic layer',
                            style: const TextStyle(
                                fontSize: 12, color: SnapColors.muted)),
                      ],
                    ),
                  ),
                  RoundIconButton(icon: Icons.search_rounded, onTap: () {}),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 0,
            top: 132,
            child: FilterRow(
              items: const ['Needs proof', 'Critical', 'Fixed', 'My area'],
              selected: filter,
              onSelected: (value) {
                final next = mapIssues.firstWhere(
                  (item) => value == 'My area' || item.status == value,
                  orElse: () => mapIssues.first,
                );
                setState(() {
                  filter = value;
                  selectedIssue = next;
                  routed = false;
                });
                // Center map on issue
                final lat = 24.9180 + (0.5 - next.y) * 0.01;
                final lng = 67.0971 + (next.x - 0.5) * 0.01;
                _mapController.move(LatLng(lat, lng), 15.0);
              },
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 86,
            child: mapIssues.isEmpty
                ? const AppCard(
                    radius: 20,
                    padding: EdgeInsets.all(24),
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
                : AppCard(
                    radius: 20,
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      children: [
                        Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(999))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(selectedIssue.image,
                                  width: 76, height: 76, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(selectedIssue.title,
                                              maxLines: 2,
                                              style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.08))),
                                      StatusPill(selectedIssue.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      routed
                                          ? 'Route ready - 7 min walk'
                                          : selectedIssue.distance,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: SnapColors.muted,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 5),
                                  Text(selectedIssue.confirmations,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                      routed
                                          ? 'Open camera when you reach it.'
                                          : 'Fresh proof can strengthen this case.',
                                      style: const TextStyle(
                                          fontSize: 9.5,
                                          color: SnapColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 13,
                              child: FilledButton(
                                onPressed: routed
                                    ? widget.onSnap
                                    : () => setState(() => routed = true),
                                style: FilledButton.styleFrom(
                                    backgroundColor: SnapColors.purple,
                                    minimumSize: const Size.fromHeight(40)),
                                child: Text(
                                    routed ? 'Open camera' : 'Go confirm',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 10,
                              child: OutlinedButton(
                                onPressed: () => widget
                                    .onCase(caseById(selectedIssue.caseId)!),
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(40)),
                                child: const Text('View case',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.issue, required this.selected});

  final MapIssue issue;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = issue.status == 'Fixed'
        ? SnapColors.success
        : issue.status == 'Critical'
            ? SnapColors.danger
            : issue.status == 'Needs proof' && issue.severity == 'Medium'
                ? SnapColors.yellow
                : SnapColors.purple;
    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      scale: selected ? 1.15 : 1,
      child: Transform.rotate(
        angle: -.78,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white, width: 4),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
            ),
          ),
          child: Transform.rotate(
            angle: .78,
            child: Icon(
                issue.status == 'Fixed'
                    ? Icons.check_rounded
                    : Icons.shield_rounded,
                color: Colors.white,
                size: 16),
          ),
        ),
      ),
    );
  }
}
