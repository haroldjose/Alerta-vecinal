import 'package:alerta_vecinal/models/report_model.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Verificar permisos de ubicación
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Los servicios de ubicación están deshabilitados';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Los permisos de ubicación fueron denegados';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Los permisos de ubicación están permanentemente denegados';
    }

    return true;
  }

  // Obtener ubicación actual
  Future<LocationData> getCurrentLocation() async {
    try {
      await checkLocationPermission();

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
          distanceFilter: 10,
        ),
      );

      // agregar geocoding reverso para obtener la dirección, solo las coordenadas
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      throw 'Error al obtener ubicación: $e';
    }
  }

  // Formatear ubicación para mostrar
  String formatLocation(LocationData location) {
    if (location.address != null && location.address!.isNotEmpty) {
      return location.address!;
    }
    return 'Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}';
  }

  // Calcular distancia entre dos puntos (opcional)
  // double calculateDistance(LocationData from, LocationData to) {
  //   return Geolocator.distanceBetween(
  //     from.latitude,
  //     from.longitude,
  //     to.latitude,
  //     to.longitude,
  //   );
  // }
}