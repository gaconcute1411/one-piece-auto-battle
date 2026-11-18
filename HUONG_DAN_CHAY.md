# Huong dan chay demo Auto Battle 3vs3 co animation

## Chay tren Godot
1. Giai nen file `2d-battle-onepiece-animated.zip`.
2. Mo Godot 4.7 (hoac ban tuong thich), chon **Import** va tro den `project.godot`.
3. Doi Godot import xong PNG (lan dau co the lau hon), sau do nhan **F5**.
4. Game chay voi doi hinh mac dinh: **Zoro / Chopper / Jinbei** vs **Kaido / Reiju / Ace**.

## Xem ca 8 nhan vat
Trong file `battle.gd`, sua hai dong:
```gdscript
var team_a_ids = ["zoro", "chopper", "jinbei"]
var team_b_ids = ["kaido", "reiju", "ace"]
```
VD de xem Sabo va Shanks:
```gdscript
var team_a_ids = ["sabo", "shanks", "zoro"]
var team_b_ids = ["kaido", "reiju", "ace"]
```

## Kiem tra animation
- `battle_loop`: 6 frame, lap lien tuc trong tran.
- `s1` va `s2`: moi skill 6 frame.
- `ult`: 12 frame.
- Anh cua moi nhan vat duoc dua ve canvas 768x576, pivot (312,500), can theo chan va dung cung mot ti le co the khi tung chieu.
- Damage duoc goi tai moc frame thay vi tru mau ngay khi anim vua bat dau. Skill nhieu hit van giu so hit goc.
- Skill phong thu, hoi mau va buff van giu logic `battle.gd`.

## Tuy chinh
- Neu muon tat animation de test lai gameplay goc, doi `USE_CHARACTER_ANIMATIONS` thanh `false` gan dau `battle.gd`.
- Chinh kich thuoc cua nhan vat trong `roster` theo thuoc tinh `h`; hoac tinh chinh gia tri `BODY_REFERENCE_PX` trong `scripts/character_animations.gd`.
- File `animations/<id>/spriteframes.tres` co the mo va chinh trong Godot.

## Luu y
Ban ZIP nay duoc kiem tra cau truc tai nguyen, CRC va 240 file anh. Chua chay bang Godot trong moi truong xuat file; can kiem tra tiep tren may cua ban. Hieu ung da bi cat ngay trong anh nguon khong the khoi phuc hoan toan khi tich hop.
