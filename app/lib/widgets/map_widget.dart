// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../core/constants/app_colors.dart';
import '../utils/logger.dart';
import '../core/services/places_service.dart';

class MapWidget extends StatefulWidget {
  final bool isSearching;
  final Function(String) onLocationSelected;
  final bool isDriver;

  const MapWidget({
    super.key,
    required this.isSearching,
    required this.onLocationSelected,
    this.isDriver = false,
  });

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  
  // Posición inicial (Lima, Perú)
  final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-12.0464, -77.0428), // Lima centro
    zoom: 14.0,
  );

  final Set<Marker> _markers = {};
  
  late AnimationController _pulseController;
  

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Actualizar la cámara del mapa
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
            ),
          ),
        );

        // Agregar marcador de ubicación actual
        _addCurrentLocationMarker();
      }
    } catch (e) {
      AppLogger.error('Error obteniendo ubicación', e);
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId('current_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              widget.isDriver ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: widget.isDriver ? 'Tu ubicación (Conductor)' : 'Tu ubicación',
              snippet: 'Estás aquí',
            ),
          ),
        );
      });

      // Si es conductor, agregar algunos pasajeros de ejemplo cerca
      if (widget.isDriver) {
        _addNearbyPassengers();
      }
    }
  }

  void _addNearbyPassengers() {
    if (_currentPosition != null) {
      // Agregar pasajeros de ejemplo cerca de la ubicación actual
      final passengers = [
        {'lat': _currentPosition!.latitude + 0.003, 'lng': _currentPosition!.longitude - 0.002, 'name': 'Juan Pérez'},
        {'lat': _currentPosition!.latitude - 0.002, 'lng': _currentPosition!.longitude + 0.003, 'name': 'María García'},
        {'lat': _currentPosition!.latitude + 0.001, 'lng': _currentPosition!.longitude + 0.002, 'name': 'Carlos López'},
      ];

      for (var passenger in passengers) {
        _markers.add(
          Marker(
            markerId: MarkerId('passenger_${passenger['name']}'),
            position: LatLng(passenger['lat'] as double, passenger['lng'] as double),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: passenger['name'] as String,
              snippet: 'Solicita viaje',
            ),
          ),
        );
      }
    }
  }

  
  void _selectPlaceFromSearch(String address, LatLng location) {
    widget.onLocationSelected(address);
    _moveToLocation(location.latitude, location.longitude, address);
  }
  
  void _moveToLocation(double lat, double lng, String address) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: 16.0,
          ),
        ),
      );
      
      // Agregar marcador del destino
      setState(() {
        _markers.removeWhere((marker) => marker.markerId.value == 'destination');
        _markers.add(
          Marker(
            markerId: MarkerId('destination'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Destino',
              snippet: address,
            ),
          ),
        );
      });
    }
  }

  void _centerOnCurrentLocation() async {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } else {
      await _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Google Maps
        GoogleMap(
          initialCameraPosition: _initialPosition,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_currentPosition != null) {
              _addCurrentLocationMarker();
            }
          },
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
          compassEnabled: true,
        ),
        
        // Indicador de carga
        if (_isLoadingLocation)
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiOrange),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Obteniendo tu ubicación...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Panel de búsqueda de ubicación
        if (widget.isSearching)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            right: 16,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Widget de búsqueda con Google Places API
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      child: _SearchField(
                        onLocationSelected: widget.onLocationSelected,
                        onPlaceSelected: _selectPlaceFromSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Botón de centrar ubicación
        if (!widget.isSearching)
          Positioned(
            bottom: widget.isDriver ? 180 : 320,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _centerOnCurrentLocation,
                icon: Icon(Icons.my_location, color: AppColors.rappiOrange),
              ),
            ),
          ),
      ],
    );
  }

}

// Widget de búsqueda con Google Places API
class _SearchField extends StatefulWidget {
  final Function(String) onLocationSelected;
  final Function(String, LatLng) onPlaceSelected;

  const _SearchField({
    required this.onLocationSelected,
    required this.onPlaceSelected,
  });

  @override
  _SearchFieldState createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlacesSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (text.isNotEmpty && text.length > 2) {
        _searchPlaces(text);
      } else {
        setState(() {
          _suggestions = [];
          _isLoading = false;
          _showSuggestions = false;
        });
      }
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus && _suggestions.isNotEmpty;
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      final suggestions = await PlacesService.searchPlaces(query);
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showSuggestions = false;
      });
    }
  }

  Future<void> _selectLocation(PlacesSuggestion suggestion) async {
    AppLogger.info('🎯 Selecting location: ${suggestion.description}');
    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    try {
      AppLogger.info('📍 Getting place details for: ${suggestion.placeId}');
      final placeDetails = await PlacesService.getPlaceDetails(suggestion.placeId);
      if (placeDetails != null) {
        AppLogger.info('✅ Place details received: ${placeDetails.formattedAddress}');
        _controller.text = placeDetails.formattedAddress;
        
        // Llamar a ambos callbacks
        widget.onLocationSelected(placeDetails.formattedAddress);
        widget.onPlaceSelected(
          placeDetails.formattedAddress, 
          LatLng(placeDetails.latitude, placeDetails.longitude)
        );
      } else {
        AppLogger.warning('⚠️ Place details not found, using description');
        _controller.text = suggestion.description;
        widget.onLocationSelected(suggestion.description);
      }
    } catch (e) {
      AppLogger.error('❌ Error getting place details', e);
      _controller.text = suggestion.description;
      widget.onLocationSelected(suggestion.description);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Buscar dirección...',
            prefixIcon: Icon(Icons.search, color: AppColors.oasisGreen),
            suffixIcon: _isLoading
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.oasisGreen),
                      ),
                    ),
                  )
                : _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _suggestions = [];
                            _showSuggestions = false;
                          });
                        },
                      )
                    : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.oasisGreen, width: 2),
            ),
          ),
        ),
        
        // Sugerencias
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
            constraints: BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () {
                    AppLogger.info('🎯 ListTile clicked for: ${suggestion.description}');
                    _selectLocation(suggestion);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.oasisGreen,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.mainText ?? suggestion.description,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500, 
                                  fontSize: 14,
                                ),
                              ),
                              if (suggestion.secondaryText != null)
                                Text(
                                  suggestion.secondaryText!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}