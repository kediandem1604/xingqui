// Engine output parser for UCI/UCCI protocols

class EngineParser {
  // Parse bestmove from engine output
  static String parseBestMove(String line) {
    // Example: "bestmove e7d7" or "bestmove (none)"
    final parts = line.split(' ');
    final i = parts.indexOf('bestmove');
    if (i >= 0 && i + 1 < parts.length) {
      final move = parts[i + 1];
      return move == '(none)' ? '' : move;
    }
    return '';
  }

  // Parse info line for MultiPV analysis
  static PvInfo? parseInfoPv(String line) {
    // Handles UCI and UCCI variants, e.g.:
    //  - "info depth 14 multipv 2 score cp 58 ... pv h2e2 e3e4"
    //  - "info depth 8 score 0 pv b2b9 ..." (EleEye without 'cp' and 'multipv')
    if (!line.startsWith('info')) return null;

    final parts = line.split(' ');
    int multipv = 1; // default when missing
    int? depth;
    int? score;
    final pvMoves = <String>[];

    for (int i = 0; i < parts.length; i++) {
      switch (parts[i]) {
        case 'multipv':
          if (i + 1 < parts.length) {
            final v = int.tryParse(parts[i + 1]);
            if (v != null) multipv = v;
          }
          break;
        case 'depth':
          if (i + 1 < parts.length) {
            depth = int.tryParse(parts[i + 1]);
          }
          break;
        case 'score':
          // Accept both "score cp N" and "score N"
          if (i + 2 < parts.length && parts[i + 1] == 'cp') {
            score = int.tryParse(parts[i + 2]);
            i += 2;
          } else if (i + 1 < parts.length) {
            final v = int.tryParse(parts[i + 1]);
            if (v != null) {
              score = v;
              i += 1;
            }
          }
          break;
        case 'pv':
          // Collect all moves after 'pv'
          for (int j = i + 1; j < parts.length; j++) {
            pvMoves.add(parts[j]);
          }
          i = parts.length; // Break loop
          break;
      }
    }

    if (depth == null || score == null || pvMoves.isEmpty) {
      return null;
    }

    return PvInfo(multipv, depth, score, pvMoves);
  }

  // Parse engine identification
  static String? parseEngineName(String line) {
    if (line.startsWith('id name ')) {
      return line.substring(8);
    }
    return null;
  }

  // Parse engine author
  static String? parseEngineAuthor(String line) {
    if (line.startsWith('id author ')) {
      return line.substring(10);
    }
    return null;
  }

  // Check if line indicates engine is ready
  static bool isReadyMessage(String line) {
    return line.contains('readyok') || line.contains('ucciok');
  }

  // Check if line indicates UCI/UCCI protocol acknowledgment
  static bool isProtocolOk(String line) {
    return line.contains('uciok') || line.contains('ucciok');
  }
}

// Information about a principal variation (PV)
class PvInfo {
  final int multipv; // PV number (1, 2, 3, ...)
  final int depth; // Search depth
  final int scoreCp; // Score in centipawns (can be negative)
  final List<String> pvMoves; // Sequence of moves in this PV

  const PvInfo(this.multipv, this.depth, this.scoreCp, this.pvMoves);

  @override
  String toString() {
    return 'PV$multipv: depth=$depth, score=${scoreCp}cp, moves=${pvMoves.join(' ')}';
  }

  // Get the first move of this PV
  String get firstMove => pvMoves.isNotEmpty ? pvMoves.first : '';

  // Get score as a readable string
  String get scoreString {
    if (scoreCp > 0) {
      return '+${scoreCp / 100}';
    } else {
      return '${scoreCp / 100}';
    }
  }
}
