import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';
import '../models/progress_model.dart';
import '../models/diagnostic_model.dart';
import '../models/emotion.dart';
import '../models/session_timer_model.dart';
import '../services/sound_service.dart';
import '../services/backup_service.dart';
import '../widgets/pin_input.dart';
import 'pin_reset_screen.dart';

/// Режимы сброса данных. Разделены отдельным enum, потому что
/// у каждого свой текст подтверждения, цвет кнопки и набор
/// последствий.
enum _ResetMode {
  /// Только прогресс модулей. Диагностика сохраняется —
  /// полезно если педагог хочет «переобучить» ребёнка
  /// с теми же исходными данными.
  learningOnly,

  /// Прогресс модулей + диагностика текущего профиля.
  /// Профиль остаётся в системе.
  all,

  /// Удалить профиль целиком вместе со всеми данными.
  deleteProfile,

  /// Полный сброс приложения — все профили, PIN, настройки.
  /// Возвращает приложение к состоянию «после установки».
  factoryReset,
}

/// Экран настроек, защищённый PIN-кодом: ребёнок не должен случайно
/// сбросить прогресс или поменять настройки.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sound = SoundService();
  late bool _soundEnabled;
  late double _volume;

  /// True после успешного ввода PIN — открывает основные настройки.
  /// Сбрасывается при выходе с экрана (новый вход = новый PIN).
  bool _pinUnlocked = false;

  @override
  void initState() {
    super.initState();
    // Снимок текущих настроек звука, чтобы UI отображал актуальные
    // значения. Изменения сохраняются сразу через [SoundService].
    _soundEnabled = _sound.soundEnabled;
    _volume = _sound.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('⚙️ Настройки'),
      ),
      body: SafeArea(
        // Переключаемся между PIN-gate и основным контентом
        // в одном Scaffold — это сохраняет AppBar единым.
        // ResponsiveContainer ограничивает ширину на планшете,
        // чтобы карточки настроек не растягивались на весь экран.
        child: ResponsiveContainer(
          padding: EdgeInsets.zero,
          child: _pinUnlocked ? _buildSettings(context) : _buildPinGate(context),
        ),
      ),
    );
  }

  Widget _buildPinGate(BuildContext context) {
    return Center(
      child: Padding(
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
              'Введите PIN-код чтобы открыть настройки.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PinInput(
              onComplete: (pin) {
                final profile = context.read<ProfileModel>();
                if (profile.verifyPin(pin)) {
                  setState(() => _pinUnlocked = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Неверный PIN-код'),
                      backgroundColor: AppTheme.errorText,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            // Ссылка «Забыл PIN» — только если задан контрольный
            // вопрос. Иначе нажатие приведёт в тупик «вопрос не
            // задан» — лучше скрыть и оставить путь через миграционный
            // баннер внутри настроек (но туда без PIN не попасть —
            // catch-22 для тех, кто действительно забыл PIN без вопроса).
            if (context.watch<ProfileModel>().hasSecurityQuestion) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/pin_reset',
                    extra: PinResetMode.recoverPin),
                child: const Text(
                  'Забыли PIN?',
                  style: TextStyle(color: AppTheme.blue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Основной контент настроек после прохождения PIN.
  /// Состоит из секций, разделённых заголовками с эмодзи.
  /// Все секции скроллятся как один [SingleChildScrollView].
  Widget _buildSettings(BuildContext context) {
    final profile = context.watch<ProfileModel>();
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.gutter + 4, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Миграционный баннер для установок, сделанных до введения
          // механизма восстановления PIN. Показывается до настроек —
          // максимально заметно, но не блокирует доступ.
          if (!profile.hasSecurityQuestion) ...[
            _SecurityQuestionMigrationBanner(
              onTap: () => context.push('/pin_reset',
                  extra: PinResetMode.setQuestion),
            ),
            const SizedBox(height: 20),
          ],
          _sectionTitle(context, '👤 Участник'),
          _buildProfileSection(context),
          const SizedBox(height: 20),
          _sectionTitle(context, '⏱ Таймер сессии'),
          _buildTimerSection(context),
          const SizedBox(height: 20),

          _sectionTitle(context, '📈 Аналитика'),
          _settingsCard(context, [
            GestureDetector(
              onTap: () => context.push('/analytics'),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.blueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Text('📈', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Открыть аналитику',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('Прогресс, диагностика, рекомендации',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textLight),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          _sectionTitle(context, '🔊 Звук'),
          _settingsCard(context, [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Звуковое сопровождение',
                    style: Theme.of(context).textTheme.bodyLarge),
                Switch(
                  value: _soundEnabled,
                  activeThumbColor: AppTheme.blue,
                  onChanged: (val) async {
                    setState(() => _soundEnabled = val);
                    await _sound.setSoundEnabled(val);
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Text('Громкость',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('🔇', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0, max: 1, divisions: 10,
                    activeColor: AppTheme.blue,
                    // Слайдер отключается если звук выключен —
                    // визуальный сигнал о связанности настроек.
                    onChanged: _soundEnabled
                        ? (val) async {
                            setState(() => _volume = val);
                            await _sound.setVolume(val);
                          }
                        : null,
                  ),
                ),
                const Text('🔊', style: TextStyle(fontSize: 18)),
              ],
            ),
          ]),

          const SizedBox(height: 20),

          // Резервная копия — экспорт/импорт всех данных приложения
          // в один JSON-файл. Нужна на случай переустановки приложения
          // или смены телефона: без неё данные исследования (20 детей
          // × 4 недели) теряются безвозвратно.
          _sectionTitle(context, '💾 Резервная копия'),
          _settingsCard(context, [
            _backupRow(
              context,
              icon: Icons.ios_share_rounded,
              title: 'Сохранить резервную копию',
              subtitle: 'JSON со всеми профилями и данными',
              onTap: () => _exportBackup(context),
            ),
            const SizedBox(height: 10),
            _backupRow(
              context,
              icon: Icons.upload_file_rounded,
              title: 'Восстановить из копии',
              subtitle: 'Заменит все текущие данные на устройстве',
              onTap: () => _importBackup(context),
            ),
          ]),
          const SizedBox(height: 20),

          // Краткая сводка прогресса — для быстрого взгляда без
          // перехода в аналитику.
          _sectionTitle(context, '📊 Прогресс обучения'),
          _settingsCard(context, [
            Consumer<ProgressModel>(
              builder: (context, progress, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow(context, 'Модуль 1 «Знакомство»',
                      '${(progress.moduleProgress['module1']! * 100).round()}%'),
                  _statRow(context, 'Модуль 2 «Конструктор»',
                      '${(progress.moduleProgress['module2']! * 100).round()}%'),
                  _statRow(context, 'Модуль 3 «Ситуации»',
                      '${(progress.moduleProgress['module3']! * 100).round()}%'),
                  if (progress.weakEmotions.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text('Нуждаются в повторении:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        )),
                    const SizedBox(height: 6),
                    ...progress.weakEmotions.take(3).map((e) {
                      final pct = (e.value * 100).round();
                      // Источник истины для имён/эмодзи эмоций один — EmotionData.all.
                      final emotion = EmotionData.getById(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${emotion.emoji} ${emotion.nameRu}: $pct% верных ответов',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: pct < 60 ? AppTheme.errorText : AppTheme.textMuted,
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ]),

          const SizedBox(height: 20),

          _sectionTitle(context, '🔬 Диагностика'),
          _settingsCard(context, [
            Consumer<DiagnosticModel>(
              builder: (context, diag, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow(context, 'Констатирующий этап',
                      diag.hasPreTest ? '✓ Пройден' : 'Не пройден'),
                  _statRow(context, 'Контрольный этап',
                      diag.hasPostTest ? '✓ Пройден' : 'Не пройден'),
                  if (diag.hasPreTest) ...[
                    _statRow(context, 'Точность (до)',
                        '${(diag.preSession!.accuracy * 100).round()}%'),
                  ],
                  if (diag.hasPostTest) ...[
                    _statRow(context, 'Точность (после)',
                        '${(diag.postSession!.accuracy * 100).round()}%'),
                  ],
                ],
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // Раздел сброса — три уровня в одной карточке + один
          // отдельной (заводской сброс) как самый разрушительный.
          _sectionTitle(context, '⚠️ Сброс данных'),
          _settingsCard(context, [
            _resetRow(
              context,
              icon: Icons.refresh_rounded,
              iconColor: AppTheme.accent,
              borderColor: AppTheme.accent,
              title: 'Сбросить прогресс обучения',
              subtitle: 'Данные диагностики сохранятся',
              onTap: () => _confirmReset(context, mode: _ResetMode.learningOnly),
            ),
            const SizedBox(height: 10),
            _resetRow(
              context,
              icon: Icons.delete_sweep_rounded,
              iconColor: AppTheme.errorText,
              borderColor: AppTheme.errorText,
              title: 'Сбросить всё',
              subtitle: 'Прогресс и диагностика текущего участника',
              onTap: () => _confirmReset(context, mode: _ResetMode.all),
            ),
            const SizedBox(height: 10),
            _resetRow(
              context,
              icon: Icons.person_remove_rounded,
              iconColor: AppTheme.errorText,
              borderColor: AppTheme.errorText,
              title: 'Удалить профиль',
              subtitle: 'Профиль и все его данные будут удалены',
              onTap: () => _confirmReset(context, mode: _ResetMode.deleteProfile),
            ),
          ]),
          const SizedBox(height: 20),
          // Заводской сброс выделен отдельной секцией и приглушённым
          // коричневым цветом — визуально сигнализирует «крайняя
          // мера, не для повседневного использования».
          _sectionTitle(context, '🏭 Сброс приложения'),
          _resetRow(
            context,
            icon: Icons.settings_backup_restore_rounded,
            iconColor: const Color(0xFF6B4F4F),
            borderColor: const Color(0xFF6B4F4F),
            title: 'Сбросить всё приложение',
            subtitle: 'Все участники, прогресс, PIN и настройки педагога',
            onTap: () => _confirmReset(context, mode: _ResetMode.factoryReset),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final profileModel = context.watch<ProfileModel>();
    final current = profileModel.currentProfile;
    final profiles = profileModel.profiles;

    return _settingsCard(context, [
      if (current != null) ...[
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: current.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: current.color.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(current.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Текущий участник',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      )),
                  Text(current.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
        if (profiles.length > 1) ...[
          const Divider(height: 20),
          Text('Переключить участника:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              )),
          const SizedBox(height: 8),
          ...profiles
              .where((p) => p.id != current.id)
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _switchProfile(context, p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSecondary,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: p.color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(p.emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(p.name,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                            const Icon(Icons.swap_horiz_rounded,
                                color: AppTheme.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                  )),
        ],
        const Divider(height: 20),
      ],
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _goToProfileSelection(context, profileModel),
          icon: const Icon(Icons.people_alt_rounded, color: AppTheme.blue),
          label: const Text('Управление участниками',
              style: TextStyle(color: AppTheme.blue)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.blue),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        ),
      ),
    ]);
  }

  Future<void> _switchProfile(
      BuildContext context, ParticipantProfile profile) async {
    final profileModel = context.read<ProfileModel>();
    final progress = context.read<ProgressModel>();
    final diagnostic = context.read<DiagnosticModel>();
    await profileModel.selectProfile(profile.id);
    await progress.loadForProfile(profile.id);
    await diagnostic.loadForProfile(profile.id);
    if (context.mounted) context.go('/');
  }

  /// Выход из текущего профиля и переход на экран выбора —
  /// для случая, когда нужно добавить нового участника
  /// или удалить существующего.
  Future<void> _goToProfileSelection(
      BuildContext context, ProfileModel profileModel) async {
    await profileModel.logout();
    if (context.mounted) context.go('/profiles');
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textMuted,
            )),
      );

  Widget _settingsCard(BuildContext context, List<Widget> children) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _statRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: AppTheme.blue,
                )),
          ],
        ),
      );

  Widget _buildTimerSection(BuildContext context) {
    final timer = context.watch<SessionTimerModel>();
    const durations = [5, 10, 15];

    return _settingsCard(context, [
      Text(
        'Длительность одной сессии занятий.',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: durations.map((minutes) {
          final selected = timer.durationMinutes == minutes;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => timer.setDuration(minutes),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.blue : AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: selected
                          ? AppTheme.blue
                          : const Color(0xFFD4E5F7),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$minutes мин',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      if (timer.isRunning) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.blueLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.blue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Сессия идёт: ${timer.timeFormatted} осталось',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.blue, fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: timer.stop,
                child: Text(
                  'Стоп',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.errorText, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ]);
  }

  /// Цвет (оранжевый/красный/коричневый) сигнализирует степень
  /// разрушительности действия.
  Widget _resetRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: borderColor.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          )),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: iconColor.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  /// Кнопка-строка для секции «Резервная копия». Визуально похожа
  /// на [_resetRow], но всегда в синих тонах — это безопасное
  /// действие, не разрушительное.
  Widget _backupRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.blueLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: AppTheme.blue.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.blue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.blue,
                          )),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.blue.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  /// Экспорт всех данных в JSON. На iOS — share sheet, на desktop —
  /// прямая запись в `~/Documents`. Логика разделения платформ
  /// зеркалит [HandoffScreen._save] для CSV: на мобильном пользователь
  /// сам решает, куда положить файл, на десктопе у нас есть прямой
  /// доступ к файловой системе.
  Future<void> _exportBackup(BuildContext context) async {
    try {
      final path = await BackupService().exportToFile();

      if (Platform.isIOS) {
        if (!context.mounted) return;
        // sharePositionOrigin обязателен на iPad — иначе popover
        // не знает, к чему привязаться.
        final box = context.findRenderObject() as RenderBox?;
        final size = MediaQuery.of(context).size;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromLTWH(0, 0, size.width, size.height / 2);
        await Share.shareXFiles(
          [XFile(path, mimeType: 'application/json')],
          subject: path.split('/').last,
          sharePositionOrigin: origin,
        );
      } else {
        final home = Platform.environment['HOME'] ?? '/tmp';
        final dir = Directory('$home/Documents');
        if (!await dir.exists()) await dir.create(recursive: true);
        final dest = File('${dir.path}/${path.split('/').last}');
        await File(path).copy(dest.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Сохранено: ${dest.path}'),
              backgroundColor: AppTheme.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: AppTheme.errorText,
          ),
        );
      }
    }
  }

  /// Переход на `/` после импорта нужен, потому что текущий профиль мог
  /// исчезнуть или появиться — GoRouter через redirect-правила сам
  /// отправит на /parent_setup, /profiles, /onboarding или /.
  Future<void> _importBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Восстановить из копии?'),
        content: const Text(
          'Все текущие профили, прогресс, диагностика, PIN и настройки '
          'будут заменены данными из выбранного файла. Это нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blue),
            child: const Text('Выбрать файл'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    XFile? picked;
    try {
      // Фильтр по расширению .json. На iOS дополнительно указываем
      // UTI `public.json` — без него системный picker может не
      // распознать кастомные расширения и показать «все файлы».
      const group = XTypeGroup(
        label: 'JSON',
        extensions: ['json'],
        uniformTypeIdentifiers: ['public.json'],
      );
      picked = await openFile(acceptedTypeGroups: [group]);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть выбор файла: $e'),
            backgroundColor: AppTheme.errorText,
          ),
        );
      }
      return;
    }
    final path = picked?.path;
    if (path == null) return; // отмена выбора — молча выходим
    if (!context.mounted) return;

    // Захватываем зависимости до await — после восстановления
    // и навигации контекст этого State может стать невалидным.
    final profileModel = context.read<ProfileModel>();
    final progressModel = context.read<ProgressModel>();
    final diagModel = context.read<DiagnosticModel>();
    final timerModel = context.read<SessionTimerModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await BackupService().importFromFile(path);

      // Перезагружаем все модели по очереди. Порядок важен:
      // профиль первым (он определяет активный ID), затем зависящие
      // от него прогресс и диагностика.
      await profileModel.load();
      final newId = profileModel.currentProfileId;
      if (newId != null) {
        await progressModel.loadForProfile(newId);
        await diagModel.loadForProfile(newId);
      } else {
        await progressModel.load();
        await diagModel.load();
      }
      await timerModel.load();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Данные восстановлены'),
          backgroundColor: AppTheme.green,
          duration: Duration(seconds: 3),
        ),
      );
      // PIN мог поменяться — выходим с экрана настроек, чтобы новый
      // вход прошёл через свежую PIN-gate.
      router.go('/');
    } on BackupImportException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.errorText,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка восстановления: $e'),
          backgroundColor: AppTheme.errorText,
        ),
      );
    }
  }

  /// Один общий метод на все 4 режима — текст, цвет кнопки и логика
  /// очистки выбираются по [mode].
  void _confirmReset(BuildContext context, {required _ResetMode mode}) {
    final titles = {
      _ResetMode.learningOnly: 'Сбросить обучение?',
      _ResetMode.all: 'Сбросить всё?',
      _ResetMode.deleteProfile: 'Удалить профиль?',
      _ResetMode.factoryReset: 'Сбросить всё приложение?',
    };
    final bodies = {
      _ResetMode.learningOnly:
          'Прогресс по модулям будет сброшен. Данные диагностики сохранятся.',
      _ResetMode.all:
          'Будут удалены весь прогресс и все результаты диагностики текущего участника. Это нельзя отменить.',
      _ResetMode.deleteProfile:
          'Профиль и все данные участника (прогресс, диагностика) будут удалены без возможности восстановления.',
      _ResetMode.factoryReset:
          'Все профили участников, прогресс, диагностика, PIN и настройки педагога будут удалены. Приложение вернётся к начальной настройке. Это нельзя отменить.',
    };
    final buttonLabels = {
      _ResetMode.learningOnly: 'Сбросить',
      _ResetMode.all: 'Сбросить всё',
      _ResetMode.deleteProfile: 'Удалить',
      _ResetMode.factoryReset: 'Сбросить приложение',
    };
    final buttonColors = {
      _ResetMode.learningOnly: AppTheme.accent,
      _ResetMode.all: AppTheme.errorText,
      _ResetMode.deleteProfile: AppTheme.errorText,
      _ResetMode.factoryReset: const Color(0xFF6B4F4F),
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(titles[mode]!),
        content: Text(bodies[mode]!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final progressModel = context.read<ProgressModel>();
              final diagModel = context.read<DiagnosticModel>();
              final profileModel = context.read<ProfileModel>();
              final profileId = profileModel.currentProfileId;

              Navigator.pop(ctx);

              switch (mode) {
                case _ResetMode.learningOnly:
                  await progressModel.resetAll();
                  if (context.mounted) context.go('/');
                case _ResetMode.all:
                  await progressModel.resetAll();
                  await diagModel.clearAll();
                  if (context.mounted) context.go('/');
                case _ResetMode.deleteProfile:
                  await progressModel.resetAll();
                  await diagModel.clearAll();
                  if (profileId != null) {
                    await profileModel.deleteProfile(profileId);
                  }
                  if (context.mounted) context.go('/profiles');
                case _ResetMode.factoryReset:
                  await progressModel.resetAll();
                  await diagModel.clearAll();
                  await profileModel.factoryReset();
                  // После сброса parentSetupDone=false → GoRouter
                  // автоматически переведёт на /parent_setup.
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: buttonColors[mode]),
            child: Text(buttonLabels[mode]!),
          ),
        ],
      ),
    );
  }
}

/// Миграционный баннер для установок, сделанных до введения
/// механизма восстановления PIN — у них нет контрольного вопроса,
/// и единственным выходом из «забытого PIN» был бы factoryReset.
///
/// Кликабельный — ведёт на `/pin_reset` в режиме setQuestion.
/// Не закрывается тапом «закрыть»: будет показываться при каждом
/// входе в /settings, пока вопрос не задан. Это намеренный
/// фрикшен — задача важная.
class _SecurityQuestionMigrationBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SecurityQuestionMigrationBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
              color: const Color(0xFFFFD0A8), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('🛟', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Контрольный вопрос не задан',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Добавьте — иначе при потере PIN придётся сбросить '
                    'приложение и потерять данные участников.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
