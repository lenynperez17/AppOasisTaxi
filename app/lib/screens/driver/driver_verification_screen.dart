// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/common/oasis_app_bar.dart';
import '../../providers/ride_provider.dart';
import '../../models/trip_model.dart';
import '../../widgets/verification_code_widget.dart'; // ✅ NUEVO: Widget de verificación mutua

/// Pantalla de verificación mutua para conductores
/// Muestra el código del conductor y permite ingresar el código del pasajero
class DriverVerificationScreen extends StatefulWidget {
  final TripModel trip;

  const DriverVerificationScreen({
    super.key,
    required this.trip,
  });

  @override
  _DriverVerificationScreenState createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;
  // ✅ Guardar referencia al provider para poder remover listener
  RideProvider? _rideProvider;

  @override
  void initState() {
    super.initState();

    // Listener para detectar cuando la verificación mutua esté completa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _setupTripListener();
      }
    });
  }

  void _setupTripListener() {
    _rideProvider = Provider.of<RideProvider>(context, listen: false);
    _rideProvider?.addListener(_onTripStatusChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    // ✅ Remover listener para evitar memory leaks
    _rideProvider?.removeListener(_onTripStatusChanged);
    super.dispose();
  }

  void _onTripStatusChanged() {
    if (_isDisposed || !mounted) return;

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final currentTrip = rideProvider.currentTrip;

    if (currentTrip != null && currentTrip.id == widget.trip.id) {
      // ✅ Si la verificación mutua está completa, viaje iniciado
      if (currentTrip.status == 'in_progress' && currentTrip.isMutualVerificationComplete) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Verificación mutua completada! El viaje ha comenzado.'),
            backgroundColor: ModernTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: OasisAppBar(
        title: 'Verificación Mutua',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Información del pasajero
              _buildPassengerInfo(),

              SizedBox(height: 20),

              // ✅ NUEVO: Widget de verificación mutua completo
              VerificationCodeWidget(
                rideId: widget.trip.id,
                isDriver: true, // Es conductor
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: Row(
        children: [
          // Avatar del pasajero
          CircleAvatar(
            radius: 30,
            backgroundColor: ModernTheme.primaryBlue.withValues(alpha: 0.1),
            child: Icon(
              Icons.person,
              size: 32,
              color: ModernTheme.primaryBlue,
            ),
          ),
          SizedBox(width: 16),
          // Info del pasajero
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasajero',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: context.secondaryText),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.trip.pickupAddress,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: context.secondaryText),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.trip.destinationAddress,
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tarifa
          Column(
            children: [
              Text(
                'S/. ${widget.trip.estimatedFare.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.oasisGreen,
                ),
              ),
              Text(
                '${widget.trip.estimatedDistance.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Métodos obsoletos eliminados - ahora usa VerificationCodeWidget
}