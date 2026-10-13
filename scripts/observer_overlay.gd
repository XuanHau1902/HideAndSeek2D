extends Control
## Lớp vẽ trên màn hình khi dùng camera quan sát:
## mũi tên ở mép màn hình chỉ tới những người trốn đang nằm ngoài khung hình.

const MARGIN := 34.0
const TOP_MARGIN := 110.0      # chừa chỗ cho đồng hồ / thông báo
const BOTTOM_MARGIN := 95.0    # chừa chỗ cho dòng hướng dẫn


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var game := get_tree().current_scene
	if game == null or not game.has_method("alive_hiders_except"):
		return
	var me = game.local_player()
	if me == null or not me.observing:
		return
	var screen := get_viewport_rect()
	var inner := Rect2(MARGIN, TOP_MARGIN, screen.size.x - MARGIN * 2.0, screen.size.y - TOP_MARGIN - BOTTOM_MARGIN)
	var xform := get_viewport().get_canvas_transform()
	var font := ThemeDB.fallback_font
	var center := inner.get_center()
	for h in game.alive_hiders_except(me.peer_id):
		var sp: Vector2 = xform * h.position
		if inner.has_point(sp):
			continue   # đang thấy trên màn hình rồi
		var dir := (sp - center).normalized()
		# Điểm trên mép khung hình theo hướng tới người đó.
		var tx := INF if dir.x == 0.0 else (inner.size.x / 2.0) / absf(dir.x)
		var ty := INF if dir.y == 0.0 else (inner.size.y / 2.0) / absf(dir.y)
		var p := center + dir * minf(tx, ty)
		var col := Color(0.4, 0.9, 1.0, 0.95)
		var tip := p + dir * 14.0
		var side := dir.orthogonal() * 10.0
		draw_colored_polygon(PackedVector2Array([tip, p - dir * 6.0 + side, p - dir * 6.0 - side]), col)
		var dist := int(h.position.distance_to(me.view_position()) / 10.0)
		var label := "%s · %dm" % [h.player_name, dist]
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var lp := (p - dir * 30.0) - Vector2(size.x / 2.0, -5.0)
		lp = lp.clamp(Vector2(4, TOP_MARGIN - 10.0), Vector2(screen.size.x - size.x - 4, screen.size.y - BOTTOM_MARGIN + 10.0))
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.9))
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
