import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:data_solaire/app/theme/app_theme.dart';
import 'package:data_solaire/core/constants/app_strings.dart';
import 'package:data_solaire/data/models/sun_state.dart';
import 'package:data_solaire/data/services/solar_tracking_service.dart';

import 'package:data_solaire/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:data_solaire/modules/dashboard/widgets/power_chart_widget.dart';

/// View matrix : œil → cible, repère main droite (clip NDC style OpenGL).
Matrix4 _lookAtRH(Vector3 eye, Vector3 center, Vector3 worldUp) {
  final z = (eye - center).normalized();
  var x = worldUp.cross(z).normalized();
  if (x.length2 < 1e-10) {
    x = Vector3(1, 0, 0);
  }
  final y = z.cross(x);
  final m = Matrix4.identity();
  m[0] = x.x;
  m[4] = x.y;
  m[8] = x.z;
  m[1] = y.x;
  m[5] = y.y;
  m[9] = y.z;
  m[2] = z.x;
  m[6] = z.y;
  m[10] = z.z;
  m[12] = -x.dot(eye);
  m[13] = -y.dot(eye);
  m[14] = -z.dot(eye);
  m[15] = 1;
  return m;
}

Matrix4 _perspectiveRH(double fovy, double aspect, double near, double far) {
  final t = math.tan(fovy * 0.5);
  final m = Matrix4.zero();
  m[0] = 1 / (aspect * t);
  m[5] = 1 / t;
  m[10] = -(far + near) / (far - near);
  m[11] = -1;
  m[14] = -(2 * far * near) / (far - near);
  m[15] = 0;
  return m;
}

/// Vue 3D perspective (MVP), éclairage directionnel lié au soleil / LDR,
/// sol avec grille, ombre portée et orbite caméra par geste.
class Tracker3dWidget extends StatefulWidget {
  const Tracker3dWidget({super.key, this.fillVertical = false});

  final bool fillVertical;

  static const double _groundTopFraction = 0.88;

  @override
  State<Tracker3dWidget> createState() => _Tracker3dWidgetState();
}

class _Tracker3dWidgetState extends State<Tracker3dWidget> {
  static const double _baseYaw = 0.48;
  static const double _basePitch = 0.38;

  double _dragYaw = 0;
  double _dragPitch = 0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Container(
        decoration: AppTheme.bentoDecoration(),
        clipBehavior: Clip.hardEdge,
        child: Padding(
          padding: kDashboardPairCardInset,
          child: LayoutBuilder(
            builder: (context, lc) {
              final plotH =
                  widget.fillVertical &&
                      lc.maxHeight.isFinite &&
                      lc.maxHeight > 0
                  ? lc.maxHeight
                  : kDashboardPairPlotHeight;
              final safeH = plotH.isFinite ? plotH : kDashboardPairPlotHeight;

              return SizedBox(
                width: lc.maxWidth.isFinite ? lc.maxWidth : double.infinity,
                height: safeH,
                child: Obx(() {
                  final o = controller.orientation.value;
                  final sun = controller.sun.value;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final groundY = h * Tracker3dWidget._groundTopFraction;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            GestureDetector(
                              onPanUpdate: (d) {
                                setState(() {
                                  _dragYaw += d.delta.dx * 0.0045;
                                  _dragPitch =
                                      (_dragPitch - d.delta.dy * 0.0045).clamp(
                                        -0.55,
                                        1.15,
                                      );
                                });
                              },
                              child: CustomPaint(
                                size: Size(w, h),
                                painter: _TrackerScenePainter(
                                  canvasSize: Size(w, h),
                                  groundY: groundY,
                                  yawDeg: o.yawDeg,
                                  pitchDeg: o.pitchDeg,
                                  rollDeg: o.rollDeg,
                                  sun: sun,
                                  camOrbitYaw: _baseYaw + _dragYaw,
                                  camOrbitPitch: _basePitch + _dragPitch,
                                  frameColor: const Color(
                                    0xFF3D4F66,
                                  ).withValues(alpha: 0.95),
                                  skyZenith: const Color(0xFF0F1A32),
                                  skyHorizon: const Color(
                                    0xFF6B93C4,
                                  ).withValues(alpha: 0.55),
                                  soilTop: AppTheme.surfaceHigh.withValues(
                                    alpha: 0.5,
                                  ),
                                  soilBottom: AppTheme.scaffold.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              top: 10,
                              child: _HudChip(
                                sun: sun,
                                labelStyle:
                                    textTheme.labelMedium ??
                                    const TextStyle(fontSize: 12, height: 1.25),
                                mutedStyle: TextStyle(
                                  fontSize: math.min(
                                    (textTheme.labelSmall?.fontSize ?? 11),
                                    11,
                                  ),
                                  height: 1.22,
                                  color: AppTheme.onMuted,
                                  fontFamily: textTheme.bodySmall?.fontFamily,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Tooltip(
                                message: AppStrings.tracker3dHint,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceHigh.withValues(
                                      alpha: 0.88,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.threed_rotation_outlined,
                                        size: 16,
                                        color: AppTheme.teal.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Orbiter',
                                        style:
                                            (textTheme.labelSmall ??
                                                    const TextStyle(
                                                      fontSize: 11,
                                                    ))
                                                .copyWith(
                                                  color: AppTheme.onMuted,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              );
            },
          ),
        ),
      ).animate().fadeIn(duration: 480.ms, delay: 60.ms),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.sun,
    required this.labelStyle,
    required this.mutedStyle,
  });

  final SunState sun;
  final TextStyle labelStyle;
  final TextStyle mutedStyle;

  @override
  Widget build(BuildContext context) {
    final irrPct = sun.irradianceNormalized == null
        ? 'N/A'
        : '${(sun.irradianceNormalized! * 100).toStringAsFixed(0)}%';
    final opt = sun.isOptimal == true
        ? 'oui'
        : (sun.isOptimal == false ? 'non' : 'N/A');

    // Calculate tracking parameters
    final tracking = SolarTrackingService.calculate(sun.ldrQuadrants);

    // Determine alignment status with visual indicator
    final alignmentIcon = tracking.isFullyAligned
        ? '✓'
        : (tracking.isVerticalAligned && tracking.isHorizontalAligned ? '◐' : '✗');
    final alignmentColor = tracking.isFullyAligned
        ? Colors.green.withValues(alpha: 0.85)
        : (tracking.isVerticalAligned && tracking.isHorizontalAligned
            ? Colors.amber.withValues(alpha: 0.8)
            : Colors.red.withValues(alpha: 0.7));

    Widget row(String k, String v, {bool strong = false, Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          text: TextSpan(
            style: labelStyle,
            children: [
              TextSpan(
                text: '$k ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: v,
                style: (valueColor != null
                    ? mutedStyle.copyWith(color: valueColor)
                    : mutedStyle).copyWith(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Irradiance $irrPct · Optimal : $opt', style: mutedStyle),
            const SizedBox(height: 8),
            // Solar tracking alignment status and corrections
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: alignmentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: alignmentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alignmentIcon,
                        style: TextStyle(
                          color: alignmentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tracking.isFullyAligned ? 'Aligné' : 'Correction',
                        style: mutedStyle.copyWith(
                          color: alignmentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  row(
                    'Vertical:',
                    '${tracking.differenceVertical.toStringAsFixed(3)} ${tracking.isVerticalAligned ? '✓' : '✗'}',
                    valueColor: tracking.isVerticalAligned
                        ? Colors.green.withValues(alpha: 0.85)
                        : Colors.red.withValues(alpha: 0.7),
                  ),
                  row(
                    'Horizontal:',
                    '${tracking.differenceHorizontal.toStringAsFixed(3)} ${tracking.isHorizontalAligned ? '✓' : '✗'}',
                    valueColor: tracking.isHorizontalAligned
                        ? Colors.green.withValues(alpha: 0.85)
                        : Colors.red.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Face rendu avec tri par profondeur (peintre).
class _ScenePoly {
  _ScenePoly({
    required this.cornersWorld,
    required this.normalWorld,
    required this.albedo,
    this.stroke,
    this.strokeW = 0,
    this.drawCells = false,
  }) : assert(cornersWorld.length == 4);

  final List<Vector3> cornersWorld;
  final Vector3 normalWorld;
  final Color albedo;
  final Color? stroke;
  final double strokeW;
  final bool drawCells;
}

class _TrackerScenePainter extends CustomPainter {
  _TrackerScenePainter({
    required this.canvasSize,
    required this.groundY,
    required this.yawDeg,
    required this.pitchDeg,
    required this.rollDeg,
    required this.sun,
    required this.camOrbitYaw,
    required this.camOrbitPitch,
    required this.frameColor,
    required this.skyZenith,
    required this.skyHorizon,
    required this.soilTop,
    required this.soilBottom,
  });

  final Size canvasSize;
  final double groundY;
  final double? yawDeg;
  final double? pitchDeg;
  final double? rollDeg;
  final SunState sun;
  final double camOrbitYaw;
  final double camOrbitPitch;

  final Color frameColor;
  final Color skyZenith;
  final Color skyHorizon;
  final Color soilTop;
  final Color soilBottom;

  static const double _panelHalfW = 0.82;
  static const double _panelH = 1.06;
  static const double _mastLen = 0.62;
  static const double _panelThickness = 0.042;

  Matrix4 _panelOrientation() {
    final y = yawDeg ?? 0.0;
    final p = pitchDeg ?? 0.0;
    final r = rollDeg ?? 0.0;
    return Matrix4.identity()
      ..rotateY(-y * math.pi / 180)
      ..rotateX(p * math.pi / 180)
      ..rotateZ(-r * math.pi / 180);
  }

  Vector3 _transformP(Matrix4 m, Vector3 v) {
    final e = m.storage;
    final x = e[0] * v.x + e[4] * v.y + e[8] * v.z + e[12];
    final y = e[1] * v.x + e[5] * v.y + e[9] * v.z + e[13];
    final z = e[2] * v.x + e[6] * v.y + e[10] * v.z + e[14];
    return Vector3(x, y, z);
  }

  Vector3 _transformDir(Matrix4 m, Vector3 v) {
    final e = m.storage;
    final x = e[0] * v.x + e[4] * v.y + e[8] * v.z;
    final y = e[1] * v.x + e[5] * v.y + e[9] * v.z;
    final z = e[2] * v.x + e[6] * v.y + e[10] * v.z;
    return Vector3(x, y, z)..normalize();
  }

  Offset? _project(Matrix4 mvp, Vector3 world, Size viewSize) {
    final e = mvp.storage;
    final x = e[0] * world.x + e[4] * world.y + e[8] * world.z + e[12];
    final y = e[1] * world.x + e[5] * world.y + e[9] * world.z + e[13];
    final z = e[2] * world.x + e[6] * world.y + e[10] * world.z + e[14];
    final wv = e[3] * world.x + e[7] * world.y + e[11] * world.z + e[15];
    if (wv.abs() < 1e-8) return null;
    final ndcX = x / wv;
    final ndcY = y / wv;
    final ndcZ = z / wv;
    if (ndcZ < -1.05 || ndcZ > 1.02) return null;
    // Use a generous guard (2.0) so that faces where one corner is slightly
    // off-screen are not silently dropped — _project returns null for any
    // out-of-bounds vertex and renderPoly discards the entire face if any
    // vertex is null, so a tight threshold hides large polygons.
    if (ndcX.abs() > 2.0 || ndcY.abs() > 2.0) return null;
    final sx = (ndcX * 0.5 + 0.5) * viewSize.width;
    final sy = (1.0 - (ndcY * 0.5 + 0.5)) * viewSize.height;
    return Offset(sx, sy);
  }

  Vector3 _lightDirWorld() {
    var hx = 0.22;
    var vz = -0.12;
    final q = sun.ldrQuadrants;
    if (q != null) {
      hx = (((q.right ?? 0.5) - (q.left ?? 0.5)).clamp(-1.0, 1.0) * 0.62);
      vz = (((q.top ?? 0.5) - (q.bottom ?? 0.5)).clamp(-1.0, 1.0) * -0.5);
    }
    final v = Vector3(hx, 0.88, vz + 0.42);
    v.normalize();
    return v;
  }

  Color _shade(Vector3 nWorld, Color albedo, Vector3 lightDir) {
    final nDot = math.max(0.0, nWorld.dot(lightDir));
    const amb = 0.22;
    final diff = 0.78 * nDot;
    // Clamp to 1.0 — values above 1.0 blow out individual channels after the
    // clamp(0,255) in fromARGB, producing flat white patches on lit faces.
    final f = (amb + diff).clamp(0.0, 1.0);
    return Color.fromARGB(
      (albedo.a * 255.0).round().clamp(0, 255),
      (albedo.r * f * 255.0).round().clamp(0, 255),
      (albedo.g * f * 255.0).round().clamp(0, 255),
      (albedo.b * f * 255.0).round().clamp(0, 255),
    );
  }

  void _drawBackdrop(Canvas canvas, double w, double h) {
    final skyR = Rect.fromLTWH(0, 0, w, groundY + 18);
    canvas.drawRect(
      skyR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.52, groundY * 0.22),
          math.max(w, h) * 0.72,
          [
            const Color(0xFF182A52).withValues(alpha: 0.95),
            skyZenith.withValues(alpha: 0.92),
            skyHorizon.withValues(alpha: 0.35),
          ],
          const [0.0, 0.38, 1.0],
        ),
    );
    final soilR = Rect.fromLTRB(0, groundY, w, h);
    canvas.drawRect(
      soilR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            soilTop.withValues(alpha: 0.88),
            soilBottom.withValues(alpha: 0.94),
          ],
        ).createShader(soilR),
    );
    canvas.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  void _drawSunDisk(Canvas canvas, Matrix4 projView, Vector3 eye, Size view) {
    final irr = sun.irradianceNormalized;
    if (irr == null || irr < 0.05) return;

    final ld = _lightDirWorld();
    final far = Vector3.copy(eye)..addScaled(ld, 58.0);
    final c = _project(projView, far, view);
    if (c == null) return;

    final orbR = (9.0 + irr * 10.0).clamp(7.5, 20.0);
    final cx = c.dx.clamp(24.0, view.width - 24.0);
    final cy = c.dy.clamp(24.0, groundY - 20.0);

    final g = irr.clamp(0.2, 1.0);
    canvas.drawCircle(
      Offset(cx, cy),
      orbR * 2.2,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.08 * g)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      orbR * 1.35,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.14 * g)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      orbR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.94 * g),
            AppTheme.primary.withValues(alpha: 0.82 * g),
            Colors.deepOrange.withValues(alpha: 0.12 * g),
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: orbR)),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      orbR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  Path? _shadowOnGround(
    Matrix4 model,
    Vector3 lightDir,
    double yPlane,
    Matrix4 mvp,
    Size view,
  ) {
    const hw = _panelHalfW;
    const hh = _panelH;
    const zf = _panelThickness * 0.5;
    final corners = [
      Vector3(-hw, 0, zf),
      Vector3(hw, 0, zf),
      Vector3(hw, hh, zf),
      Vector3(-hw, hh, zf),
    ].map((p) => _transformP(model, p)).toList();

    if (lightDir.y.abs() < 0.06) return null;

    final o = <Offset>[];
    for (final p in corners) {
      final t = (yPlane - p.y) / lightDir.y;
      if (t.isNaN || t < 0 || t > 80) return null;
      final sx = p.x + lightDir.x * t;
      final sy = p.y + lightDir.y * t;
      final sz = p.z + lightDir.z * t;
      final scr = _project(mvp, Vector3(sx, sy, sz), view);
      if (scr == null) return null;
      o.add(scr);
    }
    if (o.length != 4) return null;
    final path = Path()..moveTo(o[0].dx, o[0].dy);
    for (var i = 1; i < 4; i++) {
      path.lineTo(o[i].dx, o[i].dy);
    }
    path.close();
    return path;
  }

  void _maybeDrawCells(
    Canvas canvas,
    List<Offset> scr,
    Color base,
    Vector3 lightDir,
    Vector3 nWorld,
  ) {
    if (scr.length != 4) return;
    final bl = scr[0];
    final br = scr[1];
    final tr = scr[2];
    final tl = scr[3];
    const rows = 5;
    const cols = 8;
    final shade = _shade(nWorld, base, lightDir);
    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < cols; j++) {
        final u0 = (j + (i % 2) * 0.5) / cols;
        final u1 = (j + 1 + (i % 2) * 0.5) / cols;
        if (u1 > 1.02) continue;
        final v0 = i / rows;
        final v1 = (i + 1) / rows;
        Offset interp(
          Offset a,
          Offset b,
          Offset c,
          Offset d,
          double u,
          double v,
        ) {
          final ab = Offset(a.dx + (b.dx - a.dx) * u, a.dy + (b.dy - a.dy) * u);
          final dc = Offset(d.dx + (c.dx - d.dx) * u, d.dy + (c.dy - d.dy) * u);
          return Offset(
            ab.dx + (dc.dx - ab.dx) * v,
            ab.dy + (dc.dy - ab.dy) * v,
          );
        }

        final p00 = interp(bl, br, tr, tl, u0, v0);
        final p10 = interp(bl, br, tr, tl, u1, v0);
        final p11 = interp(bl, br, tr, tl, u1, v1);
        final p01 = interp(bl, br, tr, tl, u0, v1);
        final jitter = ((i + j * 3) % 5) * 0.012;
        final cellC = Color.lerp(
          shade,
          const Color(0xFF0D2B4A),
          0.12 + jitter,
        )!;
        final path = Path()
          ..moveTo(p00.dx, p00.dy)
          ..lineTo(p10.dx, p10.dy)
          ..lineTo(p11.dx, p11.dy)
          ..lineTo(p01.dx, p01.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = cellC.withValues(alpha: 0.88),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.85
            ..color = Colors.white.withValues(alpha: 0.06),
        );
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(bl.dx, bl.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(tl.dx, tl.dy)
        ..close(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  void _drawGroundGrid(
    Canvas canvas,
    Matrix4 mvp,
    double yG,
    Vector3 foot,
    Size view,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = frameColor.withValues(alpha: 0.14);
    final n = 12;
    final step = 0.42;
    for (var i = -n; i <= n; i++) {
      final off = i * step;
      final a = _project(
        mvp,
        Vector3(foot.x - n * step, yG, foot.z + off),
        view,
      );
      final b = _project(
        mvp,
        Vector3(foot.x + n * step, yG, foot.z + off),
        view,
      );
      if (a != null && b != null) {
        canvas.drawLine(a, b, paint);
      }
      final c = _project(
        mvp,
        Vector3(foot.x + off, yG, foot.z - n * step),
        view,
      );
      final d = _project(
        mvp,
        Vector3(foot.x + off, yG, foot.z + n * step),
        view,
      );
      if (c != null && d != null) {
        canvas.drawLine(c, d, paint);
      }
    }
  }

  void _ldrTicks(
    Canvas canvas,
    double scalePx,
    Offset bl,
    Offset br,
    Offset tr,
    Offset tl,
  ) {
    final q = sun.ldrQuadrants;
    if (q == null) return;
    final c = Offset(
      (bl.dx + br.dx + tr.dx + tl.dx) * 0.25,
      (bl.dy + br.dy + tr.dy + tl.dy) * 0.25,
    );
    void tickAt(Offset pt, double qv) {
      final vv = pt - c;
      final ln = math.min(24.0, 9.0 + (qv.clamp(0.0, 1.0)) * scalePx * 0.12);
      if (ln < 6) return;
      final dist = vv.distance;
      final out = dist < 6
          ? Offset(0.34 * ln, -0.37 * ln)
          : Offset(vv.dx / dist * ln, vv.dy / dist * ln);
      canvas.drawLine(
        pt,
        pt + out,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = AppTheme.teal.withValues(alpha: 0.72),
      );
    }

    // Physical 4-quadrant LDR layout on the panel face:
    //   top-left  → top sensor      bottom-left  → left sensor
    //   top-right → right sensor    bottom-right → bottom sensor
    tickAt(tl, q.top ?? 0);
    tickAt(tr, q.right ?? 0);
    tickAt(bl, q.left ?? 0);
    tickAt(br, q.bottom ?? 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = canvasSize.width;
    final h = canvasSize.height;
    final view = Size(w, h);

    _drawBackdrop(canvas, w, h);

    final model = _panelOrientation();
    final aspect = w / math.max(h, 1.0);
    final dist = 3.55;
    final eye = Vector3(
      math.sin(camOrbitYaw) * math.cos(camOrbitPitch) * dist,
      math.sin(camOrbitPitch) * dist + 0.52,
      math.cos(camOrbitYaw) * math.cos(camOrbitPitch) * dist,
    );
    final target = Vector3(0, 0.48, 0);
    final up = Vector3(0, 1, 0);
    final viewM = _lookAtRH(eye, target, up);
    final proj = _perspectiveRH(math.pi / 180 * 42, aspect, 0.12, 90.0);
    final vp = proj * viewM;

    final lightDir = _lightDirWorld();

    _drawSunDisk(canvas, vp, eye, view);

    final footW = _transformP(model, Vector3(0, -_mastLen, 0));
    final yPlane = footW.y - 0.02;

    final shadowPath = _shadowOnGround(model, -lightDir, yPlane, vp, view);
    if (shadowPath != null) {
      canvas.drawPath(
        shadowPath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    _drawGroundGrid(canvas, vp, yPlane, footW, view);

    final hw = _panelHalfW;
    final hh = _panelH;
    final tz = _panelThickness * 0.5;

    Vector3 ln(Vector3 local) => _transformDir(model, local);

    final polys = <_ScenePoly>[];

    final half = 4.0;
    polys.add(
      _ScenePoly(
        cornersWorld: [
          Vector3(footW.x - half, yPlane, footW.z - half),
          Vector3(footW.x + half, yPlane, footW.z - half),
          Vector3(footW.x + half, yPlane, footW.z + half),
          Vector3(footW.x - half, yPlane, footW.z + half),
        ],
        normalWorld: Vector3(0, 1, 0),
        albedo: const Color(0xFF2A3346).withValues(alpha: 0.96),
        stroke: frameColor.withValues(alpha: 0.18),
        strokeW: 1,
      ),
    );

    void addPanelFace(
      List<Vector3> lc,
      Vector3 localNormal,
      Color alb, {
      bool cells = false,
    }) {
      polys.add(
        _ScenePoly(
          cornersWorld: lc.map((p) => _transformP(model, p)).toList(),
          normalWorld: ln(localNormal),
          albedo: alb,
          drawCells: cells,
        ),
      );
    }

    final pvBlue = const Color(0xFF1B4F72);
    final pvBack = const Color(0xFF243040);
    final rim = const Color(0xFF5A6778);

    addPanelFace(
      [
        Vector3(-hw, 0, tz),
        Vector3(hw, 0, tz),
        Vector3(hw, hh, tz),
        Vector3(-hw, hh, tz),
      ],
      Vector3(0, 0, 1),
      pvBlue,
      cells: true,
    );
    addPanelFace(
      [
        Vector3(-hw, hh, -tz),
        Vector3(hw, hh, -tz),
        Vector3(hw, 0, -tz),
        Vector3(-hw, 0, -tz),
      ],
      Vector3(0, 0, -1),
      pvBack,
    );
    addPanelFace(
      [
        Vector3(-hw, 0, -tz),
        Vector3(-hw, 0, tz),
        Vector3(-hw, hh, tz),
        Vector3(-hw, hh, -tz),
      ],
      Vector3(-1, 0, 0),
      rim,
    );
    addPanelFace(
      [
        Vector3(hw, hh, -tz),
        Vector3(hw, 0, -tz),
        Vector3(hw, 0, tz),
        Vector3(hw, hh, tz),
      ],
      Vector3(1, 0, 0),
      rim,
    );
    addPanelFace(
      [
        Vector3(-hw, hh, -tz),
        Vector3(-hw, hh, tz),
        Vector3(hw, hh, tz),
        Vector3(hw, hh, -tz),
      ],
      Vector3(0, 1, 0),
      frameColor.withValues(alpha: 0.82),
    );
    addPanelFace(
      [
        Vector3(hw, 0, tz),
        Vector3(-hw, 0, tz),
        Vector3(-hw, 0, -tz),
        Vector3(hw, 0, -tz),
      ],
      Vector3(0, -1, 0),
      frameColor.withValues(alpha: 0.9),
    );

    final groundPoly = polys.first;
    final panelPolys = polys.sublist(1);

    double avgDist(_ScenePoly p) {
      var s = 0.0;
      for (final c in p.cornersWorld) {
        s += (c - eye).length;
      }
      return s / p.cornersWorld.length;
    }

    panelPolys.sort((a, b) => avgDist(b).compareTo(avgDist(a)));

    void renderPoly(_ScenePoly poly) {
      final centroid = Vector3.zero();
      for (final p in poly.cornersWorld) {
        centroid.add(p);
      }
      centroid.scale(0.25);
      final toCam = Vector3(
        eye.x - centroid.x,
        eye.y - centroid.y,
        eye.z - centroid.z,
      )..normalize();
      if (poly.normalWorld.dot(toCam) <= 0) return;

      final scr = <Offset?>[
        for (final p in poly.cornersWorld) _project(vp, p, view),
      ];
      if (scr.any((o) => o == null)) return;
      final o = scr.cast<Offset>();
      final path = Path()
        ..moveTo(o[0].dx, o[0].dy)
        ..lineTo(o[1].dx, o[1].dy)
        ..lineTo(o[2].dx, o[2].dy)
        ..lineTo(o[3].dx, o[3].dy)
        ..close();

      final lit = _shade(poly.normalWorld, poly.albedo, lightDir);
      canvas.drawPath(path, Paint()..color = lit);

      if (poly.drawCells) {
        _maybeDrawCells(canvas, o, pvBlue, lightDir, poly.normalWorld);
        final halfVec = (lightDir + toCam).normalized();
        final spec = math.pow(math.max(0.0, poly.normalWorld.dot(halfVec)), 48);
        if (spec > 0.04) {
          canvas.save();
          canvas.clipPath(path);
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(
                alpha: (spec * 0.45).clamp(0.0, 0.38).toDouble(),
              ),
          );
          canvas.restore();
        }
      }

      if (poly.stroke != null && poly.strokeW > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = poly.strokeW
            ..color = poly.stroke!,
        );
      }
    }

    renderPoly(groundPoly);

    final hinge = _transformP(model, Vector3(0, 0, 0));
    final mastBase = _transformP(model, Vector3(0, -_mastLen, 0));
    final hs = _project(vp, hinge, view);
    final ms = _project(vp, mastBase, view);
    if (hs != null && ms != null) {
      final mw = math.max(2.4, w * 0.0068);
      canvas.drawLine(
        ms,
        hs,
        Paint()
          ..strokeWidth = mw
          ..strokeCap = StrokeCap.round
          ..color = frameColor.withValues(alpha: 0.88),
      );
      canvas.drawLine(
        ms,
        hs,
        Paint()
          ..strokeWidth = mw * 0.42
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.18),
      );

      final fw = math.max(mw * 4.2, 22.0);
      final fh = math.max(mw * 1.35, 6.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: ms, width: fw, height: fh),
          Radius.circular(fh * 0.22),
        ),
        Paint()..color = frameColor.withValues(alpha: 0.82),
      );
    }

    for (final poly in panelPolys) {
      renderPoly(poly);
    }

    if (hs != null && ms != null) {
      final mw = math.max(2.4, w * 0.0068);
      final blS = _project(vp, _transformP(model, Vector3(-hw, 0, tz)), view);
      final brS = _project(vp, _transformP(model, Vector3(hw, 0, tz)), view);
      final trS = _project(vp, _transformP(model, Vector3(hw, hh, tz)), view);
      final tlS = _project(vp, _transformP(model, Vector3(-hw, hh, tz)), view);
      if (blS != null && brS != null && trS != null && tlS != null) {
        final mid = Offset((blS.dx + brS.dx) * 0.5, (blS.dy + brS.dy) * 0.5);
        final rr = math.max(mw * 1.15, 5.0);
        canvas.drawCircle(
          mid,
          rr,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
        canvas.drawCircle(
          mid,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = frameColor.withValues(alpha: 0.45),
        );
        final scalePx =
            ((blS - brS).distance + (tlS - trS).distance) * 0.25 +
            ((blS - tlS).distance + (brS - trS).distance) * 0.14;
        _ldrTicks(canvas, scalePx, blS, brS, trS, tlS);
      }
    }
  }

  int _quantize1000(double? v) {
    if (v == null || v.isNaN) return -1;
    return (v.clamp(-1.0, 2.0) * 1000).round();
  }

  @override
  bool shouldRepaint(covariant _TrackerScenePainter oldDelegate) {
    bool qEq(LdrQuadrants? a, LdrQuadrants? b) {
      if (identical(a, b)) return true;
      if (a == null || b == null) return a == null && b == null;
      return a.top == b.top &&
          a.bottom == b.bottom &&
          a.left == b.left &&
          a.right == b.right;
    }

    return oldDelegate.canvasSize != canvasSize ||
        oldDelegate.groundY != groundY ||
        oldDelegate.skyZenith != skyZenith ||
        oldDelegate.skyHorizon != skyHorizon ||
        oldDelegate.soilTop != soilTop ||
        oldDelegate.soilBottom != soilBottom ||
        oldDelegate.frameColor != frameColor ||
        ((oldDelegate.yawDeg ?? 0.0) - (yawDeg ?? 0.0)).abs() > 0.035 ||
        ((oldDelegate.pitchDeg ?? 0.0) - (pitchDeg ?? 0.0)).abs() > 0.035 ||
        ((oldDelegate.rollDeg ?? 0.0) - (rollDeg ?? 0.0)).abs() > 0.035 ||
        (oldDelegate.camOrbitYaw - camOrbitYaw).abs() > 1e-4 ||
        (oldDelegate.camOrbitPitch - camOrbitPitch).abs() > 1e-4 ||
        oldDelegate.sun.isOptimal != sun.isOptimal ||
        _quantize1000(oldDelegate.sun.irradianceNormalized) !=
            _quantize1000(sun.irradianceNormalized) ||
        !qEq(oldDelegate.sun.ldrQuadrants, sun.ldrQuadrants);
  }
}
