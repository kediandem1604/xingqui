import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'engine_base.dart';
import 'engine_parser.dart';
import '../core/logger.dart';

/// Pikafish engine with custom UCI->UCCI conversion
class PikafishEngine implements IEngine {
  final String executablePath;
  Process? _proc;
  final _ctrl = StreamController<EngineMessage>.broadcast();
  String _engineName = 'Pikafish';
  Stream<String>? _stdoutLines;

  PikafishEngine(this.executablePath);

  @override
  String get name => _engineName;

  @override
  String get protocol => 'UCCI (Pikafish with custom conversion)';

  @override
  Stream<EngineMessage> get messages => _ctrl.stream;

  @override
  Future<void> start() async {
    try {
      await AppLogger().log('Pikafish starting engine at: $executablePath');

      // Check if executable exists
      if (!File(executablePath).existsSync()) {
        throw Exception('Pikafish executable not found at: $executablePath');
      }

      // Ensure the engine starts in its own directory so DLLs/NNUE files resolve
      final workingDir = File(executablePath).parent.path;
      await AppLogger().log('Pikafish working directory: $workingDir');

      _proc = await Process.start(
        executablePath,
        [],
        runInShell: false,
        workingDirectory: workingDir,
      );

      await AppLogger().log('Pikafish process started with PID: ${_proc!.pid}');

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
            AppLogger().log('Pikafish stderr: $line');
            _ctrl.add(ErrorMessage(line));
          });

      // Initialize UCI protocol
      await AppLogger().log('Pikafish sending: uci');
      _proc!.stdin.writeln('uci');
      await _waitFor('uciok', timeout: const Duration(seconds: 10));

      // Check if Pikafish supports Xiangqi by testing a simple position
      await AppLogger().log('Testing Pikafish Xiangqi support...');
      _proc!.stdin.writeln('position startpos');
      _proc!.stdin.writeln('go depth 1');
      try {
        await _waitFor('bestmove', timeout: const Duration(seconds: 3));
        await AppLogger().log('Pikafish Xiangqi test successful');
      } catch (e) {
        await AppLogger().log('Pikafish Xiangqi test failed: $e');
        // Continue anyway, but log the issue
      }

      // Add warning that Pikafish is Chess engine
      await AppLogger().log(
        'WARNING: Pikafish is a Chess engine, not Xiangqi. Analysis may not be accurate.',
      );

      // If the engine supports NNUE EvalFile, point it to the local file
      final nnuePath = File(
        '${File(executablePath).parent.path}${Platform.pathSeparator}pikafish.nnue',
      );
      if (await nnuePath.exists()) {
        await AppLogger().log('Pikafish setting EvalFile to: ${nnuePath.path}');
        _proc!.stdin.writeln('setoption name EvalFile value ${nnuePath.path}');
      }

      await AppLogger().log('Pikafish sending: isready');
      _proc!.stdin.writeln('isready');
      await _waitFor('readyok', timeout: const Duration(seconds: 10));
      await AppLogger().log('Pikafish engine ready');
    } catch (e) {
      await AppLogger().error('Pikafish start error', e);
      rethrow;
    }
  }

  void _handleEngineOutput(String line) {
    AppLogger().log('Pikafish output: $line');

    if (line.startsWith('id name ')) {
      _engineName = EngineParser.parseEngineName(line) ?? 'Pikafish';
    } else if (line.startsWith('info')) {
      // Convert UCI info to UCCI format
      final convertedInfo = _convertInfoLine(line);
      if (convertedInfo != null) {
        _ctrl.add(InfoMessage(convertedInfo));
      }
    } else if (line.startsWith('bestmove')) {
      // Convert UCI bestmove to UCCI format
      final convertedBestMove = _convertBestMove(line);
      if (convertedBestMove != null) {
        _ctrl.add(BestMoveMessage(convertedBestMove, line));
      } else {
        // Even if conversion fails, still send the raw bestmove
        AppLogger().log(
          'Pikafish bestmove conversion failed, using raw: $line',
        );
        _ctrl.add(BestMoveMessage(line, line));
      }
    } else if (line.contains('readyok')) {
      _ctrl.add(ReadyMessage(line));
    } else if (line.contains('uciok')) {
      _ctrl.add(UciOkMessage(line));
    } else if (line.trim().isNotEmpty) {
      // Log any other non-empty output for debugging
      AppLogger().log('Pikafish other output: $line');
    }
  }

  /// Convert UCI info line to UCCI format
  String? _convertInfoLine(String line) {
    // For now, pass through info lines as-is
    // Pikafish already returns xiangqi notation, so no conversion needed
    return line;
  }

  /// Convert UCI bestmove to UCCI format
  String? _convertBestMove(String line) {
    AppLogger().log('Converting bestmove: $line');
    final parts = line.split(' ');
    final bestMoveIndex = parts.indexOf('bestmove');
    if (bestMoveIndex >= 0 && bestMoveIndex + 1 < parts.length) {
      final move = parts[bestMoveIndex + 1];
      AppLogger().log('Extracted move: $move');
      if (move != '(none)' && move.length == 4) {
        // Pikafish already returns xiangqi notation, just validate and return
        if (_isValidXiangqiMove(move)) {
          AppLogger().log('Valid xiangqi move: $move');
          return move;
        } else {
          AppLogger().log('Invalid xiangqi move: $move');
        }
      } else {
        AppLogger().log('Move format invalid: $move (length: ${move.length})');
      }
    } else {
      AppLogger().log('Could not find bestmove in line: $line');
    }
    return null;
  }

  /// Validate if a move is a valid xiangqi move
  bool _isValidXiangqiMove(String move) {
    if (move.length != 4) return false;

    // Check if move uses valid xiangqi coordinates
    // Files: a-i (0-8), Ranks: 0-9
    final fromFile = move[0].codeUnitAt(0) - 97; // a=0, b=1, etc.
    final fromRank = int.tryParse(move[1]) ?? -1;
    final toFile = move[2].codeUnitAt(0) - 97;
    final toRank = int.tryParse(move[3]) ?? -1;

    // Validate xiangqi board bounds
    return fromFile >= 0 &&
        fromFile <= 8 &&
        fromRank >= 0 &&
        fromRank <= 9 &&
        toFile >= 0 &&
        toFile <= 8 &&
        toRank >= 0 &&
        toRank <= 9;
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
    AppLogger().log('Pikafish sending: $cmd');
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
    await AppLogger().log('Pikafish setting MultiPV to $n');
    // Only set MultiPV if it's greater than 1
    if (n > 1) {
      send('setoption name MultiPV value $n');
      send('isready');
      await _waitFor('readyok');
    } else {
      // For MultiPV = 1, just ensure it's set to 1 (default)
      send('setoption name MultiPV value 1');
      send('isready');
      await _waitFor('readyok');
    }
  }

  @override
  Future<void> newGame() async {
    send('ucinewgame');
    send('isready');
    await _waitFor('readyok');
  }

  @override
  Future<void> setPosition(String fen, List<String> moves) async {
    await AppLogger().log(
      'Pikafish setting position - FEN: $fen, Moves: ${moves.join(' ')}',
    );

    // Always use startpos for reliability; Pikafish is a chess engine
    final movesStr = moves.isNotEmpty ? ' moves ${moves.join(' ')}' : '';
    final startCmd = 'position startpos$movesStr';
    await AppLogger().log('Pikafish position command: $startCmd');
    send(startCmd);
    // Ensure engine applies the position
    send('isready');
    await _waitFor('readyok', timeout: const Duration(seconds: 3));
  }

  @override
  Future<void> go({int? depth, int? movetimeMs}) async {
    if (depth != null) {
      await AppLogger().log('Pikafish go depth $depth');
      send('go depth $depth');
    } else if (movetimeMs != null) {
      await AppLogger().log('Pikafish go movetime $movetimeMs');
      send('go movetime $movetimeMs');
    } else {
      await AppLogger().log('Pikafish go depth 12 (default)');
      send('go depth 12');
    }

    // Add a timeout mechanism to ensure we get a response
    // Scale timeout by requested depth (approx 2s per depth) and movetime buffer
    int depthBased = depth != null ? depth * 2 : 0;
    int timeBased = (movetimeMs ?? 1000) ~/ 1000 + 10; // +10s buffer
    final timeoutSeconds = (depthBased > timeBased ? depthBased : timeBased)
        .clamp(10, 120); // clamp to sane bounds
    try {
      await _waitFor('bestmove', timeout: Duration(seconds: timeoutSeconds));
    } catch (e) {
      AppLogger().log('Pikafish go timeout after ${timeoutSeconds}s: $e');
      // Try with lower depth as fallback
      await AppLogger().log('Pikafish retry with depth 8...');
      send('go depth 8');
      try {
        await _waitFor('bestmove', timeout: const Duration(seconds: 8));
      } catch (e2) {
        AppLogger().log('Pikafish retry also failed: $e2');
        // Send stop command to engine
        send('stop');
        // Send a fallback bestmove if engine doesn't respond
        _ctrl.add(BestMoveMessage('a0a0', 'bestmove a0a0'));
      }
    }
  }
}
