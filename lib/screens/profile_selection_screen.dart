import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';
import '../models/progress_model.dart';
import '../models/diagnostic_model.dart';

/// Экран выбора участника — стартовый при наличии созданных профилей.
///
/// Поддержка нескольких профилей нужна, чтобы один планшет можно было
/// использовать с группой детей или в семье. Педагог/родитель видит
/// список карточек с именами и аватарами, тапает нужную — и приложение
/// перезагружает прогресс и диагностику именно для этого ребёнка.
///
/// GoRouter автоматически перенаправит на главный экран после выбора —
/// через `refreshListenable: profileModel` в роутере.
class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  /// Флаг, защищающий от двойного нажатия во время асинхронной
  /// загрузки данных профиля.
  bool _isLoading = false;

  /// Порядок await важен: ProgressModel/DiagnosticModel должны грузиться
  /// уже после selectProfile (иначе подтянут данные предыдущего профиля).
  /// По завершении GoRouter сам уйдёт с экрана — hasProfile станет true.
  Future<void> _onSelectProfile(
    ParticipantProfile profile,
    ProfileModel profileModel,
    ProgressModel progress,
    DiagnosticModel diagnostic,
  ) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await profileModel.selectProfile(profile.id);
    await progress.loadForProfile(profile.id);
    await diagnostic.loadForProfile(profile.id);
    // Защита: пользователь мог уйти с экрана пока шла загрузка.
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileModel = context.watch<ProfileModel>();
    final profiles = profileModel.profiles;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter + 4, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              _buildHeader(context),
              const SizedBox(height: 24),
              if (profiles.isEmpty)
                _buildEmptyState(context)
              else ...[
                Text(
                  'Выберите участника:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _buildProfileCard(context, profiles[i]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildAddButton(context),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const Text('🐱', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 8),
        Text(
          'Мир эмоций',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Кто сегодня занимается?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.blueLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Участников пока нет',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте первого участника\nнажав кнопку ниже',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка одного профиля.
  ///
  /// Каждая раскрашена в цвет [ParticipantProfile.color] —
  /// рамка, фон аватара и стрелка-шеврон. Это создаёт визуальное
  /// разнообразие между профилями, помогает педагогу быстрее
  /// различать детей.
  Widget _buildProfileCard(BuildContext context, ParticipantProfile profile) {
    final profileModel = context.read<ProfileModel>();
    final progress = context.read<ProgressModel>();
    final diagnostic = context.read<DiagnosticModel>();

    return GestureDetector(
      onTap: _isLoading
          ? null
          : () => _onSelectProfile(profile, profileModel, progress, diagnostic),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: profile.color.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: profile.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: profile.color.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(profile.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                profile.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: profile.color,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showAddProfileDialog(context),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Добавить участника'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.blue,
        side: const BorderSide(color: AppTheme.blue, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  /// Показывает диалог создания нового профиля.
  /// Передаёт в диалог множество уже занятых имён (в нижнем регистре)
  /// для валидации уникальности на лету.
  void _showAddProfileDialog(BuildContext context) {
    final existingNames = context
        .read<ProfileModel>()
        .profiles
        .map((p) => p.name.trim().toLowerCase())
        .toSet();
    showDialog(
      context: context,
      builder: (ctx) => _AddProfileDialog(
        existingNames: existingNames,
        onAdd: (name, colorIndex, group) async {
          final profileModel = context.read<ProfileModel>();
          final progress = context.read<ProgressModel>();
          final diagnostic = context.read<DiagnosticModel>();
          final profile =
              await profileModel.createProfile(name, colorIndex, group: group);
          // Сразу выбираем созданный профиль — не нужно лишнего тапа.
          await _onSelectProfile(profile, profileModel, progress, diagnostic);
        },
      ),
    );
  }
}

/// Аватары, доступные при создании профиля — подмножество
/// [kProfileEmojis] / [kProfileColors] по индексам: кот (0), собака (1),
/// медведь (4), лев (6), панда (5). Остальных животных намеренно не
/// показываем. Фильтруем по индексам, а не урезаем глобальные списки —
/// иначе у уже созданных профилей поехала бы привязка цвет↔аватар.
const List<int> _selectableAvatars = [0, 1, 4, 6, 5];

/// Диалог создания профиля. Имя валидируется на лету: непустое и не
/// дублирующее существующее (регистронезависимо).
class _AddProfileDialog extends StatefulWidget {
  final Set<String> existingNames;

  /// Колбэк создания. Возвращает [Future] чтобы диалог мог
  /// показать индикатор загрузки.
  final Future<void> Function(String name, int colorIndex, ParticipantGroup group)
      onAdd;

  const _AddProfileDialog({required this.existingNames, required this.onAdd});

  @override
  State<_AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<_AddProfileDialog> {
  final _controller = TextEditingController();
  int _selectedColor = 0;
  ParticipantGroup _group = ParticipantGroup.experimental;
  bool _loading = false;
  String? _nameError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      title: const Text('Новый участник'),
      // SingleChildScrollView: на узких экранах / с поднятой клавиатурой
      // содержимое (имя + аватары + выбор группы) выше доступной высоты
      // диалога — без скролла Column переполняется по вертикали.
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            // Очищаем ошибку при первом же изменении — пользователь
            // понимает, что его правка принята.
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: InputDecoration(
              hintText: 'Имя или номер участника',
              filled: true,
              fillColor: AppTheme.bgSecondary,
              errorText: _nameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: _nameError != null
                    ? const BorderSide(color: AppTheme.errorText, width: 1.5)
                    : BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Выберите аватар:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          // Все 5 аватаров в один ряд равными ячейками (Expanded):
          // Wrap влезал по 4 в ширину и переносил пятого одного на
          // новую строку. Row из Expanded раскладывает ровно при любой
          // ширине диалога, кружок центрируется в своей ячейке, вся
          // ячейка — крупный таргет под тап.
          Row(
            children: [
              for (final i in _selectableAvatars)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = i),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: kProfileColors[i].withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _selectedColor
                                ? kProfileColors[i]
                                : kProfileColors[i].withValues(alpha: 0.3),
                            width: i == _selectedColor ? 3 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            kProfileEmojis[i],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Группа исследования:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          // Поле педагога: экспериментальная группа проходит обучение,
          // контрольная — только диагностику. По умолчанию —
          // экспериментальная (типовой сценарий занятия).
          // Чипы вертикально и на всю ширину (stretch) — длинная
          // подпись «Экспериментальная» не помещалась в половину
          // строки и переносилась; вертикально читается ровно.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in ParticipantGroup.values)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: g == ParticipantGroup.values.last ? 0 : 8),
                  child: ChoiceChip(
                    label: Center(child: Text(g.label)),
                    selected: g == _group,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _group = g),
                  ),
                ),
            ],
          ),
        ],
      )),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  final name = _controller.text.trim();
                  if (name.isEmpty) return;
                  if (widget.existingNames.contains(name.toLowerCase())) {
                    setState(() => _nameError = 'Участник с таким именем уже есть');
                    return;
                  }
                  setState(() => _loading = true);
                  // Закрываем диалог до await — иначе после возврата
                  // контекст может быть уже невалидным.
                  Navigator.pop(context);
                  await widget.onAdd(name, _selectedColor, _group);
                },
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Добавить'),
        ),
      ],
    );
  }
}
