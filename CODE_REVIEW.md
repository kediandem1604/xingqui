# Code Review - Xiangqi Flutter Application

## Tổng quan dự án

Ứng dụng Flutter để chơi cờ tướng với tích hợp engine AI (Pikafish UCI và EleEye UCCI). Dự án được thiết kế theo kiến trúc clean architecture với state management sử dụng Riverpod.

## Cấu trúc thư mục

```
lib/
├── main.dart                 # Entry point
├── core/                     # Core business logic
│   ├── fen.dart             # FEN parsing và validation
│   ├── move_notation.dart   # Chuyển đổi ký hiệu nước đi
│   ├── xiangqi_rules.dart   # Luật cờ tướng
│   └── logger.dart          # Logging system
├── engine/                   # Engine integration
│   ├── engine_base.dart     # Abstract engine interface
│   ├── pikafish_engine.dart # Pikafish (UCI protocol)
│   ├── ucci_engine.dart     # EleEye (UCCI protocol)
│   └── engine_parser.dart   # Parse engine output
├── features/board/           # UI components
│   ├── board_controller.dart # State management (Riverpod)
│   ├── board_view.dart      # Bàn cờ tương tác
│   ├── controls.dart        # Nút điều khiển
│   └── best_moves_panel.dart # Panel hiển thị nước đi tốt nhất
├── services/                 # Business services
│   └── game_status_service.dart # Game status detection
└── widgets/                  # Reusable widgets
    ├── side_selection_dialog.dart # Side selection dialog
    └── game_notification.dart     # Game notifications
```

## Chi tiết từng file

### 1. main.dart - Entry Point

**Chức năng chính:**
- Khởi tạo ứng dụng Flutter
- Thiết lập theme và routing
- Quản lý side selection dialog

**Các class và hàm:**

#### `XiangqiApp` (StatelessWidget)
- **build()**: Tạo MaterialApp với theme brown và home page
- **Mục đích**: Root widget của ứng dụng

#### `XiangqiHomePage` (ConsumerStatefulWidget)
- **initState()**: Hiển thị dialog chọn bên khi khởi động
- **_showSideSelection()**: Xử lý việc chọn bên (Red/Black) và khởi tạo board controller
- **build()**: Tạo layout chính với AppBar, BoardView, Controls và BestMovesPanel

**Điểm mạnh:**
- Sử dụng Riverpod cho state management
- UI responsive với Expanded và flex
- Xử lý initialization flow tốt

**Điểm cần cải thiện:**
- Có thể tách logic khởi tạo ra service riêng
- Hard-coded strings nên được extract ra constants

### 2. core/fen.dart - FEN Parser

**Chức năng chính:**
- Parse và validate FEN notation cho cờ tướng
- Chuyển đổi giữa FEN string và board representation
- Áp dụng nước đi lên FEN

**Các hàm chính:**

#### `FenParser` class
- **isValidFen(String fen)**: Kiểm tra tính hợp lệ của FEN
  - Kiểm tra format: 10 ranks, 9 files mỗi rank
  - Validate side to move ('w' hoặc 'b')
  - Kiểm tra ký tự quân cờ hợp lệ

- **parseBoard(String fen)**: Chuyển FEN thành 2D array
  - Xử lý số (1-9) thành empty squares
  - Trả về List<List<String>> 10x9

- **boardToFen(List<List<String>> board, String sideToMove)**: Chuyển board thành FEN
  - Nén empty squares thành số
  - Kết hợp với side to move

- **applyMove(String fen, String moveUci)**: Áp dụng nước đi lên FEN
  - Parse UCI move format (e3e4)
  - Cập nhật board và flip side to move

**Điểm mạnh:**
- Logic parsing chính xác
- Xử lý edge cases tốt
- Code dễ đọc và maintain

**Điểm cần cải thiện:**
- Có thể thêm validation cho piece counts
- Nên có error handling cho invalid moves

### 3. core/logger.dart - Logging System

**Chức năng chính:**
- Singleton logger với file output
- Tự động tạo log directory
- Timestamp formatting

**Các hàm chính:**

#### `AppLogger` class (Singleton)
- **_initLogFile()**: Khởi tạo log file với timestamp
  - Tạo directory trong ApplicationSupportDirectory
  - Fallback về system temp nếu lỗi
  - Ghi header vào file

- **log(String message)**: Ghi log message với timestamp
- **error(String message, [Object? err, StackTrace? st])**: Ghi error với stack trace
- **_ts(DateTime dt)**: Format timestamp cho log
- **_tsFileSafe(DateTime dt)**: Format timestamp cho filename

**Điểm mạnh:**
- Singleton pattern đúng cách
- Error handling tốt với fallback
- Timestamp formatting chi tiết

**Điểm cần cải thiện:**
- Có thể thêm log levels (DEBUG, INFO, WARN, ERROR)
- Nên có log rotation để tránh file quá lớn

### 4. core/move_notation.dart - Move Notation

**Chức năng chính:**
- Chuyển đổi giữa UCI và Chinese notation
- Parse và validate UCI moves
- Coordinate validation

**Các class và hàm:**

#### `MoveNotation` class
- **uciToChinese(String uciMove)**: Chuyển UCI sang ký hiệu Trung Quốc
- **parseUciMove(String uciMove)**: Parse UCI move thành Move object
- **moveToUci(Move move)**: Chuyển Move object thành UCI string
- **isValidCoordinate(int file, int rank)**: Kiểm tra tọa độ hợp lệ

#### `Move` class
- **Constructor**: Lưu trữ fromFile, fromRank, toFile, toRank
- **toString()**: Trả về UCI string
- **operator ==**: So sánh equality
- **hashCode**: Hash code cho Map/Set

**Điểm mạnh:**
- Immutable Move class
- Validation đầy đủ
- Support cả UCI và Chinese notation

**Điểm cần cải thiện:**
- Chinese notation conversion chưa hoàn chỉnh
- Có thể thêm algebraic notation

### 5. core/xiangqi_rules.dart - Xiangqi Rules

**Chức năng chính:**
- Validation luật cờ tướng cho từng loại quân
- Kiểm tra nước đi hợp lệ
- Xử lý special rules (river crossing, palace restrictions)

**Các hàm chính:**

#### `XiangqiRules` class
- **isValidMove(String fen, String uciMove)**: Kiểm tra nước đi hợp lệ
  - Parse move và board
  - Kiểm tra piece ownership
  - Validate piece-specific rules

- **_isValidPieceMove()**: Router cho từng loại quân
- **_isValidChariotMove()**: Luật xe (車) - di chuyển thẳng
- **_isValidHorseMove()**: Luật mã (馬) - L-shape, không bị cản
- **_isValidElephantMove()**: Luật tượng (象) - 2 ô chéo, không qua sông
- **_isValidAdvisorMove()**: Luật sĩ (士) - 1 ô chéo trong cung
- **_isValidKingMove()**: Luật tướng (帥/將) - 1 ô thẳng trong cung
- **_isValidCannonMove()**: Luật pháo (炮) - thẳng, cần nhảy qua 1 quân để ăn
- **_isValidPawnMove()**: Luật tốt (兵/卒) - tiến, sau khi qua sông có thể ngang

**Điểm mạnh:**
- Logic luật chính xác và đầy đủ
- Xử lý special cases tốt (river, palace)
- Code structure rõ ràng

**Điểm cần cải thiện:**
- Có thể optimize bằng cách cache legal moves
- Nên thêm check/checkmate detection

### 6. engine/engine_base.dart - Engine Interface

**Chức năng chính:**
- Abstract interface cho chess engines
- Message types cho engine communication
- Engine configuration

**Các class chính:**

#### Message Types
- **EngineMessage**: Base class cho tất cả engine messages
- **InfoMessage**: Thông tin phân tích
- **BestMoveMessage**: Nước đi tốt nhất
- **ErrorMessage**: Lỗi từ engine
- **ReadyMessage**: Engine sẵn sàng
- **GameOverMessage**: Kết thúc game

#### `IEngine` interface
- **start()**: Khởi động engine
- **stop()**: Dừng engine
- **send(String cmd)**: Gửi command
- **messages**: Stream nhận messages
- **setMultiPV(int n)**: Thiết lập số nước đi tốt nhất
- **newGame()**: Bắt đầu game mới
- **setPosition(String fen, List<String> moves)**: Thiết lập vị trí
- **go()**: Bắt đầu phân tích

#### `EngineConfig` class
- **name**: Tên engine
- **executablePath**: Đường dẫn executable
- **protocol**: Giao thức (UCI/UCCI)
- **options**: Các tùy chọn

**Điểm mạnh:**
- Interface design tốt
- Separation of concerns rõ ràng
- Extensible cho nhiều engine types

**Điểm cần cải thiện:**
- Có thể thêm async/await patterns
- Nên có timeout handling

### 7. engine/engine_parser.dart - Engine Output Parser

**Chức năng chính:**
- Parse output từ chess engines
- Extract thông tin phân tích (depth, score, PV)
- Handle cả UCI và UCCI protocols

**Các hàm chính:**

#### `EngineParser` class
- **parseBestMove(String line)**: Parse bestmove từ engine output
- **parseInfoPv(String line)**: Parse info line cho MultiPV analysis
  - Extract multipv, depth, score, pv moves
  - Handle cả "score cp N" và "score N" formats
  - Convert mate scores thành centipawns

- **parseEngineName(String line)**: Parse engine name từ "id name"
- **parseEngineAuthor(String line)**: Parse engine author
- **isReadyMessage(String line)**: Kiểm tra ready message
- **isProtocolOk(String line)**: Kiểm tra protocol acknowledgment

#### `PvInfo` class
- **multipv**: PV number (1, 2, 3...)
- **depth**: Search depth
- **scoreCp**: Score in centipawns
- **pvMoves**: Sequence of moves
- **scoreString**: Formatted score string
- **firstMove**: First move của PV

**Điểm mạnh:**
- Robust parsing với error handling
- Support multiple protocols
- Clean data structures

**Điểm cần cải thiện:**
- Có thể thêm validation cho parsed data
- Nên có unit tests cho parsing logic

### 8. engine/pikafish_engine.dart - Pikafish Engine

**Chức năng chính:**
- Wrapper cho Pikafish engine (UCI protocol)
- Custom UCI->UCCI conversion
- Process management và communication

**Các hàm chính:**

#### `PikafishEngine` class
- **start()**: Khởi động Pikafish process
  - Kiểm tra executable exists
  - Set working directory cho DLLs/NNUE files
  - Initialize UCI protocol
  - Test Xiangqi support
  - Set NNUE eval file

- **_handleEngineOutput(String line)**: Xử lý output từ engine
  - Parse engine name
  - Convert UCI info to UCCI format
  - Handle bestmove conversion
  - Check game over conditions

- **_convertInfoLine(String line)**: Convert UCI info to UCCI
- **_convertBestMove(String line)**: Convert UCI bestmove to UCCI
- **_isValidXiangqiMove(String move)**: Validate xiangqi move format
- **_checkGameOverFromInfo()**: Detect checkmate từ info output
- **_checkGameOverFromBestMove()**: Detect game over từ bestmove

- **setMultiPV(int n)**: Set MultiPV option
- **newGame()**: Send ucinewgame command
- **setPosition(String fen, List<String> moves)**: Set position
- **go()**: Start analysis với timeout handling

**Điểm mạnh:**
- Comprehensive error handling
- Timeout mechanisms
- Game over detection
- NNUE file support

**Điểm cần cải thiện:**
- Warning: Pikafish là Chess engine, không phải Xiangqi
- Có thể optimize timeout calculations
- Nên có retry mechanism cho failed commands

### 9. engine/ucci_engine.dart - UCCI Engine

**Chức năng chính:**
- Wrapper cho UCCI engines (như EleEye)
- Native UCCI protocol support
- Process management

**Các hàm chính:**

#### `UcciEngine` class
- **start()**: Khởi động UCCI engine
  - Set working directory
  - Initialize UCCI protocol
  - Wait for ucciok và readyok

- **_handleEngineOutput(String line)**: Xử lý UCCI output
- **setMultiPV(int n)**: Set MultiPV (có thể không support)
- **newGame()**: Send ucinewgame
- **setPosition()**: Set position với FEN
- **go()**: Start analysis (sử dụng "go time" thay vì "go movetime")

**Điểm mạnh:**
- Native UCCI support
- Clean implementation
- Proper protocol handling

**Điểm cần cải thiện:**
- MultiPV support có thể không đầy đủ
- Nên có better error handling
- Có thể thêm engine-specific options

### 10. services/game_status_service.dart - Game Status Service

**Chức năng chính:**
- Detect check, checkmate, stalemate
- Determine game winner
- Generate legal moves

**Các hàm chính:**

#### `GameStatusService` class
- **isInCheck(String fen)**: Kiểm tra vua bị chiếu
  - Find king position (với fallback cho non-standard symbols)
  - Check all opponent pieces có thể attack king
  - Use flipped FEN để validate opponent moves

- **isCheckmate(String fen)**: Kiểm tra chiếu hết
  - Must be in check first
  - Try all possible moves để escape check
  - Return true nếu không có legal escape moves

- **isStalemate(String fen)**: Kiểm tra hết nước đi
  - Not in check và no legal moves
- **getWinner(String fen)**: Determine game winner
  - Check checkmate first
  - Check missing kings
  - Check stalemate

- **_getAllLegalMoves(String fen)**: Generate all legal moves
- **_findKingPosition()**: Find king với palace restrictions
- **_fileRankToUci()**: Convert coordinates to UCI

**Điểm mạnh:**
- Comprehensive game status detection
- Robust king finding với fallbacks
- Detailed logging cho debugging

**Điểm cần cải thiện:**
- Performance có thể chậm với deep analysis
- Có thể optimize bằng move generation caching
- Nên có unit tests cho edge cases

### 11. features/board/board_controller.dart - Board Controller

**Chức năng chính:**
- State management cho toàn bộ game
- Engine communication
- Move history management
- Animation handling

**Các class chính:**

#### `BestLine` class
- **index**: PV number (1-N)
- **depth**: Search depth
- **scoreCp**: Score in centipawns
- **pv**: Principal variation moves
- **scoreString**: Formatted score
- **firstMove**: First move của PV

#### `BoardState` class
- **fen**: Current position FEN
- **moves**: Move history
- **pointer**: Current position in history
- **redToMove**: Side to move
- **bestLines**: Engine analysis results
- **multiPv**: Number of best lines
- **selectedEngine**: Current engine
- **isEngineThinking**: Engine status
- **selectedFile/Rank**: Piece selection
- **possibleMoves**: Legal moves for selected piece
- **pendingAnimation**: Move animation state
- **notifications**: Game notifications
- **isSetupMode**: Setup mode flag
- **isRedAtBottom**: Board orientation

#### `BoardController` class (StateNotifier)
- **init()**: Initialize engine và logging
- **_switchEngine()**: Switch between engines
- **onBoardTap()**: Handle board interactions
- **makeMove()**: Apply move với animation
- **setMultiPv()**: Set MultiPV analysis
- **reset()**: Reset to initial position
- **back()/next()**: Navigate move history
- **enterSetupMode()**: Enter board setup mode
- **startGameFromSetup()**: Start game from setup position

**Điểm mạnh:**
- Comprehensive state management
- Smooth animations
- Multi-engine support
- Setup mode functionality

**Điểm cần cải thiện:**
- File rất lớn (1700+ lines), nên tách nhỏ
- Có thể optimize animation performance
- Nên có better error recovery

### 12. features/board/board_view.dart - Board View

**Chức năng chính:**
- Render bàn cờ tương tác
- Display pieces với SVG assets
- Handle user interactions
- Show best move arrows
- Move animations

**Các hàm chính:**

#### `BoardView` class (ConsumerWidget)
- **build()**: Main UI layout
  - Engine status display
  - Board với SVG background
  - Move history panel
  - Game notifications overlay

- **_buildPiecesOverlay()**: Render pieces trên board
- **_buildBestMoveArrows()**: Draw arrows cho best moves
- **_buildPossibleMoveIndicators()**: Show legal move indicators
- **_buildMoveAnimation()**: Animated piece movement
- **_onBoardTap()**: Handle tap interactions
- **_getPieceAsset()**: Map piece symbols to SVG assets

#### `_AnimatedPiece` class (StatefulWidget)
- **AnimationController**: Control move animation
- **Tween animations**: Position và opacity
- **onCompleted callback**: Commit move after animation

#### `_ArrowsPainter` class (CustomPainter)
- **paint()**: Draw arrows cho best moves
- **Colors**: Different colors cho multiple PVs
- **Arrowheads**: Proper arrow rendering

**Điểm mạnh:**
- Smooth animations
- Interactive board
- Visual feedback tốt
- SVG-based pieces

**Điểm cần cải thiện:**
- Có thể optimize rendering performance
- Nên có gesture recognition cho drag & drop
- Có thể thêm board themes

### 13. features/board/controls.dart - Controls

**Chức năng chính:**
- Engine selection dropdown
- MultiPV slider
- Side selection toggle
- Navigation controls
- Setup mode controls
- Game info display

**Các hàm chính:**

#### `Controls` class (ConsumerWidget)
- **build()**: Control panel layout
  - Engine dropdown (Pikafish/EleEye)
  - MultiPV slider (1-3)
  - Side selection toggle buttons
  - Navigation buttons (Back/Reset/Next)
  - Setup mode controls
  - Game info display
  - Open logs folder button

**Điểm mạnh:**
- Intuitive controls
- Real-time updates
- Cross-platform file operations

**Điểm cần cải thiện:**
- Có thể thêm keyboard shortcuts
- Nên có tooltips cho controls
- Có thể group related controls

### 14. features/board/best_moves_panel.dart - Best Moves Panel

**Chức năng chính:**
- Display engine analysis results
- Show multiple PVs với scores
- Color-coded score indicators

**Các hàm chính:**

#### `BestMovesPanel` class (ConsumerWidget)
- **build()**: Panel layout với ListView
- **_buildBestLineCard()**: Individual PV card
  - PV number và score
  - Depth information
  - Move sequence
  - First move highlight
- **_getScoreColor()**: Color coding cho scores

**Điểm mạnh:**
- Clear information display
- Color-coded scores
- Responsive layout

**Điểm cần cải thiện:**
- Có thể thêm move evaluation details
- Nên có copy move functionality
- Có thể thêm time information

### 15. widgets/side_selection_dialog.dart - Side Selection

**Chức năng chính:**
- Dialog để chọn bên chơi (Red/Black)
- Vietnamese UI text
- Visual side indicators

**Các hàm chính:**

#### `SideSelectionDialog` class (StatelessWidget)
- **build()**: Dialog layout với side buttons
- **_buildSideButton()**: Individual side selection button
- **show()**: Static method để show dialog

**Điểm mạnh:**
- Clean UI design
- Localized text
- Non-dismissible dialog

**Điểm cần cải thiện:**
- Có thể thêm preview của board orientation
- Nên có keyboard navigation

### 16. widgets/game_notification.dart - Game Notifications

**Chức năng chính:**
- Display game status notifications
- Animated notifications với auto-dismiss
- Overlay system

**Các class chính:**

#### `GameNotification` class (StatefulWidget)
- **AnimationController**: Slide và fade animations
- **Auto-dismiss**: Timer-based dismissal
- **Icon selection**: Context-aware icons
- **Customizable**: Colors, duration, message

#### `GameNotificationOverlay` class (StatefulWidget)
- **Stack-based overlay**: Multiple notifications
- **Dynamic management**: Add/remove notifications

**Điểm mạnh:**
- Smooth animations
- Flexible notification system
- Auto-dismiss functionality

**Điểm cần cải thiện:**
- Có thể thêm notification queuing
- Nên có notification history

### 17. test/widget_test.dart - Widget Tests

**Chức năng chính:**
- Basic smoke test cho app
- Verify UI elements exist

**Test case:**
- **Xiangqi app smoke test**: Verify app title và Best Moves panel

**Điểm cần cải thiện:**
- Cần thêm comprehensive tests
- Nên test engine integration
- Cần test game logic

## Đánh giá tổng thể

### Điểm mạnh

1. **Architecture**: Clean architecture với separation of concerns
2. **State Management**: Riverpod được sử dụng hiệu quả
3. **Engine Integration**: Support multiple protocols (UCI/UCCI)
4. **UI/UX**: Smooth animations và responsive design
5. **Error Handling**: Comprehensive error handling và logging
6. **Code Quality**: Well-structured code với clear naming
7. **Documentation**: Good inline documentation

### Điểm cần cải thiện

1. **Performance**: Một số operations có thể chậm (legal move generation)
2. **Testing**: Thiếu comprehensive test coverage
3. **Code Size**: Một số files quá lớn (board_controller.dart)
4. **Error Recovery**: Cần better recovery mechanisms
5. **Internationalization**: Hard-coded strings
6. **Memory Management**: Có thể optimize memory usage

### Khuyến nghị

1. **Refactoring**: Tách board_controller.dart thành smaller modules
2. **Testing**: Thêm unit tests và integration tests
3. **Performance**: Implement move generation caching
4. **Documentation**: Thêm API documentation
5. **Error Handling**: Implement retry mechanisms
6. **UI Improvements**: Thêm keyboard shortcuts và tooltips

## Kết luận

Đây là một dự án Flutter được thiết kế tốt với architecture rõ ràng và functionality đầy đủ. Code quality cao với good separation of concerns. Tuy nhiên cần cải thiện về performance, testing và error handling để trở thành production-ready application.

**Overall Rating: 8/10**

- Architecture: 9/10
- Code Quality: 8/10
- Functionality: 8/10
- Performance: 7/10
- Testing: 6/10
- Documentation: 8/10
