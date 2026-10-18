/// Which of the three layouts a screen is in. UI spec section 5.
///
/// The type sizes in [AppTypography] depend on it. U3 builds the responsive
/// frame on the same rule.
library;

import 'package:flutter/widgets.dart';

enum FormFactor {
  /// Height < 500 and width ≥ 600. Checked first.
  phoneLandscape,

  /// Narrower than 1024 (phone portrait and 600–1023).
  phone,

  /// 1024 wide or more.
  laptop;

  /// Width from which the laptop layout applies.
  static const double laptopMinWidth = 1024;

  /// Width from which the single column is capped at 640 and centred.
  static const double tabletMinWidth = 600;

  /// Height below which a wide screen is a phone in landscape.
  static const double landscapeMaxHeight = 500;

  static FormFactor fromSize(Size size) {
    if (size.height < landscapeMaxHeight && size.width >= tabletMinWidth) {
      return FormFactor.phoneLandscape;
    }
    if (size.width >= laptopMinWidth) return FormFactor.laptop;
    return FormFactor.phone;
  }

  static FormFactor of(BuildContext context) =>
      fromSize(MediaQuery.sizeOf(context));
}
