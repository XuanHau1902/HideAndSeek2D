extends Control
## Nền phòng chờ: một góc căn nhà nhìn từ trên xuống, giống trong game.

const PropTypes = preload("res://scripts/prop_types.gd")

## [loại, vị trí theo tỉ lệ màn hình, góc xoay (độ)]
const DECOR := [
	["sofa", Vector2(0.12, 0.2), 0], ["coffee_table", Vector2(0.12, 0.34), 0], ["plant", Vector2(0.05, 0.08), 0],
	["lamp", Vector2(0.21, 0.08), 0], ["bookshelf", Vector2(0.04, 0.55), 90], ["armchair", Vector2(0.14, 0.62), 0],
	["box", Vector2(0.07, 0.86), 0], ["box", Vector2(0.11, 0.9), 0], ["barrel", Vector2(0.2, 0.88), 0],
	["bed", Vector2(0.9, 0.2), 0], ["nightstand", Vector2(0.83, 0.1), 0], ["teddy", Vector2(0.9, 0.4), 0],
	["tv", Vector2(0.88, 0.58), 270], ["fan", Vector2(0.8, 0.66), 0], ["plant", Vector2(0.95, 0.9), 0],
	["guitar", Vector2(0.97, 0.62), 0], ["fish_tank", Vector2(0.84, 0.88), 0], ["chair", Vector2(0.24, 0.6), 90],
	["flower_pot", Vector2(0.5, 0.94), 0], ["bin", Vector2(0.38, 0.95), 0], ["speaker", Vector2(0.62, 0.95), 0],
	["laundry_basket", Vector2(0.5, 0.05), 0], ["piano", Vector2(0.36, 0.06), 0], ["dresser", Vector2(0.66, 0.06), 0],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var sz := size
	# Sân cỏ
	draw_rect(Rect2(Vector2.ZERO, sz), Color("#86b84c"))
	# Sàn gỗ trong nhà
	var wall := 22.0
	var inner := Rect2(Vector2(28, 28), sz - Vector2(56, 56))
	draw_rect(inner.grow(wall), Color("#3a0f12"))
	draw_rect(inner.grow(wall - 3.0), Color("#7c2329"))
	draw_rect(inner, Color("#c97d3c"))
	var row := 0
	var y := inner.position.y
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color("#a8652c"), 2.0)
		var x := inner.position.x + fmod(row * 53.0, 128.0)
		while x < inner.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 24.0, inner.end.y)), Color("#a8652c"), 2.0)
			x += 128.0
		y += 24.0
		row += 1
	# Cửa sổ trên tường
	for fx in [0.25, 0.5, 0.75]:
		var wx: float = sz.x * fx
		draw_rect(Rect2(wx - 50, inner.position.y - wall + 3, 100, wall - 6), Color("#5f6f63"))
		draw_rect(Rect2(wx - 48, inner.position.y - wall / 2.0 - 2, 96, 4), Color("#a8d4e6"))
	# Đồ đạc
	for d in DECOR:
		var dp: Vector2 = d[1]
		draw_set_transform(Vector2(sz.x * dp.x, sz.y * dp.y), deg_to_rad(d[2]))
		PropTypes.draw(self, d[0])
	draw_set_transform(Vector2.ZERO, 0.0)
	# Lớp tối nhẹ để thẻ ở giữa nổi bật
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.04, 0.02, 0.35))
