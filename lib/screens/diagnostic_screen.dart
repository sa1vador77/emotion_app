import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/emotion.dart';
import '../models/profile_model.dart';
import '../models/diagnostic_model.dart';
import '../models/progress_model.dart';
import '../data/diagnostic_tasks.dart';
import '../services/sound_service.dart';
import '../widgets/common_widgets.dart';

/// Экран прохождения диагностической батареи.
///
/// Используется в двух фазах исследования — `pre` (до обучения)
/// и `post` (после), различающихся только заголовком и тем,
/// куда вести по завершении.
///
/// Батарея состоит из двух методик, предъявляемых блоками:
/// 18 заданий «Эмоциональные лица» (фото) + 6 «Социальные истории»
/// (текст ситуации) = 24 задания, все с 4 вариантами.
///
/// Ключевое отличие от обучающих модулей:
/// - **Нет подсказок** — кот-помощник только повторяет вопрос.
/// - **Нет адаптивной сложности** — фиксированная батарея.
/// - **Нет повторного входа** — сессия должна быть пройдена
///   целиком, иначе результат не сохраняется.
/// - **Состояние не использует ModuleTaskMixin** — слишком
///   отличается логика (нет прогресса модулей, нет «следующего
///   задания после перерыва»).
///
/// После завершения pre-диагностики устанавливается стартовая
/// сложность обучающих модулей через
/// [ProgressModel.seedDifficultyFromAccuracy], чтобы первое
/// занятие проходило на адекватном уровне.
class DiagnosticScreen extends StatefulWidget {
  /// Фаза: `pre` (констатирующий этап) или `post` (контрольный).
  /// Передаётся через GoRouter параметр `/:phase`.
  final String phase;
  const DiagnosticScreen({super.key, required this.phase});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final _sound = SoundService();
  final _rng = Random();

  int _taskIndex = 0;
  String? _selectedId;
  bool _answered = false;
  DateTime _taskStart = DateTime.now();

  /// Длительность acknowledgment-окна между тапом ребёнка и
  /// автоматическим переходом к следующему заданию.
  ///
  /// За это время:
  /// - выбранная карточка остаётся в полном цвете, остальные мягко
  ///   приглушаются (опасить-фейд) — нейтральный визуальный маркер
  ///   «выбор зарегистрирован»;
  /// - звучит мягкий `transition.wav` (тот же звук, что между
  ///   обучающими экранами — методологически нейтрален, без
  ///   эмоциональной окраски правильно/неправильно).
  ///
  /// 500мс — компромисс: достаточно, чтобы ребёнок с РАС успел
  /// зафиксировать «нажал → услышал → увидел» в стабильном ритме,
  /// но не настолько долго, чтобы поток терял темп. План задачи #9
  /// предлагал ~300мс — увеличено до 500 для младшего школьного
  /// возраста с РАС (по обсуждению методики, ASD-дружелюбные
  /// тайминги длиннее «нейротипичных» референсов).
  static const Duration _ackDuration = Duration(milliseconds: 500);

  /// Накапливаемый список ответов — будет сохранён как
  /// [DiagnosticSession] при завершении.
  final List<DiagnosticAnswer> _answers = [];

  /// Перемешанные варианты ответа для текущего задания.
  /// Пересоздаётся при переходе к следующему заданию.
  late List<Emotion> _shuffledChoices;

  /// Выбранная форма заданий (A или B) — зависит от фазы и
  /// `participantId`, см. [getDiagnosticTasks]. Фиксируется в
  /// [initState], дальше не меняется.
  late List<DiagnosticTask> _formTasks;

  /// Полный список заданий в перемешанном порядке. Фиксируется
  /// в [initState] и больше не меняется — порядок остаётся
  /// стабильным при перестройках UI.
  late List<DiagnosticTask> _shuffledTasks;

  @override
  void initState() {
    super.initState();
    // Контрбалансировка форм: при чётном hash participantId
    // pre=A/post=B, при нечётном — наоборот. Детерминированно,
    // повторный вход в ту же фазу даёт ту же форму.
    final profileId = context.read<ProfileModel>().currentProfileId;
    _formTasks = getDiagnosticTasks(
      phase: widget.phase,
      participantId: profileId,
    );
    // Две методики предъявляются блоками: сначала все «лица», затем все
    // «социальные истории». Интерливинг (нет двух одинаковых эмоций
    // подряд) применяется внутри каждого блока отдельно — смешивать
    // фото и тексты в одном потоке методически нежелательно.
    final faces = _formTasks
        .where((t) => t.measure == DiagnosticMeasure.faces)
        .toList();
    final stories = _formTasks
        .where((t) => t.measure == DiagnosticMeasure.stories)
        .toList();
    _shuffledTasks = [
      ..._buildShuffledTasks(faces),
      ..._buildShuffledTasks(stories),
    ];
    _shuffleChoices();
  }

  /// Строит порядок заданий с **интерливингом** — двух одинаковых
  /// эмоций подряд быть не должно.
  ///
  /// Зачем: если две соседние задачи — про одну эмоцию, ребёнок
  /// получает «ритм» (правильный ответ в прошлый раз = тот же
  /// ответ сейчас), что искажает измерение реального уровня
  /// распознавания.
  ///
  /// Алгоритм:
  /// 1. Случайно перемешиваем весь список.
  /// 2. Идём слева направо, и если соседи совпадают по эмоции —
  ///    ищем впереди задачу с другой эмоцией и меняем местами.
  ///
  /// Жадный алгоритм не гарантирует идеальной альтернации, но
  /// для 6 заданий с 6 разными эмоциями он работает корректно
  /// почти всегда.
  List<DiagnosticTask> _buildShuffledTasks(List<DiagnosticTask> source) {
    final tasks = List<DiagnosticTask>.from(source);
    tasks.shuffle(_rng);

    for (int i = 1; i < tasks.length; i++) {
      if (tasks[i].targetEmotionId == tasks[i - 1].targetEmotionId) {
        // Ищем впереди задание с другой эмоцией и свопаем.
        for (int j = i + 1; j < tasks.length; j++) {
          if (tasks[j].targetEmotionId != tasks[i - 1].targetEmotionId) {
            final tmp = tasks[i];
            tasks[i] = tasks[j];
            tasks[j] = tmp;
            break;
          }
        }
      }
    }
    return tasks;
  }

  DiagnosticTask get _current => _shuffledTasks[_taskIndex];
  Emotion get _targetEmotion => EmotionData.getById(_current.targetEmotionId);

  String get _phaseTitle =>
      widget.phase == 'pre' ? 'Диагностика: до' : 'Диагностика: после';

  /// Перемешивает варианты ответа, чтобы правильный не оказывался
  /// в одной и той же позиции (например, всегда левый верхний).
  /// Без этого ребёнок мог бы «обучиться» позиции, а не эмоции.
  void _shuffleChoices() {
    _shuffledChoices = _current.choiceIds
        .map((id) => EmotionData.getById(id))
        .toList()
      ..shuffle(_rng);
  }

  /// Регистрирует ответ в диагностике.
  ///
  /// В отличие от обучающих модулей, здесь не используется
  /// [ProgressModel] — результаты диагностики хранятся отдельно
  /// в [DiagnosticModel], потому что их назначение принципиально
  /// иное (измерение, а не обучение).
  ///
  /// **Принципиально нет feedback о правильности.** Звук всегда
  /// нейтральный (`playTransition`), карточки не подсвечиваются
  /// зелёным/красным, не показывается FeedbackBanner / EmotionInfoCard.
  /// Иначе диагностика превращается в обучение: ребёнок узнаёт
  /// правильный ответ и подстраивает следующие ответы под него
  /// (особенно если post-тест следует через час обучения и память
  /// о картинках свежа). Кроме того, асимметрия положительного
  /// подкрепления «правильно» искусственно «штрафует» детей,
  /// которые честно угадывали — что снижает валидность теста.
  void _onChoiceTap(String emotionId) {
    if (_answered) return;

    final correct = emotionId == _current.targetEmotionId;
    final ms = DateTime.now().difference(_taskStart).inMilliseconds;

    _answers.add(DiagnosticAnswer(
      emotionId: _current.targetEmotionId,
      selectedId: emotionId,
      isCorrect: correct,
      reactionTimeMs: ms,
      measure: _current.measure.name,
      timestamp: DateTime.now(),
    ));

    setState(() {
      _selectedId = emotionId;
      _answered = true;
    });

    // Нейтральный звук «принято» — тот же transition.wav, что
    // звучит между обычными экранами приложения. Без эмоциональной
    // окраски правильно/неправильно.
    _sound.playTransition();

    // Авто-переход после [_ackDuration]. mounted-проверка обязательна:
    // пользователь мог нажать «назад» и подтвердить выход за это
    // время — тогда _nextTask на disposed-виджете уронит приложение.
    Future.delayed(_ackDuration, () {
      if (mounted) _nextTask();
    });
  }

  /// Переход к следующему заданию или завершение сессии.
  ///
  /// При завершении:
  /// 1. Сохраняем [DiagnosticSession] со всеми ответами.
  /// 2. Для pre-фазы — задаём стартовую сложность модулей
  ///    исходя из точности диагностики (адаптация под уровень
  ///    ребёнка).
  /// 3. Pre → переход на экран результата (ребёнок видит свою
  ///    оценку и переходит к обучению).
  ///    Post → переход на handoff (передача планшета взрослому).
  Future<void> _nextTask() async {
    if (_taskIndex + 1 >= _shuffledTasks.length) {
      final profileId = context.read<ProfileModel>().currentProfileId;
      final diagModel = context.read<DiagnosticModel>();
      final session = DiagnosticSession(
        phase: widget.phase,
        date: DateTime.now(),
        answers: _answers,
        participantId: profileId,
      );
      await diagModel.saveSession(session);
      _sound.playSuccess();
      if (mounted) {
        if (widget.phase == 'pre') {
          context.read<ProgressModel>().seedDifficultyFromAccuracy(session.accuracy);
          context.pushReplacement('/diagnostic_result',
              extra: {'session': session, 'phase': widget.phase});
        } else {
          context.pushReplacement('/handoff');
        }
      }
      return;
    }

    setState(() {
      _taskIndex++;
      _selectedId = null;
      _answered = false;
      _taskStart = DateTime.now();
    });
    _shuffleChoices();
    // Звук перехода уже сыграли при тапе на ответ (как acknowledgment)
    // — повторно здесь не нужен, иначе двойной щелчок на каждое задание.
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetEmotion;

    return Scaffold(
      appBar: AppBar(
        // Кастомная кнопка «назад» с подтверждением — выход
        // в середине диагностики теряет результаты, ребёнку
        // и педагогу нужно явное предупреждение.
        leading: IconButton(
          icon: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          onPressed: () => _confirmExit(context),
        ),
        title: Text(_phaseTitle),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter, vertical: 8),
          child: Column(
            children: [
              ModuleProgressBar(
                current: _taskIndex + 1,
                total: _shuffledTasks.length,
              ),
              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        // Кот произносит вопрос задания — без
                        // подсказок об эмоции (диагностический формат).
                        // Вопрос остаётся виден всю задачу (а не
                        // прячется после ответа, как в обучающих
                        // модулях): post-answer экран ничего не
                        // показывает, и пустота сверху смотрелась бы
                        // странно во время короткого ack-окна.
                        HelperCat(
                          message: _current.question,
                          animate: true,
                        ),
                        const SizedBox(height: 10),

                        if (_current.measure == DiagnosticMeasure.stories)
                          _buildStoryStimulus(_current.storyText ?? '')
                        else
                          _buildStimulusImage(target, _current.imagePath ?? ''),
                        const SizedBox(height: 10),

                        // Сетка 2×2 кнопок-вариантов. childAspectRatio: 1.9
                        // даёт более «весомые» кнопки — после удаления
                        // post-answer блока (feedback/info/next) под ними
                        // освободилось место, и крупный таргет удобнее
                        // для тапа ребёнком с РАС, чем узкая полоска.
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.9,
                          ),
                          itemCount: _shuffledChoices.length,
                          itemBuilder: (context, i) =>
                              _buildAnswerButton(context, _shuffledChoices[i]),
                        ),
                        // Никаких FeedbackBanner / EmotionInfoCard /
                        // NextButton — это раскрывало бы правильный
                        // ответ и превращало диагностику в обучение
                        // (см. док-комментарий к _onChoiceTap).
                        // Переход к следующей задаче автоматический
                        // через [_ackDuration] после тапа.
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

  /// Стимульное изображение — то, что ребёнок распознаёт.
  /// Использует диагностическое фото (не обучающее) — это важно,
  /// потому что обучение могло «запомнить» конкретное лицо.
  ///
  /// Путь приходит из [DiagnosticTask.imagePath] — каждая задача
  /// владеет своим стимулом, так что 3 задания на одну эмоцию
  /// используют разные фото (измерение обобщения, а не запоминания).
  ///
  /// Размер адаптивный: на телефонах ≈210dp, на планспетах ≈300dp.
  /// После удаления post-answer блока (feedback/info/next) внизу
  /// освободилось пространство — поднял фото с 130/200, чтобы лицо
  /// было крупным и хорошо читаемым (ключевой стимул диагностики).
  Widget _buildStimulusImage(Emotion emotion, String imagePath) {
    final size = context.isTablet ? 300.0 : 210.0;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: emotion.color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.3), width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        // Та же цветовая матрица, что в обучающих карточках —
        // единый визуальный язык + сенсорное смягчение фото.
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.764, 0.215, 0.022, 0, 8,
            0.064, 0.914, 0.022, 0, 8,
            0.064, 0.215, 0.721, 0, 8,
            0,     0,     0,     1, 0,
          ]),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(emotion.emoji,
                  style: TextStyle(fontSize: size * 0.55)),
            ),
          ),
        ),
      ),
    ).animate().scale(
      begin: const Offset(0.85, 0.85),
      end: const Offset(1.0, 1.0),
      duration: 300.ms,
      curve: Curves.easeOut,
    );
  }

  /// Стимул методики «Социальные истории» — текст ситуации в
  /// карточке. Без фото героя: диагностика не должна давать лишних
  /// визуальных подсказок, а единый текстово-эмодзи формат ответа
  /// (как у faces) держит две методики сравнимыми.
  Widget _buildStoryStimulus(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
            color: AppTheme.blue.withValues(alpha: 0.2), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📖', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  /// Кнопка-ответ в диагностике — текстовая, без картинки.
  /// Это намеренное отличие от обучающих модулей: диагностика
  /// не должна давать дополнительных визуальных подсказок,
  /// которые упростили бы задачу.
  ///
  /// Состояния — только нейтральные, **без раскрытия правильности**:
  /// - до ответа: обычная карточка, полная непрозрачность;
  /// - выбранная после тапа: blue-обводка чуть толще + полная
  ///   непрозрачность — визуальное подтверждение, что выбор учтён;
  /// - остальные после тапа: opacity 0.35 — мягко «уходят»,
  ///   подчёркивая выбор пользователя, но не намекая на верность.
  ///
  /// `Flexible` + `TextOverflow.ellipsis` защищают от выхода
  /// длинного слова («Отвращение») за границы кнопки.
  Widget _buildAnswerButton(BuildContext context, Emotion emotion) {
    final isSelected = _answered && emotion.id == _selectedId;
    final isFaded = _answered && !isSelected;

    return GestureDetector(
      // После ответа повторные тапы не реагируют — defence-in-depth
      // вдобавок к флагу `_answered` в [_onChoiceTap].
      onTap: _answered ? null : () => _onChoiceTap(emotion.id),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isFaded ? 0.35 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppTheme.bgPrimary,
            border: Border.all(
              color:
                  isSelected ? AppTheme.blue : const Color(0xFFD4E5F7),
              width: isSelected ? 2.5 : 2,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          // Column вместо Row: эмодзи сверху крупно, подпись снизу —
          // при childAspectRatio 1.9 кнопки достаточно высокие, чтобы
          // вместить две строки, и таргет визуально более «карточный»
          // (легче выбрать ребёнку с РАС, ориентируясь на крупный
          // эмодзи).
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emotion.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  emotion.nameRu,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Подтверждение выхода — показывается при нажатии «назад»
  /// в процессе диагностики. Без этой защиты ребёнок может
  /// случайно прервать сессию, и педагог потеряет ценные данные.
  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Прервать диагностику?'),
        content: const Text('Результаты этой сессии не будут сохранены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Продолжить'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); context.pop(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorText),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
