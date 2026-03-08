import 'package:flutter/material.dart';

/// Централизованная тема приложения «Мир эмоций».
///
/// Хранит всю визуальную систему: палитру, типографику, радиусы,
/// тени и [ThemeData] для Material Design 3. Любое изменение
/// внешнего вида (цвет, шрифт, скругления) должно происходить
/// здесь — экраны и виджеты обращаются только к константам
/// [AppTheme], а не задают цвета напрямую.
///
/// Палитра подобрана с учётом сенсорной ранимости детей с РАС:
/// мягкие пастельные тона, отсутствие чистого белого фона,
/// высокий контраст текста для лёгкого чтения, без резких
/// насыщенных цветов, которые могут вызывать перевозбуждение.
class AppTheme {
  // ─── Палитра ──────────────────────────────────────────────────────────

  /// Основной фон приложения — мягкий голубовато-белый.
  /// Не используем чистый белый (#FFFFFF) — он слепит и снижает
  /// читаемость для детей с сенсорными особенностями.
  static const Color bgPrimary = Color(0xFFF0F7FF);

  /// Фон карточек, диалогов и поднятых поверхностей. Здесь чистый
  /// белый допустим, потому что карточки занимают меньшую площадь
  /// и контрастируют с [bgPrimary].
  static const Color bgCard = Color(0xFFFFFFFF);

  static const Color bgSecondary = Color(0xFFE8F2FF);

  /// Акцентный оранжевый — для CTA, выделения, помощника-кота.
  /// Тёплый оттенок создаёт ощущение дружелюбия.
  static const Color accent = Color(0xFFFF8C42);

  /// Светлый вариант оранжевого — для фонов карточек подсказок.
  static const Color accentLight = Color(0xFFFFF0E5);

  /// Основной синий — кнопки, активные элементы, прогресс.
  static const Color blue = Color(0xFF4A90D9);

  /// Светло-голубой фон для информационных блоков.
  static const Color blueLight = Color(0xFFEBF4FF);

  /// Тёмно-синий — для нажатых состояний и сильного акцента.
  static const Color blueDark = Color(0xFF2C6FAC);

  /// Зелёный — индикатор правильного ответа и положительной динамики.
  static const Color green = Color(0xFF52C97A);

  /// Светло-зелёный фон — для подсветки правильных карточек.
  static const Color greenLight = Color(0xFFE8F9EE);

  /// Мягкий розово-красный фон ошибок. Намеренно не агрессивный:
  /// у детей с РАС резкий красный может вызвать стресс.
  static const Color errorSoft = Color(0xFFFFEBEB);

  /// Цвет текста и иконок ошибок. Тёмно-красный для контраста.
  static const Color errorText = Color(0xFFC0392B);

  /// Основной цвет текста — глубокий сине-стальной.
  /// Высокий контраст с [bgPrimary], легко читается.
  static const Color textPrimary = Color(0xFF1E3A5F);

  /// Приглушённый текст — подписи, второстепенная информация.
  static const Color textMuted = Color(0xFF5A7A9F);

  /// Светлый текст — даты, метки шкалы, плейсхолдеры.
  static const Color textLight = Color(0xFF8AAAC8);

  /// Фиолетовый акцент — используется в карточках «подумай»
  /// и для разделения смысловых блоков.
  static const Color purple = Color(0xFF8B6FD4);

  /// Светло-фиолетовый фон рефлексивных блоков.
  static const Color purpleLight = Color(0xFFF0ECFF);

  // ─── Типографика ──────────────────────────────────────────────────────

  /// Системный шрифт iOS. На Android Flutter подставит Roboto.
  /// Использование системного шрифта снижает размер сборки и
  /// гарантирует читаемость при offline-режиме (нет загрузки
  /// шрифтов из сети).
  static const String _font = 'SF Pro Rounded';

  /// Единая шкала типографики. Названия следуют Material 3:
  /// `display*` — крупные заголовки экранов,
  /// `headline*` — заголовки секций,
  /// `title*`   — подписи к карточкам и кнопкам,
  /// `body*`    — основной текст,
  /// `label*`   — текст на кнопках и микро-пометки.
  ///
  /// `height: 1.5–1.6` для body — повышенная межстрочная
  /// плотность облегчает чтение детям с трудностями восприятия.
  ///
  /// Шкала покрывает все размеры, нужные приложению — чтобы экраны
  /// не задавали `fontSize:` напрямую, а обращались к роли через
  /// `Theme.of(context).textTheme.X`. Это критично для адаптивности:
  /// один источник правды для размеров и единое поведение при
  /// масштабировании текста системой (accessibility).
  static TextTheme get textTheme => const TextTheme(
    displayLarge:   TextStyle(fontFamily: _font, fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
    displayMedium:  TextStyle(fontFamily: _font, fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary),
    displaySmall:   TextStyle(fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary),
    headlineLarge:  TextStyle(fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
    headlineMedium: TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
    headlineSmall:  TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
    titleLarge:     TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
    titleMedium:    TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
    titleSmall:     TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
    bodyLarge:      TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary, height: 1.6),
    bodyMedium:     TextStyle(fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary, height: 1.5),
    bodySmall:      TextStyle(fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w400, color: textPrimary, height: 1.4),
    labelLarge:     TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
    labelMedium:    TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
    labelSmall:     TextStyle(fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
  );

  // ─── Радиусы скруглений ───────────────────────────────────────────────

  /// Малое скругление — поля ввода, мелкие кнопки.
  static const double radiusSm = 12.0;

  /// Среднее — обычные кнопки, баннеры.
  static const double radiusMd = 16.0;

  /// Большое — карточки, диалоги.
  static const double radiusLg = 24.0;

  /// Очень большое — фирменные крупные блоки (награды, оверлеи).
  /// Мягкие округлые формы дружелюбнее для восприятия.
  static const double radiusXl = 32.0;

  // ─── Тени ─────────────────────────────────────────────────────────────

  /// Мягкая тень карточки. Низкая непрозрачность (10%) и большое
  /// размытие создают ощущение «парящей» поверхности без
  /// агрессивных границ.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: blue.withValues(alpha: 0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Более заметная тень для интерактивных кнопок —
  /// подсказывает пользователю, что элемент «нажимается».
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: blue.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Сборка ThemeData ─────────────────────────────────────────────────

  /// Готовый [ThemeData] для передачи в [MaterialApp.theme].
  ///
  /// Включает Material 3, генерирует [ColorScheme] из seed-цвета,
  /// и переопределяет тему AppBar и кнопок под фирменный стиль.
  /// Цветовая схема выводится из синего, чтобы все производные
  /// оттенки (overlay, splash) автоматически гармонировали.
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue,
      surface: bgCard,
      primary: blue,
      secondary: accent,
      error: errorText,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
      margin: EdgeInsets.zero,
    ),
  );
}
