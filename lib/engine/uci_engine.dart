import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'engine_base.dart';
import 'engine_parser.dart';

class UciEngine implements IEngine {
  final String executablePath;
  Process? _proc;
  final _ctrl = StreamController<EngineMessage>.broadcast();
  String _engineName = 'UCI Engine';
  Stream<String>? _stdoutLines; // broadcast stdout lines

  UciEngine(this.executablePath);

  @override
  String get name => _engineName;

  @override
  String get protocol => 'UCI';

  @override
  Stream<EngineMessage> get messages => _ctrl.stream;

  @override
  Future<void> start() async {
    try {
      // Ensure the engine starts in its own directory so DLLs/NNUE files resolve
      final workingDir = File(executablePath).parent.path;
      _proc = await Process.start(
        executablePath,
        [],
        runInShell: false,
        workingDirectory: workingDir,
      );

      // Listen to engine output
      _stdoutLines = _proc!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      _stdoutLines!.listen((line) {
        _handleEngineOutput(line);
      });

      // Listen to engine errors
      _proc!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _ctrl.add(ErrorMessage(line));
          });

      // Initialize UCI protocol
      _proc!.stdin.writeln('uci');
      await _waitFor('uciok', timeout: const Duration(seconds: 10));

      // Try to set Xiangqi variant (engines that don't support it will ignore/err to stderr)
      _proc!.stdin.writeln('setoption name UCI_Variant value xiangqi');

      // If the engine supports NNUE EvalFile, point it to the local file
      final nnuePath = File(
        '${File(executablePath).parent.path}${Platform.pathSeparator}pikafish.nnue',
      );
      if (await nnuePath.exists()) {
        _proc!.stdin.writeln('setoption name EvalFile value ${nnuePath.path}');
      }

      _proc!.stdin.writeln('isready');
      await _waitFor('readyok', timeout: const Duration(seconds: 10));

      print('UCI Engine started successfully');
    } catch (e) {
      print('Failed to start UCI engine: $e');
      rethrow;
    }
  }

  void _handleEngineOutput(String line) {
    if (line.startsWith('id name ')) {
      _engineName = EngineParser.parseEngineName(line) ?? 'UCI Engine';
    } else if (line.startsWith('info')) {
      _ctrl.add(InfoMessage(line));
    } else if (line.startsWith('bestmove')) {
      final bestMove = EngineParser.parseBestMove(line);
      _ctrl.add(BestMoveMessage(bestMove, line));
    } else if (line.contains('readyok')) {
      _ctrl.add(ReadyMessage(line));
    } else if (line.contains('uciok')) {
      _ctrl.add(UciOkMessage(line));
    }
  }

  Future<void> _waitFor(
    String token, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<void>();
    late StreamSubscription sub;

    sub = (_stdoutLines ?? const Stream<String>.empty()).listen((line) {
      if (line.contains(token)) {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Send a nudge to ensure engine is responsive
    _proc!.stdin.writeln();

    try {
      await completer.future.timeout(timeout);
    } catch (e) {
      sub.cancel();
      throw Exception(
        'Engine did not respond with $token within ${timeout.inSeconds} seconds',
      );
    }
  }

  @override
  void send(String cmd) {
    _proc?.stdin.writeln(cmd);
  }

  @override
  Future<void> stop() async {
    _proc?.stdin.writeln('quit');
    await _proc?.exitCode;
    await _ctrl.close();
  }

  @override
  Future<void> setMultiPV(int n) async {
    send('setoption name MultiPV value $n');
    send('isready');
    await _waitFor('readyok');
  }

  @override
  Future<void> newGame() async {
    send('ucinewgame');
    send('isready');
    await _waitFor('readyok');
  }

  @override
  Future<void> setPosition(String fen, List<String> moves) async {
    final movesStr = moves.isNotEmpty ? ' moves ${moves.join(' ')}' : '';
    send('position fen $fen$movesStr');
  }

  @override
  Future<void> go({int? depth, int? movetimeMs}) async {
    if (depth != null) {
      send('go depth $depth');
    } else if (movetimeMs != null) {
      send('go movetime $movetimeMs');
    } else {
      send('go depth 12');
    }
  }
}
