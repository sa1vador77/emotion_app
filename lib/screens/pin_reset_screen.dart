import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';

/// Режим экрана восстановления PIN — определяет какой поток
/// пройти. Один и тот же экран обслуживает два сценария, чтобы
/// не дублировать UI формы.
enum PinResetMode {
  /// Педагог забыл PIN — нужно подтвердить личность через
  /// контрольный вопрос и задать новый PIN.
  recoverPin,

  /// Старая установка без контрольного вопроса — миграция: задать
  /// вопрос и ответ, чтобы в будущем можно было восстановить PIN.
  /// PIN при этом не меняется. Доступ возможен только из /settings
  /// (PIN-gate уже пройден).
  setQuestion,
}

/// Экран восстановления PIN или установки контрольного вопроса.
///
/// **recoverPin**: 2 шага.
/// 1. Показ сохранённого вопроса → ввод ответа → проверка хэша.
/// 2. Если ответ верный — форма двойного ввода нового PIN → сохранение.
///
/// **setQuestion**: 1 шаг. Только выбор вопроса + ответ + сохранение.
///
/// Доступен напрямую из PIN-gate (без проверки PIN) — точка входа
/// в обход PIN и есть весь смысл механизма. Защита — секретный ответ.
class PinResetScreen extends StatefulWidget {
  final PinResetMode mode;

  const PinResetScreen({super.key, this.mode = PinResetMode.recoverPin});

  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends State<PinResetScreen> {
  /// Прошёл ли пользователь верификацию ответа (только для recoverPin).
  /// В режиме setQuestion остаётся true сразу — нет этапа проверки.
  late bool _verified;

  /// Контроллер ответа на контрольный вопрос — используется в обоих
  /// режимах (verify и setQuestion).
  final _answerController = TextEditingController();

  /// Контроллеры нового PIN — только в recoverPin.
  final _pin1Controller = TextEditingController();
  final _pin2Controller = TextEditingController();
  final _pin1Focus = FocusNode();
  final _pin2Focus = FocusNode();

  /// Выбранный ID вопроса — только в setQuestion. По умолчанию
  /// первый в списке (как и в parent_setup).
  String _selectedQuestionId = kSecurityQuestions.keys.first;

  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // В режиме setQuestion верификация не нужна — сразу даём
    // заполнять форму вопроса.
    _verified = widget.mode == PinResetMode.setQuestion;
  }

  @override
  void dispose() {
    _answerController.dispose();
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    _pin1Focus.dispose();
    _pin2Focus.dispose();
    super.dispose();
  }

  void _verifyAnswer() {
    final profile = context.read<ProfileModel>();
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _errorText = 'Введите ответ');
      return;
    }
    if (profile.verifySecurityAnswer(answer)) {
      setState(() {
        _verified = true;
        _errorText = null;
        _answerController.clear();
      });
    } else {
      setState(() {
        _errorText = 'Ответ не совпадает с сохранённым';
        _answerController.clear();
      });
    }
  }

  Future<void> _savePin() async {
    final pin1 = _pin1Controller.text.trim();
    final pin2 = _pin2Controller.text.trim();
    if (pin1.length < 4) {
      setState(() => _errorText = 'PIN должен содержать 4 цифры');
      return;
    }
    if (pin1 != pin2) {
      setState(() => _errorText = 'PIN-коды не совпадают');
      return;
    }
    setState(() { _saving = true; _errorText = null; });
    await context.read<ProfileModel>().changePin(pin1);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN изменён'),
        backgroundColor: AppTheme.green,
        duration: Duration(seconds: 3),
      ),
    );
    // На главный экран — там сработают redirect-правила, и педагог
    // при следующем заходе в /settings введёт уже новый PIN.
    context.go('/');
  }

  Future<void> _saveQuestion() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _errorText = 'Введите ответ');
      return;
    }
    setState(() { _saving = true; _errorText = null; });
    await context.read<ProfileModel>().setSecurityQuestion(
          questionId: _selectedQuestionId,
          answer: answer,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Контрольный вопрос сохранён'),
        backgroundColor: AppTheme.green,
        duration: Duration(seconds: 3),
      ),
    );
    // pop возвращает в /settings, где PIN-gate уже был пройден —
    // педагог продолжает работу без повторного ввода PIN.
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSetQuestion = widget.mode == PinResetMode.setQuestion;
    final title = isSetQuestion
        ? 'Контрольный вопрос'
        : 'Восстановление PIN';

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
        title: Text(title),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          padding: EdgeInsets.symmetric(
            horizontal: context.gutter + 12, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isSetQuestion)
                  _buildSetQuestionForm(context)
                else if (!_verified)
                  _buildAnswerStep(context)
                else
                  _buildNewPinStep(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerStep(BuildContext context) {
    final profile = context.watch<ProfileModel>();
    final question = profile.securityQuestionText;

    // Если по какой-то причине вопрос недоступен (например, ID был
    // удалён из приложения), показываем сообщение и кнопку «назад».
    if (question == null) {
      return _buildUnavailableMessage(context);
    }

    return Column(
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
              child: Text('🛟', style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Ответьте на контрольный вопрос',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Если ответ совпадёт с тем, что Вы задали при настройке, '
          'можно будет задать новый PIN. Данные участников останутся.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted, height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        _QuestionDisplay(text: question),
        const SizedBox(height: 12),
        _AnswerInput(controller: _answerController),

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

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _verifyAnswer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Проверить'),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPinStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.greenLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.green.withValues(alpha: 0.3), width: 2),
            ),
            child: const Center(
              child: Text('✓', style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Задайте новый PIN',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Ответ принят. Теперь придумайте новый 4-значный код.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted, height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        _PinTextField(
          controller: _pin1Controller,
          focusNode: _pin1Focus,
          hint: 'Новый PIN',
          onDone: () => FocusScope.of(context).requestFocus(_pin2Focus),
        ),
        const SizedBox(height: 10),
        _PinTextField(
          controller: _pin2Controller,
          focusNode: _pin2Focus,
          hint: 'Повторите PIN',
          onDone: () => FocusScope.of(context).unfocus(),
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

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _savePin,
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
                : const Text('Сохранить PIN'),
          ),
        ),
      ],
    );
  }

  Widget _buildSetQuestionForm(BuildContext context) {
    return Column(
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
              child: Text('🛟', style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Добавьте контрольный вопрос',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Понадобится, если когда-нибудь забудете PIN. Без него '
          'восстановить доступ можно будет только полным сбросом '
          'приложения — все данные участников будут потеряны.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted, height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        _QuestionDropdown(
          selectedId: _selectedQuestionId,
          onChanged: (id) => setState(() => _selectedQuestionId = id),
        ),
        const SizedBox(height: 10),
        _AnswerInput(controller: _answerController),
        const SizedBox(height: 6),
        Text(
          'Ответ хранится в виде SHA-256-хэша — даже если кто-то '
          'получит доступ к файлам приложения, исходный текст не виден.',
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

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveQuestion,
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
                : const Text('Сохранить'),
          ),
        ),
      ],
    );
  }

  /// Fallback, если вопрос недоступен (старый ID, удалённый в новой
  /// версии приложения). Объясняем педагогу, что делать —
  /// единственный путь это factoryReset.
  Widget _buildUnavailableMessage(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        const Text('⚠️', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(
          'Контрольный вопрос недоступен',
          style: Theme.of(context).textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Восстановление PIN невозможно. Чтобы продолжить пользоваться '
          'приложением, придётся сделать полный сброс (Настройки → '
          '«Сбросить всё приложение»). Данные участников будут потеряны.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textMuted, height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Карточка с текстом сохранённого вопроса. Серый фон, цитатная
/// типографика — визуально подчёркивает: это «данность», не поле
/// для редактирования.
class _QuestionDisplay extends StatelessWidget {
  final String text;
  const _QuestionDisplay({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: const Color(0xFFD4E5F7), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('❓', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Поле ввода ответа. Видимый текст (а не obscureText) — педагогу
/// важно проверить, что вводит, особенно после ошибки.
class _AnswerInput extends StatelessWidget {
  final TextEditingController controller;
  const _AnswerInput({required this.controller});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
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

/// Инлайн-список вопросов с радио-выбором. Дублирует виджет из
/// parent_setup (намеренно — приватный widget двух экранов).
/// См. подробное описание стиля в `parent_setup_screen.dart`.
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

/// Круглый индикатор выбора. Анимированная галочка появляется
/// мягко вместе с переходом фона карточки.
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

/// Поле ввода PIN — дублирует виджет из parent_setup.
class _PinTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onDone;

  const _PinTextField({
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
