// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/common/oasis_app_bar.dart';

class HelpCenterScreen extends StatefulWidget {
  final String? userType;
  
  HelpCenterScreen({super.key, this.userType});
  
  @override
  _HelpCenterScreenState createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  
  final List<Map<String, String>> _faqs = [
    {
      'question': '¿Cómo solicitar un viaje?',
      'answer': 'Ingresa tu destino, selecciona el tipo de vehículo y confirma tu solicitud.',
    },
    {
      'question': '¿Cómo cancelar un viaje?',
      'answer': 'Puedes cancelar desde la pantalla de seguimiento antes de que llegue el conductor.',
    },
    {
      'question': '¿Qué métodos de pago acepta?',
      'answer': 'Aceptamos efectivo, tarjetas de débito/crédito y billeteras digitales.',
    },
    {
      'question': '¿Cómo calificar a un conductor?',
      'answer': 'Al finalizar el viaje aparecerá automáticamente la pantalla de calificación.',
    },
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: OasisAppBar(
        title: 'Centro de Ayuda',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: TabController(length: 3, vsync: Scaffold.of(context)),
              tabs: [
                Tab(text: 'FAQ'),
                Tab(text: 'Contacto'),
                Tab(text: 'Guías'),
              ],
              labelColor: ModernTheme.oasisGreen,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              indicatorColor: ModernTheme.oasisGreen,
              onTap: (index) => setState(() => _selectedTab = index),
            ),
          ),
          
          // Search bar
          if (_selectedTab == 0) _buildSearchBar(),
          
          // Content
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar en preguntas frecuentes...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ModernTheme.oasisGreen),
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }
  
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildFAQList();
      case 1:
        return _buildContactOptions();
      case 2:
        return _buildGuides();
      default:
        return _buildFAQList();
    }
  }
  
  Widget _buildFAQList() {
    final filteredFAQs = _faqs.where((faq) {
      final searchTerm = _searchController.text.toLowerCase();
      return faq['question']!.toLowerCase().contains(searchTerm) ||
             faq['answer']!.toLowerCase().contains(searchTerm);
    }).toList();
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredFAQs.length,
      itemBuilder: (context, index) {
        final faq = filteredFAQs[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(
              faq['question']!,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(faq['answer']!),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildContactOptions() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildContactCard(
          'Chat en Vivo',
          'Respuesta inmediata',
          Icons.chat,
          ModernTheme.oasisGreen,
          () {},
        ),
        _buildContactCard(
          'Email',
          'soporte@oasistaxi.com',
          Icons.email,
          ModernTheme.info,
          () {},
        ),
        _buildContactCard(
          'Teléfono',
          '+51 1 234-5678',
          Icons.phone,
          ModernTheme.warning,
          () {},
        ),
        _buildContactCard(
          'WhatsApp',
          'Mensaje directo',
          Icons.message,
          ModernTheme.success,
          () {},
        ),
      ],
    );
  }
  
  Widget _buildContactCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  
  Widget _buildGuides() {
    final guides = [
      {'title': 'Cómo solicitar tu primer viaje', 'icon': Icons.play_circle},
      {'title': 'Configurar métodos de pago', 'icon': Icons.payment},
      {'title': 'Usar promociones y descuentos', 'icon': Icons.local_offer},
      {'title': 'Compartir tu ubicación', 'icon': Icons.location_on},
    ];
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: guides.length,
      itemBuilder: (context, index) {
        final guide = guides[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(guide['icon'] as IconData, color: ModernTheme.oasisGreen),
            title: Text(guide['title'] as String),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Abrir guía
            },
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}