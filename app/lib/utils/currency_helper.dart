// UTILIDADES DE MONEDA - OASIS TAXI PERÚ
// =======================================
//
// 🇵🇪 Manejo preciso de Soles Peruanos (PEN)
//
// ✅ PROBLEMA RESUELTO:
// - Evita errores de precisión de punto flotante (0.1 + 0.2 != 0.3)
// - Compatible con APIs de pago (MercadoPago, Yape, Plin)
// - Almacenamiento eficiente en Firestore (int vs double)
// - Cálculos exactos de comisiones y divisiones
//
// 💡 CONVENCIÓN:
// - Almacenamiento: int (centavos) - Ejemplo: 4550 = S/ 45.50
// - Display: String - Ejemplo: "S/ 45.50"
// - APIs externas: double cuando lo requieran
//
// ⚠️ MIGRACIÓN GRADUAL:
// - Código viejo usa double → Convertir con solesToCents()
// - Código nuevo usa int → Usar directamente
// - Ambos formatos coexisten durante migración

import 'package:intl/intl.dart';

/// Helper class para operaciones de moneda en Soles Peruanos
class CurrencyHelper {
  CurrencyHelper._(); // Constructor privado - solo métodos estáticos

  /// Formato de moneda peruana
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/.',
    decimalDigits: 2,
  );

  // ============================================================================
  // CONVERSIÓN: SOLES ↔ CENTAVOS
  // ============================================================================

  /// Convertir Soles (double) a Centavos (int)
  ///
  /// Ejemplo:
  /// ```dart
  /// solesToCents(45.50) // → 4550
  /// solesToCents(0.01) // → 1
  /// solesToCents(0.005) // → 1 (redondea hacia arriba)
  /// solesToCents(100.0) // → 10000
  /// ```
  static int solesToCents(double soles) {
    // Multiplicar por 100 y redondear para evitar errores de float
    return (soles * 100).round();
  }

  /// Convertir Centavos (int) a Soles (double)
  ///
  /// Ejemplo:
  /// ```dart
  /// centsToSoles(4550) // → 45.50
  /// centsToSoles(1) // → 0.01
  /// centsToSoles(10000) // → 100.0
  /// ```
  static double centsToSoles(int cents) {
    return cents / 100.0;
  }

  // ============================================================================
  // FORMATEO PARA UI
  // ============================================================================

  /// Formatear centavos como moneda para mostrar en UI
  ///
  /// Ejemplo:
  /// ```dart
  /// formatCurrency(4550) // → "S/ 45.50"
  /// formatCurrency(0) // → "S/ 0.00"
  /// formatCurrency(10000) // → "S/ 100.00"
  /// formatCurrency(99) // → "S/ 0.99"
  /// ```
  static String formatCurrency(int cents) {
    return _currencyFormat.format(centsToSoles(cents));
  }

  /// Formatear Soles (double) como moneda - Para compatibilidad con código viejo
  ///
  /// Ejemplo:
  /// ```dart
  /// formatFromSoles(45.50) // → "S/ 45.50"
  /// formatFromSoles(0.01) // → "S/ 0.01"
  /// ```
  static String formatFromSoles(double soles) {
    return _currencyFormat.format(soles);
  }

  /// Formatear sin símbolo de moneda (solo número)
  ///
  /// Ejemplo:
  /// ```dart
  /// formatAmount(4550) // → "45.50"
  /// formatAmount(1) // → "0.01"
  /// ```
  static String formatAmount(int cents) {
    final soles = centsToSoles(cents);
    return soles.toStringAsFixed(2);
  }

  // ============================================================================
  // PARSING (String → Centavos)
  // ============================================================================

  /// Parsear texto de moneda a centavos
  ///
  /// Soporta:
  /// - "45.50" → 4550
  /// - "S/ 45.50" → 4550
  /// - "S/45.50" → 4550
  /// - "45,50" → 4550 (coma decimal europea)
  /// - "45" → 4500
  ///
  /// Retorna null si no se puede parsear
  static int? parseCurrency(String text) {
    try {
      // Limpiar el texto
      String cleaned = text
          .replaceAll('S/', '')
          .replaceAll(' ', '')
          .replaceAll(',', '.') // Normalizar decimal
          .trim();

      // Intentar parsear como double
      final soles = double.tryParse(cleaned);
      if (soles == null) return null;

      return solesToCents(soles);
    } catch (e) {
      print('⚠️ Error parseando moneda "$text": $e');
      return null;
    }
  }

  // ============================================================================
  // CÁLCULOS PRECISOS (evitan errores de float)
  // ============================================================================

  /// Calcular porcentaje de un monto (en centavos)
  ///
  /// Ejemplo:
  /// ```dart
  /// calculatePercentage(10000, 20.0) // → 2000 (20% de S/100 = S/20)
  /// calculatePercentage(4550, 15.5) // → 705 (15.5% de S/45.50)
  /// ```
  static int calculatePercentage(int amountCents, double percentage) {
    // Calcular en double y redondear al final
    final result = (amountCents * percentage / 100).round();
    return result;
  }

  /// Calcular comisión y retornar el neto (monto - comisión)
  ///
  /// Ejemplo:
  /// ```dart
  /// final commission = calculateCommission(10000, 20.0);
  /// print(commission.commission); // 2000 (S/20)
  /// print(commission.net); // 8000 (S/80)
  /// ```
  static CommissionResult calculateCommission(int amountCents, double percentage) {
    final commission = calculatePercentage(amountCents, percentage);
    final net = amountCents - commission;

    return CommissionResult(
      gross: amountCents,
      commission: commission,
      net: net,
      percentage: percentage,
    );
  }

  /// Dividir monto entre N partes (ej: split de cuenta)
  ///
  /// Maneja centavos sobrantes distribuyéndolos equitativamente
  ///
  /// Ejemplo:
  /// ```dart
  /// splitAmount(10000, 3) // → [3334, 3333, 3333] (S/100 ÷ 3)
  /// splitAmount(100, 3) // → [34, 33, 33] (S/1 ÷ 3)
  /// ```
  static List<int> splitAmount(int totalCents, int parts) {
    if (parts <= 0) {
      throw ArgumentError('parts debe ser mayor a 0');
    }

    final baseAmount = totalCents ~/ parts; // División entera
    final remainder = totalCents % parts; // Centavos sobrantes

    final List<int> result = [];

    // Distribuir el monto base
    for (int i = 0; i < parts; i++) {
      result.add(baseAmount);
    }

    // Distribuir los centavos sobrantes a las primeras partes
    for (int i = 0; i < remainder; i++) {
      result[i]++;
    }

    return result;
  }

  /// Sumar lista de montos
  ///
  /// Ejemplo:
  /// ```dart
  /// sumAmounts([1000, 2000, 3000]) // → 6000 (S/60)
  /// ```
  static int sumAmounts(List<int> amounts) {
    return amounts.fold<int>(0, (sum, amount) => sum + amount);
  }

  // ============================================================================
  // VALIDACIONES
  // ============================================================================

  /// Verificar si un monto es válido (positivo o cero)
  static bool isValidAmount(int cents) {
    return cents >= 0;
  }

  /// Verificar si un monto cumple con un mínimo
  ///
  /// Ejemplo:
  /// ```dart
  /// meetsMinimum(4550, 4500) // → true (S/45.50 >= S/45.00)
  /// meetsMinimum(4450, 4500) // → false (S/44.50 < S/45.00)
  /// ```
  static bool meetsMinimum(int cents, int minimumCents) {
    return cents >= minimumCents;
  }

  // ============================================================================
  // CONSTANTES ÚTILES
  // ============================================================================

  /// Montos mínimos comunes en Perú
  static const int minimumFare = 450; // S/ 4.50
  static const int minimumRecharge = 1000; // S/ 10.00
  static const int minimumWithdrawal = 2000; // S/ 20.00

  /// Comisión de la plataforma (20%)
  static const double platformCommissionPercentage = 20.0;

  // ============================================================================
  // MIGRACIONES Y COMPATIBILIDAD
  // ============================================================================

  /// Convertir Map de Firestore que puede tener double o int
  ///
  /// Ejemplo de uso en modelos:
  /// ```dart
  /// final fare = CurrencyHelper.safeParseCents(data['fare']);
  /// ```
  static int safeParseCents(dynamic value) {
    if (value == null) return 0;

    // Si ya es int (nuevo formato)
    if (value is int) return value;

    // Si es double (formato viejo)
    if (value is double) return solesToCents(value);

    // Si es String
    if (value is String) return parseCurrency(value) ?? 0;

    print('⚠️ Tipo desconocido para parsear cents: ${value.runtimeType}');
    return 0;
  }

  /// Convertir a double para APIs que lo requieran (ej: MercadoPago)
  ///
  /// Ejemplo:
  /// ```dart
  /// final apiAmount = CurrencyHelper.toApiAmount(4550); // → 45.50
  /// ```
  static double toApiAmount(int cents) {
    return centsToSoles(cents);
  }
}

/// Resultado de cálculo de comisión
class CommissionResult {
  /// Monto bruto (antes de comisión)
  final int gross;

  /// Monto de la comisión
  final int commission;

  /// Monto neto (después de comisión)
  final int net;

  /// Porcentaje aplicado
  final double percentage;

  const CommissionResult({
    required this.gross,
    required this.commission,
    required this.net,
    required this.percentage,
  });

  /// Formatear resultado para mostrar
  String format() {
    return '''
Bruto: ${CurrencyHelper.formatCurrency(gross)}
Comisión ($percentage%): ${CurrencyHelper.formatCurrency(commission)}
Neto: ${CurrencyHelper.formatCurrency(net)}
''';
  }

  @override
  String toString() => format();
}

// ============================================================================
// EJEMPLOS DE USO
// ============================================================================

/// Ejemplos de uso común:
///
/// ```dart
/// // 1. Convertir tarifa de viaje
/// final fareInCents = CurrencyHelper.solesToCents(45.50); // 4550
///
/// // 2. Mostrar en UI
/// Text(CurrencyHelper.formatCurrency(fareInCents)); // "S/ 45.50"
///
/// // 3. Calcular comisión de plataforma
/// final result = CurrencyHelper.calculateCommission(
///   fareInCents,
///   CurrencyHelper.platformCommissionPercentage
/// );
/// print(result.commission); // 910 (S/ 9.10)
/// print(result.net); // 3640 (S/ 36.40)
///
/// // 4. Validar mínimo
/// final isValid = CurrencyHelper.meetsMinimum(
///   fareInCents,
///   CurrencyHelper.minimumFare
/// ); // true
///
/// // 5. Para MercadoPago API (requiere double)
/// final apiAmount = CurrencyHelper.toApiAmount(fareInCents); // 45.50
///
/// // 6. Parsear desde Firestore (migración gradual)
/// final fare = CurrencyHelper.safeParseCents(data['fare']); // Maneja int o double
/// ```
