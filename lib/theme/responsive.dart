import 'package:flutter/material.dart';

/// Адаптивная верстка по принципам Material Design 3 Window Size Classes.
///
/// Документация Material 3:
/// https://m3.material.io/foundations/layout/applying-layout/window-size-classes
///
/// Идея: вместо линейного масштабирования всех размеров под референсный
/// экран (что превращает UI на iPad в «гипертрофированный телефон»),
/// мы классифицируем доступную ширину окна на три класса и принимаем
/// раскладочные решения осознанно для каждого.
///
/// Это нативный Flutter way — не требует сторонних библиотек и
/// соответствует официальным гайдлайнам Material 3.
enum WindowSizeClass {
  /// 0–599 dp по ширине — телефоны в портретной ориентации.
  /// Основная целевая аудитория приложения.
  compact,

  /// 600–839 dp — телефоны в ландшафте, маленькие планшеты, foldable.
  medium,

  /// 840 dp и больше — iPad, большие планшеты.
  /// На таких экранах контент ограничивается по ширине, чтобы не
  /// растягиваться от края до края.
  expanded,
}

/// Расширение [BuildContext] для адаптивной верстки.
///
/// Использование:
/// ```dart
/// Padding(
///   padding: EdgeInsets.symmetric(horizontal: context.gutter),
///   child: ...
/// )
/// ```
extension ResponsiveContext on BuildContext {
  /// Размер доступной области (без статус-бара).
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  /// Текущий класс размера окна по Material 3.
  WindowSizeClass get windowSize {
    final w = screenWidth;
    if (w < 600) return WindowSizeClass.compact;
    if (w < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  bool get isCompact => windowSize == WindowSizeClass.compact;
  bool get isMedium => windowSize == WindowSizeClass.medium;
  bool get isExpanded => windowSize == WindowSizeClass.expanded;

  /// Удобный шорткат: всё, что шире телефона.
  bool get isTablet => screenWidth >= 600;
  bool get isPhone => screenWidth < 600;

  /// Боковые отступы контента от края экрана.
  /// На планшетах больше — визуальное «дыхание» вокруг контента.
  double get gutter => switch (windowSize) {
        WindowSizeClass.compact => 16,
        WindowSizeClass.medium => 24,
        WindowSizeClass.expanded => 32,
      };

  /// Вертикальный интервал между секциями.
  double get sectionSpacing => switch (windowSize) {
        WindowSizeClass.compact => 16,
        WindowSizeClass.medium => 20,
        WindowSizeClass.expanded => 24,
      };

  /// Максимальная ширина контентного блока — чтобы текст и карточки
  /// не растягивались на iPad от края до края.
  ///
  /// 600 dp ≈ оптимальная длина строки для чтения (65–75 символов),
  /// что соответствует типографическим рекомендациям WCAG.
  double get maxContentWidth => switch (windowSize) {
        WindowSizeClass.compact => double.infinity,
        WindowSizeClass.medium => 640,
        WindowSizeClass.expanded => 760,
      };

  /// Максимальный размер карточки в сетке выбора эмоций.
  /// На планшете карточки не должны вырастать до огромных размеров.
  double get maxChoiceCardSize => switch (windowSize) {
        WindowSizeClass.compact => 180,
        WindowSizeClass.medium => 220,
        WindowSizeClass.expanded => 240,
      };

  /// Число колонок сетки карточек в модулях.
  /// Параметры позволяют переопределить дефолт для конкретного экрана.
  int gridColumns({int compact = 2, int medium = 3, int expanded = 3}) =>
      switch (windowSize) {
        WindowSizeClass.compact => compact,
        WindowSizeClass.medium => medium,
        WindowSizeClass.expanded => expanded,
      };
}

/// Обёртка для body Scaffold-а, ограничивающая ширину контента
/// на больших экранах и применяющая адаптивные боковые отступы.
///
/// Не растягивает контент при ширине меньше [BuildContext.maxContentWidth] —
/// просто пропускает его как есть. На iPad центрирует и капает по
/// `maxContentWidth`, чтобы контент не «плыл» через весь экран.
///
/// Пример:
/// ```dart
/// Scaffold(body: SafeArea(child: ResponsiveContainer(child: ...)))
/// ```
class ResponsiveContainer extends StatelessWidget {
  final Widget child;

  /// Кастомный максимум ширины (по умолчанию берётся из контекста).
  final double? maxWidth;

  /// Кастомные горизонтальные отступы (по умолчанию [BuildContext.gutter]
  /// с двух сторон). Передай [EdgeInsets.zero] чтобы выключить.
  final EdgeInsetsGeometry? padding;

  /// Выравнивание контента внутри расширенного пространства.
  /// По умолчанию — по центру (стандартное поведение для iPad).
  final Alignment alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? context.maxContentWidth;
    final effectivePadding = padding ??
        EdgeInsets.symmetric(horizontal: context.gutter);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
  }
}

/// Удобный SizedBox с адаптивной высотой по [BuildContext.sectionSpacing].
/// Заменяет `SizedBox(height: 16)` где значение должно зависеть от
/// размера окна.
class AdaptiveGap extends StatelessWidget {
  /// Множитель базового интервала. 1.0 — стандартный sectionSpacing.
  final double scale;
  const AdaptiveGap({super.key, this.scale = 1.0});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: context.sectionSpacing * scale);
}
