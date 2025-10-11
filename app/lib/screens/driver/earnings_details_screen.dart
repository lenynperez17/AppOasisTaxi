// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

class EarningsDetailsScreen extends StatefulWidget {
  const EarningsDetailsScreen({super.key});

  @override
  _EarningsDetailsScreenState createState() => _EarningsDetailsScreenState();
}

class _EarningsDetailsScreenState extends State<EarningsDetailsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _chartController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _chartAnimation;
  
  // Selected period
  String _selectedPeriod = 'week';
  
  // Earnings data
  EarningsData? _earningsData;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _chartController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOut,
    );
    
    _loadEarningsData();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _chartController.dispose();
    super.dispose();
  }
  
  void _loadEarningsData() async {
    setState(() => _isLoading = true);
    
    // Simulate data loading
    await Future.delayed(Duration(seconds: 1));
    
    setState(() {
      _earningsData = _generateMockData(_selectedPeriod);
      _isLoading = false;
    });
    
    _fadeController.forward();
    _chartController.forward();
  }
  
  EarningsData _generateMockData(String period) {
    final random = math.Random();
    
    switch (period) {
      case 'week':
        return EarningsData(
          period: 'Esta Semana',
          totalEarnings: 456.75,
          totalTrips: 23,
          avgPerTrip: 19.86,
          totalHours: 28.5,
          avgPerHour: 16.02,
          onlineHours: 32.0,
          commission: 91.35,
          netEarnings: 365.40,
          dailyData: List.generate(7, (index) {
            return DailyEarnings(
              date: DateTime.now().subtract(Duration(days: 6 - index)),
              earnings: 40 + random.nextDouble() * 80,
              trips: 2 + random.nextInt(6),
              hours: 3 + random.nextDouble() * 6,
              online: true,
            );
          }),
          hourlyData: List.generate(24, (index) {
            final baseEarning = index >= 6 && index <= 22 ? 15 + random.nextDouble() * 25 : random.nextDouble() * 8;
            return HourlyEarnings(
              hour: index,
              earnings: baseEarning,
              trips: baseEarning > 10 ? 1 + random.nextInt(3) : 0,
            );
          }),
          breakdown: EarningsBreakdown(
            baseFares: 228.75,
            distanceFares: 156.40,
            timeFares: 48.20,
            tips: 23.40,
            bonuses: 0.0,
            surgeEarnings: 0.0,
          ),
          goals: WeeklyGoals(
            earningsGoal: 500.0,
            tripsGoal: 30,
            hoursGoal: 35.0,
            achievedEarnings: 456.75,
            achievedTrips: 23,
            achievedHours: 28.5,
          ),
        );
      
      case 'month':
        return EarningsData(
          period: 'Este Mes',
          totalEarnings: 1823.40,
          totalTrips: 142,
          avgPerTrip: 12.84,
          totalHours: 156.5,
          avgPerHour: 11.65,
          onlineHours: 180.0,
          commission: 364.68,
          netEarnings: 1458.72,
          dailyData: List.generate(30, (index) {
            return DailyEarnings(
              date: DateTime.now().subtract(Duration(days: 29 - index)),
              earnings: 30 + random.nextDouble() * 100,
              trips: 3 + random.nextInt(8),
              hours: 4 + random.nextDouble() * 8,
              online: random.nextBool() || index % 7 != 0, // Most days online except some Sundays
            );
          }),
          hourlyData: List.generate(24, (index) {
            final baseEarning = index >= 6 && index <= 22 ? 20 + random.nextDouble() * 40 : random.nextDouble() * 15;
            return HourlyEarnings(
              hour: index,
              earnings: baseEarning,
              trips: baseEarning > 15 ? 2 + random.nextInt(5) : random.nextInt(2),
            );
          }),
          breakdown: EarningsBreakdown(
            baseFares: 911.70,
            distanceFares: 637.19,
            timeFares: 182.34,
            tips: 91.17,
            bonuses: 1.00,
            surgeEarnings: 0.0,
          ),
          goals: WeeklyGoals(
            earningsGoal: 2000.0,
            tripsGoal: 160,
            hoursGoal: 160.0,
            achievedEarnings: 1823.40,
            achievedTrips: 142,
            achievedHours: 156.5,
          ),
        );
      
      default: // year
        return EarningsData(
          period: 'Este Año',
          totalEarnings: 18234.50,
          totalTrips: 1456,
          avgPerTrip: 12.52,
          totalHours: 1680.0,
          avgPerHour: 10.85,
          onlineHours: 1920.0,
          commission: 3646.90,
          netEarnings: 14587.60,
          dailyData: [], // Too much data for daily view
          hourlyData: List.generate(24, (index) {
            final baseEarning = index >= 6 && index <= 22 ? 150 + random.nextDouble() * 300 : random.nextDouble() * 100;
            return HourlyEarnings(
              hour: index,
              earnings: baseEarning,
              trips: (baseEarning / 15).round(),
            );
          }),
          breakdown: EarningsBreakdown(
            baseFares: 9117.25,
            distanceFares: 6371.93,
            timeFares: 1823.45,
            tips: 911.73,
            bonuses: 10.14,
            surgeEarnings: 0.0,
          ),
          goals: WeeklyGoals(
            earningsGoal: 20000.0,
            tripsGoal: 1600,
            hoursGoal: 1800.0,
            achievedEarnings: 18234.50,
            achievedTrips: 1456,
            achievedHours: 1680.0,
          ),
        );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Análisis de Ganancias',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Colors.white),
            onPressed: _exportData,
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: _shareReport,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildEarningsDetails(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Analizando tus ganancias...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEarningsDetails() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Column(
            children: [
              // Period selector
              _buildPeriodSelector(),
              
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Summary cards
                      _buildSummaryCards(),
                      
                      // Goals progress
                      _buildGoalsSection(),
                      
                      // Earnings chart
                      _buildEarningsChart(),
                      
                      // Hourly analysis
                      _buildHourlyAnalysis(),
                      
                      // Breakdown
                      _buildEarningsBreakdown(),
                      
                      // Performance insights
                      _buildInsights(),
                      
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPeriodSelector() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(4),
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
      child: Row(
        children: ['week', 'month', 'year'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = period);
                _loadEarningsData();
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? ModernTheme.oasisGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getPeriodLabel(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : ModernTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  String _getPeriodLabel(String period) {
    switch (period) {
      case 'week':
        return 'Semana';
      case 'month':
        return 'Mes';
      case 'year':
        return 'Año';
      default:
        return period;
    }
  }
  
  Widget _buildSummaryCards() {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSummaryCard(
            'Ganancias Totales',
            _earningsData!.totalEarnings.toCurrency(),
            Icons.attach_money,
            ModernTheme.success,
            'Neto: ${_earningsData!.netEarnings.toCurrency()}',
          ),
          _buildSummaryCard(
            'Total de Viajes',
            '${_earningsData!.totalTrips}',
            Icons.directions_car,
            ModernTheme.primaryBlue,
            'Promedio: ${_earningsData!.avgPerTrip.toCurrency()}',
          ),
          _buildSummaryCard(
            'Horas Trabajadas',
            '${_earningsData!.totalHours.toStringAsFixed(1)}h',
            Icons.schedule,
            ModernTheme.warning,
            'Por hora: ${_earningsData!.avgPerHour.toCurrency()}',
          ),
          _buildSummaryCard(
            'Tiempo Online',
            '${_earningsData!.onlineHours.toStringAsFixed(1)}h',
            Icons.online_prediction,
            ModernTheme.oasisGreen,
            'Eficiencia: ${(_earningsData!.totalHours / _earningsData!.onlineHours * 100).toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: ModernTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalsSection() {
    final goals = _earningsData!.goals;
    
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: ModernTheme.oasisGreen),
              SizedBox(width: 8),
              Text(
                'Progreso de Metas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildGoalProgress(
            'Ganancias',
            goals.achievedEarnings,
            goals.earningsGoal,
            AppConstants.currencySymbol,
            ModernTheme.success,
          ),
          SizedBox(height: 16),
          _buildGoalProgress(
            'Viajes',
            goals.achievedTrips.toDouble(),
            goals.tripsGoal.toDouble(),
            '',
            ModernTheme.primaryBlue,
          ),
          SizedBox(height: 16),
          _buildGoalProgress(
            'Horas',
            goals.achievedHours,
            goals.hoursGoal,
            'h',
            ModernTheme.warning,
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalProgress(String label, double achieved, double goal, String unit, Color color) {
    final progress = (achieved / goal).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$unit${achieved.toStringAsFixed(achieved % 1 == 0 ? 0 : 1)} / $unit${goal.toStringAsFixed(goal % 1 == 0 ? 0 : 1)}',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% completado',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEarningsChart() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: ModernTheme.primaryBlue),
              SizedBox(width: 8),
              Text(
                'Tendencia de Ganancias',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: EarningsChartPainter(
                    data: _earningsData!.dailyData,
                    animation: _chartAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHourlyAnalysis() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Análisis por Horas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: HourlyEarningsChartPainter(
                data: _earningsData!.hourlyData,
              ),
              size: Size.infinite,
            ),
          ),
          SizedBox(height: 12),
          _buildHourlyInsights(),
        ],
      ),
    );
  }
  
  Widget _buildHourlyInsights() {
    final bestHour = _earningsData!.hourlyData
        .reduce((a, b) => a.earnings > b.earnings ? a : b);
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ModernTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.amber, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tu mejor hora: ${bestHour.hour}:00 - ${bestHour.hour + 1}:00 (${bestHour.earnings.toCurrency()})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEarningsBreakdown() {
    final breakdown = _earningsData!.breakdown;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Desglose de Ingresos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildBreakdownItem('Tarifas base', breakdown.baseFares, Icons.monetization_on, ModernTheme.primaryBlue),
          _buildBreakdownItem('Por distancia', breakdown.distanceFares, Icons.straighten, ModernTheme.success),
          _buildBreakdownItem('Por tiempo', breakdown.timeFares, Icons.schedule, ModernTheme.warning),
          if (breakdown.tips > 0)
            _buildBreakdownItem('Propinas', breakdown.tips, Icons.star, Colors.amber),
          if (breakdown.bonuses > 0)
            _buildBreakdownItem('Bonos', breakdown.bonuses, Icons.card_giftcard, ModernTheme.oasisGreen),
          if (breakdown.surgeEarnings > 0)
            _buildBreakdownItem('Tarifa dinámica', breakdown.surgeEarnings, Icons.trending_up, Colors.red),
          Divider(),
          _buildBreakdownItem('Comisión (-20%)', -_earningsData!.commission, Icons.remove_circle, ModernTheme.error),
          Divider(),
          _buildBreakdownItem('Total neto', _earningsData!.netEarnings, Icons.account_balance_wallet, ModernTheme.oasisGreen, isTotal: true),
        ],
      ),
    );
  }
  
  Widget _buildBreakdownItem(String label, double amount, IconData icon, Color color, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Text(
            '${amount >= 0 ? '' : '-'}${amount.abs().toCurrency()}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? color : (amount >= 0 ? ModernTheme.textPrimary : ModernTheme.error),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInsights() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Insights y Recomendaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInsightCard(
            'Mejores días',
            'Martes y Viernes son tus días más rentables',
            Icons.calendar_today,
            ModernTheme.success,
          ),
          SizedBox(height: 12),
          _buildInsightCard(
            'Horario óptimo',
            'Concéntrate en las horas de 7-9 AM y 6-8 PM',
            Icons.schedule,
            ModernTheme.primaryBlue,
          ),
          SizedBox(height: 12),
          _buildInsightCard(
            'Oportunidad',
            'Puedes aumentar 15% trabajando 2 horas más los fines de semana',
            Icons.trending_up,
            ModernTheme.warning,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInsightCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exportando datos de ganancias...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _shareReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo reporte de ganancias...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// Custom painters
class EarningsChartPainter extends CustomPainter {
  final List<DailyEarnings> data;
  final double animation;
  
  const EarningsChartPainter({super.repaint, required this.data, required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = ModernTheme.oasisGreen.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    final linePaint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final maxEarnings = data.map((d) => d.earnings).reduce(math.max);
    final points = <Offset>[];
    
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final y = size.height - (data[i].earnings / maxEarnings * size.height * animation);
      points.add(Offset(x, y));
    }
    
    // Draw filled area
    final path = Path();
    path.moveTo(0, size.height);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw line
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }
    
    // Draw points
    final pointPaint = Paint()
      ..color = ModernTheme.oasisGreen
      ..style = PaintingStyle.fill;
    
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HourlyEarningsChartPainter extends CustomPainter {
  final List<HourlyEarnings> data;
  
  const HourlyEarningsChartPainter({super.repaint, required this.data});
  
  @override
  void paint(Canvas canvas, Size size) {
    final maxEarnings = data.map((d) => d.earnings).reduce(math.max);
    final barWidth = size.width / data.length;
    
    for (int i = 0; i < data.length; i++) {
      final barHeight = (data[i].earnings / maxEarnings) * size.height;
      final rect = Rect.fromLTWH(
        i * barWidth + barWidth * 0.2,
        size.height - barHeight,
        barWidth * 0.6,
        barHeight,
      );
      
      final paint = Paint()
        ..color = data[i].earnings > maxEarnings * 0.5 
            ? ModernTheme.oasisGreen
            : ModernTheme.oasisGreen.withValues(alpha: 0.5);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(2)),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Models
class EarningsData {
  final String period;
  final double totalEarnings;
  final int totalTrips;
  final double avgPerTrip;
  final double totalHours;
  final double avgPerHour;
  final double onlineHours;
  final double commission;
  final double netEarnings;
  final List<DailyEarnings> dailyData;
  final List<HourlyEarnings> hourlyData;
  final EarningsBreakdown breakdown;
  final WeeklyGoals goals;
  
  EarningsData({
    required this.period,
    required this.totalEarnings,
    required this.totalTrips,
    required this.avgPerTrip,
    required this.totalHours,
    required this.avgPerHour,
    required this.onlineHours,
    required this.commission,
    required this.netEarnings,
    required this.dailyData,
    required this.hourlyData,
    required this.breakdown,
    required this.goals,
  });
}

class DailyEarnings {
  final DateTime date;
  final double earnings;
  final int trips;
  final double hours;
  final bool online;
  
  DailyEarnings({
    required this.date,
    required this.earnings,
    required this.trips,
    required this.hours,
    required this.online,
  });
}

class HourlyEarnings {
  final int hour;
  final double earnings;
  final int trips;
  
  HourlyEarnings({
    required this.hour,
    required this.earnings,
    required this.trips,
  });
}

class EarningsBreakdown {
  final double baseFares;
  final double distanceFares;
  final double timeFares;
  final double tips;
  final double bonuses;
  final double surgeEarnings;
  
  EarningsBreakdown({
    required this.baseFares,
    required this.distanceFares,
    required this.timeFares,
    required this.tips,
    required this.bonuses,
    required this.surgeEarnings,
  });
}

class WeeklyGoals {
  final double earningsGoal;
  final int tripsGoal;
  final double hoursGoal;
  final double achievedEarnings;
  final int achievedTrips;
  final double achievedHours;
  
  WeeklyGoals({
    required this.earningsGoal,
    required this.tripsGoal,
    required this.hoursGoal,
    required this.achievedEarnings,
    required this.achievedTrips,
    required this.achievedHours,
  });
}