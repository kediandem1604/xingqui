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
        return move.toRank < 3 && move.toFile >= 3 && move.toFile <= 5;
      } else {
        return move.toRank >= 7 && move.toFile >= 3 && move.toFile <= 5;
      }
    }

    return false;
  }

  static bool _isValidCannonMove(List<List<String>> board, Move move) {
    // Cannon moves like chariot, but needs to jump over exactly one piece to capture
    if (move.fromFile != move.toFile && move.fromRank != move.toRank) {
      return false; // Must move in straight line
    }

    final toPiece = board[move.toRank][move.toFile];
    final isCapture = toPiece.isNotEmpty;

    // Debug logging for cannon moves
    print(
      'Cannon move: ${move.fromFile}${move.fromRank} -> ${move.toFile}${move.toRank}, capture: $isCapture',
    );

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
        print('Cannon vertical capture: pieceCount=$pieceCount');
        return pieceCount == 1; // Must jump over exactly one piece
      } else {
        print('Cannon vertical move: pieceCount=$pieceCount');
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
        print('Cannon horizontal capture: pieceCount=$pieceCount');
        return pieceCount == 1; // Must jump over exactly one piece
      } else {
        print('Cannon horizontal move: pieceCount=$pieceCount');
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

    print(
      'Pawn move: ${move.fromFile}${move.fromRank} -> ${move.toFile}${move.toRank}',
    );
    print('isRedPawn: $isRedPawn, piece: $piece');

    if (isRedPawn) {
      // Red pawn moves UP (decreasing rank numbers)
      // Before crossing river (rank >= 5): can only move forward (UP)
      // After crossing river (rank <= 4): can move forward OR sideways

      final hasCrossedRiver = move.fromRank <= 4; // Red pawn crossed river
      print(
        'Red pawn - fromRank: ${move.fromRank}, hasCrossedRiver: $hasCrossedRiver',
      );

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
      print(
        'Black pawn - fromRank: ${move.fromRank}, hasCrossedRiver: $hasCrossedRiver',
      );

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
}
