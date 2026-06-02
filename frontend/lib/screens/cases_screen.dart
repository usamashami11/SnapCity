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
    final filteredCases = _globalCases.where((item) {
      if (filter == 'Nearby You') return true;
      if (filter == 'Fixed') return item.status == 'Fixed';
      return true;
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
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text('Global community reports',
                style: TextStyle(fontSize: 12, color: SnapColors.muted)),
            const SizedBox(height: 4),
            const Text('Cases',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Recently Reported',
                  'Nearby You',
                  'Fixed'
                ]
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: filter == f,
                            onSelected: (val) => setState(() => filter = f),
                            backgroundColor: Colors.white,
                            selectedColor: SnapColors.purple.withOpacity(.12),
                            labelStyle: TextStyle(
                                color: filter == f
                                    ? SnapColors.purple
                                    : SnapColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide(
                                    color: filter == f
                                        ? SnapColors.purple
                                        : SnapColors.line)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(color: SnapColors.purple),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadGlobalCases,
                          child: const Text('Retry'))
                    ],
                  ),
                ),
              )
            else if (filteredCases.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded,
                          color: SnapColors.muted, size: 48),
                      SizedBox(height: 12),
                      Text("No cases found in global database.",
                          style: TextStyle(
                              color: SnapColors.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else
              ...filteredCases
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CaseCard(
                          item: item,
                          onTap: () => widget.onCase(item),
                        ),
                      ))
                  .toList(),
          ],
        ),
      ),
    );
  }
}
