/// AnswerField (UI spec section 6): the text field for Repair, typed Fill
/// the gap and Spot the error.
///
/// Radius 12; 1px accent 40% resting, 2px accent focused; min height 56
/// (48 in phone landscape); Spanish text 18 (16 in phone landscape); wraps
/// onto more lines and grows, never truncated or scrolled sideways.
///
/// Repair and Spot the error prefill it with the sentence as shown, without
/// the marks (`Question.promptText`), so the learner edits rather than
/// retypes: the screen creates the controller with that text. A muted
/// caption sits under it ([repairCaption], [spotErrorCaption]; none for
/// Fill the gap).
///
/// After checking pass [AnswerFieldState.correct] or
/// [AnswerFieldState.wrong]: the field is read-only, with a 2px mint or
/// coral border and a tick or cross at the right.
///
/// Enter checks (section 10): the field does not take new lines; Enter
/// calls [onSubmitted].
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

enum AnswerFieldState {
  /// Before checking: editable.
  editing,

  /// After checking, right: read-only, 2px mint, tick.
  correct,

  /// After checking, wrong: read-only, 2px coral, cross.
  wrong,
}

class AnswerField extends StatefulWidget {
  const AnswerField({
    super.key,
    required this.controller,
    this.state = AnswerFieldState.editing,
    this.caption,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel = 'Your answer',
  });

  /// Holds the text. For Repair and Spot the error, create it with the
  /// sentence without the marks: `TextEditingController(text:
  /// question.promptText)`.
  final TextEditingController controller;

  final AnswerFieldState state;

  /// Muted line under the field: [repairCaption], [spotErrorCaption], or
  /// null for none.
  final String? caption;

  final ValueChanged<String>? onChanged;

  /// Called when Enter is pressed while editing (the screen checks).
  final ValueChanged<String>? onSubmitted;

  final FocusNode? focusNode;
  final bool autofocus;

  /// What screen readers call the field. After checking ", correct" or
  /// ", wrong" is added.
  final String semanticLabel;

  /// Caption copy (section 6).
  static const String repairCaption = 'Change the marked words';
  static const String spotErrorCaption = 'Fix the sentence';

  /// Whether the learner has changed [text] from [original] (the prefilled
  /// sentence, or empty for typed Fill the gap), ignoring spaces at the
  /// ends. Check is enabled once this is true (section 6).
  static bool isChanged(String text, String original) =>
      text.trim() != original.trim();

  @override
  State<AnswerField> createState() => _AnswerFieldWidgetState();
}

class _AnswerFieldWidgetState extends State<AnswerField> {
  FocusNode? _ownFocusNode;
  bool _focused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    _focused = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(AnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      if (widget.focusNode != null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_onFocus);
      _focused = _focusNode.hasFocus;
    }
    // Leaving the field once it is checked, so the keyboard closes and
    // focus can move on to "Next question".
    if (widget.state != AnswerFieldState.editing && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted && _focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  bool get _checked => widget.state != AnswerFieldState.editing;

  ({Color border, double width}) get _look => switch (widget.state) {
    AnswerFieldState.correct => (
      border: AppColors.correct,
      width: AppStroke.strong,
    ),
    AnswerFieldState.wrong => (border: AppColors.wrong, width: AppStroke.strong),
    AnswerFieldState.editing =>
      _focused
          ? (border: AppColors.accent, width: AppStroke.strong)
          : (border: AppColors.accent40, width: AppStroke.resting),
  };

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final formFactor = FormFactor.of(context);
    final minHeight = formFactor == FormFactor.phoneLandscape
        ? AppSizes.fieldLandscape
        : AppSizes.fieldPhone;
    final textStyle = type.answerField;
    final lineHeight = (textStyle.fontSize ?? 18) * (textStyle.height ?? 1.4);
    final look = _look;

    // Keep the text still when the border thickens from 1 to 2px: the
    // padding gives back what the border takes. One line sits centred in
    // the minimum height.
    final vertical = ((minHeight - lineHeight) / 2 - look.width).clamp(
      0.0,
      double.infinity,
    );
    final horizontal = AppSpacing.s16 - look.width;

    final icon = switch (widget.state) {
      AnswerFieldState.correct => Icons.check_rounded,
      AnswerFieldState.wrong => Icons.close_rounded,
      AnswerFieldState.editing => null,
    };

    final semanticLabel = switch (widget.state) {
      AnswerFieldState.correct => '${widget.semanticLabel}, correct',
      AnswerFieldState.wrong => '${widget.semanticLabel}, wrong',
      AnswerFieldState.editing => widget.semanticLabel,
    };

    final field = FocusRing(
      radius: AppRadius.control,
      child: AnimatedContainer(
        duration: AppMotion.duration(context),
        curve: AppMotion.curve,
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          borderRadius: AppRadius.controlAll,
          border: Border.all(color: look.border, width: look.width),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                label: semanticLabel,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus && !_checked,
                  readOnly: _checked,
                  // Read-only after checking, but still selectable and
                  // readable by screen readers.
                  enableInteractiveSelection: true,
                  style: textStyle,
                  cursorColor: AppColors.accent,
                  // Wraps and grows; Enter checks instead of adding a line.
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  onChanged: _checked ? null : widget.onChanged,
                  onSubmitted: _checked ? null : widget.onSubmitted,
                  // The border is drawn by the container above (so it can
                  // turn mint or coral), not by the theme's input borders.
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: AppSpacing.s8),
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: AppSizes.iconSmall,
                  color: look.border,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final caption = widget.caption;
    if (caption == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        const SizedBox(height: AppSpacing.s8),
        Text(caption, style: type.caption),
      ],
    );
  }
}
