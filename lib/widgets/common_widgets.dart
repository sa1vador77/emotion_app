import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/emotion.dart';

/// Состояние карточки выбора эмоции — определяет внешний вид
/// (цвет рамки, фон, подсветка) и реакцию на касание.
enum CardState {
  /// Нейтральное — карточка кликабельна, обычные цвета.
  neutral,

  /// Правильный выбор — зелёная подсветка, отображается название эмоции.
  correct,

  /// Неправильный выбор — красная подсветка, отображается название.
  wrong,
}

/// Карточка эмоции для выбора в модулях 1 и 3 и диагностике.
///
/// Реализована круглой формой 130×130 с фото эмоции и опциональным
/// текстом названия снизу. Поддерживает три визуальных состояния
/// ([CardState]) — переключение между ними анимировано.
///
/// Дизайн-решения:
/// - **Круглая форма** мягче воспринимается детьми с РАС
///   (нет «агрессивных» прямых углов).
/// - **Колор-матрица** на изображении сглаживает яркие цвета фото
///   и смещает их в пастель — снижение сенсорной нагрузки.
/// - Название эмоции **скрыто по умолчанию** и появляется только
///   после ответа (либо если явно передан `showLabel: true`) —
///   чтобы ребёнок учился узнавать эмоцию по лицу, а не читать
///   подпись.
class EmotionChoiceCard extends StatefulWidget {
  /// Эмоция, отображаемая на карточке.
  final Emotion emotion;

  /// Колбэк по тапу — срабатывает только в состоянии [CardState.neutral].
  /// После ответа дальнейшие тапы игнорируются до перехода к следующему
  /// заданию (защита от случайных повторных нажатий).
  final VoidCallback onTap;

  /// Текущее состояние карточки.
  final CardState state;

  /// Принудительно показывать название эмоции даже в нейтральном состоянии.
  /// Используется в обучающих экранах, где нужна подпись для подкрепления.
  final bool showLabel;

  /// Индекс варианта фото в [Emotion.imagePaths]. Разные индексы
  /// дают разные лица — важно для проверки обобщения распознавания.
  final int imageIndex;

  const EmotionChoiceCard({
    super.key,
    required this.emotion,
    required this.onTap,
    this.state = CardState.neutral,
    this.showLabel = false,
    this.imageIndex = 0,
  });

  @override
  State<EmotionChoiceCard> createState() => _EmotionChoiceCardState();
}

class _EmotionChoiceCardState extends State<EmotionChoiceCard> {
  /// Флаг физического нажатия — управляет цветом рамки в момент тапа
  /// (тактильная обратная связь).
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color shadowColor;
    Color bgColor;

    switch (widget.state) {
      case CardState.correct:
        borderColor = AppTheme.green;
        shadowColor = AppTheme.green.withValues(alpha: 0.22);
        bgColor = AppTheme.greenLight;
        break;
      case CardState.wrong:
        borderColor = AppTheme.errorText;
        shadowColor = AppTheme.errorText.withValues(alpha: 0.15);
        bgColor = AppTheme.errorSoft;
        break;
      case CardState.neutral:
        borderColor = _pressed
            ? AppTheme.blue
            : const Color(0xFFD4E5F7);
        shadowColor = AppTheme.blue.withValues(alpha: _pressed ? 0.18 : 0.1);
        bgColor = widget.emotion.color;
        break;
    }

    final showName = widget.showLabel || widget.state != CardState.neutral;
    final path = widget.emotion.imagePathAt(widget.imageIndex);

    // LayoutBuilder даёт реальный размер ячейки сетки — карточка
    // адаптируется к нему вместо фиксированных 130×130.
    //
    // Размер круга = ширина ячейки (shortestSide для надёжности на
    // любых пропорциях). Контракт с сеткой: ячейки заранее имеют
    // childAspectRatio < 1 (см. _buildChoiceGrid в module1/3), то есть
    // высота больше ширины. Свободная высота под подпись уже учтена
    // на стороне сетки — здесь круг не сжимаем.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Минимум 60 — гарантирует touch-target даже на узких ячейках.
        // Максимум — из контекста (на iPad не больше maxChoiceCardSize).
        final double circleSize = constraints.maxWidth
            .clamp(60.0, context.maxChoiceCardSize);

        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            // Защита: после ответа карточка перестаёт реагировать.
            if (widget.state == CardState.neutral) widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  width: circleSize,
                  height: circleSize,
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    // Матрица RGB-преобразования: смягчает контраст и
                    // приглушает цвета фото, делая их пастельными.
                    // Снижает сенсорную нагрузку для ребёнка с РАС.
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.764, 0.215, 0.022, 0, 8,
                        0.064, 0.914, 0.022, 0, 8,
                        0.064, 0.215, 0.721, 0, 8,
                        0,     0,     0,     1, 0,
                      ]),
                      child: Image.asset(
                        path,
                        fit: BoxFit.cover,
                        // Fallback на эмодзи — размер эмодзи берём
                        // как треть круга, чтобы пропорционально
                        // смотрелось на любом размере карточки.
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(widget.emotion.emoji,
                              style: TextStyle(fontSize: circleSize * 0.34)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showName) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.emotion.nameRu,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      // Цвет подписи синхронизируется с состоянием:
                      // зелёный при правильном ответе, красный — при ошибке.
                      color: widget.state == CardState.correct
                          ? const Color(0xFF2A7A4A)
                          : widget.state == CardState.wrong
                              ? AppTheme.errorText
                              : AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Помощник-кот — персонаж, дающий подсказки на обучающих экранах.
///
/// Состоит из эмодзи-кота и речевого пузыря с текстом.
/// Введение узнаваемого «друга»-помощника — приём из методики
/// социальных историй (К. Грей): он создаёт эмоциональную связь
/// и снижает тревожность от взаимодействия с интерфейсом.
class HelperCat extends StatelessWidget {
  /// Текст в речевом пузыре.
  final String message;

  /// Запускать ли анимацию появления (fade + slide).
  /// Отключается при обновлениях с тем же текстом, чтобы не
  /// «дёргать» виджет.
  final bool animate;

  const HelperCat({
    super.key,
    required this.message,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      // center вместо end: эмодзи кота (44pt) выше пузыря с текстом,
      // и при end-align текст визуально оказывается ниже «лица» кота
      // — особенно заметно в диагностике, где вопрос короткий.
      // center выравнивает середины обоих, текст пузыря оказывается
      // на уровне «глаз» эмодзи.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('🐱', style: TextStyle(fontSize: 44)),
        const SizedBox(width: 10),
        // Без жёсткого maxWidth — пузырь сжимается на узких телефонах и
        // расширяется на планшетах (ширину в целом капает ResponsiveContainer).
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              border: Border.all(color: const Color(0xFFFFD0A8), width: 1.5),
              // Скругление «хвостика»: левый нижний угол меньше
              // остальных — имитация классического речевого облака.
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          )
              .animate(target: animate ? 1 : 0)
              .fadeIn(duration: 300.ms)
              .slideX(begin: -0.1, end: 0),
        ),
      ],
    );
  }
}

/// Кнопка «Дальше» в нижней части обучающих экранов.
///
/// Появляется после ответа ребёнка, плавно «выезжая» снизу.
/// Видимость контролируется через [isVisible] — это позволяет
/// показывать кнопку только тогда, когда дальнейшее действие
/// уместно.
class NextButton extends StatelessWidget {
  /// Текст кнопки (по умолчанию «Дальше →», для последнего
  /// задания меняется на «Завершить 🎉»).
  final String label;

  /// Колбэк по нажатию.
  final VoidCallback onPressed;

  /// Видна ли кнопка. False делает её прозрачной и неинтерактивной.
  final bool isVisible;

  const NextButton({
    super.key,
    this.label = 'Дальше →',
    required this.onPressed,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedSlide(
        // Кнопка появляется сдвигом снизу — визуально подсказывает,
        // что это «следующий шаг», а не часть статической раскладки.
        offset: isVisible ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 300),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isVisible ? onPressed : null,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Баннер обратной связи после ответа (правильно/неправильно).
///
/// Цвет и текст подстраиваются под результат:
/// - правильно → зелёный, "✓ Правильно! Молодец!" (или кастомное);
/// - неправильно → мягкий розовый, "Попробуй ещё раз 💙".
///
/// Формулировка ошибки специально щадящая (сердечко, «попробуй»),
/// без слов «неверно» или «ошибка» — критически важно для
/// мотивации ребёнка с РАС, который болезненно реагирует на
/// критику.
class FeedbackBanner extends StatelessWidget {
  final bool isCorrect;
  final bool isVisible;

  /// Опциональный кастомный текст. Если задан, используется вместо
  /// стандартного — даёт возможность включить название эмоции
  /// в обратную связь («Это была радость!»).
  final String? customMessage;

  const FeedbackBanner({
    super.key,
    required this.isCorrect,
    this.isVisible = true,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final message = customMessage ??
        (isCorrect ? '✓ Правильно! Молодец!' : 'Попробуй ещё раз 💙');
    final bgColor = isCorrect ? AppTheme.greenLight : AppTheme.errorSoft;
    final textColor =
        isCorrect ? const Color(0xFF2A7A4A) : AppTheme.errorText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    )
        // Лёгкая анимация появления с небольшим масштабированием —
        // привлекает внимание без агрессивности.
        .animate()
        .fadeIn(duration: 250.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}

/// Информационная карточка с описанием эмоции — показывается
/// после ответа в модулях 1 и 3 как обучающий момент.
///
/// Содержит эмодзи, название и текстовое описание ситуации,
/// в которой возникает эмоция. Это закрепляет связь между
/// мимикой и контекстом.
class EmotionInfoCard extends StatelessWidget {
  final Emotion emotion;

  const EmotionInfoCard({super.key, required this.emotion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blueLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: const Color(0xFFD4E5F7),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emotion.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                emotion.nameRu,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            emotion.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0);
  }
}

/// Анимация завершения модуля — большой кубок и три звезды,
/// появляющиеся с задержкой.
///
/// Подкрепление через достижения (геймификация) повышает
/// мотивацию к продолжению. Эластичная анимация и shimmer-эффект
/// делают момент эмоционально насыщенным, но без резкости.
class CompletionAnimation extends StatelessWidget {
  const CompletionAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppTheme.green.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.green.withValues(alpha: 0.35),
              width: 3,
            ),
          ),
          child: const Center(
            child: Text('🏆', style: TextStyle(fontSize: 54)),
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.3, 0.3),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 18),
        // Три звезды, появляющиеся одна за другой (delay растёт
        // на 140мс) с золотым переливом — праздничный, но не
        // перегружающий эффект.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: const Text('⭐', style: TextStyle(fontSize: 34))
                  .animate(delay: Duration(milliseconds: 450 + i * 140))
                  .scale(
                    begin: const Offset(0.0, 0.0),
                    end: const Offset(1.0, 1.0),
                    duration: 380.ms,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: 200.ms)
                  .then(delay: 300.ms)
                  .shimmer(duration: 700.ms, color: const Color(0xFFFFD700)),
            );
          }),
        ),
      ],
    );
  }
}

/// Прогресс-бар модуля — показывает «N из M» и линейный индикатор.
///
/// Видимый прогресс важен для ребёнка с РАС: он даёт ощущение
/// завершённости и структуру (характерная потребность). Также
/// помогает педагогу понимать, сколько ещё осталось до перерыва.
class ModuleProgressBar extends StatelessWidget {
  /// Номер текущего задания (1-based).
  final int current;

  /// Общее количество заданий.
  final int total;

  const ModuleProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? current / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$current / $total',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: const Color(0xFFD4E5F7),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.blue),
          ),
        ),
      ],
    );
  }
}
