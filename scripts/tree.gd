@tool
extends StaticBody2D
## Cây ngoài sân: thân cây chặn đường, tán lá che phía trên người chơi.
## Khi nhân vật của bạn đứng dưới tán, tán sẽ mờ đi (chỉ trên màn hình của bạn),
## nên người trốn có thể núp dưới gốc cây.

@export var canopy_radius := 80.0:
	set(value):
		canopy_radius = value
		queue_redraw()
@export var trunk_radius := 18.0:
	set(value):
		trunk_radius = value
		_rebuild()

var _alpha := 1.0
var _shape_owner := -1


func _ready() -> void:
	z_index = 40   # vẽ đè lên người chơi
	_rebuild()


func _rebuild() -> void:
	if _shape_owner == -1:
		_shape_owner = create_shape_owner(self)
	shape_owner_clear_shapes(_shape_owner)
	var c := CircleShape2D.new()
	c.radius = trunk_radius
	shape_owner_add_shape(_shape_owner, c)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := 1.0
	var me := get_tree().get_first_node_in_group("local_player") as Node2D
	var view: Vector2 = me.view_position() if me and me.has_method("view_position") else (me.global_position if me else Vector2.INF)
	if me and view.distance_to(global_position) < canopy_radius + 8.0:
		target = 0.35
	var new_alpha := move_toward(_alpha, target, delta * 3.0)
	if not is_equal_approx(new_alpha, _alpha):
		_alpha = new_alpha
		queue_redraw()


func _draw() -> void:
	var r := canopy_radius
	var dark := Color("#2f6b2c")
	var mid := Color("#3f8a3a")
	var light := Color("#56a64e")
	var a := _alpha
	draw_circle(Vector2(6, 8), r, Color(0, 0, 0, 0.2 * a))
	draw_circle(Vector2.ZERO, trunk_radius, Color("#5a3a20"))
	# tán lá dạng nhiều cụm tròn
	for i in 11:
		var ang := TAU * i / 11.0
		draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.66, r * 0.38, Color(dark, a))
	draw_circle(Vector2.ZERO, r * 0.78, Color(dark, a))
	for i in 11:
		var ang := TAU * i / 11.0 + 0.2
		draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.6, r * 0.32, Color(mid, a))
	draw_circle(Vector2.ZERO, r * 0.66, Color(mid, a))
	for i in 5:
		var ang := TAU * i / 5.0 + 0.6
		draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.32, r * 0.2, Color(light, a))
