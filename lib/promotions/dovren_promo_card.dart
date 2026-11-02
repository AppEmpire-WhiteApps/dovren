import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dovren_promo_colors.dart';
import 'dovren_promo_config.dart';
import 'dovren_promo_link.dart';
import 'dovren_promotions.dart';

class DovrenPromoCard extends StatelessWidget {
  const DovrenPromoCard({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scope = DovrenPromotionsScope.maybeOf(context);
    final config = scope?.notifier?.config;
    if (scope == null || config == null || !config.canShowCard) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: margin,
      child: _AnimatedPromoCard(
        promotion: config.card,
        copy: config.card.copyFor(scope.locale),
        locale: scope.locale,
      ),
    );
  }
}

class _AnimatedPromoCard extends StatefulWidget {
  const _AnimatedPromoCard({
    required this.promotion,
    required this.copy,
    required this.locale,
  });

  final DovrenPromotion promotion;
  final DovrenPromoCopy copy;
  final Locale locale;

  @override
  State<_AnimatedPromoCard> createState() => _AnimatedPromoCardState();
}

class _AnimatedPromoCardState extends State<_AnimatedPromoCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _radius = BorderRadius.all(Radius.circular(24));

  late final AnimationController _pulseController;
  late final AnimationController _ambientController;
  late final Animation<double> _pulse;
  late bool _foreground;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _pulse = Tween<double>(
      begin: 1,
      end: 1.035,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulseController);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncAnimations();
  }

  void _syncAnimations() {
    final animate =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (!_ambientController.isAnimating) {
        _ambientController.repeat();
      }
    } else {
      _pulseController.stop();
      _ambientController.stop();
      _pulseController.value = 0;
      _ambientController.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = DovrenPromoColors();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 440.0;
        final compact =
            width < 360 || MediaQuery.textScalerOf(context).scale(16) > 20;

        return SizedBox(
          width: width,
          child: AnimatedBuilder(
            animation: _ambientController,
            child: _buildContent(colors, compact, width < 300 ? 16 : 20),
            builder: (context, child) {
              final wave = math.sin(_ambientController.value * math.pi * 2);
              return Semantics(
                button: true,
                enabled: widget.promotion.destination != null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _radius,
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: _radius,
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: _radius,
                        border: Border.all(color: colors.outline),
                        gradient: LinearGradient(
                          colors: colors.cardGradient,
                          begin: Alignment(-1 + wave * 0.4, -1),
                          end: Alignment(1, 1 - wave * 0.4),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: _radius,
                        onTap: widget.promotion.destination == null
                            ? null
                            : () => openDovrenPromotion(
                                widget.promotion.destination,
                              ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _PromoShimmerPainter(
                                    progress:
                                        _ambientController.value * 2.6 - 0.8,
                                    color: colors.shimmer,
                                  ),
                                ),
                              ),
                            ),
                            child!,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(DovrenPromoColors colors, bool compact, double inset) {
    final shield = ExcludeSemantics(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colors.sage,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(Icons.shield_rounded, color: colors.text, size: 28),
            ),
          ),
        ),
      ),
    );
    final arrow = ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: colors.orange, shape: BoxShape.circle),
        child: Icon(Icons.arrow_forward_rounded, color: colors.text, size: 20),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.copy.heading,
          softWrap: true,
          style: TextStyle(
            color: colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          widget.copy.message,
          softWrap: true,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        if (widget.copy.actionText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            widget.copy.actionText,
            softWrap: true,
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 14, inset, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: colors.orangeSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.locale.languageCode == 'ru' ? 'Реклама' : 'Ad',
                softWrap: true,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (compact) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [shield, arrow],
            ),
            const SizedBox(height: 12),
            details,
          ] else
            Row(
              children: [
                shield,
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 12),
                arrow,
              ],
            ),
        ],
      ),
    );
  }
}

class _PromoShimmerPainter extends CustomPainter {
  const _PromoShimmerPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final transparent = color.withValues(alpha: 0);
    final paint = Paint()
      ..shader =
          LinearGradient(
            colors: [transparent, color, transparent],
            stops: const [0, 0.5, 1],
          ).createShader(
            Rect.fromCenter(
              center: Offset(size.width * progress, size.height / 2),
              width: size.width * 0.6,
              height: size.height,
            ),
          );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_PromoShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
