import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Таймер сессии — ограничивает длительность непрерывной работы
/// ребёнка с приложением.
///
/// Для детей с РАС важно дозированное взаимодействие с цифровой
/// средой: усталость и сенсорная перегрузка снижают эффективность
/// обучения и могут привести к мелтдауну. Педагог задаёт лимит
/// (по умолчанию 10 минут), после чего:
/// 1. За 2 минуты до конца появляется мягкий баннер-предупреждение;
/// 2. По истечении времени — оверлей с приглашением сделать перерыв.
///
/// Таймер запускается при входе в обучающий модуль и сбрасывается
/// при возврате после перерыва.
class SessionTimerModel extends ChangeNotifier {
  /// Активный [Timer.periodic], тикающий каждую секунду. Null,
  /// когда сессия не запущена.
  Timer? _timer;

  /// One-shot таймер «грейс-периода». Запускается в момент, когда
  /// основной отсчёт дошёл до 0, но текущее задание ещё не завершено
  /// (`_pendingExpiration = true`). Срабатывает через [_graceDuration]
  /// и принудительно переводит таймер в `_expired = true` — защита
  /// от «зависания» ребёнка на задании на неопределённое время.
  Timer? _graceTimer;

  int _durationMinutes = 10;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _showWarning = false;
  bool _expired = false;
  bool _pendingExpiration = false;

  /// Сколько ждём от истечения сессии до принудительного перехода
  /// на `/session_end`, если ребёнок так и не нажал «Дальше».
  /// 60 секунд — компромисс: успевает досмотреть feedback и завершить
  /// текущее задание, но не зависает на полчаса. Для младших школьников
  /// с РАС более короткие интервалы (например, плановые 15с) ощущаются
  /// тревожно — у ребёнка нет шанса спокойно прочитать обратную связь.
  static const Duration _graceDuration = Duration(seconds: 60);

  int get durationMinutes => _durationMinutes;

  int get remainingSeconds => _remainingSeconds;

  bool get isRunning => _isRunning;

  /// Нужно ли показать баннер «Скоро перерыв» (за 2 минуты до конца).
  bool get showWarning => _showWarning;

  /// Истекло ли время и можно прерывать занятие — переход на
  /// `/session_end`. Включается либо явно из модуля через
  /// [markExpired] (когда ребёнок завершил текущее задание после
  /// истечения сессии), либо автоматически после [_graceDuration].
  bool get expired => _expired;

  /// Сессия закончилась по таймеру, но текущее задание ещё не
  /// завершено — UI показывает мягкий баннер, а переход откладывается
  /// до следующего вызова [ModuleTaskMixin.advanceTask] (после
  /// просмотра feedback и нажатия «Дальше»).
  ///
  /// Введено отдельно от [expired], чтобы не перебивать ребёнка
  /// внезапной навигацией посреди задания — это особенно важно
  /// для детей с РАС.
  bool get pendingExpiration => _pendingExpiration;

  String get timeFormatted {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Загружает сохранённую длительность из [SharedPreferences].
  /// 10 минут — компромисс между достаточным числом заданий
  /// и удержанием внимания в норме для младшего школьного возраста.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _durationMinutes = prefs.getInt('session_duration_minutes') ?? 10;
  }

  /// Меняет длительность сессии. Сохраняется глобально (не привязано
  /// к профилю), потому что обычно задаётся одним педагогом для всех
  /// детей, с которыми он работает.
  Future<void> setDuration(int minutes) async {
    _durationMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_duration_minutes', minutes);
    notifyListeners();
  }

  /// Запускает отсчёт сессии. Повторный вызов в активном состоянии
  /// игнорируется — переходы между модулями не должны сбрасывать
  /// общий лимит сессии. При `pendingExpiration` (сессия фактически
  /// закончилась, ждём завершения задания) тоже игнорируется —
  /// иначе ребёнок мог бы «продлить» сессию, выйдя в меню и зайдя
  /// в другой модуль.
  void start() {
    if (_isRunning || _pendingExpiration) return;
    _timer?.cancel();
    _graceTimer?.cancel();
    _remainingSeconds = _durationMinutes * 60;
    _isRunning = true;
    _showWarning = false;
    _expired = false;
    _pendingExpiration = false;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  /// Колбэк периодического таймера. Уменьшает счётчик, проверяет
  /// триггеры (предупреждение за 120 секунд, истечение).
  /// notifyListeners каждую секунду нужен для обновления UI таймера.
  ///
  /// При истечении: переходим в `pendingExpiration` (не `expired`),
  /// чтобы UI мог мягко предупредить, а реальный переход на
  /// `/session_end` отложить до завершения текущего задания.
  /// Параллельно стартует grace-таймер: если ребёнок не нажал
  /// «Дальше» за минуту, всё равно прерываем (см. [_graceDuration]).
  void _tick(Timer _) {
    if (_remainingSeconds <= 0) {
      _timer?.cancel();
      _isRunning = false;
      _pendingExpiration = true;
      _showWarning = false;
      _graceTimer?.cancel();
      _graceTimer = Timer(_graceDuration, _forceExpire);
      notifyListeners();
      return;
    }
    _remainingSeconds--;
    if (_remainingSeconds == 120) {
      _showWarning = true;
    }
    notifyListeners();
  }

  /// Колбэк grace-таймера. Если за минуту после истечения ребёнок
  /// так и не завершил задание — переводим в `expired`, чтобы
  /// сработал listener в `main.dart` и увёл на `/session_end`.
  /// Защита от двойного срабатывания через проверку `_expired`.
  void _forceExpire() {
    if (_expired) return;
    _pendingExpiration = false;
    _expired = true;
    notifyListeners();
  }

  /// Принудительный переход pending → expired. Вызывается из
  /// [ModuleTaskMixin.advanceTask], когда ребёнок завершил текущее
  /// задание и нажал «Дальше», а сессия к этому моменту уже истекла.
  ///
  /// Главный путь выхода из pendingExpiration — этот метод. Grace
  /// существует только как страховка от «зависания».
  void markExpired() {
    if (_expired) return;
    _graceTimer?.cancel();
    _graceTimer = null;
    _pendingExpiration = false;
    _expired = true;
    notifyListeners();
  }

  /// Скрыть баннер предупреждения. Вызывается тапом по баннеру
  /// или автоматически через 6 секунд после показа (см. main.dart).
  void dismissWarning() {
    _showWarning = false;
    notifyListeners();
  }

  /// Педагог/родитель нажал «Продолжить» на экране паузы.
  /// Полностью обнуляет таймер — следующий вход в модуль вызовет
  /// [start] и отсчёт начнётся заново.
  void continueAfterBreak() {
    _timer?.cancel();
    _graceTimer?.cancel();
    _isRunning = false;
    _showWarning = false;
    _expired = false;
    _pendingExpiration = false;
    _remainingSeconds = 0;
    notifyListeners();
  }

  /// Принудительная остановка таймера — например, при выходе
  /// из модуля по кнопке «Назад».
  void stop() {
    _timer?.cancel();
    _graceTimer?.cancel();
    _isRunning = false;
    _showWarning = false;
    _expired = false;
    _pendingExpiration = false;
    _remainingSeconds = 0;
    notifyListeners();
  }

  /// Освобождает таймер при уничтожении модели — обязательно
  /// для предотвращения утечки и колбэков после dispose.
  @override
  void dispose() {
    _timer?.cancel();
    _graceTimer?.cancel();
    super.dispose();
  }
}
