class_name CoinBar
extends HBoxContainer
## Chip hiển thị số coin, tự cập nhật theo GameState.coins_changed.

var _value: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var chip := UIKit.panel(Color(0, 0, 0, 0.55), 20, Color("ffc83d"), 2)
	chip.add_theme_stylebox_override("panel", UIKit.style(Color(0, 0, 0, 0.55), 20, Color("ffc83d"), 2, 8.0))
	add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)

	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(26, 26)
	coin.add_theme_stylebox_override("panel", UIKit.style(Color("ffc83d"), 13, Color("b8860b"), 3, 0.0))
	row.add_child(coin)

	_value = UIKit.label("0", 24, Color("ffe08a"))
	_value.custom_minimum_size = Vector2(90, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_value)

	GameState.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(GameState.coins)


func _on_coins_changed(v: int) -> void:
	_value.text = _format(v)


static func _format(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out
