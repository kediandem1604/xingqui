import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/board/board_controller.dart';
import 'features/board/board_view.dart';
import 'features/board/controls.dart';
import 'features/board/best_moves_panel.dart';
import 'widgets/side_selection_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: XiangqiApp()));
}

class XiangqiApp extends StatelessWidget {
  const XiangqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xiangqi Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const XiangqiHomePage(),
    );
  }
}

class XiangqiHomePage extends ConsumerStatefulWidget {
  const XiangqiHomePage({super.key});

  @override
  ConsumerState<XiangqiHomePage> createState() => _XiangqiHomePageState();
}

class _XiangqiHomePageState extends ConsumerState<XiangqiHomePage> {
  bool _gameInitialized = false;

  @override
  void initState() {
    super.initState();
    // Show side selection dialog first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSideSelection();
    });
  }

  Future<void> _showSideSelection() async {
    final selectedSide = await SideSelectionDialog.show(context);
    if (selectedSide != null) {
      // Initialize the board controller with selected side
      final controller = ref.read(boardControllerProvider.notifier);
      await controller.init();

      // Set the board orientation based on selection
      // Red always moves first, this is just about which side is at bottom
      if (!selectedSide) {
        // If user selected Black, put Black at bottom
        await controller.setRedAtBottom(false);
      } else {
        // If user selected Red, put Red at bottom
        await controller.setRedAtBottom(true);
      }

      setState(() {
        _gameInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Xiangqi Flutter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About'),
                  content: const Text(
                    'Xiangqi Flutter App\n\n'
                    'Features:\n'
                    '• Engine integration (Pikafish UCI, EleEye UCCI)\n'
                    '• MultiPV analysis (1-3 best moves)\n'
                    '• Move history navigation\n'
                    '• Interactive board\n'
                    '• Real-time engine analysis\n\n'
                    'Phase 1: Basic functionality\n'
                    'Phase 2: Full piece movement and validation',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _gameInitialized
          ? const Row(
              children: [
                // Left side - Board and Controls
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Give the board most of the height
                      Expanded(flex: 5, child: BoardView()),
                      // Controls take less height to keep board large
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(child: Controls()),
                      ),
                    ],
                  ),
                ),
                // Right side - Best Moves Panel
                Expanded(flex: 2, child: BestMovesPanel()),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
