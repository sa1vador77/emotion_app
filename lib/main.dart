import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'models/profile_model.dart';
import 'models/progress_model.dart';
import 'models/diagnostic_model.dart';
import 'models/session_timer_model.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/module1_screen.dart';
import 'screens/module2_screen.dart';
import 'screens/module3_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/diagnostic_screen.dart';
import 'screens/parent_setup_screen.dart';
import 'screens/diagnostic_result_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/handoff_screen.dart';
import 'screens/module_restart_screen.dart';
import 'screens/pin_reset_screen.dart';

/// Глобальная ссылка на [ProfileModel] — используется как
/// `refreshListenable` в [GoRouter], чтобы маршрутизация
/// реагировала на изменения профиля (выбор, выход, сброс).
/// `late final` гарантирует одну инициализацию в [main].
late final ProfileModel _profileModel;

/// Делает асинхронную инициализацию **перед** runApp, чтобы первый
/// кадр уже знал состояние (профиль/онбординг/настройка педагога/
/// длительность сессии) и не было промежуточных «загрузок».
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Блокируем ландшафтную ориентацию — приложение оптимизировано
  // под портретный режим, и боком интерфейс выглядел бы непривычно
  // ребёнку (с РАС изменения привычного формата вызывают стресс).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  _profileModel = ProfileModel();
  await _profileModel.load();

  final progress = ProgressModel();
  final diagnostic = DiagnosticModel();
  final sessionTimer = SessionTimerModel();

  // Если профиль уже выбран — подтягиваем данные именно этого
  // ребёнка. Без этого пришлось бы перезагружать на первом экране,
  // и появлялся бы видимый «прыжок» с нулей на реальные значения.
  if (_profileModel.hasProfile) {
    final id = _profileModel.currentProfileId!;
    await progress.loadForProfile(id);
    await diagnostic.loadForProfile(id);
  }

  await sessionTimer.load();

  // Звук инициализируется отдельно — singleton, инжектится прямо
  // в экранах, а не через Provider (нет реактивности).
  final sound = SoundService();
  await sound.init();

  runApp(
    MultiProvider(
      providers: [
        // ChangeNotifierProvider.value (а не обычный) — потому что
        // экземпляры уже созданы, и мы не хотим, чтобы Provider
        // создавал их заново при перестроениях.
        ChangeNotifierProvider.value(value: _profileModel),
        ChangeNotifierProvider.value(value: progress),
        ChangeNotifierProvider.value(value: diagnostic),
        ChangeNotifierProvider.value(value: sessionTimer),
      ],
      child: EmotionApp(router: _buildRouter(_profileModel)),
    ),
  );
}

/// Конфигурация маршрутизации.
///
/// Реализует **трёхуровневый redirect** для управления потоком
/// первого запуска:
/// 1. Не настроено приложение → `/parent_setup` (педагог задаёт PIN).
/// 2. Нет активного профиля → `/profiles` (выбор/создание).
/// 3. Профиль есть, но не прошёл онбординг → `/onboarding`.
///
/// При любом изменении [ProfileModel] (через `refreshListenable`)
/// GoRouter перепроверяет условия и перенаправляет туда, куда
/// нужно — не нужно вручную делать `context.go` после каждого
/// изменения состояния.
GoRouter _buildRouter(ProfileModel profileModel) {
  return GoRouter(
    initialLocation: profileModel.hasProfile ? '/' : '/profiles',
    refreshListenable: profileModel,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 1. Глобальная настройка педагога должна быть выполнена
      //    в первую очередь — без PIN-кода защита не работает.
      if (!profileModel.parentSetupDone) {
        return loc == '/parent_setup' ? null : '/parent_setup';
      }

      // 2. Без активного профиля показываем выбор/создание.
      if (!profileModel.hasProfile) {
        return loc == '/profiles' ? null : '/profiles';
      }
      // Защита от ручного перехода на /profiles при наличии профиля.
      if (loc == '/profiles') return '/';

      // 3. Онбординг — индивидуальный для каждого ребёнка.
      if (!profileModel.onboardingCompleted) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // Не пускаем обратно на служебные экраны после их прохождения.
      if (loc == '/onboarding' || loc == '/parent_setup') return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfileSelectionScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/parent_setup',
        builder: (context, state) => const ParentSetupScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/module1',
        builder: (context, state) => const Module1Screen(),
      ),
      GoRoute(
        path: '/module2',
        builder: (context, state) => const Module2Screen(),
      ),
      GoRoute(
        path: '/module3',
        builder: (context, state) => const Module3Screen(),
      ),
      // Подтверждение повторного прохождения уже завершённого модуля.
      // Открывается с главного экрана вместо прямого захода в модуль,
      // если progress.isModuleCompleted(moduleId) == true.
      GoRoute(
        path: '/module_restart/:moduleId',
        builder: (context, state) => ModuleRestartScreen(
          moduleId: state.pathParameters['moduleId'] ?? 'module1',
        ),
      ),
      GoRoute(
        path: '/reward',
        builder: (context, state) {
          // extra — non-typed map, фолбэк на пустой словарь
          // и дефолт 'module1' защищают от прямого перехода
          // без параметров.
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RewardScreen(
            from: (extra['from'] as String?) ?? 'module1',
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        // Динамический параметр пути — фаза диагностики (pre/post).
        path: '/diagnostic/:phase',
        builder: (context, state) {
          final phase = state.pathParameters['phase'] ?? 'pre';
          return DiagnosticScreen(phase: phase);
        },
      ),
      GoRoute(
        path: '/diagnostic_result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return DiagnosticResultScreen(
            session: extra['session'] as DiagnosticSession,
            phase: extra['phase'] as String? ?? 'pre',
          );
        },
      ),
      GoRoute(
        path: '/handoff',
        builder: (context, state) => const HandoffScreen(),
      ),
      // Маршрут конца сессии по таймеру. Тот же handoff-экран,
      // но в режиме sessionExpired — тексты ребёнку про перерыв,
      // у взрослого — сводка прогресса вместо результата программы.
      GoRoute(
        path: '/session_end',
        builder: (context, state) =>
            const HandoffScreen(mode: HandoffMode.sessionExpired),
      ),
      // Восстановление PIN. Доступен из PIN-gate (/settings,
      // /handoff) без проверки PIN — это и есть точка обхода
      // забытого PIN. Защита — секретный ответ на контрольный вопрос.
      // Параметр `mode` (recoverPin/setQuestion) приходит через extra.
      GoRoute(
        path: '/pin_reset',
        builder: (context, state) {
          final mode =
              (state.extra as PinResetMode?) ?? PinResetMode.recoverPin;
          return PinResetScreen(mode: mode);
        },
      ),
    ],
  );
}

/// Корневой виджет приложения.
///
/// Использует [MaterialApp.router] для интеграции с GoRouter,
/// и **builder** с [Consumer<SessionTimerModel>] для:
///   1. глобального баннера «Скоро перерыв» (за 2 минуты до конца);
///   2. реакции на истечение таймера — навигация на `/session_end`
///      (handoff-экран в режиме sessionExpired), чтобы прервать
///      занятие полностью, а не просто показать оверлей.
///
/// Прогресс ребёнка к этому моменту уже сохранён: `submitAnswer`
/// пишет в `ProgressModel` сразу при ответе, `advanceTask` сохраняет
/// taskIndex в SharedPreferences. Никакой дополнительной логики
/// сохранения здесь не нужно — просто прерываем UI.
class EmotionApp extends StatelessWidget {
  final GoRouter router;
  const EmotionApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Мир эмоций',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      // builder оборачивает каждый маршрут — место для глобальных
      // эффектов (баннер предупреждения и реакция на конец сессии),
      // которые не должны зависеть от текущего экрана.
      builder: (context, child) {
        return Consumer<SessionTimerModel>(
          builder: (context, timer, _) {
            // При истечении времени уводим пользователя на handoff
            // в режиме sessionExpired. Делаем через postFrameCallback
            // (внутри build нельзя вызывать router.go), и сразу
            // сбрасываем флаг expired через timer.stop(), чтобы
            // не было повторной навигации на следующем notify.
            if (timer.expired) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                timer.stop();
                router.go('/session_end');
              });
            }
            return Stack(
              children: [
                child!,
                // За 2 минуты до конца сессии — мягкое предупреждение
                // в верхней части экрана.
                if (timer.showWarning)
                  _TimerWarningBanner(timer: timer),
                // Сессия только что истекла, но текущее задание ещё
                // не завершено — показываем баннер без авто-скрытия,
                // чтобы ребёнок понимал, что после нажатия «Дальше»
                // занятие закончится.
                if (timer.pendingExpiration)
                  const _PendingExpirationBanner(),
              ],
            );
          },
        );
      },
    );
  }
}

/// Баннер «Скоро перерыв» — выезжает сверху за 2 минуты до конца
/// сессии. Автоматически скрывается через 6 секунд, или сразу
/// при тапе по баннеру.
///
/// Цель — мягко предупредить ребёнка о приближении перерыва,
/// чтобы конец занятия не был внезапным (для детей с РАС
/// предсказуемость = снижение тревоги).
class _TimerWarningBanner extends StatefulWidget {
  final SessionTimerModel timer;
  const _TimerWarningBanner({required this.timer});

  @override
  State<_TimerWarningBanner> createState() => _TimerWarningBannerState();
}

class _TimerWarningBannerState extends State<_TimerWarningBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    // Автоскрытие через 6с. mounted-проверка обязательна —
    // баннер мог быть удалён вручную к этому моменту.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) widget.timer.dismissWarning();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        // Material нужен, потому что баннер живёт в Stack поверх
        // child внутри MaterialApp.router.builder — вне Scaffold.
        // Без Material у Text нет DefaultTextStyle, и Flutter рисует
        // дебаг-подчёркивание (жёлтые двойные линии на эмодзи).
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              // Тап скрывает баннер сразу — удобно для педагога,
              // который уже увидел сигнал.
              onTap: widget.timer.dismissWarning,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('🐱', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        border: Border.all(
                          color: const Color(0xFFFFD0A8),
                          width: 1.5,
                        ),
                        // То же скругление «хвостика», что и у HelperCat —
                        // единый визуальный язык подсказок Апельсина.
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Скоро перерыв — осталось 2 минуты',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textLight,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Баннер «Время сессии вышло» — показывается, когда основной
/// отсчёт дошёл до 0, но текущее задание ещё не завершено.
/// Без авто-скрытия и без кнопки «закрыть»: ребёнок должен видеть
/// сообщение постоянно, пока не нажмёт «Дальше» (это вызовет
/// переход на /session_end через `markExpired` в advanceTask).
///
/// Цвет — приглушённый красно-оранжевый, чтобы отличаться от
/// мягкого предупреждения за 2 минуты до конца ([_TimerWarningBanner]).
/// Не использует `Future.delayed` — баннер сам исчезнет, когда
/// модель перейдёт в `expired` и Consumer перестроится.
class _PendingExpirationBanner extends StatefulWidget {
  const _PendingExpirationBanner();

  @override
  State<_PendingExpirationBanner> createState() =>
      _PendingExpirationBannerState();
}

class _PendingExpirationBannerState extends State<_PendingExpirationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        // Material обязателен — баннер вне Scaffold (см. комментарий
        // в _TimerWarningBanner). Без него Flutter подчёркивает
        // эмодзи дебаг-линиями.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('🐱', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        // Тёплый персиковый — отличается от мягкого
                        // accent в warning, но не такой агрессивный,
                        // как чистый красный (для ребёнка с РАС важно
                        // избегать резких цветов даже в «срочных»
                        // сообщениях).
                        color: const Color(0xFFFFE0D6),
                        border: Border.all(
                          color: const Color(0xFFFFB59A),
                          width: 1.5,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        'Время вышло — закончи это задание, '
                        'и мы сделаем перерыв 🌿',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Раньше здесь был _SessionExpiredOverlay — модальный оверлей,
// который перекрывал UI и просил «продолжить». Заменён на полный
// переход на handoff-экран в режиме sessionExpired (см. builder
// в EmotionApp выше), чтобы корректно прерывать занятие и
// показывать ребёнку завершённый экран с передачей устройства
// взрослому.
