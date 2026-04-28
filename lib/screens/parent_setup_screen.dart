import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';
import '../models/session_timer_model.dart';

/// Экран первичной настройки приложения педагогом/родителем.
///
/// Показывается **один раз** на устройстве — после онбординга
/// и до начала работы с детьми. Настройки глобальные (общие для
/// всех профилей):
/// - **PIN-код** — защищает раздел «Настройки» и «Аналитика»
///   от случайного захода ребёнка.
/// - **Длительность сессии** — лимит времени одного занятия
///   (5/10/15 минут), после которого приложение предложит перерыв.
///
/// После сохранения [ProfileModel.parentSetupDone] становится true,
/// и GoRouter переводит на экран выбора профиля.
class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  /// Контроллеры двух полей ввода PIN — для двойного ввода и
  /// проверки совпадения (защита от опечатки).
  final _pin1Controller = TextEditingController();
  final _pin2Controller = TextEditingController();
  final _pin1Focus = FocusNode();
  final _pin2Focus = FocusNode();

  /// Контроллер ответа на контрольный вопрос. Plain-text не
  /// сохраняется — на финише посчитаем SHA-256 в [ProfileModel].
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();

  /// Выбранный ID вопроса из [kSecurityQuestions]. По умолчанию —
  /// первый в мапе (девичья фамилия мамы), чтобы не показывать
  /// «не выбрано» — большинство педагогов согласятся с дефолтом.
  String _selectedQuestionId = kSecurityQuestions.keys.first;

  int _selectedDuration = 10;

  /// Ошибка валидации: длина PIN или несовпадение.
  String? _errorText;

  /// Флаг идущего сохранения — блокирует кнопку.
  bool _saving = false;

  @override
  void dispose() {
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    _pin1Focus.dispose();
    _pin2Focus.dispose();
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  /// После успеха GoRouter сам уведёт на экран выбора профиля
  /// через `refreshListenable` — отдельной навигации тут нет.
  Future<void> _finish() async {
    final pin1 = _pin1Controller.text.trim();
    final pin2 = _pin2Controller.text.trim();
    final answer = _answerController.text.trim();

    if (pin1.length < 4) {
      setState(() => _errorText = 'PIN должен содержать 4 цифры');
      return;
    }
    if (pin1 != pin2) {
      setState(() => _errorText = 'PIN-коды не совпадают');
      return;
    }
    if (answer.isEmpty) {
      setState(() =>
          _errorText = 'Введите ответ на контрольный вопрос');
      return;
    }

    setState(() { _saving = true; _errorText = null; });

    final profile = context.read<ProfileModel>();
    final timer = context.read<SessionTimerModel>();

    await timer.setDuration(_selectedDuration);
    await profile.completeParentSetup(
      pin: pin1,
      securityQuestionId: _selectedQuestionId,
      securityAnswer: answer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter + 12, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.blueLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.blue.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(
                    child: Text('🔒', style: TextStyle(fontSize: 36)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Настройка для взрослого',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Этот раздел видит только педагог или родитель. '
                'Задайте PIN-код — он защитит настройки от случайного изменения ребёнком.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted, height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Ввод PIN ────────────────────────────────────────
              const _SectionLabel(label: '🔑 Придумайте PIN-код (4 цифры)'),
              const SizedBox(height: 8),
              _PinField(
                controller: _pin1Controller,
                focusNode: _pin1Focus,
                hint: 'Введите PIN',
                // Автоматический переход во второе поле — экономит
                // тап педагогу.
                onDone: () => FocusScope.of(context).requestFocus(_pin2Focus),
              ),
              const SizedBox(height: 10),
              _PinField(
                controller: _pin2Controller,
                focusNode: _pin2Focus,
                hint: 'Повторите PIN',
                onDone: () => FocusScope.of(context).unfocus(),
              ),

              const SizedBox(height: 24),

              // ── Контрольный вопрос ──────────────────────────────
              // Нужен для восстановления PIN, если педагог забудет.
              // Без него единственным выходом был бы factoryReset —
              // потеря всех данных исследования. Хранится только
              // SHA-256 от нормализованного ответа.
              const _SectionLabel(label: '🛟 Контрольный вопрос (если забудете PIN)'),
              const SizedBox(height: 8),
              _QuestionDropdown(
                selectedId: _selectedQuestionId,
                onChanged: (id) => setState(() => _selectedQuestionId = id),
              ),
              const SizedBox(height: 10),
              _AnswerField(
                controller: _answerController,
                focusNode: _answerFocus,
              ),
              const SizedBox(height: 6),
              Text(
                'Ответ не показывается на экране при восстановлении — '
                'выбирайте то, что точно вспомните через год.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textLight,
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.errorText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 28),

              // ── Выбор длительности сессии ───────────────────────
              const _SectionLabel(label: '⏱ Длительность одного занятия'),
              const SizedBox(height: 10),
              // Три варианта 5/10/15 — типовые для коррекционных
              // занятий с детьми младшего школьного возраста.
              Row(
                children: [5, 10, 15].map((min) {
                  final selected = _selectedDuration == min;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDuration = min),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.blue : AppTheme.bgCard,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.blue
                                  : const Color(0xFFD4E5F7),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$min мин',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textMuted,
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Длительность можно изменить позже в настройках.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textLight,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // ── Краткое описание методики ────────────────────────
              // Помогает педагогу сразу понять структуру программы.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.blueLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: const Color(0xFFB8D9F7), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Структура программы',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _infoStep(context, '①', 'Диагностика до обучения',
                        'Определяем исходный уровень'),
                    _infoStep(context, '②', 'Модули 1–3',
                        'Знакомство → Конструктор → Ситуации'),
                    _infoStep(context, '③', 'Диагностика после обучения',
                        'Оцениваем результат'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Готово — начинаем работу'),
                ),
              ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Одна строка-описание фазы программы в инфо-блоке.
  Widget _infoStep(
      BuildContext context, String num, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(num,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.blue,
                )),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    TextSpan(
                      text: '$title — ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: subtitle,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      );
}

/// Инлайн-список из 4 предустановленных контрольных вопросов.
///
/// Каждый вариант — мягкая карточка с радио-индикатором справа.
/// Заменили стандартный Material `DropdownButtonFormField`: его
/// popup-меню рисуется поверх в дефолтной Material-стилистике
/// (резкая белая плашка, тонкие тени), что выбивается из мягкой
/// пастельной палитры приложения. Инлайн-карточки повторяют
/// паттерн выбора длительности (5/10/15) и профиля — единый
/// визуальный язык во всех экранах настройки.
///
/// Выбранная карточка: пастельный синий фон, blue-обводка 2px,
/// текст жирнее, белая галочка в синем кружке. Невыбранные:
/// белый фон, мягкая тень, серая обводка, пустой кружок.
class _QuestionDropdown extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onChanged;
  const _QuestionDropdown({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: kSecurityQuestions.entries.map((entry) {
        final selected = entry.key == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppTheme.blueLight : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: selected
                      ? AppTheme.blue
                      : const Color(0xFFD4E5F7),
                  width: selected ? 2 : 1.5,
                ),
                // Тень только у невыбранных — чтобы выбранная
                // визуально «вдавливалась» в фон, а остальные
                // выглядели как поднятые кнопки.
                boxShadow: selected ? null : AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppTheme.blue
                                : AppTheme.textPrimary,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RadioDot(selected: selected),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Индикатор выбора в стиле радио приложения; анимация галочки
/// согласована с переходом фона карточки (та же длительность).
class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppTheme.blue : Colors.transparent,
        border: Border.all(
          color: selected ? AppTheme.blue : AppTheme.textLight,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: selected
            ? const Icon(Icons.check_rounded,
                key: ValueKey('check'),
                size: 14,
                color: Colors.white)
            : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }
}

/// Поле ввода ответа на контрольный вопрос. Видимый текст
/// (не obscureText) — педагогу важно видеть, что вводит, чтобы
/// случайно не сделать опечатку, которую не сможет повторить
/// при восстановлении.
class _AnswerField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _AnswerField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Ответ',
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textLight,
          ),
          filled: true,
          fillColor: AppTheme.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: Color(0xFFD4E5F7), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: Color(0xFFD4E5F7), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.blue, width: 2),
          ),
        ),
      );
}

/// Поле ввода PIN. Крупный кегль и широкий letterSpacing —
/// чтобы поле выглядело просторным и удобным для ввода кода.
class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  final VoidCallback onDone;

  const _PinField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 12,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: AppTheme.textLight,
          ),
          // Скрываем счётчик символов — он визуально шумит.
          counterText: '',
          filled: true,
          fillColor: AppTheme.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: Color(0xFFD4E5F7), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: Color(0xFFD4E5F7), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.blue, width: 2),
          ),
        ),
        onSubmitted: (_) => onDone(),
      );
}
