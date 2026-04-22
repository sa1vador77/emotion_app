import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';
import '../models/progress_model.dart';
import '../models/session_timer_model.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Базовый mixin для экранов обучающих модулей 1, 2 и 3.
///
/// Общая логика трёх обучающих модулей: серия заданий, фиксация
/// ответа/времени реакции, переход на награду и восстановление
/// позиции при повторном входе. Экраны добавляют только UI и
/// подготовку конкретного задания.
///
/// **Состояние** (`taskIndex`, `answered`, `isCorrect`,
/// `taskStartTime`) хранится как поля mixin — это удобно для
/// использования через `widget.taskIndex`, но требует осторожности
/// при изменении: всегда через [setState] или предоставленные методы.
mixin ModuleTaskMixin<T extends StatefulWidget> on State<T> {
  final sound = SoundService();

  int taskIndex = 0;

  /// True, если на текущее задание уже дан ответ — блокирует
  /// повторные нажатия и показывает обратную связь.
  bool answered = false;

  /// Был ли последний ответ правильным.
  bool isCorrect = false;

  /// Момент показа текущего задания — нужен для расчёта времени
  /// реакции. Обновляется при инициализации и при переходе к
  /// следующему заданию.
  DateTime taskStartTime = DateTime.now();

  /// ID текущего модуля. Устанавливается через [onModuleEntered]
  /// и используется в [dispose] для записи времени, проведённого
  /// в модуле, в [ProgressModel].
  String? _moduleId;

  /// Момент входа на экран модуля. На выходе вычисляется дельта
  /// до now() и инкрементируется в `progress.addTimeToModule`.
  DateTime? _moduleEnterTime;

  /// Захваченная ссылка на [ProgressModel] — нужна в [dispose],
  /// где `context.read` уже ненадёжен (виджет покидает дерево,
  /// Provider может его не найти).
  ProgressModel? _progressRef;

  /// Хук «модуль открыт» — вызывается из initState каждого
  /// экрана модуля. Делает три вещи:
  ///  1. Сохраняет moduleId и время входа (для трекинга
  ///     времени в модуле в аналитике);
  ///  2. Захватывает ссылку на ProgressModel для использования
  ///     в dispose;
  ///  3. Стартует таймер сессии (если ещё не запущен).
  ///
  /// Раньше был отдельный метод `startSessionTimer()` без
  /// параметров — переименован и расширен, чтобы накопить
  /// время по модулям без нового лайфцикл-хука в каждом экране.
  void onModuleEntered(String moduleId) {
    _moduleId = moduleId;
    _moduleEnterTime = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _progressRef = context.read<ProgressModel>();
      context.read<SessionTimerModel>().start();
    });
  }

  /// Освобождение: фиксируем сколько времени экран жил, чтобы
  /// накопить в [ProgressModel.timeByModule]. Через `super.dispose()`
  /// в State-наследниках цепочка работает прозрачно — модулям
  /// не нужно явно вызывать addTimeToModule.
  ///
  /// Запись **откладывается на следующий фрейм** через
  /// `addPostFrameCallback`. Прямой вызов `addTimeToModule` здесь
  /// бы дёрнул `notifyListeners` → `_InheritedProviderScope`
  /// попытался бы `markNeedsBuild`, но widget tree уже залочен
  /// внутри `BuildOwner.lockState` во время unmount — assertion
  /// «widget tree was locked». Замер дельты (ms) делаем сейчас,
  /// чтобы он был точным, а запись — после фрейма.
  @override
  void dispose() {
    final ref = _progressRef;
    final id = _moduleId;
    final entered = _moduleEnterTime;
    if (ref != null && id != null && entered != null) {
      final ms = DateTime.now().difference(entered).inMilliseconds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.addTimeToModule(id, ms);
      });
    }
    super.dispose();
  }

  /// Регистрирует ответ ребёнка: запись в [ProgressModel] запускает
  /// адаптацию сложности и обновление матрицы путаницы.
  ///
  /// Параметр [selectedEmotionId] — что фактически выбрал ребёнок.
  /// Для модулей 1 и 3 — id тапнутой карточки. Для модуля 2
  /// («Конструктор») — id эмоции, которую ребёнок «собрал» из
  /// частей лица (определяется в экране модуля). При правильном
  /// ответе обычно совпадает с [emotionId].
  ///
  /// [onSetSelection] — опциональный колбэк для дополнительной
  /// мутации состояния внутри того же [setState] (например,
  /// запоминание выбранной эмоции для подсветки в UI).
  ///
  /// Защита от двойного нажатия: если [answered] уже true,
  /// метод выходит без действий.
  void submitAnswer({
    required String moduleId,
    required String emotionId,
    required String selectedEmotionId,
    required bool correct,
    VoidCallback? onSetSelection,
  }) {
    if (answered) return;
    final reactionMs = DateTime.now().difference(taskStartTime).inMilliseconds;
    context.read<ProgressModel>().recordAnswer(
      moduleId: moduleId,
      emotionId: emotionId,
      selectedEmotionId: selectedEmotionId,
      isCorrect: correct,
      reactionTimeMs: reactionMs,
    );
    setState(() {
      answered = true;
      isCorrect = correct;
      onSetSelection?.call();
    });
    correct ? sound.playCorrect() : sound.playWrong();
  }

  /// Сохраняет индекс текущего задания в SharedPreferences под
  /// профильным префиксом, чтобы при выходе и возврате ребёнок
  /// продолжал с того же места — критически важно для детей
  /// с РАС, которым тяжело даются «потери прогресса».
  Future<void> _saveTaskIndex(String moduleId, int index) async {
    final profileId = context.read<ProfileModel>().currentProfileId ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('profile_${profileId}_${moduleId}_task_index', index);
  }

  /// Удаляет сохранённый индекс — вызывается при завершении модуля,
  /// чтобы следующий запуск начался с первого задания.
  Future<void> _clearTaskIndex(String moduleId) async {
    final profileId = context.read<ProfileModel>().currentProfileId ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_${profileId}_${moduleId}_task_index');
  }

  /// Восстанавливает индекс задания при входе в модуль.
  ///
  /// Вызывается из [initState] через [addPostFrameCallback] —
  /// контекст должен быть готов для доступа к Provider.
  ///
  /// Защиты:
  /// - `saved > 0` — не восстанавливаем если ничего не сохранено;
  /// - `saved < maxTasks` — защита от ситуации, когда количество
  ///   заданий уменьшилось в обновлении приложения;
  /// - `mounted` — экран мог быть уничтожен до завершения async.
  ///
  /// [onRestored] вызывается после [setState] — экран использует
  /// его для подготовки нового задания (выбор дистракторов,
  /// перетасовка кнопок).
  Future<void> restoreTaskIndex({
    required String moduleId,
    required int maxTasks,
    required VoidCallback onRestored,
  }) async {
    final profileId = context.read<ProfileModel>().currentProfileId ?? '';
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('profile_${profileId}_${moduleId}_task_index') ?? 0;
    if (saved > 0 && saved < maxTasks && mounted) {
      setState(() {
        taskIndex = saved;
        answered = false;
        isCorrect = false;
        taskStartTime = DateTime.now();
      });
      onRestored();
    }
  }

  /// Переход к следующему заданию или завершение модуля.
  ///
  /// На последнем задании уходит на /reward через `pushReplacement`
  /// (чтобы «назад» не возвращал в завершённый модуль). [onPrepareNext]
  /// готовит UI следующего задания (дистракторы, перетасовка).
  void advanceTask({
    required String moduleId,
    required int taskCount,
    required VoidCallback onPrepareNext,
  }) {
    final progress = context.read<ProgressModel>();
    progress.updateModuleProgress(
        moduleId, ((taskIndex + 1) / taskCount).clamp(0.0, 1.0));

    if (taskIndex + 1 >= taskCount) {
      // Последнее задание — даём дойти до экрана награды независимо
      // от состояния таймера. Если время уже истекло, главное окно
      // /reward всё равно покажется (markExpired ниже разрулит выход
      // на /session_end после reward). Без этого ребёнок терял бы
      // награду за полностью завершённый модуль из-за нескольких
      // секунд опоздания таймера — это демотивирует.
      sound.playSuccess();
      _clearTaskIndex(moduleId);
      context.pushReplacement('/reward', extra: {'from': moduleId});
      return;
    }

    // Сессия истекла, но ребёнок только что завершил задание —
    // мягко выводим на /session_end вместо перехода к следующему.
    // Прогресс текущего ответа уже учтён выше (updateModuleProgress
    // + submitAnswer записал ответ в recordAnswer), так что ничего
    // не теряется.
    final timer = context.read<SessionTimerModel>();
    if (timer.pendingExpiration) {
      timer.markExpired();
      return;
    }

    setState(() {
      taskIndex++;
      answered = false;
      isCorrect = false;
      taskStartTime = DateTime.now();
    });
    _saveTaskIndex(moduleId, taskIndex);
    onPrepareNext();
    sound.playTransition();
  }

  /// Кастомная кнопка «назад» в стиле приложения — белый круглый
  /// фон с тенью и стрелкой. Используется во всех модулях, чтобы
  /// не дублировать декорацию.
  Widget buildBackButton() {
    return IconButton(
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.cardShadow,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
      onPressed: () => context.pop(),
    );
  }
}
