import 'package:flutter/material.dart';
import '../models.dart';
import '../snapcity_theme.dart';
import '../widgets.dart';
import '../mock_data.dart';
import '../services/api_service.dart';
import '../backend_contract.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen(
      {super.key,
      required this.onHome,
      required this.onFeed,
      required this.onMap,
      required this.onSnap,
      required this.onCase});

  final VoidCallback onHome;
  final VoidCallback onFeed;
  final VoidCallback onMap;
  final VoidCallback onSnap;
  final ValueChanged<CivicCase> onCase;

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  String filter = 'Recently Reported';
  List<CivicCase> _globalCases = [];
  bool _isLoading = true;
  String? _error;

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
      final cases = await ApiService().fetchGlobalCases();
      if (!mounted) return;

      setState(() {
        final parsedCases = cases
            .map((resp) => CivicCase(
                  id: resp.caseId,
                  title: resp.issueType.replaceAll('_', ' ').toUpperCase(),
                  location: resp.locationName?.isNotEmpty == true
                      ? resp.locationName!
                      : resp.area,
                  status: 'Verified',
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
                  authorityName: resp.authority['name'] as String? ?? '',
                  authorityEmail: resp.authority['email'] as String? ?? '',
                  authorityWhatsapp:
                      resp.authority['whatsapp'] as String? ?? '',
                  tags: _buildCaseTags(resp),
                  weather: resp.weather,
                  traffic: resp.traffic,
                ))
            .toList();

        _globalCases = _mergeClusteredCases(parsedCases);
        if (_globalCases.isEmpty) {
          _globalCases = _fallbackCases();
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

  List<String> _buildCaseTags(AgentReportResponse resp) {
    final tags = <String>[];
    if (resp.duplicateClusterId?.isNotEmpty == true ||
        resp.similarReports > 0) {
      tags.add('Clustered');
    }
    if (resp.similarReports >= 3) {
      tags.add('${resp.similarReports} Similar');
    }
    if (resp.severity.isNotEmpty) {
      tags.add(resp.severity);
    }
    if (resp.assignedResponder.isNotEmpty) {
      tags.add('Responder');
    }
    return tags;
  }

  List<CivicCase> _mergeClusteredCases(List<CivicCase> rawCases) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in rawCases) {
      final groupKey = item.duplicateClusterId?.isNotEmpty == true
          ? item.duplicateClusterId!
          : item.id;
      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = {
          'item': item,
          'count': 1,
        };
      } else {
        final currentCount = grouped[groupKey]!['count'] as int;
        grouped[groupKey]!['count'] = currentCount + 1;
      }
    }

    return grouped.entries.map((entry) {
      final item = entry.value['item'] as CivicCase;
      final count = entry.value['count'] as int;
      if (count <= 1) return item;

      return CivicCase(
        id: item.id,
        title: '${item.title} Cluster',
        location: item.location,
        status: 'Clustered',
        severity: item.severity,
        reports: item.reports,
        strength: item.strength,
        updated: item.updated,
        action: 'Cluster summary',
        image: item.image,
        detail:
            '$count related reports were grouped into this cluster for a stronger response.',
        helper: item.helper,
        lat: item.lat,
        lng: item.lng,
        duplicateClusterId: item.duplicateClusterId,
        similarReportsNearby: item.similarReportsNearby,
        rewardMessage: item.rewardMessage,
        tags: [
          'Clustered',
          if (item.severity.isNotEmpty) item.severity,
          if (item.similarReportsNearby > 0)
            '${item.similarReportsNearby} Nearby',
        ],
      );
    }).toList();
  }

  List<CivicCase> _fallbackCases() {
    if (feedCases.isNotEmpty) return feedCases;
    if (caseItems.isNotEmpty) return caseItems;
    return []; // Return an empty list to allow native empty state
  }

  @override
  Widget build(BuildContext context) {
    final cases = _globalCases.where((item) {
      if (filter == 'Nearby You') {
        // Simple logic for MVP: everything in current locality
        return true;
      }
      if (filter == 'Fixed') return item.status == 'Fixed';
      return true; // Recently Reported (All)
    }).toList();

    return ScaffoldWithNav(
      current: 'Cases',
      onHome: widget.onHome,
      onCases: () {},
      onSnap: widget.onSnap,
      onMap: widget.onMap,
      onFeed: widget.onFeed,
      child: RefreshIndicator(
        onRefresh: _loadGlobalCases,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 46, 12, 92),
          children: [
            const Text('Global community reports',
                style: TextStyle(fontSize: 12, color: SnapColors.muted)),
            const SizedBox(height: 4),
            const Text('Cases',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            FilterRow(
                items: const ['Recently Reported', 'Nearby You', 'Fixed'],
                selected: filter,
                onSelected: (value) => setState(() => filter = value)),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(SnapColors.purple),
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: SnapColors.danger),
                      const SizedBox(height: 12),
                      Text(
                        'Error loading cases',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SnapColors.ink),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              color: SnapColors.muted,
                              fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadGlobalCases,
                        style: FilledButton.styleFrom(
                          backgroundColor: SnapColors.purple,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_isLoading && _error == null && cases.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 60, color: SnapColors.success),
                      const SizedBox(height: 18),
                      const Text(
                        'No civic issues reported yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: SnapColors.ink),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your city is looking great!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: SnapColors.muted),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loadGlobalCases,
                        style: FilledButton.styleFrom(
                          backgroundColor: SnapColors.purple,
                        ),
                        child: const Text('Refresh Cases'),
                      ),
                    ],
                  ),
                ),
              )
            else if (cases.isEmpty && _globalCases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.filter_list_off_rounded,
                          size: 48, color: SnapColors.muted),
                      const SizedBox(height: 12),
                      const Text(
                        'No cases match the selected filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SnapColors.muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...cases.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        FeedRow(item: item, onTap: () => widget.onCase(item)),
                  )),
          ],
        ),
      ),
    );
  }
}
