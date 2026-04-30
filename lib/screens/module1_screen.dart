import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/emotion.dart';
import '../models/progress_model.dart';
import '../data/tasks_data.dart';
import '../widgets/common_widgets.dart';
import 'module_screen_base.dart';

/// Модуль 1 — «Знакомство»: рецептивный уровень, ребёнок связывает
/// фото эмоции с её названием. 2–6 вариантов выбора по адаптивной
/// сложности; дистракторы перемешиваются, чтобы правильная карточка
/// не оказывалась всегда в одной позиции (позиционный эффект).
class Module1Screen extends StatefulWidget {
  const Module1Screen({super.key});

  @override
  State<Module1Screen> createState() => _Module1ScreenState();
}

class _Module1ScreenState extends State<Module1Screen>
    with ModuleTaskMixin<Module1Screen> {
  String? _selectedEmotionId;
  List<Emotion> _choices = [];
  late Module1Task _activeTask;

  /// Подмножество заданий пула, доступных при текущей сложности.
  /// Чем выше сложность модуля, тем большее значение `difficultyLevel`
  /// заданий допускается. Формула `((maxDiff + 1) ~/ 2 + 1)`
  /// даёт постепенное расширение пула: сложность 1 → задания
  /// уровня ≤ 2, сложность 5 → до 4.
  List<Module1Task> get _tasks {
    final progress = context.read<ProgressModel>();
    final maxDiff = progress.difficulty['module1'] ?? 1;
    return module1Tasks
        .where((t) => t.difficultyLevel <= ((maxDiff + 1) ~/ 2 + 1))
        .toList();
  }

  /// Текущее задание. taskIndex может превысить длину пула при
  /// смене сложности — оператор `%` зацикливает безопасно.
  Module1Task get _currentTask => _tasks[taskIndex % _tasks.length];

  @override
  void initState() {
    super.initState();
    _prepareTask();
    onModuleEntered('module1');
    // Восстанавливаем сохранённый индекс задания после первой отрисовки —
    // нужно, чтобы контекст уже был доступен.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await restoreTaskIndex(
        moduleId: 'module1',
        maxTasks: _tasks.length,
        onRestored: _prepareTask,
      );
    });
  }

  /// Перемешивает варианты, чтобы избежать позиционного эффекта
  /// (ребёнок не должен «привыкать» нажимать в одну точку).
  void _prepareTask() {
    _activeTask = _currentTask;
    final progress = context.read<ProgressModel>();
    final choiceCount = progress.getChoiceCount('module1');
    final target = EmotionData.getById(_activeTask.targetEmotionId);
    final distractors = (EmotionData.all
          .where((e) => e.id != target.id)
          .toList()
        ..shuffle())
        .take(choiceCount - 1)
        .toList();
    _choices = [target, ...distractors]..shuffle();
    _selectedEmotionId = null;
  }

  void _onChoiceTap(String emotionId) {
    submitAnswer(
      moduleId: 'module1',
      emotionId: _activeTask.targetEmotionId,
      selectedEmotionId: emotionId,
      correct: emotionId == _activeTask.targetEmotionId,
      onSetSelection: () => _selectedEmotionId = emotionId,
    );
  }

  void _nextTask() {
    advanceTask(
      moduleId: 'module1',
      taskCount: _tasks.length,
      onPrepareNext: _prepareTask,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _activeTask;
    return Scaffold(
      appBar: AppBar(
        leading: buildBackButton(),
        title: const Text('🔍 Знакомство'),
        actions: const [],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter, vertical: 8),
          child: Column(
            children: [
              ModuleProgressBar(current: taskIndex + 1, total: _tasks.length),
              const SizedBox(height: 8),
              Expanded(
                // Прячем скроллбары — отвлекают внимание от задания.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Сворачивается после ответа, освобождая место для feedback.
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: answered
                              ? const SizedBox.shrink()
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HelperCat(message: task.helperHint),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                        ),
                        Text(
                          task.question,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(duration: 300.ms),
                        const SizedBox(height: 10),
                        _buildChoiceGrid(),
                        if (answered) ...[
                          const SizedBox(height: 8),
                          // Кастомное сообщение включает название эмоции —
                          // обучающий момент: ребёнок видит правильный ответ
                          // независимо от того, правильно ли он угадал.
                          FeedbackBanner(
                            isCorrect: isCorrect,
                            isVisible: true,
                            customMessage: isCorrect
                                ? '✓ Правильно! Это ${EmotionData.getById(task.targetEmotionId).nameRu}!'
                                : '${EmotionData.getById(task.targetEmotionId).emoji} Это — ${EmotionData.getById(task.targetEmotionId).nameRu}',
                          ),
                          const SizedBox(height: 8),
                          EmotionInfoCard(
                            emotion: EmotionData.getById(task.targetEmotionId),
                          ),
                          const SizedBox(height: 8),
                          NextButton(
                            label: taskIndex + 1 >= _tasks.length
                                ? 'Завершить 🎉'
                                : 'Дальше →',
                            onPressed: _nextTask,
                            isVisible: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Сетка вариантов выбора. Число колонок зависит от:
  /// 1. Адаптивной сложности — количество вариантов (2/4/6);
  /// 2. Класса размера окна — на планшете показываем больше колонок,
  ///    чтобы карточки не растягивались до неоправданно крупных
  ///    размеров и сохранялась обзорность.
  ///
  /// Раскладка:
  /// - 2 варианта: 2 колонки везде;
  /// - 4 варианта: 2 на телефоне (две строки), 4 на планшете (одна);
  /// - 6 вариантов: 2 на телефоне (три строки), 3 на планшете (две).
  ///
  /// RepaintBoundary с ключом по заданию помогает Flutter оптимизировать
  /// перерисовку при смене задания (старая ячейка не пересчитывает
  /// анимации).
  Widget _buildChoiceGrid() {
    final task = _activeTask;
    final cols = _gridColumns(context, _choices.length);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        // Ячейка чуть выше квадрата — резервирует место под подпись
        // эмоции, появляющуюся после ответа. Сам круг занимает
        // только ширину ячейки, оставшаяся высота отдаётся подписи.
        // Так Column [круг + подпись] всегда вписывается без overflow,
        // и при этом круг остаётся стабильного размера (нет анимации
        // сжатия при появлении подписи).
        childAspectRatio: 0.82,
      ),
      itemCount: _choices.length,
      itemBuilder: (context, i) {
        final emotion = _choices[i];
        // Дистракторы берут 0-й вариант фото — конкретный индекс не важен,
        // важно лишь чтобы фото отличалось от правильного.
        final imgIndex =
            emotion.id == task.targetEmotionId ? task.imageIndex : 0;
        CardState state = CardState.neutral;
        if (answered) {
          if (emotion.id == task.targetEmotionId) {
            state = CardState.correct;
          } else if (emotion.id == _selectedEmotionId) {
            state = CardState.wrong;
          }
        }
        return RepaintBoundary(
          key: ValueKey('${taskIndex}_${emotion.id}'),
          child: EmotionChoiceCard(
            emotion: emotion,
            imageIndex: imgIndex,
            onTap: () => _onChoiceTap(emotion.id),
            state: state,
          ),
        );
      },
    );
  }

  /// Адаптивное число колонок для сетки выбора.
  /// Логика описана в [_buildChoiceGrid].
  int _gridColumns(BuildContext context, int choiceCount) {
    if (choiceCount <= 2) return 2;
    if (choiceCount == 4) return context.isTablet ? 4 : 2;
    // 6 вариантов: на телефоне 2 колонки (3 строки) — иначе ячейка
    // получается слишком узкой (~104 dp), лица плохо различимы,
    // а подпись эмоции не помещается под кругом и даёт overflow.
    // На планшете шире — позволяем 3 колонки в 2 строки.
    return context.isTablet ? 3 : 2;
  }
}
