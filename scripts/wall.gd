@tool
extends StaticBody2D
## Bức tường hình chữ nhật. Chỉnh "Size" và "Style" ở Inspector, kéo thả để đặt vị trí (tâm tường).
## Style: outer = tường ngoài nhà, inner = vách ngăn trong nhà, window = cửa sổ, fence = hàng rào gỗ.

@export var size := Vector2(200, 24):
	set(value):
		size = value
		_rebuild()
@export_enum("outer", "inner", "window", "fence") var style: String = "outer":
	set(value):
		style = value
		queue_redraw()

var _shape_owner := -1


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if _shape_owner == -1:
		_shape_owner = create_shape_owner(self)
	shape_owner_clear_shapes(_shape_owner)
	var r := RectangleShape2D.new()
	r.size = size
	shape_owner_add_shape(_shape_owner, r)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	var horizontal := size.x >= size.y
	match style:
		"outer":
			draw_rect(rect, Color("#3a0f12"))
			draw_rect(rect.grow(-3), Color("#7c2329"))
		"inner":
			draw_rect(rect, Color("#7d7464"))
			draw_rect(rect.grow(-2.5), Color("#ece5d6"))
		"window":
			draw_rect(rect, Color("#3a0f12"))
			var glass := rect.grow(-3)
			draw_rect(glass, Color("#5f6f63"))
			# tấm kính mỏng ở giữa
			if horizontal:
				draw_rect(Rect2(glass.position.x + 2, -2.5, glass.size.x - 4, 5), Color("#a8d4e6"))
			else:
				draw_rect(Rect2(-2.5, glass.position.y + 2, 5, glass.size.y - 4), Color("#a8d4e6"))
		"fence":
			var wood := Color("#9a6a3a")
			draw_rect(rect, wood.darkened(0.5))
			draw_rect(rect.grow(-2), wood)
			var length := size.x if horizontal else size.y
			var n := int(length / 60.0)
			for i in range(n + 1):
				var t := -length / 2.0 + i * (length / maxf(1.0, n))
				var post := Rect2(t - 5, -size.y / 2.0 - 2, 10, size.y + 4) if horizontal \
					else Rect2(-size.x / 2.0 - 2, t - 5, size.x + 4, 10)
				draw_rect(post, wood.darkened(0.5))
				draw_rect(post.grow(-2), wood.darkened(0.15))
