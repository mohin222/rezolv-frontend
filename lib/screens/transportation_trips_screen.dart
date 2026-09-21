import 'package:flutter/material.dart';
import '../utils/app_version.dart';

class _Trip {
  final String hotelName;
  final String station;
  final String mode;
  final String vehicleNumber;
  final String driver;
  final String pickupTime;
  final String status;
  const _Trip({
    required this.hotelName,
    required this.station,
    required this.mode,
    required this.vehicleNumber,
    required this.driver,
    required this.pickupTime,
    required this.status,
  });
}

// No real trip data exists in RIDE Ops for our stations yet — replace with
// live backend once available.
const _dummyTrips = <_Trip>[];

class TransportationTripsScreen extends StatelessWidget {
  const TransportationTripsScreen({super.key});

  static const _navy = Color(0xFF1C1C1E);
  static const _gold = Color(0xFF6E6E6E);

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'In Transit': return _gold;
      case 'Cancelled': return const Color(0xFF1C1C1E);
      default: return _navy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
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
                Text('Trips · ${AppVersion.version}', style: TextStyle(fontSize: 11, color: textSecondary)),
              ])),
              Row(children: [
                const Icon(Icons.circle, size: 7, color: Colors.green),
                const SizedBox(width: 5),
                Text('Live', style: TextStyle(fontSize: 11, color: textPrimary)),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Text('Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
              const Spacer(),
              Text('Showing ${_dummyTrips.length} of ${_dummyTrips.length}', style: TextStyle(fontSize: 11, color: textSecondary)),
            ]),
          ),
          Expanded(
            child: _dummyTrips.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.directions_car_outlined, size: 40, color: textSecondary),
                      const SizedBox(height: 10),
                      Text('No live trips yet', style: TextStyle(fontSize: 13, color: textSecondary)),
                    ]),
                  )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _dummyTrips.length,
              itemBuilder: (_, i) {
                final trip = _dummyTrips[i];
                final statusColor = _statusColor(trip.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: IntrinsicHeight(
                    child: Row(children: [
                      Container(width: 4, decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
                      Expanded(child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text(trip.hotelName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy))),
                            Text('${trip.station} · ${trip.pickupTime}', style: TextStyle(fontSize: 11, color: textSecondary)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.directions_car_filled_outlined, size: 12, color: textSecondary),
                            const SizedBox(width: 4),
                            Text('${trip.mode} · ${trip.vehicleNumber}', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.person_outline, size: 12, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(trip.driver, style: TextStyle(fontSize: 10.5, color: textSecondary)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                              child: Text(trip.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                            ),
                            const Spacer(),
                            Row(children: [
                              Icon(Icons.call_outlined, size: 14, color: _navy),
                              const SizedBox(width: 4),
                              Text('Contact Driver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _navy)),
                            ]),
                          ]),
                        ]),
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
