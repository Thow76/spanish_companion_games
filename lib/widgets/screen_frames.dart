/// The responsive frame (UI spec section 5): [HomeFrame] and [GameFrame].
///
/// One layout per screen, chosen from the window size by [FormFactor] (the
/// phone-landscape rule, height < 500 and width ≥ 600, is checked first;
/// then 1024). Screens give the frame their parts; the frame places them,
/// sets the side padding and maximum widths, and scrolls when the content
/// is taller than the window. Each frame is a whole page (it builds its own
/// `Scaffold`), so a screen returns it from `build`.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'result_toast.dart';

/// Centres [child] and holds it to [maxWidth] plus [side] padding each side.
class _Centred extends StatelessWidget {
  const _Centred({
    required this.maxWidth,
    required this.side,
    required this.child,
  });

  final double maxWidth;
  final double side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + side * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: child,
        ),
      ),
    );
  }
}

/// A full-width hairline under a laptop top bar.
const BoxDecoration _barRule = BoxDecoration(
  border: Border(bottom: BorderSide(color: AppColors.hairline)),
);

/// Lays [children] out in a column with [gap] between them.
List<Widget> _spaced(List<Widget> children, double gap) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) SizedBox(height: gap),
    children[i],
  ],
];

/// The home screen frame.
///
/// - Phone portrait: one column, 16 side margins, the top bar scrolling
///   with the content.
/// - Phone landscape and 600–1023: the same single column, content at most
///   640 wide, centred.
/// - Laptop: the top bar stays at the top with a full-width hairline under
///   it; under it the content, at most 1040 wide and centred, starting with
///   the screen title ("Choose a game"). The page scrolls if it needs to.
///
/// [footer] (usually [HomeFrame.footerText]) sits at the bottom of the
/// window when the content is short, and after the content when it is
/// long.
class HomeFrame extends StatelessWidget {
  const HomeFrame({
    super.key,
    required this.topBar,
    required this.children,
    this.footer,
  });

  /// Usually a [HomeTopBar].
  final Widget topBar;

  /// The phase groups (headings and cards).
  final List<Widget> children;

  final Widget? footer;

  static const String laptopTitle = 'Choose a game';
  static const String footerText =
      'New questions arrive from your Spanish Daily Companion.';

  /// The footer line in caption style, centred.
  static Widget footerLine(BuildContext context) => Text(
    footerText,
    style: AppTypography.of(context).caption,
    textAlign: TextAlign.center,
  );

  @override
  Widget build(BuildContext context) {
    final f = FormFactor.of(context);
    return Scaffold(
      body: SafeArea(
        child: f == FormFactor.laptop ? _laptop(context) : _phone(context, f),
      ),
    );
  }

  Widget _phone(BuildContext context, FormFactor f) {
    final side = AppLayout.sidePadding(f);
    final top = f == FormFactor.phoneLandscape
        ? AppSpacing.s16
        : AppLayout.phoneTopPadding;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Centred(
            maxWidth: AppLayout.columnMaxWidth,
            side: side,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topBar,
                  // PhaseHeading adds 16 above the first group: 24 in all.
                  const SizedBox(height: AppSpacing.s8),
                  ...children,
                ],
              ),
            ),
          ),
        ),
        _footerSliver(side, AppLayout.columnMaxWidth),
      ],
    );
  }

  Widget _laptop(BuildContext context) {
    const side = AppSpacing.laptopPadding;
    final type = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: _barRule,
          child: _Centred(
            maxWidth: AppLayout.laptopMaxWidth,
            side: side,
            child: topBar,
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Centred(
                  maxWidth: AppLayout.laptopMaxWidth,
                  side: side,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: AppLayout.laptopHomePadding.top,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(laptopTitle, style: type.screenTitle),
                        ),
                        ...children,
                      ],
                    ),
                  ),
                ),
              ),
              _footerSliver(side, AppLayout.laptopMaxWidth),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footerSliver(double side, double maxWidth) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _Centred(
          maxWidth: maxWidth,
          side: side,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s24,
              bottom: AppSpacing.s40,
            ),
            child: SizedBox(width: double.infinity, child: footer),
          ),
        ),
      ),
    );
  }
}

/// The game screen frame, the same for all six games.
///
/// - Phone portrait and 600–1023: one column (at most 640 wide from 600,
///   centred): [topBar], then [children] (chip row, instruction, prompt
///   card, answer area) and, after checking, [explanation]. [primaryButton]
///   is pinned at the bottom (16 side, 40 bottom padding); the content
///   scrolls above it, so nothing hides behind it. The result toast rises
///   from the bottom edge over the button while [toastResult] is set.
/// - Phone landscape: one column, 44 side padding, 10 between rows; the
///   slim [topBar] carries the primary action (pass `onAction` to
///   [GameTopBar]), so [primaryButton] is not shown. [explanation] comes 24
///   under the answer area. The toast rises from the bottom edge.
/// - Laptop: [topBar] across the top with a full-width hairline; under it,
///   at most 1040 wide and centred, the main column ([children], then
///   [primaryButton] right-aligned) and the side panel ([sidePanel],
///   280–320 wide: the session panel and, after checking, the feedback
///   panel). [explanation] and the toast are not used on laptop.
class GameFrame extends StatelessWidget {
  const GameFrame({
    super.key,
    required this.topBar,
    required this.children,
    this.explanation,
    this.primaryButton,
    this.sidePanel,
    this.toastResult,
    this.toastId = 0,
    this.onToastHidden,
  });

  /// Usually a [GameTopBar].
  final Widget topBar;

  /// The rows of the main column, top to bottom. The frame puts the row
  /// gap between them.
  final List<Widget> children;

  /// Phones only: the explanation card, after checking.
  final Widget? explanation;

  /// Phone portrait, 600–1023 and laptop: the [PrimaryButton].
  final Widget? primaryButton;

  /// Laptop only: the side panel's contents.
  final Widget? sidePanel;

  /// Phones only: `true` or `false` shows the result toast (correct or
  /// wrong), null hides it. Give a new [toastId] each time a question is
  /// checked. See [ResultToastHost].
  final bool? toastResult;
  final int toastId;

  /// Runs when the toast has gone, so the screen can move keyboard focus to
  /// "Next question" in portrait (spec section 10).
  final VoidCallback? onToastHidden;

  @override
  Widget build(BuildContext context) {
    final f = FormFactor.of(context);
    final Widget body = switch (f) {
      FormFactor.phone => _portrait(f),
      FormFactor.phoneLandscape => _landscape(f),
      FormFactor.laptop => _laptop(f),
    };
    return Scaffold(
      body: f == FormFactor.laptop
          ? SafeArea(child: body)
          : ResultToastHost(
              result: toastResult,
              showId: toastId,
              onHidden: onToastHidden,
              // The toast sits on the bottom edge, so only the content
              // keeps clear of the system areas.
              child: SafeArea(child: body),
            ),
    );
  }

  List<Widget> _mainRows(FormFactor f) => [
    ..._spaced(children, AppLayout.gameRowGap(f)),
    if (explanation != null) ...[
      SizedBox(height: AppLayout.resultGap(f)),
      explanation!,
    ],
  ];

  Widget _portrait(FormFactor f) {
    final side = AppLayout.sidePadding(f);
    return _Centred(
      maxWidth: AppLayout.columnMaxWidth + side * 2,
      // The bar and the scrolling content set their own side padding, so
      // the scroll bar and the back chevron's tap area can reach the edge.
      side: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              side - AppLayout.backChevronInset,
              AppLayout.phoneTopPadding,
              side,
              AppSpacing.s8,
            ),
            child: topBar,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                side,
                AppSpacing.s8,
                side,
                AppSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _mainRows(f),
              ),
            ),
          ),
          if (primaryButton != null)
            Padding(
              padding: AppLayout.bottomButtonPadding.copyWith(
                left: side,
                right: side,
              ),
              child: primaryButton,
            ),
        ],
      ),
    );
  }

  Widget _landscape(FormFactor f) {
    final side = AppLayout.sidePadding(f);
    final gap = AppLayout.gameRowGap(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            side - AppLayout.backChevronInset,
            AppLayout.landscapeTopPadding,
            side,
            0,
          ),
          child: topBar,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(side, gap, side, AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _mainRows(f),
            ),
          ),
        ),
      ],
    );
  }

  Widget _laptop(FormFactor f) {
    const side = AppSpacing.laptopPadding;
    final padding = AppLayout.laptopGamePadding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: _barRule,
          child: _Centred(
            maxWidth: AppLayout.laptopMaxWidth,
            side: side,
            child: topBar,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: _Centred(
              maxWidth: AppLayout.laptopMaxWidth,
              side: side,
              child: Padding(
                padding: EdgeInsets.only(
                  top: padding.top,
                  bottom: padding.bottom,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panelWidth = AppLayout.sidePanelWidth(
                      constraints.maxWidth,
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._spaced(children, AppLayout.gameRowGap(f)),
                              if (primaryButton != null) ...[
                                const SizedBox(height: AppSpacing.s24),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: primaryButton,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (sidePanel != null) ...[
                          const SizedBox(width: AppLayout.sidePanelGap),
                          SizedBox(width: panelWidth, child: sidePanel),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
