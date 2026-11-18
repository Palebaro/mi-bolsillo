import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const _components = FlexSubThemesData(
    defaultRadius: 16,
    cardRadius: 20,
    inputDecoratorRadius: 14,
    inputDecoratorIsFilled: true,
    alignedDropdown: true,
  );

  static final ThemeData light = FlexThemeData.light(
    scheme: FlexScheme.tealM3,
    subThemesData: _components,
    useMaterial3: true,
  );

  static final ThemeData dark = FlexThemeData.dark(
    scheme: FlexScheme.tealM3,
    subThemesData: _components,
    useMaterial3: true,
  );
}
