# Flutter Application Window - Xiangqi Game

## 🎮 Tổng quan

Dự án Flutter Xiangqi game đã được phát triển hoàn chỉnh với đầy đủ tính năng:

- **Complete Xiangqi Game Logic** với full rules validation
- **Engine Integration** (Pikafish UCI + EleEye UCCI)
- **AI vs Human Mode** với 3 cấp độ khó
- **Game Management** (save/load/replay)
- **Professional UI** với animations và real-time analysis

## 🚀 Tính năng chính

### ✅ Engine Integration
- Pikafish Engine (UCI protocol)
- EleEye Engine (UCCI protocol)  
- MultiPV analysis (1-3 best moves)
- Real-time engine analysis
- Dynamic engine switching

### ✅ Game Management
- Save/Load games với metadata
- Game history navigation
- Replay mode với controls
- Setup board mode
- Game statistics

### ✅ AI vs Human Mode
- **Dễ**: Random moves + occasional bad moves
- **Trung bình**: Lower scoring best moves  
- **Khó**: Best moves only
- Automatic move making

### ✅ UI/UX Features
- Interactive board với touch controls
- Move animation và visual feedback
- Best moves panel
- Game notifications
- Responsive layout

### ✅ Core Game Logic
- Complete Xiangqi rules validation
- FEN parsing và manipulation
- Move validation với UCI notation
- Game status detection
- Legal move generation

## 📁 Cấu trúc dự án

```
lib/
├── core/                    # Core game logic
│   ├── fen.dart            # FEN parsing
│   ├── xiangqi_rules.dart  # Game rules
│   ├── move_notation.dart  # Move notation
│   └── logger.dart         # Logging
├── engine/                 # Engine integration
│   ├── engine_base.dart    # Engine interface
│   ├── engine_parser.dart  # Message parsing
│   ├── pikafish_engine.dart # Pikafish UCI
│   └── ucci_engine.dart    # EleEye UCCI
├── features/board/         # Board management
│   ├── board_controller.dart # Main controller
│   ├── board_view.dart     # Board UI
│   └── best_moves_panel.dart # Analysis display
├── models/                 # Data models
│   └── saved_game.dart     # Saved game model
├── services/               # Business logic
│   ├── game_status_service.dart # Game status
│   └── saved_games_service.dart # Persistence
├── widgets/                # UI components
│   ├── game_notification.dart    # Notifications
│   └── side_selection_dialog.dart # Side selection
└── main.dart              # App entry point
```

## 🔧 Dependencies

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

## 📋 Chuyển đổi sang Android

### Quick Start:
1. Copy tất cả files từ `lib/` folder
2. Add dependencies vào `pubspec.yaml`
3. Run `flutter pub get`
4. Update `main.dart` với Riverpod setup
5. Test trên Android device

### Chi tiết:
- Xem `MIGRATION_GUIDE.md` cho hướng dẫn đầy đủ
- Xem `FEATURES_CHECKLIST.md` cho checklist chi tiết

## 🎯 Key Features Ready for Android

### Engine Integration
```dart
// Switch engine
await controller.switchEngine('Pikafish');
await controller.setMultiPv(3);
await controller.setAnalysisDepth(16);
```

### AI Mode
```dart
// Start AI vs Human
await controller.startVsEngineMode('hard');
```

### Game Management
```dart
// Save game
await controller.saveCurrentGame('My Game');

// Load game  
await controller.loadSavedGame(gameId);

// Replay
await controller.startReplay(moves);
```

### State Management
```dart
// Watch state
Consumer(
  builder: (context, ref, child) {
    final state = ref.watch(boardControllerProvider);
    return BoardView(showBestMoves: true);
  },
)
```

## ⚠️ Android Considerations

1. **Engine Files**: Place trong assets hoặc download dynamically
2. **Permissions**: May need Android permissions cho external processes
3. **Performance**: Optimize analysis depth cho mobile
4. **UI**: Adjust layout cho mobile screen sizes

## 🎮 Game Features

### Piece Movement
- **Chariot (R/r)**: Horizontal/vertical, any distance
- **Horse (H/h)**: L-shaped moves, can't be blocked
- **Elephant (E/e)**: Diagonal 2 squares, can't cross river
- **Advisor (A/a)**: Diagonal 1 square, palace only
- **King (K/k)**: 1 square horizontal/vertical, palace only
- **Cannon (C/c)**: Like chariot, must jump to capture
- **Pawn (P/p)**: Forward only, sideways after crossing river

### Game Status
- **Check**: King under attack
- **Checkmate**: King under attack, no legal moves
- **Stalemate**: No legal moves, king not under attack
- **King Capture**: King captured (immediate win)

### AI Difficulty
- **Easy**: Random moves + occasional bad moves
- **Medium**: Lower scoring best moves
- **Hard**: Best moves only

## 🚀 Ready for Production

Tất cả tính năng đã được test và hoạt động ổn định:

- ✅ Complete game logic
- ✅ Engine integration
- ✅ AI opponent
- ✅ Game management
- ✅ Professional UI
- ✅ Mobile optimization ready

## 📞 Support

Nếu gặp vấn đề:
1. Check dependencies và imports
2. Verify engine files và paths
3. Check Riverpod setup
4. Review AppLogger output

**Chúc bạn tích hợp thành công!** 🎯