# Hướng dẫn chuyển đổi từ flutter_application_window sang flutter_android

## Tổng quan

Dự án `flutter_application_window` đã được phát triển hoàn chỉnh với các tính năng sau:

### 🎯 Tính năng chính đã hoàn thành

1. **Engine Integration**
   - Hỗ trợ Pikafish (UCI) và EleEye (UCCI) engines
   - MultiPV analysis (1-3 best moves)
   - Real-time engine analysis với depth control
   - Engine switching và configuration

2. **Game Management**
   - Lưu/tải ván cờ với metadata
   - Replay mode với controls (play/pause/next/previous)
   - Game history navigation (back/next)
   - Setup board mode để tạo custom positions

3. **AI vs Human Mode**
   - 3 cấp độ khó: Dễ, Trung bình, Khó
   - Engine tự động đi nước cờ
   - Difficulty-based move selection

4. **UI/UX Features**
   - Interactive board với piece selection
   - Move animation và visual feedback
   - Best moves panel hiển thị analysis
   - Game notifications (check, checkmate, etc.)
   - Side selection dialog

5. **Core Game Logic**
   - Complete Xiangqi rules validation
   - FEN parsing và manipulation
   - Move notation conversion
   - Game status detection (check, checkmate, stalemate)

## 📁 Cấu trúc thư mục cần chuyển

```
lib/
├── core/                    # Core game logic
│   ├── fen.dart            # FEN parsing và manipulation
│   ├── xiangqi_rules.dart  # Complete game rules
│   ├── move_notation.dart  # Move notation conversion
│   └── logger.dart         # Logging system
├── engine/                 # Engine integration
│   ├── engine_base.dart    # Engine interface
│   ├── engine_parser.dart  # Engine message parsing
│   ├── pikafish_engine.dart # Pikafish UCI engine
│   └── ucci_engine.dart    # EleEye UCCI engine
├── features/               # Feature modules
│   ├── board/              # Board management
│   │   ├── board_controller.dart # Main game controller
│   │   ├── board_view.dart       # Board UI
│   │   └── best_moves_panel.dart # Analysis display
│   └── camera/             # Camera integration (if needed)
├── models/                 # Data models
│   └── saved_game.dart     # Saved game model
├── services/               # Business logic services
│   ├── game_status_service.dart # Game status detection
│   └── saved_games_service.dart # Game persistence
├── widgets/                # Reusable UI components
│   ├── game_notification.dart    # Game notifications
│   └── side_selection_dialog.dart # Side selection
└── main.dart              # App entry point
```

## 🔧 Dependencies cần thêm vào pubspec.yaml

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  freezed_annotation: ^2.4.4
  collection: ^1.18.0
  flutter_svg: ^2.0.10+1
  path_provider: ^2.1.4
  process_run: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.11
  freezed: ^2.5.7
```

## 📋 Checklist chuyển đổi

### Phase 1: Core Dependencies
- [ ] Thêm dependencies vào `pubspec.yaml`
- [ ] Chạy `flutter pub get`
- [ ] Copy thư mục `core/` hoàn toàn
- [ ] Copy thư mục `engine/` hoàn toàn
- [ ] Copy thư mục `models/` hoàn toàn
- [ ] Copy thư mục `services/` hoàn toàn

### Phase 2: UI Components
- [ ] Copy thư mục `widgets/` hoàn toàn
- [ ] Copy `features/board/` hoàn toàn
- [ ] Update imports trong các file đã copy

### Phase 3: Integration
- [ ] Update `main.dart` để sử dụng Riverpod
- [ ] Integrate `BoardController` vào existing UI
- [ ] Test engine integration
- [ ] Test game functionality

### Phase 4: Android-specific Adaptations
- [ ] Update engine paths cho Android
- [ ] Test trên Android device
- [ ] Optimize performance cho mobile
- [ ] Handle Android permissions

## 🚀 Các bước tích hợp chi tiết

### 1. Copy Core Files

```bash
# Copy core game logic
cp -r flutter_application_window/lib/core flutter_android/lib/
cp -r flutter_application_window/lib/engine flutter_android/lib/
cp -r flutter_application_window/lib/models flutter_android/lib/
cp -r flutter_application_window/lib/services flutter_android/lib/
cp -r flutter_application_window/lib/widgets flutter_android/lib/
cp -r flutter_application_window/lib/features flutter_android/lib/
```

### 2. Update pubspec.yaml

Thêm dependencies vào `flutter_android/pubspec.yaml`:

```yaml
dependencies:
  # Existing dependencies...
  flutter_riverpod: ^2.5.1
  freezed_annotation: ^2.4.4
  collection: ^1.18.0
  flutter_svg: ^2.0.10+1
  path_provider: ^2.1.4
  process_run: ^1.0.0

dev_dependencies:
  # Existing dev dependencies...
  build_runner: ^2.4.11
  freezed: ^2.5.7
```

### 3. Update main.dart

Thay thế nội dung `flutter_android/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _gameMode = 'normal';
  int _engineThinkingTime = 10;
  int _bestMovesCount = 1;
  String _selectedEngine = 'EleEye';
  int _engineDepth = 16;
  bool _showBestMoves = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(boardControllerProvider.notifier);
      controller.setResetSettingsCallback(_resetSettings);
      _showSideSelection();
    });
  }

  Future<void> _showSideSelection() async {
    final selectedSide = await SideSelectionDialog.show(context);
    if (selectedSide != null) {
      final controller = ref.read(boardControllerProvider.notifier);
      await controller.init();
      
      if (!selectedSide) {
        await controller.setRedAtBottom(false);
      } else {
        await controller.setRedAtBottom(true);
      }

      setState(() {
        _gameInitialized = true;
      });
    }
  }

  void _resetSettings() {
    setState(() {
      _selectedEngine = 'EleEye';
      _bestMovesCount = 1;
      _engineThinkingTime = 10;
      _engineDepth = 16;
      _showBestMoves = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Xiangqi Flutter'),
        actions: [
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
      body: _gameInitialized
          ? Row(
              children: [
                Expanded(
                  flex: _showBestMoves ? 4 : 6,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final state = ref.watch(boardControllerProvider);
                      if (state.isSetupMode) {
                        return BoardView(showBestMoves: _showBestMoves);
                      }
                      return Column(
                        children: [
                          Expanded(
                            flex: 6,
                            child: BoardView(showBestMoves: _showBestMoves),
                          ),
                          Expanded(flex: 1, child: _buildMinimalControls()),
                        ],
                      );
                    },
                  ),
                ),
                if (_showBestMoves) 
                  Expanded(flex: 1, child: BestMovesPanel()),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMinimalControls() {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(boardControllerProvider);
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
}
```

### 4. Android-specific Engine Paths

Update engine paths trong `board_controller.dart`:

```dart
// Thay đổi engine paths cho Android
String _resolveEnginePath(String relativePath) {
  // For Android, engines should be in assets or downloaded
  // Example: return 'assets/engines/$relativePath';
  return relativePath; // Adjust based on your Android setup
}
```

### 5. Test Integration

1. Chạy `flutter pub get`
2. Chạy `flutter pub run build_runner build` (nếu có freezed models)
3. Test trên Android device
4. Verify engine integration hoạt động

## ⚠️ Lưu ý quan trọng

1. **Engine Files**: Cần copy engine executables vào Android assets hoặc download dynamically
2. **Permissions**: Android có thể cần permissions để chạy external processes
3. **Performance**: Mobile có thể cần optimize engine analysis depth
4. **UI Adaptation**: Có thể cần adjust UI cho mobile screen sizes

## 🎯 Tính năng đã sẵn sàng

Tất cả tính năng trong `flutter_application_window` đã được test và hoạt động ổn định:

- ✅ Complete Xiangqi game logic
- ✅ Engine integration (Pikafish + EleEye)
- ✅ MultiPV analysis
- ✅ Game saving/loading
- ✅ Replay functionality
- ✅ AI vs Human mode
- ✅ Setup board mode
- ✅ Move validation và animation
- ✅ Game status detection
- ✅ Responsive UI

## 📞 Support

Nếu gặp vấn đề trong quá trình chuyển đổi, hãy kiểm tra:

1. Dependencies đã được thêm đúng
2. Import paths đã được update
3. Engine files có sẵn trên Android
4. Permissions đã được cấp

Chúc bạn tích hợp thành công! 🚀
