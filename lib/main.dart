import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:process_run/shell.dart';
import 'features/board/board_controller.dart';
import 'features/board/board_view.dart';
import 'features/board/best_moves_panel.dart';
import 'widgets/side_selection_dialog.dart';
import 'core/logger.dart';

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
  String _gameMode = 'normal'; // 'normal' or 'vs_engine'
  int _engineThinkingTime = 10; // seconds
  int _bestMovesCount = 1;
  String _selectedEngine = 'EleEye';
  int _engineDepth = 16;
  bool _showBestMoves = true; // Show/hide best moves panel

  // Reset all settings to initial values
  void _resetSettings() {
    setState(() {
      _selectedEngine = 'EleEye';
      _bestMovesCount = 1;
      _engineThinkingTime = 10;
      _engineDepth = 16;
      _showBestMoves = true;
    });
  }

  // Show difficulty selection dialog
  void _showDifficultySelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn cấp độ khó'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chọn cấp độ khó cho máy:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.star_border, color: Colors.green),
              title: const Text('Dễ'),
              subtitle: const Text(
                'Máy đi ngẫu nhiên, thỉnh thoảng theo bestmove thấp',
              ),
              onTap: () {
                Navigator.pop(context);
                _startVsEngineMode('easy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_half, color: Colors.orange),
              title: const Text('Trung bình'),
              subtitle: const Text('Máy đi theo bestmove có điểm thấp hơn'),
              onTap: () {
                Navigator.pop(context);
                _startVsEngineMode('medium');
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.red),
              title: const Text('Khó'),
              subtitle: const Text('Máy đi theo bestmove tốt nhất'),
              onTap: () {
                Navigator.pop(context);
                _startVsEngineMode('hard');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  // Start vs engine mode with selected difficulty
  Future<void> _startVsEngineMode(String difficulty) async {
    setState(() {
      _gameMode = 'vs_engine';
      // Always show best moves for all difficulty modes
      _showBestMoves = true;
    });

    final controller = ref.read(boardControllerProvider.notifier);
    await controller.startVsEngineMode(difficulty);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bắt đầu chế độ đánh với máy - Cấp độ: ${_getDifficultyName(difficulty)}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Get difficulty display name
  String _getDifficultyName(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Dễ';
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      default:
        return 'Không xác định';
    }
  }

  @override
  void initState() {
    super.initState();
    // Set callback for resetting settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(boardControllerProvider.notifier);
      controller.setResetSettingsCallback(_resetSettings);
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          // Exit vs engine mode button
          if (_gameMode == 'vs_engine')
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                setState(() {
                  _gameMode = 'normal';
                  _showBestMoves = true;
                });
                final controller = ref.read(boardControllerProvider.notifier);
                controller.stopVsEngineMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã thoát chế độ đánh với máy'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              tooltip: 'Thoát chế độ đánh với máy',
            ),
          IconButton(
            icon: Icon(
              _showBestMoves ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _showBestMoves = !_showBestMoves;
              });
            },
            tooltip: _showBestMoves ? 'Ẩn Best Moves' : 'Hiện Best Moves',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _gameInitialized
          ? Row(
              children: [
                // Left side - Board (phóng to hơn)
                Expanded(
                  flex: _showBestMoves
                      ? 4
                      : 6, // Phóng to hơn khi ẩn best moves
                  child: Consumer(
                    builder: (context, ref, child) {
                      final state = ref.watch(boardControllerProvider);

                      // In setup mode, only show board without controls
                      if (state.isSetupMode) {
                        return BoardView(showBestMoves: _showBestMoves);
                      }

                      // In normal mode, show board with controls
                      return Column(
                        children: [
                          // Board takes most of the space
                          Expanded(
                            flex: 6,
                            child: BoardView(showBestMoves: _showBestMoves),
                          ),
                          // Minimal controls
                          Expanded(flex: 1, child: _buildMinimalControls()),
                        ],
                      );
                    },
                  ),
                ),
                // Right side - Best Moves Panel (chỉ hiện khi _showBestMoves = true)
                if (_showBestMoves) Expanded(flex: 1, child: BestMovesPanel()),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.brown),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sports_esports),
            title: const Text('Chế độ chơi bình thường'),
            selected: _gameMode == 'normal',
            onTap: () {
              setState(() {
                _gameMode = 'normal';
              });
              // Disable vs engine mode
              final controller = ref.read(boardControllerProvider.notifier);
              controller.setVsEngineMode(false);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Đánh với máy'),
            subtitle: const Text('Chọn cấp độ khó'),
            selected: _gameMode == 'vs_engine',
            onTap: () {
              Navigator.pop(context);
              _showDifficultySelection();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Cài đặt engine'),
            onTap: () {
              Navigator.pop(context);
              _showEngineSettingsDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.grid_on),
            title: const Text('Setup Board'),
            onTap: () {
              Navigator.pop(context);
              _showSetupBoardDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Log lỗi'),
            onTap: () {
              Navigator.pop(context);
              _openLogsFolder();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalControls() {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(boardControllerProvider);

        // Hide controls when in setup mode
        if (state.isSetupMode) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  final controller = ref.read(boardControllerProvider.notifier);
                  controller.back();
                },
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () {
                  final controller = ref.read(boardControllerProvider.notifier);
                  controller.reset();
                },
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: () {
                  final controller = ref.read(boardControllerProvider.notifier);
                  controller.next();
                },
                child: const Text('Next'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEngineSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cài đặt Engine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Engine selection
                Row(
                  children: [
                    const Text('Engine: '),
                    DropdownButton<String>(
                      value: _selectedEngine,
                      items: const [
                        DropdownMenuItem(
                          value: 'Pikafish',
                          child: Text('Pikafish'),
                        ),
                        DropdownMenuItem(
                          value: 'EleEye',
                          child: Text('EleEye'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedEngine = value ?? 'EleEye';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Best moves count
                Text('Số lượng bestmove: $_bestMovesCount'),
                Slider(
                  value: _bestMovesCount.toDouble(),
                  min: 1,
                  max: 3,
                  divisions: 2,
                  onChanged: _selectedEngine == 'EleEye'
                      ? null
                      : (value) {
                          setState(() {
                            _bestMovesCount = value.round();
                          });
                        },
                ),
                if (_selectedEngine == 'EleEye')
                  const Text(
                    'EleEye chỉ hỗ trợ 1 bestmove',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                const SizedBox(height: 16),

                // Thinking time
                Text('Thời gian suy nghĩ: ${_engineThinkingTime}s'),
                Slider(
                  value: _engineThinkingTime.toDouble(),
                  min: 3,
                  max: 60,
                  divisions: 57,
                  onChanged: (value) {
                    setState(() {
                      _engineThinkingTime = value.round();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Engine depth
                Text('Độ sâu phân tích: $_engineDepth'),
                Slider(
                  value: _engineDepth.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (value) {
                    setState(() {
                      _engineDepth = value.round();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Apply settings sequentially to avoid conflicts
                final controller = ref.read(boardControllerProvider.notifier);

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  // Step 1: Switch engine first
                  await controller.switchEngine(_selectedEngine);

                  // Step 2: Set MultiPV after engine is ready
                  await controller.setMultiPv(_bestMovesCount);

                  // Step 3: Set analysis depth
                  await controller.setAnalysisDepth(_engineDepth);

                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Close settings dialog
                  Navigator.of(context).pop();

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cài đặt engine đã được áp dụng thành công!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi khi áp dụng cài đặt: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetupBoardDialog() {
    final controller = ref.read(boardControllerProvider.notifier);
    controller.enterSetupMode();
  }

  void _openLogsFolder() async {
    try {
      final path = await AppLogger().getLogsDirectoryPath();
      // Try to open with system file explorer
      try {
        final shell = Shell();
        if (Theme.of(context).platform == TargetPlatform.windows) {
          await shell.run('start "" "$path"');
        } else if (Theme.of(context).platform == TargetPlatform.macOS) {
          await shell.run('open "$path"');
        } else {
          await shell.run('xdg-open "$path"');
        }
      } catch (_) {}
    } catch (_) {}
  }

  void _showAboutDialog() {
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
  }
}
