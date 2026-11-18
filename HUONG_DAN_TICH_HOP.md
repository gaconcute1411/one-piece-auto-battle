# Gói "Meta game": màn hình vào game, sảnh, gacha UR/SP/SSR, điểm danh tích lũy, coin

Gói này chỉ chứa file MỚI + 2 file đã sửa (`battle.gd`, `project.godot`).
Cấu trúc thư mục khớp với gốc dự án, nên chỉ cần giải nén đè vào thư mục chứa `project.godot`.

## Cài đặt
1. Sao lưu dự án (hoặc commit git) trước.
2. Giải nén gói này đè vào thư mục dự án.
3. Mở dự án bằng Godot 4.7 (mở bằng editor ít nhất 1 lần để Godot nhận `class_name`: UIKit, CoinBar, GachaSystem).
4. Nhấn F5. Game bắt đầu từ màn hình vào game.
   Muốn test riêng trận đấu: mở `battle.tscn` rồi nhấn F6, trận dùng đội mặc định như trước.

> CHƯA CHẠY THỬ trong Godot (môi trường tạo gói không có Godot). Nếu có lỗi đỏ ở Output/Debugger,
> gửi nguyên dòng lỗi cho mình để sửa.

## Luồng game
Màn hình vào game -> Sảnh -> { Nhân vật/Đội hình | Triệu hồi | Điểm danh | Chiến đấu }
- Chiến đấu: đội của bạn vs đội ngẫu nhiên cùng số người. Thắng +150, hòa +60, thua +40 coin.
  Hết trận có nút "Về sảnh".
- Vào sảnh lần đầu trong phiên mà còn quà chưa nhận -> tự mở màn Điểm danh.
- Dữ liệu lưu tự động tại `user://save.json` (Godot: Project > Open User Data Folder).

## Bản đồ file
| File | Việc |
|---|---|
| `scripts/autoload/game_data.gd` | TOÀN BỘ số liệu cân bằng: tỉ lệ, giá, pity, quà điểm danh, bậc từng nhân vật |
| `scripts/autoload/game_state.gd` | Coin, kho nhân vật, đội hình, điểm danh, lưu/tải |
| `scripts/autoload/scene_manager.gd` | Chuyển scene có hiệu ứng mờ |
| `scripts/gacha_system.gd` | Logic triệu hồi (không có UI) |
| `scripts/ui/ui_kit.gd`, `coin_bar.gd` | Hàm dựng UI dùng chung |
| `scenes/title_screen / lobby / gacha / roster / login_rewards` | 5 màn hình (.tscn chỉ có node gốc, UI dựng bằng code) |

## Các giá trị mặc định (sửa trong game_data.gd)
- Bậc (cao -> thấp): UR > SP > SSR. UR: Kaido, Shanks. SP: Zoro, Ace, Sabo. SSR: Chopper, Jinbei, Reiju.
  Đây là phân bậc GỢI Ý tạm, bạn đổi tùy ý.
- Tỉ lệ cơ bản: UR 2% / SP 13% / SSR 85%. Bảo hiểm: đủ 50 lượt chưa ra UR thì chắc chắn UR.
  Mô phỏng 200.000 lượt cho tỉ lệ thực tế ~3.0% UR, ~14.5% SP, trung bình ~30 lượt ra UR đầu tiên.
- x10: lượt cuối đảm bảo từ SP trở lên. Giá x1 = 160, x10 = 1500 coin.
- Trùng nhân vật: +1 sao (tối đa 5), mỗi sao từ sao 2 cộng +6% HP/ATK/MAG/DEF khi vào trận (chỉ đội bạn).
  Đủ sao mà trùng nữa thì hoàn coin (UR 600 / SP 200 / SSR 60).
- Khởi đầu: 1600 coin, 3 nhân vật SSR (Chopper, Jinbei, Reiju).
- Điểm danh: 30 ngày/vòng, TÍCH LŨY không cần liên tục, tổng 10.800 coin/vòng (~7 lần x10).

## 3 chỗ đã sửa trong battle.gd (đánh dấu `[META]`)
Nếu bạn đã sửa `battle.gd` sau bản mình đọc, đừng ghi đè mà tự áp 3 thay đổi này:
1. Đầu `_ready()`: nếu `GameState.pending_battle` có `team_a` thì gán `team_a_ids` / `team_b_ids` từ đó.
2. `make_unit()`: cộng chỉ số theo sao cho team 0, và đổi `u["max_hp"] = d["hp"]` thành `u["max_hp"] = u["hp"]`.
3. `check_end()` + nhánh hòa cuối `run_battle()`: gọi `show_battle_rewards(outcome)` (hàm mới, thêm nút "Về sảnh").
`project.godot`: đổi `run/main_scene`, thêm mục `[autoload]` (3 mục) và kích thước viewport 1152x648.

## Hạn chế đã biết
- Điểm danh dựa vào đồng hồ máy: đổi ngày hệ thống là nhận được thêm. Ổn cho game offline,
  nếu có online/PvP thì phải kiểm tra phía server.
- File save là JSON thường, người chơi sửa được. Cùng lý do như trên.
- Chỉ số chiến đấu vẫn nằm trong `roster` của battle.gd; GameData chỉ giữ bậc và tên hiển thị.
  Thêm nhân vật mới = thêm vào cả `roster` (battle.gd), `BODY_REFERENCE_PX` (character_animations.gd)
  và `CHARACTERS` (game_data.gd).
- Số sao dùng ô vuông nhỏ thay vì ký tự ★ để không phụ thuộc font.
- Chưa có âm thanh, ảnh chân dung riêng (đang dùng animation idle), cài đặt, hay màn chọn màn chơi.

## Gợi ý bước tiếp theo
1. Chạy thử, báo lỗi (nếu có) để chỉnh.
2. Chốt phân bậc nhân vật và cân bằng coin (thắng 150 coin = 10 trận cho 1 lần x10 có hợp lý không).
3. Chế độ chơi có chiều sâu: chọn màn (PvE theo chương), boss, nhiệm vụ ngày.
4. Âm thanh, hiệu ứng triệu hồi đẹp hơn, chân dung từng nhân vật.
