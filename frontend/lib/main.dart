import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

import 'mock_data.dart';
import 'models.dart';
import 'backend_contract.dart';
import 'snapcity_theme.dart';
import 'widgets.dart';
import 'screens/home_screen.dart';
import 'screens/cases_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/map_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'screens/scanning_screen.dart';
import 'screens/ticket_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/case_detail_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request critical permissions on startup
  await [
    Permission.location,
    Permission.camera,
    Permission.microphone,
  ].request();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
        "Warning: .env file not found. Using hardcoded fallback if available.");
  }

  // Lazy initialize ApiService with variables from .env
  await ApiService().initializeSupabase(
    url: dotenv.get('SUPABASE_URL', fallback: ''),
    anonKey: dotenv.get('SUPABASE_ANON_KEY', fallback: ''),
  );
  runApp(const SnapCityApp());
}

class SnapCityApp extends StatelessWidget {
  const SnapCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapCity',
      debugShowCheckedModeBanner: false,
      theme: snapTheme(),
      home: const SnapCityPreviewHost(),
    );
  }
}

class SnapCityPreviewHost extends StatelessWidget {
  const SnapCityPreviewHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD5D6D6),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final usePhoneFrame = constraints.maxWidth >= 620;
          if (!usePhoneFrame) return const SnapCityShell();

          final frameHeight = (constraints.maxHeight - 40).clamp(640.0, 880.0);
          return Center(
            child: Container(
              width: 420,
              height: frameHeight,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(46),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x3D000000), // Colors.black.withOpacity(.24)
                    blurRadius: 54,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: const SnapCityShell(),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum AppScreen {
  home,
  cases,
  map,
  feed,
  camera,
  scanning,
  ticket,
  reward,
  detail
}

class SnapCityShell extends StatefulWidget {
  const SnapCityShell({super.key});

  @override
  State<SnapCityShell> createState() => _SnapCityShellState();
}

class _SnapCityShellState extends State<SnapCityShell> {
  AppScreen _screen = AppScreen.home;
  AppScreen _previous = AppScreen.home; // Keep previous screen for navigation
  CivicCase? _selectedCase; // Changed to nullable and initialized to null

  bool _submittingReport = false;
  AgentReportResponse? _lastReportResponse;
  String _userName = 'Resident';
  String? _capturedImagePath;
  // String? _capturedVoicePath; // This is handled in ticket_screen.dart now
  List<CivicCase> _myCases = [];

  Position? _currentPosition;
  String _currentArea = 'Your Area';

  List<CivicCase> _allGlobalCases = [];
  CivicCase? _nearestCase;
  CivicCase? targetFocusCase;
  bool _isCurrentlyRouted = false;
  Future<AgentReportResponse>? _orchestrationFuture;

  void selectActiveCase(CivicCase selectedCase, {bool changeTab = true}) {
    setState(() {
      targetFocusCase = selectedCase;
      _isCurrentlyRouted = false;
      if (changeTab) {
        _screen = AppScreen.map;
      }
    });
  }

  // Mock stats for UI
  int _fixedIssuesCount = 5;
  int _neighborCount = 128;
  String _impactScore = '4,250';
  String _localRank = 'Top 8%';
  String _verifiedCount = '23';
  String _fixedNearbyCount = '5';

  final List<String> _notifications = [];
  Timer? _proximityTimer;

  // ignore: unused_field
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadUserConfig();
    _initNotifications();
    _determinePosition();
    _startProximityCheck();
  }

  void _startProximityCheck() {
    _proximityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkNearbyCases();
    });
  }

  Future<void> _checkNearbyCases() async {
    if (_currentPosition == null) return;

    try {
      final cases = await ApiService().fetchGlobalCases();
      for (final c in cases) {
        // Better check: use GPS from raw data if available, but contract doesn't expose it directly in response yet
        // Let's assume for MVP nearby check uses a small subset or we update contract
        // TODO: Implement proximity check logic using the case's location.
        // The 'distance' variable was unused.
        Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          c.authority['lat'] ?? 0.0,
          c.authority['lng'] ?? 0.0,
        );
      }
    } catch (e) {
      debugPrint('Proximity check error: $e');
    }
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint(
          'Location permission denied or permanently denied: $permission');
      setState(() {
        _currentPosition = null;
      });
      _showLocationRequiredMessage();
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      setState(() {
        _currentPosition = null;
      });
      _showLocationRequiredMessage();
      return;
    }

    Position? position;
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
      timeLimit: Duration(seconds: 8),
    );

    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
    } catch (e) {
      debugPrint('Primary GPS lookup failed: $e');
      try {
        position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          debugPrint('Using last known position as fallback.');
        }
      } catch (fallbackError) {
        debugPrint('getLastKnownPosition fallback failed: $fallbackError');
      }
    }

    if (position == null) {
      _showLocationRequiredMessage();
      return;
    }

    setState(() {
      _currentPosition = position;
    });

    try {
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentArea = place.subLocality ?? place.locality ?? 'Your Area';
        });
      }
    } catch (geoErr) {
      debugPrint('Geocoding error: $geoErr');
    }
    _loadGlobalCases();
  }

  Future<void> _loadGlobalCases() async {
    try {
      final responses = await ApiService().fetchGlobalCases();
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
                updated: formatRelativeTime(resp.timestamp),
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
                timestamp: resp.timestamp,
              ))
          .toList();

      setState(() {
        _allGlobalCases = parsedCases;
        _updateNearestCase();
      });
    } catch (e) {
      debugPrint('Error loading global cases: $e');
    }
  }

  void _updateNearestCase() {
    if (_currentPosition == null || _allGlobalCases.isEmpty) {
      setState(() {
        _nearestCase = null;
      });
      return;
    }
    CivicCase? nearest;
    double minDistance = double.infinity;
    for (final c in _allGlobalCases) {
      if (c.lat == null || c.lng == null) continue;
      if (c.status.toLowerCase() == 'fixed') continue;
      final dist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        c.lat!,
        c.lng!,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = c;
      }
    }
    setState(() {
      _nearestCase = nearest;
    });
  }

  void _setMapActiveCase({CivicCase? targetCase, bool routing = false}) {
    CivicCase? finalCase = targetCase;
    if (finalCase == null) {
      if (_currentPosition != null && _allGlobalCases.isNotEmpty) {
        CivicCase? nearest;
        double minDistance = double.infinity;
        for (final c in _allGlobalCases) {
          if (c.lat == null || c.lng == null) continue;
          final dist = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            c.lat!,
            c.lng!,
          );
          if (dist < minDistance) {
            minDistance = dist;
            nearest = c;
          }
        }
        finalCase = nearest;
      } else if (_allGlobalCases.isNotEmpty) {
        finalCase = _allGlobalCases.first;
      }
    }
    setState(() {
      targetFocusCase = finalCase;
      _isCurrentlyRouted = routing;
      _screen = AppScreen.map;
    });
  }

  Future<void> _openDirectCamera() async {
    final previousScreen = _screen;
    final picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _capturedImagePath = photo.path;
          _screen = AppScreen.scanning;
        });
        _startAiOrchestration();
      } else {
        setState(() {
          _screen = previousScreen;
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      setState(() {
        _screen = previousScreen;
      });
    }
  }

  void _startAiOrchestration() {
    _lastReportResponse = null;
    _orchestrationFuture = ApiService().submitCivicReport(
      reportId: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      localImagePath: _capturedImagePath!,
      lat: _currentPosition?.latitude ?? 24.9180,
      lng: _currentPosition?.longitude ?? 67.0971,
      voiceNoteTranscript: '',
      locationName: _currentArea,
    );
  }

  Future<void> _initNotifications() async {
    // Notification initialization logic can be restored here if needed
  }

  void _showLocationRequiredMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please enable GPS/Location services to report an issue.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showNotification(String title, String body) async {
    setState(() {
      _notifications.insert(0, body);
    });
    // Notification display logic can be restored here if needed
  }

  Future<void> _loadUserConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name');

    // Load persisted cases
    final casesJson = prefs.getStringList('user_cases') ?? [];
    setState(() {
      _myCases = casesJson.map((str) {
        final map = jsonDecode(str);
        return CivicCase(
          id: map['id'],
          title: map['title'],
          location: map['location'],
          status: map['status'],
          severity: map['severity'],
          reports: map['reports'],
          strength: map['strength'],
          updated: map['updated'],
          action: map['action'],
          image: map['image'],
          detail: map['detail'],
          helper: map['helper'],
          lat: map['lat'] is num ? (map['lat'] as num).toDouble() : null,
          lng: map['lng'] is num ? (map['lng'] as num).toDouble() : null,
          duplicateClusterId: map['duplicate_cluster_id'],
          similarReportsNearby: map['similar_reports_nearby'] ?? 0,
          rewardMessage: map['reward_message'],
          noticeDraft: map['notice_draft'],
          authorityName: map['authority_name'],
          authorityEmail: map['authority_email'],
          authorityWhatsapp: map['authority_whatsapp'],
          weather: map['weather'],
          traffic: map['traffic'],
        );
      }).toList();
      caseItems = _myCases; // Update global mock list for now
    });

    // Load dynamic stats
    setState(() {
      _fixedIssuesCount = prefs.getInt('stats_fixed') ?? 5;
      _neighborCount = prefs.getInt('stats_neighbors') ?? 128;
      _impactScore = prefs.getString('stats_impact') ?? '4,250';
      _localRank = prefs.getString('stats_rank') ?? 'Top 8%';
      _verifiedCount = prefs.getString('stats_verified') ?? '23';
      _fixedNearbyCount = prefs.getString('stats_nearby') ?? '5';
    });

    if (savedName == null) {
      Future.delayed(const Duration(milliseconds: 500), _showOnboardingDialog);
    } else {
      setState(() {
        _userName = savedName;
      });
    }
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stats_fixed', _fixedIssuesCount);
    await prefs.setInt('stats_neighbors', _neighborCount);
    await prefs.setString('stats_impact', _impactScore);
    await prefs.setString('stats_rank', _localRank);
    await prefs.setString('stats_verified', _verifiedCount);
    await prefs.setString('stats_nearby', _fixedNearbyCount);

    // Save cases
    final casesJson = _myCases
        .map((c) => jsonEncode({
              'id': c.id,
              'title': c.title,
              'location': c.location,
              'status': c.status,
              'severity': c.severity,
              'reports': c.reports,
              'strength': c.strength,
              'updated': c.updated,
              'action': c.action,
              'image': c.image,
              'detail': c.detail,
              'helper': c.helper,
              'notice_draft': c.noticeDraft,
              'authority_name': c.authorityName,
              'authority_email': c.authorityEmail,
              'authority_whatsapp': c.authorityWhatsapp,
              'weather': c.weather,
              'traffic': c.traffic,
            }))
        .toList();
    await prefs.setStringList('user_cases', casesJson);
  }

  void _showOnboardingDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10091E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Welcome to SnapCity',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How should we greet you?',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Your Name',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', name);
                setState(() => _userName = name);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Get Started',
                style: TextStyle(
                    color: SnapColors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_lastReportResponse == null) return;

    setState(() {
      _submittingReport = true;
    });

    try {
      final response = _lastReportResponse!;

      // The backend already handles saving the case to Supabase via the submitCivicReport call
      // which is executed during the scanning screen orchestration phase.
      // Here we update the local state to reflect the submission.

      setState(() {
        _submittingReport = false;
        _screen = AppScreen.reward;

        // Dynamic update of stats for Hackathon demo
        _fixedIssuesCount++;
        _verifiedCount = (int.parse(_verifiedCount) + 1).toString();

        // Update impact score
        final currentScore = int.parse(_impactScore.replaceAll(',', ''));
        final newScore = currentScore + response.points;
        _impactScore = newScore.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

        final newCase = CivicCase(
          id: response.caseId,
          title: response.issueType.replaceAll('_', ' ').toUpperCase(),
          location: response.locationName?.isNotEmpty == true
              ? response.locationName!
              : response.area,
          status: 'Reported',
          severity: response.severity,
          reports: 1,
          strength: response.confidence,
          updated: 'Just now',
          action: 'Awaiting Verification',
          image: _capturedImagePath ?? 'assets/pothole-camera.png',
          detail: response.escalationReason,
          helper: response.assignedResponder,
          noticeDraft: response.noticeDraft,
          authorityName: response.authority['name'] as String? ?? 'SSWMB',
          authorityEmail: response.authority['email'] as String? ?? '',
          authorityWhatsapp: response.authority['whatsapp'] as String? ?? '',
          weather: response.weather,
          traffic: response.traffic,
          timestamp: response.timestamp,
        );
        _myCases.insert(0, newCase);

        _saveStats();
      });

      // Reload global cases to ensure the map and cases tab are updated immediately
      _loadGlobalCases();

      _showNotification(
        'Report Processed!',
        'AI detected ${response.issueType} in ${response.area}. Case #${response.caseId} created.',
      );
    } catch (e) {
      setState(() {
        _submittingReport = false;
      });
      debugPrint("Error finalizing case: $e");
    }
  }

  void _open(AppScreen screen) => setState(() => _screen = screen);

  void _openCase(CivicCase item) {
    setState(() {
      _previous = _screen;
      _selectedCase = item;
      _screen = AppScreen.detail;
    });
  }

  void _backFromDetail() => setState(() => _screen = _previous);

  @override
  Widget build(BuildContext context) {
    final child = switch (_screen) {
      AppScreen.home => HomeScreen(
          userName: _userName,
          currentArea: _currentArea,
          notificationCount: _notifications.length,
          fixedIssuesCount: _fixedIssuesCount,
          neighborCount: _neighborCount,
          impactScore: _impactScore,
          localRank: _localRank,
          verifiedCount: _verifiedCount,
          fixedNearbyCount: _fixedNearbyCount,
          onFeed: () => _open(AppScreen.feed),
          onMap: () => _setMapActiveCase(targetCase: null, routing: false),
          onCases: () => _open(AppScreen.cases),
          onSnap: _openDirectCamera,
          onCase: _openCase,
          nearestCase: _nearestCase,
          currentPosition: _currentPosition,
          onGoConfirm: (CivicCase targetCase) =>
              _setMapActiveCase(targetCase: targetCase, routing: true),
          activeCases: _myCases.isEmpty
              ? _allGlobalCases.where((c) => c.status != 'Fixed').toList()
              : _myCases,
          recentFixes:
              _allGlobalCases.where((c) => c.status == 'Fixed').toList(),
        ),
      AppScreen.cases => CasesScreen(
          onHome: () => _open(AppScreen.home),
          onFeed: () => _open(AppScreen.feed),
          onMap: () => _setMapActiveCase(targetCase: null, routing: false),
          onSnap: _openDirectCamera,
          onCase: _openCase,
        ),
      AppScreen.map => CivicMapScreen(
          currentPosition: _currentPosition,
          onHome: () => _open(AppScreen.home),
          onCases: () => _open(AppScreen.cases),
          onFeed: () => _open(AppScreen.feed),
          onSnap: _openDirectCamera,
          onCase: _openCase,
          targetFocusCase: targetFocusCase,
          selectActiveCase: selectActiveCase,
          initialRouted: _isCurrentlyRouted,
          allGlobalCases: _allGlobalCases,
        ),
      AppScreen.feed => FeedScreen(
          notifications: _notifications,
          onHome: () => _open(AppScreen.home),
          onCases: () => _open(AppScreen.cases),
          onMap: () => _setMapActiveCase(targetCase: null, routing: false),
          onSnap: _openDirectCamera,
          onCase: _openCase,
        ),
      AppScreen.camera => Container(), // Shutter screen removed entirely
      AppScreen.scanning => ScanningScreen(
          imagePath: _capturedImagePath ?? 'assets/pothole-camera.png',
          orchestrationFuture: _orchestrationFuture,
          onComplete: (res) {
            setState(() {
              _lastReportResponse = res;
              _screen = AppScreen.ticket;
            });
          },
        ),
      AppScreen.ticket => TicketScreen(
          imagePath: _capturedImagePath ?? 'assets/pothole-camera.png',
          lat: _currentPosition?.latitude ?? 24.9180,
          lng: _currentPosition?.longitude ?? 67.0971,
          onClose: () => _open(AppScreen.home),
          onSubmit: _submitReport,
          response: _lastReportResponse!,
        ),
      AppScreen.reward => RewardScreen(
          onHome: () => _open(AppScreen.home),
          onCase: () {
            if (_lastReportResponse != null) {
              final newCase = _myCases
                  .firstWhere((c) => c.id == _lastReportResponse!.caseId);
              _openCase(newCase);
            } else {
              _open(AppScreen.home);
            }
          },
          response: _lastReportResponse,
        ),
      AppScreen.detail => CaseDetailScreen(
          item: _selectedCase!,
          onBack: _backFromDetail,
          onHome: () => _open(AppScreen.home),
          onCases: () => _open(AppScreen.cases),
          onFeed: () => _open(AppScreen.feed),
          onMap: () => selectActiveCase(_selectedCase!, changeTab: true),
          onSnap: _openDirectCamera,
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
              duration: const Duration(milliseconds: 220), child: child),
          if (_submittingReport)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: SnapColors.purple),
                    SizedBox(height: 16),
                    Text(
                      'AI Swarm Orchestrating...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
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
