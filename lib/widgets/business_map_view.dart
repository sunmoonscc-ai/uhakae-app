import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/business_model.dart';
import '../screens/business_detail_screen.dart';

class BusinessMapView extends StatelessWidget {
  final List<BusinessModel> businesses;
  final LatLng? initialCenter;
  final double initialZoom;

  const BusinessMapView({
    super.key,
    required this.businesses,
    this.initialCenter,
    this.initialZoom = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    // 필터링: 좌표(address3)가 있는 업체만
    final List<Map<String, dynamic>> validMarkers = [];
    for (var b in businesses) {
      if (b.address3.isNotEmpty) {
        try {
          final parts = b.address3.split(',');
          if (parts.length == 2) {
            final lat = double.parse(parts[0].trim());
            final lng = double.parse(parts[1].trim());
            validMarkers.add({
              'business': b,
              'point': LatLng(lat, lng),
            });
          }
        } catch (e) {
          // parse 오류 무시
        }
      }
    }

    // 초기 중심 좌표 설정: 지정된 값이 없으면 마커들의 평균 위치, 마커도 없으면 기본 세부 중심 좌표
    LatLng center = initialCenter ?? const LatLng(10.3157, 123.8854); // Cebu City 기본값
    if (initialCenter == null && validMarkers.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      for (var m in validMarkers) {
        sumLat += (m['point'] as LatLng).latitude;
        sumLng += (m['point'] as LatLng).longitude;
      }
      center = LatLng(sumLat / validMarkers.length, sumLng / validMarkers.length);
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.uhakae.app',
        ),
        MarkerLayer(
          markers: validMarkers.map((m) {
            final b = m['business'] as BusinessModel;
            final point = m['point'] as LatLng;
            return Marker(
              point: point,
              width: 120,
              height: 60,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BusinessDetailScreen(business: b),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Text(
                        b.name,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Icon(Icons.location_on, color: Colors.blue, size: 24),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
