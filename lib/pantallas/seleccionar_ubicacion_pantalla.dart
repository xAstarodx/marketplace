import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class PantallaSeleccionarUbicacion extends StatefulWidget {
  const PantallaSeleccionarUbicacion({super.key});

  @override
  State<PantallaSeleccionarUbicacion> createState() =>
      _PantallaSeleccionarUbicacionState();
}

class _PantallaSeleccionarUbicacionState
    extends State<PantallaSeleccionarUbicacion> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  LatLng? posicionSeleccionada;
  String nombreUbicacion = 'Obteniendo ubicación...';
  bool cargandoGps = true;

  @override
  void initState() {
    super.initState();
    _determinarPosicionActual();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinarPosicionActual() async {
    setState(() => cargandoGps = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            nombreUbicacion = 'Servicio de ubicación desactivado';
            cargandoGps = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Activa el GPS en la configuración de tu dispositivo',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              nombreUbicacion = 'Permiso de ubicación denegado';
              cargandoGps = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            nombreUbicacion = 'Permiso denegado permanentemente';
            cargandoGps = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Habilita el permiso de ubicación en la configuración',
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final newLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          posicionSeleccionada = newLatLng;
          cargandoGps = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 15),
        );
        _obtenerNombreUbicacion(newLatLng);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          nombreUbicacion = 'No se pudo obtener la ubicación';
          cargandoGps = false;
        });
      }
    }
  }

  Future<void> _obtenerNombreUbicacion(LatLng posicion) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        posicion.latitude,
        posicion.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final partes = [
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).toList();
        setState(() {
          nombreUbicacion = partes.isNotEmpty
              ? partes.take(2).join(', ')
              : 'Ubicación seleccionada';
        });
      }
    } catch (_) {
      if (mounted) setState(() => nombreUbicacion = 'Ubicación desconocida');
    }
  }

  Future<void> _buscarDireccion() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newLatLng = LatLng(loc.latitude, loc.longitude);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 16),
        );
        setState(() => posicionSeleccionada = newLatLng);
        _obtenerNombreUbicacion(newLatLng);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la dirección')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar ubicación')),
      body: cargandoGps && posicionSeleccionada == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Obteniendo tu ubicación...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : posicionSeleccionada == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombreUbicacion,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _determinarPosicionActual,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: posicionSeleccionada!,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: (position) {
                    posicionSeleccionada = position.target;
                  },
                  onCameraIdle: () {
                    if (posicionSeleccionada != null) {
                      _obtenerNombreUbicacion(posicionSeleccionada!);
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                const Center(
                  child: Icon(Icons.location_on, size: 44, color: Colors.red),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(Icons.search),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Buscar dirección...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _buscarDireccion(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _buscarDireccion,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nombreUbicacion,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${posicionSeleccionada!.latitude.toStringAsFixed(5)}, '
                                '${posicionSeleccionada!.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => Navigator.pop(context, {
                                  'posicion': posicionSeleccionada,
                                  'nombre': nombreUbicacion,
                                }),
                                icon: const Icon(Icons.check),
                                label: const Text('Confirmar ubicación'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
