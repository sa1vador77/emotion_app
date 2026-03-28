import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_model.dart';

/// Один ответ в диагностической сессии.
///
/// Фиксирует не только правильность, но и выбранный вариант
/// (`selectedId`) — это важно для качественного анализа: какие
/// эмоции ребёнок путает между собой (матрица смешения).
class DiagnosticAnswer {
  final String emotionId;

  /// ID эмоции, которую выбрал ребёнок.
  /// Совпадение с [emotionId] = правильный ответ.
  final String selectedId;

  /// Производное от сравнения [emotionId] и [selectedId].
  /// Дублируется для скорости вычислений в агрегатах.
  final bool isCorrect;

  /// Время от показа задания до клика по варианту, в миллисекундах.
  /// Один из ключевых показателей в исследовании — снижение
  /// латентности означает автоматизацию распознавания.
  final int reactionTimeMs;

  /// Методика задания: `'faces'` (распознавание по фото) или
  /// `'stories'` (понимание по ситуации). Хранится строкой, чтобы
  /// модель не зависела от data-слоя (`DiagnosticMeasure`).
  /// Старые сессии без поля читаются как `'faces'` (миграция:
  /// до введения социальных историй вся диагностика была по лицам).
  final String measure;

  /// Момент ответа. Используется для построения хронологии
  /// и проверки длительности всей сессии.
  final DateTime timestamp;

  DiagnosticAnswer({
    required this.emotionId,
    required this.selectedId,
    required this.isCorrect,
    required this.reactionTimeMs,
    required this.timestamp,
    this.measure = 'faces',
  });

  /// Сериализация в JSON для хранения в [SharedPreferences]
  /// и CSV-экспорта.
  Map<String, dynamic> toJson() => {
    'emotionId': emotionId,
    'selectedId': selectedId,
    'isCorrect': isCorrect,
    'reactionTimeMs': reactionTimeMs,
    'measure': measure,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Десериализация из JSON. `measure` с fallback на `'faces'`
  /// для сессий, записанных до введения социальных историй.
  factory DiagnosticAnswer.fromJson(Map<String, dynamic> j) => DiagnosticAnswer(
    emotionId: j['emotionId'],
    selectedId: j['selectedId'],
    isCorrect: j['isCorrect'],
    reactionTimeMs: j['reactionTimeMs'],
    measure: (j['measure'] as String?) ?? 'faces',
    timestamp: DateTime.parse(j['timestamp']),
  );
}

/// Одна диагностическая сессия — серия ответов в одну фазу
/// (`pre` — до обучения, `post` — после).
///
/// В рамках исследования каждый ребёнок проходит обе фазы,
/// и сравнение их результатов даёт основной материал для
/// статистической проверки гипотезы об эффективности обучения
/// (T-критерий Вилкоксона).
class DiagnosticSession {
  /// Фаза: `pre` (констатирующий этап) или `post` (контрольный).
  final String phase;

  /// Дата прохождения. Используется в аналитике и CSV.
  final DateTime date;

  /// Все ответы сессии в порядке предъявления.
  final List<DiagnosticAnswer> answers;

  /// ID профиля участника. Может быть `null` для старых сессий,
  /// записанных до введения системы профилей — для них в экспорт
  /// подставляется `participant_1`.
  final String? participantId;

  DiagnosticSession({
    required this.phase,
    required this.date,
    required this.answers,
    this.participantId,
  });

  /// Ответы методики «Эмоциональные лица» (faces). Перцептивный
  /// компонент — основной для адаптивной сложности и сравнения.
  List<DiagnosticAnswer> get _faceAnswers =>
      answers.where((a) => a.measure == 'faces').toList();

  /// Ответы методики «Социальные истории» (stories) — контекстный
  /// компонент.
  List<DiagnosticAnswer> get _storyAnswers =>
      answers.where((a) => a.measure == 'stories').toList();

  /// Точность по методике «Эмоциональные лица» (перцептивный
  /// компонент). Это основная метрика сессии: на ней строится
  /// сравнение pre/post и сидирование сложности. Старые сессии без
  /// поля `measure` целиком считаются faces, поэтому значение для
  /// них не меняется.
  double get accuracy => _accuracyOf(_faceAnswers);

  /// Точность по методике «Социальные истории» (контекстный компонент).
  double get storiesAccuracy => _accuracyOf(_storyAnswers);

  double _accuracyOf(List<DiagnosticAnswer> list) {
    if (list.isEmpty) return 0.0;
    return list.where((a) => a.isCorrect).length / list.length;
  }

  /// Среднее время реакции по методике «Эмоциональные лица», мс.
  double get avgReactionMs => _avgRtOf(_faceAnswers);

  /// Среднее время реакции по методике «Социальные истории», мс.
  double get storiesAvgReactionMs => _avgRtOf(_storyAnswers);

  double _avgRtOf(List<DiagnosticAnswer> list) {
    if (list.isEmpty) return 0.0;
    return list.map((a) => a.reactionTimeMs).reduce((a, b) => a + b) /
        list.length;
  }

  /// Точность распознавания одной конкретной эмоции по фото
  /// (методика «Эмоциональные лица»). Возвращает 0.0 при отсутствии
  /// faces-ответов на эту эмоцию.
  double accuracyForEmotion(String emotionId) {
    final relevant =
        _faceAnswers.where((a) => a.emotionId == emotionId).toList();
    if (relevant.isEmpty) return 0.0;
    return relevant.where((a) => a.isCorrect).length / relevant.length;
  }

  /// Среднее время реакции на одну эмоцию по фото, мс
  /// (методика «Эмоциональные лица»). 0.0 при отсутствии ответов.
  /// Нужно для поэмоционной динамики RT (Таблица 5.3.4 ВКР).
  double avgReactionForEmotion(String emotionId) {
    final relevant =
        _faceAnswers.where((a) => a.emotionId == emotionId).toList();
    return _avgRtOf(relevant);
  }

  /// Сырые счётчики «верно / всего» — нужны для критерия Мак-Немара
  /// и для выражения результата в любой балльной шкале (0–18 по лицам,
  /// 0–6 по историям). Per-emotion счётчики не выгружаются отдельно:
  /// они восстанавливаются из `accuracyForEmotion × <число заданий>`.
  int get facesCorrect => _faceAnswers.where((a) => a.isCorrect).length;
  int get facesTotal => _faceAnswers.length;
  int get storiesCorrect => _storyAnswers.where((a) => a.isCorrect).length;
  int get storiesTotal => _storyAnswers.length;

  /// Уникальные ID эмоций, встретившиеся в сессии. Используется
  /// для построения карты «эмоция → точность».
  List<String> get emotionIds =>
      answers.map((a) => a.emotionId).toSet().toList();

  Map<String, dynamic> toJson() => {
    'phase': phase,
    'date': date.toIso8601String(),
    'participantId': participantId,
    'answers': answers.map((a) => a.toJson()).toList(),
  };

  factory DiagnosticSession.fromJson(Map<String, dynamic> j) =>
      DiagnosticSession(
        phase: j['phase'],
        date: DateTime.parse(j['date']),
        participantId: j['participantId'],
        answers: (j['answers'] as List)
            .map((a) => DiagnosticAnswer.fromJson(a))
            .toList(),
      );
}

/// Хранилище и экспорт диагностических сессий участника.
///
/// Параллельно с [ProgressModel] поддерживает разделение по
/// профилям через префикс ключей. Кроме хранения сессий, отвечает
/// за два формата CSV-экспорта:
/// - **детальный** (одна строка на ответ — для качественного анализа);
/// - **сводный** (одна строка на участника — для T-критерия).
class DiagnosticModel extends ChangeNotifier {
  String _prefix = '';
  List<DiagnosticSession> _sessions = [];

  /// Все сессии текущего профиля (в порядке записи).
  List<DiagnosticSession> get sessions => _sessions;

  /// Последняя сессия фазы «до обучения» (если есть).
  /// Берётся именно последняя на случай повторного прохождения.
  DiagnosticSession? get preSession =>
      _sessions.where((s) => s.phase == 'pre').lastOrNull;

  /// Последняя сессия фазы «после обучения» (если есть).
  DiagnosticSession? get postSession =>
      _sessions.where((s) => s.phase == 'post').lastOrNull;

  bool get hasPreTest => preSession != null;

  bool get hasPostTest => postSession != null;

  bool get hasBothTests => hasPreTest && hasPostTest;

  /// Загружает сессии из [SharedPreferences] по текущему префиксу.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('${_prefix}diagnostic_sessions');
    if (json != null) {
      final list = jsonDecode(json) as List;
      _sessions = list.map((j) => DiagnosticSession.fromJson(j)).toList();
    } else {
      _sessions = [];
    }
    notifyListeners();
  }

  Future<void> loadForProfile(String profileId) async {
    _prefix = 'profile_${profileId}_';
    await load();
  }

  Future<void> saveSession(DiagnosticSession session) async {
    _sessions.add(session);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_prefix}diagnostic_sessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// Детальный CSV: одна строка на каждый ответ.
  ///
  /// Колонки: `participant_id, phase, date, trial_number,
  /// emotion_id, selected_id, is_correct, reaction_time_ms`.
  ///
  /// Подходит для качественного анализа (матрица смешения,
  /// динамика внутри сессии) и для импорта в SPSS/R.
  String exportCsv({ParticipantGroup group = ParticipantGroup.experimental}) {
    final buffer = StringBuffer();
    buffer.writeln(
      'participant_id,group,phase,date,trial_number,measure,emotion_id,'
      'selected_id,is_correct,reaction_time_ms',
    );

    for (final session in _sessions) {
      for (var i = 0; i < session.answers.length; i++) {
        final a = session.answers[i];
        final pid = session.participantId ?? 'participant_1';
        final date = session.date.toIso8601String().substring(0, 10);
        buffer.writeln(
          '$pid,${group.name},${session.phase},$date,${i + 1},${a.measure},'
          '${a.emotionId},${a.selectedId},${a.isCorrect ? 1 : 0},'
          '${a.reactionTimeMs}',
        );
      }
    }

    return buffer.toString();
  }

  /// Порядок эмоций в поэмоционных колонках всех CSV — единый
  /// источник правды для acc- и rt-колонок.
  static const List<String> _emotionOrder = [
    'joy', 'sadness', 'anger', 'fear', 'surprise', 'disgust'
  ];

  /// Хвост заголовка сводного CSV (после идентификатора участника).
  /// Общий для [exportSummaryCsv] и [exportAllProfilesSummaryCsv] —
  /// инвариант «4 формы в синхроне».
  static String _summaryHeaderTail() => [
        'pre_accuracy', 'post_accuracy',
        'pre_avg_rt_ms', 'post_avg_rt_ms',
        'pre_stories_accuracy', 'post_stories_accuracy',
        // Сырые счётчики (Мак-Немар, любая балльная шкала):
        'pre_faces_correct', 'pre_faces_total',
        'post_faces_correct', 'post_faces_total',
        'pre_stories_correct', 'pre_stories_total',
        'post_stories_correct', 'post_stories_total',
        ..._emotionOrder.map((e) => 'pre_${e}_acc'),
        ..._emotionOrder.map((e) => 'post_${e}_acc'),
        ..._emotionOrder.map((e) => 'pre_${e}_rt_ms'),
        ..._emotionOrder.map((e) => 'post_${e}_rt_ms'),
      ].join(',');

  /// Хвост строки сводного CSV по сессиям pre/post. Парный к
  /// [_summaryHeaderTail] — порядок ячеек обязан совпадать.
  static String _summaryRowTail(
      DiagnosticSession? pre, DiagnosticSession? post) {
    String f2(double? v) => (v ?? 0).toStringAsFixed(2);
    String f0(double? v) => (v ?? 0).toStringAsFixed(0);
    return [
      f2(pre?.accuracy), f2(post?.accuracy),
      f0(pre?.avgReactionMs), f0(post?.avgReactionMs),
      f2(pre?.storiesAccuracy), f2(post?.storiesAccuracy),
      '${pre?.facesCorrect ?? 0}', '${pre?.facesTotal ?? 0}',
      '${post?.facesCorrect ?? 0}', '${post?.facesTotal ?? 0}',
      '${pre?.storiesCorrect ?? 0}', '${pre?.storiesTotal ?? 0}',
      '${post?.storiesCorrect ?? 0}', '${post?.storiesTotal ?? 0}',
      ..._emotionOrder.map((e) => f2(pre?.accuracyForEmotion(e))),
      ..._emotionOrder.map((e) => f2(post?.accuracyForEmotion(e))),
      ..._emotionOrder.map((e) => f0(pre?.avgReactionForEmotion(e))),
      ..._emotionOrder.map((e) => f0(post?.avgReactionForEmotion(e))),
    ].join(',');
  }

  /// Сводный CSV: одна строка на участника с метриками до/после.
  ///
  /// Содержит точность и RT по двум методикам, сырые счётчики
  /// «верно/всего», точность и RT по каждой из 6 эмоций. Готовый
  /// формат для критериев Вилкоксона / Мак-Немара.
  String exportSummaryCsv(
      {ParticipantGroup group = ParticipantGroup.experimental}) {
    final buffer = StringBuffer();
    buffer.writeln('participant_id,group,${_summaryHeaderTail()}');

    // Все уникальные участники в сессиях — обычно один, но
    // схема поддерживает миграцию старых данных без profileId.
    final participants = _sessions
        .map((s) => s.participantId ?? 'participant_1')
        .toSet();

    for (final pid in participants) {
      final pre = _sessions
          .where((s) =>
              s.phase == 'pre' &&
              (s.participantId ?? 'participant_1') == pid)
          .lastOrNull;
      final post = _sessions
          .where((s) =>
              s.phase == 'post' &&
              (s.participantId ?? 'participant_1') == pid)
          .lastOrNull;

      buffer.writeln(
          '$pid,${group.name},${_summaryRowTail(pre, post)}');
    }

    return buffer.toString();
  }

  /// Детальный CSV по **всем профилям** на устройстве. Статический
  /// метод — работает напрямую с [SharedPreferences] без необходимости
  /// загружать каждый профиль в память.
  ///
  /// Используется педагогом, который ведёт группу детей и хочет
  /// получить общий датасет для статистики.
  static Future<String> exportAllProfilesCsv(
      List<ParticipantProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final buffer = StringBuffer();
    buffer.writeln(
      'participant_id,participant_name,group,phase,date,trial_number,measure,'
      'emotion_id,selected_id,is_correct,reaction_time_ms',
    );
    for (final profile in profiles) {
      final json =
          prefs.getString('profile_${profile.id}_diagnostic_sessions');
      if (json == null) continue;
      final sessions = (jsonDecode(json) as List)
          .map((j) => DiagnosticSession.fromJson(j))
          .toList();
      for (final session in sessions) {
        for (var i = 0; i < session.answers.length; i++) {
          final a = session.answers[i];
          final date = session.date.toIso8601String().substring(0, 10);
          buffer.writeln(
            '${profile.id},${profile.name},${profile.group.name},'
            '${session.phase},$date,${i + 1},${a.measure},'
            '${a.emotionId},${a.selectedId},${a.isCorrect ? 1 : 0},'
            '${a.reactionTimeMs}',
          );
        }
      }
    }
    return buffer.toString();
  }

  /// Сводный CSV по всем профилям — основной файл для статистики
  /// выборки. Колонки идентичны [exportSummaryCsv] плюс имя участника.
  static Future<String> exportAllProfilesSummaryCsv(
      List<ParticipantProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final buffer = StringBuffer();
    buffer.writeln(
        'participant_id,participant_name,group,${_summaryHeaderTail()}');
    for (final profile in profiles) {
      final json =
          prefs.getString('profile_${profile.id}_diagnostic_sessions');
      if (json == null) continue;
      final sessions = (jsonDecode(json) as List)
          .map((j) => DiagnosticSession.fromJson(j))
          .toList();
      final pre = sessions.where((s) => s.phase == 'pre').lastOrNull;
      final post = sessions.where((s) => s.phase == 'post').lastOrNull;
      buffer.writeln(
          '${profile.id},${profile.name},${profile.group.name},'
          '${_summaryRowTail(pre, post)}');
    }
    return buffer.toString();
  }

  /// Строит матрицу путаницы по сессиям текущего профиля.
  ///
  /// Возвращает вложенную мапу: внешний ключ — `targetId` (правильная
  /// эмоция), внутренний — `selectedId` (что выбрал ребёнок),
  /// значение — счётчик. Диагональ (target == selected) = правильные
  /// ответы, всё остальное — ошибки.
  ///
  /// [phase] — фильтр по этапу:
  /// - `null` → агрегат по всем сессиям (default);
  /// - `'pre'` → только констатирующий этап;
  /// - `'post'` → только контрольный.
  ///
  /// Если несколько сессий одной фазы (повторное прохождение) —
  /// учитываются все: матрица суммируется как по индивидуальным
  /// ответам, а не по «последней попытке». Это сохраняет всю
  /// информацию об ошибках, не теряя историю.
  Map<String, Map<String, int>> confusionMatrix({String? phase}) {
    final matrix = <String, Map<String, int>>{};
    for (final session in _sessions) {
      if (phase != null && session.phase != phase) continue;
      for (final a in session.answers) {
        final row = matrix.putIfAbsent(a.emotionId, () => {});
        row[a.selectedId] = (row[a.selectedId] ?? 0) + 1;
      }
    }
    return matrix;
  }

  /// Удаляет все диагностические сессии текущего профиля.
  /// Используется в настройках при «Очистить диагностику».
  Future<void> clearAll() async {
    _sessions.clear();
    await _persist();
    notifyListeners();
  }
}
