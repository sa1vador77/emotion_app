import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../models/profile_model.dart';

/// Онбординг. Показывается один раз при первом входе **каждого профиля**
/// (статус `onboardingCompleted` per-profile в [ProfileModel]) — в семье
/// разные дети впервые попадают в приложение в разное время.
/// Кнопка «Пропустить» — для педагога при повторном знакомстве.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  /// Порядок слайдов — нарративная прогрессия: первый знакомит с персонажем
  /// (снижает тревожность), дальше — что делать, как отвечать, мотивация.
  static const _slides = [
    _Slide(
      emoji: '🐱',
      emojiSize: 80,
      title: 'Привет! Я — кот Апельсин!',
      body:
          'Я помогу тебе научиться понимать эмоции — что чувствуют люди на фотографиях.',
      bgColor: Color(0xFFFFF5EE),
      accentColor: AppTheme.accent,
    ),
    _Slide(
      emoji: '👀',
      emojiSize: 72,
      title: 'Смотри на лицо',
      body:
          'Я покажу тебе фотографию человека. Посмотри внимательно на его лицо.',
      bgColor: Color(0xFFEBF4FF),
      accentColor: AppTheme.blue,
    ),
    _Slide(
      emoji: '☝️',
      emojiSize: 72,
      title: 'Выбери название',
      body:
          'Ты увидишь несколько кнопок с названиями эмоций. Нажми на ту, которая подходит.',
      bgColor: Color(0xFFE8F9EE),
      accentColor: AppTheme.green,
    ),
    _Slide(
      emoji: '🏆',
      emojiSize: 72,
      title: 'Ты становишься лучше!',
      body:
          'С каждым занятием ты будешь узнавать эмоции всё точнее и быстрее. Просто старайся!',
      bgColor: Color(0xFFF0ECFF),
      accentColor: AppTheme.purple,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Фиксирует прохождение онбординга и доверяет GoRouter
  /// перенаправить на главный экран (через refreshListenable).
  Future<void> _finish() async {
    await context.read<ProfileModel>().markOnboardingCompleted();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      // Фон всего экрана меняется вместе со слайдом — даёт
      // ощущение целостного цветового перехода.
      backgroundColor: slide.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Кнопка «Пропустить» в правом верхнем — для педагога.
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Пропустить',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Индикатор точек: активная точка вытягивается в полоску
            // длиной 24px — это понятнее для детей, чем равные точки.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? slide.accentColor
                        : slide.accentColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Основная CTA — её цвет тоже меняется со слайдом.
            // Текст «Далее →» меняется на «Начать!» на последнем
            // слайде, чтобы было понятно, что это финиш онбординга.
            ResponsiveContainer(
              padding: EdgeInsets.symmetric(horizontal: context.gutter + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: slide.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'Начать!' : 'Далее →',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Элементы слайда появляются со ступенчатой задержкой (fade + slide up)
/// — создаёт ощущение «жизни» статичной картинки.
class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(horizontal: context.gutter + 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(slide.emoji, style: TextStyle(fontSize: slide.emojiSize))
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.7, 0.7), duration: 400.ms, curve: Curves.easeOut),
          const SizedBox(height: 32),
          Text(
            slide.title,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 350.ms)
              .slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 350.ms),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textMuted,
                ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 250.ms, duration: 350.ms)
              .slideY(begin: 0.2, end: 0, delay: 250.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

/// Структура одного слайда онбординга — собранные вместе данные,
/// удобно держать в `const`-массиве и не плодить отдельные
/// классы для каждого слайда.
class _Slide {
  final String emoji;
  final double emojiSize;
  final String title;
  final String body;
  final Color bgColor;
  final Color accentColor;

  const _Slide({
    required this.emoji,
    required this.emojiSize,
    required this.title,
    required this.body,
    required this.bgColor,
    required this.accentColor,
  });
}
