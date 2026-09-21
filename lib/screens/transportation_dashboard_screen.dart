import 'package:flutter/material.dart';
import '../data/api_repository.dart';
import '../utils/app_version.dart';

class TransportationDashboardScreen extends StatefulWidget {
  const TransportationDashboardScreen({super.key});

  @override
  State<TransportationDashboardScreen> createState() => _TransportationDashboardScreenState();
}

class _TransportationDashboardScreenState extends State<TransportationDashboardScreen> {
  static const _navy = Color(0xFF1C1C1E);
  static const _lightBlue = Color(0xFF1565C0);
  static const _lightBlueBg = Color(0xFFE3F2FD);
  static const _purple = Color(0xFF7B1FA2);
  static const _purpleBg = Color(0xFFF3E5F5);

  Map<String, int> _typeCounts = {};
  int _activeVendors = 0;
  int _fleetVehicles = 0;
  int _activeDrivers = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLive();
  }

  Future<void> _loadLive() async {
    setState(() => _loading = true);
    final data = await ApiRepository().fetchTransportationDashboard();
    if (!mounted) return;
    setState(() {
      final types = (data['vehicle_types'] as Map?) ?? {};
      _typeCounts = types.map((k, v) => MapEntry(k as String, (v as num).toInt()));
      _activeVendors = (data['active_vendors'] as num?)?.toInt() ?? 0;
      _fleetVehicles = (data['fleet_vehicles'] as num?)?.toInt() ?? 0;
      _activeDrivers = (data['active_drivers'] as num?)?.toInt() ?? 0;
      _loading = false;
    });
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(textPrimary, textSecondary),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fleet Summary · LIVE (RIDE OPS)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 12),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [
                    _statCard(label: 'Fleet Vehicles', value: '$_fleetVehicles', unit: 'Registered vehicles', cardBg: _lightBlueBg, borderColor: borderColor, textPrimary: _lightBlue, textSecondary: _lightBlue.withOpacity(0.7), highlight: true),
                    _statCard(label: 'Active Drivers', value: '$_activeDrivers', unit: 'Available for dispatch', cardBg: _purpleBg, borderColor: borderColor, textPrimary: _purple, textSecondary: _purple.withOpacity(0.7), highlight: true),
                  ],
                ),

                const SizedBox(height: 20),
                Text('Vehicle Type Breakdown · LIVE (RIDE OPS)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 10),
                if (_typeCounts.isEmpty)
                  _breakdownCard(label: 'No live vehicles yet', value: '0', cardBg: cardBg, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary)
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _typeCounts.entries.toList().asMap().entries.map((entry) {
                      final isBlue = entry.key.isEven;
                      final e = entry.value;
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 32 - 16) / 3,
                        child: _breakdownCard(
                          label: e.key, value: '${e.value}',
                          cardBg: isBlue ? _lightBlueBg : _purpleBg, borderColor: borderColor,
                          textPrimary: isBlue ? _lightBlue : _purple, textSecondary: (isBlue ? _lightBlue : _purple).withOpacity(0.7),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),
                Text('Active Vendors · LIVE (RIDE OPS)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(height: 10),
                _breakdownCard(label: 'Vendors with vehicles', value: '$_activeVendors', cardBg: _purpleBg, borderColor: borderColor, textPrimary: _purple, textSecondary: _purple.withOpacity(0.7)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1C1C1E), Color(0xFF20344A)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
          child: const Center(child: Text('R', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rezolv', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          Text('Transportation Dashboard · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
        ])),
        Row(children: [
          const Icon(Icons.circle, size: 7, color: Colors.green),
          const SizedBox(width: 5),
          Text('Live', style: TextStyle(fontSize: 11, color: textPrimary)),
        ]),
      ]),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String unit,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: highlight ? null : Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: textSecondary)),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary)),
        Text(unit, style: TextStyle(fontSize: 11, color: textSecondary)),
      ]),
    );
  }

  Widget _breakdownCard({required String label, required String value, required Color cardBg, required Color borderColor, required Color textPrimary, required Color textSecondary}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
      ]),
    );
  }
}
