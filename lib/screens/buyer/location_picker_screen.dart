import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../config/constants.dart';

// ---------------------------------------------------------------------
// LocationPickerScreen
//
// Shows an OpenStreetMap view (no API key needed) with a pin fixed in
// the center of the screen. The buyer pans/drags the MAP underneath the
// pin to position it over their actual delivery spot, then taps Confirm
// to return that center point's lat/lng back to the caller.
//
// Usage:
//   final result = await Navigator.of(context).push<latlong.LatLng>(
//     MaterialPageRoute(
//       builder: (_) => LocationPickerScreen(initialCenter: someLatLng),
//     ),
//   );
//   if (result != null) { // use result.latitude / result.longitude }
// ---------------------------------------------------------------------

class LocationPickerScreen extends StatefulWidget {
  final latlong.LatLng initialCenter;

  const LocationPickerScreen({super.key, required this.initialCenter});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  late latlong.LatLng _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
  }

  void _confirm() {
    Navigator.of(context).pop(_center);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Pin Delivery Location',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _center = position.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.suanmouakhom.market',
              ),
            ],
          ),

          // Fixed pin in the exact center of the map viewport — this is
          // the classic "drag the map under the pin" pattern (like
          // Grab/Google Maps address pickers) instead of tapping to drop
          // a marker, which is easier to use precisely on mobile.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 36), // pin tip aligns with true center
                child: Icon(Icons.location_pin, size: 44, color: Color(AppColors.errorValue)),
              ),
            ),
          ),

          // Coordinates readout + confirm button.
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                  ),
                  child: Text(
                    '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(AppColors.primaryValue),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

          // My-location button — re-centers on GPS if the buyer wandered
          // too far while panning (uses the same initial point passed in,
          // since re-fetching GPS here would need another permission
          // round-trip; the caller already has a fresh fix).
          Positioned(
            right: 16,
            top: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: const Color(AppColors.primaryValue),
              onPressed: () {
                _mapController.move(widget.initialCenter, 16);
                setState(() => _center = widget.initialCenter);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
