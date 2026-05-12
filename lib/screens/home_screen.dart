import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';
import '../models/progress_model.dart';
import '../models/diagnostic_model.dart';

/// Главный экран приложения — карта прогресса участника.
///
/// Реализует три **последовательные фазы** исследования
/// в виде вертикального списка:
/// 1. **Диагностика до обучения** — обязательна, разблокирует
///    обучающие модули.
/// 2. **Обучение** — три модуля, проходятся в любом порядке.
/// 3. **Диагностика после обучения** — открывается после
///    завершения всех модулей.
///
/// Карточки модулей в фазе 2 заблокированы (показывается замок),
/// пока не пройдена pre-диагностика. Post-диагностика заблокирована,
/// пока не завершены все три модуля. Это обеспечивает корректный
/// порядок исследования и предотвращает «случайный» сбор данных.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressModel>();
    final diag = context.watch<DiagnosticModel>();
    final preTestDone = diag.hasPreTest;
    // Контрольная группа не проходит обучение — для неё post-тест
    // разблокируется сразу после pre-теста, а фаза обучения скрыта.
    final isControl =
        context.watch<ProfileModel>().currentProfile?.group ==
            ParticipantGroup.control;
    final postTestUnlocked =
        isControl ? preTestDone : progress.allModulesCompleted;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              // ── Фаза 1: Диагностика «до» ─────────────────────────
              const _PhaseLabel(number: '①', text: 'Диагностика до обучения'),
              const SizedBox(height: 6),
              _buildPreTestCard(context, done: preTestDone),
              const SizedBox(height: 16),

              // ── Фаза 2: Обучающие модули ─────────────────────────
              // Контрольная группа фазу обучения не проходит — для неё
              // показываем пояснение вместо карточек модулей.
              if (isControl) ...[
                const _ControlGroupNote(),
                const SizedBox(height: 16),
              ] else ...[
                const _PhaseLabel(number: '②', text: 'Обучение'),
                const SizedBox(height: 6),
                // Подсказка появляется только если pre-тест не пройден —
                // объясняет, почему модули заблокированы.
                if (!preTestDone)
                  const _LockedBanner(
                      message: 'Сначала пройдите диагностику до обучения'),
                _buildModuleCard(
                  context,
                  moduleId: 'module1',
                  icon: '🔍', title: 'Знакомство',
                  subtitle: 'Узнай базовые эмоции',
                  color: AppTheme.blue, lightColor: AppTheme.blueLight,
                  borderColor: const Color(0xFFB8D9F7),
                  progress: progress,
                  locked: !preTestDone,
                ),
                const SizedBox(height: 10),
                _buildModuleCard(
                  context,
                  moduleId: 'module2',
                  icon: '🧩', title: 'Конструктор',
                  subtitle: 'Собери эмоцию по частям',
                  color: AppTheme.green, lightColor: AppTheme.greenLight,
                  borderColor: const Color(0xFFC7F0D4),
                  progress: progress,
                  locked: !preTestDone,
                ),
                const SizedBox(height: 10),
                _buildModuleCard(
                  context,
                  moduleId: 'module3',
                  icon: '📖', title: 'Эмоции в ситуации',
                  subtitle: 'Пойми, что чувствует герой',
                  color: AppTheme.purple, lightColor: AppTheme.purpleLight,
                  borderColor: const Color(0xFFDDD4FA),
                  progress: progress,
                  locked: !preTestDone,
                ),
                const SizedBox(height: 6),
                if (preTestDone)
                  _buildTotalProgress(context, progress.totalProgress),
                const SizedBox(height: 16),
              ],

              // ── Фаза 3: Диагностика «после» ──────────────────────
              const _PhaseLabel(number: '③', text: 'Диагностика после обучения'),
              const SizedBox(height: 6),
              _buildPostTestCard(context,
                  diag: diag,
                  unlocked: postTestUnlocked),
              const SizedBox(height: 16),

              // Доступ в настройки педагога (через PIN на следующем экране).
              TextButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Text('⚙️'),
                label: Text(
                  'Настройки (для педагога)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Чип с именем профиля помогает педагогу убедиться, что перед
  /// занятием выбран правильный ребёнок.
  Widget _buildHeader(BuildContext context) {
    final profile = context.watch<ProfileModel>().currentProfile;
    return Column(
      children: [
        const SizedBox(height: 4),
        if (profile != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  // Полупрозрачный цвет профиля — мягко выделяет
                  // чип, не перетягивая внимание с основного контента.
                  color: profile.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: profile.color.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(profile.emoji,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        const Text('🐱', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 2),
        Text('Мир эмоций',
            style: Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildTotalProgress(BuildContext context, double progress) {
    final pct = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Text('Общий прогресс',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted, fontWeight: FontWeight.w600,
              )),
          const Spacer(),
          Text('$pct%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.blue, fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFD4E5F7),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Карточка обучающего модуля.
  ///
  /// Счётчик «правильных/отвеченных» — в рамках текущей попытки
  /// (сбрасывается при перезапуске). Для уже завершённого модуля
  /// тап ведёт на экран подтверждения перезапуска, а не открывает
  /// модуль напрямую.
  Widget _buildModuleCard(
    BuildContext context, {
    required String moduleId,
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color lightColor,
    required Color borderColor,
    required ProgressModel progress,
    required bool locked,
  }) {
    final value = progress.moduleProgress[moduleId] ?? 0.0;
    final pct = (value * 100).round();
    final correct = progress.correctInModule(moduleId);
    final total = progress.totalInModule(moduleId);
    final started = total > 0 || value > 0;
    final completed = progress.isModuleCompleted(moduleId);

    final String label;
    if (!started) {
      label = 'Не начат';
    } else if (total > 0) {
      label = '$correct/$total · $pct%';
    } else {
      label = '$pct%';
    }

    void handleTap() {
      if (completed) {
        context.push('/module_restart/$moduleId');
      } else {
        context.push('/$moduleId');
      }
    }

    return GestureDetector(
      onTap: locked ? null : handleTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: completed && !locked
                  ? AppTheme.green.withValues(alpha: 0.55)
                  : borderColor,
              width: 2,
            ),
            // Тень убираем у заблокированных — они должны выглядеть
            // «плоскими», без приглашения к нажатию.
            boxShadow: locked ? [] : AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: completed && !locked ? AppTheme.greenLight : lightColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    locked ? '🔒' : (completed ? '✓' : icon),
                    style: TextStyle(
                      fontSize: 26,
                      // Зелёная галочка — единственный случай, когда
                      // в иконке-плашке используется цвет (не эмодзи).
                      color: completed && !locked ? AppTheme.green : null,
                      fontWeight:
                          completed && !locked ? FontWeight.w800 : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        )),
                    if (!locked) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                backgroundColor: lightColor,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: started ? color : AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: locked ? AppTheme.textLight : AppTheme.textMuted,
                  size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreTestCard(BuildContext context, {required bool done}) {
    if (done) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.greenLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.green.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Диагностика до обучения пройдена',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2A7A4A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/diagnostic/pre'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.blue.withValues(alpha: 0.4), width: 2),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppTheme.blueLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Начать диагностику',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    'Определим исходный уровень — это нужно сделать один раз перед обучением',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.blue, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTestCard(
    BuildContext context, {
    required DiagnosticModel diag,
    required bool unlocked,
  }) {
    final done = diag.hasPostTest;

    if (done) {
      return GestureDetector(
        onTap: () => context.push('/diagnostic_result', extra: {
          'session': diag.postSession!,
          'phase': 'post',
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.greenLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppTheme.green.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Итоговая диагностика пройдена',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2A7A4A),
                          fontWeight: FontWeight.w700,
                        )),
                    if (diag.hasBothTests) ...[
                      const SizedBox(height: 2),
                      // Краткое сравнение до/после — мотивирует
                      // педагога и сразу даёт ключевой результат.
                      Text(
                        'До: ${(diag.preSession!.accuracy * 100).round()}%  →  '
                        'После: ${(diag.postSession!.accuracy * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.green, size: 22),
            ],
          ),
        ),
      );
    }

    if (!unlocked) {
      return Opacity(
        opacity: 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: const Color(0xFFDDD4FA), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.purpleLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🔒', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Итоговая диагностика',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      'Доступна после прохождения всех трёх модулей',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/diagnostic/post'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.purple.withValues(alpha: 0.4), width: 2),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppTheme.purpleLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Итоговая диагностика',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    'Все модули пройдены — можно оценить результат!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.purple, size: 26),
          ],
        ),
      ),
    );
  }
}

class _PhaseLabel extends StatelessWidget {
  final String number;
  final String text;
  const _PhaseLabel({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textMuted,
              )),
        ],
      );
}

/// Пояснение для контрольной группы — она проходит только
/// диагностику до и после, без обучающих модулей между ними.
class _ControlGroupNote extends StatelessWidget {
  const _ControlGroupNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('🧪', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Контрольная группа',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    'Без обучающих модулей — только диагностика до и после',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LockedBanner extends StatelessWidget {
  final String message;
  const _LockedBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.accent,
                  )),
            ),
          ],
        ),
      );
}
