import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/price_negotiation_model.dart';

/// Pantalla de negociaciones para conductores
/// Muestra las solicitudes activas donde pueden hacer ofertas
class DriverNegotiationsScreen extends StatefulWidget {
  const DriverNegotiationsScreen({super.key});

  @override
  State<DriverNegotiationsScreen> createState() => _DriverNegotiationsScreenState();
}

class _DriverNegotiationsScreenState extends State<DriverNegotiationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadActiveNegotiations();
  }

  Future<void> _loadActiveNegotiations() async {
    final provider = Provider.of<PriceNegotiationProvider>(context, listen: false);
    await provider.loadDriverRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Viaje'),
        backgroundColor: ModernTheme.oasisGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveNegotiations,
          ),
        ],
      ),
      body: Consumer<PriceNegotiationProvider>(
        builder: (context, provider, _) {
          final activeNegotiations = provider.driverVisibleRequests
              .where((n) => n.status == NegotiationStatus.waiting ||
                           n.status == NegotiationStatus.negotiating)
              .toList();

          if (activeNegotiations.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadActiveNegotiations,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeNegotiations.length,
              itemBuilder: (context, index) {
                return _buildNegotiationCard(activeNegotiations[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay solicitudes activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las nuevas solicitudes aparecerán aquí',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationCard(PriceNegotiation negotiation) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentDriverId = authProvider.currentUser?.id ?? '';

    // Verificar si el conductor ya hizo una oferta
    final hasOffer = negotiation.driverOffers.any((offer) =>
      offer.driverId == currentDriverId
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header con info del pasajero
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: negotiation.passengerPhoto.isNotEmpty
                      ? NetworkImage(negotiation.passengerPhoto)
                      : null,
                  child: negotiation.passengerPhoto.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        negotiation.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            negotiation.passengerRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildTimer(negotiation),
              ],
            ),
          ),

          // Detalles del viaje
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origen
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  color: ModernTheme.success,
                  label: 'Origen',
                  address: negotiation.pickup.address,
                ),
                const SizedBox(height: 12),

                // Destino
                _buildLocationRow(
                  icon: Icons.location_on,
                  color: ModernTheme.error,
                  label: 'Destino',
                  address: negotiation.destination.address,
                ),
                const SizedBox(height: 16),

                // Info del viaje
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.route,
                        label: '${negotiation.distance.toStringAsFixed(1)} km',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.schedule,
                        label: '${negotiation.estimatedTime} min',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.payments,
                        label: _getPaymentMethodText(negotiation.paymentMethod),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Precio ofrecido por el pasajero
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Precio ofrecido:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        negotiation.offeredPrice.toCurrency(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                if (negotiation.notes != null && negotiation.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            negotiation.notes!,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Botón de acción
                if (!hasOffer)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showOfferDialog(negotiation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.oasisGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hacer una oferta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: ModernTheme.success),
                        const SizedBox(width: 8),
                        const Text(
                          'Ya realizaste una oferta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer(PriceNegotiation negotiation) {
    final remaining = negotiation.timeRemaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: minutes < 2 ? ModernTheme.error : ModernTheme.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.wallet:
        return 'Wallet';
    }
  }

  void _showOfferDialog(PriceNegotiation negotiation) {
    final priceController = TextEditingController(
      text: negotiation.offeredPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hacer una oferta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio sugerido: ${negotiation.suggestedPrice.toCurrency()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              'Precio del pasajero: ${negotiation.offeredPrice.toCurrency()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu precio',
                prefixText: '${AppConstants.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el precio al que estás dispuesto a aceptar este viaje',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un precio válido')),
                );
                return;
              }

              Navigator.pop(context);

              final provider = Provider.of<PriceNegotiationProvider>(
                context,
                listen: false,
              );
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                await provider.makeDriverOffer(
                  negotiation.id,
                  price,
                );

                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Oferta enviada exitosamente'),
                      backgroundColor: ModernTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al enviar oferta: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: const Text('Enviar oferta'),
          ),
        ],
      ),
    );
  }
}
