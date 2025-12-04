import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';
import '../services/firebase_service.dart';

// Modelo para billetera
class Wallet {
  final String id;
  final String userId;
  final double balance;
  final double pendingBalance;
  final double totalEarnings;
  final double totalWithdrawals;
  final String currency;
  final bool isActive;
  final DateTime lastActivityDate;
  final Map<String, dynamic>? bankAccount;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.pendingBalance,
    required this.totalEarnings,
    required this.totalWithdrawals,
    required this.currency,
    required this.isActive,
    required this.lastActivityDate,
    this.bankAccount,
  });

  factory Wallet.fromMap(Map<String, dynamic> map, String id) {
    return Wallet(
      id: id,
      userId: map['userId'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      pendingBalance: (map['pendingBalance'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      totalWithdrawals: (map['totalWithdrawals'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'PEN',
      isActive: map['isActive'] ?? true,
      lastActivityDate: (map['lastActivityDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bankAccount: map['bankAccount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'pendingBalance': pendingBalance,
      'totalEarnings': totalEarnings,
      'totalWithdrawals': totalWithdrawals,
      'currency': currency,
      'isActive': isActive,
      'lastActivityDate': Timestamp.fromDate(lastActivityDate),
      'bankAccount': bankAccount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// Modelo para transacción de billetera
class WalletTransaction {
  final String id;
  final String walletId;
  final String type; // 'earning', 'withdrawal', 'commission', 'bonus', 'penalty'
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String status; // 'pending', 'processing', 'completed', 'failed', 'cancelled'
  final String? tripId;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? processedAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    this.tripId,
    this.description,
    this.metadata,
    required this.createdAt,
    this.processedAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      walletId: map['walletId'] ?? '',
      type: map['type'] ?? 'earning',
      amount: (map['amount'] ?? 0).toDouble(),
      balanceBefore: (map['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      tripId: map['tripId'],
      description: map['description'],
      metadata: map['metadata'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'walletId': walletId,
      'type': type,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'status': status,
      'tripId': tripId,
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }
}

// Modelo para solicitud de retiro
class WithdrawalRequest {
  final String id;
  final String walletId;
  final double amount;
  final String status; // 'pending', 'approved', 'processing', 'completed', 'rejected'
  final String? bankAccountId;
  final Map<String, dynamic>? bankDetails;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;

  WithdrawalRequest({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.status,
    this.bankAccountId,
    this.bankDetails,
    this.rejectionReason,
    required this.requestedAt,
    this.approvedAt,
    this.completedAt,
  });

  factory WithdrawalRequest.fromMap(Map<String, dynamic> map, String id) {
    return WithdrawalRequest(
      id: id,
      walletId: map['walletId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      bankAccountId: map['bankAccountId'],
      bankDetails: map['bankDetails'],
      rejectionReason: map['rejectionReason'],
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Estado
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  List<WithdrawalRequest> _withdrawalRequests = [];
  Map<String, double> _earnings = {
    'today': 0,
    'week': 0,
    'month': 0,
    'total': 0,
  };
  bool _isLoading = false;
  String? _error;
  
  // Campos adicionales para retiros
  List<Map<String, dynamic>> _withdrawalHistory = [];
  final double _totalWithdrawn = 0.0;
  double _pendingWithdrawals = 0.0;
  
  // Streams
  Stream<DocumentSnapshot>? _walletStream;
  Stream<QuerySnapshot>? _transactionsStream;
  Stream<QuerySnapshot>? _withdrawalsStream;

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  List<WithdrawalRequest> get withdrawalRequests => _withdrawalRequests;
  Map<String, double> get earnings => _earnings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get availableBalance => (_wallet?.balance ?? 0.0) - (_wallet?.pendingBalance ?? 0.0);

  WalletProvider() {
    _initializeWallet();
  }

  // Inicializar billetera
  Future<void> _initializeWallet() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Stream de billetera
    _walletStream = _firestore
        .collection('wallets')
        .doc(user.uid)
        .snapshots();

    _walletStream?.listen((snapshot) async {
      if (snapshot.exists) {
        _wallet = Wallet.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
      } else {
        // Crear billetera si no existe
        await _createWallet();
      }
      
      await _calculateEarnings();
      notifyListeners();
    });

    // Stream de transacciones
    _transactionsStream = _firestore
        .collection('walletTransactions')
        .where('walletId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    _transactionsStream?.listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      notifyListeners();
    });

    // Stream de solicitudes de retiro
    _withdrawalsStream = _firestore
        .collection('withdrawalRequests')
        .where('walletId', isEqualTo: user.uid)
        .orderBy('requestedAt', descending: true)
        .limit(20)
        .snapshots();

    _withdrawalsStream?.listen((snapshot) {
      _withdrawalRequests = snapshot.docs
          .map((doc) => WithdrawalRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      notifyListeners();
    });
  }

  // Crear billetera nueva
  Future<void> _createWallet() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final wallet = Wallet(
        id: user.uid,
        userId: user.uid,
        balance: 0,
        pendingBalance: 0,
        totalEarnings: 0,
        totalWithdrawals: 0,
        currency: 'PEN',
        isActive: true,
        lastActivityDate: DateTime.now(),
      );

      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .set({
        ...wallet.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _wallet = wallet;
    } catch (e) {
      AppLogger.error('Error creando billetera', e);
    }
  }

  // Calcular ganancias por período
  Future<void> _calculateEarnings() async {
    if (_wallet == null) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Ganancias de hoy
      final todayEarnings = await _getEarningsByPeriod(todayStart, now);
      
      // Ganancias de la semana
      final weekEarnings = await _getEarningsByPeriod(weekStart, now);
      
      // Ganancias del mes
      final monthEarnings = await _getEarningsByPeriod(monthStart, now);

      _earnings = {
        'today': todayEarnings,
        'week': weekEarnings,
        'month': monthEarnings,
        'total': _wallet!.totalEarnings,
      };

      notifyListeners();
    } catch (e) {
      AppLogger.error('Error calculando ganancias', e);
    }
  }

  // Obtener ganancias por período
  Future<double> _getEarningsByPeriod(DateTime start, DateTime end) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final query = await _firestore
          .collection('walletTransactions')
          .where('walletId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'earning')
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      double total = 0;
      for (var doc in query.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }

      return total;
    } catch (e) {
      AppLogger.error('Error obteniendo ganancias por período', e);
      return 0;
    }
  }

  // Agregar ganancia por viaje
  Future<bool> addTripEarning({
    required String tripId,
    required double amount,
    required double commission,
    String? description,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      if (_wallet == null) {
        await _createWallet();
      }

      final netEarning = amount - commission;
      final balanceBefore = _wallet!.balance;
      final balanceAfter = balanceBefore + netEarning;

      // Crear transacción
      final transaction = WalletTransaction(
        id: '',
        walletId: user.uid,
        type: 'earning',
        amount: netEarning,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        status: 'completed',
        tripId: tripId,
        description: description ?? 'Ganancia por viaje',
        metadata: {
          'grossAmount': amount,
          'commission': commission,
          'commissionRate': (commission / amount * 100).toStringAsFixed(2),
        },
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );

      // Guardar transacción
      await _firestore
          .collection('walletTransactions')
          .add(transaction.toMap());

      // Actualizar billetera
      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(netEarning),
        'totalEarnings': FieldValue.increment(netEarning),
        'lastActivityDate': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al agregar ganancia: $e');
      _setLoading(false);
      return false;
    }
  }

  // Solicitar retiro
  Future<bool> requestWithdrawal({
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      if (_wallet == null) throw Exception('Billetera no encontrada');

      // Validar monto
      if (amount > availableBalance) {
        throw Exception('Monto excede el balance disponible');
      }

      if (amount < 50) {
        throw Exception('El monto mínimo de retiro es S/. 50.00');
      }

      // Crear solicitud de retiro
      final withdrawal = {
        'walletId': user.uid,
        'amount': amount,
        'status': 'pending',
        'bankDetails': bankDetails,
        'requestedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'balanceAtRequest': _wallet!.balance,
          'currency': 'PEN',
        },
      };

      final docRef = await _firestore
          .collection('withdrawalRequests')
          .add(withdrawal);

      // Actualizar balance pendiente
      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'pendingBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Crear transacción pendiente
      final transaction = WalletTransaction(
        id: '',
        walletId: user.uid,
        type: 'withdrawal',
        amount: amount,
        balanceBefore: _wallet!.balance,
        balanceAfter: _wallet!.balance,
        status: 'pending',
        description: 'Solicitud de retiro',
        metadata: {
          'withdrawalRequestId': docRef.id,
          'bankDetails': bankDetails,
        },
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('walletTransactions')
          .add(transaction.toMap());

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al solicitar retiro: $e');
      _setLoading(false);
      return false;
    }
  }

  // Cancelar solicitud de retiro
  Future<bool> cancelWithdrawal(String withdrawalId) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Obtener solicitud
      final withdrawalDoc = await _firestore
          .collection('withdrawalRequests')
          .doc(withdrawalId)
          .get();

      if (!withdrawalDoc.exists) {
        throw Exception('Solicitud no encontrada');
      }

      final withdrawal = WithdrawalRequest.fromMap(withdrawalDoc.data()!, withdrawalId);

      if (withdrawal.status != 'pending') {
        throw Exception('Solo se pueden cancelar solicitudes pendientes');
      }

      // Actualizar solicitud
      await _firestore
          .collection('withdrawalRequests')
          .doc(withdrawalId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Liberar balance pendiente
      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'pendingBalance': FieldValue.increment(-withdrawal.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al cancelar retiro: $e');
      _setLoading(false);
      return false;
    }
  }

  // Agregar cuenta bancaria
  Future<bool> addBankAccount(Map<String, dynamic> bankAccount) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'bankAccount': bankAccount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al agregar cuenta bancaria: $e');
      _setLoading(false);
      return false;
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final now = DateTime.now();
      final lastMonth = now.subtract(const Duration(days: 30));

      // Obtener todas las transacciones del último mes
      final query = await _firestore
          .collection('walletTransactions')
          .where('walletId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .get();

      int totalTrips = 0;
      double totalEarnings = 0;
      double totalCommissions = 0;
      double totalWithdrawals = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        final type = data['type'];
        final amount = (data['amount'] ?? 0).toDouble();

        if (type == 'earning') {
          totalTrips++;
          totalEarnings += amount;
          totalCommissions += (data['metadata']?['commission'] ?? 0).toDouble();
        } else if (type == 'withdrawal' && data['status'] == 'completed') {
          totalWithdrawals += amount;
        }
      }

      return {
        'totalTrips': totalTrips,
        'totalEarnings': totalEarnings,
        'totalCommissions': totalCommissions,
        'totalWithdrawals': totalWithdrawals,
        'averagePerTrip': totalTrips > 0 ? totalEarnings / totalTrips : 0,
      };
    } catch (e) {
      AppLogger.error('Error obteniendo estadísticas', e);
      return {};
    }
  }

  // Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      AppLogger.error(error, null);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Cargar historial de retiros
  Future<void> loadWithdrawalHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final snapshot = await FirebaseFirestore.instance
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      _withdrawalHistory = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
    } catch (e) {
      AppLogger.error('Error cargando historial de retiros', e);
      _error = 'Error al cargar historial';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Procesar retiro
  Future<bool> processWithdrawal({
    required String userId,
    required double amount,
    required String method,
    required Map<String, dynamic> accountDetails,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Verificar saldo disponible
      if (amount > availableBalance) {
        throw Exception('Saldo insuficiente');
      }
      
      // Crear documento de retiro
      await FirebaseFirestore.instance.collection('withdrawals').add({
        'userId': userId,
        'amount': amount,
        'method': method,
        'accountDetails': accountDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Actualizar saldo pendiente de retiro
      _pendingWithdrawals += amount;
      
      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
          .update({
        'pendingBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      AppLogger.error('Error procesando retiro', e);
      _error = 'Error al procesar retiro: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Getters adicionales
  List<Map<String, dynamic>> get withdrawalHistory => _withdrawalHistory;
  double get totalWithdrawn => _totalWithdrawn;
  double get pendingWithdrawals => _pendingWithdrawals;

}