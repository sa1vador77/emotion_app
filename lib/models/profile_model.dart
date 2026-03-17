import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Преднастроенные контрольные вопросы для восстановления PIN.
///
/// Ключ — стабильный ID, сохраняется в `SharedPreferences` под
/// `global_security_question`. Значение — текст для UI.
/// **Менять можно текст, но не ID** — иначе старые установки не
/// смогут отобразить свой вопрос (но восстановление всё равно
/// сработает, потому что проверка идёт по хэшу ответа).
///
/// 4 классических вопроса с устойчивыми во времени ответами —
/// педагог сможет вспомнить даже через год после задания.
const Map<String, String> kSecurityQuestions = {
  'q_mother_maiden': 'Девичья фамилия мамы?',
  'q_birth_city': 'В каком городе Вы родились?',
  'q_first_teacher': 'Имя первой учительницы?',
  'q_first_pet': 'Кличка первого домашнего животного?',
};

/// Нормализация ответа перед хэшированием.
///
/// Приводим к нижнему регистру и схлопываем пробельные участки —
/// «Москва » и «москва» должны давать один и тот же хэш.
/// Без этого пользователь не вспомнит свой ответ через год
/// из-за капитализации или лишнего пробела.
String _normalizeSecurityAnswer(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// SHA-256 от нормализованного ответа. Возвращает hex-строку.
/// Подсолить не нужно — это локальный, низкорисковый секрет
/// (защита от шурующего ребёнка, не от криптоатаки).
String hashSecurityAnswer(String raw) {
  final bytes = utf8.encode(_normalizeSecurityAnswer(raw));
  return sha256.convert(bytes).toString();
}

/// Группа участника в квазиэкспериментальном дизайне исследования.
///
/// - [experimental] — проходит обучающие модули между pre- и post-диагностикой;
/// - [control] — проходит только диагностику (pre и post) без обучения,
///   что даёт базу для межгруппового сравнения прироста (критерий
///   Манна-Уитни) и контроль над эффектом естественного развития /
///   повторного тестирования.
///
/// [name] (`'experimental'` / `'control'`) служит стабильным ключом
/// хранения и значением колонки `group` во всех CSV-экспортах.
enum ParticipantGroup {
  experimental,
  control;

  /// Человекочитаемая подпись для UI выбора группы.
  String get label => switch (this) {
        ParticipantGroup.experimental => 'Экспериментальная',
        ParticipantGroup.control => 'Контрольная',
      };

  /// Восстановление из ключа с fallback на [experimental] —
  /// старые профили без поля `group` читаются как экспериментальные
  /// (до введения групп всё устройство было «экспериментом»).
  static ParticipantGroup fromKey(String? key) =>
      key == 'control' ? ParticipantGroup.control : ParticipantGroup.experimental;
}

/// Палитра цветов для аватаров участников. Выбирается ребёнком
/// или педагогом при создании профиля и сохраняется как индекс.
/// Хранение по индексу (а не цвета напрямую) упрощает миграции
/// палитры — достаточно изменить массив.
const List<Color> kProfileColors = [
  Color(0xFF4A90D9),
  Color(0xFFFF8C42),
  Color(0xFF52C97A),
  Color(0xFF8B6FD4),
  Color(0xFFE74C3C),
  Color(0xFF1ABC9C),
  Color(0xFFF39C12),
  Color(0xFF2980B9),
];

/// Эмодзи-аватары, парные [kProfileColors]. Индекс цвета определяет
/// и аватар — это даёт автоматическую цветовую идентификацию
/// каждого животного и упрощает выбор для ребёнка.
const List<String> kProfileEmojis = ['🐱', '🐶', '🦊', '🐰', '🐻', '🐼', '🦁', '🐸'];

/// Профиль одного ребёнка-участника исследования.
///
/// Поддержка нескольких профилей нужна для использования одного
/// планшета в группе или семье (несколько детей). Все данные
/// прогресса и диагностики хранятся под префиксом `profile_{id}_`
/// в [SharedPreferences].
class ParticipantProfile {
  /// Уникальный идентификатор профиля. Формат: `p{timestamp}` —
  /// timestamp обеспечивает уникальность при создании двух профилей
  /// в одну секунду маловероятно, но обработка коллизий не нужна,
  /// так как ID генерируется только при создании.
  final String id;

  /// Имя, которое ввёл педагог/родитель при создании.
  /// Может быть как реальным именем, так и условным («Ребёнок 1»).
  final String name;

  /// Индекс в [kProfileColors] / [kProfileEmojis]. Mod-арифметика
  /// в геттерах [color] и [emoji] защищает от выхода за границы.
  final int colorIndex;

  /// Группа исследования. Назначается при создании профиля педагогом
  /// и определяет поток (обучение vs только диагностика) и колонку
  /// `group` в CSV. По умолчанию [ParticipantGroup.experimental].
  final ParticipantGroup group;

  const ParticipantProfile({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.group = ParticipantGroup.experimental,
  });

  /// Цвет аватара. Возвращает корректное значение даже если
  /// `colorIndex` больше длины палитры (циклический перебор).
  Color get color => kProfileColors[colorIndex % kProfileColors.length];

  String get emoji => kProfileEmojis[colorIndex % kProfileEmojis.length];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'group': group.name,
  };

  /// Десериализация из JSON. Защищена fallback'ом `?? 0`
  /// на случай повреждённых данных или миграции со старой схемы.
  /// Отсутствие `group` → [ParticipantGroup.experimental] (миграция).
  factory ParticipantProfile.fromJson(Map<String, dynamic> j) =>
      ParticipantProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: (j['colorIndex'] as int?) ?? 0,
        group: ParticipantGroup.fromKey(j['group'] as String?),
      );
}

/// Глобальное состояние профилей и настроек педагога/родителя.
///
/// Делит данные на две категории:
/// 1. **Профильные** (`profile_{id}_*` в [SharedPreferences]) —
///    онбординг, прогресс, диагностика. Привязаны к ребёнку.
/// 2. **Глобальные** (`global_*`) — PIN-код взрослого, факт
///    первоначальной настройки. Один для всего устройства.
///
/// Такое разделение позволяет переключаться между детьми, не
/// заставляя педагога заново вводить PIN.
class ProfileModel extends ChangeNotifier {
  List<ParticipantProfile> _profiles = [];
  String? _currentProfileId;
  bool _onboardingCompleted = false;
  bool _parentSetupDone = false;
  String? _pin;

  /// ID выбранного контрольного вопроса (ключ в [kSecurityQuestions]).
  /// `null` для установок, сделанных до введения механизма
  /// восстановления PIN — для них в UI показывается миграционный
  /// баннер «добавьте контрольный вопрос».
  String? _securityQuestionId;

  /// SHA-256 от нормализованного ответа. Plain-text нигде не хранится.
  String? _securityAnswerHash;

  /// Все созданные профили. Возвращается неизменяемой копией,
  /// чтобы вызывающий код не мог случайно мутировать состояние.
  List<ParticipantProfile> get profiles => List.unmodifiable(_profiles);

  /// ID текущего активного профиля или `null`, если никто не выбран.
  String? get currentProfileId => _currentProfileId;

  /// Есть ли активный профиль И существует ли он в списке.
  /// Двойная проверка защищает от рассинхронизации, если профиль
  /// был удалён, но `current_profile_id` остался в prefs.
  bool get hasProfile => _currentProfileId != null && currentProfile != null;

  /// Прошёл ли текущий участник онбординг (приветственные экраны).
  bool get onboardingCompleted => _onboardingCompleted;

  /// Выполнена ли первоначальная настройка педагогом (PIN задан).
  bool get parentSetupDone => _parentSetupDone;

  /// Есть ли непустой PIN-код для входа в раздел педагога.
  bool get hasPinSet => _pin != null && _pin!.isNotEmpty;

  /// Проверка PIN-кода при попытке доступа к настройкам и аналитике.
  bool verifyPin(String pin) => _pin == pin;

  /// Задан ли контрольный вопрос — если нет, восстановление PIN
  /// невозможно (педагогу остаётся только сброс приложения через
  /// /settings, если он туда зайдёт). UI скрывает кнопку «Забыл PIN»
  /// при `false` и показывает миграционный баннер.
  bool get hasSecurityQuestion =>
      _securityQuestionId != null && _securityAnswerHash != null;

  /// Текст текущего контрольного вопроса для отображения на экране
  /// восстановления. Возвращает `null`, если вопрос не задан или
  /// его ID отсутствует в [kSecurityQuestions] (например, после
  /// удаления старого вопроса в новой версии — fallback на «вопрос
  /// больше не доступен»).
  String? get securityQuestionText {
    final id = _securityQuestionId;
    if (id == null) return null;
    return kSecurityQuestions[id];
  }

  /// Проверка ответа на контрольный вопрос. Нормализация и хэширование
  /// в [hashSecurityAnswer] — здесь только сравнение строк.
  bool verifySecurityAnswer(String answer) {
    if (_securityAnswerHash == null) return false;
    return hashSecurityAnswer(answer) == _securityAnswerHash;
  }

  /// Текущий профиль как объект или `null`. Использует `firstOrNull`
  /// чтобы не падать с исключением, если ID указывает на несуществующий
  /// (удалённый) профиль.
  ParticipantProfile? get currentProfile =>
      _profiles.where((p) => p.id == _currentProfileId).firstOrNull;

  /// Загружает все данные из [SharedPreferences] при старте приложения.
  /// Должна вызываться один раз в [main] до запуска runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('profiles_list');
    if (json != null) {
      final list = jsonDecode(json) as List;
      _profiles = list
          .map((j) => ParticipantProfile.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    _currentProfileId = prefs.getString('current_profile_id');
    _parentSetupDone = prefs.getBool('global_parent_setup') ?? false;
    _pin = prefs.getString('global_pin');
    _securityQuestionId = prefs.getString('global_security_question');
    _securityAnswerHash = prefs.getString('global_security_answer_hash');
    if (_currentProfileId != null) {
      final id = _currentProfileId!;
      _onboardingCompleted = prefs.getBool('profile_${id}_onboarding') ?? false;
    }
    notifyListeners();
  }

  /// Сохраняет список профилей в JSON. Отдельный метод, потому что
  /// вызывается из нескольких операций (создание, удаление).
  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'profiles_list',
      jsonEncode(_profiles.map((p) => p.toJson()).toList()),
    );
  }

  /// Создаёт новый профиль участника. ID генерируется из timestamp
  /// в миллисекундах — это даёт уникальность без UUID-зависимости
  /// и позволяет сортировать профили по времени создания.
  Future<ParticipantProfile> createProfile(
    String name,
    int colorIndex, {
    ParticipantGroup group = ParticipantGroup.experimental,
  }) async {
    final id = 'p${DateTime.now().millisecondsSinceEpoch}';
    final profile = ParticipantProfile(
        id: id, name: name, colorIndex: colorIndex, group: group);
    _profiles.add(profile);
    await _persistProfiles();
    notifyListeners();
    return profile;
  }

  /// Выбирает активный профиль. После вызова все экраны увидят
  /// нового участника через `context.read<ProfileModel>().currentProfile`.
  /// Подтягивает статус онбординга именно этого профиля.
  Future<void> selectProfile(String id) async {
    _currentProfileId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_profile_id', id);
    _onboardingCompleted = prefs.getBool('profile_${id}_onboarding') ?? false;
    notifyListeners();
  }

  /// Фиксирует прохождение онбординга для текущего профиля.
  /// Без активного профиля ничего не делает — защита от вызова
  /// до выбора участника.
  Future<void> markOnboardingCompleted() async {
    if (_currentProfileId == null) return;
    _onboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_${_currentProfileId}_onboarding', true);
    notifyListeners();
  }

  /// Завершает первоначальную настройку педагога: сохраняет PIN
  /// и помечает приложение как готовое к работе.
  ///
  /// [securityQuestionId] + [securityAnswer] обязательны на новых
  /// установках (см. экран `parent_setup_screen.dart`), но методически
  /// оставлены опциональными, чтобы тесты и миграционные сценарии
  /// могли создавать минимальную настройку без вопроса.
  ///
  /// После вызова GoRouter перестаёт редиректить на экран настройки.
  Future<void> completeParentSetup({
    required String pin,
    String? securityQuestionId,
    String? securityAnswer,
  }) async {
    _parentSetupDone = true;
    _pin = pin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('global_parent_setup', true);
    await prefs.setString('global_pin', pin);
    if (securityQuestionId != null && securityAnswer != null) {
      _securityQuestionId = securityQuestionId;
      _securityAnswerHash = hashSecurityAnswer(securityAnswer);
      await prefs.setString('global_security_question', securityQuestionId);
      await prefs.setString(
          'global_security_answer_hash', _securityAnswerHash!);
    }
    notifyListeners();
  }

  /// Задаёт/меняет контрольный вопрос. Вызывается:
  /// - из миграционного потока (старые установки без вопроса);
  /// - в будущем — из настроек, если педагог захочет сменить вопрос.
  Future<void> setSecurityQuestion({
    required String questionId,
    required String answer,
  }) async {
    _securityQuestionId = questionId;
    _securityAnswerHash = hashSecurityAnswer(answer);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_security_question', questionId);
    await prefs.setString(
        'global_security_answer_hash', _securityAnswerHash!);
    notifyListeners();
  }

  /// Меняет PIN-код. Используется из настроек педагогом
  /// и из экрана восстановления PIN.
  Future<void> changePin(String newPin) async {
    _pin = newPin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_pin', newPin);
    notifyListeners();
  }

  /// Удаляет профиль участника. Если удаляется активный —
  /// сбрасывает `currentProfileId`, чтобы экран выбора профиля
  /// открылся при следующем входе.
  /// Сами данные прогресса (`profile_{id}_*`) остаются в prefs —
  /// можно очистить отдельно через [factoryReset].
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    if (_currentProfileId == id) {
      _currentProfileId = null;
      _onboardingCompleted = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_profile_id');
    }
    await _persistProfiles();
    notifyListeners();
  }

  /// Выход из текущего профиля без удаления. Используется при
  /// смене ребёнка на том же устройстве.
  /// Глобальные настройки (PIN) сохраняются — взрослому не нужно
  /// заново настраивать приложение.
  Future<void> logout() async {
    _currentProfileId = null;
    _onboardingCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_profile_id');
    notifyListeners();
  }

  /// Полный сброс приложения до состояния «после установки».
  /// Удаляет все профили, прогресс, диагностику, PIN и настройки.
  ///
  /// Опасная операция — вызывается только из настроек педагога
  /// с двойным подтверждением. Перебирает только известные ключи,
  /// чтобы не задеть данные других пакетов (если они появятся).
  Future<void> factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().toList();
    for (final key in allKeys) {
      if (key.startsWith('profile_') ||
          key == 'profiles_list' ||
          key == 'current_profile_id' ||
          key == 'global_parent_setup' ||
          key == 'global_pin' ||
          key == 'global_security_question' ||
          key == 'global_security_answer_hash' ||
          key == 'session_duration_minutes') {
        await prefs.remove(key);
      }
    }
    _profiles = [];
    _currentProfileId = null;
    _onboardingCompleted = false;
    _parentSetupDone = false;
    _pin = null;
    _securityQuestionId = null;
    _securityAnswerHash = null;
    notifyListeners();
  }
}
