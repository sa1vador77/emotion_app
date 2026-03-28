import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Состояние прогресса одного участника по обучающим модулям.
///
/// Хранит и обновляет:
/// - прогресс прохождения каждого модуля (0.0–1.0);
/// - точность распознавания по каждой эмоции;
/// - время реакции (для последних 50 ответов в целом и 30 на модуль);
/// - адаптивную сложность каждого модуля (1–5);
/// - журнал активности по дням;
/// - набор завершённых модулей.
///
/// Все данные сохраняются в [SharedPreferences] под префиксом
/// `profile_{id}_*`, чтобы поддерживать несколько участников
/// независимо. После [loadForProfile] все операции автоматически
/// пишутся в нужный профиль.
class ProgressModel extends ChangeNotifier {
  /// Префикс ключей в [SharedPreferences], содержащий ID профиля.
  /// Пустая строка означает «без профиля» (старая схема, оставлена
  /// для обратной совместимости).
  String _prefix = '';

  /// Прогресс каждого модуля как доля выполнения (0.0–1.0).
  /// Не растёт автоматически — обновляется явно из экранов модулей.
  Map<String, double> _moduleProgress = {
    'module1': 0.0,
    'module2': 0.0,
    'module3': 0.0,
  };
  Map<String, double> get moduleProgress => _moduleProgress;

  /// Среднее по всем модулям — общий процент прохождения курса.
  double get totalProgress {
    final sum = _moduleProgress.values.reduce((a, b) => a + b);
    return sum / _moduleProgress.length;
  }

  /// Счётчики правильных ответов по каждой эмоции (joy → 12, sadness → 8...).
  Map<String, int> _correctByEmotion = {};

  /// Счётчики всех попыток по каждой эмоции — знаменатель для точности.
  Map<String, int> _totalByEmotion = {};

  /// Счётчики правильных ответов в рамках **текущей попытки прохождения**
  /// модуля. Сбрасываются через [resetModule], когда ребёнок начинает
  /// модуль заново после завершения. Используются для подписи
  /// «5/7 · 71%» на главном экране — показывают результат в этой попытке,
  /// а не суммарный (для суммарного есть [_correctByEmotion]).
  Map<String, int> _correctByModule = {};

  /// Счётчики всех ответов в рамках текущей попытки прохождения модуля.
  Map<String, int> _totalByModule = {};

  int correctInModule(String moduleId) => _correctByModule[moduleId] ?? 0;

  /// Количество отвеченных заданий в текущей попытке модуля.
  int totalInModule(String moduleId) => _totalByModule[moduleId] ?? 0;

  /// True, если ребёнок уже доводил модуль до 100% хотя бы раз.
  /// При перезапуске через [resetModule] флаг снимается.
  bool isModuleCompleted(String moduleId) =>
      _completedModules.contains(moduleId);

  /// Кольцевой буфер последних 50 времён реакции по всем модулям.
  /// Старые значения отбрасываются, чтобы показатели отражали
  /// текущее состояние ребёнка, а не среднее за всю историю.
  List<int> _reactionTimes = [];

  /// Журнал активности по дням: ключ — дата `YYYY-MM-DD`,
  /// значение — количество ответов за этот день.
  Map<String, int> _sessionLog = {};

  /// Множество ID модулей, которые ребёнок прошёл полностью.
  /// Управляет доступностью наград и общим прогрессом.
  Set<String> _completedModules = {};

  /// True, если все три модуля завершены — открывается финальная награда.
  bool get allModulesCompleted =>
      _completedModules.containsAll(['module1', 'module2', 'module3']);

  /// Журнал активности (read-only) для отображения на графике
  /// «активность за 14 дней» в аналитике.
  Map<String, int> get sessionLog => Map.unmodifiable(_sessionLog);

  int get totalAnswers =>
      _totalByEmotion.values.fold(0, (sum, v) => sum + v);

  int get totalCorrect =>
      _correctByEmotion.values.fold(0, (sum, v) => sum + v);

  /// Среднее время реакции для последних 30 ответов в каждом модуле.
  /// Размер окна 30 (а не 50, как общее) даёт большую чувствительность
  /// к недавним изменениям при обучении внутри модуля.
  Map<String, double> _avgReactionByModule = {};
  Map<String, double> get avgReactionByModule =>
      Map.unmodifiable(_avgReactionByModule);

  /// Кольцевые буферы времени реакции на каждый модуль.
  Map<String, List<int>> _reactionByModule = {
    'module1': [], 'module2': [], 'module3': [],
  };

  /// Текущая адаптивная сложность каждого модуля (1–5).
  /// Влияет на количество вариантов выбора и доступные задания.
  Map<String, int> _difficulty = {
    'module1': 1,
    'module2': 1,
    'module3': 1,
  };
  Map<String, int> get difficulty => _difficulty;

  /// Окно последних 5 ответов на каждый модуль для адаптации
  /// сложности по методу лестницы (см. [_adaptDifficulty]).
  Map<String, List<bool>> _recentAnswers = {
    'module1': [],
    'module2': [],
    'module3': [],
  };

  /// Матрица путаницы по модулям обучения: для каждого модуля —
  /// `target → selected → счётчик`. Растёт кумулятивно за всё
  /// время прохождения, как [_correctByEmotion] (см. [resetModule] —
  /// тоже не сбрасывается при перезапуске модуля).
  ///
  /// Нужна для одноимённой карточки в аналитике: какие пары эмоций
  /// ребёнок путает в каждом модуле. Не дублирует
  /// [_correctByEmotion]/[_totalByEmotion]: те хранят только итоги,
  /// без направления ошибки.
  Map<String, Map<String, Map<String, int>>> _confusionByModule = {
    'module1': {},
    'module2': {},
    'module3': {},
  };

  /// Суммарное время, проведённое в каждом модуле, в миллисекундах.
  /// Накапливается через [addTimeToModule] при выходе из экрана
  /// модуля (dispose в [ModuleTaskMixin]). Кумулятивная метрика —
  /// не сбрасывается в [resetModule], только в [resetAll] — нужна
  /// педагогу для долгосрочной картины «какие модули ребёнок
  /// «не любит» (быстро уходит)».
  Map<String, int> _timeByModule = {
    'module1': 0,
    'module2': 0,
    'module3': 0,
  };
  Map<String, int> get timeByModule => Map.unmodifiable(_timeByModule);

  /// Максимальный возраст записей в [_sessionLog] при загрузке.
  /// Журнал старше этого порога обрезается — оставляем последние
  /// 30 дней, потому что в UI «Активность» показывается только 14,
  /// а небольшой запас полезен для возможных будущих графиков.
  /// Это же предохраняет хранилище от неограниченного роста.
  static const int _sessionLogMaxDays = 30;

  /// Загружает прогресс по текущему префиксу. Вызывать после
  /// установки префикса через [loadForProfile].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString('${_prefix}moduleProgress');
    if (progressJson != null) {
      final decoded = jsonDecode(progressJson) as Map<String, dynamic>;
      _moduleProgress = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } else {
      _moduleProgress = {'module1': 0.0, 'module2': 0.0, 'module3': 0.0};
    }

    final correctJson = prefs.getString('${_prefix}correctByEmotion');
    if (correctJson != null) {
      _correctByEmotion = Map<String, int>.from(jsonDecode(correctJson));
    } else {
      _correctByEmotion = {};
    }

    final totalJson = prefs.getString('${_prefix}totalByEmotion');
    if (totalJson != null) {
      _totalByEmotion = Map<String, int>.from(jsonDecode(totalJson));
    } else {
      _totalByEmotion = {};
    }

    final correctModJson = prefs.getString('${_prefix}correctByModule');
    if (correctModJson != null) {
      _correctByModule = Map<String, int>.from(jsonDecode(correctModJson));
    } else {
      _correctByModule = {};
    }

    final totalModJson = prefs.getString('${_prefix}totalByModule');
    if (totalModJson != null) {
      _totalByModule = Map<String, int>.from(jsonDecode(totalModJson));
    } else {
      _totalByModule = {};
    }

    final diffJson = prefs.getString('${_prefix}difficulty');
    if (diffJson != null) {
      final decoded = jsonDecode(diffJson) as Map<String, dynamic>;
      _difficulty = decoded.map((k, v) => MapEntry(k, v as int));
    } else {
      _difficulty = {'module1': 1, 'module2': 1, 'module3': 1};
    }

    final rtJson = prefs.getString('${_prefix}reactionTimes');
    if (rtJson != null) {
      _reactionTimes =
          (jsonDecode(rtJson) as List).map((e) => e as int).toList();
    } else {
      _reactionTimes = [];
    }

    final sessionLogJson = prefs.getString('${_prefix}sessionLog');
    if (sessionLogJson != null) {
      final decoded = Map<String, int>.from(jsonDecode(sessionLogJson));
      // Обрезаем записи старше [_sessionLogMaxDays]. Используем
      // лексикографическое сравнение ISO-дат (YYYY-MM-DD) — оно
      // совпадает с хронологическим.
      final cutoff = DateTime.now()
          .subtract(const Duration(days: _sessionLogMaxDays))
          .toIso8601String()
          .substring(0, 10);
      decoded.removeWhere((date, _) => date.compareTo(cutoff) < 0);
      _sessionLog = decoded;
    } else {
      _sessionLog = {};
    }

    final rbmJson = prefs.getString('${_prefix}reactionByModule');
    if (rbmJson != null) {
      final decoded = jsonDecode(rbmJson) as Map<String, dynamic>;
      _reactionByModule = decoded.map((k, v) =>
          MapEntry(k, (v as List).map((e) => e as int).toList()));
      // Дозаполняем ключи, которых могло не быть в старой записи.
      for (final id in ['module1', 'module2', 'module3']) {
        _reactionByModule.putIfAbsent(id, () => <int>[]);
      }
    } else {
      _reactionByModule = {'module1': [], 'module2': [], 'module3': []};
    }

    // [_avgReactionByModule] — производное от [_reactionByModule],
    // не персистится отдельно (storage-only-source-of-truth).
    _avgReactionByModule = {};
    for (final entry in _reactionByModule.entries) {
      if (entry.value.isNotEmpty) {
        _avgReactionByModule[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }

    final recentJson = prefs.getString('${_prefix}recentAnswers');
    if (recentJson != null) {
      final decoded = jsonDecode(recentJson) as Map<String, dynamic>;
      _recentAnswers = decoded.map((k, v) =>
          MapEntry(k, (v as List).map((e) => e as bool).toList()));
      for (final id in ['module1', 'module2', 'module3']) {
        _recentAnswers.putIfAbsent(id, () => <bool>[]);
      }
    } else {
      _recentAnswers = {'module1': [], 'module2': [], 'module3': []};
    }

    final completedJson = prefs.getString('${_prefix}completedModules');
    if (completedJson != null) {
      _completedModules = Set<String>.from(jsonDecode(completedJson) as List);
    } else {
      _completedModules = {};
    }

    final timeJson = prefs.getString('${_prefix}timeByModule');
    if (timeJson != null) {
      final decoded = Map<String, int>.from(jsonDecode(timeJson));
      // putIfAbsent: подстраховка для старых записей без какого-то
      // модуля — иначе при добавлении нового модуля счётчик не
      // существовал бы и портил агрегаты.
      for (final id in ['module1', 'module2', 'module3']) {
        decoded.putIfAbsent(id, () => 0);
      }
      _timeByModule = decoded;
    } else {
      _timeByModule = {'module1': 0, 'module2': 0, 'module3': 0};
    }

    final confusionJson = prefs.getString('${_prefix}confusionByModule');
    if (confusionJson != null) {
      final decoded = jsonDecode(confusionJson) as Map<String, dynamic>;
      _confusionByModule = decoded.map((mod, rows) {
        final rowsMap = (rows as Map<String, dynamic>).map((target, cols) {
          final colsMap = (cols as Map<String, dynamic>)
              .map((sel, count) => MapEntry(sel, count as int));
          return MapEntry(target, colsMap);
        });
        return MapEntry(mod, rowsMap);
      });
      for (final id in ['module1', 'module2', 'module3']) {
        _confusionByModule.putIfAbsent(id, () => {});
      }
    } else {
      _confusionByModule = {'module1': {}, 'module2': {}, 'module3': {}};
    }

    notifyListeners();
  }

  Future<void> loadForProfile(String profileId) async {
    _prefix = 'profile_${profileId}_';
    await load();
  }

  /// Атомарно сохраняет все персистентные поля в [SharedPreferences].
  /// Вызывается после каждого изменения состояния.
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}moduleProgress', jsonEncode(_moduleProgress));
    await prefs.setString('${_prefix}correctByEmotion', jsonEncode(_correctByEmotion));
    await prefs.setString('${_prefix}totalByEmotion', jsonEncode(_totalByEmotion));
    await prefs.setString('${_prefix}correctByModule', jsonEncode(_correctByModule));
    await prefs.setString('${_prefix}totalByModule', jsonEncode(_totalByModule));
    await prefs.setString('${_prefix}difficulty', jsonEncode(_difficulty));
    await prefs.setString(
        '${_prefix}completedModules', jsonEncode(_completedModules.toList()));
    await prefs.setString('${_prefix}reactionTimes', jsonEncode(_reactionTimes));
    await prefs.setString('${_prefix}sessionLog', jsonEncode(_sessionLog));
    await prefs.setString(
        '${_prefix}reactionByModule', jsonEncode(_reactionByModule));
    await prefs.setString(
        '${_prefix}recentAnswers', jsonEncode(_recentAnswers));
    await prefs.setString(
        '${_prefix}confusionByModule', jsonEncode(_confusionByModule));
    await prefs.setString(
        '${_prefix}timeByModule', jsonEncode(_timeByModule));
  }

  /// Прибавляет дельту времени к счётчику модуля.
  ///
  /// Вызывается из [ModuleTaskMixin.dispose] с миллисекундами от
  /// `onModuleEntered` до выхода с экрана. Кумулятивно: каждый заход
  /// плюсуется к предыдущему, чтобы было видно общее время, потраченное
  /// ребёнком на каждый модуль.
  ///
  /// Защита от отрицательных значений (если бы DateTime.now где-то
  /// откатился — теоретически возможно при смене часового пояса):
  /// `ms <= 0` игнорируется.
  void addTimeToModule(String moduleId, int ms) {
    if (ms <= 0) return;
    _timeByModule[moduleId] = (_timeByModule[moduleId] ?? 0) + ms;
    _save();
    notifyListeners();
  }

  /// Регистрирует один ответ ребёнка в обучающем задании.
  ///
  /// Обновляет четыре категории метрик одновременно:
  /// 1. **Точность** по эмоции (счётчики correct и total).
  /// 2. **Время реакции** в общий буфер и буфер модуля.
  /// 3. **Окно последних 5 ответов** для адаптации сложности.
  /// 4. **Матрица путаницы**: `confusionByModule[moduleId][target][selected]++`.
  ///
  /// Параметры:
  /// - [emotionId] — правильная (целевая) эмоция задания;
  /// - [selectedEmotionId] — что ребёнок фактически выбрал. Для
  ///   модулей 1 и 3 — id тапнутой карточки. Для модуля 2
  ///   («Конструктор») экран сам определяет, какую эмоцию ребёнок
  ///   «собрал» из выбранных частей лица (см. `module2_screen.dart`).
  ///   При правильном ответе всегда совпадает с [emotionId].
  /// - [reactionTimeMs] — время от показа задания до выбора,
  ///   измеряется в экране модуля.
  void recordAnswer({
    required String moduleId,
    required String emotionId,
    required String selectedEmotionId,
    required bool isCorrect,
    required int reactionTimeMs,
  }) {
    _totalByEmotion[emotionId] = (_totalByEmotion[emotionId] ?? 0) + 1;
    if (isCorrect) {
      _correctByEmotion[emotionId] = (_correctByEmotion[emotionId] ?? 0) + 1;
    }

    _totalByModule[moduleId] = (_totalByModule[moduleId] ?? 0) + 1;
    if (isCorrect) {
      _correctByModule[moduleId] = (_correctByModule[moduleId] ?? 0) + 1;
    }

    // Матрица путаницы: считаем все ответы, не только ошибки —
    // диагональ нужна для оценки общей точности и визуализации.
    final modMatrix = _confusionByModule.putIfAbsent(moduleId, () => {});
    final row = modMatrix.putIfAbsent(emotionId, () => {});
    row[selectedEmotionId] = (row[selectedEmotionId] ?? 0) + 1;

    _reactionTimes.add(reactionTimeMs);
    if (_reactionTimes.length > 50) _reactionTimes.removeAt(0);

    final mrt = _reactionByModule[moduleId] ??= [];
    mrt.add(reactionTimeMs);
    if (mrt.length > 30) mrt.removeAt(0);
    _avgReactionByModule[moduleId] =
        mrt.reduce((a, b) => a + b) / mrt.length;

    final window = _recentAnswers[moduleId]!;
    window.add(isCorrect);
    if (window.length > 5) window.removeAt(0);

    _adaptDifficulty(moduleId);

    // Счётчик ответов за сегодня для графика активности.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _sessionLog[today] = (_sessionLog[today] ?? 0) + 1;

    _save();
    notifyListeners();
  }

  /// Адаптирует сложность по **методу лестницы** (staircase method) —
  /// классический психофизический подход, обеспечивающий нахождение
  /// в зоне ближайшего развития ребёнка (~70–85% правильных).
  ///
  /// Правила:
  /// - точность > 85% → повышаем сложность (но не выше 5);
  /// - точность < 70% → понижаем (но не ниже 1);
  /// - в диапазоне 70–85% — оставляем как есть.
  ///
  /// Минимум 3 ответа в окне нужно для статистической достоверности
  /// решения об изменении.
  void _adaptDifficulty(String moduleId) {
    final window = _recentAnswers[moduleId]!;
    if (window.length < 3) return;

    final accuracy = window.where((a) => a).length / window.length;
    final current = _difficulty[moduleId]!;

    if (accuracy > 0.85 && current < 5) {
      _difficulty[moduleId] = current + 1;
    } else if (accuracy < 0.70 && current > 1) {
      _difficulty[moduleId] = current - 1;
    }
  }

  /// Возвращает количество вариантов выбора в задании
  /// в зависимости от текущей сложности модуля:
  /// сложность 1–2 → 2 варианта, 3–4 → 4, 5 → 6.
  /// Чем больше вариантов, тем сложнее правильно угадать случайно.
  int getChoiceCount(String moduleId) {
    final d = _difficulty[moduleId] ?? 1;
    if (d <= 2) return 2;
    if (d <= 4) return 4;
    return 6;
  }

  /// Обновляет прогресс модуля. Значение клампится в [0.0, 1.0]
  /// на случай ошибочного аргумента. При достижении 100% модуль
  /// добавляется в список завершённых.
  void updateModuleProgress(String moduleId, double value) {
    _moduleProgress[moduleId] = value.clamp(0.0, 1.0);
    if (value >= 1.0) _completedModules.add(moduleId);
    _save();
    notifyListeners();
  }

  /// Точность распознавания конкретной эмоции (0.0–1.0).
  /// Возвращает 0.0, если эмоция ещё не встречалась — чтобы
  /// избежать деления на ноль.
  double accuracyForEmotion(String emotionId) {
    final total = _totalByEmotion[emotionId] ?? 0;
    if (total == 0) return 0.0;
    final correct = _correctByEmotion[emotionId] ?? 0;
    return correct / total;
  }

  /// Список эмоций, отсортированный по возрастанию точности
  /// (худшие — первыми). Учитываются только эмоции с минимум 3
  /// ответами — иначе результат статистически недостоверен.
  /// Используется в карточке рекомендаций для педагога.
  List<MapEntry<String, double>> get weakEmotions {
    final entries = _totalByEmotion.keys
        .where((id) => (_totalByEmotion[id] ?? 0) >= 3)
        .map((id) => MapEntry(id, accuracyForEmotion(id)))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  /// Матрица путаницы для аналитики педагога.
  ///
  /// [moduleId] — фильтр: при `null` агрегирует по всем модулям
  /// (общая картина), при заданном id — только этот модуль.
  /// Возвращает копию (вложенные Map'ы тоже копируются), чтобы
  /// вызывающий код не мог случайно мутировать внутреннее состояние.
  Map<String, Map<String, int>> confusionMatrixForModule({String? moduleId}) {
    if (moduleId != null) {
      final src = _confusionByModule[moduleId] ?? const {};
      return {for (final e in src.entries) e.key: Map<String, int>.from(e.value)};
    }
    final agg = <String, Map<String, int>>{};
    for (final mod in _confusionByModule.values) {
      for (final row in mod.entries) {
        final dst = agg.putIfAbsent(row.key, () => {});
        for (final col in row.value.entries) {
          dst[col.key] = (dst[col.key] ?? 0) + col.value;
        }
      }
    }
    return agg;
  }

  double get avgReactionTime {
    if (_reactionTimes.isEmpty) return 0;
    return _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length;
  }

  /// Устанавливает стартовую сложность всех модулей, исходя из
  /// результатов предварительной диагностики.
  ///
  /// Это даёт более точное начало обучения: ребёнок, который уже
  /// справляется на 75%+, не будет тратить время на тривиальные
  /// задания первого уровня.
  ///
  /// Сопоставление:
  /// - ≥ 75% → уровень 4 (выше среднего),
  /// - ≥ 50% → 3 (средний),
  /// - ≥ 25% → 2 (ниже среднего),
  /// - иначе → 1 (лёгкий).
  void seedDifficultyFromAccuracy(double accuracy) {
    final level = accuracy >= 0.75
        ? 4
        : accuracy >= 0.50
            ? 3
            : accuracy >= 0.25
                ? 2
                : 1;
    _difficulty = {
      'module1': level,
      'module2': level,
      'module3': level,
    };
    _save();
    notifyListeners();
  }

  /// Сбрасывает весь прогресс участника. Используется кнопкой
  /// «Очистить статистику» в настройках педагога.
  /// Не трогает диагностику — она в [DiagnosticModel].
  Future<void> resetAll() async {
    _moduleProgress = {'module1': 0.0, 'module2': 0.0, 'module3': 0.0};
    _correctByEmotion = {};
    _totalByEmotion = {};
    _correctByModule = {};
    _totalByModule = {};
    _reactionTimes = [];
    _sessionLog = {};
    _difficulty = {'module1': 1, 'module2': 1, 'module3': 1};
    _recentAnswers = {'module1': [], 'module2': [], 'module3': []};
    _reactionByModule = {'module1': [], 'module2': [], 'module3': []};
    _avgReactionByModule = {};
    _completedModules = {};
    _confusionByModule = {'module1': {}, 'module2': {}, 'module3': {}};
    _timeByModule = {'module1': 0, 'module2': 0, 'module3': 0};
    await _save();
    notifyListeners();
  }

  /// Сбрасывает прогресс конкретного модуля для повторного прохождения.
  ///
  /// Вызывается из [ModuleRestartScreen], когда ребёнок выбирает
  /// «пройти снова» уже завершённый модуль. Что чистим:
  /// 1. Прогресс модуля → 0;
  /// 2. Удаляем из множества завершённых (иначе при следующем входе
  ///    снова сработает экран подтверждения);
  /// 3. Сбрасываем счётчики правильных/всего для **этого** модуля —
  ///    новая попытка считается с нуля;
  /// 4. Удаляем сохранённый `taskIndex` (формат ключа задан
  ///    в [ModuleTaskMixin._saveTaskIndex] — храним совместимо).
  ///
  /// Суммарную статистику по эмоциям ([_correctByEmotion]) намеренно
  /// не трогаем — она кумулятивная и нужна аналитике педагога.
  Future<void> resetModule(String moduleId) async {
    _moduleProgress[moduleId] = 0.0;
    _completedModules.remove(moduleId);
    _correctByModule[moduleId] = 0;
    _totalByModule[moduleId] = 0;
    await _save();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix${moduleId}_task_index');
    notifyListeners();
  }
}
