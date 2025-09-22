import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/engine_base.dart';
import '../../engine/engine_parser.dart';
import '../../engine/uci_engine.dart';
import '../../engine/ucci_engine.dart';
import '../../core/fen.dart';
import '../../core/xiangqi_rules.dart';
import '../../core/logger.dart';
import '../../services/game_status_service.dart';
import '../../widgets/game_notification.dart';

// Best line information
class BestLine {
  final int index; // 1..N
  final int depth;
  final int scoreCp;
  final List<String> pv;

  const BestLine(this.index, this.depth, this.scoreCp, this.pv);

  @override
  String toString() {
    return 'PV$index: depth=$depth, score=${scoreCp}cp, moves=${pv.join(' ')}';
  }

  String get scoreString {
    if (scoreCp > 0) {
      return '+${scoreCp / 100}';
    } else {
      return '${scoreCp / 100}';
    }
  }

  String get firstMove => pv.isNotEmpty ? pv.first : '';
}

// Board state
class BoardState {
  final String fen;
  final List<String> moves; // history in UCI-like coord
  final int pointer; // current index in history
  final bool redToMove;
  final List<BestLine> bestLines;
  final int multiPv; // 1..3
  final bool canBack;
  final bool canNext;
  final String? selectedEngine;
  final bool isEngineThinking;
  final String? engineError; // last engine error message to display
  final String? enginePath; // resolved engine path for diagnostics

  // Piece selection state
  final int? selectedFile; // 0-8
  final int? selectedRank; // 0-9
  final List<Offset> possibleMoves; // list of possible move destinations
  // Pending move animation (before FEN/state updates)
  final MoveAnimation? pendingAnimation;
  final List<GameNotification> notifications;

  const BoardState({
    required this.fen,
    required this.moves,
    required this.pointer,
    required this.redToMove,
    required this.bestLines,
    required this.multiPv,
    required this.canBack,
    required this.canNext,
    this.selectedEngine,
    this.isEngineThinking = false,
    this.engineError,
    this.enginePath,
    this.selectedFile,
    this.selectedRank,
    this.possibleMoves = const [],
    this.pendingAnimation,
    this.notifications = const [],
  });

  BoardState copyWith({
    String? fen,
    List<String>? moves,
    int? pointer,
    bool? redToMove,
    List<BestLine>? bestLines,
    int? multiPv,
    bool? canBack,
    bool? canNext,
    String? selectedEngine,
    bool? isEngineThinking,
    String? engineError,
    String? enginePath,
    int? selectedFile,
    int? selectedRank,
    List<Offset>? possibleMoves,
    MoveAnimation? pendingAnimation,
    List<GameNotification>? notifications,
    // explicit clear flags
    bool clearPendingAnimation = false,
    bool clearSelection = false,
  }) => BoardState(
    fen: fen ?? this.fen,
    moves: moves ?? this.moves,
    pointer: pointer ?? this.pointer,
    redToMove: redToMove ?? this.redToMove,
    bestLines: bestLines ?? this.bestLines,
    multiPv: multiPv ?? this.multiPv,
    canBack: canBack ?? this.canBack,
    canNext: canNext ?? this.canNext,
    selectedEngine: selectedEngine ?? this.selectedEngine,
    isEngineThinking: isEngineThinking ?? this.isEngineThinking,
    engineError: engineError ?? this.engineError,
    enginePath: enginePath ?? this.enginePath,
    selectedFile: clearSelection ? null : (selectedFile ?? this.selectedFile),
    selectedRank: clearSelection ? null : (selectedRank ?? this.selectedRank),
    possibleMoves: possibleMoves ?? this.possibleMoves,
    pendingAnimation: clearPendingAnimation
        ? null
        : (pendingAnimation ?? this.pendingAnimation),
    notifications: notifications ?? this.notifications,
  );

  static BoardState initial() => BoardState(
    fen: defaultXqFen,
    moves: const [],
    pointer: 0,
    redToMove: true,
    bestLines: const [],
    multiPv: 1,
    canBack: false,
    canNext: false,
    selectedEngine: 'EleEye',
    engineError: null,
    enginePath: null,
    selectedFile: null,
    selectedRank: null,
    possibleMoves: const [],
    pendingAnimation: null,
  );
}

// Board controller using Riverpod
class BoardController extends StateNotifier<BoardState> {
  IEngine? _engine;
  StreamSubscription? _engineSubscription;
  Timer? _thinkingWatchdog;
  Timer? _animationAutoCommit;
  Timer? _animationWatchdog;
  // EleEye MultiPV support via iterative banmoves
  bool _eleEyeBanMode = false;
  int _banIteration = 0; // 0-based; displayed as index = _banIteration + 1
  final List<String> _bannedFirstMoves = [];
  Completer<void>? _bestMoveOnce;
  bool _isCommittingAnim = false;
  String? _recentAppliedMove;
  DateTime? _recentAppliedAt;
  DateTime? _pendingSince;

  BoardController() : super(BoardState.initial());

  Future<void> init() async {
    try {
      await AppLogger.ensureInitialized();
      await AppLogger().log('App init start');
      // Initialize with default engine
      await _switchEngine(state.selectedEngine ?? 'EleEye');
      await AppLogger().log('App init done');
    } catch (e, st) {
      print('Failed to initialize engine: $e');
      await AppLogger().error('init failed', e, st);
      // Set a safe state without engine
      state = state.copyWith(
        selectedEngine: null,
        isEngineThinking: false,
        bestLines: [],
        engineError: e.toString(),
      );
    }
  }

  Future<void> _switchEngine(String engineName) async {
    String? previousEngine = state.selectedEngine;
    try {
      await AppLogger().log('Switching engine to: ' + engineName);
      // Stop current engine
      if (_engine != null) {
        await AppLogger().log('Stopping previous engine...');
        await _engine!.stop();
        await AppLogger().log('Previous engine stopped');
      }
      _engineSubscription?.cancel();

      // Clear any pending UI animation when changing engines
      state = state.copyWith(pendingAnimation: null, possibleMoves: []);

      // Create new engine
      await AppLogger().log('Creating new engine: $engineName');
      switch (engineName) {
        case 'Pikafish':
          final path = _resolveEnginePath('engines/pikafish/win/pikafish.exe');
          await AppLogger().log('Pikafish path resolved: $path');
          if (!File(path).existsSync()) {
            await AppLogger().error('Pikafish not found', path);
            throw Exception('Pikafish executable not found at: ' + path);
          }
          _engine = UciEngine(path);
          await AppLogger().log('UciEngine created for Pikafish');
          break;
        case 'EleEye':
          // Prefer the freshly built eleeye_new.exe if present
          final preferredPath = _resolveEnginePath(
            'engines/eleeye/win/eleeye_new.exe',
          );
          final fallbackPath = _resolveEnginePath(
            'engines/eleeye/win/eleeye.exe',
          );
          final path = File(preferredPath).existsSync()
              ? preferredPath
              : fallbackPath;
          await AppLogger().log('EleEye path resolved: $path');
          if (!File(path).existsSync()) {
            await AppLogger().error('EleEye not found', path);
            throw Exception('EleEye executable not found at: ' + path);
          }
          _engine = UcciEngine(path);
          await AppLogger().log('UcciEngine created for EleEye');
          break;
        default:
          throw Exception('Unknown engine: $engineName');
      }

      // Start engine
      await AppLogger().log('Starting engine...');
      await _engine!.start();
      await AppLogger().log('Engine started successfully');

      // Listen to engine messages
      _engineSubscription = _engine!.messages.listen(
        _handleEngineMessage,
        onError: (e) async {
          await AppLogger().error('Engine stream error', e);
        },
        onDone: () async {
          await AppLogger().log('Engine stream closed');
        },
      );

      // Update state
      state = state.copyWith(
        selectedEngine: engineName,
        engineError: null,
        enginePath: (_engine is UciEngine || _engine is UcciEngine)
            ? (engineName == 'Pikafish'
                  ? _resolveEnginePath('engines/pikafish/win/pikafish.exe')
                  : (File(
                          _resolveEnginePath(
                            'engines/eleeye/win/eleeye_new.exe',
                          ),
                        ).existsSync()
                        ? _resolveEnginePath(
                            'engines/eleeye/win/eleeye_new.exe',
                          )
                        : _resolveEnginePath('engines/eleeye/win/eleeye.exe')))
            : null,
      );

      // Initialize game
      await _initializeGame();
      await AppLogger().log('Engine initialized');
    } catch (e) {
      print('Failed to switch to engine $engineName: $e');
      await AppLogger().error('Switch engine failed: ' + engineName, e);
      // Revert to previous engine selection and safe state
      state = state.copyWith(
        selectedEngine: previousEngine,
        isEngineThinking: false,
        bestLines: [],
        engineError: e.toString(),
      );
      rethrow;
    }
  }

  // Try to resolve engine executable path both when running from project root
  // and when running the packaged Windows exe (build/windows/x64/runner/Release).
  // It searches from the current executable directory upwards for the provided
  // relative path, and falls back to the given relative path if not found.
  String _resolveEnginePath(String relativePath) {
    // Normalize separators for the current platform
    final normalizedRelative = relativePath.replaceAll(
      '/',
      Platform.pathSeparator,
    );

    // 1) Direct relative (works in `flutter run` from project root)
    final direct = File(normalizedRelative);
    if (direct.existsSync()) {
      return direct.path;
    }

    // 2) From the executable directory walking up a few levels
    try {
      final exe = File(Platform.resolvedExecutable);
      Directory dir = exe.parent; // exe directory
      for (int i = 0; i < 8; i++) {
        final candidate = File(
          '${dir.path}${Platform.pathSeparator}$normalizedRelative',
        );
        if (candidate.existsSync()) {
          return candidate.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break; // reached filesystem root
        dir = parent;
      }
    } catch (_) {
      // ignore and fall through
    }

    // 3) As a last resort, return the original relative path (will likely fail,
    // but preserves previous behavior for debugging messages)
    return normalizedRelative;
  }

  void _startThinkingWatchdog() {
    _thinkingWatchdog?.cancel();
    _thinkingWatchdog = Timer(const Duration(seconds: 6), () {
      // If still thinking after 3s, surface a helpful message
      if (state.isEngineThinking) {
        state = state.copyWith(
          engineError:
              'Engine took too long to respond. Check engine files/DLLs and permissions.',
        );
      }
    });
  }

  void _handleEngineMessage(EngineMessage message) {
    if (message is InfoMessage) {
      AppLogger().log('Engine info: ' + message.raw);
      final pv = EngineParser.parseInfoPv(message.raw);
      if (pv != null) {
        final list = [...state.bestLines];

        // Replace or insert based on multipv index
        final idx = _eleEyeBanMode ? (_banIteration + 1) : pv.multipv;
        final bl = BestLine(idx, pv.depth, pv.scoreCp, pv.pvMoves);

        final existingIndex = list.indexWhere((e) => e.index == idx);
        if (existingIndex >= 0) {
          list[existingIndex] = bl;
        } else {
          list.add(bl);
        }

        // Sort by index
        list.sort((a, b) => a.index.compareTo(b.index));
        state = state.copyWith(bestLines: list);
      }
    } else if (message is BestMoveMessage) {
      AppLogger().log('Engine bestmove: ' + message.bestMove);
      state = state.copyWith(isEngineThinking: false);
      _thinkingWatchdog?.cancel();
      // Signal a single search cycle completed when using EleEye banmoves loop
      if (_bestMoveOnce != null && !(_bestMoveOnce!.isCompleted)) {
        _bestMoveOnce!.complete();
      }
    } else if (message is ErrorMessage) {
      AppLogger().error('Engine error', message.raw);
      state = state.copyWith(engineError: message.raw);
    }
  }

  Future<void> _initializeGame() async {
    if (_engine == null) return;

    await AppLogger().log('Initialize game');
    await _engine!.setMultiPV(state.multiPv);
    await _engine!.newGame();
    await _analyzePosition(movetimeMs: 1000);
  }

  List<String> currentMoves() => state.moves.take(state.pointer).toList();

  Future<void> onPickSide({required bool red}) async {
    state = state.copyWith(redToMove: red);
    // Update FEN side-to-move if needed
    final newFen = FenParser.flipSideToMove(state.fen);
    state = state.copyWith(fen: newFen);

    if (_engine != null) {
      await _analyzePosition(movetimeMs: 1000);
    }
  }

  Future<void> setMultiPv(int n) async {
    if (_engine == null) return;

    state = state.copyWith(multiPv: n, bestLines: []);
    await _engine!.setMultiPV(n);
    await _analyzePosition(movetimeMs: 1000);
  }

  Future<void> applyMove(String moveUci) async {
    if (_engine == null) return;

    await AppLogger().log('Apply move: ' + moveUci);

    // Deduplicate quick double commits
    final now = DateTime.now();
    if (_recentAppliedMove == moveUci &&
        _recentAppliedAt != null &&
        now.difference(_recentAppliedAt!).inMilliseconds < 800) {
      await AppLogger().log('Skip duplicate apply for: ' + moveUci);
      return;
    }
    _recentAppliedMove = moveUci;
    _recentAppliedAt = now;

    // Validate move
    if (!XiangqiRules.isValidMove(state.fen, moveUci)) {
      print('Invalid move: $moveUci');
      await AppLogger().error('Invalid move', moveUci);
      return;
    }

    final newMoves = [...state.moves];
    if (state.pointer < newMoves.length) {
      newMoves.removeRange(state.pointer, newMoves.length);
    }
    newMoves.add(moveUci);

    // Update FEN after the move
    final newFen = FenParser.applyMove(state.fen, moveUci);

    // Store current animation before clearing
    final hadAnimation = state.pendingAnimation != null;

    state = state.copyWith(
      fen: newFen,
      moves: newMoves,
      pointer: newMoves.length,
      redToMove: !state.redToMove, // Switch sides
      bestLines: [],
      canBack: newMoves.isNotEmpty,
      canNext: false,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
      // Keep animation until FEN is fully applied if we had one
      pendingAnimation: hadAnimation ? state.pendingAnimation : null,
      isEngineThinking: false,
    );

    // Set position FIRST
    await _engine!.setPosition(state.fen, currentMoves());

    // Only NOW clear animation after everything is set
    if (hadAnimation) {
      state = state.copyWith(pendingAnimation: null);
    }

    // Start analysis
    await _analyzePosition(movetimeMs: 1000);

    // FORCE CHECK GAME STATUS with explicit error handling
    try {
      await AppLogger().log('=== FORCING GAME STATUS CHECK ===');
      await _checkGameStatus();
      await AppLogger().log('=== GAME STATUS CHECK COMPLETED ===');
    } catch (e, stackTrace) {
      await AppLogger().error(
        'CRITICAL: _checkGameStatus failed',
        e,
        stackTrace,
      );
      // Force show error notification
      _showNotification(
        'ERROR: Could not check game status',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> back() async {
    if (!state.canBack || _engine == null) return;

    final newPointer = state.pointer - 1;

    // Reconstruct FEN from move history up to the new pointer
    String newFen = defaultXqFen;
    bool newRedToMove = true;

    for (int i = 0; i < newPointer; i++) {
      newFen = FenParser.applyMove(newFen, state.moves[i]);
      newRedToMove = !newRedToMove;
    }

    AppLogger().log(
      'Back: pointer ${state.pointer} -> $newPointer, FEN updated',
    );

    state = state.copyWith(
      pointer: newPointer,
      fen: newFen,
      redToMove: newRedToMove,
      bestLines: [],
      canBack: newPointer > 0,
      canNext: true,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
      pendingAnimation: null, // Clear any pending animation
    );

    // Set engine position to match the board state
    await _engine!.setPosition(newFen, state.moves.take(newPointer).toList());
    await _analyzePosition(movetimeMs: 1000);
  }

  Future<void> next() async {
    if (!state.canNext || _engine == null) return;

    final newPointer = state.pointer + 1;

    // Reconstruct FEN from move history up to the new pointer
    String newFen = defaultXqFen;
    bool newRedToMove = true;

    for (int i = 0; i < newPointer; i++) {
      newFen = FenParser.applyMove(newFen, state.moves[i]);
      newRedToMove = !newRedToMove;
    }

    AppLogger().log(
      'Next: pointer ${state.pointer} -> $newPointer, FEN updated',
    );

    state = state.copyWith(
      pointer: newPointer,
      fen: newFen,
      redToMove: newRedToMove,
      bestLines: [],
      canBack: true,
      canNext: newPointer < state.moves.length,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: [],
      pendingAnimation: null, // Clear any pending animation
    );

    // Set engine position to match the board state
    await _engine!.setPosition(newFen, state.moves.take(newPointer).toList());
    await _analyzePosition(movetimeMs: 1000);
  }

  Future<void> reset() async {
    if (_engine == null) return;

    state = BoardState.initial();
    await _engine!.newGame();
    await _engine!.setMultiPV(state.multiPv);
    await _analyzePosition(movetimeMs: 1000);
  }

  /// Updates board position from recognized FEN
  Future<void> setBoardFromFEN(String fen) async {
    if (_engine == null) return;

    await AppLogger().log('Setting board from recognized FEN: $fen');

    // Validate FEN format
    if (!_isValidFEN(fen)) {
      await AppLogger().error('Invalid FEN format', fen);
      throw Exception('Invalid FEN format');
    }

    // Parse FEN to get side to move
    final fenParts = fen.split(' ');
    final sideToMove = fenParts.length > 1 ? fenParts[1] : 'w';
    final isRedToMove = sideToMove == 'w';

    // Update state with new position
    state = state.copyWith(
      fen: fen,
      redToMove: isRedToMove,
      moves: const [], // Clear move history
      pointer: 0,
      bestLines: const [],
      canBack: false,
      canNext: false,
      selectedFile: null,
      selectedRank: null,
      possibleMoves: const [],
      pendingAnimation: null,
      isEngineThinking: false,
    );

    // Set engine position
    await _engine!.setPosition(fen, []);
    await _analyzePosition(movetimeMs: 1000);

    // Check game status
    await _checkGameStatus();

    await AppLogger().log('Board position updated successfully');
  }

  /// Checks game status and shows notifications
  Future<void> _checkGameStatus() async {
    try {
      AppLogger().log('=== CHECKING GAME STATUS ===');
      final fen = state.fen;
      AppLogger().log('Current FEN: $fen');

      // Check for check FIRST with enhanced logging
      AppLogger().log('Checking for check...');
      final isInCheck = GameStatusService.isInCheck(fen);
      AppLogger().log('Is in check: $isInCheck');

      if (isInCheck) {
        final sideToMove = FenParser.getSideToMove(fen);
        final currentPlayer = sideToMove == 'w' ? 'Red' : 'Black';
        AppLogger().log(
          '*** SHOWING CHECK NOTIFICATION for $currentPlayer ***',
        );
        _showNotification(
          '${currentPlayer} is in CHECK!',
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        );
        AppLogger().log('Check notification added to state');
        AppLogger().log(
          'Current notifications count: ${state.notifications.length}',
        );
      }

      // Check for checkmate or king captured (winner)
      AppLogger().log('Checking for checkmate...');
      final isCheckmate = GameStatusService.isCheckmate(fen);
      AppLogger().log('Is checkmate: $isCheckmate');
      final winner = GameStatusService.getWinner(fen);
      AppLogger().log('Winner: $winner');
      if (isCheckmate || (winner != null && winner != 'Draw')) {
        final displayWinner =
            winner ?? ((FenParser.getSideToMove(fen) == 'w') ? 'Black' : 'Red');
        AppLogger().log(
          '*** SHOWING GAME OVER NOTIFICATION for $displayWinner ***',
        );
        _showNotification(
          '$displayWinner WINS! ${isCheckmate ? 'Checkmate' : 'King captured'}!',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        );
        return; // Don't check stalemate if game is over
      }

      // Check for stalemate only if not in check and not checkmate
      if (!isInCheck) {
        AppLogger().log('Checking for stalemate...');
        final isStalemate = GameStatusService.isStalemate(fen);
        AppLogger().log('Is stalemate: $isStalemate');
        if (isStalemate) {
          AppLogger().log('*** SHOWING STALEMATE NOTIFICATION ***');
          _showNotification(
            'DRAW! Stalemate!',
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger().error('Error checking game status', e, stackTrace);
    }
  }

  /// Shows a game notification
  void _showNotification(
    String message, {
    Color backgroundColor = Colors.red,
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      AppLogger().log('=== SHOWING NOTIFICATION ===');
      AppLogger().log('Message: $message');
      AppLogger().log('Background color: $backgroundColor');
      AppLogger().log('Duration: ${duration.inSeconds}s');
      AppLogger().log(
        'Current notifications count BEFORE: ${state.notifications.length}',
      );

      final notification = GameNotification(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        duration: duration,
      );

      final newNotifications = List<GameNotification>.from(state.notifications)
        ..add(notification);
      state = state.copyWith(notifications: newNotifications);

      AppLogger().log(
        'Notification added. New count AFTER: ${state.notifications.length}',
      );
      final hasNotification = state.notifications.any(
        (n) => n.message == message,
      );
      AppLogger().log('Notification verified in state: $hasNotification');

      Future.delayed(duration + const Duration(milliseconds: 500), () {
        try {
          AppLogger().log('Auto-removing notification: $message');
          _removeNotification(notification);
        } catch (e) {
          AppLogger().error('Error removing notification', e);
        }
      });
      AppLogger().log('=== NOTIFICATION SETUP COMPLETE ===');
    } catch (e, stackTrace) {
      AppLogger().error('Error showing notification', e, stackTrace);
    }
  }

  /// Removes a notification
  void _removeNotification(GameNotification notification) {
    try {
      AppLogger().log('Removing notification: ${notification.message}');
      AppLogger().log(
        'Current notifications count BEFORE removal: ${state.notifications.length}',
      );
      final updatedNotifications = List<GameNotification>.from(
        state.notifications,
      );
      final removed = updatedNotifications.remove(notification);
      AppLogger().log('Notification removed: $removed');
      state = state.copyWith(notifications: updatedNotifications);
      AppLogger().log(
        'Current notifications count AFTER removal: ${state.notifications.length}',
      );
    } catch (e, stackTrace) {
      AppLogger().error('Error removing notification', e, stackTrace);
    }
  }

  // (Debug/test helpers removed)

  /// Validates FEN format
  bool _isValidFEN(String fen) {
    try {
      final parts = fen.split(' ');
      if (parts.length < 2) return false;

      final boardPart = parts[0];
      final sidePart = parts[1];

      // Check side to move
      if (sidePart != 'w' && sidePart != 'b') return false;

      // Check board format (simplified validation)
      final ranks = boardPart.split('/');
      if (ranks.length != 10) return false; // Xiangqi has 10 ranks

      // Each rank should have valid piece notation and sum to 9 files
      for (final rank in ranks) {
        if (rank.isEmpty) return false;
        // Allow digits 1-9 and project piece letters (both cases): r,h,e,a,k,c,p
        if (!RegExp(r'^[1-9rheakcpRHEAKCP]+$').hasMatch(rank)) {
          return false;
        }
        // Sum files
        int width = 0;
        for (int i = 0; i < rank.length; i++) {
          final ch = rank[i];
          final digit = int.tryParse(ch);
          if (digit != null) {
            width += digit;
          } else {
            width += 1;
          }
        }
        if (width != 9) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> switchEngine(String engineName) async {
    await _switchEngine(engineName);
  }

  void onBoardTap(int file, int rank) {
    // Debug current animation state
    AppLogger().log(
      'TAP DEBUG - Animation: ${state.pendingAnimation != null}, Since: $_pendingSince, Committing: $_isCommittingAnim',
    );

    // More robust animation state checking and clearing
    if (state.pendingAnimation != null || _isCommittingAnim) {
      final since = _pendingSince;
      final now = DateTime.now();

      if (since != null) {
        final ms = now.difference(since).inMilliseconds;
        AppLogger().log('Animation age: ${ms}ms');

        // Reduce timeout to 800ms for faster recovery
        if (ms > 800) {
          AppLogger().log('Force-clear stuck animation after ${ms}ms');
          _forceCleanAnimationState();
        } else {
          AppLogger().log('Tap ignored: animation in progress (${ms}ms)');
          return;
        }
      } else if (_isCommittingAnim) {
        // If committing but no timestamp, something is wrong
        AppLogger().log('Tap ignored: commit in progress without timestamp');
        return;
      } else {
        // Animation exists but no timestamp - definitely stuck
        AppLogger().log('Force-clear animation with no timestamp');
        _forceCleanAnimationState();
      }
    }

    AppLogger().log(
      'Tap at file=$file rank=$rank, fenSide=${FenParser.getSideToMove(state.fen)}',
    );
    final board = FenParser.parseBoard(state.fen);
    final piece = board[rank][file];

    // If no piece is selected, try to select a piece
    if (state.selectedFile == null || state.selectedRank == null) {
      if (piece.isNotEmpty) {
        // Check if it's the correct side to move based on FEN
        final isRedPiece = piece == piece.toUpperCase();
        final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';
        AppLogger().log(
          'Select attempt piece=$piece isRed=$isRedPiece canSelect=${(isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)}',
        );
        if ((isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)) {
          // Select the piece and calculate possible moves
          final possibleMoves = _calculatePossibleMoves(file, rank, board);
          AppLogger().log(
            'Selected piece. possibleMoves=${possibleMoves.length}',
          );
          state = state.copyWith(
            selectedFile: file,
            selectedRank: rank,
            possibleMoves: possibleMoves,
          );
        }
      }
    } else {
      // A piece is already selected
      final selectedFile = state.selectedFile!;
      final selectedRank = state.selectedRank!;

      // Check if clicking on the same piece (deselect)
      if (file == selectedFile && rank == selectedRank) {
        state = state.copyWith(
          selectedFile: null,
          selectedRank: null,
          possibleMoves: [],
        );
        return;
      }

      // If for some reason there are no possible moves cached (e.g. state
      // reset after turn switch), treat this tap as a new selection attempt
      if (state.possibleMoves.isEmpty) {
        if (piece.isNotEmpty) {
          final isRedPiece = piece == piece.toUpperCase();
          final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';
          if ((isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)) {
            final possibleMoves = _calculatePossibleMoves(file, rank, board);
            state = state.copyWith(
              selectedFile: file,
              selectedRank: rank,
              possibleMoves: possibleMoves,
            );
          }
        }
        return;
      }

      // Allow move if the click is near one of possible moves (tolerance)
      final click = Offset(file.toDouble(), rank.toDouble());
      Offset? chosen;
      double best = 1e9;
      for (final m in state.possibleMoves) {
        final d = (m.dx - click.dx).abs() + (m.dy - click.dy).abs();
        if (d < best) {
          best = d;
          chosen = m;
        }
      }
      // Accept if within ~1 cell from a legal destination (to absorb mapping/flooring errors)
      if (chosen == null || best > 1.1) {
        // Not near any legal destination; ignore
        AppLogger().log(
          'No near legal destination. best=$best, pmCount=${state.possibleMoves.length}',
        );
        return;
      }
      final snappedToFile = chosen.dx.round();
      final snappedToRank = chosen.dy.round();
      final moveUci = _fileRankToUci(
        selectedFile,
        selectedRank,
        snappedToFile,
        snappedToRank,
      );
      AppLogger().log('Attempt move: $moveUci');
      if (XiangqiRules.isValidMove(state.fen, moveUci)) {
        // Queue animation first; BoardView will commit and then we apply
        final board = FenParser.parseBoard(state.fen);
        final piece = board[selectedRank][selectedFile];
        state = state.copyWith(
          pendingAnimation: MoveAnimation(
            fromFile: selectedFile,
            fromRank: selectedRank,
            toFile: snappedToFile,
            toRank: snappedToRank,
            piece: piece,
            moveUci: moveUci,
          ),
          selectedFile: null,
          selectedRank: null,
          possibleMoves: [],
        );
        _pendingSince = DateTime.now();
        AppLogger().log('Move queued for animation.');
        // Failsafe: auto-commit after animation duration in case the
        // widget callback is skipped due to rebuilds
        _animationAutoCommit?.cancel();
        _animationAutoCommit = Timer(const Duration(milliseconds: 260), () {
          if (state.pendingAnimation != null) {
            AppLogger().log('Auto-commit animated move (failsafe)');
            commitAnimatedMove();
          }
        });
        // Additional watchdog: force clear if animation is stuck for too long
        _animationWatchdog?.cancel();
        _animationWatchdog = Timer(const Duration(milliseconds: 1500), () {
          if (state.pendingAnimation != null) {
            AppLogger().log(
              'Animation watchdog: force clearing stuck animation',
            );
            state = state.copyWith(pendingAnimation: null);
            _pendingSince = null;
            _isCommittingAnim = false;
          }
        });
      } else {
        // Try to select a different piece
        if (piece.isNotEmpty) {
          final isRedPiece = piece == piece.toUpperCase();
          final isRedToMove = FenParser.getSideToMove(state.fen) == 'w';
          AppLogger().log('Move invalid. Try reselect piece=$piece');
          if ((isRedToMove && isRedPiece) || (!isRedToMove && !isRedPiece)) {
            final possibleMoves = _calculatePossibleMoves(file, rank, board);
            AppLogger().log(
              'Reselected. possibleMoves=${possibleMoves.length}',
            );
            state = state.copyWith(
              selectedFile: file,
              selectedRank: rank,
              possibleMoves: possibleMoves,
            );
          }
        } else {
          // Clicked on empty square, deselect
          AppLogger().log('Clicked empty square. Deselect.');
          state = state.copyWith(
            selectedFile: null,
            selectedRank: null,
            possibleMoves: [],
          );
        }
      }
    }
  }

  // Called by UI after animation ends to actually apply move
  Future<void> commitAnimatedMove() async {
    final commitStart = DateTime.now();
    AppLogger().log(
      'COMMIT START - isCommitting: $_isCommittingAnim, hasAnimation: ${state.pendingAnimation != null}',
    );

    if (_isCommittingAnim) {
      AppLogger().log('Already committing animation, ignoring duplicate call.');
      return;
    }

    final anim = state.pendingAnimation;
    if (anim == null) {
      AppLogger().log('No pending animation to commit');
      return;
    }

    _isCommittingAnim = true;

    // Cancel timers first
    _animationAutoCommit?.cancel();
    _animationAutoCommit = null;
    _animationWatchdog?.cancel();
    _animationWatchdog = null;

    AppLogger().log('Committing animation: ${anim.moveUci}');

    try {
      // Clear animation IMMEDIATELY before applying move
      state = state.copyWith(clearPendingAnimation: true);
      _pendingSince = null;
      AppLogger().log('Animation cleared before move, now applying...');

      final moveStart = DateTime.now();
      await applyMove(anim.moveUci);
      final moveTime = DateTime.now().difference(moveStart).inMilliseconds;
      AppLogger().log('Move applied in ${moveTime}ms');

      final totalTime = DateTime.now().difference(commitStart).inMilliseconds;
      AppLogger().log('COMMIT COMPLETE in ${totalTime}ms');
    } catch (e) {
      AppLogger().error('Failed to commit animated move', e);
      _forceCleanAnimationState();
    } finally {
      _isCommittingAnim = false;
    }
  }

  // Helper method to force clean animation state
  void _forceCleanAnimationState() {
    AppLogger().log(
      'Cleaning animation state - before: ${state.pendingAnimation != null}',
    );

    // Cancel all timers
    _animationAutoCommit?.cancel();
    _animationAutoCommit = null;
    _animationWatchdog?.cancel();
    _animationWatchdog = null;

    // Reset all flags and state
    _isCommittingAnim = false;
    _pendingSince = null;

    // Use explicit clear flags to ensure null assignment
    state = state.copyWith(
      clearPendingAnimation: true,
      clearSelection: true,
      possibleMoves: [],
    );

    AppLogger().log(
      'Animation state cleaned - after: ${state.pendingAnimation != null}',
    );

    // Double-check and force create new state if still not cleared
    if (state.pendingAnimation != null) {
      AppLogger().log(
        'WARNING: Animation still exists, force creating new state',
      );
      state = BoardState(
        fen: state.fen,
        moves: state.moves,
        pointer: state.pointer,
        redToMove: state.redToMove,
        bestLines: state.bestLines,
        multiPv: state.multiPv,
        canBack: state.canBack,
        canNext: state.canNext,
        selectedEngine: state.selectedEngine,
        isEngineThinking: state.isEngineThinking,
        engineError: state.engineError,
        enginePath: state.enginePath,
        selectedFile: null,
        selectedRank: null,
        possibleMoves: const [],
        pendingAnimation: null,
      );
      AppLogger().log(
        'Forced new state - animation cleared: ${state.pendingAnimation == null}',
      );
    }
  }

  // Analyze current position, supporting EleEye's lack of native MultiPV
  Future<void> _analyzePosition({int? movetimeMs}) async {
    if (_engine == null) return;

    // Clear previous best lines when starting a fresh analysis
    state = state.copyWith(bestLines: [], isEngineThinking: true);
    _startThinkingWatchdog();

    try {
      final isEleEye =
          state.selectedEngine == 'EleEye' && _engine!.protocol == 'UCCI';

      if (!isEleEye || state.multiPv <= 1) {
        // Standard path: ask engine once with requested MultiPV
        await _engine!.setPosition(state.fen, currentMoves());
        await _engine!.go(movetimeMs: movetimeMs ?? 1000);
        return;
      }

      // EleEye path: emulate MultiPV using iterative banmoves
      _eleEyeBanMode = true;
      _bannedFirstMoves.clear();

      for (_banIteration = 0; _banIteration < state.multiPv; _banIteration++) {
        // Reposition resets previous ban list inside engine
        await _engine!.setPosition(state.fen, currentMoves());

        if (_bannedFirstMoves.isNotEmpty) {
          // Example: "banmoves b2b9 h2h9"
          final cmd = 'banmoves ' + _bannedFirstMoves.join(' ');
          _engine!.send(cmd);
        }

        // Wait for a single bestmove to mark the end of this cycle
        _bestMoveOnce = Completer<void>();
        await _engine!.go(movetimeMs: movetimeMs ?? 1000);
        try {
          await _bestMoveOnce!.future.timeout(const Duration(seconds: 5));
        } catch (_) {
          // If EleEye fails to reply, break the loop
          break;
        }

        // Capture first move of just-finished PV index
        final idx = _banIteration + 1;
        final bl = state.bestLines.firstWhere(
          (e) => e.index == idx,
          orElse: () => const BestLine(0, 0, 0, []),
        );
        if (bl.firstMove.isNotEmpty) {
          _bannedFirstMoves.add(bl.firstMove);
        } else {
          break; // no move parsed; stop early
        }
      }

      // Restore flags
      _eleEyeBanMode = false;
    } catch (e) {
      // Ensure clear thinking state if there's an error
      state = state.copyWith(isEngineThinking: false);
      rethrow;
    }
  }

  List<Offset> _calculatePossibleMoves(
    int file,
    int rank,
    List<List<String>> board,
  ) {
    // Generate legal moves for the selected piece by validating every target
    final possibleMoves = <Offset>[];
    final piece = board[rank][file];
    if (piece.isEmpty) return possibleMoves;

    AppLogger().log(
      'Calculating possible moves for piece $piece at $file,$rank',
    );

    for (int toRank = 0; toRank < 10; toRank++) {
      for (int toFile = 0; toFile < 9; toFile++) {
        if (toFile == file && toRank == rank) continue;
        final uci = _fileRankToUci(file, rank, toFile, toRank);
        final isValid = XiangqiRules.isValidMove(state.fen, uci);
        if (isValid) {
          AppLogger().log('Valid move found: $uci');
          possibleMoves.add(Offset(toFile.toDouble(), toRank.toDouble()));
        }
      }
    }

    AppLogger().log('Total possible moves: ${possibleMoves.length}');
    return possibleMoves;
  }

  String _fileRankToUci(int fromFile, int fromRank, int toFile, int toRank) {
    // Convert file/rank coordinates to UCI notation
    final fromSquare = '${String.fromCharCode(97 + fromFile)}${9 - fromRank}';
    final toSquare = '${String.fromCharCode(97 + toFile)}${9 - toRank}';
    return '$fromSquare$toSquare';
  }

  @override
  void dispose() {
    _engine?.stop();
    _engineSubscription?.cancel();
    _thinkingWatchdog?.cancel();
    _animationAutoCommit?.cancel();
    _animationWatchdog?.cancel();
    super.dispose();
  }
}

class MoveAnimation {
  final int fromFile;
  final int fromRank;
  final int toFile;
  final int toRank;
  final String piece;
  final String moveUci;
  const MoveAnimation({
    required this.fromFile,
    required this.fromRank,
    required this.toFile,
    required this.toRank,
    required this.piece,
    required this.moveUci,
  });
}

// Provider for board controller
final boardControllerProvider =
    StateNotifierProvider<BoardController, BoardState>((ref) {
      return BoardController();
    });
