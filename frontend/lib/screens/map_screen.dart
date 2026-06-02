import 'dart:async';
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
    this.targetFocusCase,
    required this.selectActiveCase,
    this.initialRouted = false,
    required this.allGlobalCases,
  });

  final Position? currentPosition;
  final VoidCallback onHome;
  final VoidCallback onCases;
  final VoidCallback onFeed;
  final VoidCallback onSnap;
  final ValueChanged<CivicCase> onCase;
  final CivicCase? targetFocusCase;
  final void Function(CivicCase, {bool changeTab}) selectActiveCase;
  final bool initialRouted;
  final List<CivicCase> allGlobalCases;

  @override
  State<CivicMapScreen> createState() => _CivicMapScreenState();
}

class _CivicMapScreenState extends State<CivicMapScreen> {
  String filter = 'Needs proof';
  List<CivicCase> _cases = [];
  CivicCase? selectedCase;
  bool isRoutingActive = false;
  Set<Polyline> mapPolylines = {};
  bool _isLoading = true;
  String? _error;
  final MapController _mapController = MapController();

  // Location tracking state
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _livePosition;
  double? _remainingDistance;

  // Geofence and verification state
  bool _geofenceDialogShown = false;
  bool _geofenceReached = false;

  bool get isWithin15Meters {
    if (_remainingDistance == null) return false;
    return _remainingDistance! <= 15.0;
  }

  @override
  void initState() {
    super.initState();
    _cases = widget.allGlobalCases;
    selectedCase = widget.targetFocusCase;
    isRoutingActive = widget.initialRouted;

    if (isRoutingActive && selectedCase != null) {
      filter = selectedCase!.severity.toLowerCase() == 'high'
          ? 'Critical'
          : 'Needs proof';
      _startLiveTracking(selectedCase!);
    }

    _loadGlobalCases();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _verifyCase(CivicCase caseToVerify) async {
    try {
      print('📤 Calling verify endpoint for case: ${caseToVerify.id}');
      final response = await ApiService().verifyCase(caseToVerify.id);

      if (response.statusCode == 200) {
        print('✅ Verification successful');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Record updated!'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF6C5CE7),
            ),
          );
          _loadGlobalCases(); // Refresh to show incremented count
        }
      } else {
        print('⚠️ Verification returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Verification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification failed. Please try again.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showGeofenceDialog(CivicCase targetCase) {
    if (_geofenceDialogShown) return;
    _geofenceDialogShown = true;

    print('🎯 Showing geofence arrival dialog for case: ${targetCase.id}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Destination Reached'),
        content: const Text('Have you encountered that issue too?'),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ User clicked No on geofence dialog');
              Navigator.of(context).pop();
              _geofenceDialogShown = false;
            },
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              print('✅ User clicked Yes on geofence dialog - verifying case');
              Navigator.of(context).pop();
              _geofenceDialogShown = false;
              _verifyCase(targetCase);
              setState(() {
                _geofenceReached = true;
              });
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _startLiveTracking(CivicCase target) {
    if (target.lat == null || target.lng == null) {
      print('⚠️ Cannot start tracking: target has no coordinates');
      return;
    }

    print('🚀 Starting live tracking for case: ${target.id}');
    print('   Target: ${target.lat}, ${target.lng}');

    setState(() {
      isRoutingActive = true;
      mapPolylines.clear();
      _remainingDistance = null;
      _geofenceDialogShown = false;
      _geofenceReached = false;
    });

    _positionStreamSubscription?.cancel();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (!mounted) return;

        final dist = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          target.lat!,
          target.lng!,
        );

        print(
            '📍 Location update: ${position.latitude}, ${position.longitude} | Distance: ${dist.toStringAsFixed(1)}m');

        setState(() {
          _livePosition = position;
          _remainingDistance = dist;
        });

        // Update polyline while user is navigating
        if (dist > 15.0) {
          setState(() {
            mapPolylines = {
              Polyline(
                points: [
                  LatLng(position.latitude, position.longitude),
                  LatLng(target.lat!, target.lng!),
                ],
                color: Colors.indigo,
                strokeWidth: 4.5,
              )
            };
          });
          print(
              '   📍 Drawing polyline, distance: ${(dist / 1000).toStringAsFixed(2)} km');
        } else {
          // User has reached the geofence (15 meters or less)
          print('🎯 GEOFENCE REACHED! Distance: ${dist.toStringAsFixed(1)}m');

          _positionStreamSubscription?.cancel();
          _positionStreamSubscription = null;

          setState(() {
            mapPolylines.clear();
            isRoutingActive = false;
          });

          // Show geofence arrival dialog
          _showGeofenceDialog(target);
        }

        _mapController.move(
            LatLng(position.latitude, position.longitude), 16.0);
      },
      onError: (err) {
        print('❌ Location stream error: $err');
        if (mounted) {
          setState(() {
            isRoutingActive = false;
          });
        }
      },
    );
  }

  Future<void> _loadGlobalCases() async {
    print('📡 Loading global cases...');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await ApiService().fetchGlobalCases();
      print('✅ Fetched ${responses.length} cases');

      if (!mounted) return;

      final parsedCases = responses
          .where((resp) => resp.lat != null && resp.lng != null)
          .map((resp) => CivicCase(
                id: resp.caseId,
                title: resp.issueType.replaceAll('_', ' ').toUpperCase(),
                location: resp.locationName?.isNotEmpty == true
                    ? resp.locationName!
                    : resp.area,
                status: resp.severity.toLowerCase() == 'high'
                    ? 'Critical'
                    : 'Needs proof',
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
      });

      // DIRECT TAB FALLBACK: If targetFocusCase is null, find nearest case
      CivicCase? activeCase = widget.targetFocusCase;
      if (activeCase == null && _cases.isNotEmpty) {
        print(
            '🔄 Direct Tab Fallback: targetFocusCase is null, finding nearest case...');

        Position? userPos = widget.currentPosition ?? _livePosition;
        if (userPos == null) {
          try {
            print('   📍 Getting current position...');
            userPos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (e) {
            print('   ⚠️ Could not get current position: $e');
          }
        }

        if (userPos != null) {
          CivicCase? closest;
          double minDistance = double.infinity;

          for (final c in _cases) {
            if (c.lat == null || c.lng == null) continue;

            final dist = Geolocator.distanceBetween(
              userPos.latitude,
              userPos.longitude,
              c.lat!,
              c.lng!,
            );

            if (dist < minDistance) {
              minDistance = dist;
              closest = c;
            }
          }

          if (closest != null) {
            print(
                '   ✅ Found nearest case: ${closest.title} (${(minDistance / 1000).toStringAsFixed(2)} km away)');
            activeCase = closest;
          }
        } else {
          print('   📋 No user position, using first case');
          activeCase = _cases.first;
        }

        if (activeCase != null) {
          print('   🎯 Setting active case via selectActiveCase');
          widget.selectActiveCase(activeCase, changeTab: false);
        }
      }

      setState(() {
        selectedCase = activeCase;
        if (selectedCase != null &&
            selectedCase!.lat != null &&
            selectedCase!.lng != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print(
                  '🗺️  Moving map to selected case: ${selectedCase!.lat}, ${selectedCase!.lng}');
              _mapController.move(
                  LatLng(selectedCase!.lat!, selectedCase!.lng!), 15.0);
            }
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading global cases: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  LatLng get _center {
    if (_livePosition != null) {
      return LatLng(_livePosition!.latitude, _livePosition!.longitude);
    }
    if (widget.currentPosition != null) {
      return LatLng(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    }
    return const LatLng(24.9180, 67.0971); // Default to Karachi centroid
  }

  @override
  Widget build(BuildContext context) {
    final visible = _cases.where((item) {
      if (filter == 'Critical') return item.severity.toLowerCase() == 'high';
      if (filter == 'Fixed') return item.status == 'Fixed';
      if (filter == 'My area') {
        if (widget.currentPosition == null ||
            item.lat == null ||
            item.lng == null) return true;
        final dist = Geolocator.distanceBetween(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
          item.lat!,
          item.lng!,
        );
        return dist <= 1000; // Within 1 km radius
      }
      return item.severity.toLowerCase() != 'high' &&
          item.status != 'Fixed'; // Needs proof
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
                            color: SnapColors.purple.withValues(alpha: 0.2),
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
                            isRoutingActive = false;
                            _geofenceReached = false;
                            _mapController.move(point, 15.0);
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
                if (isRoutingActive && mapPolylines.isNotEmpty)
                  PolylineLayer(
                    polylines: mapPolylines.toList(),
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
                  RoundIconButton(
                      icon: Icons.refresh_rounded, onTap: _loadGlobalCases),
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
                  if (value == 'Critical')
                    return item.severity.toLowerCase() == 'high';
                  if (value == 'Fixed') return item.status == 'Fixed';
                  if (value == 'My area') {
                    if (widget.currentPosition == null ||
                        item.lat == null ||
                        item.lng == null) return true;
                    final dist = Geolocator.distanceBetween(
                      widget.currentPosition!.latitude,
                      widget.currentPosition!.longitude,
                      item.lat!,
                      item.lng!,
                    );
                    return dist <= 1000;
                  }
                  return item.severity.toLowerCase() != 'high' &&
                      item.status != 'Fixed';
                }).toList();

                final next = filtered.isNotEmpty
                    ? filtered.first
                    : (_cases.isNotEmpty ? _cases.first : null);
                setState(() {
                  filter = value;
                  if (next != null) {
                    selectedCase = next;
                    isRoutingActive = false;
                    _geofenceReached = false;
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
                      child:
                          CircularProgressIndicator(color: SnapColors.purple),
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
                    : Builder(builder: (context) {
                        final displayCase = selectedCase ??
                            widget.targetFocusCase ??
                            (_cases.isNotEmpty ? _cases.first : null);
                        if (displayCase == null) {
                          return const SizedBox.shrink();
                        }
                        return AppCard(
                          radius: 20,
                          padding: const EdgeInsets.all(9),
                          child: Column(
                            children: [
                              Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius:
                                          BorderRadius.circular(999))),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      width: 76,
                                      height: 76,
                                      child: _buildMapImage(displayCase.image),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                                child: Text(displayCase.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        height: 1.08))),
                                            StatusPill(
                                              displayCase.severity
                                                          .toLowerCase() ==
                                                      'high'
                                                  ? 'Critical'
                                                  : displayCase.status,
                                              color: displayCase.severity
                                                          .toLowerCase() ==
                                                      'high'
                                                  ? SnapColors.danger
                                                  : null,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                            isRoutingActive
                                                ? (_remainingDistance != null
                                                    ? (_remainingDistance! >=
                                                            1000
                                                        ? 'Distance: ${(_remainingDistance! / 1000).toStringAsFixed(2)} km'
                                                        : 'Distance: ${_remainingDistance!.toStringAsFixed(0)} meters')
                                                    : 'Locating...')
                                                : getDistanceText(
                                                    widget.currentPosition,
                                                    displayCase.lat,
                                                    displayCase.lng),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: SnapColors.muted,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 5),
                                        Text(
                                            getConfirmationsText(
                                                displayCase.reports),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            'Authority: ${displayCase.authorityName ?? "SSWMB"}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                      onPressed: _geofenceReached
                                          ? widget.onSnap
                                          : (!isRoutingActive
                                              ? () => _startLiveTracking(
                                                  displayCase)
                                              : null),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _geofenceReached
                                              ? SnapColors.purple
                                              : (!isRoutingActive
                                                  ? SnapColors.purple
                                                  : Colors.grey),
                                          minimumSize:
                                              const Size.fromHeight(40)),
                                      child: Text(
                                          _geofenceReached
                                              ? 'Open camera'
                                              : (!isRoutingActive
                                                  ? 'Confirm Case'
                                                  : 'Routing...'),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 10,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          widget.onCase(displayCase),
                                      style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(40)),
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
                        );
                      }),
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
    final isFixed = item.status.toLowerCase() == 'fixed' ||
        item.status.toLowerCase() == 'resolved';
    final isCritical = item.severity.toLowerCase() == 'high';

    final Color pinColor;
    final IconData pinIcon;
    final bool isCircle;

    if (isFixed) {
      pinColor = Colors.green;
      pinIcon = Icons.check;
      isCircle = true;
    } else if (isCritical) {
      pinColor = Colors.red;
      pinIcon = Icons.warning_rounded;
      isCircle = false;
    } else {
      // Active verification / Needs proof
      pinColor = Colors.amber;
      pinIcon = Icons.shield;
      isCircle = false;
    }

    final childWidget = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: pinColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Icon(pinIcon, color: Colors.white, size: 18),
      ),
    );

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      scale: selected ? 1.25 : 1.0,
      child: childWidget,
    );
  }
}
