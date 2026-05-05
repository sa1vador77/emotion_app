import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/emotion.dart';
import '../data/tasks_data.dart';
import '../widgets/common_widgets.dart';
import 'module_screen_base.dart';

/// Связка «текстовая характеристика бровей + текстовая
/// характеристика рта» для одной эмоции. Используется как
/// эталон при проверке ответа в модуле 2.
class _EmotionFaceData {
  final String browsLabel;
  final String mouthLabel;

  const _EmotionFaceData({
    required this.browsLabel,
    required this.mouthLabel,
  });
}

/// Карта эмоция → правильные характеристики частей лица.
/// Используется в [_prepareTask] для определения правильного
/// варианта и в feedback-баннере для подсказки.
const Map<String, _EmotionFaceData> _faceData = {
  'joy':      _EmotionFaceData(browsLabel: 'Приподняты',      mouthLabel: 'Улыбка'),
  'sadness':  _EmotionFaceData(browsLabel: 'Уголки вниз',     mouthLabel: 'Уголки опущены'),
  'anger':    _EmotionFaceData(browsLabel: 'Нахмуренные',     mouthLabel: 'Сжатые губы'),
  'fear':     _EmotionFaceData(browsLabel: 'Высоко подняты',  mouthLabel: 'Открытый рот'),
  'surprise': _EmotionFaceData(browsLabel: 'Очень высоко',    mouthLabel: 'Широко открыт'),
  'disgust':  _EmotionFaceData(browsLabel: 'Одна выше',       mouthLabel: 'Нос сморщен'),
};

/// Один текстовый вариант выбора (часть лица).
class _TextOption {
  final String id;
  final String label;

  /// Является ли этот вариант правильным для текущего задания.
  /// Устанавливается при подготовке задания, не зависит от пула.
  final bool isCorrect;

  const _TextOption({
    required this.id,
    required this.label,
    this.isCorrect = false,
  });
}

/// Пул вариантов для бровей (4 типичных описания). Из него
/// выбирается один дистрактор для каждого задания.
const List<_TextOption> _allBrowsPool = [
  _TextOption(id: 'b_joy',  label: 'Приподняты'),
  _TextOption(id: 'b_sad',  label: 'Уголки вниз'),
  _TextOption(id: 'b_ang',  label: 'Нахмуренные'),
  _TextOption(id: 'b_fear', label: 'Высоко подняты'),
];

/// Пул вариантов для рта (4 типичных описания).
const List<_TextOption> _allMouthPool = [
  _TextOption(id: 'm_joy',  label: 'Улыбка'),
  _TextOption(id: 'm_sad',  label: 'Уголки опущены'),
  _TextOption(id: 'm_ang',  label: 'Сжатые губы'),
  _TextOption(id: 'm_fear', label: 'Открытый рот'),
];

/// Модуль 2 — «Конструктор»: ребёнку называется эмоция,
/// и нужно выбрать правильные характеристики бровей и рта
/// из двух вариантов в каждой строке.
///
/// Это **аналитический** уровень распознавания: ребёнок не
/// просто узнаёт лицо, а декомпозирует его на составляющие.
/// Это формирует понимание, **по каким признакам** определяется
/// эмоция — навык, который потом переносится на узнавание
/// в реальной жизни.
///
/// Задания делятся на две фазы:
/// 1. С образцом (`showReference: true`) — рядом показывается
///    подсказка-карточка с названием и эмодзи эмоции.
/// 2. Без образца — закрепление по памяти.
class Module2Screen extends StatefulWidget {
  const Module2Screen({super.key});

  @override
  State<Module2Screen> createState() => _Module2ScreenState();
}

class _Module2ScreenState extends State<Module2Screen>
    with ModuleTaskMixin<Module2Screen> {
  String? _selectedBrowsId;
  String? _selectedMouthId;

  late List<_TextOption> _browsOptions;
  late List<_TextOption> _mouthOptions;

  List<Module2Task> get _tasks => module2Tasks;
  Module2Task get _currentTask => _tasks[taskIndex % _tasks.length];

  @override
  void initState() {
    super.initState();
    _prepareTask();
    onModuleEntered('module2');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await restoreTaskIndex(
        moduleId: 'module2',
        maxTasks: _tasks.length,
        onRestored: _prepareTask,
      );
    });
  }

  /// Один дистрактор на часть лица (выбор из двух): на аналитическом
  /// уровне сам процесс декомпозиции уже когнитивно нагружает, больше
  /// вариантов сделало бы задание непосильным.
  void _prepareTask() {
    final fd = _faceData[_currentTask.targetEmotionId]!;
    final correctBrows =
        _TextOption(id: 'correct_brows', label: fd.browsLabel, isCorrect: true);
    final correctMouth =
        _TextOption(id: 'correct_mouth', label: fd.mouthLabel, isCorrect: true);
    final wrongBrows =
        _allBrowsPool.where((b) => b.label != fd.browsLabel).take(1).toList();
    final wrongMouths =
        _allMouthPool.where((m) => m.label != fd.mouthLabel).take(1).toList();
    _browsOptions = [correctBrows, ...wrongBrows]..shuffle();
    _mouthOptions = [correctMouth, ...wrongMouths]..shuffle();
    _selectedBrowsId = null;
    _selectedMouthId = null;
  }

  /// Ответ правильный, только если обе части выбраны верно.
  /// Это обучает целостному восприятию: одна правильная часть
  /// не делает лицо эмоцией.
  void _checkAnswer() {
    final correct = _selectedBrowsId == 'correct_brows' &&
        _selectedMouthId == 'correct_mouth';
    submitAnswer(
      moduleId: 'module2',
      emotionId: _currentTask.targetEmotionId,
      selectedEmotionId: _inferSelectedEmotionId(correct),
      correct: correct,
    );
  }

  /// Возвращает эмоцию, к которой ребёнок «собрал» лицо —
  /// нужно для матрицы путаницы в аналитике.
  ///
  /// Логика:
  /// 1. На правильном ответе — целевая эмоция (быстрый путь).
  /// 2. Иначе ищем эмоцию в [_faceData], у которой обе части
  ///    совпадают с выбранными лейблами. Это случай «собрал
  ///    другую целую эмоцию» — самый информативный для педагога.
  /// 3. Если такой нет (брови от одной эмоции, рот от другой) —
  ///    fallback на эмоцию по неправильной части. Приоритет:
  ///    сначала проверяем брови (как первая по порядку часть
  ///    выбора в UI), потом рот. Это компромисс между
  ///    статистической чистотой и информативностью — без него
  ///    половина ошибок не попала бы в матрицу.
  String _inferSelectedEmotionId(bool correct) {
    if (correct) return _currentTask.targetEmotionId;

    final picked = (
      brows: _browsOptions.firstWhere((o) => o.id == _selectedBrowsId).label,
      mouth: _mouthOptions.firstWhere((o) => o.id == _selectedMouthId).label,
    );

    for (final entry in _faceData.entries) {
      if (entry.value.browsLabel == picked.brows &&
          entry.value.mouthLabel == picked.mouth) {
        return entry.key;
      }
    }
    if (_selectedBrowsId != 'correct_brows') {
      for (final entry in _faceData.entries) {
        if (entry.value.browsLabel == picked.brows) return entry.key;
      }
    }
    for (final entry in _faceData.entries) {
      if (entry.value.mouthLabel == picked.mouth) return entry.key;
    }
    // Теоретически недостижимо: пулы покрывают все 6 эмоций.
    return _currentTask.targetEmotionId;
  }

  void _nextTask() {
    advanceTask(
      moduleId: 'module2',
      taskCount: _tasks.length,
      onPrepareNext: _prepareTask,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _currentTask;
    final emotion = EmotionData.getById(task.targetEmotionId);
    final fd = _faceData[emotion.id]!;

    return Scaffold(
      appBar: AppBar(
        leading: buildBackButton(),
        title: const Text('🧩 Конструктор'),
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
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        // Кот-помощник до ответа.
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
                        ),
                        const SizedBox(height: 10),
                        if (task.showReference && !answered)
                          _buildReference(emotion),
                        const SizedBox(height: 14),
                        _buildPartRow(
                          label: '👁 Брови:',
                          options: _browsOptions,
                          selectedId: _selectedBrowsId,
                          // Снимаем интерактивность после ответа,
                          // чтобы ребёнок не «исправлял» свой выбор.
                          onSelect: answered
                              ? null
                              : (id) => setState(() => _selectedBrowsId = id),
                        ),
                        const SizedBox(height: 12),
                        _buildPartRow(
                          label: '👄 Рот:',
                          options: _mouthOptions,
                          selectedId: _selectedMouthId,
                          onSelect: answered
                              ? null
                              : (id) => setState(() => _selectedMouthId = id),
                        ),
                        const SizedBox(height: 14),
                        if (answered) ...[
                          // После ответа показываем реальное фото
                          // эмоции — наглядное подтверждение того,
                          // как «правильные» части складываются в лицо.
                          _buildPhotoReveal(emotion),
                          const SizedBox(height: 12),
                          FeedbackBanner(
                            isCorrect: isCorrect,
                            isVisible: true,
                            customMessage: isCorrect
                                ? '✓ Правильно! Вот как выглядит ${emotion.nameRu}!'
                                : 'Правильно: ${fd.browsLabel} + ${fd.mouthLabel}',
                          ),
                          const SizedBox(height: 10),
                          EmotionInfoCard(emotion: emotion),
                          const SizedBox(height: 10),
                          NextButton(
                            label: taskIndex + 1 >= _tasks.length
                                ? 'Завершить 🎉'
                                : 'Дальше →',
                            onPressed: _nextTask,
                            isVisible: true,
                          ),
                        ] else
                          // Кнопка «Проверить» активна только когда
                          // обе части выбраны — даёт чёткий сигнал
                          // о том, что нужно завершить выбор.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_selectedBrowsId != null &&
                                      _selectedMouthId != null)
                                  ? _checkAnswer
                                  : null,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.green),
                              child: const Text('Проверить ✓'),
                            ),
                          ),
                      ],
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

  /// Карточка-образец, видимая в фазе с подсказкой.
  /// Содержит эмодзи и название эмоции на фоне «фирменного»
  /// цвета этой эмоции (см. [Emotion.color]).
  Widget _buildReference(Emotion emotion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: emotion.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emotion.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text('Образец: ${emotion.nameRu}',
              style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  /// Раскрытие правильного ответа: круглое фото эмоции
  /// с той же цветовой матрицей, что используется в карточках
  /// модуля 1 — единый визуальный язык.
  Widget _buildPhotoReveal(Emotion emotion) {
    return Column(
      children: [
        Text(
          isCorrect
              ? 'Вот как выглядит ${emotion.nameRu}:'
              : 'Правильный ответ — ${emotion.nameRu}:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        Center(
          // Размер фото берём из контекста — на планшете крупнее,
          // но не разрастается до неестественных размеров.
          child: SizedBox(
            width: context.maxChoiceCardSize,
            height: context.maxChoiceCardSize,
            child: ClipOval(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.764, 0.215, 0.022, 0, 8,
                  0.064, 0.914, 0.022, 0, 8,
                  0.064, 0.215, 0.721, 0, 8,
                  0,     0,     0,     1, 0,
                ]),
                child: Image.asset(
                  emotion.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: emotion.color,
                    child: Center(
                      child: Text(emotion.emoji,
                          style: TextStyle(
                              fontSize: context.maxChoiceCardSize * 0.33)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Строка выбора части лица: подпись и две кнопки-варианта.
  ///
  /// Цветовая логика:
  /// - **до ответа**: выбранный вариант — оранжевый акцент.
  /// - **после ответа**: правильный — зелёный (всегда), неправильный
  ///   выбранный — красный, остальные — нейтральные.
  ///
  /// [onSelect] null означает «после ответа» — взаимодействие
  /// заблокировано на уровне GestureDetector.
  Widget _buildPartRow({
    required String label,
    required List<_TextOption> options,
    required String? selectedId,
    required void Function(String)? onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: options.map((opt) {
            final selected = opt.id == selectedId;
            Color borderCol =
                selected ? AppTheme.accent : const Color(0xFFD4E5F7);
            Color bgCol =
                selected ? AppTheme.accentLight : AppTheme.bgPrimary;
            Color textCol =
                selected ? AppTheme.accent : AppTheme.textPrimary;

            if (answered) {
              if (opt.isCorrect) {
                borderCol = AppTheme.green;
                bgCol = AppTheme.greenLight;
                textCol = const Color(0xFF2A7A4A);
              } else if (opt.id == selectedId) {
                borderCol = AppTheme.errorText;
                bgCol = AppTheme.errorSoft;
                textCol = AppTheme.errorText;
              }
            }

            return Expanded(
              child: GestureDetector(
                onTap: onSelect != null ? () => onSelect(opt.id) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 6),
                  decoration: BoxDecoration(
                    color: bgCol,
                    border: Border.all(
                      color: borderCol,
                      width: selected ? 2.5 : 1.5,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    opt.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: textCol,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
