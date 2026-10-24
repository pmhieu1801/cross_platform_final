import 'package:flutter/widgets.dart';

/// Spacing scale (4-pt grid).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radius scale.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Motion tokens. Keep animations short so the UI feels responsive.
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;
}

/// Window size classes, following Material 3 guidance.
enum WindowSize { compact, medium, expanded, large }

abstract final class AppBreakpoints {
  /// Phones (portrait).
  static const double medium = 600;

  /// Tablets / small laptop windows.
  static const double expanded = 1024;

  /// Large desktop / wide web windows.
  static const double large = 1440;

  static WindowSize of(double width) {
    if (width < medium) return WindowSize.compact;
    if (width < expanded) return WindowSize.medium;
    if (width < large) return WindowSize.expanded;
    return WindowSize.large;
  }

  /// Convenience lookup from the nearest [MediaQuery].
  static WindowSize fromContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}

/// Minimum interactive target size (accessibility).
abstract final class AppSizes {
  static const double minTapTarget = 48;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double buttonHeight = 52;
  static const double inputHeight = 52;
  static const double sidebarWidth = 260;
  static const double editorPanelMinWidth = 380;
}
