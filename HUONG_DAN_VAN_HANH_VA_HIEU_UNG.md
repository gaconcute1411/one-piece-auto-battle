# Hướng dẫn vận hành và mở rộng hiệu ứng

## Bản bàn giao

- Dự án giữ nguyên luồng chơi và danh sách 8 nhân vật: Zoro, Chopper, Reiju, Shanks, Sabo, Jinbei, Ace, Kaido.
- Không đưa `.godot/` vào gói bàn giao. Đây là cache/import do Godot tự tạo; mở `project.godot` bằng Godot 4.7 để import lại.
- Ảnh tổng hợp kiểm tra sprite trong `tools/reports/` là đầu ra có thể sinh lại. Đã loại khỏi bản gọn để tiết kiệm dung lượng; lệnh kiểm tra sẽ tạo lại.

## Quy trình kiểm tra sprite

Chạy tại thư mục gốc dự án, cần Python 3 cùng Pillow và NumPy:

```bash
python tools/sprite_tools.py check
python tools/sprite_tools.py check zoro
python tools/sprite_tools.py build zoro
```

`check` rà soát 8 nhân vật và sinh ảnh tổng hợp trong `tools/reports/`. `build` chỉ dùng sau khi chỉnh frame để tạo lại `spriteframes.tres`. Không xóa PNG nguồn, file `.import`, các file `.tres`, hay sửa ID nhân vật nếu muốn giữ nguyên project hiện tại.

## Hiệu ứng nằm ngoài khung hình nhân vật

Không cần nhét tất cả hiệu ứng vào sprite sheet. Chọn cách đặt hiệu ứng theo phạm vi và thời gian sống:

1. **Hiệu ứng gắn vào cơ thể** (lửa quanh đồng đội, độc, khiên): tạo node FX làm con của node nhân vật. Dùng tọa độ local; hiệu ứng sẽ đi theo nhân vật. Đặt `z_index` để FX nằm sau/trước sprite theo ý muốn.
2. **Hiệu ứng tại vị trí thế giới** (burn bùng lên, nổ, vòng Room): thêm FX vào node sân đấu hoặc một `Node2D` riêng như `BattleVFXLayer`, rồi đặt `global_position`. Không gắn lên nhân vật nếu hiệu ứng cần đứng yên tại chỗ sau khi mục tiêu di chuyển.
3. **Hiệu ứng bay** (đạn, cầu lửa, luồng nước): tạo node độc lập trên lớp FX, tween từ điểm xuất phát tới điểm va chạm; khi tới nơi phát impact rồi `queue_free()`. Đạn phải sống độc lập với animation của nhân vật.
4. **Hiệu ứng phủ màn hình** (flash, cut-in): dùng `CanvasLayer`; tránh dùng lớp này cho hiệu ứng cần bị che bởi địa hình/sprite.

Trong project hiện tại, `BattleVFX` trong `battle.gd` vẽ hiệu ứng bằng vector, `fly_skill_orb()` xử lý vật thể bay, và `spawn_skill_vfx()` tạo hiệu ứng tồn tại ngắn tại tọa độ. Đây là nền tảng có thể tái sử dụng mà không làm thay đổi luật chiến đấu.

### Ví dụ cho các hiệu ứng bạn nêu

- **Lửa quanh đồng đội:** aura gắn vào node nhân vật, theo dõi thời hạn buff bằng dữ liệu trạng thái; khi hết buff, fade-out rồi giải phóng node.
- **Burn:** dữ liệu sát thương theo lượt vẫn là nguồn sự thật. FX lửa gắn lên mục tiêu chỉ biểu diễn trạng thái; khi nhận tick burn thì phát thêm impact nhỏ. Nếu mục tiêu chết/hết burn, dừng FX.
- **Đạn bay:** node projectile độc lập, `global_position` tween từ người bắn tới mục tiêu. Impact chỉ phát khi projectile đến; hủy projectile nếu trận đấu kết thúc.
- **Lồng tơ:** đặt các đường tơ/vòng khóa ở tọa độ thế giới quanh mục tiêu, hoặc gắn vào mục tiêu nếu nó cần di chuyển cùng. Bộ đếm lượt trói và chặn hành động phải tách khỏi hình ảnh.
- **Room của Law:** vòng lớn đặt ở tọa độ thế giới; chỉ dùng `CanvasLayer` nếu cần luôn nằm phủ trên giao diện. Vùng ảnh hưởng và hiệu ứng hình ảnh nên là hai node riêng để gameplay không phụ thuộc việc vòng tròn đang hiện hay không.

### Nguyên tắc để FX không gây lỗi

- Gameplay quyết định trúng đòn, burn, trói và buff; animation chỉ báo hiệu. Không dùng việc node FX xuất hiện làm điều kiện gây sát thương.
- Tạo hiệu ứng ở đúng tọa độ: `position` khi là con của nhân vật/layer; `global_position` khi đặt từ tọa độ sân đấu.
- Mọi FX ngắn hạn cần tự giải phóng sau tween/animation; FX trạng thái cần được dừng khi trạng thái hết, nhân vật chết, hoặc trận kết thúc.
- Dùng một lớp FX dùng chung để quản lý thứ tự hiển thị và dễ tắt hiệu ứng khi cần tối ưu.
- Hiệu ứng lớn vượt khung 768×576 có thể xuất thành clip riêng kích thước lớn hơn, nhưng phải căn cùng pivot theo `SPRITE_SPEC.md`; không kéo giãn từng frame nhân vật.

## Giảm dung lượng

- Có thể xóa `.godot/` khi đóng Godot; Godot tự tạo cache lại. Bản ZIP bàn giao này đã bỏ cache đó.
- `tools/reports/*.png` có thể xóa và tạo lại bằng lệnh `check`; bản ZIP đã bỏ ảnh tổng hợp để giảm kích thước.
- PNG animation là tài nguyên nguồn cần thiết cho 8 nhân vật. Không giảm kích thước/đổi định dạng mất dữ liệu nếu chưa chấp nhận giảm chất lượng và kiểm tra lại pivot, frame, import.
- Khi xuất bản game, dùng **Project > Export** để đóng gói tài nguyên cần thiết thay vì gửi toàn bộ thư mục nguồn.
