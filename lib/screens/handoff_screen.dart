import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';
import '../models/progress_model.dart';
import '../models/diagnostic_model.dart';
import '../widgets/pin_input.dart';
import 'pin_reset_screen.dart';

/// Фаза экрана handoff. Передача планшета взрослому реализована
/// как многошаговый flow внутри одного маршрута: дети не видят
/// аналитики, взрослые — не «через назад».
enum _Phase {
  /// Ребёнок видит поздравление и просьбу передать планшет.
  child,

  /// Промежуточный экран ввода PIN-кода.
  pinGate,

  /// Взрослый видит результаты и экспорт.
  adult,
}

/// Контекст завершения занятия — определяет, что показывается
/// на handoff-экране (тексты ребёнку и содержимое для взрослого).
enum HandoffMode {
  /// После пост-диагностики: показываем сравнение pre/post и
  /// возможность CSV-экспорта.
  postDiagnostic,

  /// По истечении таймера сессии: показываем сводку текущего
  /// прогресса и кнопку возврата на главный экран. Без сравнения
  /// диагностик (могут быть не пройдены) и без экспорта (не место).
  sessionExpired,
}

/// Экран передачи устройства от ребёнка к взрослому.
///
/// Используется в двух сценариях:
/// 1. **После итоговой диагностики** ([HandoffMode.postDiagnostic]) —
///    показываем взрослому сравнение pre/post и даём возможность
///    экспортировать данные для статистической обработки.
/// 2. **По истечении таймера сессии** ([HandoffMode.sessionExpired]) —
///    мягко прерываем занятие, ребёнок благодарится за работу,
///    взрослый видит короткую сводку и возвращает на главный.
///
/// В обоих случаях нельзя позволить ребёнку «случайно» увидеть
/// аналитику или поменять данные — поэтому одинаковый защитный
/// двухфазный flow:
/// 1. Ребёнок видит положительный экран и просьбу передать устройство.
/// 2. По нажатию «Я педагог/родитель» — ввод PIN.
/// 3. Только после верного PIN — раскрытие взрослого контента.
///
/// `PopScope(canPop: false)` блокирует системную кнопку «назад» —
/// единственный путь дальше через «На главную» после просмотра.
class HandoffScreen extends StatefulWidget {
  /// Режим работы экрана. По умолчанию — пост-диагностика
  /// (для обратной совместимости со старым маршрутом `/handoff`).
  final HandoffMode mode;

  const HandoffScreen({
    super.key,
    this.mode = HandoffMode.postDiagnostic,
  });

  @override
  State<HandoffScreen> createState() => _HandoffScreenState();
}

class _HandoffScreenState extends State<HandoffScreen> {
  _Phase _phase = _Phase.child;

  /// Переход к запросу доступа взрослого. Если PIN не задан
  /// (старая установка) — пропускаем pinGate и сразу показываем
  /// результаты; это вынужденное упрощение для совместимости.
  void _requestAdultAccess() {
    final profileModel = context.read<ProfileModel>();
    if (!profileModel.hasPinSet) {
      setState(() => _phase = _Phase.adult);
    } else {
      setState(() => _phase = _Phase.pinGate);
    }
  }

  /// Колбэк ввода PIN. Верный → переход в фазу adult.
  /// Неверный → snackbar с подсказкой, поле автоматически
  /// очищается (см. [PinInput]) — ребёнок может попробовать ещё.
  void _onPinEntered(String pin) {
    final profileModel = context.read<ProfileModel>();
    if (profileModel.verifyPin(pin)) {
      setState(() => _phase = _Phase.adult);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Неверный PIN-код'),
          backgroundColor: AppTheme.errorText,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Блокируем системный жест «назад» — после диагностики
      // ребёнок не должен возвращаться в неё.
      canPop: false,
      child: Scaffold(
        body: switch (_phase) {
          _Phase.child => _ChildView(
              mode: widget.mode,
              onAdultTap: _requestAdultAccess,
            ),
          _Phase.pinGate => _PinGateView(
              onPinEntered: _onPinEntered,
              onCancel: () => setState(() => _phase = _Phase.child),
            ),
          _Phase.adult => _AdultView(mode: widget.mode),
        },
      ),
    );
  }
}

/// Промежуточный экран ввода PIN перед раскрытием взрослого контента.
class _PinGateView extends StatelessWidget {
  final void Function(String pin) onPinEntered;
  final VoidCallback onCancel;
  const _PinGateView({required this.onPinEntered, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ResponsiveContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.blueLight,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔒', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Для педагога / родителя',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Введите PIN-код для доступа к результатам.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PinInput(onComplete: onPinEntered),
              const SizedBox(height: 16),
              // Кнопка восстановления показывается только при наличии
              // контрольного вопроса — без него нет смысла её нажимать.
              // Watch ради реактивности — если в этой же сессии
              // педагог зайдёт в /settings и задаст вопрос, кнопка
              // подхватится при следующей сборке.
              if (context.watch<ProfileModel>().hasSecurityQuestion)
                TextButton(
                  onPressed: () => context.push('/pin_reset',
                      extra: PinResetMode.recoverPin),
                  child: const Text(
                    'Забыли PIN?',
                    style: TextStyle(color: AppTheme.blue),
                  ),
                ),
              TextButton(
                onPressed: onCancel,
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран для ребёнка: поздравление и просьба передать устройство.
///
/// Намеренно не содержит никаких цифр результата — для ребёнка
/// это просто завершение хорошей работы. Результаты в любом
/// случае увидит только взрослый после ввода PIN.
///
/// Тексты подстраиваются под [HandoffMode]:
/// - post-diagnostic — «Ты прошёл всю программу!»
/// - session-expired — «Время занятия закончилось!»
class _ChildView extends StatelessWidget {
  final HandoffMode mode;
  final VoidCallback onAdultTap;
  const _ChildView({required this.mode, required this.onAdultTap});

  /// Большой эмодзи в шапке. Для пост-диагностики — праздник
  /// (всё прошёл!), для таймера — спокойный отдых.
  String get _heroEmoji => switch (mode) {
        HandoffMode.postDiagnostic => '🎉',
        HandoffMode.sessionExpired => '☕',
      };

  String get _title => switch (mode) {
        HandoffMode.postDiagnostic => 'Молодец!',
        HandoffMode.sessionExpired => 'Время отдохнуть!',
      };

  String get _subtitle => switch (mode) {
        HandoffMode.postDiagnostic =>
          'Ты прошёл всю программу!\nТы очень постарался сегодня.',
        HandoffMode.sessionExpired =>
          'Занятие закончилось.\nТы хорошо поработал — пора сделать перерыв.',
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsiveContainer(
        padding: EdgeInsets.symmetric(
          horizontal: context.gutter + 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_heroEmoji, style: const TextStyle(fontSize: 88)),
            const SizedBox(height: 20),
            Text(
              _title,
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textMuted,
                    height: 1.6,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            // Заметная карточка с инструкцией — рассчитана на то,
            // что ребёнок может не дочитать обычный текст.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.blueLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                    color: AppTheme.blue.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  const Text('📱', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text(
                    'Передай устройство\nпедагогу или родителю',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Outlined кнопка для взрослого — намеренно менее
            // заметная, чем основная инструкция, чтобы ребёнок
            // не нажимал её случайно.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAdultTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                      color: AppTheme.textLight.withValues(alpha: 0.6),
                      width: 1.5),
                ),
                child: Text(
                  'Я педагог / родитель',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Экран для взрослого после успешного PIN.
///
/// Содержимое адаптируется под [HandoffMode]:
/// - **postDiagnostic**: заголовок «Результаты программы» + сравнение
///   pre/post + блок CSV-экспорта;
/// - **sessionExpired**: заголовок «Сессия завершена» + краткая сводка
///   прогресса по модулям + ссылка в полную аналитику. Без сравнения
///   диагностик (могут быть не пройдены) и без экспорта (не контекст).
class _AdultView extends StatelessWidget {
  final HandoffMode mode;
  const _AdultView({required this.mode});

  String get _title => switch (mode) {
        HandoffMode.postDiagnostic => '📊 Результаты программы',
        HandoffMode.sessionExpired => '⏱ Сессия завершена',
      };

  @override
  Widget build(BuildContext context) {
    final diagModel = context.watch<DiagnosticModel>();
    final profileModel = context.watch<ProfileModel>();
    final profile = profileModel.currentProfile;
    final pre = diagModel.preSession;
    final post = diagModel.postSession;

    return SafeArea(
      child: ResponsiveContainer(
        padding: EdgeInsets.symmetric(
          horizontal: context.gutter, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Text(
                _title,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              if (profile != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${profile.emoji} ${profile.name}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),

              // ── Содержимое по режиму ────────────────────────────
              if (mode == HandoffMode.sessionExpired) ...[
                // Сессия по таймеру: краткая сводка прогресса +
                // приглашение в /analytics за деталями.
                _buildSessionSummary(context),
              ] else ...[
                // Пост-диагностика: сравнение pre/post (если есть),
                // переход в полную аналитику и блок CSV-экспорта.
                if (pre != null && post != null)
                  _buildComparison(context, pre, post)
                else if (post != null)
                  _buildSingleResult(context, post),

                const SizedBox(height: 16),
                // Та же кнопка перехода в /analytics, что и в режиме
                // sessionExpired. Раньше её здесь не было, и педагог
                // после итогового PIN-входа упирался только в CSV —
                // приходилось закрывать handoff, идти на главную и
                // открывать настройки. Один тап вместо трёх.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/analytics'),
                    icon: const Icon(Icons.bar_chart_rounded, size: 20),
                    label: const Text('Подробная аналитика'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.blue,
                      side: const BorderSide(color: AppTheme.blue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildExportCard(context, diagModel, profileModel, profile),
              ],

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('На главную 🏠'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Сводка прогресса для режима [HandoffMode.sessionExpired].
  /// Показывает: процент прохождения каждого модуля + ссылка
  /// в полную аналитику. Без сравнения диагностик и без экспорта —
  /// контекст «занятие прервано», а не «программа завершена».
  Widget _buildSessionSummary(BuildContext context) {
    final progress = context.watch<ProgressModel>();
    final m1 = ((progress.moduleProgress['module1'] ?? 0.0) * 100).round();
    final m2 = ((progress.moduleProgress['module2'] ?? 0.0) * 100).round();
    final m3 = ((progress.moduleProgress['module3'] ?? 0.0) * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Текущий прогресс',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Все ответы ребёнка сохранены. Занятие можно продолжить в '
            'любое время с того места, где остановились.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          _progressRow(context, 'Знакомство', m1, AppTheme.blue),
          const SizedBox(height: 8),
          _progressRow(context, 'Конструктор', m2, AppTheme.green),
          const SizedBox(height: 8),
          _progressRow(context, 'Эмоции в ситуации', m3, AppTheme.purple),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/analytics'),
              icon: const Icon(Icons.bar_chart_rounded, size: 20),
              label: const Text('Подробная аналитика'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.blue,
                side: const BorderSide(color: AppTheme.blue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
      BuildContext context, String title, int pct, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(title,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }

  /// Карточка с одним результатом — на случай если pre-теста нет
  /// (старые данные или сброс прогресса с сохранением профиля).
  Widget _buildSingleResult(BuildContext context, DiagnosticSession s) {
    final pct = (s.accuracy * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text('$pct%',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppTheme.blue,
                    fontSize: 56,
                  )),
          Text('точность (итоговая диагностика)',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  /// Сравнительная карточка — основной результат программы для
  /// взрослого. Структура идентична такой же на экране результата
  /// диагностики; код повторяется ради независимости компонента.
  Widget _buildComparison(
      BuildContext context, DiagnosticSession pre, DiagnosticSession post) {
    final diff = post.accuracy - pre.accuracy;
    final diffPct = (diff.abs() * 100).round();
    final improved = diff > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: improved ? AppTheme.greenLight : AppTheme.blueLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: improved
              ? AppTheme.green.withValues(alpha: 0.4)
              : AppTheme.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📈 Динамика (до → после)',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 16,
                    color: improved ? const Color(0xFF2A7A4A) : AppTheme.blue,
                  )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _compCol(context, 'До',
                  '${(pre.accuracy * 100).round()}%', AppTheme.textMuted),
              Text(
                improved
                    ? '▲ +$diffPct%'
                    : (diff < 0 ? '▼ -$diffPct%' : '= 0%'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: improved ? AppTheme.green : AppTheme.errorText,
                      fontSize: 28,
                    ),
              ),
              _compCol(context, 'После',
                  '${(post.accuracy * 100).round()}%', AppTheme.blue),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            improved
                ? 'Наблюдается положительная динамика в развитии навыка распознавания эмоций.'
                : diff < 0
                    ? 'Снижение точности. Рекомендуется продолжить тренировочные занятия.'
                    : 'Точность не изменилась. Рекомендуется продолжить занятия.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMuted, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('⏱ Время реакции: ',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textMuted)),
              Text(
                '${(pre.avgReactionMs / 1000).toStringAsFixed(1)} с → '
                '${(post.avgReactionMs / 1000).toStringAsFixed(1)} с',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compCol(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMuted)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(color: color, fontSize: 32)),
      ],
    );
  }

  /// Карточка экспорта данных. Содержит 4 типа CSV-выгрузки:
  /// - **детальная** по текущему профилю (одна строка на ответ);
  /// - **сводная** по текущему профилю (одна строка с до/после);
  /// - **детальная** по всем профилям;
  /// - **сводная** по всем профилям.
  ///
  /// Эти форматы покрывают типовые потребности статистики:
  /// детальные — для матрицы смешения и временного анализа,
  /// сводные — для T-критерия Вилкоксона и других непараметрических
  /// тестов «до/после».
  Widget _buildExportCard(
    BuildContext context,
    DiagnosticModel diagModel,
    ProfileModel profileModel,
    ParticipantProfile? profile,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📁 Экспорт данных',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Совместимо с SPSS и Excel (CSV)',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),

          // Секция текущего ребёнка — выводится только если
          // профиль активен. Это позволяет педагогу выгрузить
          // данные одного ребёнка без необходимости в групповом
          // экспорте.
          if (profile != null) ...[
            _sectionLabel(context, '${profile.emoji} ${profile.name}'),
            const SizedBox(height: 6),
            _exportTile(
              context,
              icon: '📊',
              label: 'Все ответы (CSV)',
              subtitle: 'Каждый ответ — отдельная строка',
              onTap: () => _save(context,
                  diagModel.exportCsv(group: profile.group),
                  'answers_${profile.id}'),
            ),
            const SizedBox(height: 8),
            _exportTile(
              context,
              icon: '📋',
              label: 'Сводная таблица (CSV)',
              subtitle: 'До/после — для критерия Вилкоксона',
              onTap: () => _save(context,
                  diagModel.exportSummaryCsv(group: profile.group),
                  'summary_${profile.id}'),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
          ],

          // Секция всех детей — групповой экспорт.
          // Здесь используются static-методы [DiagnosticModel],
          // которые читают данные всех профилей напрямую из
          // SharedPreferences (без необходимости загружать
          // каждый профиль в память).
          _sectionLabel(context, '👥 Все дети'),
          const SizedBox(height: 6),
          _exportTile(
            context,
            icon: '📊',
            label: 'Все ответы, все дети (CSV)',
            subtitle: 'Объединённые данные по всем участникам',
            onTap: () async {
              final csv = await DiagnosticModel.exportAllProfilesCsv(
                  profileModel.profiles);
              if (context.mounted) _save(context, csv, 'all_answers');
            },
          ),
          const SizedBox(height: 8),
          _exportTile(
            context,
            icon: '📋',
            label: 'Сводная таблица, все дети (CSV)',
            subtitle: 'До/после по каждому участнику',
            onTap: () async {
              final csv = await DiagnosticModel.exportAllProfilesSummaryCsv(
                  profileModel.profiles);
              if (context.mounted) _save(context, csv, 'all_summary');
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
    );
  }

  /// Плитка экспорта: визуально одинаковые, но за каждой свой формат CSV.
  Widget _exportTile(
    BuildContext context, {
    required String icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.blueLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: const Color(0xFFB8D9F7), width: 1.5),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 13)),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          )),
                ],
              ),
            ),
            const Icon(Icons.download_rounded,
                color: AppTheme.blue, size: 22),
          ],
        ),
      ),
    );
  }

  /// Сохраняет CSV-файл с разделённой логикой по платформам.
  ///
  /// **iOS**: пишем во временную директорию приложения (sandboxed),
  /// затем открываем нативный share sheet через share_plus —
  /// пользователь сам выбирает, куда сохранить (Файлы, AirDrop,
  /// почта и т.д.). `sharePositionOrigin` обязателен на iOS
  /// (особенно для iPad) — задаёт позицию popover.
  ///
  /// **macOS/desktop**: пишем напрямую в `~/Documents` и показываем
  /// snackbar с путём. На desktop у нас есть прямой доступ к
  /// файловой системе, не нужен share sheet.
  ///
  /// Имя файла включает timestamp в ISO-формате для уникальности
  /// и сортировки.
  Future<void> _save(
      BuildContext context, String csv, String name) async {
    try {
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 16);
      final fileName = 'emotion_app_${name}_$ts.csv';

      if (Platform.isIOS) {
        // Захватываем позицию share sheet ДО await — потом
        // context может стать невалидным (виджет размонтирован).
        final box = context.findRenderObject() as RenderBox?;
        final size = MediaQuery.of(context).size;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromLTWH(0, 0, size.width, size.height / 2);

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv')],
          subject: fileName,
          sharePositionOrigin: origin,
        );
      } else {
        final home = Platform.environment['HOME'] ?? '/tmp';
        final dir = Directory('$home/Documents');
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(csv);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Сохранено: ${file.path}'),
              backgroundColor: AppTheme.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Любая ошибка — показываем красный snackbar с текстом.
      // Главное, чтобы приложение не падало на сбое экспорта.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: AppTheme.errorText,
          ),
        );
      }
    }
  }
}
