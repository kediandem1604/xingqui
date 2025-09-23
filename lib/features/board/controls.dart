import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_controller.dart';
import 'package:process_run/shell.dart';
import '../../core/logger.dart';
// Board recognition removed

class Controls extends ConsumerWidget {
  const Controls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(boardControllerProvider);
    final controller = ref.read(boardControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Engine selection
          Row(
            children: [
              const Text('Engine: '),
              DropdownButton<String>(
                value: state.selectedEngine,
                items: const [
                  DropdownMenuItem(value: 'Pikafish', child: Text('Pikafish')),
                  DropdownMenuItem(value: 'EleEye', child: Text('EleEye')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.switchEngine(value);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Logs
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final path = await AppLogger().getLogsDirectoryPath();
                  // Try to open with system file explorer
                  try {
                    final shell = Shell();
                    if (Theme.of(context).platform == TargetPlatform.windows) {
                      await shell.run('start "" "$path"');
                    } else if (Theme.of(context).platform ==
                        TargetPlatform.macOS) {
                      await shell.run('open "$path"');
                    } else {
                      await shell.run('xdg-open "$path"');
                    }
                  } catch (_) {}
                },
                child: const Text('Open Logs Folder'),
              ),
            ],
          ),

          // MultiPV selection
          Row(
            children: [
              const Text('Best Moves: '),
              Slider(
                value: state.multiPv.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                label: state.multiPv.toString(),
                onChanged: (value) {
                  controller.setMultiPv(value.round());
                },
              ),
              Text('${state.multiPv}'),
            ],
          ),

          const SizedBox(height: 16),

          // Side selection
          Row(
            children: [
              const Text('Side to Move: '),
              ToggleButtons(
                isSelected: [state.redToMove, !state.redToMove],
                onPressed: (index) {
                  controller.onPickSide(red: index == 0);
                },
                children: const [Text('Red'), Text('Black')],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Navigation controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: state.canBack ? () => controller.back() : null,
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () => controller.reset(),
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: state.canNext ? () => controller.next() : null,
                child: const Text('Next'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Setup mode controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: state.isSetupMode
                    ? null
                    : () => controller.enterSetupMode(),
                child: const Text('Setup Board'),
              ),
              if (state.isSetupMode) ...[
                ElevatedButton(
                  onPressed: () => controller.startGameFromSetup(),
                  child: const Text('Start Game'),
                ),
                ElevatedButton(
                  onPressed: () => controller.exitSetupMode(),
                  child: const Text('Exit Setup'),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Game info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moves: ${state.moves.length}'),
                Text('Pointer: ${state.pointer}'),
                Text('Side to move: ${state.redToMove ? 'Red' : 'Black'}'),
                Text('Best lines: ${state.bestLines.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Camera navigation removed
}
