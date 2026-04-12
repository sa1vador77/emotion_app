import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Резервное копирование и восстановление данных приложения.
///
/// Зачем нужно: всё хранится в [SharedPreferences]. Переустановка
/// приложения / смена телефона / некорректное обновление iOS = полная
/// потеря данных исследования. Для ВКР с выборкой 20 детей за месяц
/// это критический риск.
///
/// Что входит в бэкап определяет [_isBackupKey] (per-profile + [_globalKeys]).
/// Настройки звука (`audio_*` ключи `SoundService`) НЕ входят — они относятся
/// к устройству, а не к данным исследования.
///
/// Платформонезависимый сервис: возвращает путь к временному файлу
/// и читает содержимое выбранного. Открытие share sheet и file picker
/// делает вызывающий экран (там нужен `BuildContext`).
class BackupService {
  /// Версия формата файла. Меняется при несовместимых правках схемы;
  /// импорт более новой версии будет отклонён с понятной ошибкой.
  static const int _formatVersion = 1;

  /// Сигнатура формата — защита от случайного импорта чужого JSON.
  static const String _formatTag = 'emotion_app_backup';

  /// Глобальные ключи без префикса `profile_`. Должны совпадать
  /// со списком в [ProfileModel.factoryReset], иначе бэкап и сброс
  /// разъедутся (что-то одно затронет ключи, которые другое игнорирует).
  static const Set<String> _globalKeys = {
    'profiles_list',
    'current_profile_id',
    'global_parent_setup',
    'global_pin',
    'global_security_question',
    'global_security_answer_hash',
    'session_duration_minutes',
  };

  /// Подходит ли ключ для включения в бэкап.
  /// Per-profile (`profile_*`) + явно перечисленные глобальные.
  static bool _isBackupKey(String key) =>
      key.startsWith('profile_') || _globalKeys.contains(key);

  /// Экспортирует все данные в JSON-файл во временной директории.
  /// Возвращает абсолютный путь к файлу — вызывающий код передаёт
  /// его в `Share.shareXFiles`.
  ///
  /// Имя файла: `emotion_app_backup_<ISO-timestamp>.json` — содержит
  /// дату для сортировки и уникальности.
  Future<String> exportToFile() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <Map<String, dynamic>>[];

    for (final key in prefs.getKeys()) {
      if (!_isBackupKey(key)) continue;
      final value = prefs.get(key);
      final type = _typeNameFor(value);
      if (type == null) continue;
      entries.add({'key': key, 'type': type, 'value': value});
    }

    final payload = {
      'format': _formatTag,
      'version': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries,
    };

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 16);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/emotion_app_backup_$ts.json');
    // Используем pretty-print с отступом 2 пробела — для редкой,
    // но возможной ручной инспекции бэкапа (если педагог захочет
    // проверить, что внутри). Размер всё равно небольшой (десятки KB).
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload));
    return file.path;
  }

  /// Восстанавливает SharedPreferences из JSON-файла по [path].
  ///
  /// Полная замена, не слияние: сначала удаляются все ключи под `_isBackupKey`
  /// (иначе профили, отсутствующие в бэкапе, остались бы «висеть»), затем
  /// восстанавливаются значения из файла.
  ///
  /// После успешного импорта вызывающий код должен перезагрузить
  /// все ChangeNotifier'ы (`ProfileModel.load`, `ProgressModel.load`,
  /// `DiagnosticModel.load`, `SessionTimerModel.load`).
  ///
  /// Бросает [BackupImportException] при невалидном файле.
  Future<void> importFromFile(String path) async {
    final raw = await File(path).readAsString();
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw BackupImportException('Файл не похож на JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupImportException('Неожиданная структура файла.');
    }
    if (decoded['format'] != _formatTag) {
      throw const BackupImportException(
          'Это не файл резервной копии «Мира эмоций».');
    }
    final version = decoded['version'];
    if (version is! int || version > _formatVersion) {
      throw BackupImportException(
          'Версия файла ($version) не поддерживается. Обновите приложение.');
    }
    final entries = decoded['entries'];
    if (entries is! List) {
      throw const BackupImportException('Повреждённый бэкап: нет записей.');
    }

    final prefs = await SharedPreferences.getInstance();

    // Сначала чистим старые ключи бэкапа, чтобы импорт давал
    // **полную** замену, а не объединение. Иначе профили из старого
    // состояния, отсутствующие в бэкапе, остались бы «висеть».
    final existing = prefs.getKeys().where(_isBackupKey).toList();
    for (final key in existing) {
      await prefs.remove(key);
    }

    // Восстанавливаем по типам. Неизвестные типы пропускаем без падения —
    // лучше неполный импорт, чем сорванный целиком.
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final key = entry['key'];
      final type = entry['type'];
      final value = entry['value'];
      if (key is! String || !_isBackupKey(key)) continue;
      switch (type) {
        case 'string':
          if (value is String) await prefs.setString(key, value);
        case 'bool':
          if (value is bool) await prefs.setBool(key, value);
        case 'int':
          if (value is int) await prefs.setInt(key, value);
        case 'double':
          if (value is num) await prefs.setDouble(key, value.toDouble());
        case 'stringList':
          if (value is List) {
            await prefs.setStringList(
                key, value.map((e) => e.toString()).toList());
          }
      }
    }
  }

  /// Сопоставление Dart-типа значения [SharedPreferences] и строкового
  /// тега в JSON. Null означает «не сохраняем» (на практике не должно
  /// встречаться, но защищает от сюрпризов будущих типов).
  static String? _typeNameFor(Object? v) {
    if (v is String) return 'string';
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is List<String>) return 'stringList';
    return null;
  }
}

/// Ошибка импорта бэкапа с человекочитаемым сообщением.
/// Выводится в snackbar — поэтому текст уже на русском.
class BackupImportException implements Exception {
  final String message;
  const BackupImportException(this.message);
  @override
  String toString() => message;
}
