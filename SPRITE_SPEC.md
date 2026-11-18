# Đặc tả sprite nhân vật (đưa file này cho AI agent mỗi lần làm / sửa)

Mục đích: giảm lỗi và giảm số lần làm lại. Mọi yêu cầu kỹ thuật cố định nằm ở đây,
lúc nhờ AI chỉ cần nói **nhân vật nào + clip nào + muốn gì**.

## 1. Quy chuẩn kỹ thuật (KHÔNG đổi giữa các nhân vật)
| Mục | Giá trị |
|---|---|
| Canvas mỗi frame | **768 x 576**, PNG RGBA, nền trong suốt |
| Điểm chân (pivot) | **(312, 500)**: chân nhân vật luôn đứng ở điểm này ở MỌI frame |
| Hướng mặt | Nhìn sang **phải** (phe phải sẽ tự lật gương trong game) |
| Kích cỡ cơ thể | **Giữ nguyên ở mọi frame và mọi clip**. Không phóng to/thu nhỏ khi ra chiêu |
| Chừa lề | Hiệu ứng (lửa, lốc, vệt chém) phải nằm **trọn trong canvas**, không chạm mép |
| Clip | `battle_loop` 6 frame (lặp), `s1` 6, `s2` 6, `ult` 12 |
| Tên file | `animations/<id>/<clip>/f01.png ... fNN.png` |

## 2. Quy trình làm việc (mỗi lượt chỉ làm MỘT clip)
1. Chốt **ảnh idle gốc** của nhân vật (1 ảnh duy nhất) và dùng nó làm "nguồn sự thật" cho mọi clip.
2. Làm **1 clip → chạy kiểm tra → sửa → mới sang clip tiếp**. Không nhờ AI làm cả 30 frame một lần.
3. Chạy: `python tools/sprite_tools.py check <id>` rồi mở `tools/reports/<id>.png`
   (viền đỏ = frame có vấn đề). Chỉ gửi lại cho AI **đúng những frame bị cảnh báo**.
4. Khi cả 4 clip đạt: `python tools/sprite_tools.py build <id>` để tự sinh `spriteframes.tres`.
   (AI không cần viết file này nữa, đây là chỗ hay sai nhất.)
5. Chỉ khi `check` báo OK mới mở Godot kiểm tra bằng mắt.

## 3. Mẫu yêu cầu cho AI (copy, điền chỗ trong < >)
```
Nhân vật: <id>   Clip: <s1 | s2 | ult | battle_loop>   Số frame: <6 hoặc 12>
Ảnh idle gốc: <đính kèm>   Ảnh tham khảo phong cách: <đính kèm, nếu có>

Mô tả chiêu: <mỗi frame làm gì, theo thứ tự. Ví dụ:
  f01 gồng người, f02-f03 xoay, f04 nhịp hit 1, f05 nhịp hit 2, f06 thu chiêu>
Nhịp sát thương (frame nào gây hit): <ví dụ f03, f04, f05>
Hiệu ứng: <màu, hình dạng, mức lớn nhất. Ví dụ: lốc xoáy xanh lá + tím, rộng tối đa 600px>

Ràng buộc BẮT BUỘC (xem SPRITE_SPEC.md mục 1):
- 768x576 RGBA nền trong suốt, chân đứng tại (312,500) mọi frame
- Nhân vật giữ NGUYÊN kích cỡ so với ảnh idle, không to/nhỏ lên khi ra chiêu
- Mọi hiệu ứng nằm trọn trong canvas, không chạm mép
- Hai frame liền nhau phải KHÁC nhau và chuyển động nhỏ dần (không xoay nguyên idle)
- Xuất đúng tên f01.png..fNN.png

Trước khi trả kết quả: tự kiểm tra danh sách trên và liệt kê frame nào có nguy cơ vi phạm.
```

## 4. Lỗi hay gặp -> cách phòng
| Lỗi | Phòng |
|---|---|
| Nhân vật to/nhỏ lên khi vào chiêu | Ghi rõ "giữ kích cỡ như idle", gửi lại ảnh idle ở mỗi lượt |
| Hiệu ứng bị cắt mép | Nêu kích thước tối đa của hiệu ứng; đã có cảnh báo "chạm mép" trong `check` |
| Chuyển frame giống "xoay nguyên idle" | Mô tả từng frame khác nhau; `check` báo frame trùng hệt |
| Chân lệch, nhân vật "trôi" | Pivot cố định (312,500); `check` báo chân dao động |
| Sai tên/thiếu frame | `check` báo ngay; không để AI tự đặt tên |
| Sai `spriteframes.tres` | Dùng `build`, không nhờ AI viết |

## 5. Làm nhiều nhân vật
- Làm theo **lô theo clip** thay vì theo nhân vật: ví dụ làm hết `s1` cho 3 nhân vật, kiểm tra, rồi mới làm `s2`.
  Lỗi cùng loại sẽ lặp lại và bạn dùng chung một cách sửa.
- Ưu tiên `ult` và `s1` của nhân vật bạn dùng nhiều nhất; `s2` phòng thủ/hồi máu có thể làm sau bằng hiệu ứng code (ít frame hơn).
- Giữ một thư mục "chuẩn" (ví dụ Zoro đã đạt) để đính kèm làm mẫu cho các nhân vật mới.

## 6. Clip có khung hình to hơn bình thường (dùng chung cho MỌI nhân vật)
Dùng cho: hóa rồng, phượng hoàng, cầu lửa khổng lồ, hóa Phật, sóng thần, triệu hồi... mọi thứ lớn hơn canvas thường.

Game giữ **một tỉ lệ pixel duy nhất** cho mọi clip, nên muốn hình to hơn thì clip đó phải được vẽ trên **canvas lớn hơn**.
Quy tắc (không cần khai báo gì trong code):
1. Canvas = **768x576 nhân k**, với k = 1.5, 2, 2.5, 3 hoặc 4 (ví dụ k=2 -> 1536x1152). Luôn giữ tỉ lệ 4:3.
2. Chân/điểm neo nhân vật nằm ở cùng vị trí **tương đối**: **40.6% từ trái** và **86.8% từ trên**
   (k=2: (624, 1000); k=3: (936, 1500)). Phần bên phải còn lại ~59% chiều rộng cho tia lửa, cánh, cầu lửa bay tới.
3. Giữ nguyên tỉ lệ pixel với idle: người cao 340px thì khi hóa rồng, thân rồng vẽ cao ~700-1000px, không thu nhỏ cho vừa khung.
4. Mọi frame trong cùng một clip cùng kích thước. `battle_loop` luôn 768x576 (khung cut-in ultimate cắt ảnh từ clip này).
5. Game tự đọc kích thước ảnh và đặt chân đúng chỗ cho cả hai phe; `check` kiểm tra bội số hợp lệ và vẽ dấu pivot trên ảnh tổng hợp.

Chọn hệ số k theo hiệu ứng:
| Hiệu ứng | k gợi ý |
|---|---|
| Cầu lửa lớn, sóng kiếm, cánh phượng hoàng mở rộng | 1.5 - 2 |
| Hóa rồng, hóa Phật, bão lớn | 2 - 3 |
Kích thước trên sân = pixel trong ảnh x tỉ lệ hiển thị (ví dụ Kaido: ~0.39). Canvas 1536 -> khoảng 600px trên sân, tức chiếm
cỡ nửa sân bên đó; k lớn hơn sẽ lấn sang phe địch và vượt khỏi màn hình.

**Giới hạn bộ nhớ (quan trọng nếu xuất Android):** mỗi frame RGBA chiếm khoảng (rộng x cao x 4) byte trong VRAM.
| Canvas | Mỗi frame | Clip 12 frame |
|---|---|---|
| 768x576 (k=1) | 1.8 MB | 21 MB |
| 1536x1152 (k=2) | 7 MB | 85 MB |
| 2304x1728 (k=3) | 16 MB | 191 MB |
Vì vậy: k=2 cho đa số nhân vật; k=3 chỉ dùng cho vài clip đặc biệt, và nên giảm số frame (ví dụ 8 thay vì 12) hoặc
chấp nhận chỉ chạy trên máy mạnh. Đừng cho mọi nhân vật dùng k=3.

Khi nhờ AI vẽ, thêm dòng này vào yêu cầu:
```
Clip này dùng canvas <1536x1152> (k=2). Chân/điểm neo nhân vật ở (<624>, <1000>) mọi frame.
Giữ nguyên tỉ lệ pixel với ảnh idle (không thu nhỏ để vừa khung). Hiệu ứng chạy sang bên phải, nằm trọn trong canvas.
Frame biến hình/phóng chiêu to dần từng bước, mô tả: <f01..f12>.
```

Chỉ khi cần pivot khác quy tắc (ví dụ phượng hoàng bay cao hơn mặt đất) mới khai báo riêng trong `CLIP_LAYOUT`
của `scripts/character_animations.gd` (có dòng mẫu và giải thích sẵn trong file).
