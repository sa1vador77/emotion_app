import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_app/models/diagnostic_model.dart';

/// Юнит-тесты расчётных метрик диагностической сессии. Ключевой
/// методологический инвариант — раздельный учёт двух методик:
/// `accuracy`/`avgReactionMs` считают только «лица» (faces),
/// истории (stories) учитываются отдельными геттерами.
void main() {
  DiagnosticAnswer ans(String target, String selected, String measure,
          {int rt = 1000}) =>
      DiagnosticAnswer(
        emotionId: target,
        selectedId: selected,
        isCorrect: target == selected,
        reactionTimeMs: rt,
        measure: measure,
        timestamp: DateTime(2024, 1, 1),
      );

  group('Раздельный учёт методик', () {
    final session = DiagnosticSession(
      phase: 'pre',
      date: DateTime(2024, 1, 1),
      participantId: 'p1',
      answers: [
        ans('joy', 'joy', 'faces'), // верно
        ans('joy', 'joy', 'faces'), // верно
        ans('fear', 'surprise', 'faces'), // ошибка
        ans('joy', 'sadness', 'stories'), // ошибка
        ans('sadness', 'sadness', 'stories'), // верно
      ],
    );

    test('accuracy учитывает только faces', () {
      // 2 из 3 faces верны
      expect(session.accuracy, closeTo(2 / 3, 1e-9));
    });

    test('storiesAccuracy учитывает только stories', () {
      // 1 из 2 stories верна
      expect(session.storiesAccuracy, closeTo(1 / 2, 1e-9));
    });

    test('сырые счётчики faces/stories', () {
      expect(session.facesCorrect, 2);
      expect(session.facesTotal, 3);
      expect(session.storiesCorrect, 1);
      expect(session.storiesTotal, 2);
    });

    test('accuracyForEmotion берёт только faces данной эмоции', () {
      // joy: 2 faces верных из 2; ошибочная joy-история не учитывается
      expect(session.accuracyForEmotion('joy'), 1.0);
    });
  });

  group('Время реакции', () {
    test('avgReactionMs усредняет только faces', () {
      final s = DiagnosticSession(
        phase: 'pre',
        date: DateTime(2024, 1, 1),
        answers: [
          ans('joy', 'joy', 'faces', rt: 1000),
          ans('fear', 'fear', 'faces', rt: 3000),
          ans('joy', 'joy', 'stories', rt: 9000), // не влияет на faces
        ],
      );
      expect(s.avgReactionMs, closeTo(2000, 1e-9));
    });
  });

  group('Граничные случаи', () {
    test('пустая по методике сессия даёт 0, а не деление на ноль', () {
      final s = DiagnosticSession(
        phase: 'pre',
        date: DateTime(2024, 1, 1),
        answers: [ans('joy', 'joy', 'faces')],
      );
      expect(s.storiesAccuracy, 0.0);
      expect(s.storiesAvgReactionMs, 0.0);
    });
  });

  group('Сериализация (как в бэкапе и хранилище)', () {
    test('DiagnosticAnswer переживает round-trip JSON', () {
      final a = ans('anger', 'disgust', 'faces', rt: 1234);
      final back = DiagnosticAnswer.fromJson(a.toJson());
      expect(back.emotionId, 'anger');
      expect(back.selectedId, 'disgust');
      expect(back.isCorrect, false);
      expect(back.reactionTimeMs, 1234);
      expect(back.measure, 'faces');
    });

    test('старые ответы без поля measure читаются как faces', () {
      final back = DiagnosticAnswer.fromJson({
        'emotionId': 'joy',
        'selectedId': 'joy',
        'isCorrect': true,
        'reactionTimeMs': 800,
        'timestamp': DateTime(2024, 1, 1).toIso8601String(),
        // 'measure' отсутствует — миграция со старых сессий
      });
      expect(back.measure, 'faces');
    });

    test('DiagnosticSession переживает round-trip JSON', () {
      final s = DiagnosticSession(
        phase: 'post',
        date: DateTime(2024, 5, 20),
        participantId: 'p42',
        answers: [
          ans('joy', 'joy', 'faces'),
          ans('fear', 'surprise', 'stories'),
        ],
      );
      final back = DiagnosticSession.fromJson(s.toJson());
      expect(back.phase, 'post');
      expect(back.participantId, 'p42');
      expect(back.answers.length, 2);
      expect(back.facesTotal, 1);
      expect(back.storiesTotal, 1);
    });
  });
}
