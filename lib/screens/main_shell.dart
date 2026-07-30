import 'package:flutter/material.dart';
import '../data/api_repository.dart';
import '../data/api_config.dart';
import '../models/real_station.dart';
import 'real_overview_screen.dart';
import 'leaks_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // Load with default date range (today + 2 days) immediately
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final twoDaysLater = now.add(const Duration(days: 2));
    final toStr = '${twoDaysLater.year}-${twoDaysLater.month.toString().padLeft(2, '0')}-${twoDaysLater.day.toString().padLeft(2, '0')}';
    _loadStations(fromDate: todayStr, toDate: toStr);
  }

  Future<void> _loadStations({String? fromDate, String? toDate, String? station}) async {
    setState(() { _loading = true; _error = null; });
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

      final stations = results[0]..sort((a, b) => a.code.compareTo(b.code));
      final todayList = results[1]..sort((a, b) => a.code.compareTo(b.code));

      if (!mounted) return;
      setState(() {
        _stations = stations;
        _todayStations = todayList;
        _lastFetched = DateTime.now();
        _loading = false;
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
      setState(() { _error = e.toString(); _loading = false; });
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
      ),
      const RealAlertsScreen(),
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