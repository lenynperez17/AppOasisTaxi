// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/currency_formatter.dart';

class TransactionsHistoryScreen extends StatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  _TransactionsHistoryScreenState createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends State<TransactionsHistoryScreen> 
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Filter state
  String _selectedFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  
  // Transactions data
  final List<Transaction> _transactions = [
    Transaction(
      id: 'T001',
      type: TransactionType.trip,
      date: DateTime.now().subtract(Duration(hours: 2)),
      amount: 45.50,
      status: TransactionStatus.completed,
      passenger: 'María García',
      pickup: 'Av. Principal 123',
      destination: 'Centro Comercial Plaza',
      distance: 8.5,
      duration: 25,
      paymentMethod: 'Efectivo',
      commission: 9.10,
      netEarnings: 36.40,
    ),
    Transaction(
      id: 'T002',
      type: TransactionType.trip,
      date: DateTime.now().subtract(Duration(hours: 5)),
      amount: 32.00,
      status: TransactionStatus.completed,
      passenger: 'Carlos López',
      pickup: 'Calle 45 #678',
      destination: 'Aeropuerto Internacional',
      distance: 15.2,
      duration: 35,
      paymentMethod: 'Tarjeta',
      commission: 6.40,
      netEarnings: 25.60,
    ),
    Transaction(
      id: 'T003',
      type: TransactionType.withdrawal,
      date: DateTime.now().subtract(Duration(days: 1)),
      amount: 500.00,
      status: TransactionStatus.completed,
      withdrawalMethod: 'Transferencia Bancaria',
      bankAccount: '****1234',
    ),
    Transaction(
      id: 'T004',
      type: TransactionType.trip,
      date: DateTime.now().subtract(Duration(days: 1)),
      amount: 28.75,
      status: TransactionStatus.cancelled,
      passenger: 'Ana Martínez',
      pickup: 'Plaza Central',
      destination: 'Universidad Nacional',
      cancellationReason: 'Pasajero no se presentó',
      cancellationFee: 5.00,
    ),
    Transaction(
      id: 'T005',
      type: TransactionType.bonus,
      date: DateTime.now().subtract(Duration(days: 2)),
      amount: 100.00,
      status: TransactionStatus.completed,
      bonusType: 'Meta semanal cumplida',
      description: 'Completaste 50 viajes esta semana',
    ),
    Transaction(
      id: 'T006',
      type: TransactionType.trip,
      date: DateTime.now().subtract(Duration(days: 2)),
      amount: 52.25,
      status: TransactionStatus.completed,
      passenger: 'Luis Torres',
      pickup: 'Hotel Marriott',
      destination: 'Distrito Financiero',
      distance: 12.3,
      duration: 28,
      paymentMethod: 'Billetera Digital',
      commission: 10.45,
      netEarnings: 41.80,
      tip: 5.00,
    ),
    Transaction(
      id: 'T007',
      type: TransactionType.refund,
      date: DateTime.now().subtract(Duration(days: 3)),
      amount: -15.00,
      status: TransactionStatus.completed,
      refundReason: 'Cobro duplicado',
      originalTransaction: 'T004',
    ),
    Transaction(
      id: 'T008',
      type: TransactionType.trip,
      date: DateTime.now().subtract(Duration(days: 3)),
      amount: 38.50,
      status: TransactionStatus.completed,
      passenger: 'Elena Rodríguez',
      pickup: 'Centro Histórico',
      destination: 'Zona Industrial',
      distance: 18.7,
      duration: 42,
      paymentMethod: 'Efectivo',
      commission: 7.70,
      netEarnings: 30.80,
    ),
  ];
  
  // Summary data
  final Map<String, dynamic> _summary = {
    'totalEarnings': 1245.50,
    'totalTrips': 142,
    'totalWithdrawals': 500.00,
    'pendingBalance': 745.50,
    'thisWeek': 456.75,
    'lastWeek': 788.75,
  };
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((transaction) {
      // Filter by type
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'trips' && transaction.type != TransactionType.trip) return false;
        if (_selectedFilter == 'withdrawals' && transaction.type != TransactionType.withdrawal) return false;
        if (_selectedFilter == 'bonuses' && transaction.type != TransactionType.bonus) return false;
        if (_selectedFilter == 'refunds' && transaction.type != TransactionType.refund) return false;
      }
      
      // Filter by date range
      if (_selectedDateRange != null) {
        if (transaction.date.isBefore(_selectedDateRange!.start) ||
            transaction.date.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }
      
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return transaction.id.toLowerCase().contains(query) ||
               (transaction.passenger?.toLowerCase().contains(query) ?? false) ||
               (transaction.pickup?.toLowerCase().contains(query) ?? false) ||
               (transaction.destination?.toLowerCase().contains(query) ?? false);
      }
      
      return true;
    }).toList();
    
    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    return filtered;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Historial de Transacciones',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportTransactions,
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          _buildSummarySection(),
          
          // Search bar
          _buildSearchBar(),
          
          // Filter chips
          _buildFilterChips(),
          
          // Transactions list
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: _buildTransactionsList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummarySection() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(16),
        children: [
          _buildSummaryCard(
            'Balance Pendiente',
            (_summary['pendingBalance'] as double).toCurrency(),
            Icons.account_balance_wallet,
            ModernTheme.oasisGreen,
            true,
          ),
          _buildSummaryCard(
            'Total Ganado',
            (_summary['totalEarnings'] as double).toCurrency(),
            Icons.attach_money,
            ModernTheme.primaryBlue,
            false,
          ),
          _buildSummaryCard(
            'Viajes',
            '${_summary['totalTrips']}',
            Icons.directions_car,
            Colors.orange,
            false,
          ),
          _buildSummaryCard(
            'Retiros',
            (_summary['totalWithdrawals'] as double).toCurrency(),
            Icons.money_off,
            Colors.purple,
            false,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool highlight) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - _slideAnimation.value), 0),
          child: Container(
            width: 140,
            margin: EdgeInsets.only(right: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: highlight ? color : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: ModernTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: highlight ? Colors.white : color,
                  size: 28,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: highlight ? Colors.white : ModernTheme.textPrimary,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: highlight ? Colors.white70 : ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por ID, pasajero o dirección...',
            border: InputBorder.none,
            icon: Icon(Icons.search, color: ModernTheme.textSecondary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
    );
  }
  
  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildFilterChip('Todos', 'all', Icons.list),
          _buildFilterChip('Viajes', 'trips', Icons.directions_car),
          _buildFilterChip('Retiros', 'withdrawals', Icons.money_off),
          _buildFilterChip('Bonos', 'bonuses', Icons.card_giftcard),
          _buildFilterChip('Reembolsos', 'refunds', Icons.replay),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : ModernTheme.textSecondary,
            ),
            SizedBox(width: 4),
            Text(label),
          ],
        ),
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        selectedColor: ModernTheme.oasisGreen,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : ModernTheme.textSecondary,
        ),
      ),
    );
  }
  
  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: ModernTheme.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No hay transacciones',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    // Group transactions by date
    Map<String, List<Transaction>> groupedTransactions = {};
    for (var transaction in _filteredTransactions) {
      final dateKey = _getDateKey(transaction.date);
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateKey = groupedTransactions.keys.elementAt(index);
        final transactions = groupedTransactions[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ),
            // Transactions for this date
            ...transactions.map((transaction) => _buildTransactionCard(transaction)),
          ],
        );
      },
    );
  }
  
  Widget _buildTransactionCard(Transaction transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Transaction icon
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTransactionIcon(transaction.type),
                  color: _getTransactionColor(transaction.type),
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              
              // Transaction details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTransactionTitle(transaction),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getTransactionSubtitle(transaction),
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (transaction.status == TransactionStatus.cancelled)
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ModernTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cancelado',
                          style: TextStyle(
                            color: ModernTheme.error,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}${transaction.amount.abs().toCurrency()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: transaction.amount >= 0 ? ModernTheme.success : ModernTheme.error,
                    ),
                  ),
                  if (transaction.netEarnings != null)
                    Text(
                      'Neto: ${transaction.netEarnings!.toCurrency()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  Text(
                    _formatTime(transaction.date),
                    style: TextStyle(
                      fontSize: 11,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Hoy';
    } else if (dateOnly == yesterday) {
      return 'Ayer';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.money_off;
      case TransactionType.bonus:
        return Icons.card_giftcard;
      case TransactionType.refund:
        return Icons.replay;
      case TransactionType.commission:
        return Icons.percent;
    }
  }
  
  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return ModernTheme.primaryBlue;
      case TransactionType.withdrawal:
        return Colors.purple;
      case TransactionType.bonus:
        return ModernTheme.oasisGreen;
      case TransactionType.refund:
        return ModernTheme.error;
      case TransactionType.commission:
        return Colors.orange;
    }
  }
  
  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.trip:
        return transaction.passenger ?? 'Viaje';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.bonus:
        return transaction.bonusType ?? 'Bono';
      case TransactionType.refund:
        return 'Reembolso';
      case TransactionType.commission:
        return 'Comisión';
    }
  }
  
  String _getTransactionSubtitle(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.trip:
        if (transaction.status == TransactionStatus.cancelled) {
          return transaction.cancellationReason ?? 'Viaje cancelado';
        }
        return '${transaction.pickup} → ${transaction.destination}';
      case TransactionType.withdrawal:
        return transaction.withdrawalMethod ?? 'Retiro de fondos';
      case TransactionType.bonus:
        return transaction.description ?? '';
      case TransactionType.refund:
        return transaction.refundReason ?? '';
      case TransactionType.commission:
        return 'Comisión de plataforma';
    }
  }
  
  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getTransactionColor(transaction.type).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTransactionIcon(transaction.type),
                      color: _getTransactionColor(transaction.type),
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTransactionTitle(transaction),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${transaction.id}',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${transaction.amount >= 0 ? '+' : ''}${transaction.amount.abs().toCurrency()}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: transaction.amount >= 0 ? ModernTheme.success : ModernTheme.error,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(),
            
            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (transaction.type == TransactionType.trip) ...[
                      _buildDetailSection('Información del Viaje', [
                        _buildDetailRow('Pasajero', transaction.passenger ?? ''),
                        _buildDetailRow('Recogida', transaction.pickup ?? ''),
                        _buildDetailRow('Destino', transaction.destination ?? ''),
                        _buildDetailRow('Distancia', '${transaction.distance ?? 0} km'),
                        _buildDetailRow('Duración', '${transaction.duration ?? 0} min'),
                      ]),
                      SizedBox(height: 20),
                      _buildDetailSection('Detalles Financieros', [
                        _buildDetailRow('Tarifa', transaction.amount.toCurrency()),
                        if (transaction.tip != null)
                          _buildDetailRow('Propina', transaction.tip!.toCurrency()),
                        _buildDetailRow('Comisión (-20%)', (transaction.commission ?? 0).toCurrency()),
                        Divider(),
                        _buildDetailRow('Ganancia Neta', (transaction.netEarnings ?? 0).toCurrency(), bold: true),
                      ]),
                      SizedBox(height: 20),
                      _buildDetailSection('Pago', [
                        _buildDetailRow('Método', transaction.paymentMethod ?? ''),
                        _buildDetailRow('Estado', transaction.status == TransactionStatus.completed ? 'Completado' : 'Cancelado'),
                      ]),
                    ],
                    
                    if (transaction.type == TransactionType.withdrawal) ...[
                      _buildDetailSection('Detalles del Retiro', [
                        _buildDetailRow('Monto', transaction.amount.abs().toCurrency()),
                        _buildDetailRow('Método', transaction.withdrawalMethod ?? ''),
                        _buildDetailRow('Cuenta', transaction.bankAccount ?? ''),
                        _buildDetailRow('Estado', 'Completado'),
                      ]),
                    ],
                    
                    if (transaction.type == TransactionType.bonus) ...[
                      _buildDetailSection('Detalles del Bono', [
                        _buildDetailRow('Tipo', transaction.bonusType ?? ''),
                        _buildDetailRow('Descripción', transaction.description ?? ''),
                        _buildDetailRow('Monto', transaction.amount.toCurrency()),
                      ]),
                    ],
                    
                    SizedBox(height: 20),
                    _buildDetailSection('Información General', [
                      _buildDetailRow('Fecha', '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}'),
                      _buildDetailRow('Hora', _formatTime(transaction.date)),
                      _buildDetailRow('ID Transacción', transaction.id),
                    ]),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _shareTransaction(transaction);
                      },
                      icon: Icon(Icons.share),
                      label: Text('Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _reportIssue(transaction);
                      },
                      icon: Icon(Icons.report),
                      label: Text('Reportar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold ? ModernTheme.oasisGreen : ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar Transacciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date range picker button
            ListTile(
              leading: Icon(Icons.date_range),
              title: Text(_selectedDateRange != null 
                  ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                  : 'Seleccionar rango de fechas'),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: ModernTheme.oasisGreen,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  setState(() => _selectedDateRange = range);
                }
              },
            ),
            if (_selectedDateRange != null)
              TextButton(
                onPressed: () {
                  setState(() => _selectedDateRange = null);
                },
                child: Text('Limpiar fechas'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Aplicar'),
          ),
        ],
      ),
    );
  }
  
  void _exportTransactions() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando transacciones...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _shareTransaction(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo transacción ${transaction.id}'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _reportIssue(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reportando problema con ${transaction.id}'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
}

// Transaction model
class Transaction {
  final String id;
  final TransactionType type;
  final DateTime date;
  final double amount;
  final TransactionStatus status;
  
  // Trip details
  final String? passenger;
  final String? pickup;
  final String? destination;
  final double? distance;
  final int? duration;
  final String? paymentMethod;
  final double? commission;
  final double? netEarnings;
  final double? tip;
  
  // Withdrawal details
  final String? withdrawalMethod;
  final String? bankAccount;
  
  // Bonus details
  final String? bonusType;
  final String? description;
  
  // Refund details
  final String? refundReason;
  final String? originalTransaction;
  
  // Cancellation details
  final String? cancellationReason;
  final double? cancellationFee;
  
  Transaction({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.status,
    this.passenger,
    this.pickup,
    this.destination,
    this.distance,
    this.duration,
    this.paymentMethod,
    this.commission,
    this.netEarnings,
    this.tip,
    this.withdrawalMethod,
    this.bankAccount,
    this.bonusType,
    this.description,
    this.refundReason,
    this.originalTransaction,
    this.cancellationReason,
    this.cancellationFee,
  });
}

enum TransactionType { trip, withdrawal, bonus, refund, commission }
enum TransactionStatus { completed, pending, cancelled }