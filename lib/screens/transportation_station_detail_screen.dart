import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_repository.dart';

class TransportationStationDetailScreen extends StatefulWidget {
  final String code;
  final String city;
  const TransportationStationDetailScreen({super.key, required this.code, required this.city});

  @override
  State<TransportationStationDetailScreen> createState() => _TransportationStationDetailScreenState();
}

class _TransportationStationDetailScreenState extends State<TransportationStationDetailScreen> {
  static const _navy = Color(0xFF1C1C1E);
  static const _gold = Color(0xFF6E6E6E);
  static const _green = Color(0xFF2E7D32);

  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedVendorKey;

  bool _loading = true;
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _vehicles = [];
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ApiRepository().fetchTransportationStationDetail(widget.code);
      if (!mounted) return;
      setState(() {
        _vendors = (data['vendors'] as List? ?? []).cast<Map<String, dynamic>>();
        _vehicles = (data['vehicles'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent) return; // keep showing the last good list over a transient background failure
      setState(() {
        _vendors = [];
        _vehicles = [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    var result = _vehicles;
    if (_selectedVendorKey != null) {
      result = result.where((v) => _keyFor(v['vendor'] as String?, v['tenant'] as String?) == _selectedVendorKey).toList();
    }
    if (_query.isEmpty) return result;
    final q = _query.toLowerCase();
    return result.where((v) =>
        '${v['plate']}'.toLowerCase().contains(q) ||
        '${v['type']}'.toLowerCase().contains(q) ||
        '${v['vendor']}'.toLowerCase().contains(q)
    ).toList();
  }

  Map<String, int> get _typeCounts {
    final counts = <String, int>{};
    for (final v in _vehicles) {
      final type = (v['type'] as String?) ?? 'Other';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  static String _keyFor(String? name, String? tenant) {
    final n = name?.trim().isNotEmpty == true ? name!.trim() : 'Unknown';
    final t = tenant?.trim() ?? '';
    return t.isEmpty ? n : '$n ($t)';
  }

  // Vehicles grouped under their vendor, in the same order as the vendor
  // summary cards above — so the user never has to search which vehicle
  // belongs to which vendor, it's just labelled right there.
  Map<String, List<Map<String, dynamic>>> _groupedByVendor(List<Map<String, dynamic>> vehicles) {
    final orderedKeys = _vendors.map((v) => _keyFor(v['name'] as String?, v['tenant'] as String?)).toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final v in vehicles) {
      groups.putIfAbsent(_keyFor(v['vendor'] as String?, v['tenant'] as String?), () => []).add(v);
    }
    final ordered = <String, List<Map<String, dynamic>>>{};
    for (final key in orderedKeys) {
      if (groups.containsKey(key)) ordered[key] = groups.remove(key)!;
    }
    ordered.addAll(groups); // any leftover vendor not in the summary list
    return ordered;
  }

  IconData _vendorIcon(int index) {
    const icons = [Icons.storefront_rounded, Icons.local_shipping_outlined, Icons.apartment_rounded];
    return icons[index % icons.length];
  }

  static const _palette = [
    (bg: Color(0xFFE3F2FD), fg: Color(0xFF1565C0)),
    (bg: Color(0xFFF3E5F5), fg: Color(0xFF7B1FA2)),
  ];

  // Same palette entry a vendor's summary card uses, looked up by its key —
  // so a vehicle's accent color always matches its vendor's card color.
  ({Color bg, Color fg}) _paletteFor(String vendorKey) {
    final index = _vendors.indexWhere((v) => _keyFor(v['name'] as String?, v['tenant'] as String?) == vendorKey);
    return _palette[(index < 0 ? 0 : index) % _palette.length];
  }

  // Keyword → icon for common vehicle types, checked in order. One fixed
  // color is used for every type — only the icon tells them apart.
  static const _typeIcons = [
    (keyword: 'luxury', icon: Icons.diamond_rounded),
    (keyword: 'coach',  icon: Icons.directions_bus_filled_rounded),
    (keyword: 'bus',    icon: Icons.directions_bus_rounded),
    (keyword: 'muv',    icon: Icons.airport_shuttle_rounded),
    (keyword: 'suv',    icon: Icons.directions_car_filled_rounded),
    (keyword: 'sedan',  icon: Icons.directions_car_rounded),
  ];

  static const _typeBg = Color(0xFFFDF6E3);
  static const _typeFg = Color(0xFFB8860B);

  ({IconData icon, Color bg, Color fg}) _vehicleTypeStyle(String type) {
    final lower = type.toLowerCase();
    for (final s in _typeIcons) {
      if (lower.contains(s.keyword)) return (icon: s.icon, bg: _typeBg, fg: _typeFg);
    }
    return (icon: Icons.directions_car_filled_rounded, bg: _typeBg, fg: _typeFg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);
    final cardBg = theme.cardColor;
    final borderColor = isDark ? Colors.grey.shade800 : const Color(0xFFE9EAED);
    final filtered = _filteredVehicles;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(9)),
                child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rezolv', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                Text('Station Detail', style: TextStyle(fontSize: 11, color: textSecondary)),
              ])),
              Row(children: [
                Icon(Icons.circle, size: 7, color: _loading ? Colors.orange : Colors.green),
                const SizedBox(width: 5),
                Text(_loading ? 'Syncing' : 'Live', style: TextStyle(fontSize: 11, color: textPrimary)),
              ]),
              IconButton(
                icon: Icon(Icons.refresh, color: textPrimary, size: 20),
                onPressed: _load,
              ),
            ]),
          ),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFF1C1C1E), Color(0xFF20344A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(widget.city, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                        ])),
                        _headerStat('${_vehicles.length}', 'Vehicles'),
                        const SizedBox(width: 22),
                        _headerStat('${_vendors.length}', 'Vendors'),
                      ]),
                    ),

                    if (_vehicles.isEmpty) ...[
                      const SizedBox(height: 60),
                      Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.directions_car_outlined, size: 40, color: textSecondary),
                          const SizedBox(height: 10),
                          Text('No live vehicles at this station yet', style: TextStyle(fontSize: 13, color: textSecondary)),
                        ]),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Row(children: [
                          Icon(Icons.search, size: 18, color: textSecondary),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search plate, type, or vendor...',
                              hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => setState(() => _query = v),
                          )),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                              child: Icon(Icons.close, size: 16, color: textSecondary),
                            ),
                        ]),
                      ),

                      const SizedBox(height: 18),
                      Text('VENDORS · LIVE (RIDE OPS)', style: TextStyle(fontSize: 10.5, color: textSecondary, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      ..._vendors.asMap().entries.map((entry) {
                        final palette = _palette[entry.key % _palette.length];
                        final key = _keyFor(entry.value['name'] as String?, entry.value['tenant'] as String?);
                        final isSelected = _selectedVendorKey == key;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedVendorKey = isSelected ? null : key),
                          child: _AccentCard(
                            isDark: isDark, cardBg: cardBg, accentColor: palette.fg,
                            selected: isSelected,
                            child: Row(children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(10)),
                                child: Icon(_vendorIcon(entry.key), size: 18, color: palette.fg),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${entry.value['name']}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                if ((entry.value['tenant'] ?? '').toString().isNotEmpty)
                                  Text('Tenant: ${entry.value['tenant']}', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                              ])),
                              if (isSelected) Icon(Icons.check_circle, size: 16, color: palette.fg),
                              if (isSelected) const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(20)),
                                child: Text('${entry.value['vehicles']} vehicles', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.fg)),
                              ),
                            ]),
                          ),
                        );
                      }),
                      if (_selectedVendorKey != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedVendorKey = null),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.filter_alt_off_rounded, size: 13, color: textSecondary),
                              const SizedBox(width: 4),
                              Text('Showing $_selectedVendorKey only — tap to clear', style: TextStyle(fontSize: 11, color: textSecondary)),
                            ]),
                          ),
                        ),

                      const SizedBox(height: 22),
                      Text('VEHICLE TYPE', style: TextStyle(fontSize: 10.5, color: textSecondary, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: _typeCounts.entries.map((e) {
                          final style = _vehicleTypeStyle(e.key);
                          return Container(
                            width: (MediaQuery.of(context).size.width - 32 - 20) / 3,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: style.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(style.icon, size: 16, color: style.fg),
                              const SizedBox(height: 6),
                              Text('${e.value}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: style.fg)),
                              const SizedBox(height: 2),
                              Text(e.key, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: style.fg.withOpacity(0.75)), overflow: TextOverflow.ellipsis),
                            ]),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),
                      Row(children: [
                        Text('VEHICLES · LIVE (RIDE OPS)', style: TextStyle(fontSize: 10.5, color: textSecondary, letterSpacing: 0.8)),
                        const Spacer(),
                        Text('${filtered.length} of ${_vehicles.length}', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                      ]),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No vehicles match "$_query"', style: TextStyle(fontSize: 12.5, color: textSecondary))),
                        )
                      else
                        ..._groupedByVendor(filtered).entries.expand((group) {
                          final vendorLabel = group.key;
                          final vehicles = group.value;
                          final palette = _paletteFor(vendorLabel);
                          return [
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 6),
                              child: Row(children: [
                                Icon(Icons.storefront_rounded, size: 13, color: palette.fg),
                                const SizedBox(width: 6),
                                Text(vendorLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary)),
                                const SizedBox(width: 6),
                                Text('· ${vehicles.length}', style: TextStyle(fontSize: 11, color: textSecondary)),
                              ]),
                            ),
                            ...vehicles.map((v) {
                              final style = _vehicleTypeStyle('${v['type']}');
                              return _AccentCard(
                                isDark: isDark, cardBg: cardBg, accentColor: palette.fg,
                                child: Row(children: [
                                  Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(9)),
                                    child: Icon(style.icon, size: 16, color: palette.fg),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${v['plate']}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary)),
                                    const SizedBox(height: 2),
                                    Text('${v['type']}', style: TextStyle(fontSize: 10.5, color: textSecondary), overflow: TextOverflow.ellipsis),
                                  ])),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                                    child: Text('${v['status']}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: _green)),
                                  ),
                                ]),
                              );
                            }),
                          ];
                        }),
                    ],
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ]);
  }
}

class _AccentCard extends StatelessWidget {
  final bool isDark;
  final Color cardBg, accentColor;
  final Widget child;
  final bool selected;
  const _AccentCard({required this.isDark, required this.cardBg, required this.accentColor, required this.child, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: accentColor, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 4, decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
          Expanded(child: Padding(padding: const EdgeInsets.all(12), child: child)),
        ]),
      ),
    );
  }
}
