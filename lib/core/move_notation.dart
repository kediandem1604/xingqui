// Move notation for Xiangqi
// Supports both UCI-like format (e2e4) and Chinese notation

class MoveNotation {
  // Convert UCI-like move to Chinese notation
  static String uciToChinese(String uciMove) {
    if (uciMove.length < 4) return uciMove;
    
    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    
    final fromFile = from[0];
    final fromRank = int.parse(from[1]);
    final toFile = to[0];
    final toRank = int.parse(to[1]);
    
    // Convert file letters to numbers (a=0, b=1, ..., i=8)
    final fromFileNum = fromFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toFileNum = toFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
    
    // Chinese notation: from piece + from position + to position
    // For now, return simplified format
    return '${fileToChinese(fromFileNum)}${rankToChinese(fromRank)}${fileToChinese(toFileNum)}${rankToChinese(toRank)}';
  }
  
  static String fileToChinese(int file) {
    const files = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return files[file];
  }
  
  static String rankToChinese(int rank) {
    const ranks = ['十', '九', '八', '七', '六', '五', '四', '三', '二', '一'];
    return ranks[rank];
  }
  
  // Parse UCI move format (e.g., "e2e4")
  static Move? parseUciMove(String uciMove) {
    if (uciMove.length < 4) return null;
    
    try {
      final from = uciMove.substring(0, 2);
      final to = uciMove.substring(2, 4);
      
      final fromFile = from[0];
      final fromRank = int.parse(from[1]);
      final toFile = to[0];
      final toRank = int.parse(to[1]);
      
      // Validate coordinates (0-8 for files, 0-9 for ranks)
      if (fromFile.codeUnitAt(0) < 'a'.codeUnitAt(0) || 
          fromFile.codeUnitAt(0) > 'i'.codeUnitAt(0) ||
          toFile.codeUnitAt(0) < 'a'.codeUnitAt(0) || 
          toFile.codeUnitAt(0) > 'i'.codeUnitAt(0) ||
          fromRank < 0 || fromRank > 9 ||
          toRank < 0 || toRank > 9) {
        return null;
      }
      
      return Move(
        fromFile: fromFile.codeUnitAt(0) - 'a'.codeUnitAt(0),
        fromRank: fromRank,
        toFile: toFile.codeUnitAt(0) - 'a'.codeUnitAt(0),
        toRank: toRank,
      );
    } catch (e) {
      return null;
    }
  }
  
  // Convert Move to UCI string
  static String moveToUci(Move move) {
    final fromFile = String.fromCharCode('a'.codeUnitAt(0) + move.fromFile);
    final toFile = String.fromCharCode('a'.codeUnitAt(0) + move.toFile);
    return '$fromFile${move.fromRank}$toFile${move.toRank}';
  }
  
  // Check if move is within board bounds
  static bool isValidCoordinate(int file, int rank) {
    return file >= 0 && file <= 8 && rank >= 0 && rank <= 9;
  }
}

class Move {
  final int fromFile;
  final int fromRank;
  final int toFile;
  final int toRank;
  
  const Move({
    required this.fromFile,
    required this.fromRank,
    required this.toFile,
    required this.toRank,
  });
  
  @override
  String toString() {
    return MoveNotation.moveToUci(this);
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Move &&
        other.fromFile == fromFile &&
        other.fromRank == fromRank &&
        other.toFile == toFile &&
        other.toRank == toRank;
  }
  
  @override
  int get hashCode {
    return fromFile.hashCode ^
        fromRank.hashCode ^
        toFile.hashCode ^
        toRank.hashCode;
  }
}
