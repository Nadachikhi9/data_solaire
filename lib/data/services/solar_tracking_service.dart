import 'package:flutter/foundation.dart';
import '../models/sun_state.dart';

/// Solar tracking calculation service based on quad-LDR sensor data
/// Reference: 4.3 Réalisation et test du système de tracking solaire
/// 
/// The system uses 4 LDR sensors positioned as:
///   - HG (Haut-Gauche): Top-Left
///   - HD (Haut-Droite): Top-Right
///   - BG (Bas-Gauche): Bottom-Left
///   - BD (Bas-Droite): Bottom-Right
///
/// Formulas:
///   - MoyenneHaut = (HG + HD) / 2
///   - MoyenneBas = (BG + BD) / 2
///   - MoyenneGauche = (HG + BG) / 2
///   - MoyenneDroite = (HD + BD) / 2
///   - DifferenceVertical = MoyenneHaut - MoyenneBas
///   - DifferenceHorizontale = MoyenneGauche - MoyenneDroite
///
/// When the difference exceeds tolerance (50), servomotors adjust the panel orientation.
@immutable
class SolarTrackingCalculations {
  const SolarTrackingCalculations({
    required this.averageTop,
    required this.averageBottom,
    required this.averageLeft,
    required this.averageRight,
    required this.differenceVertical,
    required this.differenceHorizontal,
    required this.isVerticalAligned,
    required this.isHorizontalAligned,
    required this.isFullyAligned,
  });

  /// Average of Top sensors: (HG + HD) / 2 — receives value from Firebase ldr_quadrants.top
  final double averageTop;

  /// Average of Bottom sensors: (BG + BD) / 2 — receives value from Firebase ldr_quadrants.bottom
  final double averageBottom;

  /// Average of Left sensors: (HG + BG) / 2 — receives value from Firebase ldr_quadrants.left
  final double averageLeft;

  /// Average of Right sensors: (HD + BD) / 2 — receives value from Firebase ldr_quadrants.right
  final double averageRight;

  /// Vertical difference: MoyenneHaut - MoyenneBas
  final double differenceVertical;

  /// Horizontal difference: MoyenneGauche - MoyenneDroite
  final double differenceHorizontal;

  /// Whether vertical alignment is within tolerance
  final bool isVerticalAligned;

  /// Whether horizontal alignment is within tolerance
  final bool isHorizontalAligned;

  /// Whether both axes are aligned (fully optimized)
  final bool isFullyAligned;

  @override
  String toString() => 'SolarTrackingCalculations('
      'avgTop: ${averageTop.toStringAsFixed(2)}, '
      'avgBot: ${averageBottom.toStringAsFixed(2)}, '
      'avgLeft: ${averageLeft.toStringAsFixed(2)}, '
      'avgRight: ${averageRight.toStringAsFixed(2)}, '
      'diffV: ${differenceVertical.toStringAsFixed(2)}, '
      'diffH: ${differenceHorizontal.toStringAsFixed(2)}, '
      'alignedV: $isVerticalAligned, '
      'alignedH: $isHorizontalAligned)';
}

/// Service for calculating solar tracking parameters
class SolarTrackingService {
  /// Tolerance value for servo adjustment (default: 50)
  /// When the difference between two opposite sensors exceeds this tolerance,
  /// the servomotor adjusts the panel orientation
  static const double tolerance = 50.0;

  /// Calculate tracking parameters from LDR quadrant values (0.0 to 1.0)
  /// 
  /// [quadrants] contains normalized values for top, bottom, left, right sensors
  /// These values are already averages from the Firebase RTDB:
  ///   - top = (HG + HD) / 2 / 4095
  ///   - bottom = (BG + BD) / 2 / 4095
  ///   - left = (HG + BG) / 2 / 4095
  ///   - right = (HD + BD) / 2 / 4095
  /// 
  /// Returns calculated tracking parameters including differences and alignment status
  static SolarTrackingCalculations calculate(LdrQuadrants? quadrants) {
    if (quadrants == null) {
      return const SolarTrackingCalculations(
        averageTop: 0,
        averageBottom: 0,
        averageLeft: 0,
        averageRight: 0,
        differenceVertical: 0,
        differenceHorizontal: 0,
        isVerticalAligned: false,
        isHorizontalAligned: false,
        isFullyAligned: false,
      );
    }

    // These values are already normalized averages from Firebase
    final top = quadrants.top ?? 0.0;
    final bottom = quadrants.bottom ?? 0.0;
    final left = quadrants.left ?? 0.0;
    final right = quadrants.right ?? 0.0;

    // Calculate differences (in normalized scale 0-1)
    final diffVertical = top - bottom; // MoyenneHaut - MoyenneBas
    final diffHorizontal = left - right; // MoyenneGauche - MoyenneDroite

    // Normalize tolerance to 0-1 scale (50 out of 4095 ≈ 0.0122)
    final normalizedTolerance = tolerance / 4095.0;

    return SolarTrackingCalculations(
      averageTop: top,
      averageBottom: bottom,
      averageLeft: left,
      averageRight: right,
      differenceVertical: diffVertical,
      differenceHorizontal: diffHorizontal,
      isVerticalAligned: diffVertical.abs() <= normalizedTolerance,
      isHorizontalAligned: diffHorizontal.abs() <= normalizedTolerance,
      isFullyAligned:
          diffVertical.abs() <= normalizedTolerance &&
          diffHorizontal.abs() <= normalizedTolerance,
    );
  }

  /// Calculate raw tracking from raw ADC values (0-4095)
  /// Useful for debugging and direct hardware communication
  static SolarTrackingCalculations calculateRaw({
    required int hg, // Top-Left
    required int hd, // Top-Right
    required int bg, // Bottom-Left
    required int bd, // Bottom-Right
  }) {
    final avgTop = (hg + hd) / 2.0;
    final avgBottom = (bg + bd) / 2.0;
    final avgLeft = (hg + bg) / 2.0;
    final avgRight = (hd + bd) / 2.0;

    final diffVertical = avgTop - avgBottom;
    final diffHorizontal = avgLeft - avgRight;

    return SolarTrackingCalculations(
      averageTop: avgTop,
      averageBottom: avgBottom,
      averageLeft: avgLeft,
      averageRight: avgRight,
      differenceVertical: diffVertical,
      differenceHorizontal: diffHorizontal,
      isVerticalAligned: diffVertical.abs() <= tolerance,
      isHorizontalAligned: diffHorizontal.abs() <= tolerance,
      isFullyAligned:
          diffVertical.abs() <= tolerance && diffHorizontal.abs() <= tolerance,
    );
  }

  /// Get servo adjustment direction for vertical (pitch) axis
  /// Returns positive for upward adjustment, negative for downward
  static double getVerticalServoAdjustment(double differenceVertical) {
    if (differenceVertical.abs() <= tolerance / 4095.0) {
      return 0.0; // No adjustment needed
    }
    return differenceVertical > 0 ? 1.0 : -1.0;
  }

  /// Get servo adjustment direction for horizontal (yaw) axis
  /// Returns positive for rightward adjustment, negative for leftward
  static double getHorizontalServoAdjustment(double differenceHorizontal) {
    if (differenceHorizontal.abs() <= tolerance / 4095.0) {
      return 0.0; // No adjustment needed
    }
    return differenceHorizontal > 0 ? 1.0 : -1.0;
  }
}
