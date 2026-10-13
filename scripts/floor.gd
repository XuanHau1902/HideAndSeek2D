@tool
extends Node2D
## Một vùng sàn hình chữ nhật. Vị trí (position) là góc trên-trái, "Size" là kích thước.
## Pattern: grass = cỏ, planks = sàn gỗ, checker = gạch caro, tiles = gạch nhỏ,
## carpet = thảm trải sàn, concrete = xi măng.
## Vùng sàn tên "Grass" (phủ cả bản đồ) cũng quyết định kích thước bản đồ.

@export var size := Vector2(400, 300):
	set(value):
		size = value
		queue_redraw()
@export_enum("grass", "planks", "checker", "tiles", "carpet", "concrete") var pattern: String = "planks":
	set(value):
		pattern = value
		queue_redraw()
@export var color_a := Color("#c9803f"):
	set(value):
		color_a = value
		queue_redraw()
@export var color_b := Color("#a8652c"):
	set(value):
		color_b = value
		queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, color_a)
	match pattern:
		"grass":
			var step := 200.0
			var x := step
			while x < size.x:
				draw_line(Vector2(x, 0), Vector2(x, size.y), color_b, 2.0)
				x += step
			var y := step
			while y < size.y:
				draw_line(Vector2(0, y), Vector2(size.x, y), color_b, 2.0)
				y += step
		"planks":
			var row_h := 24.0
			var plank_w := 128.0
			var row := 0
			var y := 0.0
			while y < size.y:
				draw_line(Vector2(0, y), Vector2(size.x, y), color_b, 2.0)
				var offset := fmod(row * 53.0, plank_w)
				var x := offset
				while x < size.x:
					draw_line(Vector2(x, y), Vector2(x, minf(y + row_h, size.y)), color_b, 2.0)
					x += plank_w
				y += row_h
				row += 1
		"checker", "tiles":
			var t := 40.0 if pattern == "checker" else 28.0
			var cols := int(ceil(size.x / t))
			var rows := int(ceil(size.y / t))
			for j in rows:
				for i in cols:
					var r := Rect2(i * t, j * t, t, t).intersection(area)
					if (i + j) % 2 == 1:
						draw_rect(r, color_b)
					if pattern == "tiles":
						draw_rect(r, color_a.darkened(0.3), false, 1.0)
		"carpet":
			draw_rect(area.grow(-10), color_b, false, 4.0)
			draw_rect(area.grow(-18), color_b.lightened(0.15), false, 1.5)
		"concrete":
			var step2 := 80.0
			var x2 := step2
			while x2 < size.x:
				draw_line(Vector2(x2, 0), Vector2(x2, size.y), color_b, 1.0)
				x2 += step2
			var y2 := step2
			while y2 < size.y:
				draw_line(Vector2(0, y2), Vector2(size.x, y2), color_b, 1.0)
				y2 += step2
