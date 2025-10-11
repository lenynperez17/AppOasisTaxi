// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/utils/currency_formatter.dart';

enum TransactionType { trip, withdrawal, commission, refund }
enum PaymentStatus { completed, pending, failed, processing }

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final PaymentStatus status;
  final String description;
  final String? driverId;
  final String? driverName;
  final String? passengerId;
  final String? passengerName;
  final double? commission;
  final String? invoiceNumber;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    required this.description,
    this.driverId,
    this.driverName,
    this.passengerId,
    this.passengerName,
    this.commission,
    this.invoiceNumber,
  });
}

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  _FinancialScreenState createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _chartAnimationController;
  late AnimationController _statsAnimationController;
  
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedPeriod = 'today';
  String _searchQuery = '';
  double _currentCommissionRate = 20.0; // 20% commission
  final bool _isLoading = true;

  // Datos financieros desde Firebase
  final Map<String, double> _financialStats = {
    'totalRevenue': 45678.90,
    'totalCommissions': 9135.78,
    'pendingPayouts': 3456.50,
    'completedPayouts': 32086.62,
    'avgTripValue': 18.75,
    'dailyAverage': 1522.63,
  };
  
  final List<Transaction> _transactions = [
    Transaction(
      id: 'TRX001',
      type: TransactionType.trip,
      amount: 25.50,
      date: DateTime.now().subtract(Duration(hours: 1)),
      status: PaymentStatus.completed,
      description: 'Viaje #V001',
      driverId: 'D001',
      driverName: 'Juan Pérez',
      passengerId: 'P001',
      passengerName: 'María García',
      commission: 5.10,
    ),
    Transaction(
      id: 'TRX002',
      type: TransactionType.withdrawal,
      amount: 250.00,
      date: DateTime.now().subtract(Duration(hours: 3)),
      status: PaymentStatus.processing,
      description: 'Retiro conductor',
      driverId: 'D002',
      driverName: 'Carlos López',
    ),
    Transaction(
      id: 'TRX003',
      type: TransactionType.commission,
      amount: 4.80,
      date: DateTime.now().subtract(Duration(hours: 5)),
      status: PaymentStatus.completed,
      description: 'Comisión viaje #V002',
      driverId: 'D003',
      driverName: 'Ana Martínez',
    ),
    Transaction(
      id: 'TRX004',
      type: TransactionType.refund,
      amount: 15.00,
      date: DateTime.now().subtract(Duration(days: 1)),
      status: PaymentStatus.completed,
      description: 'Reembolso viaje cancelado',
      passengerId: 'P002',
      passengerName: 'Luis Torres',
    ),
    Transaction(
      id: 'TRX005',
      type: TransactionType.trip,
      amount: 32.75,
      date: DateTime.now().subtract(Duration(days: 1)),
      status: PaymentStatus.completed,
      description: 'Viaje #V003',
      driverId: 'D001',
      driverName: 'Juan Pérez',
      passengerId: 'P003',
      passengerName: 'Sofia Mendez',
      commission: 6.55,
    ),
  ];
  
  final List<Map<String, dynamic>> _pendingPayouts = [
    {
      'driverId': 'D001',
      'driverName': 'Juan Pérez',
      'amount': 456.80,
      'trips': 24,
      'requestDate': DateTime.now().subtract(Duration(days: 2)),
      'accountNumber': '**** 1234',
      'bank': 'BCP',
    },
    {
      'driverId': 'D002',
      'driverName': 'Carlos López',
      'amount': 678.50,
      'trips': 35,
      'requestDate': DateTime.now().subtract(Duration(days: 1)),
      'accountNumber': '**** 5678',
      'bank': 'Interbank',
    },
    {
      'driverId': 'D003',
      'driverName': 'Ana Martínez',
      'amount': 234.25,
      'trips': 15,
      'requestDate': DateTime.now(),
      'accountNumber': '**** 9012',
      'bank': 'BBVA',
    },
  ];
  
  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((transaction) {
      if (_searchQuery.isEmpty) return true;
      
      return transaction.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             transaction.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (transaction.driverName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (transaction.passengerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (transaction.invoiceNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
    
    // Apply tab filter
    switch (_tabController.index) {
      case 1: // Income
        filtered = filtered.where((t) => 
          t.type == TransactionType.trip || t.type == TransactionType.commission).toList();
        break;
      case 2: // Payouts
        filtered = filtered.where((t) => t.type == TransactionType.withdrawal).toList();
        break;
      case 3: // Refunds
        filtered = filtered.where((t) => t.type == TransactionType.refund).toList();
        break;
    }
    
    // Apply period filter
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        filtered = filtered.where((t) => 
          t.date.year == now.year && 
          t.date.month == now.month && 
          t.date.day == now.day).toList();
        break;
      case 'week':
        final weekAgo = now.subtract(Duration(days: 7));
        filtered = filtered.where((t) => t.date.isAfter(weekAgo)).toList();
        break;
      case 'month':
        filtered = filtered.where((t) => 
          t.date.year == now.year && t.date.month == now.month).toList();
        break;
    }
    
    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    return filtered;
  }
  
  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 4, vsync: this);
    _chartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _statsAnimationController.forward(from: 0);
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _chartAnimationController.dispose();
    _statsAnimationController.dispose();
    _searchController.dispose();
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
          'Control Financiero',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: _showCommissionSettings,
          ),
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportFinancialReport,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: TabBar(
            controller: _tabController,
            indicatorColor: ModernTheme.oasisGreen,
            labelColor: ModernTheme.oasisGreen,
            unselectedLabelColor: ModernTheme.textSecondary,
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Ingresos'),
              Tab(text: 'Pagos'),
              Tab(text: 'Reembolsos'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildIncomeTab(),
          _buildPayoutsTab(),
          _buildRefundsTab(),
        ],
      ),
    );
  }
  
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          _buildPeriodSelector(),
          
          SizedBox(height: 20),
          
          // Financial stats cards
          AnimatedBuilder(
            animation: _statsAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - _statsAnimationController.value)),
                child: Opacity(
                  opacity: _statsAnimationController.value,
                  child: _buildFinancialStats(),
                ),
              );
            },
          ),
          
          SizedBox(height: 24),
          
          // Revenue chart
          _buildRevenueChart(),
          
          SizedBox(height: 24),
          
          // Commission breakdown
          _buildCommissionBreakdown(),
          
          SizedBox(height: 24),
          
          // Recent transactions
          _buildRecentTransactions(),
        ],
      ),
    );
  }
  
  Widget _buildIncomeTab() {
    return Column(
      children: [
        // Search bar
        Container(
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar transacción...',
              hintStyle: TextStyle(color: ModernTheme.textSecondary),
              prefixIcon: Icon(Icons.search, color: ModernTheme.oasisGreen),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        
        // Income summary
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ModernTheme.success, ModernTheme.success.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIncomeStat('Total Ingresos', _financialStats['totalRevenue']!.toCurrency()),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _buildIncomeStat('Comisiones', _financialStats['totalCommissions']!.toCurrency()),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _buildIncomeStat('Promedio', _financialStats['avgTripValue']!.toCurrency()),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Transactions list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredTransactions.where((t) => 
              t.type == TransactionType.trip || t.type == TransactionType.commission).length,
            itemBuilder: (context, index) {
              final incomeTransactions = _filteredTransactions.where((t) => 
                t.type == TransactionType.trip || t.type == TransactionType.commission).toList();
              final transaction = incomeTransactions[index];
              return _buildTransactionCard(transaction);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPayoutsTab() {
    return Column(
      children: [
        // Pending payouts header
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ModernTheme.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ModernTheme.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: ModernTheme.warning),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos Pendientes',
                      style: TextStyle(
                        color: ModernTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_financialStats['pendingPayouts']!.toCurrency()} en ${_pendingPayouts.length} solicitudes',
                      style: TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _processAllPayouts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Procesar Todos'),
              ),
            ],
          ),
        ),
        
        // Pending payouts list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingPayouts.length,
            itemBuilder: (context, index) {
              final payout = _pendingPayouts[index];
              return _buildPayoutCard(payout);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildRefundsTab() {
    return Column(
      children: [
        // Refunds summary
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ModernTheme.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ModernTheme.error.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.replay, color: ModernTheme.error, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Reembolsos',
                      style: TextStyle(color: ModernTheme.textSecondary, fontSize: 14),
                    ),
                    Text(
                      234.50.toCurrency(),
                      style: TextStyle(
                        color: ModernTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '8 reembolsos este mes',
                      style: TextStyle(color: ModernTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Refunds list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredTransactions.where((t) => 
              t.type == TransactionType.refund).length,
            itemBuilder: (context, index) {
              final refundTransactions = _filteredTransactions.where((t) => 
                t.type == TransactionType.refund).toList();
              final transaction = refundTransactions[index];
              return _buildTransactionCard(transaction);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildPeriodChip('Hoy', 'today'),
          _buildPeriodChip('Esta Semana', 'week'),
          _buildPeriodChip('Este Mes', 'month'),
          _buildPeriodChip('Este Año', 'year'),
          _buildPeriodChip('Personalizado', 'custom'),
        ],
      ),
    );
  }
  
  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: ModernTheme.oasisGreen,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : ModernTheme.textSecondary,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedPeriod = value);
            if (value == 'custom') {
              _showDateRangePicker();
            }
          }
        },
      ),
    );
  }
  
  Widget _buildFinancialStats() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Ingresos Totales',
          _financialStats['totalRevenue']!.toCurrency(),
          Icons.trending_up,
          ModernTheme.success,
          '+22.5%',
        ),
        _buildStatCard(
          'Comisiones',
          _financialStats['totalCommissions']!.toCurrency(),
          Icons.percent,
          ModernTheme.primaryBlue,
          '20%',
        ),
        _buildStatCard(
          'Pagos Pendientes',
          _financialStats['pendingPayouts']!.toCurrency(),
          Icons.schedule,
          ModernTheme.warning,
          '${_pendingPayouts.length}',
        ),
        _buildStatCard(
          'Pagos Completados',
          _financialStats['completedPayouts']!.toCurrency(),
          Icons.check_circle,
          ModernTheme.oasisGreen,
          '156',
        ),
        _buildStatCard(
          'Valor Promedio',
          _financialStats['avgTripValue']!.toCurrency(),
          Icons.analytics,
          Colors.purple,
          '+5.2%',
        ),
        _buildStatCard(
          'Promedio Diario',
          _financialStats['dailyAverage']!.toCurrency(),
          Icons.calendar_today,
          Colors.orange,
          '+18.3%',
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color, String extra) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  extra,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueChart() {
    return Container(
      height: 250,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendencia de Ingresos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: AnimatedBuilder(
              animation: _chartAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: RevenueChartPainter(
                    progress: _chartAnimationController.value,
                    data: [
                      1200, 1500, 1300, 1800, 2100, 1900, 2300,
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((day) => Text(
                      day,
                      style: TextStyle(color: ModernTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommissionBreakdown() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Desglose de Comisiones',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_currentCommissionRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: ModernTheme.oasisGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          _buildCommissionRow('Viajes Estándar', 18.0, 3456.78),
          _buildCommissionRow('Viajes Premium', 22.0, 2134.56),
          _buildCommissionRow('Viajes Corporativos', 15.0, 3544.44),
          
          Divider(color: Colors.grey.shade300, height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Comisiones',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _financialStats['totalCommissions']!.toCurrency(),
                style: TextStyle(
                  color: ModernTheme.oasisGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommissionRow(String type, double rate, double amount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(color: ModernTheme.textPrimary, fontSize: 14),
                ),
                Text(
                  '${rate.toStringAsFixed(0)}% de comisión',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount.toCurrency(),
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentTransactions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transacciones Recientes',
                style: TextStyle(
                  color: ModernTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _tabController.index = 1);
                },
                child: Text(
                  'Ver todas',
                  style: TextStyle(color: ModernTheme.oasisGreen),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          ..._transactions.take(5).map((transaction) => 
            _buildTransactionRow(transaction)),
        ],
      ),
    );
  }
  
  Widget _buildTransactionRow(Transaction transaction) {
    final icon = _getTransactionIcon(transaction.type);
    final color = _getTransactionColor(transaction.type);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    color: ModernTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  transaction.driverName ?? transaction.passengerName ?? 'Sistema',
                  style: TextStyle(
                    color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.type == TransactionType.withdrawal || transaction.type == TransactionType.refund ? '-' : '+'} ${transaction.amount.toCurrency()}',
                style: TextStyle(
                  color: transaction.type == TransactionType.withdrawal ||
                         transaction.type == TransactionType.refund
                    ? ModernTheme.error
                    : ModernTheme.success,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatTime(transaction.date),
                style: TextStyle(
                  color: ModernTheme.textSecondary.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionCard(Transaction transaction) {
    final icon = _getTransactionIcon(transaction.type);
    final color = _getTransactionColor(transaction.type);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(transaction.status).withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: TextStyle(
                            color: ModernTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          transaction.id,
                          style: TextStyle(
                            color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        transaction.amount.toCurrency(),
                        style: TextStyle(
                          color: ModernTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(transaction.status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(transaction.status),
                          style: TextStyle(
                            color: _getStatusColor(transaction.status),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (transaction.driverName != null || transaction.passengerName != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    if (transaction.driverName != null) ...[
                      Icon(Icons.directions_car, size: 14, color: ModernTheme.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        transaction.driverName!,
                        style: TextStyle(color: ModernTheme.textSecondary, fontSize: 13),
                      ),
                      SizedBox(width: 16),
                    ],
                    if (transaction.passengerName != null) ...[
                      Icon(Icons.person, size: 14, color: ModernTheme.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        transaction.passengerName!,
                        style: TextStyle(color: ModernTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                    Spacer(),
                    Text(
                      _formatDateTime(transaction.date),
                      style: TextStyle(color: ModernTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ],
              
              if (transaction.commission != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.percent, size: 14, color: ModernTheme.primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        'Comisión: ${transaction.commission!.toCurrency()}',
                        style: TextStyle(
                          color: ModernTheme.primaryBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ModernTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.2),
                  child: Icon(Icons.person, color: ModernTheme.oasisGreen),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payout['driverName'],
                        style: TextStyle(
                          color: ModernTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${payout['trips']} viajes completados',
                        style: TextStyle(
                          color: ModernTheme.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  payout['amount'].toCurrency(),
                  style: TextStyle(
                    color: ModernTheme.warning,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance, size: 16, color: Colors.white54),
                  SizedBox(width: 8),
                  Text(
                    '${payout['bank']} - ${payout['accountNumber']}',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Spacer(),
                  Text(
                    'Solicitado ${_formatDate(payout['requestDate'])}',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectPayout(payout),
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ModernTheme.error,
                      side: BorderSide(color: ModernTheme.error),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePayout(payout),
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Aprobar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIncomeStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return Icons.directions_car;
      case TransactionType.withdrawal:
        return Icons.account_balance_wallet;
      case TransactionType.commission:
        return Icons.percent;
      case TransactionType.refund:
        return Icons.replay;
    }
  }
  
  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return ModernTheme.success;
      case TransactionType.withdrawal:
        return ModernTheme.warning;
      case TransactionType.commission:
        return ModernTheme.primaryBlue;
      case TransactionType.refund:
        return ModernTheme.error;
    }
  }
  
  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return ModernTheme.success;
      case PaymentStatus.pending:
        return ModernTheme.warning;
      case PaymentStatus.failed:
        return ModernTheme.error;
      case PaymentStatus.processing:
        return ModernTheme.primaryBlue;
    }
  }
  
  String _getStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return 'COMPLETADO';
      case PaymentStatus.pending:
        return 'PENDIENTE';
      case PaymentStatus.failed:
        return 'FALLIDO';
      case PaymentStatus.processing:
        return 'PROCESANDO';
    }
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
  
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ModernTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Text(
              'Detalles de Transacción',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 20),
            
            _buildDetailRow('ID Transacción', transaction.id),
            _buildDetailRow('Tipo', _getTransactionTypeName(transaction.type)),
            _buildDetailRow('Monto', transaction.amount.toCurrency()),
            _buildDetailRow('Estado', _getStatusText(transaction.status)),
            _buildDetailRow('Fecha', _formatDateTime(transaction.date)),
            
            if (transaction.driverName != null)
              _buildDetailRow('Conductor', transaction.driverName!),
            if (transaction.passengerName != null)
              _buildDetailRow('Pasajero', transaction.passengerName!),
            if (transaction.commission != null)
              _buildDetailRow('Comisión', transaction.commission!.toCurrency()),
            if (transaction.invoiceNumber != null)
              _buildDetailRow('Nº Factura', transaction.invoiceNumber!),
            
            SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _exportTransaction(transaction);
                    },
                    icon: Icon(Icons.download),
                    label: Text('Exportar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.primaryBlue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateInvoice(transaction);
                    },
                    icon: Icon(Icons.receipt),
                    label: Text('Factura'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(color: ModernTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  String _getTransactionTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.trip:
        return 'Viaje';
      case TransactionType.withdrawal:
        return 'Retiro';
      case TransactionType.commission:
        return 'Comisión';
      case TransactionType.refund:
        return 'Reembolso';
    }
  }
  
  void _showCommissionSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ModernTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Configuración de Comisiones',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tasa de comisión actual',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _currentCommissionRate,
                    min: 10,
                    max: 30,
                    divisions: 20,
                    activeColor: ModernTheme.oasisGreen,
                    onChanged: (value) {
                      setState(() => _currentCommissionRate = value);
                      Navigator.pop(context);
                      _showCommissionSettings();
                    },
                  ),
                ),
                Text(
                  '${_currentCommissionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: ModernTheme.oasisGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Comisiones por tipo de viaje',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 12),
            _buildCommissionSetting('Viajes Estándar', 18),
            _buildCommissionSetting('Viajes Premium', 22),
            _buildCommissionSetting('Viajes Corporativos', 15),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Comisiones actualizadas'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommissionSetting(String type, int rate) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(type, style: TextStyle(color: ModernTheme.textPrimary, fontSize: 14)),
          Text('$rate%', style: TextStyle(color: ModernTheme.oasisGreen, fontSize: 14)),
        ],
      ),
    );
  }
  
  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: ModernTheme.oasisGreen,
              surface: ModernTheme.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      // Handle date range selection
    }
  }
  
  void _processAllPayouts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ModernTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Procesar Todos los Pagos', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de procesar ${_pendingPayouts.length} pagos por un total de ${_financialStats['pendingPayouts']!.toCurrency()}?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Procesando ${_pendingPayouts.length} pagos...'),
                  backgroundColor: ModernTheme.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.warning,
            ),
            child: Text('Procesar'),
          ),
        ],
      ),
    );
  }
  
  void _approvePayout(Map<String, dynamic> payout) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pago aprobado: ${payout['amount'].toCurrency()} a ${payout['driverName']}'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
  
  void _rejectPayout(Map<String, dynamic> payout) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pago rechazado'),
        backgroundColor: ModernTheme.error,
      ),
    );
  }
  
  void _exportFinancialReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando reporte financiero...'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }
  
  void _exportTransaction(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando transacción ${transaction.id}...'),
        backgroundColor: ModernTheme.primaryBlue,
      ),
    );
  }
  
  void _generateInvoice(Transaction transaction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando factura...'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
  }
}

// Custom painter for revenue chart
class RevenueChartPainter extends CustomPainter {
  final double progress;
  final List<double> data;
  
  const RevenueChartPainter({super.repaint, required this.progress, required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          ModernTheme.oasisGreen.withValues(alpha: 0.3),
          ModernTheme.oasisGreen.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final path = Path();
    final fillPath = Path();
    
    final maxValue = data.reduce(math.max);
    final stepX = size.width / (data.length - 1);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height * 0.8 * progress;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    // Draw fill
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    paint.color = ModernTheme.oasisGreen;
    canvas.drawPath(path, paint);
    
    // Draw points
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = ModernTheme.oasisGreen;
    
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue) * size.height * 0.8 * progress;
      
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}