import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/emotion.dart';
import '../data/tasks_data.dart';
import '../widgets/common_widgets.dart';
import 'module_screen_base.dart';

/// Модуль 3 — «Эмоции в ситуации»: социальные истории по К. Грей.
///
/// Самый высокий когнитивный уровень в программе. Ребёнку
/// читается короткая бытовая история, и нужно определить, что
/// чувствует персонаж — **без фотографии лица**. Это требует:
/// - удержания контекста в рабочей памяти;
/// - построения причинно-следственной связи «событие → эмоция»;
/// - переноса знаний об эмоциях на типовые жизненные ситуации.
///
/// Социальные истории — методика, специально разработанная для
/// детей с РАС (Carol Gray, 1991). Она помогает формировать
/// социальную компетентность через структурированное описание
/// типовых ситуаций и подходящих реакций на них.
///
/// Дополнительный рефлексивный вопрос (`followUpQuestion`)
/// в некоторых заданиях развивает вербализацию причин
/// эмоциональных реакций — следующий уровень понимания.
class Module3Screen extends StatefulWidget {
  const Module3Screen({super.key});

  @override
  State<Module3Screen> createState() => _Module3ScreenState();
}

class _Module3ScreenState extends State<Module3Screen>
    with ModuleTaskMixin<Module3Screen> {
  final _rng = Random();

  String? _selectedEmotionId;
  late List<Emotion> _shuffledChoices;

  List<Module3Task> get _tasks => module3Tasks;
  Module3Task get _currentTask => _tasks[taskIndex % _tasks.length];

  /// В отличие от модуля 1 набор вариантов фиксирован для каждой
  /// истории (см. [Module3Task.choiceEmotionIds]) — меняется только
  /// порядок отображения.
  void _shuffleChoices() {
    _shuffledChoices = _currentTask.choiceEmotionIds
        .map((id) => EmotionData.getById(id))
        .toList()
      ..shuffle(_rng);
  }

  @override
  void initState() {
    super.initState();
    _shuffleChoices();
    onModuleEntered('module3');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await restoreTaskIndex(
        moduleId: 'module3',
        maxTasks: _tasks.length,
        onRestored: _shuffleChoices,
      );
    });
  }

  void _onChoiceTap(String emotionId) {
    submitAnswer(
      moduleId: 'module3',
      emotionId: _currentTask.targetEmotionId,
      selectedEmotionId: emotionId,
      correct: emotionId == _currentTask.targetEmotionId,
      onSetSelection: () => _selectedEmotionId = emotionId,
    );
  }

  void _nextTask() {
    advanceTask(
      moduleId: 'module3',
      taskCount: _tasks.length,
      onPrepareNext: () {
        _selectedEmotionId = null;
        _shuffleChoices();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _currentTask;
    final targetEmotion = EmotionData.getById(task.targetEmotionId);

    return Scaffold(
      appBar: AppBar(
        leading: buildBackButton(),
        title: const Text('📖 Ситуация'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${taskIndex + 1} / ${_tasks.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter, vertical: 8),
          child: SingleChildScrollView(
            child: Column(
            children: [
              ModuleProgressBar(current: taskIndex + 1, total: _tasks.length),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                const SizedBox(height: 16),
                              ],
                            ),
                    ),
                    _buildStoryCard(task.storyText),
                    const SizedBox(height: 16),
                    Text(
                      task.question,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                    const SizedBox(height: 16),
                    _buildChoiceGrid(),
                    if (answered) ...[
                      const SizedBox(height: 12),
                      FeedbackBanner(
                        isCorrect: isCorrect,
                        isVisible: true,
                        customMessage: isCorrect
                            ? '✓ Верно! Это ${targetEmotion.nameRu}!'
                            : 'Правильный ответ: ${targetEmotion.emoji} ${targetEmotion.nameRu}',
                      ),
                      const SizedBox(height: 12),
                      EmotionInfoCard(emotion: targetEmotion),
                      // Только после ответа — даёт педагогу повод для
                      // развёрнутого обсуждения с ребёнком.
                      if (task.followUpQuestion != null) ...[
                        const SizedBox(height: 12),
                        _buildFollowUpQuestion(task.followUpQuestion!),
                      ],
                      const SizedBox(height: 12),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Голубой фон с рамкой визуально отделяет «текст для чтения»
  /// от вопроса и управляющих элементов.
  Widget _buildStoryCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFD4E5F7), width: 1.5),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              // Увеличенный line-height улучшает читаемость
              // длинного текста для детей с трудностями чтения.
              height: 1.7,
            ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  /// Сетка вариантов: 2 в ряд если эмоций ≤ 2 (Row для
  /// удобной растягиваемости), сетка 2×N для большего количества.
  /// childAspectRatio < 1 даёт ячейкам чуть больше высоты —
  /// иначе круглая карточка с подписью не помещается.
  Widget _buildChoiceGrid() {
    final choices = _shuffledChoices;
    if (choices.length <= 2) {
      return Row(
        children: choices.map((emotion) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildChoiceButton(emotion),
            ),
          );
        }).toList(),
      );
    }
    // На планшете показываем 3 колонки если вариантов 3+ — это
    // помещается одной строкой и не выглядит «потерянным» среди
    // широкого пространства экрана.
    final cols = choices.length >= 3 && context.isTablet ? 3 : 2;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      // Ячейка чуть выше квадрата — резервирует место под подпись
      // эмоции, появляющуюся после ответа. См. подробности в
      // module1_screen.dart:_buildChoiceGrid.
      childAspectRatio: 0.82,
      children: choices.asMap().entries.map((entry) {
        return RepaintBoundary(
          key: ValueKey('${taskIndex}_${entry.value.id}'),
          child: _buildChoiceButton(entry.value),
        );
      }).toList(),
    );
  }

  /// Одна карточка выбора эмоции. Использует общий [EmotionChoiceCard]
  /// — это сохраняет единый визуальный язык между модулями 1 и 3.
  ///
  /// Все карточки в одном задании показывают фото пола, совпадающего
  /// с полом героя истории ([Module3Task.characterGender]). Это
  /// убирает «когнитивный шум»: ребёнок сравнивает эмоции на лицах,
  /// а не отвлекается на несоответствие пола.
  Widget _buildChoiceButton(Emotion emotion) {
    CardState state = CardState.neutral;
    if (answered) {
      if (emotion.id == _currentTask.targetEmotionId) {
        state = CardState.correct;
      } else if (emotion.id == _selectedEmotionId) {
        state = CardState.wrong;
      }
    }
    // Подбираем индекс фото нужного пола внутри Emotion.photos.
    // Если у эмоции нет фото подходящего пола, метод вернёт 0 —
    // безопасный фолбэк на любое фото.
    final imgIndex =
        emotion.photoIndexForGender(_currentTask.characterGender);
    return EmotionChoiceCard(
      emotion: emotion,
      imageIndex: imgIndex,
      onTap: () => _onChoiceTap(emotion.id),
      state: state,
    );
  }

  /// Карточка с рефлексивным вопросом и приглашением к диалогу.
  /// Фиолетовый цвет визуально отличает её от обучающих карточек
  /// и сигнализирует «сейчас обсуди с педагогом» —
  /// это не самостоятельное действие, а коммуникативное.
  Widget _buildFollowUpQuestion(String question) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.purpleLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border:
            Border.all(color: AppTheme.purple.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💭 Подумай:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.purple,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          // Явное приглашение к диалогу — самостоятельно ребёнок
          // в текст ответа не вводит, эта функция реализуется
          // через коммуникацию со взрослым.
          Text(
            'Обсуди ответ с педагогом или родителем.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
