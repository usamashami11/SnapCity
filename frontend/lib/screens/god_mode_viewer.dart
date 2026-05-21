import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';
import '../services/api_service.dart';

class GodModeLogViewerScreen extends StatefulWidget {
  const GodModeLogViewerScreen({super.key, required this.token});

  final String token;

  @override
  State<GodModeLogViewerScreen> createState() => _GodModeLogViewerScreenState();
}

class _GodModeLogViewerScreenState extends State<GodModeLogViewerScreen> {
  final List<String> _logs = [];
  Timer? _pollingTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    // Poll logs every 2 seconds
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _fetchLogs());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    try {
      final url =
          '${ApiService.activeBaseUrl}/api/v1/godmode/logs?token=${widget.token}&format=json';
      print('🚨 DEBUG API CALL: Requesting URL -> $url');
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> logData = data['logs'] ?? [];
        final fetchedLogs = logData.map((e) {
          if (e is Map<String, dynamic>) {
            final agent = e['agent'] ?? 'System';
            final message = e['message'] ?? jsonEncode(e);
            return '[$agent] $message';
          }
          return e.toString();
        }).toList();

        if (mounted) {
          setState(() {
            _logs.clear();
            _logs.addAll(fetchedLogs);
            _isLoading = false;
            _error = null;
          });
          _scrollToBottom();
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                'Failed to fetch logs from backend (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Fallback for Android Emulator connection if activeBaseUrl isn't already the emulator default
      if (ApiService.activeBaseUrl != ApiService.optionC_emulatorDefaultUrl) {
        try {
          final fallbackUrl =
              '${ApiService.optionC_emulatorDefaultUrl}/api/v1/godmode/logs?token=${widget.token}&format=json';
          print('🚨 DEBUG API CALL: Retrying Fallback URL -> $fallbackUrl');
          final response = await http
              .get(Uri.parse(fallbackUrl))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final List<dynamic> logData = data['logs'] ?? [];
            final fetchedLogs = logData.map((e) {
              if (e is Map<String, dynamic>) {
                final agent = e['agent'] ?? 'System';
                final message = e['message'] ?? jsonEncode(e);
                return '[$agent] $message';
              }
              return e.toString();
            }).toList();
            if (mounted) {
              setState(() {
                _logs.clear();
                _logs.addAll(fetchedLogs);
                _isLoading = false;
                _error = null;
              });
              _scrollToBottom();
            }
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _error =
              'Failed to connect to backend server. Make sure Python API is running.';
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _extractAgent(String line) {
    final match = RegExp(r'^\[(.*?)\]').firstMatch(line);
    return match?.group(1) ?? 'System';
  }

  int? _extractConfidence(String text) {
    final percentage = RegExp(r'(\d{1,3})\s*%').firstMatch(text);
    if (percentage != null) {
      return int.tryParse(percentage.group(1)!);
    }
    final confidence = RegExp(r'confidence(?: score)?:\s*(\d{1,3})')
        .firstMatch(text.toLowerCase());
    return confidence != null ? int.tryParse(confidence.group(1)!) : null;
  }

  String? _extractClusterId(String text) {
    final match =
        RegExp(r'cluster(?: id)?:\s*([A-Za-z0-9_-]+)', caseSensitive: false)
            .firstMatch(text);
    return match?.group(1);
  }

  String? _extractLocation(String text) {
    final match =
        RegExp(r'location(?: name)?:\s*([^|,;\.]+)', caseSensitive: false)
            .firstMatch(text);
    return match?.group(1)?.trim();
  }

  List<String> _extractBullets(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
    final parts = cleaned
        .split(RegExp(r'\s*[\|;]\s*|\.\s+| - '))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length <= 3) return parts;
    return parts.take(3).toList();
  }

  List<_AgentLogCard> _buildAgentCards() {
    final grouped = <String, List<String>>{};
    for (final line in _logs) {
      final agent = _extractAgent(line);
      grouped.putIfAbsent(agent, () => []).add(line);
    }

    return grouped.entries.map((entry) {
      final agent = entry.key;
      final lines = entry.value;
      final combined = lines.join(' | ');
      final raw = combined.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
      final confidence = _extractConfidence(combined);
      final clusterId = _extractClusterId(combined);
      final location = _extractLocation(combined);
      final bullets = _extractBullets(raw);
      final tags = <String>[];
      if (clusterId != null) tags.add('Cluster: $clusterId');
      if (location != null) tags.add('Location: $location');
      if (confidence != null) tags.add('Confidence: $confidence%');
      if (lines.length > 1) tags.add('${lines.length} events');

      return _AgentLogCard(
        agent: agent,
        summary: lines.first.replaceAll(RegExp(r'^\[.*?\]\s*'), ''),
        bullets: bullets,
        confidence: confidence,
        tags: tags,
        color: agent == 'ReasoningAgent'
            ? Colors.deepPurpleAccent
            : agent == 'ContextAgent'
                ? Colors.amberAccent
                : agent == 'DispatchAgent'
                    ? Colors.greenAccent
                    : agent == 'IngestionAgent'
                        ? Colors.lightBlueAccent
                        : Colors.white70,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final agentCards = _buildAgentCards();
    return Scaffold(
      backgroundColor: const Color(0xFF080A10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0F19),
        elevation: 0,
        title: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.05),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: const Icon(Icons.blur_on_rounded,
                  color: Color(0xFF5EE4E3), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Live Swarm Telemetry',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Courier',
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchLogs,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SnapCityPreviewHost()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF121822),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D9CDB), Color(0xFF53E3A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.memory_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Agentic Swarm Control Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Live telemetry from the orchestration pipeline with context, clustering, and confidence metrics.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF5EE4E3),
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : agentCards.isEmpty
                            ? const Center(
                                child: Text(
                                  'Waiting for the swarm to generate telemetry...',
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 12),
                                itemCount: agentCards.length,
                                itemBuilder: (context, index) {
                                  return _buildAgentCard(agentCards[index]);
                                },
                              ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0C0F19),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Token: ${widget.token.substring(0, 8)}...',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.fiber_manual_record,
                          size: 10, color: Colors.greenAccent),
                      SizedBox(width: 6),
                      Text(
                        'POLLING (2s)',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(_AgentLogCard card) {
    final confidence = card.confidence ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101523),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: card.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                card.agent,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (card.tags.isNotEmpty)
                StatusPill(card.tags.first, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: card.tags
                .map((tag) => StatusPill(tag, color: Colors.white70))
                .toList(),
          ),
          if (card.confidence != null) ...[
            const SizedBox(height: 14),
            Text(
              'Confidence score',
              style: TextStyle(
                  color: Colors.white70.withOpacity(0.9), fontSize: 12),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: confidence / 100,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  confidence >= 75
                      ? SnapColors.success
                      : confidence >= 45
                          ? Colors.orangeAccent
                          : SnapColors.danger,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$confidence% confidence',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Column(
            children: card.bullets
                .map((bullet) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            card.agent == 'ReasoningAgent'
                                ? Icons.radar
                                : card.agent == 'ContextAgent'
                                    ? Icons.location_on_rounded
                                    : card.agent == 'DispatchAgent'
                                        ? Icons.send_rounded
                                        : Icons.memory_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AgentLogCard {
  _AgentLogCard({
    required this.agent,
    required this.summary,
    required this.bullets,
    required this.tags,
    required this.color,
    this.confidence,
  });

  final String agent;
  final String summary;
  final List<String> bullets;
  final List<String> tags;
  final Color color;
  final int? confidence;
}

extension ColorDarken on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}
