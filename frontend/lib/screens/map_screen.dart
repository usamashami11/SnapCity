import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';
import '../services/api_service.dart';

Widget _buildMapImage(String path,
    {double? height, double? width, BoxFit fit = BoxFit.cover}) {
  if (path.isEmpty) return Container(color: Colors.grey[200]);
  if (path.startsWith('http')) {
    return Image.network(
      path,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  } else if (path.startsWith('/') || path.contains(':/')) {
    return Image.file(File(path), height: height, width: width, fit: fit);
  } else {
    return Image.asset(path, height: height, width: width, fit: fit);
  }
}

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
  List<CivicCase> _cases = [];
  CivicCase? selectedCase;
  bool routed = false;
  bool _isLoading = true;
  String? _error;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadGlobalCases();
  }

  Future<void> _loadGlobalCases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final responses = await ApiService().fetchGlobalCases();
      if (!mounted) return;

      final parsedCases = responses
          .where((resp) => resp.lat != null && resp.lng != null)
          .map((resp) => CivicCase(
                id: resp.caseId,
                title: resp.issueType.replaceAll('_', ' ').toUpperCase(),
                location: resp.locationName?.isNotEmpty == true
                    ? resp.locationName!
                    : resp.area,
                status: resp.severity.toLowerCase() == 'high' ? 'Critical' : 'Needs proof',
                severity: resp.severity,
                reports: resp.similarReports + 1,
                strength: resp.confidence,
                updated: 'Recently',
                action: 'Ready',
                image: resp.imageUrl,
                detail: resp.escalationReason,
                helper: resp.assignedResponder,
                lat: resp.lat,
                lng: resp.lng,
                duplicateClusterId: resp.duplicateClusterId,
                similarReportsNearby: resp.similarReports,
                rewardMessage: resp.rewardMessage,
                noticeDraft: resp.noticeDraft,
                authorityName: resp.authority['name'] as String? ?? 'SSWMB',
                authorityEmail: resp.authority['email'] as String? ?? '',
                authorityWhatsapp: resp.authority['whatsapp'] as String? ?? '',
                weather: resp.weather,
                traffic: resp.traffic,
              ))
          .toList();

      setState(() {
        _cases = parsedCases;
        if (_cases.isNotEmpty) {
          selectedCase = _cases.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  LatLng get _center {
    if (widget.currentPosition != null) {
      return LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    }
    return const LatLng(24.9180, 67.0971); // Default to Karachi centroid
  }

  String _getDistanceText(CivicCase item) {
    if (widget.currentPosition == null || item.lat == null || item.lng == null) {
      return 'Calculating distance...';
    }
    final meters = Geolocator.distanceBetween(
      widget.currentPosition!.latitude,
      widget.currentPosition!.longitude,
      item.lat!,
      item.lng!,
    );
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m away';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  String _getConfirmationsText(CivicCase item) {
    if (item.reports <= 1) {
      return 'Reported by 1 citizen';
    }
    return 'Reported by ${item.reports} citizens';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _cases.where((item) {
      if (filter == 'Critical') return item.severity.toLowerCase() == 'high';
      if (filter == 'Fixed') return item.status == 'Fixed';
      if (filter == 'My area') {
        if (widget.currentPosition == null || item.lat == null || item.lng == null) return true;
        final dist = Geolocator.distanceBetween(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
          item.lat!,
          item.lng!,
        );
        return dist <= 1000; // Within 1 km radius
      }
      return item.severity.toLowerCase() != 'high' && item.status != 'Fixed'; // Needs proof
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
                      final point = LatLng(item.lat!, item.lng!);

                      return Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            selectedCase = item;
                            routed = false;
                          }),
                          child: MapPin(
                            item: item,
                            selected: selectedCase?.id == item.id,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                if (routed && selectedCase != null && selectedCase!.lat != null && selectedCase!.lng != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          _center,
                          LatLng(selectedCase!.lat!, selectedCase!.lng!),
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
                  RoundIconButton(icon: Icons.refresh_rounded, onTap: _loadGlobalCases),
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
                final filtered = _cases.where((item) {
                  if (value == 'Critical') return item.severity.toLowerCase() == 'high';
                  if (value == 'Fixed') return item.status == 'Fixed';
                  if (value == 'My area') {
                    if (widget.currentPosition == null || item.lat == null || item.lng == null) return true;
                    final dist = Geolocator.distanceBetween(
                      widget.currentPosition!.latitude,
                      widget.currentPosition!.longitude,
                      item.lat!,
                      item.lng!,
                    );
                    return dist <= 1000;
                  }
                  return item.severity.toLowerCase() != 'high' && item.status != 'Fixed';
                }).toList();
                
                final next = filtered.isNotEmpty ? filtered.first : (_cases.isNotEmpty ? _cases.first : null);
                setState(() {
                  filter = value;
                  if (next != null) {
                    selectedCase = next;
                    routed = false;
                    _mapController.move(LatLng(next.lat!, next.lng!), 15.0);
                  }
                });
              },
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: 86,
            child: _isLoading
                ? const AppCard(
                    radius: 20,
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: SnapColors.purple),
                    ),
                  )
                : _error != null
                    ? AppCard(
                        radius: 20,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Error loading map data:\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontFamily: 'monospace'),
                          ),
                        ),
                      )
                    : selectedCase == null
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
                                      child: SizedBox(
                                        width: 76,
                                        height: 76,
                                        child: _buildMapImage(selectedCase!.image),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: Text(selectedCase!.title,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w800,
                                                          height: 1.08))),
                                              StatusPill(selectedCase!.status),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                              routed
                                                  ? 'Route ready - walk path set'
                                                  : _getDistanceText(selectedCase!),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: SnapColors.muted,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 5),
                                          Text(_getConfirmationsText(selectedCase!),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800)),
                                          Text(
                                              'Authority: ${selectedCase!.authorityName ?? "SSWMB"}',
                                              style: const TextStyle(
                                                  fontSize: 9.5,
                                                  color: SnapColors.purple,
                                                  fontWeight: FontWeight.bold)),
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
                                        onPressed: () => widget.onCase(selectedCase!),
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
  const MapPin({super.key, required this.item, required this.selected});

  final CivicCase item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = item.status == 'Fixed'
        ? SnapColors.success
        : item.severity.toLowerCase() == 'high'
            ? SnapColors.danger
            : item.severity.toLowerCase() == 'medium'
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
                item.status == 'Fixed'
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
