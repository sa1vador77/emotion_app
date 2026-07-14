import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_app/models/profile_model.dart';

/// Тесты восстановления PIN по контрольному вопросу и разбора
/// группы участника. Ответ на вопрос нигде не хранится в открытом
/// виде — только SHA-256 от нормализованной строки.
void main() {
  group('hashSecurityAnswer', () {
    test('детерминирован: одинаковый вход → одинаковый хэш', () {
      expect(hashSecurityAnswer('Барсик'), hashSecurityAnswer('Барсик'));
    });

    test('нормализация: регистр и крайние пробелы не влияют', () {
      final canon = hashSecurityAnswer('Москва');
      expect(hashSecurityAnswer('москва'), canon);
      expect(hashSecurityAnswer('  МОСКВА  '), canon);
      expect(hashSecurityAnswer('москва '), canon);
    });

    test('нормализация: повторные пробелы внутри схлопываются', () {
      expect(hashSecurityAnswer('мария  ивановна'),
          hashSecurityAnswer('мария ивановна'));
    });

    test('разные ответы → разные хэши', () {
      expect(hashSecurityAnswer('Барсик'),
          isNot(hashSecurityAnswer('Мурзик')));
    });

    test('результат — 64-символьная hex-строка (SHA-256)', () {
      final h = hashSecurityAnswer('что-нибудь');
      expect(h.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h), isTrue);
    });
  });

  group('ParticipantGroup.fromKey', () {
    test('распознаёт известные ключи', () {
      expect(ParticipantGroup.fromKey('control'), ParticipantGroup.control);
      expect(ParticipantGroup.fromKey('experimental'),
          ParticipantGroup.experimental);
    });

    test('null и неизвестный ключ → experimental (миграция старых профилей)',
        () {
      expect(ParticipantGroup.fromKey(null), ParticipantGroup.experimental);
      expect(ParticipantGroup.fromKey('что-то'), ParticipantGroup.experimental);
    });
  });
}
