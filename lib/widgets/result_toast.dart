/// Toast (UI spec section 6): the result pop-up on phone (both
/// orientations) and 600–1023. It holds only the result: circled tick +
/// "Correct" (mint) or circled cross + "Not quite" (coral), on one line.
/// Correct and wrong are the same size and style; border solid.
///
/// - Portrait: full width, flush with the left, right and bottom edges, top
///   corners radius 16, no bottom border, padding 22/24/40, icon 22, text
///   16/22.
/// - Landscape: nearly full width, sitting on the bottom edge, radius 12,
///   about 69 high, icon 20, text 15/20.
/// - All: `surface`, 1px border in the feedback colour at 60%, shadow above
///   (0 −8 24, black 45%). Announced to screen readers.
///
/// [ResultToast] is the toast itself; [ResultToastHost] slides it up from
/// the bottom edge over 150 ms, keeps it about 2.5 s and slides it back down
/// (no sliding with reduced motion). Tapping it dismisses it straight away.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';

class ResultToast extends StatelessWidget {
  const ResultToast({super.key, required this.correct, this.onTap});

  final bool correct;

  /// Dismisses the toast.
  final VoidCallback? onTap;

  static const String correctText = 'Correct';
  static const String wrongText = 'Not quite';

  @override
  Widget build(BuildContext context) {
    final landscape = FormFactor.of(context) == FormFactor.phoneLandscape;
    final type = AppTypography.of(context);
    final colour = correct ? AppColors.correct : AppColors.wrong;
    final border = correct ? AppColors.correct60 : AppColors.wrong60;
    final text = correct ? correctText : wrongText;

    final content = Row(
      children: [
        Icon(
          correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: colour,
          size: landscape ? AppSizes.toastIconLandscape : AppSizes.toastIcon,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            text,
            style: type.feedbackHeading.copyWith(color: colour),
          ),
        ),
      ],
    );

    final Widget toast = landscape
        ? Container(
            width: double.infinity,
            padding: AppInsets.toastLandscape,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.controlAll,
              border: Border.all(color: border),
              boxShadow: appToastShadow,
            ),
            child: content,
          )
        : Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.toastTop,
              boxShadow: appToastShadow,
            ),
            child: CustomPaint(
              foregroundPainter: _TopAndSidesBorder(border),
              child: ConstrainedBox(
                // About 100 high with the bottom safe area, so it covers the
                // pinned primary button while it shows.
                constraints: const BoxConstraints(
                  minHeight: AppSizes.toastPortraitMinHeight,
                ),
                child: Padding(
                  padding: AppInsets.toastPortrait,
                  child: content,
                ),
              ),
            ),
          );

    return Semantics(
      liveRegion: true,
      button: onTap != null,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: toast,
      ),
    );
  }
}

/// The portrait toast's border: top and sides only, following the rounded
/// top corners. (Flutter cannot round a box whose sides differ.)
class _TopAndSidesBorder extends CustomPainter {
  _TopAndSidesBorder(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    const w = AppStroke.resting;
    const h = w / 2;
    const r = AppRadius.card;
    final path = Path()
      ..moveTo(h, size.height)
      ..lineTo(h, r)
      ..arcToPoint(const Offset(r, h), radius: const Radius.circular(r - h))
      ..lineTo(size.width - r, h)
      ..arcToPoint(
        Offset(size.width - h, r),
        radius: const Radius.circular(r - h),
      )
      ..lineTo(size.width - h, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = w,
    );
  }

  @override
  bool shouldRepaint(_TopAndSidesBorder old) => old.colour != colour;
}

/// Shows a [ResultToast] over [child], rising from the bottom edge.
///
/// Set [result] to `true` (correct) or `false` (wrong) to show it, with a
/// new [showId] each time a question is checked; set [result] to null to
/// hide it. [onHidden] runs when it has gone (after about 2.5 s, or when
/// tapped), so the screen can move keyboard focus to "Next question" in
/// portrait (section 10).
///
/// Once it has slid away the toast is put offstage (not painted, not
/// tappable, not read out), and the host clips to its own area. Otherwise a hidden toast, parked just below the
/// bottom edge, shows through when the on-screen keyboard moves that edge
/// up (seen in phone landscape with a floating keyboard, 2026-10-23).
class ResultToastHost extends StatefulWidget {
  const ResultToastHost({
    super.key,
    required this.child,
    required this.result,
    this.showId = 0,
    this.onHidden,
  });

  final Widget child;
  final bool? result;
  final int showId;
  final VoidCallback? onHidden;

  @override
  State<ResultToastHost> createState() => _ResultToastHostState();
}

class _ResultToastHostState extends State<ResultToastHost> {
  bool _visible = false;

  /// True once a hidden toast has finished sliding away: it is offstage.
  bool _gone = true;
  bool _correct = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final result = widget.result;
    if (result != null) {
      // First frame: in place, no slide (as before this change).
      _correct = result;
      _visible = true;
      _gone = false;
      _timer = Timer(AppMotion.fast + AppMotion.toastHold, _hide);
    }
  }

  @override
  void didUpdateWidget(ResultToastHost old) {
    super.didUpdateWidget(old);
    if (widget.result == null) {
      if (_visible) _hide(notify: false);
    } else if (widget.result != old.result || widget.showId != old.showId) {
      _show(widget.result!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(bool correct) {
    _timer?.cancel();
    _timer = Timer(AppMotion.fast + AppMotion.toastHold, _hide);
    // Offstage keeps the slide's state, so it rises from below the edge.
    setState(() {
      _correct = correct;
      _visible = true;
      _gone = false;
    });
  }

  void _hide({bool notify = true}) {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    // With reduced motion there is no slide to wait for.
    final instant = AppMotion.duration(context) == Duration.zero;
    setState(() {
      _visible = false;
      if (instant) _gone = true;
    });
    if (notify) widget.onHidden?.call();
  }

  void _slideEnded() {
    if (!_visible && !_gone && mounted) setState(() => _gone = true);
  }

  @override
  Widget build(BuildContext context) {
    final landscape = FormFactor.of(context) == FormFactor.phoneLandscape;
    final side = landscape ? AppSpacing.landscapePadding : 0.0;
    // ClipRect: the slide moves the toast by painting, not layout, so the
    // Stack alone would not clip it.
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: side,
            right: side,
            bottom: 0,
            child: Offstage(
              offstage: _gone,
              child: IgnorePointer(
                ignoring: !_visible,
                child: ExcludeSemantics(
                  excluding: !_visible,
                  // Slides 1.5× its height below the edge, so its shadow
                  // goes too, then goes offstage.
                  child: AnimatedSlide(
                    offset: _visible ? Offset.zero : const Offset(0, 1.5),
                    duration: AppMotion.duration(context),
                    curve: AppMotion.curve,
                    onEnd: _slideEnded,
                    child: ResultToast(correct: _correct, onTap: _hide),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
