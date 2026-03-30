import '../models/emotion.dart' show Gender;

// ─────────────────────────────────────────────────────────────────────
// МОДУЛЬ 1 — «ЗНАКОМСТВО»: прямое распознавание эмоции на фото
// ─────────────────────────────────────────────────────────────────────

/// Одно задание модуля 1.
///
/// Ребёнку показывается фото человека с одной из 6 эмоций и набор
/// вариантов (2–6 в зависимости от текущей сложности). Нужно выбрать,
/// какая эмоция изображена.
class Module1Task {
  /// Уникальный ID задания, используется для логирования и отладки.
  final String id;

  /// Текст вопроса, который читает педагог или озвучивает приложение.
  /// Используются разные формулировки («Покажи где…», «Найди…»,
  /// «Кто здесь…»), чтобы ребёнок научился узнавать эмоцию вне
  /// зависимости от глагольной формы.
  final String question;

  final String targetEmotionId;

  /// Подсказка от кота-помощника. Содержит ключевые мимические
  /// признаки целевой эмоции — это обучающий момент даже когда
  /// ребёнок ещё не ответил.
  final String helperHint;

  /// Уровень сложности задания (1=лёгкий, 2=средний, 3=сложный).
  /// Адаптивный фильтр отбирает только задания, доступные на
  /// текущем уровне ребёнка (см. [ProgressModel.getChoiceCount]).
  final int difficultyLevel;

  /// Индекс фото в [Emotion.imagePaths] (0, 1 или 2). Разные фото
  /// для одной и той же эмоции предотвращают заучивание
  /// конкретного лица вместо эмоции — ключевой принцип валидной
  /// диагностики обобщения.
  final int imageIndex;

  const Module1Task({
    required this.id,
    required this.question,
    required this.targetEmotionId,
    required this.helperHint,
    this.difficultyLevel = 1,
    this.imageIndex = 0,
  });
}

/// Полный пул заданий модуля 1: 18 заданий (6 эмоций × 3 варианта фото).
///
/// Распределение по сложности неравномерное — простые эмоции
/// (радость, грусть) начинаются с уровня 1, более тонкие
/// (отвращение, страх) — со 2-3, чтобы первое знакомство
/// прошло успешно и сформировало положительный опыт.
const List<Module1Task> module1Tasks = [
  // ── РАДОСТЬ ─────────────────────────────────────────────────────
  Module1Task(
    id: 'm1_joy_1', imageIndex: 0, difficultyLevel: 1,
    question: 'Покажи, где РАДОСТЬ',
    targetEmotionId: 'joy',
    helperHint: 'Когда нам хорошо — мы улыбаемся! Ищи улыбку!',
  ),
  Module1Task(
    id: 'm1_joy_2', imageIndex: 1, difficultyLevel: 2,
    question: 'Найди РАДОСТНОЕ лицо',
    targetEmotionId: 'joy',
    helperHint: 'Радость — приподнятые щёки и широкая улыбка.',
  ),
  Module1Task(
    id: 'm1_joy_3', imageIndex: 2, difficultyLevel: 3,
    question: 'Кто здесь радуется?',
    targetEmotionId: 'joy',
    helperHint: 'Вспомни: при радости уголки рта тянутся вверх!',
  ),

  // ── ГРУСТЬ ──────────────────────────────────────────────────────
  Module1Task(
    id: 'm1_sad_1', imageIndex: 0, difficultyLevel: 1,
    question: 'Покажи, где ГРУСТЬ',
    targetEmotionId: 'sadness',
    helperHint: 'Грусть — уголки рта опущены вниз.',
  ),
  Module1Task(
    id: 'm1_sad_2', imageIndex: 1, difficultyLevel: 2,
    question: 'Найди ГРУСТНОЕ лицо',
    targetEmotionId: 'sadness',
    helperHint: 'При грусти брови сведены, взгляд опущен.',
  ),
  Module1Task(
    id: 'm1_sad_3', imageIndex: 2, difficultyLevel: 3,
    question: 'Кому здесь грустно?',
    targetEmotionId: 'sadness',
    helperHint: 'Грусть — человеку плохо или он потерял что-то важное.',
  ),

  // ── ГНЕВ (начинается с уровня 2 — сложнее для детей с РАС) ──────
  Module1Task(
    id: 'm1_ang_1', imageIndex: 0, difficultyLevel: 2,
    question: 'Покажи ГНЕВ',
    targetEmotionId: 'anger',
    helperHint: 'Гнев — брови нахмурены и сдвинуты к носу.',
  ),
  Module1Task(
    id: 'm1_ang_2', imageIndex: 1, difficultyLevel: 2,
    question: 'Найди СЕРДИТОЕ лицо',
    targetEmotionId: 'anger',
    helperHint: 'При гневе брови «сползают» вниз и сближаются.',
  ),
  Module1Task(
    id: 'm1_ang_3', imageIndex: 2, difficultyLevel: 3,
    question: 'Кто здесь сердится?',
    targetEmotionId: 'anger',
    helperHint: 'Гнев — человеку кажется, что что-то несправедливо.',
  ),

  // ── СТРАХ (часто путают с удивлением) ───────────────────────────
  Module1Task(
    id: 'm1_fear_1', imageIndex: 0, difficultyLevel: 2,
    question: 'Где здесь СТРАХ?',
    targetEmotionId: 'fear',
    helperHint: 'Страх — большие глаза, брови подняты и сведены!',
  ),
  Module1Task(
    id: 'm1_fear_2', imageIndex: 1, difficultyLevel: 3,
    question: 'Найди ИСПУГАННОЕ лицо',
    targetEmotionId: 'fear',
    helperHint: 'При страхе рот приоткрыт, глаза широко открыты.',
  ),
  Module1Task(
    id: 'm1_fear_3', imageIndex: 2, difficultyLevel: 3,
    question: 'Кому здесь страшно?',
    targetEmotionId: 'fear',
    helperHint: 'Страх и удивление похожи — но при страхе брови сведены вместе.',
  ),

  // ── УДИВЛЕНИЕ ───────────────────────────────────────────────────
  Module1Task(
    id: 'm1_sur_1', imageIndex: 0, difficultyLevel: 1,
    question: 'Найди УДИВЛЕНИЕ',
    targetEmotionId: 'surprise',
    helperHint: 'При удивлении брови высоко поднимаются, рот открывается!',
  ),
  Module1Task(
    id: 'm1_sur_2', imageIndex: 1, difficultyLevel: 2,
    question: 'Покажи УДИВЛЁННОЕ лицо',
    targetEmotionId: 'surprise',
    helperHint: 'Удивление — что-то неожиданное случилось!',
  ),
  Module1Task(
    id: 'm1_sur_3', imageIndex: 2, difficultyLevel: 3,
    question: 'Кто здесь удивляется?',
    targetEmotionId: 'surprise',
    helperHint: 'При удивлении брови высоко, рот округлён.',
  ),

  // ── ОТВРАЩЕНИЕ (самая сложная — все задания уровня 3) ───────────
  // Дети с РАС часто демонстрируют трудности именно с этой эмоцией,
  // потому что она реже встречается в социальном опыте.
  Module1Task(
    id: 'm1_dis_1', imageIndex: 0, difficultyLevel: 3,
    question: 'Найди ОТВРАЩЕНИЕ',
    targetEmotionId: 'disgust',
    helperHint: 'Отвращение — нос сморщен, верхняя губа приподнята.',
  ),
  Module1Task(
    id: 'm1_dis_2', imageIndex: 1, difficultyLevel: 3,
    question: 'Кому здесь что-то неприятно?',
    targetEmotionId: 'disgust',
    helperHint: 'При отвращении морщится нос и поднимается губа.',
  ),
  Module1Task(
    id: 'm1_dis_3', imageIndex: 2, difficultyLevel: 3,
    question: 'Покажи лицо с ОТВРАЩЕНИЕМ',
    targetEmotionId: 'disgust',
    helperHint: 'Отвращение — что-то очень неприятное.',
  ),
];

// ─────────────────────────────────────────────────────────────────────
// МОДУЛЬ 2 — «КОНСТРУКТОР»: сборка лица из бровей/глаз/рта
// ─────────────────────────────────────────────────────────────────────

/// Одно задание модуля 2.
///
/// Ребёнку даётся название эмоции, и нужно собрать соответствующее
/// лицо, выбрав правильные брови, глаза и рот из набора вариантов.
/// Это формирует **аналитическое** восприятие эмоции — понимание,
/// какие именно черты лица за неё отвечают.
class Module2Task {
  final String id;

  /// Целевая эмоция, лицо которой нужно собрать.
  final String targetEmotionId;

  final String question;

  final String helperHint;

  /// Показывать ли образец (готовое лицо) рядом для сравнения.
  /// На первом этапе показывается, на втором (закрепление) —
  /// убирается, и ребёнок должен опираться на запомненное.
  final bool showReference;

  final int difficultyLevel;

  const Module2Task({
    required this.id,
    required this.targetEmotionId,
    required this.question,
    required this.helperHint,
    this.showReference = true,
    this.difficultyLevel = 1,
  });
}

/// Задания модуля 2. Сначала идут варианты с образцом
/// (`showReference: true`) — для всех 6 эмоций. Затем — без
/// образца для наиболее освоенных эмоций, как закрепление.
const List<Module2Task> module2Tasks = [
  Module2Task(
    id: 'm2_joy_ref', targetEmotionId: 'joy',
    question: 'Собери лицо с РАДОСТЬЮ',
    helperHint: 'Смотри на образец и выбирай части лица!',
    showReference: true, difficultyLevel: 1,
  ),
  Module2Task(
    id: 'm2_sad_ref', targetEmotionId: 'sadness',
    question: 'Собери лицо с ГРУСТЬЮ',
    helperHint: 'Обрати внимание на положение бровей и рта.',
    showReference: true, difficultyLevel: 1,
  ),
  Module2Task(
    id: 'm2_ang_ref', targetEmotionId: 'anger',
    question: 'Собери лицо с ГНЕВОМ',
    helperHint: 'Посмотри как выглядят нахмуренные брови.',
    showReference: true, difficultyLevel: 2,
  ),
  Module2Task(
    id: 'm2_fear_ref', targetEmotionId: 'fear',
    question: 'Собери ИСПУГАННОЕ лицо',
    helperHint: 'Страх и удивление похожи — но есть отличие!',
    showReference: true, difficultyLevel: 2,
  ),
  Module2Task(
    id: 'm2_sur_ref', targetEmotionId: 'surprise',
    question: 'Собери лицо с УДИВЛЕНИЕМ',
    helperHint: 'При удивлении брови высоко, рот широко открыт.',
    showReference: true, difficultyLevel: 2,
  ),
  Module2Task(
    id: 'm2_dis_ref', targetEmotionId: 'disgust',
    question: 'Собери лицо с ОТВРАЩЕНИЕМ',
    helperHint: 'Нос сморщен, губа приподнята.',
    showReference: true, difficultyLevel: 3,
  ),

  // Фаза 2: без образца — закрепление по памяти
  Module2Task(
    id: 'm2_joy_noref', targetEmotionId: 'joy',
    question: 'Собери РАДОСТНОЕ лицо — без подсказки!',
    helperHint: 'Ты уже умеешь! Попробуй сам.',
    showReference: false, difficultyLevel: 2,
  ),
  Module2Task(
    id: 'm2_sad_noref', targetEmotionId: 'sadness',
    question: 'Собери ГРУСТНОЕ лицо — без подсказки!',
    helperHint: 'Вспомни: брови уголками вниз.',
    showReference: false, difficultyLevel: 2,
  ),
  Module2Task(
    id: 'm2_ang_noref', targetEmotionId: 'anger',
    question: 'Собери СЕРДИТОЕ лицо — без подсказки!',
    helperHint: 'Вспомни: брови нахмурены.',
    showReference: false, difficultyLevel: 3,
  ),
  Module2Task(
    id: 'm2_sur_noref', targetEmotionId: 'surprise',
    question: 'Собери УДИВЛЁННОЕ лицо — без подсказки!',
    helperHint: 'Вспомни: брови высоко, рот открыт.',
    showReference: false, difficultyLevel: 3,
  ),
];

// ─────────────────────────────────────────────────────────────────────
// МОДУЛЬ 3 — «ЭМОЦИИ В СИТУАЦИИ»: социальные истории
// ─────────────────────────────────────────────────────────────────────

/// Одно задание модуля 3, реализующее метод **социальных историй**
/// Кэрол Грей (Social Stories™).
///
/// Ребёнку рассказывается короткая история о персонаже в типовой
/// бытовой ситуации, и нужно определить, какую эмоцию должен
/// испытывать персонаж. Это самый сложный уровень — нет фотографии
/// лица, эмоцию надо вывести из контекста.
class Module3Task {
  final String id;

  /// Текст социальной истории. 2-4 коротких предложения. Стиль
  /// нейтральный, описательный — без оценочных слов, чтобы не
  /// подсказывать ответ напрямую.
  final String storyText;

  /// Вопрос «Что чувствует X?» — всегда формулируется через
  /// глагол «чувствует», чтобы ребёнок учился использовать
  /// эмоциональную лексику в правильной грамматической форме.
  final String question;

  final String targetEmotionId;

  /// Подсказка кота-помощника — указывает на ключевое слово или
  /// связь между событием и эмоцией.
  final String helperHint;

  /// Конкретный набор вариантов выбора для этого задания.
  /// В отличие от модуля 1, здесь варианты подбираются вручную
  /// для каждой истории — это позволяет включать или исключать
  /// близкие эмоции в зависимости от уровня сложности.
  final List<String> choiceEmotionIds;

  /// Пол героя истории. По нему модуль 3 подбирает фото
  /// соответствующего пола для всех 4 карточек выбора — чтобы
  /// несовпадение пола героя и лиц на ответах не отвлекало
  /// ребёнка от различения эмоций.
  final Gender characterGender;

  final int difficultyLevel;

  /// Дополнительный рефлексивный вопрос для обсуждения с педагогом
  /// после ответа (например, «Почему Ира испугалась?»). Развивает
  /// навык вербализации причинно-следственных связей.
  /// Опционален — у простых заданий его может не быть.
  final String? followUpQuestion;

  const Module3Task({
    required this.id,
    required this.storyText,
    required this.question,
    required this.targetEmotionId,
    required this.helperHint,
    required this.choiceEmotionIds,
    required this.characterGender,
    this.difficultyLevel = 1,
    this.followUpQuestion,
  });
}

/// 9 социальных историй разного уровня сложности.
/// Тематика: подарки, потеря, конфликт, неожиданность, страх,
/// успех, отвращение, день рождения, переезд друга — покрывает
/// типовой эмоциональный опыт ребёнка младшего школьного возраста.
const List<Module3Task> module3Tasks = [
  Module3Task(
    id: 'm3_gift',
    storyText:
        'У Маши день рождения. В коробке — кукла, '
        'о которой она давно мечтала.',
    question: 'Что чувствует Маша?',
    targetEmotionId: 'joy',
    helperHint: 'Получить долгожданный подарок — это приятно!',
    choiceEmotionIds: ['joy', 'sadness'],
    characterGender: Gender.female,
    difficultyLevel: 1,
  ),
  Module3Task(
    id: 'm3_toy_lost',
    storyText:
        'У Пети пропал любимый плюшевый мишка. '
        'Петя искал везде, но мишку нигде не нашёл.',
    question: 'Что чувствует Петя?',
    targetEmotionId: 'sadness',
    helperHint: 'Когда теряешь любимую вещь — это очень...',
    choiceEmotionIds: ['sadness', 'joy'],
    characterGender: Gender.male,
    difficultyLevel: 1,
  ),
  Module3Task(
    id: 'm3_rainbow',
    storyText:
        'После дождя Вова увидел в небе огромную яркую радугу. '
        'Такой большой он ещё никогда не видел!',
    question: 'Что чувствует Вова?',
    targetEmotionId: 'surprise',
    helperHint: 'Что-то неожиданное и новое вызывает...',
    choiceEmotionIds: ['surprise', 'sadness', 'joy', 'fear'],
    characterGender: Gender.male,
    difficultyLevel: 2,
  ),
  Module3Task(
    id: 'm3_quarrel',
    storyText:
        'Саша долго строил башню из кубиков. '
        'Вася подбежал и нарочно её сломал.',
    question: 'Что чувствует Саша?',
    targetEmotionId: 'anger',
    helperHint: 'Когда кто-то специально портит твою работу...',
    choiceEmotionIds: ['anger', 'joy', 'surprise', 'sadness'],
    characterGender: Gender.male,
    difficultyLevel: 2,
  ),
  Module3Task(
    id: 'm3_dark',
    storyText:
        'Ира одна дома. Вдруг погас свет, '
        'и за окном кто-то громко закричал.',
    question: 'Что чувствует Ира?',
    targetEmotionId: 'fear',
    helperHint: 'Темнота и неожиданные звуки могут вызвать...',
    choiceEmotionIds: ['fear', 'joy', 'sadness', 'anger'],
    characterGender: Gender.female,
    difficultyLevel: 3,
    followUpQuestion: 'Почему Ире стало страшно?',
  ),
  Module3Task(
    id: 'm3_homework',
    storyText:
        'Коля долго решал трудную задачу и наконец справился. '
        'Учительница поставила ему пятёрку.',
    question: 'Что чувствует Коля?',
    targetEmotionId: 'joy',
    helperHint: 'Когда стараешься и получается — это...',
    choiceEmotionIds: ['joy', 'anger', 'fear', 'sadness'],
    characterGender: Gender.male,
    difficultyLevel: 3,
    followUpQuestion: 'Почему Коля радуется?',
  ),
  Module3Task(
    id: 'm3_lunch',
    storyText:
        'В столовой Диме дали суп со странным неприятным запахом. '
        'Дима понюхал и отодвинул тарелку.',
    question: 'Что чувствует Дима?',
    targetEmotionId: 'disgust',
    helperHint: 'Когда что-то пахнет очень неприятно...',
    choiceEmotionIds: ['disgust', 'anger', 'sadness', 'fear'],
    characterGender: Gender.male,
    difficultyLevel: 3,
  ),
  Module3Task(
    id: 'm3_birthday',
    storyText:
        'Лена пришла в школу. Одноклассники вдруг все вместе '
        'закричали: «С днём рождения!»',
    question: 'Что чувствует Лена?',
    targetEmotionId: 'surprise',
    helperHint: 'Это было очень неожиданно для Лены!',
    choiceEmotionIds: ['surprise', 'fear', 'joy', 'anger'],
    characterGender: Gender.female,
    difficultyLevel: 2,
    followUpQuestion: 'Почему Лена удивилась?',
  ),
  Module3Task(
    id: 'm3_friend_left',
    storyText:
        'Лучший друг Миши переехал в другой город. '
        'Они больше не смогут играть вместе.',
    question: 'Что чувствует Миша?',
    targetEmotionId: 'sadness',
    helperHint: 'Когда расстаёшься с близким другом...',
    choiceEmotionIds: ['sadness', 'anger', 'surprise', 'joy'],
    characterGender: Gender.male,
    difficultyLevel: 2,
  ),
];
