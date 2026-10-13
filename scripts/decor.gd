@tool
extends Node2D
## Đồ trang trí nằm phẳng trên sàn (thảm, thảm chùi chân). Không va chạm, không phá được.
## Vị trí là tâm của tấm thảm.

@export var size := Vector2(160, 100):
	set(value):
		size = value
		queue_redraw()
@export_enum("rug", "round_rug", "mat") var style: String = "rug":
	set(value):
		style = value
		queue_redraw()
@export var color := Color("#8e2f2f"):
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	match style:
		"rug":
			draw_rect(rect, color.darkened(0.35))
			draw_rect(rect.grow(-5), color)
			draw_rect(rect.grow(-12), color.lightened(0.25), false, 2.0)
			var h := size / 2.0 - Vector2(22, 22)
			var diamond := PackedVector2Array([Vector2(0, -h.y), Vector2(h.x * 0.5, 0), Vector2(0, h.y), Vector2(-h.x * 0.5, 0)])
			draw_colored_polygon(diamond, color.darkened(0.25))
			draw_circle(Vector2.ZERO, minf(h.x, h.y) * 0.25, color.lightened(0.3))
			# tua rua hai đầu
			var x := rect.position.x + 4.0
			while x < rect.end.x - 2.0:
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y - 5), color.lightened(0.4), 1.5)
				draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + 5), color.lightened(0.4), 1.5)
				x += 6.0
		"round_rug":
			var r := minf(size.x, size.y) / 2.0
			draw_circle(Vector2.ZERO, r, color.darkened(0.35))
			draw_circle(Vector2.ZERO, r - 5, color)
			draw_arc(Vector2.ZERO, r * 0.65, 0, TAU, 40, color.lightened(0.25), 3.0)
			draw_circle(Vector2.ZERO, r * 0.25, color.lightened(0.2))
		"mat":
			draw_rect(rect, Color("#4a3b2a"))
			draw_rect(rect.grow(-4), color)
			var y := rect.position.y + 6.0
			while y < rect.end.y - 4.0:
				draw_line(Vector2(rect.position.x + 6, y), Vector2(rect.end.x - 6, y), color.darkened(0.25), 2.0)
				y += 6.0
