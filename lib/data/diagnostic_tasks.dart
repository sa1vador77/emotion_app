/// Какую способность измеряет задание.
///
/// - [faces] — распознавание эмоции по фотографии лица
///   (перцептивный компонент, методика «Эмоциональные лица»);
/// - [stories] — понимание эмоции по описанию ситуации
///   (контекстный компонент, методика «Социальные истории»).
///
/// [name] (`'faces'` / `'stories'`) — стабильный ключ для
/// `DiagnosticAnswer.measure` и колонки `measure` в детальном CSV.
enum DiagnosticMeasure { faces, stories }

/// Одно задание диагностической батареи.
///
/// Состав варианта выбора фиксирован: всегда 4 варианта,
/// один правильный плюс три дистрактора. Это обеспечивает
/// одинаковую вероятность случайного попадания (25%) во всех
/// заданиях и сопоставимость результатов между участниками
/// и между фазами «до/после».
///
/// Задание относится к одной из двух методик ([measure]):
/// - **faces** — владеет фото-стимулом [imagePath] (несколько задач
///   на эмоцию используют разные лица — измерение обобщения, а не
///   запоминания);
/// - **stories** — владеет текстом ситуации [storyText], без фото.
class DiagnosticTask {
  /// Уникальный ID задания (используется только для отладки).
  /// Префикс `formA_` / `formB_` показывает принадлежность к
  /// параллельной форме.
  final String id;

  final DiagnosticMeasure measure;

  final String targetEmotionId;

  /// Все варианты ответа. Первым идёт правильный, остальные —
  /// дистракторы. На экране порядок рандомизируется, чтобы
  /// исключить эффект позиции (выбор «по привычке» левого
  /// верхнего варианта).
  final List<String> choiceIds;

  /// Текст вопроса. Для faces одинаков для всех заданий; для stories
  /// адресован герою истории («Что чувствует Коля?»).
  final String question;

  /// Путь к стимульному фото (только для [DiagnosticMeasure.faces]).
  /// Конвенция имён: `assets/images/diagnostic/form_<a|b>/<emotion>_<N>.jpg`.
  /// `null` для story-заданий.
  final String? imagePath;

  /// Текст социальной ситуации (только для [DiagnosticMeasure.stories]).
  /// Нейтральный, описательный — без оценочных слов, чтобы не
  /// подсказывать эмоцию напрямую. `null` для faces-заданий.
  final String? storyText;

  const DiagnosticTask({
    required this.id,
    required this.targetEmotionId,
    required this.choiceIds,
    required this.question,
    this.measure = DiagnosticMeasure.faces,
    this.imagePath,
    this.storyText,
  });
}

/// Параллельная форма **A** диагностической батареи — 18 заданий
/// (по 3 на каждую эмоцию Экмана).
///
/// Стимулы взяты из датасета KDEF (Karolinska Directed Emotional
/// Faces, Lundqvist, Flykt & Öhman, 1998), участники #1–#18.
/// Гендерный баланс: 9 женщин + 9 мужчин (2Ж+1М / 1Ж+2М
/// чередуется по эмоциям).
///
/// Парная форма [diagnosticTasksFormB] использует **других**
/// участников KDEF (#19–#35), полностью независимый набор лиц.
/// Контрбалансировка между формами и фазами — в [getDiagnosticTasks].
const List<DiagnosticTask> diagnosticTasksFormA = [
  // ─── Радость (joy) ──────────────────────────────────────────────
  DiagnosticTask(
    id: 'formA_diag_joy_1',
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/joy_1.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_joy_2',
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/joy_2.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_joy_3',
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/joy_3.jpg',
  ),

  // ─── Грусть (sadness) ───────────────────────────────────────────
  DiagnosticTask(
    id: 'formA_diag_sadness_1',
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/sadness_1.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_sadness_2',
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/sadness_2.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_sadness_3',
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/sadness_3.jpg',
  ),

  // ─── Гнев (anger) ───────────────────────────────────────────────
  DiagnosticTask(
    id: 'formA_diag_anger_1',
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/anger_1.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_anger_2',
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/anger_2.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_anger_3',
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/anger_3.jpg',
  ),

  // ─── Страх (fear) ───────────────────────────────────────────────
  DiagnosticTask(
    id: 'formA_diag_fear_1',
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/fear_1.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_fear_2',
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/fear_2.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_fear_3',
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/fear_3.jpg',
  ),

  // ─── Удивление (surprise) ───────────────────────────────────────
  DiagnosticTask(
    id: 'formA_diag_surprise_1',
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/surprise_1.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_surprise_2',
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/surprise_2.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_surprise_3',
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/surprise_3.jpg',
  ),

  // ─── Отвращение (disgust) ───────────────────────────────────────
  DiagnosticTask(
    id: 'formA_diag_disgust_1',
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/disgust_1.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_disgust_2',
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/disgust_2.jpg',
  ),
  DiagnosticTask(
    id: 'formA_diag_disgust_3',
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_a/disgust_3.jpg',
  ),
];

/// Параллельная форма **B** — психометрически эквивалентна
/// [diagnosticTasksFormA] (те же эмоции, те же дистракторы,
/// тот же гендерный баланс), но с **другими** актёрами KDEF
/// (участники #3, #19–#35; для удивления #20, #3, #24 после
/// замены неудачно похожих на страх).
///
/// Зачем существуют две формы: устранить эффект научения тесту
/// (test-retest learning) при повторном измерении (pre/post).
/// Если бы pre и post показывали одни и те же фото, любое
/// улучшение можно было бы объяснить тем, что ребёнок запомнил
/// правильные ответы, а не научился распознавать эмоции.
const List<DiagnosticTask> diagnosticTasksFormB = [
  // ─── Радость (joy) ──────────────────────────────────────────────
  DiagnosticTask(
    id: 'formB_diag_joy_1',
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/joy_1.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_joy_2',
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/joy_2.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_joy_3',
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/joy_3.jpg',
  ),

  // ─── Грусть (sadness) ───────────────────────────────────────────
  DiagnosticTask(
    id: 'formB_diag_sadness_1',
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/sadness_1.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_sadness_2',
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/sadness_2.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_sadness_3',
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/sadness_3.jpg',
  ),

  // ─── Гнев (anger) ───────────────────────────────────────────────
  DiagnosticTask(
    id: 'formB_diag_anger_1',
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/anger_1.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_anger_2',
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/anger_2.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_anger_3',
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/anger_3.jpg',
  ),

  // ─── Страх (fear) ───────────────────────────────────────────────
  DiagnosticTask(
    id: 'formB_diag_fear_1',
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/fear_1.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_fear_2',
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/fear_2.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_fear_3',
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/fear_3.jpg',
  ),

  // ─── Удивление (surprise) ───────────────────────────────────────
  DiagnosticTask(
    id: 'formB_diag_surprise_1',
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/surprise_1.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_surprise_2',
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/surprise_2.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_surprise_3',
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/surprise_3.jpg',
  ),

  // ─── Отвращение (disgust) ───────────────────────────────────────
  DiagnosticTask(
    id: 'formB_diag_disgust_1',
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/disgust_1.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_disgust_2',
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/disgust_2.jpg',
  ),
  DiagnosticTask(
    id: 'formB_diag_disgust_3',
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует этот человек?',
    imagePath: 'assets/images/diagnostic/form_b/disgust_3.jpg',
  ),
];

/// Социальные истории, форма **A** — по одной ситуации на каждую
/// из 6 эмоций (методика «Социальные истории», контекстный компонент).
///
/// Дистракторы идентичны faces-форме той же эмоции (тот же принцип
/// мимической/семантической близости) — это держит две методики
/// психометрически сопоставимыми. Истории **новые**, не пересекаются
/// с обучающими в `module3Tasks` (иначе натренированный ребёнок узнавал
/// бы сюжет, а не понимал эмоцию — leak обучения в измерение).
///
/// Ответы — те же текстово-эмодзи карточки эмоций, что и в faces
/// (без фото героя): диагностика не должна давать лишних визуальных
/// подсказок, а единый формат ответа держит две методики сравнимыми.
const List<DiagnosticTask> socialStoryTasksFormA = [
  DiagnosticTask(
    id: 'formA_story_joy',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует Коля?',
    storyText: 'Коля давно копил на новый велосипед. '
        'Сегодня папа привёз велосипед домой.',
  ),
  DiagnosticTask(
    id: 'formA_story_sadness',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует Лена?',
    storyText: 'Лена нечаянно разбила любимую мамину чашку. '
        'Починить её уже нельзя.',
  ),
  DiagnosticTask(
    id: 'formA_story_anger',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует Дима?',
    storyText: 'Дима долго расставлял солдатиков по местам. '
        'Младший брат подбежал и раскидал их.',
  ),
  DiagnosticTask(
    id: 'formA_story_fear',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует Ира?',
    storyText: 'Вечером свет в комнате погас. '
        'Ира услышала странный шорох под кроватью.',
  ),
  DiagnosticTask(
    id: 'formA_story_surprise',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует Миша?',
    storyText: 'Миша открыл свой шкафчик в школе. '
        'Оттуда вдруг вылетел воздушный шарик.',
  ),
  DiagnosticTask(
    id: 'formA_story_disgust',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует Саша?',
    storyText: 'Саша откусил яблоко. '
        'Внутри он увидел половину червяка.',
  ),
];

/// Социальные истории, форма **B** — параллельна [socialStoryTasksFormA]
/// (те же эмоции, те же дистракторы), но с **другими** сюжетами.
/// Назначение A/B контрбалансируется так же, как у faces.
const List<DiagnosticTask> socialStoryTasksFormB = [
  DiagnosticTask(
    id: 'formB_story_joy',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'joy',
    choiceIds: ['joy', 'sadness', 'surprise', 'anger'],
    question: 'Что чувствует Маша?',
    storyText: 'Маша нарисовала рисунок. '
        'Учительница повесила его на стену в классе.',
  ),
  DiagnosticTask(
    id: 'formB_story_sadness',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'sadness',
    choiceIds: ['sadness', 'fear', 'anger', 'joy'],
    question: 'Что чувствует Вова?',
    storyText: 'У Вовы заболел щенок, и его увезли к врачу. '
        'Дома стало пусто и тихо.',
  ),
  DiagnosticTask(
    id: 'formB_story_anger',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'anger',
    choiceIds: ['anger', 'disgust', 'sadness', 'fear'],
    question: 'Что чувствует Петя?',
    storyText: 'Петя стоял в очереди за мороженым. '
        'Большой мальчик влез прямо перед ним.',
  ),
  DiagnosticTask(
    id: 'formB_story_fear',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'fear',
    choiceIds: ['fear', 'surprise', 'sadness', 'anger'],
    question: 'Что чувствует Гриша?',
    storyText: 'Гриша шёл по двору. '
        'Навстречу с громким лаем выбежала огромная собака.',
  ),
  DiagnosticTask(
    id: 'formB_story_surprise',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'surprise',
    choiceIds: ['surprise', 'fear', 'joy', 'anger'],
    question: 'Что чувствует Катя?',
    storyText: 'Катя вошла в тёмную комнату и включила свет. '
        'А там все кричат: «Сюрприз!»',
  ),
  DiagnosticTask(
    id: 'formB_story_disgust',
    measure: DiagnosticMeasure.stories,
    targetEmotionId: 'disgust',
    choiceIds: ['disgust', 'anger', 'sadness', 'surprise'],
    question: 'Что чувствует Настя?',
    storyText: 'Настя открыла холодильник. '
        'Оттуда пахнуло испорченным молоком.',
  ),
];

/// Возвращает диагностические задания для указанной фазы и участника
/// с **контрбалансировкой** между параллельными формами A/B.
///
/// Контрбалансировка устраняет confound «форма × фаза»:
/// если бы все дети проходили pre на форме A и post на форме B,
/// любая систематическая разница в трудности форм была бы ошибочно
/// приписана эффекту обучения. С контрбалансировкой половина детей
/// видит pre=A/post=B, другая половина — pre=B/post=A, и любая
/// разница форм усредняется по выборке.
///
/// Назначение детерминированное по чётности `participantId.hashCode`:
/// чётный → pre=A/post=B; нечётный → pre=B/post=A. Это гарантирует,
/// что повторный вход в ту же фазу даёт ту же форму (важно при
/// прерывании диагностики и возврате к ней).
///
/// Если `participantId == null` (старые сессии до системы профилей
/// или ошибка инициализации) — фолбэк на фиксированный порядок
/// A→B, что безопасно: гипотеза проверится, просто без защиты от
/// confound формы.
/// Включает обе методики: 18 faces-заданий + 6 story-заданий = 24.
/// Обе формы (faces и stories) выбираются по одному правилу
/// контрбалансировки, чтобы участник никогда не видел один и тот же
/// стимул в pre и post.
List<DiagnosticTask> getDiagnosticTasks({
  required String phase,
  String? participantId,
}) {
  final bool useFormA;
  if (participantId == null) {
    // Фолбэк: фиксированный A→B без защиты от confound формы.
    useFormA = phase == 'pre';
  } else {
    useFormA = participantId.hashCode.isEven == (phase == 'pre');
  }
  return useFormA
      ? [...diagnosticTasksFormA, ...socialStoryTasksFormA]
      : [...diagnosticTasksFormB, ...socialStoryTasksFormB];
}
