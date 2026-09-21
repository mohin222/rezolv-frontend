import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/leak_item.dart';
import '../data/api_repository.dart';
import '../utils/app_version.dart';
import '../utils/error_messages.dart';

class LeaksScreen extends StatefulWidget {
  const LeaksScreen({super.key});
  @override
  State<LeaksScreen> createState() => _LeaksScreenState();
}

class _LeaksScreenState extends State<LeaksScreen> {
  static const _navy    = Color(0xFF0D2B4E);
  static const _gold    = Color(0xFFC1791C);
  static const _darkRed = Color(0xFFC62828);
  static const _pageSize = 20;

  final _repo = ApiRepository();

  final _stationLayerLink = LayerLink();
  final _stationSearchCtrl = TextEditingController();
  final _stationSearchFocus = FocusNode();
  OverlayEntry? _stationOverlay;
  bool _stationDropdownOpen = false;
  String _selectedStation = '';

  final _hotelLayerLink = LayerLink();
  final _hotelSearchCtrl = TextEditingController();
  final _hotelSearchFocus = FocusNode();
  OverlayEntry? _hotelOverlay;
  bool _hotelDropdownOpen = false;
  String _selectedHotelName = '';
  String _selectedHotelId = '';

  DateTime _selectedDate = DateTime.now();
  List<LeakItem> _allLeaks = [];
  List<String> _stations = [];
  int _visibleCount = _pageSize;
  bool _loading = false;
  String? _error;
  bool _isOffline = false;
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 60);

  static final _apiFmt     = DateFormat('yyyy-MM-dd');
  static final _displayFmt = DateFormat('d MMM yyyy');

  List<LeakItem> get _visibleLeaks {
    final sorted = [..._allLeaks]..sort((a, b) => a.gap.compareTo(b.gap));
    return sorted.take(_visibleCount).toList();
  }

  List<LeakItem> get _uniqueHotels {
    final seen = <int>{};
    return _allLeaks.where((h) => seen.add(h.hotelId)).toList()
      ..sort((a, b) => a.hotelName.compareTo(b.hotelName));
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
    _fetch();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) => _fetch(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _closeStationOverlay();
    _closeHotelOverlay();
    _stationSearchCtrl.dispose();
    _stationSearchFocus.dispose();
    _hotelSearchCtrl.dispose();
    _hotelSearchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    try {
      final codes = await _repo.fetchAirportCodes();
      if (!mounted) return;
      setState(() => _stations = codes.map((c) => c['code'] as String).toList()..sort());
    } catch (_) {}
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _loading = true; _error = null; _visibleCount = _pageSize; });
    try {
      final (leaks, fetchWasFromCache) = await _repo.fetchLeaks(
        date: _apiFmt.format(_selectedDate),
        station: _selectedStation,
        hotelId: _selectedHotelId,
      );
      if (!mounted) return;
      setState(() {
        _allLeaks = leaks;
        _isOffline = fetchWasFromCache;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) return; // keep showing the last good list over a transient background failure
      setState(() => _error = friendlyError(e));
    } finally {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  void _toggleStationOverlay() => _stationDropdownOpen ? _closeStationOverlay() : _openStationOverlay();

  void _openStationOverlay() {
    _stationSearchCtrl.clear();
    setState(() => _stationDropdownOpen = true);
    _stationOverlay = OverlayEntry(
      builder: (_) => _StationOverlay(
        layerLink: _stationLayerLink,
        searchController: _stationSearchCtrl,
        searchFocus: _stationSearchFocus,
        selectedCode: _selectedStation,
        stations: _stations,
        onSelectAll: () {
          setState(() { _selectedStation = ''; _visibleCount = _pageSize; });
          _closeStationOverlay();
          _fetch();
        },
        onSelectStation: (code) {
          setState(() { _selectedStation = code; _visibleCount = _pageSize; });
          _closeStationOverlay();
          _fetch();
        },
        onDismiss: _closeStationOverlay,
      ),
    );
    Overlay.of(context).insert(_stationOverlay!);
  }

  void _closeStationOverlay() {
    _stationOverlay?.remove(); _stationOverlay = null;
    if (mounted) setState(() => _stationDropdownOpen = false);
  }

  void _toggleHotelOverlay() => _hotelDropdownOpen ? _closeHotelOverlay() : _openHotelOverlay();

  void _openHotelOverlay() {
    _hotelSearchCtrl.clear();
    setState(() => _hotelDropdownOpen = true);
    _hotelOverlay = OverlayEntry(
      builder: (_) => _HotelOverlay(
        layerLink: _hotelLayerLink,
        searchController: _hotelSearchCtrl,
        searchFocus: _hotelSearchFocus,
        selectedHotelName: _selectedHotelName,
        hotels: _uniqueHotels,
        onSelectAll: () {
          setState(() { _selectedHotelName = ''; _selectedHotelId = ''; _visibleCount = _pageSize; });
          _closeHotelOverlay();
          _fetch();
        },
        onSelectHotel: (leak) {
          setState(() { _selectedHotelName = leak.hotelName; _selectedHotelId = leak.hotelId.toString(); _visibleCount = _pageSize; });
          _closeHotelOverlay();
          _fetch();
        },
        onDismiss: _closeHotelOverlay,
      ),
    );
    Overlay.of(context).insert(_hotelOverlay!);
  }

  void _closeHotelOverlay() {
    _hotelOverlay?.remove(); _hotelOverlay = null;
    if (mounted) setState(() => _hotelDropdownOpen = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 180)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _navy, onPrimary: Colors.white, onSurface: _navy),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _navy)),
          dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetch();
    }
  }

  void _openFixInRich() async {
    final uri = Uri.parse('https://rich.rezolv.app/#/login');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openEmail(LeakItem leak) async {
    final email = leak.email.isNotEmpty ? leak.email : '';
    final subject = Uri.encodeComponent('Inventory Gap Alert - ${leak.hotelName} (${leak.station})');
    final body = Uri.encodeComponent(
        'Dear Team,\n\nPlease note an inventory gap has been detected for the following hotel:\n\n'
            'Hotel: ${leak.hotelName}\n'
            'Station: ${leak.station}\n'
            'Date: ${leak.date}\n'
            'CM Rooms: ${leak.cmRooms}\n'
            'Extranet Rooms: ${leak.extranetRooms}\n'
            'Gap: ${leak.gap} rooms\n\n'
            'Kindly take necessary action.\n\nRegards,\nRezolv Operations'
    );
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email app found on this device')),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedStation = '';
      _selectedHotelName = '';
      _selectedHotelId = '';
      _selectedDate = DateTime.now();
      _visibleCount = _pageSize;
    });
    _hotelSearchCtrl.clear();
    _stationSearchCtrl.clear();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);

    return GestureDetector(
      onTap: () { _closeStationOverlay(); _closeHotelOverlay(); },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: Column(children: [
          _buildHeader(cardBg, textPrimary, textSecondary),
          _buildFilters(cardBg, textPrimary, textSecondary, borderColor, isDark),
          Expanded(child: _buildBody(textPrimary, textSecondary, isDark)),
        ])),
      ),
    );
  }

  Widget _buildHeader(Color cardBg, Color textPrimary, Color textSecondary) {
    return Container(
      color: cardBg,
      child: Column(children: [
                        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)), child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rezolv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
              Row(children: [
                Text('Leaks · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),

              ]),
            ])),
            if (_isOffline) Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.circle, size: 6, color: Colors.orange),
                const SizedBox(width: 4),
                Text('Offline', style: TextStyle(fontSize: 10.5, color: textSecondary)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.refresh, color: _navy, size: 20), onPressed: _resetFilters, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFilters(Color cardBg, Color textPrimary, Color textSecondary, Color borderColor, bool isDark) {
    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: CompositedTransformTarget(
              link: _stationLayerLink,
              child: GestureDetector(
                onTap: _toggleStationOverlay,
                child: _DropdownTrigger(
                  icon: Icons.flight_takeoff,
                  label: _selectedStation.isEmpty ? 'All stations' : _selectedStation,
                  isSelected: _selectedStation.isNotEmpty,
                  isOpen: _stationDropdownOpen,
                  cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary,
                  onClear: _selectedStation.isEmpty ? null : () { setState(() => _selectedStation = ''); _closeStationOverlay(); _fetch(); },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_displayFmt.format(_selectedDate), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _hotelLayerLink,
          child: GestureDetector(
            onTap: _toggleHotelOverlay,
            child: _DropdownTrigger(
              icon: Icons.hotel_outlined,
              label: _selectedHotelName.isEmpty ? 'Search hotel by name or ID...' : _selectedHotelName,
              isSelected: _selectedHotelName.isNotEmpty,
              isOpen: _hotelDropdownOpen,
              cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary,
              onClear: _selectedHotelName.isEmpty ? null : () {
                setState(() { _selectedHotelName = ''; _selectedHotelId = ''; });
                _closeHotelOverlay();
                _fetch();
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody(Color textPrimary, Color textSecondary, bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _navy));
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded, size: 44, color: textSecondary),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _fetch, style: ElevatedButton.styleFrom(backgroundColor: _navy), child: const Text('Retry', style: TextStyle(color: Colors.white))),
      ]));
    }
    if (_allLeaks.isEmpty) {
      return RefreshIndicator(color: _navy, onRefresh: _fetch, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        const SizedBox(height: 120),
        const Icon(Icons.check_circle_outline_rounded, size: 52, color: Colors.green),
        const SizedBox(height: 12),
        Center(child: Text('No leaks found', style: TextStyle(fontSize: 16, color: textSecondary))),
      ]));
    }
    final visible = _visibleLeaks;
    final hasMore = _visibleCount < _allLeaks.length;
    return RefreshIndicator(
      color: _navy, onRefresh: _fetch,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: visible.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Showing ${visible.length} of ${_allLeaks.length} leaks', style: TextStyle(fontSize: 11, color: textSecondary)));
          }
          final leak = visible[i - 1];
          final isLast = i == visible.length;
          return Column(children: [
            _LeakCard(leak: leak, navy: _navy, gold: _gold, darkRed: _darkRed, isDark: isDark, onEmail: () => _openEmail(leak), onFixRich: _openFixInRich),
            if (isLast && hasMore) ...[
              const SizedBox(height: 10),
              Center(child: OutlinedButton(
                onPressed: () => setState(() => _visibleCount += _pageSize),
                style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _navy), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Load more', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              )),
            ],
          ]);
        },
      ),
    );
  }
}

class _LeakCard extends StatelessWidget {
  final LeakItem leak;
  final Color navy, gold, darkRed;
  final bool isDark;
  final VoidCallback onEmail, onFixRich;
  const _LeakCard({required this.leak, required this.navy, required this.gold, required this.darkRed, required this.isDark, required this.onEmail, required this.onFixRich});

  String _fmtDate(String d) {
    try { return DateFormat('d MMM').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 4, decoration: const BoxDecoration(color: Color(0xFFC62828), borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(leak.hotelName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: navy))),
                Text('${leak.station} · ${_fmtDate(leak.date)}', style: TextStyle(fontSize: 11, color: textSecondary)),
              ]),
              if (leak.starCategory != null && leak.target != null) ...[
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star_rounded, size: 13, color: gold),
                  const SizedBox(width: 2),
                  Text(
                    '${leak.starCategory} Star · Target: ${leak.target} rooms',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gold),
                  ),
                  if (leak.starTargetPct != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${leak.starTargetPct}%)',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: textSecondary),
                    ),
                  ],
                ]),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.flight_takeoff, size: 12, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  leak.distanceKm != null
                      ? '${leak.distanceKm!.toStringAsFixed(1)} km from ${leak.station} airport'
                      : (leak.distanceText != null && leak.distanceText!.isNotEmpty)
                          ? '${leak.distanceText} from ${leak.station} airport'
                          : '—',
                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _StatBox(label: 'CM',       value: '${leak.cmRooms}',       color: navy,    isDark: isDark),
                const SizedBox(width: 6),
                _StatBox(label: 'Extranet', value: '${leak.extranetRooms}', color: gold,    isDark: isDark),
                const SizedBox(width: 6),
                _StatBox(label: 'Gap',      value: '+${leak.gap}',          color: darkRed, isDark: isDark, highlight: true),
              ]),
              const SizedBox(height: 10),
              SizedBox(height: 50, child: Row(children: [
                Expanded(child: _ActionBtn(label: 'Fix in RICH',      icon: Icons.build_outlined,  bg: navy,                    fg: Colors.white,            onTap: onFixRich)),
                const SizedBox(width: 6),
                Expanded(child: _ActionBtn(label: 'Send Email',       icon: Icons.email_outlined,  bg: const Color(0xFFE3F2FD), fg: const Color(0xFF1565C0), onTap: onEmail)),
              ])),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _DropdownTrigger extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected, isOpen;
  final VoidCallback? onClear;
  final Color cardBg, borderColor, textPrimary, textSecondary;
  const _DropdownTrigger({required this.icon, required this.label, required this.isSelected, required this.isOpen, this.onClear, required this.cardBg, required this.borderColor, required this.textPrimary, required this.textSecondary});

  @override
  Widget build(BuildContext context) => Container(
    height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: isOpen ? const Color(0xFF0D2B4E) : borderColor, width: isOpen ? 1.5 : 1)),
    child: Row(children: [
      Icon(icon, size: 17, color: textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? textPrimary : textSecondary))),
      if (onClear != null) GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 16, color: textSecondary)),
      const SizedBox(width: 6),
      Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: textSecondary),
    ]),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool highlight, isDark;
  const _StatBox({required this.label, required this.value, required this.color, required this.isDark, this.highlight = false});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFFCE4E4) : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9.5, color: color.withOpacity(0.7))),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ]),
  ));
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: double.infinity,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: fg)),
      ]),
    ),
  );
}

class _StationOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String selectedCode;
  final List<String> stations;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectStation;
  final VoidCallback onDismiss;
  const _StationOverlay({required this.layerLink, required this.searchController, required this.searchFocus, required this.selectedCode, required this.stations, required this.onSelectAll, required this.onSelectStation, required this.onDismiss});

  @override
  State<_StationOverlay> createState() => _StationOverlayState();
}

class _StationOverlayState extends State<_StationOverlay> {
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
          link: widget.layerLink, showWhenUnlinked: false, offset: const Offset(0, 44),
          child: Material(color: Colors.transparent, child: GestureDetector(onTap: () {},
            child: SizedBox(width: screenWidth - 32, child: _OverlayBox(cardBg: cardBg, borderColor: borderColor, children: [
              _OverlaySearch(controller: widget.searchController, focusNode: widget.searchFocus, inputBg: inputBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary, onChanged: (v) => setState(() => _query = v), onClear: () => setState(() => _query = '')),
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 220), child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                if (_query.isEmpty) ...[
                  _OverlayAllRow(isSelected: widget.selectedCode.isEmpty, label: 'All stations', icon: Icons.public, textPrimary: textPrimary, onTap: widget.onSelectAll),
                  Divider(height: 1, color: borderColor),
                ],
                ..._options.map((code) => InkWell(
                  onTap: () => widget.onSelectStation(code),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                    Expanded(child: Text(code, style: TextStyle(fontSize: 13, fontWeight: widget.selectedCode == code ? FontWeight.w700 : FontWeight.w400, color: widget.selectedCode == code ? const Color(0xFF0D2B4E) : textPrimary))),
                    if (widget.selectedCode == code) const Icon(Icons.check, size: 16, color: Color(0xFF0D2B4E)),
                  ])),
                )),
                if (_options.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No results found', style: TextStyle(color: textSecondary))),
                const SizedBox(height: 6),
              ])),
            ])),
          )),
        ),
      ]),
    );
  }
}

class _HotelOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String selectedHotelName;
  final List<LeakItem> hotels;
  final VoidCallback onSelectAll;
  final ValueChanged<LeakItem> onSelectHotel;
  final VoidCallback onDismiss;
  const _HotelOverlay({required this.layerLink, required this.searchController, required this.searchFocus, required this.selectedHotelName, required this.hotels, required this.onSelectAll, required this.onSelectHotel, required this.onDismiss});

  @override
  State<_HotelOverlay> createState() => _HotelOverlayState();
}

class _HotelOverlayState extends State<_HotelOverlay> {
  String _query = '';

  List<LeakItem> get _options {
    if (_query.isEmpty) return widget.hotels;
    final q = _query.toLowerCase();
    return widget.hotels.where((h) =>
    h.hotelName.toLowerCase().contains(q) ||
        h.hotelId.toString().contains(q)
    ).toList();
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
          link: widget.layerLink, showWhenUnlinked: false, offset: const Offset(0, 44),
          child: Material(color: Colors.transparent, child: GestureDetector(onTap: () {},
            child: SizedBox(width: screenWidth - 32, child: _OverlayBox(cardBg: cardBg, borderColor: borderColor, children: [
              _OverlaySearch(
                controller: widget.searchController,
                focusNode: widget.searchFocus,
                hint: 'Search by name or ID...',
                inputBg: inputBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary,
                onChanged: (v) => setState(() => _query = v),
                onClear: () => setState(() => _query = ''),
              ),
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 220), child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                if (_query.isEmpty) ...[
                  _OverlayAllRow(isSelected: widget.selectedHotelName.isEmpty, label: 'All hotels', icon: Icons.hotel_outlined, textPrimary: textPrimary, onTap: widget.onSelectAll),
                  Divider(height: 1, color: borderColor),
                ],
                ..._options.map((h) => InkWell(
                  onTap: () => widget.onSelectHotel(h),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
                    Expanded(child: Text(
                      h.hotelName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.selectedHotelName == h.hotelName ? FontWeight.w700 : FontWeight.w400,
                        color: widget.selectedHotelName == h.hotelName ? const Color(0xFF0D2B4E) : textPrimary,
                      ),
                    )),
                    if (widget.selectedHotelName == h.hotelName) const Icon(Icons.check, size: 16, color: Color(0xFF0D2B4E)),
                  ])),
                )),
                if (_options.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No results found', style: TextStyle(color: textSecondary))),
                const SizedBox(height: 6),
              ])),
            ])),
          )),
        ),
      ]),
    );
  }
}

class _OverlayBox extends StatelessWidget {
  final List<Widget> children;
  final Color cardBg, borderColor;
  const _OverlayBox({required this.children, required this.cardBg, required this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6))]),
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _OverlaySearch extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final Color inputBg, borderColor, textPrimary, textSecondary;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _OverlaySearch({required this.controller, required this.focusNode, this.hint = 'Search...', required this.inputBg, required this.borderColor, required this.textPrimary, required this.textSecondary, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Container(
      height: 38,
      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
      child: Row(children: [
        const SizedBox(width: 10),
        Icon(Icons.search, size: 16, color: textSecondary),
        const SizedBox(width: 6),
        Expanded(child: TextField(
          controller: controller, focusNode: focusNode, autofocus: true,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontSize: 13, color: textSecondary), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          onChanged: onChanged,
        )),
        if (controller.text.isNotEmpty)
          GestureDetector(onTap: () { controller.clear(); onClear(); }, child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.close, size: 16, color: textSecondary))),
      ]),
    ),
  );
}

class _OverlayAllRow extends StatelessWidget {
  final bool isSelected;
  final String label;
  final IconData icon;
  final Color textPrimary;
  final VoidCallback onTap;
  const _OverlayAllRow({required this.isSelected, required this.label, required this.icon, required this.textPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF0D2B4E)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary))),
      if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFF0D2B4E)),
    ])),
  );
}