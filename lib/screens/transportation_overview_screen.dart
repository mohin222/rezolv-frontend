import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transportation_trips_screen.dart';
import 'transportation_dashboard_screen.dart';
import 'transportation_more_screen.dart';
import '../widgets/transportation_bottom_nav.dart';
import '../data/api_repository.dart';
import 'transportation_station_detail_screen.dart';
import '../utils/app_version.dart';

class TransportationShell extends StatefulWidget {
  const TransportationShell({super.key});

  @override
  State<TransportationShell> createState() => _TransportationShellState();
}

class _TransportationShellState extends State<TransportationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const TransportationOverviewScreen(),
      const TransportationTripsScreen(),
      const TransportationDashboardScreen(),
      const TransportationMoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: TransportationBottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _StationVehicles {
  final String code;
  final String city;
  final int available;
  final int total;
  final int depots;
  final int companyOwned;
  final int outsourced;
  final Map<String, int> typeMix; // vehicle type -> count

  const _StationVehicles({
    required this.code,
    required this.city,
    required this.available,
    required this.total,
    required this.depots,
    required this.companyOwned,
    required this.outsourced,
    required this.typeMix,
  });
}

class TransportationOverviewScreen extends StatefulWidget {
  const TransportationOverviewScreen({super.key});

  @override
  State<TransportationOverviewScreen> createState() => _TransportationOverviewScreenState();
}

class _TransportationOverviewScreenState extends State<TransportationOverviewScreen> {
  static const _navy = Color(0xFF1C1C1E);
  static const _gold = Color(0xFF6E6E6E);

  static final DateFormat _displayDateFmt = DateFormat('d MMM yyyy');

  Map<String, String> _stationCities = {};
  List<_StationVehicles> _stations = [];
  bool _loading = true;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));

  final _stationLayerLink = LayerLink();
  final _stationSearchCtrl = TextEditingController();
  final _stationSearchFocus = FocusNode();
  OverlayEntry? _stationOverlay;
  bool _stationDropdownOpen = false;
  String _selectedStationCode = '';

  List<_StationVehicles> get _displayedStations => _selectedStationCode.isEmpty
      ? _stations
      : _stations.where((s) => s.code == _selectedStationCode).toList();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning, team';
    if (hour >= 12 && hour < 17) return 'Good afternoon, team';
    if (hour >= 17 && hour < 21) return 'Good evening, team';
    return 'Good night, team';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closeStationOverlay();
    _stationSearchCtrl.dispose();
    _stationSearchFocus.dispose();
    super.dispose();
  }

  void _toggleStationOverlay() => _stationDropdownOpen ? _closeStationOverlay() : _openStationOverlay();

  void _openStationOverlay() {
    _stationSearchCtrl.clear();
    setState(() => _stationDropdownOpen = true);
    _stationOverlay = OverlayEntry(
      builder: (_) => _StationFilterOverlay(
        layerLink: _stationLayerLink,
        searchController: _stationSearchCtrl,
        searchFocus: _stationSearchFocus,
        selectedCode: _selectedStationCode,
        stations: _stationCities.keys.toList(),
        onSelectAll: () {
          setState(() => _selectedStationCode = '');
          _closeStationOverlay();
        },
        onSelectStation: (code) {
          setState(() => _selectedStationCode = code);
          _closeStationOverlay();
        },
        onDismiss: _closeStationOverlay,
      ),
    );
    Overlay.of(context).insert(_stationOverlay!);
  }

  void _closeStationOverlay() {
    _stationOverlay?.remove();
    _stationOverlay = null;
    if (mounted) setState(() => _stationDropdownOpen = false);
  }

  Future<DateTime?> _showStyledDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required String helpText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : initialDate.isAfter(lastDate)
          ? lastDate
          : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      confirmText: 'CONFIRM',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _navy,
            onPrimary: Colors.white,
          ),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _navy)),
          dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await _showStyledDatePicker(
      initialDate: _fromDate,
      firstDate: now.subtract(const Duration(days: 180)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'SELECT FROM DATE',
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
    });
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await _showStyledDatePicker(
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'SELECT TO DATE',
    );
    if (picked == null) return;
    setState(() => _toDate = picked);
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textSecondary, letterSpacing: 0.7)),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(
                _displayDateFmt.format(date),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy),
              )),
              Icon(Icons.calendar_today_rounded, size: 14, color: textSecondary),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final codes = await ApiRepository().fetchAirportCodes();
      final cities = {
        for (final c in codes)
          (c['code'] as String): (c['city'] as String? ?? '')
      };
      final rows = await ApiRepository().fetchTransportationOverview();
      if (!mounted) return;
      final byCode = {for (final r in rows) r['code'] as String: r};
      setState(() {
        _stationCities = cities;
        _stations = cities.entries.map((e) {
          final row = byCode[e.key];
          final total = (row?['total'] as num?)?.toInt() ?? 0;
          final available = (row?['available'] as num?)?.toInt() ?? 0;
          final depots = (row?['depots'] as num?)?.toInt() ?? 0;
          return _StationVehicles(
            code: e.key,
            city: e.value,
            available: available,
            total: total,
            depots: depots,
            companyOwned: 0,
            outsourced: 0,
            typeMix: total > 0 ? {'Vehicles': total} : const {},
          );
        }).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stations = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    final totalAvailable = _stations.fold<int>(0, (s, e) => s + e.available);
    final totalDepots = _stations.fold<int>(0, (s, e) => s + e.depots);

    return GestureDetector(
      onTap: _closeStationOverlay,
      child: Scaffold(
      drawer: _buildDrawer(context, textPrimary),
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Builder(builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: textPrimary, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )),
              const SizedBox(width: 8),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)),
                child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rezolv', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                Text('Transportation · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
              ])),
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary, size: 20),
                onPressed: _load,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              Row(children: [
                Icon(Icons.circle, size: 7, color: _loading ? Colors.orange : Colors.green),
                const SizedBox(width: 5),
                Text(_loading ? 'Syncing' : 'Live', style: TextStyle(fontSize: 11, color: textPrimary)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1C1C1E), Color(0xFF20344A)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_getGreeting(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('$totalDepots vendors live · $totalAvailable vehicles available right now.', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CompositedTransformTarget(
              link: _stationLayerLink,
              child: GestureDetector(
                onTap: _toggleStationOverlay,
                child: _StationFilterTrigger(
                  label: _selectedStationCode.isEmpty ? 'All stations' : _selectedStationCode,
                  isSelected: _selectedStationCode.isNotEmpty,
                  isOpen: _stationDropdownOpen,
                  cardBg: theme.cardColor,
                  borderColor: isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED),
                  textPrimary: textPrimary, textSecondary: textSecondary,
                  onClear: _selectedStationCode.isEmpty ? null : () { setState(() => _selectedStationCode = ''); _closeStationOverlay(); },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _buildDateField(
                label: 'FROM', date: _fromDate, onTap: _pickFromDate,
                cardBg: theme.cardColor, textPrimary: textPrimary,
                textSecondary: textSecondary, borderColor: isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildDateField(
                label: 'TO', date: _toDate, onTap: _pickToDate,
                cardBg: theme.cardColor, textPrimary: textPrimary,
                textSecondary: textSecondary, borderColor: isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(
                _selectedStationCode.isEmpty
                    ? 'STATION AVAILABILITY · LIVE (RIDE OPS)'
                    : '${_displayedStations.length} RESULT${_displayedStations.length == 1 ? '' : 'S'} FOR "$_selectedStationCode"',
                style: TextStyle(fontSize: 10.5, color: textSecondary, letterSpacing: 0.8),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _displayedStations.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TransportationStationDetailScreen(code: _displayedStations[i].code, city: _displayedStations[i].city),
                  )),
                  child: _VehicleStationCard(station: _displayedStations[i], isDark: isDark),
                ),
              ),
            ),
          ),
        ]),
      ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Color textPrimary) {
    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(color: _navy),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rezolv', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Transportation', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              ])),
            ]),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.apartment_rounded, color: _navy),
            title: Text('Inventory', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
        ]),
      ),
    );
  }
}

class _VehicleStationCard extends StatelessWidget {
  final _StationVehicles station;
  final bool isDark;
  const _VehicleStationCard({required this.station, required this.isDark});

  static const _gold = Color(0xFF6E6E6E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    final fillPct = station.total == 0 ? 0.0 : station.available / station.total * 100;

    final statusColor = station.total == 0
        ? Colors.grey
        : fillPct >= 60
            ? const Color(0xFF2E7D32)
            : fillPct >= 30
                ? const Color(0xFFE9A227)
                : const Color(0xFFD64545);

    const typeChipColors = [
      (bg: Color(0xFFE3F2FD), fg: Color(0xFF1565C0)),
      (bg: Color(0xFFF3E5F5), fg: Color(0xFF7B1FA2)),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 4, decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(station.code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                  Text(station.city, style: TextStyle(fontSize: 10.5, color: textSecondary)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
                  child: Text('${station.depots} vendors', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 56, height: 56,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 56, height: 56, child: CircularProgressIndicator(
                      value: (fillPct / 100).clamp(0.0, 1.0),
                      strokeWidth: 4.5,
                      backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    )),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${station.available}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                      Text('AVAIL', style: TextStyle(fontSize: 6.5, color: textSecondary)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(children: [
                  _statRow('Total fleet', '${station.total}', textPrimary, textSecondary),
                  _statRow('Utilization', '${fillPct.toStringAsFixed(0)}%', statusColor, textSecondary),
                  _statRow('Vendors', '${station.depots}', textPrimary, textSecondary),
                ])),
              ]),
              const SizedBox(height: 4),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: dividerColor)),
              Text('VEHICLE TYPE', style: TextStyle(fontSize: 8.5, color: textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Row(children: station.typeMix.entries.toList().asMap().entries.map((entry) {
                final palette = typeChipColors[entry.key % typeChipColors.length];
                final e = entry.value;
                return Expanded(child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(8)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.key, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: palette.fg)),
                    const SizedBox(height: 2),
                    Text('${e.value}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.fg)),
                  ]),
                ));
              }).toList()),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor)),
      ]),
    );
  }
}

class _StationFilterTrigger extends StatelessWidget {
  final String label;
  final bool isSelected, isOpen;
  final VoidCallback? onClear;
  final Color cardBg, borderColor, textPrimary, textSecondary;
  const _StationFilterTrigger({required this.label, required this.isSelected, required this.isOpen, this.onClear, required this.cardBg, required this.borderColor, required this.textPrimary, required this.textSecondary});

  @override
  Widget build(BuildContext context) => Container(
    height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isOpen ? const Color(0xFF1C1C1E) : borderColor, width: isOpen ? 1.5 : 1),
    ),
    child: Row(children: [
      Icon(Icons.flight_takeoff, size: 17, color: textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? textPrimary : textSecondary))),
      if (onClear != null) GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 16, color: textSecondary)),
      const SizedBox(width: 6),
      Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: textSecondary),
    ]),
  );
}

class _StationFilterOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String selectedCode;
  final List<String> stations;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectStation;
  final VoidCallback onDismiss;
  const _StationFilterOverlay({required this.layerLink, required this.searchController, required this.searchFocus, required this.selectedCode, required this.stations, required this.onSelectAll, required this.onSelectStation, required this.onDismiss});

  @override
  State<_StationFilterOverlay> createState() => _StationFilterOverlayState();
}

class _StationFilterOverlayState extends State<_StationFilterOverlay> {
  String _query = '';
  List<String> get _options {
    if (_query.isEmpty) return widget.stations;
    final q = _query.toUpperCase();
    return widget.stations.where((s) => s.toUpperCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : const Color(0xFFE9EAED);
    final inputBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade500;

    return GestureDetector(
      behavior: HitTestBehavior.translucent, onTap: widget.onDismiss,
      child: Stack(children: [
        CompositedTransformFollower(
          link: widget.layerLink, showWhenUnlinked: false, offset: const Offset(0, 50),
          child: Material(color: Colors.transparent, child: GestureDetector(onTap: () {},
            child: SizedBox(width: screenWidth - 32, child: Container(
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
                    child: Row(children: [
                      const SizedBox(width: 10),
                      Icon(Icons.search, size: 16, color: textSecondary),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(
                        controller: widget.searchController, focusNode: widget.searchFocus, autofocus: true,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(hintText: 'Search station...', hintStyle: TextStyle(fontSize: 13, color: textSecondary), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        onChanged: (v) => setState(() => _query = v),
                      )),
                      if (widget.searchController.text.isNotEmpty)
                        GestureDetector(onTap: () { widget.searchController.clear(); setState(() => _query = ''); }, child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.close, size: 16, color: textSecondary))),
                    ]),
                  ),
                ),
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 260), child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                  if (_query.isEmpty) ...[
                    InkWell(
                      onTap: widget.onSelectAll,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                        const Icon(Icons.public, size: 16, color: Color(0xFF1C1C1E)),
                        const SizedBox(width: 10),
                        Expanded(child: Text('All stations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary))),
                        if (widget.selectedCode.isEmpty) const Icon(Icons.check, size: 16, color: Color(0xFF1C1C1E)),
                      ])),
                    ),
                    Divider(height: 1, color: borderColor),
                  ],
                  ..._options.map((code) => InkWell(
                    onTap: () => widget.onSelectStation(code),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                      Expanded(child: Text(code, style: TextStyle(fontSize: 13, fontWeight: widget.selectedCode == code ? FontWeight.w700 : FontWeight.w400, color: widget.selectedCode == code ? const Color(0xFF1C1C1E) : textPrimary))),
                      if (widget.selectedCode == code) const Icon(Icons.check, size: 16, color: Color(0xFF1C1C1E)),
                    ])),
                  )),
                  if (_options.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No results found', style: TextStyle(color: textSecondary))),
                  const SizedBox(height: 6),
                ])),
              ]),
            )),
          )),
        ),
      ]),
    );
  }
}
