# Xiangqi Flutter App

Ứng dụng Flutter để chơi cờ tướng với tích hợp engine AI (Pikafish UCI và EleEye UCCI).

## Tính năng

- **Tích hợp Engine**: Hỗ trợ Pikafish (UCI) và EleEye (UCCI)
- **MultiPV Analysis**: Hiển thị 1-3 nước đi tốt nhất với điểm số và độ sâu
- **Giao diện tương tác**: Bàn cờ tướng với quân cờ Unicode
- **Điều hướng lịch sử**: Nút Back/Next để xem lại các nước đi
- **Phân tích thời gian thực**: Engine phân tích vị trí hiện tại
- **Chuyển đổi engine**: Có thể chọn giữa Pikafish và EleEye

## Cấu trúc dự án

```
lib/
├── main.dart                 # Entry point
├── core/                     # Core logic
│   ├── fen.dart             # FEN parsing và validation
│   ├── move_notation.dart   # Chuyển đổi ký hiệu nước đi
│   └── xiangqi_rules.dart   # Luật cờ tướng (Phase 1)
├── engine/                   # Engine integration
│   ├── engine_base.dart     # Abstract engine interface
│   ├── pikafish_engine.dart # Pikafish (UCI protocol)
│   ├── ucci_engine.dart     # EleEye (UCCI protocol)
│   └── engine_parser.dart   # Parse engine output
└── features/board/           # UI components
    ├── board_controller.dart # State management (Riverpod)
    ├── board_view.dart      # Bàn cờ tương tác
    ├── controls.dart        # Nút điều khiển
    └── best_moves_panel.dart # Panel hiển thị nước đi tốt nhất
```

## Cài đặt

1. **Cài đặt Flutter**: Đảm bảo Flutter SDK đã được cài đặt
2. **Cài đặt dependencies**:
   ```bash
   flutter pub get
   ```
3. **Chuẩn bị engines**: Copy engine binaries vào thư mục `engines/`
   - `engines/pikafish/win/pikafish.exe`
   - `engines/pikafish/win/pikafish.nnue`
   - `engines/eleeye/win/eleeye.exe`

## Chạy ứng dụng

### Desktop (Windows)
```bash
flutter run -d windows
```

### Test engines
```bash
test_engines.bat
```

## Sử dụng

1. **Chọn engine**: Sử dụng dropdown để chọn Pikafish hoặc EleEye
2. **Chọn số nước đi tốt nhất**: Slider từ 1-3
3. **Chọn bên đi trước**: Red hoặc Black
4. **Điều hướng**: Sử dụng nút Back/Next để xem lại lịch sử
5. **Reset**: Nút Reset để quay về vị trí ban đầu

## Giao diện

- **Bàn cờ**: Hiển thị vị trí hiện tại với quân cờ Unicode
- **Panel điều khiển**: Engine selection, MultiPV, side selection, navigation
- **Panel nước đi tốt nhất**: Hiển thị phân tích engine với điểm số và độ sâu
- **Lịch sử nước đi**: Hiển thị chuỗi nước đi đã chơi

## Phase 1 vs Phase 2

### Phase 1 (Hiện tại)
- ✅ Tích hợp engine cơ bản
- ✅ Hiển thị bàn cờ và quân cờ
- ✅ MultiPV analysis
- ✅ Navigation controls
- ✅ Basic move validation
- ❌ Piece movement (drag & drop)
- ❌ Full game logic

### Phase 2 (Tương lai)
- 🔄 Complete piece movement
- 🔄 Full Xiangqi rules validation
- 🔄 Check/checkmate detection
- 🔄 Game result detection
- 🔄 Opening book integration
- 🔄 Time controls

## Troubleshooting

### Engine không khởi động
- Kiểm tra đường dẫn engine trong `engines/` folder
- Đảm bảo file `pikafish.nnue` tồn tại cho Pikafish
- Chạy `test_engines.bat` để test riêng lẻ

### Lỗi Flutter
- Chạy `flutter clean` và `flutter pub get`
- Kiểm tra Flutter version: `flutter --version`
- Đảm bảo Windows desktop support được enable

### Performance
- Giảm MultiPV từ 3 xuống 1-2 nếu engine chậm
- Giảm search depth trong code nếu cần

## Dependencies

- `flutter_riverpod`: State management
- `freezed_annotation`: Code generation
- `collection`: Utilities
- `build_runner`: Code generation tools

## License

MIT License - Xem file LICENSE để biết thêm chi tiết.