import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_controller.dart';

class BestMovesPanel extends ConsumerWidget {
  const BestMovesPanel({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardControllerProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Moves',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          if (state.bestLines.isEmpty)
            const Text('No analysis available')
          else
            Expanded(
              child: ListView.builder(
                itemCount: state.bestLines.length,
                itemBuilder: (context, index) {
                  final line = state.bestLines[index];
                  return _buildBestLineCard(line);
                },
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBestLineCard(BestLine line) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PV ${line.index}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(line.scoreCp),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    line.scoreString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Depth: ${line.depth}'),
            const SizedBox(height: 4),
            Text(
              'Moves: ${line.pv.join(' ')}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            if (line.firstMove.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('First move: '),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      line.firstMove,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getScoreColor(int scoreCp) {
    if (scoreCp > 100) return Colors.green;
    if (scoreCp > 50) return Colors.lightGreen;
    if (scoreCp > -50) return Colors.orange;
    if (scoreCp > -100) return Colors.red[300]!;
    return Colors.red;
  }
}
