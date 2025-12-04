// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/payment_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_overlay.dart';

/// PANTALLA DE SELECCIÓN DE MÉTODO DE PAGO - OASIS TAXI
/// ====================================================
/// 
/// Métodos de pago implementados:
/// 💳 MercadoPago (tarjetas débito/crédito)
/// 📱 Yape (código QR y deep link)
/// 💸 Plin (código QR y deep link)  
/// 💵 Efectivo (pago directo al conductor)
/// 
/// Funcionalidades:
/// ✅ Selección visual de método de pago
/// 💰 Cálculo automático de comisiones (20% plataforma)
/// 🧮 Desglose detallado de costos
/// 📊 Verificación de estado de pago en tiempo real
/// 🔄 Reintento automático de pagos fallidos
class PaymentMethodSelectionScreen extends StatefulWidget {
  final String rideId;
  final double fareAmount;
  final String passengerName;
  final String passengerEmail;
  final String? passengerPhone;

  const PaymentMethodSelectionScreen({
    super.key,
    required this.rideId,
    required this.fareAmount,
    required this.passengerName,
    required this.passengerEmail,
    this.passengerPhone,
  });

  @override
  State<PaymentMethodSelectionScreen> createState() => _PaymentMethodSelectionScreenState();
}

class _PaymentMethodSelectionScreenState extends State<PaymentMethodSelectionScreen> {
  final PaymentService _paymentService = PaymentService();
  final FirebaseService _firebaseService = FirebaseService();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  PaymentMethodInfo? _selectedMethod;
  List<PaymentMethodInfo> _availableMethods = [];
  
  // Variables para el proceso de pago
  String? _currentPaymentId;
  Timer? _paymentStatusTimer;
  Timer? _paymentTimeoutTimer;

  // Variables para mostrar QR de Yape/Plin
  String? _qrCodeUrl;
  String? _qrInstructions;

  // Cálculos de costos
  late double _platformCommission;
  late double _driverEarnings;

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _calculateCosts();
    _loadAvailableMethods();
    
    // Pre-llenar teléfono si está disponible
    if (widget.passengerPhone != null) {
      _phoneController.text = widget.passengerPhone!;
    }
  }

  @override
  void dispose() {
    // ✅ Marcar como disposed ANTES de cancelar recursos
    _isDisposed = true;

    _paymentStatusTimer?.cancel();
    _paymentStatusTimer = null;
    _paymentTimeoutTimer?.cancel();
    _paymentTimeoutTimer = null;
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    await _paymentService.initialize();
  }

  void _calculateCosts() {
    _platformCommission = _paymentService.calculatePlatformCommission(widget.fareAmount);
    _driverEarnings = _paymentService.calculateDriverEarnings(widget.fareAmount);
  }

  void _loadAvailableMethods() {
    setState(() {
      _availableMethods = _paymentService.getAvailablePaymentMethods();
      _selectedMethod = _availableMethods.isNotEmpty ? _availableMethods.first : null;
    });
  }

  // ============================================================================
  // PROCESAMIENTO DE PAGOS POR MÉTODO
  // ============================================================================

  Future<void> _processPayment() async {
    if (_selectedMethod == null) return;

    setState(() => _isLoading = true);

    try {
      switch (_selectedMethod!.id) {
        case 'mercadopago':
          await _processMercadoPagoPayment();
          break;
        case 'yape':
          await _processYapePayment();
          break;
        case 'plin':
          await _processPlinPayment();
          break;
        case 'cash':
          await _processCashPayment();
          break;
      }
    } catch (e) {
      _showErrorDialog('Error procesando pago: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processMercadoPagoPayment() async {
    final result = await _paymentService.createMercadoPagoPreference(
      rideId: widget.rideId,
      amount: widget.fareAmount,
      payerEmail: widget.passengerEmail,
      payerName: widget.passengerName,
      description: 'Viaje Oasis Taxi #${widget.rideId}',
    );

    if (result.success) {
      _currentPaymentId = result.preferenceId;
      
      // Abrir checkout de MercadoPago
      final launched = await _paymentService.openMercadoPagoCheckout(result.initPoint!);
      
      if (launched) {
        _startPaymentStatusMonitoring();
        _showPaymentInProgressDialog('MercadoPago');
      } else {
        _showErrorDialog('No se pudo abrir el checkout de MercadoPago');
      }
    } else {
      _showErrorDialog(result.error ?? 'Error creando preferencia de MercadoPago');
    }
  }

  Future<void> _processYapePayment() async {
    if (!_validatePhoneNumber()) return;

    final result = await _paymentService.processWithYape(
      rideId: widget.rideId,
      amount: widget.fareAmount,
      phoneNumber: _phoneController.text,
    );

    if (result.success) {
      _currentPaymentId = result.paymentId;
      _qrCodeUrl = result.qrUrl;
      _qrInstructions = result.instructions;
      
      setState(() {});
      
      _showYapeQRDialog();
      _startPaymentStatusMonitoring();
    } else {
      _showErrorDialog(result.error ?? 'Error procesando pago con Yape');
    }
  }

  Future<void> _processPlinPayment() async {
    if (!_validatePhoneNumber()) return;

    final result = await _paymentService.processWithPlin(
      rideId: widget.rideId,
      amount: widget.fareAmount,
      phoneNumber: _phoneController.text,
    );

    if (result.success) {
      _currentPaymentId = result.paymentId;
      _qrCodeUrl = result.qrUrl;
      _qrInstructions = result.instructions;
      
      setState(() {});
      
      _showPlinQRDialog();
      _startPaymentStatusMonitoring();
    } else {
      _showErrorDialog(result.error ?? 'Error procesando pago con Plin');
    }
  }

  Future<void> _processCashPayment() async {
    // Para pago en efectivo, solo marcamos como pendiente
    await _firebaseService.analytics.logEvent(
      name: 'payment_method_selected_cash',
      parameters: {
        'ride_id': widget.rideId,
        'amount': widget.fareAmount,
      },
    );

    _showCashPaymentDialog();
  }

  // ============================================================================
  // MONITOREO DE ESTADO DE PAGO
  // ============================================================================

  void _startPaymentStatusMonitoring() {
    if (_currentPaymentId == null) return;

    _paymentStatusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // ✅ TRIPLE VERIFICACIÓN para prevenir verificaciones después de dispose
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final statusResult = await _paymentService.checkPaymentStatus(_currentPaymentId!);

        // ✅ Verificar mounted después de operación asíncrona
        if (!mounted || _isDisposed) {
          timer.cancel();
          return;
        }

        if (statusResult.success) {
          switch (statusResult.status) {
            case 'approved':
              timer.cancel();
              if (mounted) _showPaymentSuccessDialog();
              break;
            case 'rejected':
              timer.cancel();
              if (mounted) _showPaymentRejectedDialog();
              break;
            case 'cancelled':
              timer.cancel();
              if (mounted) _showPaymentCancelledDialog();
              break;
            // 'pending' continúa monitoreando
          }
        }
      } catch (e) {
        // Continuar monitoreando en caso de error de red
      }
    });

    // Timeout después de 10 minutos
    _paymentTimeoutTimer = Timer(const Duration(minutes: 10), () {
      // ✅ Verificar disposed y mounted antes de mostrar diálogo
      if (_isDisposed || !mounted) return;

      _paymentStatusTimer?.cancel();
      _paymentStatusTimer = null;
      _showPaymentTimeoutDialog();
    });
  }

  // ============================================================================
  // VALIDACIONES
  // ============================================================================

  bool _validatePhoneNumber() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showErrorDialog('Ingresa tu número de teléfono');
      return false;
    }
    
    // Validar formato peruano: 9XXXXXXXX
    if (!RegExp(r'^9[0-9]{8}$').hasMatch(phone)) {
      _showErrorDialog('Número de teléfono inválido. Formato: 9XXXXXXXX');
      return false;
    }
    
    return true;
  }

  // ============================================================================
  // DIÁLOGOS DE PAGO
  // ============================================================================

  void _showYapeQRDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: Colors.purple),
            SizedBox(width: 8),
            Text('📱 Pagar con Yape'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_qrCodeUrl != null) 
              QrImageView(
                data: _qrCodeUrl!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            const SizedBox(height: 16),
            Text(
              _qrInstructions ?? 'Escanea el código QR con tu app Yape',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final launched = await _paymentService.openYapeApp(
                  '946123456',
                  widget.fareAmount,
                  'Viaje Oasis Taxi #${widget.rideId}',
                );
                if (!launched) {
                  _showErrorDialog('No se pudo abrir la app de Yape');
                }
              },
              icon: const Icon(Icons.launch),
              label: const Text('Abrir Yape'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Monto: S/. ${widget.fareAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _paymentStatusTimer?.cancel();
              Navigator.of(context).pop();
            },
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
  }

  void _showPlinQRDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: Colors.blue),
            SizedBox(width: 8),
            Text('💸 Pagar con Plin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_qrCodeUrl != null)
              QrImageView(
                data: _qrCodeUrl!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            const SizedBox(height: 16),
            Text(
              _qrInstructions ?? 'Escanea el código QR con tu app Plin',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final launched = await _paymentService.openPlinApp(
                  '946123456',
                  widget.fareAmount,
                  'Viaje Oasis Taxi #${widget.rideId}',
                );
                if (!launched) {
                  _showErrorDialog('No se pudo abrir la app de Plin');
                }
              },
              icon: const Icon(Icons.launch),
              label: const Text('Abrir Plin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Monto: S/. ${widget.fareAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _paymentStatusTimer?.cancel();
              Navigator.of(context).pop();
            },
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
  }

  void _showCashPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.money, color: Colors.green),
            SizedBox(width: 8),
            Text('💵 Pago en Efectivo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Has seleccionado pagar en efectivo al conductor.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Consejos para pago en efectivo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Ten el monto exacto si es posible'),
                  const Text('• El conductor puede dar vuelto'),
                  const Text('• Solicita tu comprobante digital'),
                  const SizedBox(height: 12),
                  Text(
                    'Monto total: S/. ${widget.fareAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CAMBIAR MÉTODO'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmCashPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  void _showPaymentInProgressDialog(String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Procesando Pago...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Procesando tu pago con $method.\n'
              'Por favor espera...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('¡Pago Exitoso!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✅ Tu pago ha sido procesado exitosamente.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Monto pagado: S/. ${widget.fareAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comisión plataforma: S/. ${_platformCommission.toStringAsFixed(2)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  Text(
                    'Ganancia conductor: S/. ${_driverEarnings.toStringAsFixed(2)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showPaymentRejectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('Pago Rechazado'),
          ],
        ),
        content: const Text(
          '❌ Tu pago ha sido rechazado.\n\n'
          'Por favor verifica tu información de pago e intenta nuevamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('INTENTAR DE NUEVO'),
          ),
        ],
      ),
    );
  }

  void _showPaymentCancelledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pago Cancelado'),
        content: const Text('El pago ha sido cancelado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _showPaymentTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiempo Agotado'),
        content: const Text(
          'El tiempo para completar el pago ha expirado.\n'
          'Por favor intenta nuevamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('INTENTAR DE NUEVO'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  void _confirmCashPayment() {
    // Aquí se confirmaría el pago en efectivo
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ============================================================================
  // UI - BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
      appBar: AppBar(
        title: const Text('💳 Método de Pago'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFareSummaryCard(),
                    const SizedBox(height: 16),
                    _buildPaymentMethodsCard(),
                    const SizedBox(height: 16),
                    if (_selectedMethod?.requiresPhoneNumber == true) 
                      _buildPhoneNumberInput(),
                  ],
                ),
              ),
            ),
            _buildPayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFareSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Resumen del Viaje',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tarifa base:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'S/. ${widget.fareAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comisión plataforma (20%):',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        'S/. ${_platformCommission.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ganancia conductor:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        'S/. ${_driverEarnings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'S/. ${widget.fareAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Selecciona Método de Pago',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: _availableMethods.map((method) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: _selectedMethod?.id == method.id 
                    ? Colors.blue.shade50 
                    : Theme.of(context).colorScheme.onPrimary,
                  child: ListTile(
                    leading: Radio<PaymentMethodInfo>(
                      value: method,
                      groupValue: _selectedMethod,
                      onChanged: (PaymentMethodInfo? value) {
                        setState(() {
                          _selectedMethod = value;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                    title: Text(
                      '${method.icon} ${method.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(method.description),
                    onTap: () {
                      setState(() {
                        _selectedMethod = method;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneNumberInput() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Número de Teléfono',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: const InputDecoration(
                labelText: 'Número de teléfono',
                hintText: '987654321',
                prefixText: '+51 ',
                border: OutlineInputBorder(),
                helperText: 'Formato: 9XXXXXXXX (sin +51)',
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _selectedMethod != null && !_isLoading ? _processPayment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _selectedMethod != null 
            ? 'Pagar S/. ${widget.fareAmount.toStringAsFixed(2)} con ${_selectedMethod!.name}'
            : 'Selecciona un método de pago',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}