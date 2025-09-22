import '../core/fen.dart';
import '../core/xiangqi_rules.dart';
import '../core/logger.dart';

/// Service for checking game status (check, checkmate, etc.)
class GameStatusService {
  /// Checks if the current player is in check
  static bool isInCheck(String fen) {
    try {
      final board = FenParser.parseBoard(fen);
      final sideToMove = FenParser.getSideToMove(fen);
      final isRedToMove = sideToMove == 'w';

      // IMPORTANT: Some positions/logs showed non-standard mappings.
      // Try multiple possible king symbols to be robust, prefer standard first.
      String? foundKingSymbol;
      KingPosition? kingPosition;

      final possibleKings = isRedToMove ? ['K', 'k'] : ['k', 'K', 'C', 'c'];
      for (final symbol in possibleKings) {
        final pos = _findKingPosition(board, symbol);
        if (pos != null) {
          foundKingSymbol = symbol;
          kingPosition = pos;
          AppLogger().log(
            'Found ${isRedToMove ? 'red' : 'black'} king: $symbol at (${pos.file}, ${pos.rank})',
          );
          break;
        }
      }

      if (kingPosition == null || foundKingSymbol == null) {
        AppLogger().log(
          'King not found for ${isRedToMove ? 'red' : 'black'} (tried: $possibleKings)',
        );
        // Debug: print board to see what pieces are actually there
        AppLogger().log('Board state:');
        for (int rank = 0; rank < 10; rank++) {
          final row = board[rank].join(' ');
          AppLogger().log('Rank $rank: $row');
        }
        return false;
      }

      // Check if any opponent piece can attack the king
      // Use wide set of symbols to be safe, then filter out own pieces.
      final opponentSymbols = isRedToMove
          ? [
              'p',
              'r',
              'h',
              'e',
              'a',
              'k',
              'c',
              'P',
              'R',
              'H',
              'E',
              'A',
              'K',
              'C',
            ]
          : [
              'P',
              'R',
              'H',
              'E',
              'A',
              'K',
              'C',
              'p',
              'r',
              'h',
              'e',
              'a',
              'k',
              'c',
            ];
      opponentSymbols.remove(foundKingSymbol);

      AppLogger().log(
        'Looking for opponent pieces against $foundKingSymbol king: $opponentSymbols',
      );
      AppLogger().log(
        'King position: file=${kingPosition.file}, rank=${kingPosition.rank}',
      );

      // Validate opponent moves using a FEN where it's the opponent's turn
      final fenForOpponentTurn = FenParser.flipSideToMove(fen);

      for (int rank = 0; rank < 10; rank++) {
        for (int file = 0; file < 9; file++) {
          final piece = board[rank][file];
          if (piece.isNotEmpty && opponentSymbols.contains(piece)) {
            // Ensure it's truly an opponent piece
            final isPieceRed = piece == piece.toUpperCase();
            if (isPieceRed == isRedToMove) {
              continue;
            }
            AppLogger().log('Found opponent piece $piece at ($file, $rank)');

            // Create UCI move from opponent piece to king
            // No coordinate conversion needed - both are already in correct format
            final moveUci = _fileRankToUci(
              file,
              rank,
              kingPosition.file,
              kingPosition.rank,
            );
            AppLogger().log('Checking attack move: $moveUci');

            if (XiangqiRules.isValidMove(fenForOpponentTurn, moveUci)) {
              AppLogger().log(
                '*** CHECK DETECTED *** King is in check by piece $piece at ($file, $rank)',
              );
              return true;
            }
          }
        }
      }

      AppLogger().log('No check detected');
      return false;
    } catch (e, stackTrace) {
      AppLogger().error('Error checking check status', e, stackTrace);
      return false;
    }
  }

  /// Checks if the current player is in checkmate
  static bool isCheckmate(String fen) {
    try {
      AppLogger().log('Checking for checkmate...');

      // First check if in check
      if (!isInCheck(fen)) {
        AppLogger().log('Not in check, cannot be checkmate');
        return false;
      }

      // Check if there are any legal moves that can escape check
      final legalMoves = _getAllLegalMoves(fen);
      AppLogger().log('Legal moves available: ${legalMoves.length}');

      // Test each legal move to see if it escapes check
      for (final move in legalMoves) {
        final newFen = FenParser.applyMove(fen, move);
        if (!isInCheck(newFen)) {
          AppLogger().log('Found escape move: $move');
          return false; // Found a move that escapes check
        }
      }

      AppLogger().log('Checkmate confirmed - no escape moves');
      return true; // No moves can escape check
    } catch (e, stackTrace) {
      AppLogger().error('Error checking checkmate status', e, stackTrace);
      return false;
    }
  }

  /// Checks if the game is a draw (stalemate)
  static bool isStalemate(String fen) {
    try {
      AppLogger().log('Checking for stalemate...');

      // Check if not in check but no legal moves
      if (isInCheck(fen)) {
        AppLogger().log('In check, cannot be stalemate');
        return false;
      }

      final legalMoves = _getAllLegalMoves(fen);
      final isStalemate = legalMoves.isEmpty;
      AppLogger().log(
        'Stalemate check: ${isStalemate ? 'YES' : 'NO'} (legal moves: ${legalMoves.length})',
      );
      return isStalemate;
    } catch (e, stackTrace) {
      AppLogger().error('Error checking stalemate status', e, stackTrace);
      return false;
    }
  }

  /// Gets the winner of the game
  static String? getWinner(String fen) {
    try {
      if (isCheckmate(fen)) {
        // The player who is NOT to move wins (opponent of current player)
        final sideToMove = FenParser.getSideToMove(fen);
        final isRedToMove = sideToMove == 'w';
        final winner = isRedToMove ? 'Black' : 'Red';
        AppLogger().log('Winner determined: $winner (checkmate)');
        return winner;
      }

      if (isStalemate(fen)) {
        AppLogger().log('Game result: Draw (stalemate)');
        return 'Draw';
      }

      return null; // Game continues
    } catch (e, stackTrace) {
      AppLogger().error('Error determining winner', e, stackTrace);
      return null;
    }
  }

  /// Gets all legal moves for the current position
  static List<String> _getAllLegalMoves(String fen) {
    final legalMoves = <String>[];

    try {
      final board = FenParser.parseBoard(fen);
      final sideToMove = FenParser.getSideToMove(fen);
      final isRedToMove = sideToMove == 'w';

      for (int rank = 0; rank < 10; rank++) {
        for (int file = 0; file < 9; file++) {
          final piece = board[rank][file];
          if (piece.isEmpty) continue;

          // Check if this piece belongs to current player
          final isRedPiece = piece == piece.toUpperCase();
          if (isRedToMove != isRedPiece) continue;

          // Try all possible moves for this piece
          for (int toRank = 0; toRank < 10; toRank++) {
            for (int toFile = 0; toFile < 9; toFile++) {
              if (toFile == file && toRank == rank) continue;

              final moveUci = _fileRankToUci(file, rank, toFile, toRank);
              if (XiangqiRules.isValidMove(fen, moveUci)) {
                legalMoves.add(moveUci);
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger().error('Error getting legal moves', e, stackTrace);
    }

    return legalMoves;
  }

  /// Finds the position of the king
  static KingPosition? _findKingPosition(
    List<List<String>> board,
    String kingSymbol,
  ) {
    // Restrict search to palace squares for kings to avoid mis-detection
    // Red king 'K' resides within files 3..5 and ranks 7..9 (bottom palace)
    // Black king 'k' resides within files 3..5 and ranks 0..2 (top palace)
    Iterable<int> files = [3, 4, 5];
    Iterable<int> ranks;

    if (kingSymbol == 'K') {
      // Red king at bottom palace
      ranks = [7, 8, 9];
    } else if (kingSymbol == 'k') {
      // Black king at top palace
      ranks = [0, 1, 2];
    } else {
      files = List<int>.generate(9, (i) => i);
      ranks = List<int>.generate(10, (i) => i);
    }

    for (final rank in ranks) {
      for (final file in files) {
        if (board[rank][file] == kingSymbol) {
          return KingPosition(file: file, rank: rank);
        }
      }
    }

    // Fallback: full board scan (in case of non-standard setups)
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        if (board[rank][file] == kingSymbol) {
          return KingPosition(file: file, rank: rank);
        }
      }
    }
    return null;
  }

  /// Convert file/rank coordinates to UCI notation
  static String _fileRankToUci(
    int fromFile,
    int fromRank,
    int toFile,
    int toRank,
  ) {
    // Board coordinates are already 0-9 from top to bottom
    // Convert to UCI: rank 0 (top) -> '9', rank 9 (bottom) -> '0'
    final fromSquare = '${String.fromCharCode(97 + fromFile)}${9 - fromRank}';
    final toSquare = '${String.fromCharCode(97 + toFile)}${9 - toRank}';
    return '$fromSquare$toSquare';
  }
}

/// Represents a king's position on the board
class KingPosition {
  final int file;
  final int rank;

  const KingPosition({required this.file, required this.rank});
}
