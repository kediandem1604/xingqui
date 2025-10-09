import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'board_controller.dart';
import '../../core/fen.dart';

class BoardView extends ConsumerWidget {
  final bool showBestMoves;

  const BoardView({super.key, this.showBestMoves = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardControllerProvider);
    final controller = ref.read(boardControllerProvider.notifier);

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Engine status
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('Engine: ${state.selectedEngine}')],
                      ),
                    ),
                    if (state.isEngineThinking)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Thinking...'),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Setup mode UI or Board
              if (state.isSetupMode) ...[
                _buildSetupModeUI(state, controller),
              ] else ...[
                // Board (maximize square size within available space)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      final dim =
                          size.shortestSide; // use the limiting dimension
                      return Center(
                        child: SizedBox(
                          width: dim,
                          height: dim,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    // SVG Board Background
                                    SvgPicture.asset(
                                      'assets/boards/xiangqi_gmchess_wood.svg',
                                      fit: BoxFit.fill,
                                    ),
                                    // Best move arrows overlay should appear BELOW pieces
                                    if (showBestMoves)
                                      _buildBestMoveArrows(
                                        state,
                                        constraints.biggest,
                                      ),
                                    // Pieces overlay
                                    _buildPiecesOverlay(
                                      state,
                                      constraints.biggest,
                                    ),
                                    // Move animation overlay
                                    _buildMoveAnimation(
                                      state,
                                      constraints.biggest,
                                      controller,
                                    ),
                                    // Gesture detector for tap handling
                                    GestureDetector(
                                      onTapDown: (details) => _onBoardTap(
                                        context,
                                        details,
                                        state,
                                        controller,
                                      ),
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Only show move history when not in setup mode
              if (!state.isSetupMode) ...[
                const SizedBox(height: 16),

                // Move history
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Move History:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            state.moves.take(state.pointer).join(' '),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Game notifications overlay
        ...state.notifications.map(
          (notification) =>
              Positioned(top: 0, left: 0, right: 0, child: notification),
        ),
      ],
    );
  }

  Widget _buildPiecesOverlay(BoardState state, Size boardSize) {
    final board = FenParser.parseBoard(state.fen);

    // With square container and BoxFit.fill, each cell is uniform
    final actualCellWidth = boardSize.width / 9;
    final actualCellHeight = boardSize.height / 10;
    const double boardOffsetX = 0;
    const double boardOffsetY = 0;

    return Stack(
      children: [
        // Draw possible move indicators
        ..._buildPossibleMoveIndicators(
          state,
          actualCellWidth,
          actualCellHeight,
          boardOffsetX,
          boardOffsetY,
        ),
        // Arrows are drawn in a separate painter below pieces, handled above
        // Draw pieces
        ..._buildPieces(
          board,
          state,
          actualCellWidth,
          actualCellHeight,
          boardOffsetX,
          boardOffsetY,
        ),
      ],
    );
  }

  Widget _buildBestMoveArrows(BoardState state, Size boardSize) {
    // Use same geometry as pieces overlay
    final cellWidth = boardSize.width / 9;
    final cellHeight = boardSize.height / 10;
    const double boardOffsetX = 0;
    const double boardOffsetY = 0;

    // Collect arrow segments from PV first moves
    final List<_Arrow> arrows = [];
    final maxArrows = state.multiPv.clamp(1, 3);
    final available = state.bestLines.take(maxArrows).toList();
    for (final bl in available) {
      if (bl.firstMove.isEmpty || bl.firstMove.length < 4) continue;
      final mv = _parseUciMove(bl.firstMove);
      if (mv == null) continue;

      // Calculate display positions based on isRedAtBottom
      final fromFile = mv.fromFile;
      final fromRank = state.isRedAtBottom ? mv.fromRank : 9 - mv.fromRank;
      final toFile = mv.toFile;
      final toRank = state.isRedAtBottom ? mv.toRank : 9 - mv.toRank;

      arrows.add(_Arrow(fromFile, fromRank, toFile, toRank));
    }

    if (arrows.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      size: Size.infinite,
      painter: _ArrowsPainter(
        arrows: arrows,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        offsetX: boardOffsetX,
        offsetY: boardOffsetY,
      ),
    );
  }

  List<Widget> _buildPossibleMoveIndicators(
    BoardState state,
    double cellWidth,
    double cellHeight,
    double boardOffsetX,
    double boardOffsetY,
  ) {
    final indicatorSize = (cellWidth * 0.3).clamp(10.0, 20.0);

    return state.possibleMoves.map((move) {
      // Calculate display position based on isRedAtBottom
      final displayX = move.dx;
      final displayY = state.isRedAtBottom ? move.dy : 9 - move.dy;

      return Positioned(
        left:
            boardOffsetX +
            displayX * cellWidth +
            (cellWidth - indicatorSize) / 2,
        top:
            boardOffsetY +
            displayY * cellHeight +
            (cellHeight - indicatorSize) / 2,
        child: Container(
          width: indicatorSize,
          height: indicatorSize,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPieces(
    List<List<String>> board,
    BoardState state,
    double cellWidth,
    double cellHeight,
    double boardOffsetX,
    double boardOffsetY,
  ) {
    List<Widget> pieces = [];
    final anim = state.pendingAnimation;

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = board[rank][file];
        if (piece.isNotEmpty) {
          // During animation, hide the piece at source and any captured piece at destination
          if (anim != null) {
            if ((file == anim.fromFile && rank == anim.fromRank) ||
                (file == anim.toFile && rank == anim.toRank)) {
              continue;
            }
          }

          // Calculate display position based on isRedAtBottom
          final displayRank = state.isRedAtBottom ? rank : 9 - rank;
          final displayFile = file;

          final isSelected =
              state.selectedFile == file && state.selectedRank == rank;
          final pieceWidget = _buildPiece(
            piece,
            displayFile,
            displayRank,
            isSelected,
            cellWidth,
            cellHeight,
            boardOffsetX,
            boardOffsetY,
          );
          pieces.add(pieceWidget);
        }
      }
    }

    return pieces;
  }

  Widget _buildMoveAnimation(
    BoardState state,
    Size boardSize,
    BoardController controller,
  ) {
    final anim = state.pendingAnimation;
    if (anim == null) return const SizedBox.shrink();

    // Use EXACTLY the same geometry as overlays (square board with fill)
    const double boardOffsetX = 0;
    const double boardOffsetY = 0;
    final double cellWidth = boardSize.width / 9;
    final double cellHeight = boardSize.height / 10;

    // Piece asset
    final asset = _getPieceAsset(anim.piece);
    if (asset == null) return const SizedBox.shrink();

    final pieceSize = (cellWidth * 0.8).clamp(30.0, 60.0);

    // Calculate display positions based on isRedAtBottom
    final fromFile = anim.fromFile;
    final fromRank = state.isRedAtBottom ? anim.fromRank : 9 - anim.fromRank;
    final toFile = anim.toFile;
    final toRank = state.isRedAtBottom ? anim.toRank : 9 - anim.toRank;

    final start = Offset(
      boardOffsetX + fromFile * cellWidth + (cellWidth - pieceSize) / 2,
      boardOffsetY + fromRank * cellHeight + (cellHeight - pieceSize) / 2,
    );
    final end = Offset(
      boardOffsetX + toFile * cellWidth + (cellWidth - pieceSize) / 2,
      boardOffsetY + toRank * cellHeight + (cellHeight - pieceSize) / 2,
    );

    return _AnimatedPiece(
      asset: asset,
      size: pieceSize,
      start: start,
      end: end,
      onCompleted: () {
        controller.commitAnimatedMove();
      },
      // When capturing, briefly fade-in at destination border
    );
  }

  Widget _buildPiece(
    String piece,
    int file,
    int rank,
    bool isSelected,
    double cellWidth,
    double cellHeight,
    double boardOffsetX,
    double boardOffsetY,
  ) {
    final pieceAsset = _getPieceAsset(piece);
    if (pieceAsset == null) return const SizedBox.shrink();

    final pieceSize = (cellWidth * 0.8).clamp(30.0, 60.0);

    return Positioned(
      left: boardOffsetX + file * cellWidth + (cellWidth - pieceSize) / 2,
      top: boardOffsetY + rank * cellHeight + (cellHeight - pieceSize) / 2,
      child: Container(
        width: pieceSize,
        height: pieceSize,
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              )
            : null,
        child: Center(
          child: SvgPicture.asset(
            pieceAsset,
            width: pieceSize * 0.9,
            height: pieceSize * 0.9,
          ),
        ),
      ),
    );
  }

  void _onBoardTap(
    BuildContext context,
    TapDownDetails details,
    BoardState state,
    BoardController controller,
  ) {
    // Don't handle normal moves in setup mode
    if (state.isSetupMode) return;

    // Convert tap position to board coordinates using same metrics
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    final boardSize = renderBox.size;
    final cellWidth = boardSize.width / 9;
    final cellHeight = boardSize.height / 10;
    final dx = localPosition.dx.clamp(0.0, boardSize.width - 0.01);
    final dy = localPosition.dy.clamp(0.0, boardSize.height - 0.01);

    // Calculate file and rank (0-based, top-left origin)
    final file = (dx / cellWidth).floor().clamp(0, 8);
    final displayRank = (dy / cellHeight).floor().clamp(0, 9);

    // Convert display rank to actual rank based on isRedAtBottom
    final rank = state.isRedAtBottom ? displayRank : 9 - displayRank;

    // Handle piece selection and movement
    controller.onBoardTap(file, rank);
  }

  // Helpers for arrows
  _Move? _parseUciMove(String uci) {
    if (uci.length < 4) return null;
    final fromFile = uci.codeUnitAt(0) - 97; // 'a' -> 0
    // Xiangqi rank digits are 0..9 from bottom to top; our board ranks are 0..9 top-down
    // Convert: uiDigit d -> boardRank = 9 - d
    final fromRank = 9 - (int.tryParse(uci[1]) ?? 0);
    final toFile = uci.codeUnitAt(2) - 97;
    final toRank = 9 - (int.tryParse(uci[3]) ?? 0);
    if (fromFile < 0 || fromFile > 8 || toFile < 0 || toFile > 8) return null;
    if (fromRank < 0 || fromRank > 9 || toRank < 0 || toRank > 9) return null;
    return _Move(fromFile, fromRank, toFile, toRank);
  }
}

class _AnimatedPiece extends StatefulWidget {
  final String asset;
  final double size;
  final Offset start;
  final Offset end;
  final VoidCallback onCompleted;
  const _AnimatedPiece({
    required this.asset,
    required this.size,
    required this.start,
    required this.end,
    required this.onCompleted,
  });

  @override
  State<_AnimatedPiece> createState() => _AnimatedPieceState();
}

class _AnimatedPieceState extends State<_AnimatedPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _position;
  late final Animation<double> _opacity;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _position = Tween<Offset>(
      begin: widget.start,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasCompleted) {
        _hasCompleted = true;
        Future.microtask(() {
          widget.onCompleted();
        });
      }
    });
    // Extra safety: if for any reason status listener misses, trigger after duration
    Future.delayed(
      _controller.duration! + const Duration(milliseconds: 100),
      () {
        if (mounted &&
            _controller.status != AnimationStatus.forward &&
            !_hasCompleted) {
          _hasCompleted = true;
          widget.onCompleted();
        }
      },
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pos = _position.value;
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Opacity(
              opacity: _opacity.value,
              child: SvgPicture.asset(
                widget.asset,
                width: widget.size,
                height: widget.size,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Move {
  final int fromFile;
  final int fromRank;
  final int toFile;
  final int toRank;
  _Move(this.fromFile, this.fromRank, this.toFile, this.toRank);
}

class _Arrow {
  final int fromFile;
  final int fromRank;
  final int toFile;
  final int toRank;
  _Arrow(this.fromFile, this.fromRank, this.toFile, this.toRank);
}

class _ArrowsPainter extends CustomPainter {
  final List<_Arrow> arrows;
  final double cellWidth;
  final double cellHeight;
  final double offsetX;
  final double offsetY;
  _ArrowsPainter({
    required this.arrows,
    required this.cellWidth,
    required this.cellHeight,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Colors for up to 3 arrows
    final List<Color> colors = [Colors.blue, Colors.green, Colors.orange];

    for (int i = 0; i < arrows.length; i++) {
      final a = arrows[i];
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.9)
        ..strokeWidth = (cellWidth * 0.1).clamp(2.0, 4.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final start = Offset(
        offsetX + a.fromFile * cellWidth + cellWidth / 2,
        offsetY + a.fromRank * cellHeight + cellHeight / 2,
      );
      final end = Offset(
        offsetX + a.toFile * cellWidth + cellWidth / 2,
        offsetY + a.toRank * cellHeight + cellHeight / 2,
      );

      // Draw line
      canvas.drawLine(start, end, paint);

      // Draw arrowhead
      final arrowLength = (cellWidth * 0.35).clamp(10.0, 18.0);
      final angle = (end - start).direction;
      final arrowAngle = 0.6; // radians
      final p1 = end - Offset.fromDirection(angle - arrowAngle, arrowLength);
      final p2 = end - Offset.fromDirection(angle + arrowAngle, arrowLength);
      final head = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(p1.dx, p1.dy)
        ..moveTo(end.dx, end.dy)
        ..lineTo(p2.dx, p2.dy);
      canvas.drawPath(head, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY;
  }
}

// Setup mode UI
Widget _buildSetupModeUI(BoardState state, BoardController controller) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          // Setup controls - compact header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Setup Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    // Always show navigation buttons in setup mode
                    ElevatedButton(
                      onPressed: controller.canUndoSetupMove()
                          ? controller.undoSetupMove
                          : null,
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: controller.resetSetupBoard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        foregroundColor: Colors.red[800],
                      ),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: controller.canRedoSetupMove()
                          ? controller.redoSetupMove
                          : null,
                      child: const Text('Next'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: controller.startGameFromSetup,
                      child: const Text('Start Game'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: controller.exitSetupMode,
                      child: const Text('Exit Setup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Main setup area with board and pieces
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final boardHeight =
                    size.height *
                    0.7; // Board takes 70% of height to give more space to pieces
                final pieceAreaHeight =
                    (size.height - boardHeight) /
                    2; // Space for pieces above and below

                return Column(
                  children: [
                    // Top pieces - Red pieces
                    SizedBox(
                      height: pieceAreaHeight,
                      child: _buildTopBottomPieces(state, controller, 'top'),
                    ),
                    // Center board - reasonable width
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width:
                              size.width *
                              0.35, // Use 35% of available width to give more space to pieces
                          height: boardHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    // SVG Board Background
                                    SvgPicture.asset(
                                      'assets/boards/xiangqi_gmchess_wood.svg',
                                      fit: BoxFit.fill,
                                    ),
                                    // Setup pieces overlay
                                    _buildSetupPiecesOverlay(
                                      state,
                                      constraints.biggest,
                                    ),
                                    // Gesture detector for setup
                                    GestureDetector(
                                      onTapDown: (details) => _onSetupBoardTap(
                                        context,
                                        details,
                                        state,
                                        controller,
                                      ),
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom pieces - Black pieces
                    SizedBox(
                      height: pieceAreaHeight,
                      child: _buildTopBottomPieces(state, controller, 'bottom'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTopBottomPieces(
  BoardState state,
  BoardController controller,
  String position,
) {
  final isTop = position == 'top';
  // Red pieces position depends on isRedAtBottom setting
  final isRed = state.isRedAtBottom ? !isTop : isTop;

  final pieces = state.setupPieces.entries
      .where(
        (entry) =>
            entry.value > 0 &&
            ((isRed && entry.key == entry.key.toUpperCase()) ||
                (!isRed && entry.key == entry.key.toLowerCase())),
      )
      .toList();

  return Container(
    padding: const EdgeInsets.all(4),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isRed ? 'Quân Đỏ' : 'Quân Đen',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: pieces
                  .map(
                    (entry) => _buildTopBottomPieceButton(
                      entry.key,
                      entry.value,
                      state,
                      controller,
                      isTop,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTopBottomPieceButton(
  String piece,
  int count,
  BoardState state,
  BoardController controller,
  bool isTop,
) {
  final isSelected = state.selectedSetupPiece == piece;
  final pieceAsset = _getPieceAsset(piece);

  return GestureDetector(
    onTap: () => controller.selectSetupPiece(piece),
    child: Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          if (pieceAsset != null)
            Center(child: SvgPicture.asset(pieceAsset, width: 55, height: 55))
          else
            Center(
              child: Text(
                piece,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          if (count > 1)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildSetupPiecesOverlay(BoardState state, Size boardSize) {
  final cellWidth = boardSize.width / 9;
  final cellHeight = boardSize.height / 10;
  final board = FenParser.parseBoard(state.fen);

  return Stack(
    children: [
      // Draw pieces using SVG images
      ..._buildSetupPieces(board, state, cellWidth, cellHeight),
    ],
  );
}

List<Widget> _buildSetupPieces(
  List<List<String>> board,
  BoardState state,
  double cellWidth,
  double cellHeight,
) {
  List<Widget> pieces = [];

  for (int rank = 0; rank < 10; rank++) {
    for (int file = 0; file < 9; file++) {
      final piece = board[rank][file];
      if (piece.isNotEmpty) {
        final pieceAsset = _getPieceAsset(piece);
        if (pieceAsset != null) {
          final pieceSize = (cellWidth * 0.8).clamp(30.0, 60.0);

          pieces.add(
            Positioned(
              left: file * cellWidth + (cellWidth - pieceSize) / 2,
              top: rank * cellHeight + (cellHeight - pieceSize) / 2,
              child: SvgPicture.asset(
                pieceAsset,
                width: pieceSize,
                height: pieceSize,
              ),
            ),
          );
        }
      }
    }
  }

  return pieces;
}

void _onSetupBoardTap(
  BuildContext context,
  TapDownDetails details,
  BoardState state,
  BoardController controller,
) {
  if (!state.isSetupMode) return;

  final RenderBox renderBox = context.findRenderObject() as RenderBox;
  final localPosition = renderBox.globalToLocal(details.globalPosition);

  final cellWidth = renderBox.size.width / 9;
  final cellHeight = renderBox.size.height / 10;

  final file = (localPosition.dx / cellWidth).floor().clamp(0, 8);
  final rank = (localPosition.dy / cellHeight).floor().clamp(0, 9);

  if (state.selectedSetupPiece != null) {
    controller.placePieceOnBoard(file, rank);
  } else {
    // If no piece selected, try to remove piece
    controller.removePieceFromBoard(file, rank);
  }
}

String? _getPieceAsset(String piece) {
  final isRed = piece == piece.toUpperCase();
  final color = isRed ? 'red' : 'black';

  switch (piece.toLowerCase()) {
    case 'r':
      return 'assets/pieces/xiangqi/${color}_rook.svg';
    case 'h':
      return 'assets/pieces/xiangqi/${color}_knight.svg';
    case 'e':
      return 'assets/pieces/xiangqi/${color}_bishop.svg';
    case 'a':
      return 'assets/pieces/xiangqi/${color}_advisor.svg';
    case 'k':
      return 'assets/pieces/xiangqi/${color}_king.svg';
    case 'c':
      return 'assets/pieces/xiangqi/${color}_cannon.svg';
    case 'p':
      return 'assets/pieces/xiangqi/${color}_pawn.svg';
    default:
      return null;
  }
}
