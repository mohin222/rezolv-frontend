import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/real_station.dart';
import '../widgets/real_station_card.dart';
import 'real_station_drilldown_screen.dart';
import '../utils/app_version.dart';

class RealOverviewScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;
  final List<RealStation> stations;
  final List<RealStation> todayStations; // for banner only
  final bool loading;
  final String? error;
  final Future<void> Function({String? fromDate, String? toDate}) onReload;
  final bool isOffline;

  const RealOverviewScreen({
    super.key,
    required this.onNavigateToTab,
    required this.stations,
    required this.todayStations,
    required this.loading,
    required this.error,
    required this.onReload,
    this.isOffline = false,
  });

  @override
  State<RealOverviewScreen> createState() => _RealOverviewScreenState();
}

class _RealOverviewScreenState extends State<RealOverviewScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<RealStation> _cachedAllStations = [];

  double _collapseProgress = 0.0;
  static const double _collapseDistance = 90.0;
  static const int _pageSize = 15;
  int _visibleCount = _pageSize;

  String? _selectedCode;
  String? _selectedCity;
  bool _dropdownOpen = false;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));

  static final DateFormat _apiDateFmt = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFmt = DateFormat('d MMM yyyy');

  static const _navy = Color(0xFF0D2B4E);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(RealOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always update cached stations from todayStations for dropdown
    if (widget.todayStations.isNotEmpty) {
      _cachedAllStations = List<RealStation>.from(widget.todayStations);
    }
  }

  @override
  void dispose() {
    _closeOverlay();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset.clamp(0.0, _collapseDistance);
    final progress = offset / _collapseDistance;
    if ((progress - _collapseProgress).abs() > 0.01) {
      setState(() => _collapseProgress = progress);
    }
  }

  void _resetDates() {
    setState(() {
      _fromDate = DateTime.now();
      _toDate = DateTime.now().add(const Duration(days: 1));
    });
  }

  void _loadMore() {
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, _filteredStations.length);
    });
  }

  List<RealStation> get _filteredStations {
    if (_selectedCode == null || _selectedCode!.isEmpty) return widget.stations;
    return widget.stations
        .where((s) => s.code.toUpperCase() == _selectedCode!.toUpperCase())
        .toList();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning, team';
    if (hour >= 12 && hour < 17) return 'Good afternoon, team';
    if (hour >= 17 && hour < 21) return 'Good evening, team';
    return 'Good night, team';
  }

  void _toggleOverlay() => _dropdownOpen ? _closeOverlay() : _openOverlay();

  void _openOverlay() {
    _searchController.clear();
    setState(() => _dropdownOpen = true);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => _OverlayDropdown(
        layerLink: _layerLink,
        searchController: _searchController,
        searchFocus: _searchFocus,
        selectedCode: _selectedCode,
        getOptions: () {
          final source = _cachedAllStations.isNotEmpty
              ? _cachedAllStations
              : widget.todayStations;
          final list = List<RealStation>.from(source);
          list.sort((a, b) => a.code.compareTo(b.code));
          return list;
        },
        onSelectAll: () {
          setState(() {
            _selectedCode = null;
            _selectedCity = null;
            _visibleCount = _pageSize;
          });
          _closeOverlay();
          widget.onReload(
            fromDate: _apiDateFmt.format(_fromDate),
            toDate: _apiDateFmt.format(_toDate),
          );
        },
        onSelectStation: (s) {
          setState(() {
            _selectedCode = s.code;
            _selectedCity = s.cityLabel;
            _visibleCount = _pageSize;
          });
          _closeOverlay();
          widget.onReload(
            fromDate: _apiDateFmt.format(_fromDate),
            toDate: _apiDateFmt.format(_toDate),
          );
        },
        onDismiss: _closeOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _dropdownOpen = false);
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
    widget.onReload(
      fromDate: _apiDateFmt.format(_fromDate),
      toDate: _apiDateFmt.format(_toDate),
    );
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
    widget.onReload(
      fromDate: _apiDateFmt.format(_fromDate),
      toDate: _apiDateFmt.format(_toDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);
    final bannerOpacity = (1 - _collapseProgress * 1.6).clamp(0.0, 1.0);

    // Use todayStations for banner — always shows today's data
    final bannerStations = widget.todayStations.isNotEmpty
        ? widget.todayStations
        : _cachedAllStations;

    return Scaffold(
      body: GestureDetector(
      onTap: () { if (_dropdownOpen) _closeOverlay(); },
      child: Container(
        color: bg,
        child: SafeArea(
          child: Column(children: [

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)),
                  child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rezolv', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  Text('Inventory Control · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
                ])),
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(children: [
                      Icon(Icons.circle, size: 7, color: widget.isOffline ? Colors.orange : Colors.green),
                      const SizedBox(width: 5),
                      Text(widget.isOffline ? 'Offline' : 'RICH · Live', style: TextStyle(fontSize: 11, color: textPrimary)),
                    ]),
                    if (!widget.isOffline) Text('Real-time', style: TextStyle(fontSize: 10, color: textSecondary)),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: _navy, size: 20),
                    onPressed: () {
                      _resetDates();
                      setState(() { _selectedCode = null; _selectedCity = null; });
                      widget.onReload(
                        fromDate: _apiDateFmt.format(DateTime.now()),
                        toDate: _apiDateFmt.format(DateTime.now().add(const Duration(days: 1))),
                      );
                    },
                    padding: const EdgeInsets.only(left: 6),
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ]),
            ),

            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: (1 - _collapseProgress).clamp(0.0, 1.0),
                child: Opacity(
                  opacity: bannerOpacity,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(_getGreeting(), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        bannerStations.isEmpty
                            ? 'Connecting to live data...'
                            : '${bannerStations.length} stations live · ${bannerStations.fold(0, (sum, s) => sum + s.hotelCount)} hotels, '
                            '${bannerStations.fold(0, (sum, s) => sum + s.roomsToday)} rooms available right now.',
                        style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.25),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(children: [
                CompositedTransformTarget(
                  link: _layerLink,
                  child: GestureDetector(
                    onTap: _toggleOverlay,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _dropdownOpen ? _navy : borderColor,
                          width: _dropdownOpen ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.flight_takeoff, size: 17, color: textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _selectedCode == null ? 'All stations' : '$_selectedCode - ${_selectedCity ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedCode == null ? FontWeight.w400 : FontWeight.w600,
                            color: _selectedCode == null ? textSecondary : textPrimary,
                          ),
                        )),
                        if (_selectedCode != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCode = null;
                                _selectedCity = null;
                                _visibleCount = _pageSize;
                              });
                              _closeOverlay();
                              widget.onReload(
                                fromDate: _apiDateFmt.format(_fromDate),
                                toDate: _apiDateFmt.format(_toDate),
                              );
                            },
                            child: Icon(Icons.close, size: 16, color: textSecondary),
                          ),
                        const SizedBox(width: 6),
                        Icon(_dropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: textSecondary),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _buildDateField(
                    label: 'FROM', date: _fromDate, onTap: _pickFromDate,
                    cardBg: cardBg, textPrimary: textPrimary,
                    textSecondary: textSecondary, borderColor: borderColor,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDateField(
                    label: 'TO', date: _toDate, onTap: _pickToDate,
                    cardBg: cardBg, textPrimary: textPrimary,
                    textSecondary: textSecondary, borderColor: borderColor,
                  )),
                ]),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Row(children: [
                Text(
                  _selectedCode == null
                      ? 'STATION OVERVIEW · LIVE'
                      : '${_filteredStations.length} RESULT${_filteredStations.length == 1 ? '' : 'S'} FOR "$_selectedCode"',
                  style: TextStyle(fontSize: 10.5, color: textSecondary, letterSpacing: 0.8),
                ),
              ]),
            ),

            Expanded(child: _buildBody(textPrimary, textSecondary)),
          ]),
        ),
      ),
      ),
    );
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

  Widget _buildBody(Color textPrimary, Color textSecondary) {
    if (widget.loading) return const Center(child: CircularProgressIndicator());

    if (widget.error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, color: textSecondary, size: 48),
          const SizedBox(height: 12),
          Text('Could not reach the server', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text(widget.error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _resetDates();
              widget.onReload(
                fromDate: _apiDateFmt.format(DateTime.now()),
                toDate: _apiDateFmt.format(DateTime.now().add(const Duration(days: 1))),
              );
            },
            child: const Text('Retry'),
          ),
        ]),
      ));
    }

    final filtered = _filteredStations;

    if (filtered.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, color: textSecondary, size: 40),
          const SizedBox(height: 10),
          Text(
            _selectedCode == null ? 'No stations with hotels right now.' : 'No station found for "$_selectedCode"',
            style: TextStyle(color: textSecondary),
          ),
        ]),
      ));
    }

    final visibleStations = filtered.take(_visibleCount).toList();
    final hasMore = _visibleCount < filtered.length;

    return RefreshIndicator(
      onRefresh: () {
        _resetDates();
        setState(() { _selectedCode = null; _selectedCity = null; });
        return widget.onReload(
          fromDate: _apiDateFmt.format(DateTime.now()),
          toDate: _apiDateFmt.format(DateTime.now().add(const Duration(days: 1))),
        );
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        itemCount: visibleStations.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == visibleStations.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(child: OutlinedButton(
                onPressed: _loadMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Load more', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              )),
            );
          }
          final station = visibleStations[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RealStationDrilldownScreen(
                station: station,
                onNavigateToTab: widget.onNavigateToTab,
                fromDate: _apiDateFmt.format(_fromDate),
                toDate: _apiDateFmt.format(_toDate),
              ),
            )),
            child: RealStationCard(station: station),
          );
        },
      ),
    );
  }
}

class _OverlayDropdown extends StatefulWidget {
  final LayerLink layerLink;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String? selectedCode;
  final List<RealStation> Function() getOptions;
  final VoidCallback onSelectAll;
  final ValueChanged<RealStation> onSelectStation;
  final VoidCallback onDismiss;

  const _OverlayDropdown({
    required this.layerLink,
    required this.searchController,
    required this.searchFocus,
    required this.selectedCode,
    required this.getOptions,
    required this.onSelectAll,
    required this.onSelectStation,
    required this.onDismiss,
  });

  @override
  State<_OverlayDropdown> createState() => _OverlayDropdownState();
}

class _OverlayDropdownState extends State<_OverlayDropdown> {
  String _query = '';

  List<RealStation> get _options {
    final all = widget.getOptions();
    if (_query.isEmpty) return all;
    final q = _query.toUpperCase();
    return all.where((s) => s.code.toUpperCase().contains(q) || s.cityLabel.toUpperCase().contains(q)).toList();
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
      behavior: HitTestBehavior.translucent,
      onTap: widget.onDismiss,
      child: Stack(children: [
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {},
              child: SizedBox(
                width: screenWidth - 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
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
                            controller: widget.searchController,
                            focusNode: widget.searchFocus,
                            autofocus: true,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          )),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () { setState(() => _query = ''); widget.searchController.clear(); },
                              child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.close, size: 16, color: textSecondary)),
                            ),
                        ]),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
                        if (_query.isEmpty)
                          InkWell(
                            onTap: widget.onSelectAll,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                const Icon(Icons.public, size: 16, color: Color(0xFF0D2B4E)),
                                const SizedBox(width: 10),
                                Expanded(child: Text('All stations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary))),
                                if (widget.selectedCode == null) const Icon(Icons.check, size: 16, color: Color(0xFF0D2B4E)),
                              ]),
                            ),
                          ),
                        if (_query.isEmpty) Divider(height: 1, color: borderColor),
                        ..._options.map((s) {
                          final isSel = widget.selectedCode == s.code;
                          return InkWell(
                            onTap: () => widget.onSelectStation(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${s.code} - ${s.cityLabel}', style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.w700 : FontWeight.w400, color: isSel ? const Color(0xFF0D2B4E) : textPrimary)),
                                  Text('${s.hotelCount} hotels · ${s.roomsToday} rooms', style: TextStyle(fontSize: 11, color: textSecondary)),
                                ])),
                                if (isSel) const Icon(Icons.check, size: 16, color: Color(0xFF0D2B4E)),
                              ]),
                            ),
                          );
                        }),
                        if (_options.isEmpty)
                          Padding(padding: const EdgeInsets.all(16), child: Text('No matching station', style: TextStyle(color: textSecondary))),
                        const SizedBox(height: 6),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}