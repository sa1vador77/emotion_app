import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Кастомная цифровая клавиатура (а не системная), чтобы ребёнок не подобрал
/// PIN через автоподстановку, не появлялась отвлекающая полноразмерная
/// клавиатура и размер кнопок был под палец взрослого.
class PinInput extends StatefulWidget {
  /// Колбэк, вызываемый при вводе полной комбинации (4 цифры).
  /// Сам виджет не выполняет проверку — только передаёт строку
  /// родителю, который решает, что с ней делать.
  final void Function(String pin) onComplete;

  const PinInput({super.key, required this.onComplete});

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  /// Текущий вводимый PIN. Не сохраняется при выходе с экрана.
  String _pin = '';

  /// Длина PIN — 4 цифры. Достаточно для защиты от ребёнка,
  /// но не утомляет взрослого при частом вводе.
  static const int _pinLength = 4;

  /// Очистка поля отложена на 300мс — даёт родителю увидеть результат
  /// проверки и удобна при повторном вводе.
  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == _pinLength) {
      widget.onComplete(_pin);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _pin = '');
      });
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Цифры не отображаются открытым текстом (точки) — привычный паттерн PIN.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (i) {
            final filled = i < _pin.length;
            return Container(
              width: 16, height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: filled ? AppTheme.blue : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: filled ? AppTheme.blue : AppTheme.textLight,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Левый нижний угол пустой — ноль остаётся посередине, как в системной раскладке.
        ...[
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ].map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  // Пустая ячейка занимает место кнопки —
                  // сохраняет геометрию сетки.
                  if (key.isEmpty) return const SizedBox(width: 80);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: key == '⌫' ? _onDelete : () => _onDigit(key),
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          // Кнопка «удалить» выделена красным,
                          // чтобы её было видно мгновенно — иначе
                          // взрослый может искать «отмену».
                          color: key == '⌫'
                              ? AppTheme.errorSoft
                              : AppTheme.blueLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: key == '⌫'
                                ? AppTheme.errorText.withValues(alpha: 0.3)
                                : const Color(0xFFB8D9F7),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            key,
                            style: TextStyle(
                              fontSize: key == '⌫' ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: key == '⌫'
                                  ? AppTheme.errorText
                                  : AppTheme.blue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )),
      ],
    );
  }
}
