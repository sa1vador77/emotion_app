import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_app/data/diagnostic_tasks.dart';

/// Тесты контрбалансировки форм диагностики. Назначение формы
/// детерминировано и устраняет confound «форма × фаза»: один и тот
/// же ребёнок видит в pre и post разные формы, а повторный вход
/// в ту же фазу даёт ту же форму.
void main() {
  String formOf(List task) => (task.first as dynamic).id.startsWith('formA')
      ? 'A'
      : 'B';

  test('батарея = лица + истории одной формы (24 задания)', () {
    final tasks = getDiagnosticTasks(phase: 'pre', participantId: null);
    expect(tasks.length,
        diagnosticTasksFormA.length + socialStoryTasksFormA.length);
    expect(tasks.length, 24);
  });

  group('Фолбэк без participantId — фиксированный A→B', () {
    test('pre → форма A', () {
      final t = getDiagnosticTasks(phase: 'pre', participantId: null);
      expect(formOf(t), 'A');
    });

    test('post → форма B', () {
      final t = getDiagnosticTasks(phase: 'post', participantId: null);
      expect(formOf(t), 'B');
    });
  });

  group('Контрбалансировка по participantId', () {
    // Берём несколько разных id, чтобы покрыть и чётный, и нечётный hashCode.
    const ids = ['child-001', 'p1700000000001', 'Маша', 'xZ', 'участник-7'];

    test('pre и post всегда дают РАЗНЫЕ формы', () {
      for (final id in ids) {
        final pre = getDiagnosticTasks(phase: 'pre', participantId: id);
        final post = getDiagnosticTasks(phase: 'post', participantId: id);
        expect(formOf(pre), isNot(formOf(post)),
            reason: 'для $id формы pre и post должны различаться');
      }
    });

    test('назначение детерминировано: повторный вызов даёт ту же форму', () {
      for (final id in ids) {
        final a = getDiagnosticTasks(phase: 'pre', participantId: id);
        final b = getDiagnosticTasks(phase: 'pre', participantId: id);
        expect(formOf(a), formOf(b));
        expect(a.length, b.length);
      }
    });
  });
}
