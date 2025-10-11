// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

class SettingsAdminScreen extends StatefulWidget {
  const SettingsAdminScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsAdminScreenState createState() => _SettingsAdminScreenState();
}

class _SettingsAdminScreenState extends State<SettingsAdminScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // General settings
  bool _maintenanceMode = false;
  bool _allowNewRegistrations = true;
  bool _requireDocumentVerification = true;
  String _defaultLanguage = 'es';
  String _timezone = 'America/Lima';
  
  // Pricing settings
  final TextEditingController _baseFareController = TextEditingController(text: '5.00');
  final TextEditingController _perKmController = TextEditingController(text: '2.50');
  final TextEditingController _perMinController = TextEditingController(text: '0.50');
  final TextEditingController _commissionController = TextEditingController(text: '20');
  final TextEditingController _cancellationFeeController = TextEditingController(text: '5.00');
  bool _dynamicPricing = true;
  double _surgeMultiplier = 1.5;
  
  // Zones settings
  final List<Zone> _zones = [
    Zone(name: 'Centro', surcharge: 0, restricted: false),
    Zone(name: 'Aeropuerto', surcharge: 10, restricted: false),
    Zone(name: 'Zona Industrial', surcharge: 5, restricted: true),
  ];
  
  // Promotions settings
  final List<Promotion> _promotions = [
    Promotion(
      code: 'NUEVO20',
      discount: 20,
      type: DiscountType.percentage,
      active: true,
      expiryDate: DateTime.now().add(Duration(days: 30)),
    ),
    Promotion(
      code: 'TAXI10',
      discount: 10,
      type: DiscountType.fixed,
      active: true,
      expiryDate: DateTime.now().add(Duration(days: 15)),
    ),
  ];
  
  // Notifications settings
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _notifyNewTrips = true;
  bool _notifyPayments = true;
  bool _notifyEmergencies = true;
  
  // Security settings
  bool _twoFactorAuth = true;
  int _sessionTimeout = 30;
  int _maxLoginAttempts = 5;
  bool _requireStrongPasswords = true;
  bool _enableApiAccess = false;
  String _apiKey = 'sk_live_...';
  
  // Backup settings
  bool _autoBackup = true;
  String _backupFrequency = 'daily';
  String _backupTime = '03:00';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _baseFareController.dispose();
    _perKmController.dispose();
    _perMinController.dispose();
    _commissionController.dispose();
    _cancellationFeeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Configuración del Sistema',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveSettings,
            icon: Icon(Icons.save, color: ModernTheme.oasisGreen),
            label: Text(
              'Guardar',
              style: TextStyle(color: ModernTheme.oasisGreen),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: ModernTheme.oasisGreen,
          tabs: [
            Tab(text: 'General'),
            Tab(text: 'Tarifas'),
            Tab(text: 'Zonas'),
            Tab(text: 'Promociones'),
            Tab(text: 'Notificaciones'),
            Tab(text: 'Seguridad'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralSettings(),
          _buildPricingSettings(),
          _buildZonesSettings(),
          _buildPromotionsSettings(),
          _buildNotificationSettings(),
          _buildSecuritySettings(),
        ],
      ),
    );
  }
  
  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Configuración General'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Modo de Mantenimiento'),
              subtitle: Text('Desactiva temporalmente la aplicación'),
              value: _maintenanceMode,
              onChanged: (value) => setState(() => _maintenanceMode = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
            if (_maintenanceMode)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: ModernTheme.warning),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La aplicación mostrará un mensaje de mantenimiento a todos los usuarios',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(),
            SwitchListTile(
              title: Text('Permitir Nuevos Registros'),
              subtitle: Text('Habilita el registro de nuevos usuarios'),
              value: _allowNewRegistrations,
              onChanged: (value) => setState(() => _allowNewRegistrations = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Verificación de Documentos'),
              subtitle: Text('Requiere verificación para conductores'),
              value: _requireDocumentVerification,
              onChanged: (value) => setState(() => _requireDocumentVerification = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
          ]),
          
          SizedBox(height: 20),
          _buildSectionTitle('Regional'),
          _buildSettingCard([
            ListTile(
              title: Text('Idioma Predeterminado'),
              subtitle: Text(_defaultLanguage == 'es' ? 'Español' : 'English'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showLanguageDialog,
            ),
            Divider(),
            ListTile(
              title: Text('Zona Horaria'),
              subtitle: Text(_timezone),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showTimezoneDialog,
            ),
          ]),
          
          SizedBox(height: 20),
          _buildSectionTitle('Respaldo de Datos'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Respaldo Automático'),
              subtitle: Text('Realiza respaldos periódicos'),
              value: _autoBackup,
              onChanged: (value) => setState(() => _autoBackup = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
            if (_autoBackup) ...[
              Divider(),
              ListTile(
                title: Text('Frecuencia'),
                subtitle: Text(_getBackupFrequencyText()),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showBackupFrequencyDialog,
              ),
              Divider(),
              ListTile(
                title: Text('Hora del Respaldo'),
                subtitle: Text(_backupTime),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showTimePickerDialog,
              ),
            ],
          ]),
        ],
      ),
    );
  }
  
  Widget _buildPricingSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Tarifas Base'),
          _buildSettingCard([
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceInput('Tarifa Base', _baseFareController, AppConstants.currencySymbol),
                  SizedBox(height: 16),
                  _buildPriceInput('Por Kilómetro', _perKmController, AppConstants.currencySymbol),
                  SizedBox(height: 16),
                  _buildPriceInput('Por Minuto', _perMinController, AppConstants.currencySymbol),
                  SizedBox(height: 16),
                  _buildPriceInput('Comisión Plataforma', _commissionController, '%'),
                  SizedBox(height: 16),
                  _buildPriceInput('Penalidad Cancelación', _cancellationFeeController, AppConstants.currencySymbol),
                ],
              ),
            ),
          ]),
          
          SizedBox(height: 20),
          _buildSectionTitle('Precios Dinámicos'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Habilitar Precios Dinámicos'),
              subtitle: Text('Ajusta precios según demanda'),
              value: _dynamicPricing,
              onChanged: (value) => setState(() => _dynamicPricing = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
            if (_dynamicPricing) ...[
              Divider(),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multiplicador de Demanda Alta',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Slider(
                      value: _surgeMultiplier,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      label: '${_surgeMultiplier}x',
                      activeColor: ModernTheme.oasisGreen,
                      onChanged: (value) {
                        setState(() => _surgeMultiplier = value);
                      },
                    ),
                    Center(
                      child: Text(
                        '${_surgeMultiplier.toStringAsFixed(1)}x',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ]),
          
          SizedBox(height: 20),
          _buildSectionTitle('Horarios Especiales'),
          _buildSettingCard([
            ListTile(
              leading: Icon(Icons.nightlight, color: ModernTheme.primaryBlue),
              title: Text('Tarifa Nocturna'),
              subtitle: Text('22:00 - 06:00 (+20%)'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              ),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.weekend, color: Colors.orange),
              title: Text('Tarifa Fin de Semana'),
              subtitle: Text('Sábado y Domingo (+15%)'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              ),
            ),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildZonesSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Zonas Especiales'),
          ..._zones.map((zone) => _buildZoneCard(zone)),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _addZone,
              icon: Icon(Icons.add),
              label: Text('Agregar Zona'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildZoneCard(Zone zone) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ExpansionTile(
        title: Text(zone.name),
        subtitle: Text(
          zone.restricted ? 'Zona Restringida' : 'Recargo: ${zone.surcharge.toCurrency()}',
          style: TextStyle(
            color: zone.restricted ? ModernTheme.error : ModernTheme.textSecondary,
          ),
        ),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: zone.restricted 
                ? ModernTheme.error.withValues(alpha: 0.1)
                : ModernTheme.oasisGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.location_on,
            color: zone.restricted ? ModernTheme.error : ModernTheme.oasisGreen,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: ModernTheme.error),
          onPressed: () => _removeZone(zone),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Nombre de la Zona',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  controller: TextEditingController(text: zone.name),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Recargo (${AppConstants.currencySymbol})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixText: '${AppConstants.currencySymbol} ',
                  ),
                  controller: TextEditingController(text: zone.surcharge.toString()),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Zona Restringida'),
                  subtitle: Text('Solo conductores autorizados'),
                  value: zone.restricted,
                  onChanged: (value) {
                    setState(() => zone.restricted = value);
                  },
                  thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPromotionsSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Promociones Activas'),
          ..._promotions.map((promo) => _buildPromotionCard(promo)),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _addPromotion,
              icon: Icon(Icons.add),
              label: Text('Crear Promoción'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.oasisGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPromotionCard(Promotion promo) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  promo.code,
                  style: TextStyle(
                    color: ModernTheme.oasisGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                promo.type == DiscountType.percentage
                    ? '${promo.discount}% OFF'
                    : '${promo.discount.toCurrency()} OFF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Switch(
                value: promo.active,
                onChanged: (value) {
                  setState(() => promo.active = value);
                },
                thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: ModernTheme.textSecondary),
              SizedBox(width: 4),
              Text(
                'Vence: ${promo.expiryDate.day}/${promo.expiryDate.month}/${promo.expiryDate.year}',
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _editPromotion(promo),
                icon: Icon(Icons.edit, size: 16),
                label: Text('Editar'),
              ),
              TextButton.icon(
                onPressed: () => _removePromotion(promo),
                icon: Icon(Icons.delete, size: 16),
                label: Text('Eliminar'),
                style: TextButton.styleFrom(
                  foregroundColor: ModernTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationSettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Canales de Notificación'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Notificaciones Push'),
              subtitle: Text('Enviar notificaciones a la app'),
              value: _pushNotifications,
              onChanged: (value) => setState(() => _pushNotifications = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              secondary: Icon(Icons.notifications, color: ModernTheme.primaryBlue),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Notificaciones por Email'),
              subtitle: Text('Enviar correos electrónicos'),
              value: _emailNotifications,
              onChanged: (value) => setState(() => _emailNotifications = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              secondary: Icon(Icons.email, color: Colors.orange),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Notificaciones SMS'),
              subtitle: Text('Enviar mensajes de texto'),
              value: _smsNotifications,
              onChanged: (value) => setState(() => _smsNotifications = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              secondary: Icon(Icons.sms, color: Colors.purple),
            ),
          ]),
          
          SizedBox(height: 20),
          _buildSectionTitle('Tipos de Notificaciones'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Nuevos Viajes'),
              subtitle: Text('Notificar cuando hay nuevas solicitudes'),
              value: _notifyNewTrips,
              onChanged: (value) => setState(() => _notifyNewTrips = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Pagos y Transacciones'),
              subtitle: Text('Notificar pagos recibidos y retiros'),
              value: _notifyPayments,
              onChanged: (value) => setState(() => _notifyPayments = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Emergencias'),
              subtitle: Text('Alertas de seguridad y emergencias'),
              value: _notifyEmergencies,
              onChanged: (value) => setState(() => _notifyEmergencies = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildSecuritySettings() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Autenticación'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Autenticación de Dos Factores'),
              subtitle: Text('Requiere código adicional para admins'),
              value: _twoFactorAuth,
              onChanged: (value) => setState(() => _twoFactorAuth = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              secondary: Icon(Icons.security, color: ModernTheme.oasisGreen),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.timer, color: ModernTheme.warning),
              title: Text('Tiempo de Sesión'),
              subtitle: Text('$_sessionTimeout minutos'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      if (_sessionTimeout > 5) {
                        setState(() => _sessionTimeout -= 5);
                      }
                    },
                  ),
                  Text('$_sessionTimeout'),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() => _sessionTimeout += 5);
                    },
                  ),
                ],
              ),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.lock, color: ModernTheme.error),
              title: Text('Máximo de Intentos de Login'),
              subtitle: Text('$_maxLoginAttempts intentos'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      if (_maxLoginAttempts > 1) {
                        setState(() => _maxLoginAttempts--);
                      }
                    },
                  ),
                  Text('$_maxLoginAttempts'),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() => _maxLoginAttempts++);
                    },
                  ),
                ],
              ),
            ),
            Divider(),
            SwitchListTile(
              title: Text('Contraseñas Fuertes'),
              subtitle: Text('Mínimo 8 caracteres, mayúsculas y números'),
              value: _requireStrongPasswords,
              onChanged: (value) => setState(() => _requireStrongPasswords = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
            ),
          ]),
          
          SizedBox(height: 20),
          _buildSectionTitle('API y Acceso Externo'),
          _buildSettingCard([
            SwitchListTile(
              title: Text('Habilitar Acceso API'),
              subtitle: Text('Permite integraciones externas'),
              value: _enableApiAccess,
              onChanged: (value) => setState(() => _enableApiAccess = value),
              thumbColor: WidgetStateProperty.all(ModernTheme.oasisGreen),
              secondary: Icon(Icons.api, color: ModernTheme.primaryBlue),
            ),
            if (_enableApiAccess) ...[
              Divider(),
              ListTile(
                leading: Icon(Icons.vpn_key, color: ModernTheme.warning),
                title: Text('API Key'),
                subtitle: Text(_apiKey),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 20),
                      onPressed: _copyApiKey,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 20),
                      onPressed: _regenerateApiKey,
                    ),
                  ],
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ModernTheme.textPrimary,
        ),
      ),
    );
  }
  
  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }
  
  Widget _buildPriceInput(String label, TextEditingController controller, String suffix) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixText: suffix,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
    );
  }
  
  String _getBackupFrequencyText() {
    switch (_backupFrequency) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensual';
      default:
        return 'Diario';
    }
  }
  
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'es',
                groupValue: _defaultLanguage,
                onChanged: (value) {
                  setState(() => _defaultLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Español'),
              onTap: () {
                setState(() => _defaultLanguage = 'es');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'en',
                groupValue: _defaultLanguage,
                onChanged: (value) {
                  setState(() => _defaultLanguage = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('English'),
              onTap: () {
                setState(() => _defaultLanguage = 'en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTimezoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Seleccionar Zona Horaria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'America/Lima',
                groupValue: _timezone,
                onChanged: (value) {
                  setState(() => _timezone = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('América/Lima'),
              onTap: () {
                setState(() => _timezone = 'America/Lima');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'America/Mexico_City',
                groupValue: _timezone,
                onChanged: (value) {
                  setState(() => _timezone = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('América/México'),
              onTap: () {
                setState(() => _timezone = 'America/Mexico_City');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showBackupFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Frecuencia de Respaldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Radio<String>(
                value: 'daily',
                groupValue: _backupFrequency,
                onChanged: (value) {
                  setState(() => _backupFrequency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Diario'),
              onTap: () {
                setState(() => _backupFrequency = 'daily');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'weekly',
                groupValue: _backupFrequency,
                onChanged: (value) {
                  setState(() => _backupFrequency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Semanal'),
              onTap: () {
                setState(() => _backupFrequency = 'weekly');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Radio<String>(
                value: 'monthly',
                groupValue: _backupFrequency,
                onChanged: (value) {
                  setState(() => _backupFrequency = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text('Mensual'),
              onTap: () {
                setState(() => _backupFrequency = 'monthly');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTimePickerDialog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: 3, minute: 0),
    );
    if (time != null) {
      setState(() {
        _backupTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }
  
  void _addZone() {
    setState(() {
      _zones.add(Zone(name: 'Nueva Zona', surcharge: 0, restricted: false));
    });
  }
  
  void _removeZone(Zone zone) {
    setState(() {
      _zones.remove(zone);
    });
  }
  
  void _addPromotion() {
    setState(() {
      _promotions.add(
        Promotion(
          code: 'NUEVO',
          discount: 10,
          type: DiscountType.percentage,
          active: true,
          expiryDate: DateTime.now().add(Duration(days: 30)),
        ),
      );
    });
  }
  
  void _editPromotion(Promotion promo) {
    // Show edit dialog
  }
  
  void _removePromotion(Promotion promo) {
    setState(() {
      _promotions.remove(promo);
    });
  }
  
  void _copyApiKey() {
    Clipboard.setData(ClipboardData(text: _apiKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('API Key copiada al portapapeles'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
  
  void _regenerateApiKey() {
    setState(() {
      _apiKey = 'sk_live_${DateTime.now().millisecondsSinceEpoch}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nueva API Key generada'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configuración guardada exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
}

// Models
class Zone {
  String name;
  double surcharge;
  bool restricted;
  
  Zone({
    required this.name,
    required this.surcharge,
    required this.restricted,
  });
}

class Promotion {
  String code;
  double discount;
  DiscountType type;
  bool active;
  DateTime expiryDate;
  
  Promotion({
    required this.code,
    required this.discount,
    required this.type,
    required this.active,
    required this.expiryDate,
  });
}

enum DiscountType { percentage, fixed }