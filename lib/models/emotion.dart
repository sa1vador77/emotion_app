import 'package:flutter/material.dart';

/// Пол человека на фотографии эмоции.
///
/// Нужен для модуля 3 («Эмоции в ситуации»): когда история про
/// девочку Машу, на карточках ответа должны быть женские лица, а
/// не мужские. Это снимает «когнитивный шум» — ребёнок сравнивает
/// эмоции, а не отвлекается на несоответствие пола.
///
/// На модули 1 (распознавание по фото) и диагностику не влияет —
/// там пол не привязан к контексту.
enum Gender { male, female }

/// Одна фотография эмоции с указанием пола изображённого человека.
/// Несколько `EmotionPhoto` хранятся в [Emotion.photos] и
/// используются модулем 3 для подбора визуально-консистентного
/// набора карточек выбора.
class EmotionPhoto {
  final String path;
  final Gender gender;
  const EmotionPhoto({required this.path, required this.gender});
}

/// Модель одной базовой эмоции, используемая во всех модулях приложения.
///
/// Опирается на классификацию Пола Экмана (1972) — шесть универсальных
/// эмоций, распознаваемых независимо от культуры. Каждая эмоция
/// связана с набором фотографий (несколько вариантов лиц для разнообразия
/// заданий), отдельным фото для диагностики и описанием мимических
/// признаков для модуля «Конструктор лица».
class Emotion {
  /// Внутренний идентификатор эмоции — латиницей.
  /// Используется как ключ в [SharedPreferences] и в CSV-экспорте.
  final String id;

  final String nameRu;

  /// Эмодзи-символ эмоции. Применяется как fallback, если фото
  /// не загрузилось, и как маркер в кнопках выбора.
  final String emoji;

  /// Все фотографии эмоции с гендерной разметкой. Несколько разных
  /// лиц предотвращают заучивание конкретного человека вместо эмоции,
  /// а пол позволяет модулю 3 показывать карточки, соответствующие
  /// полу персонажа истории.
  final List<EmotionPhoto> photos;

  /// Краткое объяснение «когда возникает эта эмоция» — показывается
  /// после ответа как обучающий момент.
  final String description;

  /// Описание частей лица (брови, глаза, рот) для модуля 2
  /// «Конструктор лица».
  final FaceParts faceParts;

  /// Цвет-фон карточки эмоции. Помогает зрительно различать
  /// эмоции и создаёт эмоциональную ассоциацию (грусть — голубой,
  /// радость — жёлтый и т.д.).
  final Color color;

  const Emotion({
    required this.id,
    required this.nameRu,
    required this.emoji,
    required this.photos,
    required this.description,
    required this.faceParts,
    required this.color,
  });

  /// Путь к первой фотографии — точка входа для случаев, когда
  /// конкретный индекс не важен (например, photo reveal в модуле 2).
  String get imagePath => photos.first.path;

  /// Все пути единым плоским списком — для случаев, где гендер
  /// не важен (резерв на будущее).
  List<String> get imagePaths => photos.map((p) => p.path).toList();

  /// Возвращает путь к фотографии по индексу с цикличным перебором.
  /// Если у эмоции 3 фото, а индекс 5, вернётся `photos[2].path`
  /// (5 mod 3). Используется модулем 1 для разнообразия заданий
  /// (там пол не привязан к контексту, идёт перебор).
  String imagePathAt(int index) {
    if (photos.isEmpty) return imagePath;
    return photos[index % photos.length].path;
  }

  /// Возвращает индекс **первой** фотографии указанного пола в [photos].
  /// Используется модулем 3 для подбора визуально-консистентного
  /// набора карточек: все 4 карточки в задании одного пола, чтобы
  /// несовпадение пола героя истории и лиц на ответах не мешало
  /// сравнивать эмоции.
  ///
  /// Если фотографий нужного пола нет (неполный набор ассетов) —
  /// возвращает 0 (первая любого пола) как safe fallback.
  int photoIndexForGender(Gender g) {
    for (int i = 0; i < photos.length; i++) {
      if (photos[i].gender == g) return i;
    }
    return 0;
  }
}

/// Описание мимических признаков эмоции — используется модулем
/// «Конструктор лица» для обучения связыванию эмоции с конкретными
/// чертами (поднятые брови, опущенные уголки рта и т.д.).
class FaceParts {
  final String browsAsset;

  final String eyesAsset;

  final String mouthAsset;

  /// Текстовое описание положения бровей (для подсказок и аналитики).
  final String browsLabel;

  final String mouthLabel;

  const FaceParts({
    required this.browsAsset,
    required this.eyesAsset,
    required this.mouthAsset,
    required this.browsLabel,
    required this.mouthLabel,
  });
}

/// Каталог всех шести базовых эмоций — единственный источник
/// правды о наборе эмоций в приложении. Добавление новой эмоции
/// требует только дополнения списка [all].
class EmotionData {
  /// Шесть базовых эмоций по Экману. Порядок зафиксирован —
  /// он определяет порядок отображения в аналитике и CSV.
  ///
  /// **Гендерная разметка фото.** В каждом emotion перечислены
  /// 3 фотографии с пометкой [Gender]. Это используется модулем 3
  /// для подбора визуально-консистентного набора карточек
  /// (см. [Emotion.photoIndexForGender]).
  ///
  /// **При смене распределения** (например, оказалось 1m+2f
  /// вместо 2m+1f): поменяй здесь `Gender.male`/`Gender.female`
  /// у соответствующих фото И переименуй файлы в
  /// `assets/images/emotions/` по схеме `{эмоция}_{m|f}_{N}.jpg`,
  /// где N — порядковый номер внутри пола, начиная с 1.
  static const List<Emotion> all = [
    Emotion(
      id: 'joy',
      nameRu: 'Радость',
      emoji: '😄',
      photos: [
        EmotionPhoto(path: 'assets/images/emotions/joy_f_1.jpg', gender: Gender.female),
        EmotionPhoto(path: 'assets/images/emotions/joy_f_2.jpg', gender: Gender.female),
        EmotionPhoto(path: 'assets/images/emotions/joy_m_1.jpg', gender: Gender.male),
      ],
      description: 'Когда нам хорошо и приятно — мы радуемся!',
      color: Color(0xFFFFF3CD),
      faceParts: FaceParts(
        browsAsset: 'assets/images/face_parts/brows_joy.png',
        eyesAsset: 'assets/images/face_parts/eyes_joy.png',
        mouthAsset: 'assets/images/face_parts/mouth_joy.png',
        browsLabel: 'Брови приподняты, расслаблены',
        mouthLabel: 'Широкая улыбка',
      ),
    ),
    Emotion(
      id: 'sadness',
      nameRu: 'Грусть',
      emoji: '😢',
      photos: [
        EmotionPhoto(path: 'assets/images/emotions/sadness_m_1.jpg', gender: Gender.male),
        EmotionPhoto(path: 'assets/images/emotions/sadness_m_2.jpg', gender: Gender.male),
        EmotionPhoto(path: 'assets/images/emotions/sadness_f_1.jpg', gender: Gender.female),
      ],
      description: 'Когда нам плохо или мы потеряли что-то важное.',
      color: Color(0xFFDCEEFF),
      faceParts: FaceParts(
        browsAsset: 'assets/images/face_parts/brows_sadness.png',
        eyesAsset: 'assets/images/face_parts/eyes_sadness.png',
        mouthAsset: 'assets/images/face_parts/mouth_sadness.png',
        browsLabel: 'Брови сведены и опущены по краям',
        mouthLabel: 'Уголки рта опущены',
      ),
    ),
    Emotion(
      id: 'anger',
      nameRu: 'Гнев',
      emoji: '😠',
      photos: [
        EmotionPhoto(path: 'assets/images/emotions/anger_f_1.jpg', gender: Gender.female),
        EmotionPhoto(path: 'assets/images/emotions/anger_f_2.jpg', gender: Gender.female),
        EmotionPhoto(path: 'assets/images/emotions/anger_m_1.jpg', gender: Gender.male),
      ],
      description: 'Когда что-то кажется несправедливым или мешает нам.',
      color: Color(0xFFFFE5E5),
      faceParts: FaceParts(
        browsAsset: 'assets/images/face_parts/brows_anger.png',
        eyesAsset: 'assets/images/face_parts/eyes_anger.png',
        mouthAsset: 'assets/images/face_parts/mouth_anger.png',
        browsLabel: 'Брови нахмурены, сдвинуты к носу',
        mouthLabel: 'Сжатые губы или оскал',
      ),
    ),
    Emotion(
      id: 'fear',
      nameRu: 'Страх',
      emoji: '😨',
      photos: [
        EmotionPhoto(path: 'assets/images/emotions/fear_m_1.jpg', gender: Gender.male),
        EmotionPhoto(path: 'assets/images/emotions/fear_m_2.jpg', gender: Gender.male),
        EmotionPhoto(path: 'assets/images/emotions/fear_f_1.jpg', gender: Gender.female),
      ],
      description: 'Когда что-то кажется опасным или очень неожиданным.',
      color: Color(0xFFE8E5FF),
      faceParts: FaceParts(
        browsAsset: 'assets/images/face_parts/brows_fear.png',
        eyesAsset: 'assets/images/face_parts/eyes_fear.png',
        mouthAsset: 'assets/images/face_parts/mouth_fear.png',
        browsLabel: 'Брови подняты и сведены вместе',
        mouthLabel: 'Рот приоткрыт',
      ),
    ),
    Emotion(
      id: 'surprise',
      nameRu: 'Удивление',
      emoji: '😲',
      photos: [
        EmotionPhoto(path: 'assets/images/emotions/surprise_f_1.jpg', gender: Gender.female),
        EmotionPhoto(path: 'assets/images/emotions/surprise_f_2.jpg', gender: Gender.female),
        EmotionPhoto(path: 'assets/images/emotions/surprise_m_1.jpg', gender: Gender.male),
      ],
      description: 'Когда происходит что-то неожиданное и новое.',
      color: Color(0xFFE5FFF0),
      faceParts: FaceParts(
        browsAsset: 'assets/images/face_parts/brows_surprise.png',
        eyesAsset: 'assets/images/face_parts/eyes_surprise.png',
        mouthAsset: 'assets/images/face_parts/mouth_surprise.png',
        browsLabel: 'Брови высоко подняты',
        mouthLabel: 'Рот широко открыт',
      ),
    ),
    Emotion(
      id: 'disgust',
      nameRu: 'Отвращение',
      emoji: '🤢',
      photos: [
        EmotionPhoto(path: 'assets/images/emotions/disgust_m_1.jpg', gender: Gender.male),
        EmotionPhoto(path: 'assets/images/emotions/disgust_m_2.jpg', gender: Gender.male),
        EmotionPhoto(path: 'assets/images/emotions/disgust_f_1.jpg', gender: Gender.female),
      ],
      description: 'Когда что-то кажется очень неприятным.',
      color: Color(0xFFEEFFE5),
      faceParts: FaceParts(
        browsAsset: 'assets/images/face_parts/brows_disgust.png',
        eyesAsset: 'assets/images/face_parts/eyes_disgust.png',
        mouthAsset: 'assets/images/face_parts/mouth_disgust.png',
        browsLabel: 'Одна бровь приподнята',
        mouthLabel: 'Верхняя губа приподнята, нос сморщен',
      ),
    ),
  ];

  /// Возвращает эмоцию по строковому идентификатору.
  /// Выбрасывает [StateError], если эмоция не найдена —
  /// это сигнал об ошибке в коде (опечатка в id), не runtime-ситуация.
  static Emotion getById(String id) =>
      all.firstWhere((e) => e.id == id);
}
