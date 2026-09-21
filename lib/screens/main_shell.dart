import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_repository.dart';
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

  Future<void> _loadStations({String? fromDate, String? toDate, String? station, bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
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

      var stations = [...rangeStations]..sort((a, b) => a.code.compareTo(b.code));
      var todayList = [...todayStationsRaw]..sort((a, b) => a.code.compareTo(b.code));

      // Vehicle counts are a nice-to-have on the cards — never let a
      // Transportation outage block the Inventory screen from loading.
      try {
        final vehicleRows = await ApiRepository().fetchTransportationOverview();
        final vehicleByCode = <String, int>{
          for (final row in vehicleRows)
            (row['code'] as String? ?? ''): (row['total'] as num?)?.toInt() ?? 0,
        };
        stations = stations.map((s) => s.withVehicleCount(vehicleByCode[s.code])).toList();
        todayList = todayList.map((s) => s.withVehicleCount(vehicleByCode[s.code])).toList();
      } catch (_) {
        // leave vehicleCount null — card just omits the badge
      }

      // Flight-risk counts are a nice-to-have on the cards too — never let
      // a missing/stale Think Lumo upload block the Inventory screen.
      try {
        final flightRisk = await ApiRepository().fetchFlightRiskLatest();
        final breakdown = (flightRisk['station_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
        RealStation applyFlightRisk(RealStation s) {
          final entry = (breakdown[s.code] as Map?)?.cast<String, dynamic>();
          if (entry == null) return s;
          return s.withFlightRisk(entry['tomorrow'] as int?, entry['next_5_days'] as int?);
        }
        stations = stations.map(applyFlightRisk).toList();
        todayList = todayList.map(applyFlightRisk).toList();
      } catch (_) {
        // leave flight-risk fields null — card just omits the badge
      }

      if (!mounted) return;
      setState(() {
        _stations = stations;
        _todayStations = todayList;
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