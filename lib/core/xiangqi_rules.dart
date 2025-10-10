// Xiangqi rules validation (Phase 1 - Basic)
// This is a simplified validator for basic move validation

import 'fen.dart';
import 'move_notation.dart';

class XiangqiRules {
  // Basic piece movement validation
  static bool isValidMove(String fen, String uciMove) {
    final move = MoveNotation.parseUciMove(uciMove);
    if (move == null) return false;
    // Convert UCI ranks (0=bottom .. 9=top) to board indices (0=top .. 9=bottom)
    final moveIdx = Move(
      fromFile: move.fromFile,
      fromRank: 9 - move.fromRank,
      toFile: move.toFile,
      toRank: 9 - move.toRank,
    );

    final board = FenParser.parseBoard(fen);
    final sideToMove = FenParser.getSideToMove(fen);

    // Check if coordinates are valid
    if (!MoveNotation.isValidCoordinate(moveIdx.fromFile, moveIdx.fromRank) ||
        !MoveNotation.isValidCoordinate(moveIdx.toFile, moveIdx.toRank)) {
      return false;
    }

    // Check if there's a piece at the source square
    final fromPiece = board[moveIdx.fromRank][moveIdx.fromFile];
    if (fromPiece.isEmpty) return false;

    // Check if the piece belongs to the side to move
    final isRedPiece = fromPiece == fromPiece.toUpperCase();
    final isRedToMove = sideToMove == 'w';
    if (isRedPiece != isRedToMove) return false;

    // Check if destination square is not occupied by own piece
    final toPiece = board[moveIdx.toRank][moveIdx.toFile];
    if (toPiece.isNotEmpty) {
      final isToRedPiece = toPiece == toPiece.toUpperCase();
      if (isRedPiece == isToRedPiece) return false; // Can't capture own piece
    }

    // Basic piece movement rules (simplified)
    return _isValidPieceMove(board, moveIdx, fromPiece);
  }

  static bool _isValidPieceMove(
    List<List<String>> board,
    Move move,
    String piece,
  ) {
    final pieceType = piece.toLowerCase();

    switch (pieceType) {
      case 'r': // Chariot (車)
        return _isValidChariotMove(board, move);
      case 'h': // Horse (馬)
        return _isValidHorseMove(board, move);
      case 'e': // Elephant (象)
        return _isValidElephantMove(board, move);
      case 'a': // Advisor (士)
        return _isValidAdvisorMove(board, move);
      case 'k': // King (帥/將)
        return _isValidKingMove(board, move);
      case 'c': // Cannon (炮)
        return _isValidCannonMove(board, move);
      case 'p': // Pawn (兵/卒)
        return _isValidPawnMove(board, move);
      default:
        return false;
    }
  }

  static bool _isValidChariotMove(List<List<String>> board, Move move) {
    // Chariot moves horizontally or vertically, any distance
    if (move.fromFile != move.toFile && move.fromRank != move.toRank) {
      return false; // Must move in straight line
    }

    // Check if path is clear
    if (move.fromFile == move.toFile) {
      // Vertical move
      final start = move.fromRank < move.toRank ? move.fromRank : move.toRank;
      final end = move.fromRank < move.toRank ? move.toRank : move.fromRank;
      for (int rank = start + 1; rank < end; rank++) {
        if (board[rank][move.fromFile].isNotEmpty) {
          return false; // Path blocked
        }
      }
    } else {
      // Horizontal move
      final start = move.fromFile < move.toFile ? move.fromFile : move.toFile;
      final end = move.fromFile < move.toFile ? move.toFile : move.fromFile;
      for (int file = start + 1; file < end; file++) {
        if (board[move.fromRank][file].isNotEmpty) {
          return false; // Path blocked
        }
      }
    }

    return true;
  }

  static bool _isValidHorseMove(List<List<String>> board, Move move) {
    // Horse moves in L-shape: 2 squares in one direction, then 1 square perpendicular
    final fileDiff = (move.toFile - move.fromFile).abs();
    final rankDiff = (move.toRank - move.fromRank).abs();

    if (!((fileDiff == 2 && rankDiff == 1) ||
        (fileDiff == 1 && rankDiff == 2))) {
      return false; // Not L-shape
    }

    // Check if horse is not blocked (hobbled)
    int blockFile, blockRank;
    if (fileDiff == 2) {
      blockFile = move.fromFile + (move.toFile - move.fromFile) ~/ 2;
      blockRank = move.fromRank;
    } else {
      blockFile = move.fromFile;
      blockRank = move.fromRank + (move.toRank - move.fromRank) ~/ 2;
    }

    if (board[blockRank][blockFile].isNotEmpty) {
      return false; // Horse is hobbled
    }

    return true;
  }

  static bool _isValidElephantMove(List<List<String>> board, Move move) {
    // Elephant moves diagonally 2 squares, cannot cross river
    final fileDiff = (move.toFile - move.fromFile).abs();
    final rankDiff = (move.toRank - move.fromRank).abs();

    if (fileDiff != 2 || rankDiff != 2) {
      return false; // Must move 2 squares diagonally
    }

    // Check if elephant crosses river (ranks 4-5)
    final isRedElephant = move.fromRank < 5;
    if (isRedElephant && move.toRank >= 5) return false;
    if (!isRedElephant && move.toRank < 5) return false;

    // Check if path is clear (center square)
    final centerFile = move.fromFile + (move.toFile - move.fromFile) ~/ 2;
    final centerRank = move.fromRank + (move.toRank - move.fromRank) ~/ 2;

    if (board[centerRank][centerFile].isNotEmpty) {
      return false; // Path blocked
    }

    return true;
  }

  static bool _isValidAdvisorMove(List<List<String>> board, Move move) {
    // Advisor moves diagonally 1 square, stays in palace
    final fileDiff = (move.toFile - move.fromFile).abs();
    final rankDiff = (move.toRank - move.fromRank).abs();

    if (fileDiff != 1 || rankDiff != 1) {
      return false; // Must move 1 square diagonally
    }

    // Check if stays in palace
    final isRedAdvisor = move.fromRank < 3;
    if (isRedAdvisor) {
      if (move.toRank >= 3 || move.toFile < 3 || move.toFile > 5) {
        return false;
      }
    } else {
      if (move.toRank < 7 || move.toFile < 3 || move.toFile > 5) {
        return false;
      }
    }

    return true;
  }

  static bool _isValidKingMove(List<List<String>> board, Move move) {
    // King moves 1 square horizontally or vertically, stays in palace
    final fileDiff = (move.toFile - move.fromFile).abs();
    final rankDiff = (move.toRank - move.fromRank).abs();

    if ((fileDiff == 1 && rankDiff == 0) || (fileDiff == 0 && rankDiff == 1)) {
      // Check if stays in palace
      final isRedKing = move.fromRank < 3;
      if (isRedKing) {
        if (move.toRank >= 3 || move.toFile < 3 || move.toFile > 5) {
          return false;
        }
      } else {
        if (move.toRank < 7 || move.toFile < 3 || move.toFile > 5) {
          return false;
        }
      }

      // Check king face-to-face rule: two kings cannot face each other directly
      if (_wouldKingsFaceEachOther(board, move)) {
        return false;
      }

      return true;
    }

    return false;
  }

  // Check if the move would result in kings facing each other directly
  static bool _wouldKingsFaceEachOther(List<List<String>> board, Move move) {
    // Find both kings
    int redKingFile = -1, redKingRank = -1;
    int blackKingFile = -1, blackKingRank = -1;

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece == 'K') {
          redKingFile = file;
          redKingRank = rank;
        } else if (piece == 'k') {
          blackKingFile = file;
          blackKingRank = rank;
        }
      }
    }

    // If we can't find both kings, no face-to-face issue
    if (redKingFile == -1 || blackKingFile == -1) return false;

    // Check if the move involves a king
    final fromPiece = board[move.fromRank][move.fromFile];
    if (fromPiece.toLowerCase() != 'k') return false;

    // Determine which king is moving
    final isRedKingMoving = fromPiece == 'K';
    int movingKingFile, movingKingRank;
    int otherKingFile, otherKingRank;

    if (isRedKingMoving) {
      movingKingFile = move.toFile;
      movingKingRank = move.toRank;
      otherKingFile = blackKingFile;
      otherKingRank = blackKingRank;
    } else {
      movingKingFile = move.toFile;
      movingKingRank = move.toRank;
      otherKingFile = redKingFile;
      otherKingRank = redKingRank;
    }

    // Check if kings are in the same file (column)
    if (movingKingFile != otherKingFile) return false;

    // Check if there are any pieces between the kings
    final startRank = movingKingRank < otherKingRank
        ? movingKingRank
        : otherKingRank;
    final endRank = movingKingRank < otherKingRank
        ? otherKingRank
        : movingKingRank;

    for (int rank = startRank + 1; rank < endRank; rank++) {
      if (board[rank][movingKingFile].isNotEmpty) {
        return false; // There's a piece between the kings
      }
    }

    return true; // Kings would face each other directly
  }

  static bool _isValidCannonMove(List<List<String>> board, Move move) {
    // Cannon moves like chariot, but needs to jump over exactly one piece to capture
    if (move.fromFile != move.toFile && move.fromRank != move.toRank) {
      return false; // Must move in straight line
    }

    final toPiece = board[move.toRank][move.toFile];
    final isCapture = toPiece.isNotEmpty;

    // Debug logging removed

    if (move.fromFile == move.toFile) {
      // Vertical move
      final start = move.fromRank < move.toRank ? move.fromRank : move.toRank;
      final end = move.fromRank < move.toRank ? move.toRank : move.fromRank;
      int pieceCount = 0;

      for (int rank = start + 1; rank < end; rank++) {
        if (board[rank][move.fromFile].isNotEmpty) {
          pieceCount++;
        }
      }

      if (isCapture) {
        return pieceCount == 1; // Must jump over exactly one piece
      } else {
        return pieceCount == 0; // Path must be clear
      }
    } else {
      // Horizontal move
      final start = move.fromFile < move.toFile ? move.fromFile : move.toFile;
      final end = move.fromFile < move.toFile ? move.toFile : move.fromFile;
      int pieceCount = 0;

      for (int file = start + 1; file < end; file++) {
        if (board[move.fromRank][file].isNotEmpty) {
          pieceCount++;
        }
      }

      if (isCapture) {
        return pieceCount == 1; // Must jump over exactly one piece
      } else {
        return pieceCount == 0; // Path must be clear
      }
    }
  }

  static bool _isValidPawnMove(List<List<String>> board, Move move) {
    // Pawn moves forward only until crossing river, then can move sideways too
    // In our coordinate system:
    // - Board ranks 0-9 (top to bottom)
    // - River is between ranks 4 and 5
    // - Red pawns start at ranks 6,7,8 and move UP (decreasing rank)
    // - Black pawns start at ranks 1,2,3 and move DOWN (increasing rank)

    final piece = board[move.fromRank][move.fromFile];
    final isRedPawn = piece == piece.toUpperCase(); // Red pieces are uppercase

    // Debug logging removed

    if (isRedPawn) {
      // Red pawn moves UP (decreasing rank numbers)
      // Before crossing river (rank >= 5): can only move forward (UP)
      // After crossing river (rank <= 4): can move forward OR sideways

      final hasCrossedRiver = move.fromRank <= 4; // Red pawn crossed river
      // Debug logging removed

      if (hasCrossedRiver) {
        // After crossing river: can move forward (UP) OR sideways
        if (move.fromFile == move.toFile && move.fromRank - move.toRank == 1) {
          return true; // Forward (UP)
        }
        if (move.fromRank == move.toRank &&
            (move.toFile - move.fromFile).abs() == 1) {
          return true; // Sideways
        }
        return false;
      } else {
        // Before crossing river: can ONLY move forward (UP)
        if (move.fromFile == move.toFile && move.fromRank - move.toRank == 1) {
          return true; // Forward only
        }
        return false;
      }
    } else {
      // Black pawn moves DOWN (increasing rank numbers)
      // Before crossing river (rank <= 4): can only move forward (DOWN)
      // After crossing river (rank >= 5): can move forward OR sideways

      final hasCrossedRiver = move.fromRank >= 5; // Black pawn crossed river
      // Debug logging removed

      if (hasCrossedRiver) {
        // After crossing river: can move forward (DOWN) OR sideways
        if (move.fromFile == move.toFile && move.toRank - move.fromRank == 1) {
          return true; // Forward (DOWN)
        }
        if (move.fromRank == move.toRank &&
            (move.toFile - move.fromFile).abs() == 1) {
          return true; // Sideways
        }
        return false;
      } else {
        // Before crossing river: can ONLY move forward (DOWN)
        if (move.fromFile == move.toFile && move.toRank - move.fromRank == 1) {
          return true; // Forward only
        }
        return false;
      }
    }
  }

  // Get all legal moves from a FEN position
  static List<String> getAllLegalMoves(String fen) {
    final legalMoves = <String>[];
    final board = FenParser.parseBoard(fen);
    final sideToMove = FenParser.getSideToMove(fen);

    // Iterate through all squares to find pieces of the side to move
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece.isEmpty) continue;

        // Check if this piece belongs to the side to move
        final isRedPiece = piece == piece.toUpperCase();
        final isRedToMove = sideToMove == 'w';
        if (isRedPiece != isRedToMove) continue;

        // Generate all possible moves for this piece
        final moves = _generateMovesForPiece(board, rank, file, piece);
        legalMoves.addAll(moves);
      }
    }

    return legalMoves;
  }

  // Generate all possible moves for a specific piece
  static List<String> _generateMovesForPiece(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final pieceType = piece.toLowerCase();

    // Convert board coordinates to UCI notation
    final fromFileUci = String.fromCharCode(97 + fromFile); // a=0, b=1, etc.
    final fromRankUci = 9 - fromRank; // Convert to UCI rank (0=bottom, 9=top)

    List<List<int>> boardMoves = [];
    switch (pieceType) {
      case 'k': // King
        boardMoves = _generateKingMoves(board, fromRank, fromFile, piece);
        break;
      case 'a': // Advisor
        boardMoves = _generateAdvisorMoves(board, fromRank, fromFile, piece);
        break;
      case 'e': // Elephant
        boardMoves = _generateElephantMoves(board, fromRank, fromFile, piece);
        break;
      case 'h': // Horse
        boardMoves = _generateHorseMoves(board, fromRank, fromFile, piece);
        break;
      case 'r': // Rook/Chariot
        boardMoves = _generateRookMoves(board, fromRank, fromFile, piece);
        break;
      case 'c': // Cannon
        boardMoves = _generateCannonMoves(board, fromRank, fromFile, piece);
        break;
      case 'p': // Pawn
        boardMoves = _generatePawnMoves(board, fromRank, fromFile, piece);
        break;
    }

    // Convert to UCI notation
    return boardMoves.map((move) {
      final toFileUci = String.fromCharCode(97 + move[0]);
      final toRankUci = 9 - move[1];
      return '$fromFileUci$fromRankUci$toFileUci$toRankUci';
    }).toList();
  }

  // Generate king moves (simplified - only within palace)
  static List<List<int>> _generateKingMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];
    final isRedKing = piece == piece.toUpperCase();

    // King can only move within palace (3x3 area)
    final palaceRanks = isRedKing ? [7, 8, 9] : [0, 1, 2];
    final palaceFiles = [3, 4, 5];

    // Check all adjacent squares
    for (int dr = -1; dr <= 1; dr++) {
      for (int df = -1; df <= 1; df++) {
        if (dr == 0 && df == 0) continue; // Skip current position

        final toRank = fromRank + dr;
        final toFile = fromFile + df;

        // Check if within palace
        if (!palaceRanks.contains(toRank) || !palaceFiles.contains(toFile)) {
          continue;
        }

        // Check if destination is empty or has opponent piece
        final toPiece = board[toRank][toFile];
        if (toPiece.isNotEmpty) {
          final isToRedPiece = toPiece == toPiece.toUpperCase();
          final isFromRedPiece = piece == piece.toUpperCase();
          if (isToRedPiece == isFromRedPiece) {
            continue; // Can't capture own piece
          }
        }

        moves.add([toFile, toRank]);
      }
    }

    return moves;
  }

  // Generate advisor moves (simplified - only within palace, diagonal only)
  static List<List<int>> _generateAdvisorMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];
    final isRedAdvisor = piece == piece.toUpperCase();

    // Advisor can only move within palace (3x3 area), diagonal only
    final palaceRanks = isRedAdvisor ? [7, 8, 9] : [0, 1, 2];
    final palaceFiles = [3, 4, 5];

    // Check diagonal moves only
    final diagonalMoves = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];

    for (final move in diagonalMoves) {
      final toRank = fromRank + move[0];
      final toFile = fromFile + move[1];

      // Check if within palace
      if (!palaceRanks.contains(toRank) || !palaceFiles.contains(toFile)) {
        continue;
      }

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isNotEmpty) {
        final isToRedPiece = toPiece == toPiece.toUpperCase();
        final isFromRedPiece = piece == piece.toUpperCase();
        if (isToRedPiece == isFromRedPiece) continue; // Can't capture own piece
      }

      moves.add([toFile, toRank]);
    }

    return moves;
  }

  // Generate elephant moves (simplified - 2 squares diagonally, can't cross river)
  static List<List<int>> _generateElephantMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];
    final isRedElephant = piece == piece.toUpperCase();

    // Elephant can't cross river
    final maxRank = isRedElephant
        ? 9
        : 4; // Red can't go below rank 4, Black can't go above rank 4

    // Check 2-square diagonal moves
    final diagonalMoves = [
      [-2, -2],
      [-2, 2],
      [2, -2],
      [2, 2],
    ];

    for (final move in diagonalMoves) {
      final toRank = fromRank + move[0];
      final toFile = fromFile + move[1];

      // Check bounds
      if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) continue;

      // Check river crossing
      if (isRedElephant && toRank > maxRank) continue;
      if (!isRedElephant && toRank < maxRank) continue;

      // Check if blocking piece exists (elephant can't jump)
      final blockRank = fromRank + move[0] ~/ 2;
      final blockFile = fromFile + move[1] ~/ 2;
      if (board[blockRank][blockFile].isNotEmpty) continue;

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isNotEmpty) {
        final isToRedPiece = toPiece == toPiece.toUpperCase();
        final isFromRedPiece = piece == piece.toUpperCase();
        if (isToRedPiece == isFromRedPiece) continue; // Can't capture own piece
      }

      moves.add([toFile, toRank]);
    }

    return moves;
  }

  // Generate horse moves (simplified - L-shaped moves)
  static List<List<int>> _generateHorseMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];

    // Horse moves in L-shape: 2 squares in one direction, then 1 square perpendicular
    final horseMoves = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];

    for (final move in horseMoves) {
      final toRank = fromRank + move[0];
      final toFile = fromFile + move[1];

      // Check bounds
      if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) continue;

      // Check if horse leg is blocked
      int legRank, legFile;
      if (move[0].abs() == 2) {
        // Moving 2 ranks, check leg at 1 rank
        legRank = fromRank + (move[0] > 0 ? 1 : -1);
        legFile = fromFile;
      } else {
        // Moving 2 files, check leg at 1 file
        legRank = fromRank;
        legFile = fromFile + (move[1] > 0 ? 1 : -1);
      }

      if (board[legRank][legFile].isNotEmpty) continue; // Leg is blocked

      // Check if destination is empty or has opponent piece
      final toPiece = board[toRank][toFile];
      if (toPiece.isNotEmpty) {
        final isToRedPiece = toPiece == toPiece.toUpperCase();
        final isFromRedPiece = piece == piece.toUpperCase();
        if (isToRedPiece == isFromRedPiece) continue; // Can't capture own piece
      }

      moves.add([toFile, toRank]);
    }

    return moves;
  }

  // Generate rook moves (horizontal and vertical)
  static List<List<int>> _generateRookMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];

    // Check all 4 directions
    final directions = [
      [-1, 0], [1, 0], [0, -1], [0, 1], // up, down, left, right
    ];

    for (final dir in directions) {
      for (int i = 1; i < 10; i++) {
        final toRank = fromRank + dir[0] * i;
        final toFile = fromFile + dir[1] * i;

        // Check bounds
        if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) break;

        final toPiece = board[toRank][toFile];

        if (toPiece.isNotEmpty) {
          // Check if it's opponent piece
          final isToRedPiece = toPiece == toPiece.toUpperCase();
          final isFromRedPiece = piece == piece.toUpperCase();
          if (isToRedPiece != isFromRedPiece) {
            moves.add([toFile, toRank]); // Can capture opponent piece
          }
          break; // Stop at first piece
        } else {
          moves.add([toFile, toRank]); // Empty square, can move
        }
      }
    }

    return moves;
  }

  // Generate cannon moves (horizontal and vertical, must jump over one piece to capture)
  static List<List<int>> _generateCannonMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];

    // Check all 4 directions
    final directions = [
      [-1, 0], [1, 0], [0, -1], [0, 1], // up, down, left, right
    ];

    for (final dir in directions) {
      bool hasJumped = false;

      for (int i = 1; i < 10; i++) {
        final toRank = fromRank + dir[0] * i;
        final toFile = fromFile + dir[1] * i;

        // Check bounds
        if (toRank < 0 || toRank > 9 || toFile < 0 || toFile > 8) break;

        final toPiece = board[toRank][toFile];

        if (toPiece.isNotEmpty) {
          if (!hasJumped) {
            // First piece encountered, can jump over it
            hasJumped = true;
          } else {
            // Second piece encountered, can capture if it's opponent
            final isToRedPiece = toPiece == toPiece.toUpperCase();
            final isFromRedPiece = piece == piece.toUpperCase();
            if (isToRedPiece != isFromRedPiece) {
              moves.add([toFile, toRank]); // Can capture opponent piece
            }
            break; // Stop after second piece
          }
        } else {
          if (!hasJumped) {
            // No piece jumped yet, can move to empty square
            moves.add([toFile, toRank]);
          }
          // If hasJumped, can't move to empty square
        }
      }
    }

    return moves;
  }

  // Generate pawn moves
  static List<List<int>> _generatePawnMoves(
    List<List<String>> board,
    int fromRank,
    int fromFile,
    String piece,
  ) {
    final moves = <List<int>>[];
    final isRedPawn = piece == piece.toUpperCase();

    if (isRedPawn) {
      // Red pawn moves UP (decreasing rank numbers)
      final hasCrossedRiver = fromRank <= 4; // Red pawn crossed river

      if (hasCrossedRiver) {
        // After crossing river: can move forward (UP) OR sideways
        // Forward (UP)
        if (fromRank > 0) {
          final toPiece = board[fromRank - 1][fromFile];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add([fromFile, fromRank - 1]);
          }
        }
        // Sideways
        if (fromFile > 0) {
          final toPiece = board[fromRank][fromFile - 1];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add([fromFile - 1, fromRank]);
          }
        }
        if (fromFile < 8) {
          final toPiece = board[fromRank][fromFile + 1];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add([fromFile + 1, fromRank]);
          }
        }
      } else {
        // Before crossing river: can ONLY move forward (UP)
        if (fromRank > 0) {
          final toPiece = board[fromRank - 1][fromFile];
          if (toPiece.isEmpty || toPiece != toPiece.toUpperCase()) {
            moves.add([fromFile, fromRank - 1]);
          }
        }
      }
    } else {
      // Black pawn moves DOWN (increasing rank numbers)
      final hasCrossedRiver = fromRank >= 5; // Black pawn crossed river

      if (hasCrossedRiver) {
        // After crossing river: can move forward (DOWN) OR sideways
        // Forward (DOWN)
        if (fromRank < 9) {
          final toPiece = board[fromRank + 1][fromFile];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add([fromFile, fromRank + 1]);
          }
        }
        // Sideways
        if (fromFile > 0) {
          final toPiece = board[fromRank][fromFile - 1];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add([fromFile - 1, fromRank]);
          }
        }
        if (fromFile < 8) {
          final toPiece = board[fromRank][fromFile + 1];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add([fromFile + 1, fromRank]);
          }
        }
      } else {
        // Before crossing river: can ONLY move forward (DOWN)
        if (fromRank < 9) {
          final toPiece = board[fromRank + 1][fromFile];
          if (toPiece.isEmpty || toPiece == toPiece.toUpperCase()) {
            moves.add([fromFile, fromRank + 1]);
          }
        }
      }
    }

    return moves;
  }
}
