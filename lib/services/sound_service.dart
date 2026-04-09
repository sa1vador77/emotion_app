import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис воспроизведения звуковых эффектов.
///
/// Реализован как singleton: один [AudioPlayer] на всё приложение,
/// что гарантирует прерывание предыдущего звука при воспроизведении
/// нового. Это важно для интерфейса с детьми с РАС — наложение
/// нескольких звуков создаёт сенсорный хаос.
///
/// Дизайн звукового сопровождения учитывает сенсорные особенности РАС:
/// - все звуки **мягкие**, без резких атак;
/// - **нет неожиданных** или громких эффектов;
/// - звук ошибки **нейтральный**, не «бузер» — чтобы не вызывать
///   эмоциональной реакции;
/// - возможность полного отключения и регулировки громкости;
/// - умеренная громкость по умолчанию (60%).
class SoundService {
  static final SoundService _instance = SoundService._internal();

  factory SoundService() => _instance;
  SoundService._internal();

  /// Единственный плеер. Метод [_play] всегда вызывает [_player.stop]
  /// перед началом нового звука, чтобы прервать предыдущий.
  final AudioPlayer _player = AudioPlayer();

  bool _soundEnabled = true;
  double _volume = 0.6;

  bool get soundEnabled => _soundEnabled;

  double get volume => _volume;

  /// Загружает сохранённые настройки звука и применяет громкость
  /// к плееру. Вызывается один раз при инициализации приложения.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _volume = prefs.getDouble('volume') ?? 0.6;
    await _player.setVolume(_volume);
  }

  /// Звук правильного ответа — мягкий приятный сигнал.
  /// Подкрепление успеха в обучении с РАС критически важно.
  Future<void> playCorrect() async {
    if (!_soundEnabled) return;
    await _play('correct.wav');
  }

  /// Звук ошибки — намеренно **нейтральный**, без негативной
  /// эмоциональной окраски. Дети с РАС болезненно реагируют на
  /// «штрафные» звуки, что может привести к отказу от приложения.
  Future<void> playWrong() async {
    if (!_soundEnabled) return;
    await _play('wrong_soft.wav');
  }

  /// Звук получения «пузырька» — мелкое поощрение за активность.
  Future<void> playBubble() async {
    if (!_soundEnabled) return;
    await _play('bubble_pop.wav');
  }

  /// Тихий звук перехода между экранами — для плавности
  /// и подсказки об изменении контекста.
  Future<void> playTransition() async {
    if (!_soundEnabled) return;
    await _play('transition.wav');
  }

  /// Звук завершения модуля — заметнее остальных, отмечает
  /// достижение цели.
  Future<void> playSuccess() async {
    if (!_soundEnabled) return;
    await _play('success.wav');
  }

  /// Внутренний метод воспроизведения. Прерывает предыдущий звук
  /// перед запуском нового и **молча проглатывает любые ошибки**:
  /// отсутствие файла или сбой плеера не должны прерывать
  /// взаимодействие ребёнка с приложением.
  Future<void> _play(String filename) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$filename'));
    } catch (_) {
      // Намеренно проглатываем — лучше тишина, чем сломанный UX.
    }
  }

  /// Меняет настройку «звук вкл/выкл». Сохраняется глобально.
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', enabled);
  }

  /// Меняет громкость с защитой от выхода за диапазон [0; 1].
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', _volume);
  }

  /// Освобождает ресурсы плеера. Вызывать при завершении приложения.
  void dispose() {
    _player.dispose();
  }
}
