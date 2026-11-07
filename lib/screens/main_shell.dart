import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_repository.dart';
import '../main.dart' show peakDatesStore;
import '../data/api_config.dart';
import '../utils/error_messages.dart';
import '../models/real_station.dart';
import 'real_overview_screen.dart';
import 'leaks_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import 'real_alerts_screen.dart';
import 'real_more_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;
  List<RealStation> _stations = [];
  List<RealStation> _todayStations = [];
  DateTime _lastFetched = DateTime.now();
  bool _isOffline = false;
  Timer? _autoRefreshTimer;
  // Last-known card extras, kept across reloads so the chips don't blink
  // out while a refresh is in flight. Null = not loaded (badge omitted).
  Map<String, int>? _vehicleByCode;
  Map<String, dynamic>? _flightRiskByCode;
  // Mirrors the admin 'Show Lumo data in app' switch (sent with flight risk).
  bool _lumoEnabled = true;
  // Bumped per load so a slow, older load can't overwrite a newer one.
  int _loadSeq = 0;
  static const _autoRefreshInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    // Load with default date range (today + tomorrow) immediately
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tomorrow = now.add(const Duration(days: 1));
    final toStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    _loadStations(fromDate: todayStr, toDate: toStr);

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _loadStations(fromDate: todayStr, toDate: toStr, silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Applies whichever card extras (vehicle count, flight-risk counts) have
  /// loaded so far onto a station list.
  List<RealStation> _withExtras(List<RealStation> list) => list.map((s) {
        var out = s;
        final vehicles = _vehicleByCode;
        if (vehicles != null) out = out.withVehicleCount(vehicles[s.code]);
        final entry = (_flightRiskByCode?[s.code] as Map?)?.cast<String, dynamic>();
        if (entry != null) {
          out = out.withFlightRisk(entry['tomorrow'] as int?, entry['next_5_days'] as int?);
        } else if (!_lumoEnabled) {
          out = out.withFlightRisk(null, null);
        }
        return out;
      }).toList();

  void _reapplyExtras() {
    setState(() {
      _stations = _withExtras(_stations);
      _todayStations = _withExtras(_todayStations);
    });
  }

  Future<void> _loadStations({String? fromDate, String? toDate, String? station, bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) setState(() { _loading = true; _error = null; });

    // Transport and flight-risk counts are nice-to-haves on the cards and
    // their backends are the slowest to answer (flight risk can take ~10s
    // when its cache is cold) — fetch them in parallel with the stations
    // and fill the chips in whenever each arrives, instead of making the
    // whole Overview wait for them. A failure just leaves its chip off.
    ApiRepository().fetchTransportationOverview().then((rows) {
      if (!mounted || seq != _loadSeq) return;
      _vehicleByCode = {
        for (final row in rows)
          (row['code'] as String? ?? ''): (row['total'] as num?)?.toInt() ?? 0,
      };
      _reapplyExtras();
    }).catchError((_) {});
    // Peak & block dates for the station cards — shared via Provider.
    peakDatesStore.load();
    ApiRepository().fetchFlightRiskLatest().then((flightRisk) {
      if (!mounted || seq != _loadSeq) return;
      _flightRiskByCode = (flightRisk['station_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
      _lumoEnabled = flightRisk['lumo_enabled'] != false;
      _reapplyExtras();
    }).catchError((_) {});

    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final from = fromDate ?? todayStr;
      final to = toDate ?? todayStr;

      // Fetch both simultaneously — no flickering
      final results = await Future.wait([
        ApiRepository().fetchAllStations(fromDate: from, toDate: to),
        ApiRepository().fetchAllStations(fromDate: todayStr, toDate: todayStr),
      ]);

      final (rangeStations, rangeFromCache) = results[0];
      final (todayStationsRaw, todayFromCache) = results[1];
      final fetchWasFromCache = rangeFromCache || todayFromCache;

      final stations = [...rangeStations]..sort((a, b) => a.code.compareTo(b.code));
      final todayList = [...todayStationsRaw]..sort((a, b) => a.code.compareTo(b.code));

      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _stations = _withExtras(stations);
        _todayStations = _withExtras(todayList);
        _lastFetched = DateTime.now();
        _loading = false;
        _isOffline = fetchWasFromCache;
      });
    } on UnauthorizedException {
      await ApiConfig.clearToken();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (silent) return; // don't blank out a working screen over a transient background failure
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      RealOverviewScreen(
        onNavigateToTab: _goToTab,
        stations: _stations,
        todayStations: _todayStations,
        loading: _loading,
        error: _error,
        onReload: _loadStations,
        isOffline: _isOffline,
      ),
      const RealAlertsScreen(),
      const DashboardScreen(),
      const LeaksScreen(),
      RealMoreScreen(
        stations: _todayStations,
        loading: _loading,
        error: _error,
        lastFetched: _lastFetched,
        onReload: _loadStations,
        onNavigateToTab: _goToTab,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onTap: _goToTab,
      ),
    );
  }
}