import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emotion_app/models/progress_model.dart';

/// Юнит-тесты доменной логики прогресса: адаптивная сложность
/// («метод лестницы»), агрегирование метрик, матрица путаницы.
/// Модель работает поверх SharedPreferences, поэтому в setUp
/// подменяем хранилище мок-реализацией.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressModel m;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    m = ProgressModel();
    await m.loadForProfile('test');
  });

  // Удобный помощник: один ответ ребёнка.
  void answer(bool correct,
      {String module = 'module1',
      String target = 'joy',
      String? selected,
      int rt = 1000}) {
    m.recordAnswer(
      moduleId: module,
      emotionId: target,
      selectedEmotionId: selected ?? (correct ? target : 'sadness'),
      isCorrect: correct,
      reactionTimeMs: rt,
    );
  }

  group('Адаптивная сложность (staircase)', () {
    test('не меняется, пока в окне меньше 3 ответов', () {
      expect(m.difficulty['module1'], 1);
      answer(true);
      answer(true);
      // в окне всего 2 ответа — решение не принимается
      expect(m.difficulty['module1'], 1);
    });

    test('повышается при точности > 85 % (3 верных подряд → уровень 2)', () {
      answer(true);
      answer(true);
      answer(true);
      expect(m.difficulty['module1'], 2);
    });

    test('растёт ступенчато: 5 верных подряд → уровень 4', () {
      for (var i = 0; i < 5; i++) {
        answer(true);
      }
      expect(m.difficulty['module1'], 4);
    });

    test('понижается при точности < 70 %', () {
      m.seedDifficultyFromAccuracy(0.80); // старт с уровня 4
      expect(m.difficulty['module1'], 4);
      answer(false);
      answer(false);
      answer(false); // окно [F,F,F], точность 0 % → уровень 3
      expect(m.difficulty['module1'], 3);
    });

    test('не опускается ниже 1 (нижний кламп)', () {
      answer(false);
      answer(false);
      answer(false);
      expect(m.difficulty['module1'], 1);
    });

    test('не поднимается выше 5 (верхний кламп)', () {
      for (var i = 0; i < 8; i++) {
        answer(true);
      }
      expect(m.difficulty['module1'], 5);
    });

    test('каждый модуль адаптируется независимо', () {
      for (var i = 0; i < 3; i++) {
        answer(true, module: 'module1');
      }
      expect(m.difficulty['module1'], 2);
      expect(m.difficulty['module2'], 1);
    });
  });

  group('Число вариантов выбора от уровня (getChoiceCount)', () {
    test('уровни 1–2 → 2 варианта', () {
      m.seedDifficultyFromAccuracy(0.10); // → уровень 1
      expect(m.getChoiceCount('module1'), 2);
    });

    test('уровни 3–4 → 4 варианта', () {
      m.seedDifficultyFromAccuracy(0.55); // → уровень 3
      expect(m.getChoiceCount('module1'), 4);
    });

    test('уровень 5 → 6 вариантов', () {
      for (var i = 0; i < 6; i++) {
        answer(true); // докручиваем до уровня 5
      }
      expect(m.difficulty['module1'], 5);
      expect(m.getChoiceCount('module1'), 6);
    });
  });

  group('Сидирование стартовой сложности из точности pre-теста', () {
    test('≥75 % → 4, ≥50 % → 3, ≥25 % → 2, иначе → 1', () {
      m.seedDifficultyFromAccuracy(0.90);
      expect(m.difficulty['module2'], 4);
      m.seedDifficultyFromAccuracy(0.50);
      expect(m.difficulty['module2'], 3);
      m.seedDifficultyFromAccuracy(0.30);
      expect(m.difficulty['module2'], 2);
      m.seedDifficultyFromAccuracy(0.0);
      expect(m.difficulty['module2'], 1);
    });
  });

  group('Метрики', () {
    test('поэмоционная точность считается верно', () {
      answer(true, target: 'joy');
      answer(true, target: 'joy');
      answer(false, target: 'joy', selected: 'sadness');
      expect(m.accuracyForEmotion('joy'), closeTo(2 / 3, 1e-9));
    });

    test('точность невстречавшейся эмоции = 0 (без деления на ноль)', () {
      expect(m.accuracyForEmotion('disgust'), 0.0);
    });

    test('среднее время реакции усредняется по всем ответам', () {
      answer(true, rt: 1000);
      answer(true, rt: 2000);
      answer(true, rt: 1500);
      expect(m.avgReactionTime, closeTo(1500, 1e-9));
    });
  });

  group('Матрица путаницы', () {
    test('фиксирует и диагональ (верные), и ошибки с направлением', () {
      answer(true, module: 'module1', target: 'joy', selected: 'joy');
      answer(true, module: 'module1', target: 'joy', selected: 'joy');
      answer(false, module: 'module1', target: 'joy', selected: 'sadness');

      final mx = m.confusionMatrixForModule(moduleId: 'module1');
      expect(mx['joy']?['joy'], 2);
      expect(mx['joy']?['sadness'], 1);
    });

    test('агрегирование по всем модулям складывает счётчики', () {
      answer(false, module: 'module1', target: 'fear', selected: 'surprise');
      answer(false, module: 'module2', target: 'fear', selected: 'surprise');
      final agg = m.confusionMatrixForModule();
      expect(agg['fear']?['surprise'], 2);
    });
  });
}
