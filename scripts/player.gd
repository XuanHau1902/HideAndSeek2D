extends CharacterBody2D
## Nhân vật người chơi.
## Máy của ai thì người đó điều khiển nhân vật của mình (multiplayer authority),
## vị trí và hình dạng hóa trang được gửi cho các máy khác.

const PropTypes = preload("res://scripts/prop_types.gd")
const Rules = preload("res://scripts/game_rules.gd")
const SmokePuff = preload("res://scripts/smoke_puff.gd")
const POP_TIME := 0.2

const SPEED := 230.0
const DISGUISED_SPEED := 175.0
const GHOST_SPEED := 340.0
const BODY_RADIUS := 16.0
const HIDER_COLOR := Color("#4aa3ff")
const SEEKER_COLOR := Color("#ff5a4a")

var peer_id := 1
var player_name := ""
var role := "hider"          # "hider" hoặc "seeker"
var disguise := ""           # loại đồ vật đang hóa trang, "" = hình người
var disguise_rot := 0.0      # góc xoay của đồ vật hóa trang (bội số 90°)
var alive := true
var hp := Rules.SEEKER_MAX_HP
var weapon := "hammer"       # vũ khí đang cầm (người tìm)
var can_move := false        # màn chơi bật/tắt theo giai đoạn
var net_ready := false       # chỉ gửi vị trí khi mọi máy đã tải xong màn chơi
var game: Node = null
var map_rect := Rect2(0, 0, 2400, 1600)

var _target_pos := Vector2.ZERO
var _facing := Vector2.RIGHT
var _last_pos := Vector2.ZERO
var _attack_cd := 0.0
var _shape_owner := -1

# Camera quan sát (chỉ trên máy của chính người chơi này)
const OBSERVE_SPEED := 650.0
const OBSERVE_ZOOM_MIN := 0.35
const OBSERVE_ZOOM_MAX := 1.5
var observing := false
var observe_target = null   # người trốn đang được bám theo (null = camera tự do)
var _cam_world := Vector2.ZERO
var _step_acc := 0.0
var _pop := 0.0   # hiệu ứng đồ vật "bật" ra sau làn khói

@onready var name_label: Label = $NameLabel
@onready var camera: Camera2D = $Camera2D


## Gọi trước khi add_child.
func setup(id: int, p_name: String, p_role: String, start_pos: Vector2, p_game: Node, p_map: Rect2) -> void:
	peer_id = id
	name = str(id)
	player_name = p_name
	role = p_role
	hp = Rules.SEEKER_MAX_HP if p_role == "seeker" else Rules.HIDER_MAX_HP
	position = start_pos
	_target_pos = start_pos
	game = p_game
	map_rect = p_map
	set_multiplayer_authority(id)


func _ready() -> void:
	_last_pos = position
	name_label.text = player_name
	_shape_owner = create_shape_owner(self)
	_update_shape()
	if is_multiplayer_authority():
		add_to_group("local_player")
		camera.limit_left = int(map_rect.position.x)
		camera.limit_top = int(map_rect.position.y)
		camera.limit_right = int(map_rect.end.x)
		camera.limit_bottom = int(map_rect.end.y)
		camera.enabled = true
		camera.make_current()
	else:
		camera.enabled = false
	refresh_visibility()


func is_seeker() -> bool:
	return role == "seeker"


## Vị trí mới nhất nhận qua mạng (máy chủ dùng để xét trúng đòn).
func get_net_position() -> Vector2:
	return position if is_multiplayer_authority() else _target_pos


## Điểm (tọa độ thế giới) có trúng người này không.
func contains_point(world_point: Vector2) -> bool:
	var local := world_point - get_net_position()
	if disguise != "":
		return PropTypes.contains_point(disguise, local.rotated(-disguise_rot))
	return local.length() <= BODY_RADIUS + 4.0


# ---------------------------------------------------------------- Điều khiển

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not alive:
		# Bóng ma: bay xuyên tường để xem tiếp.
		position = (position + dir * GHOST_SPEED * delta).clamp(map_rect.position, map_rect.end)
		return
	if can_move and not observing:
		velocity = dir * (DISGUISED_SPEED if disguise != "" else SPEED)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if net_ready:
		_sync_position.rpc(position, _facing.angle())


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		# Làm mượt chuyển động của người chơi khác.
		if position.distance_to(_target_pos) > 200.0:
			position = _target_pos
		else:
			position = position.lerp(_target_pos, clampf(delta * 15.0, 0.0, 1.0))
	var moved := position - _last_pos
	if moved.length() > 0.3:
		_facing = moved.normalized()
	# Tiếng bước chân của người tìm (người trốn nghe được khi họ tới gần)
	if is_seeker() and alive and moved.length() < 50.0:
		_step_acc += moved.length()
		if _step_acc > 72.0:
			_step_acc = 0.0
			Sfx.play_at("step", position)
	_last_pos = position
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_pop = maxf(0.0, _pop - delta)
	if observing:
		_update_observe_camera(delta)
	# Khi người chơi trên máy này đang quan sát: người trốn khác được vẽ nổi lên trên tán cây.
	z_index = 45 if _is_highlighted_for_observer() else 0
	if is_multiplayer_authority() and is_seeker() and alive:
		var m := get_global_mouse_position() - position
		if m.length() > 1.0:
			_facing = m.normalized()
		# Súng trường: giữ chuột để bắn liên tục.
		if can_move and Rules.WEAPONS[weapon]["auto"] and Input.is_action_pressed("attack"):
			_try_fire()
	elif not is_multiplayer_authority() and is_seeker():
		_facing = Vector2.from_angle(_remote_aim)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or not alive or not can_move:
		return
	if is_seeker():
		if event.is_action_pressed("attack"):
			_try_fire()
		for w in Rules.WEAPON_ORDER:
			if event.is_action_pressed("weapon_%d" % Rules.WEAPONS[w]["key"]):
				select_weapon(w)
	else:
		if event.is_action_pressed("observe"):
			if observing:
				stop_observing()
			elif disguise == "":
				game.hud.show_message("Hãy hóa trang thành đồ vật trước rồi mới mở camera quan sát.")
			else:
				start_observing()
			return
		if observing:
			_observe_input(event)
			return
		if event.is_action_pressed("disguise"):
			var prop: Node2D = game.find_nearest_prop(position, Rules.DISGUISE_RANGE)
			if prop:
				set_disguise.rpc(prop.prop_type, prop.snapped_rotation())
			else:
				game.hud.show_message("Không có đồ vật nào ở gần để hóa trang.")
		elif event.is_action_pressed("rotate_disguise") and disguise != "":
			set_disguise.rpc(disguise, wrapf(disguise_rot + PI / 2.0, 0.0, TAU))


# ---------------------------------------------------------------- Camera quan sát

func start_observing() -> void:
	observing = true
	observe_target = null
	_cam_world = global_position
	velocity = Vector2.ZERO
	game.hud.show_message("Đã bật camera quan sát", Color("#9fd3ff"))


func stop_observing() -> void:
	if not observing:
		return
	observing = false
	observe_target = null
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE


## Vị trí mà người chơi này đang "nhìn" (dùng cho tán cây mờ đi).
func view_position() -> Vector2:
	return _cam_world if observing else global_position


func _observe_input(event: InputEvent) -> void:
	if event.is_action_pressed("observe_next"):
		var hiders: Array = game.alive_hiders_except(peer_id)
		if hiders.is_empty():
			game.hud.show_message("Không còn người trốn nào khác.")
			observe_target = null
			return
		var idx := hiders.find(observe_target)
		observe_target = hiders[(idx + 1) % hiders.size()]
		game.hud.show_message("Đang theo dõi: %s" % observe_target.player_name, Color("#9fd3ff"))
	elif event is InputEventMouseButton and event.pressed:
		var z := camera.zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			z *= 1.12
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			z /= 1.12
		z = clampf(z, OBSERVE_ZOOM_MIN, OBSERVE_ZOOM_MAX)
		camera.zoom = Vector2(z, z)


func _update_observe_camera(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		observe_target = null   # tự lia camera thì thôi bám theo
		_cam_world += dir * OBSERVE_SPEED / camera.zoom.x * delta
	elif observe_target != null:
		if is_instance_valid(observe_target) and observe_target.alive:
			_cam_world = observe_target.position
		else:
			observe_target = null
	_cam_world = _cam_world.clamp(map_rect.position, map_rect.end)
	camera.position = _cam_world - global_position


func _is_highlighted_for_observer() -> bool:
	if is_multiplayer_authority() or role != "hider" or not alive or game == null:
		return false
	var me = game.local_player()
	return me != null and me.observing


## Bị ép biến hình: thử lần lượt các loại đồ vật (đã xáo trộn sẵn), chọn loại đầu tiên
## vừa với chỗ đang đứng để không bị kẹt vào tường. Chỉ chạy trên máy của người trốn này.
func force_random_disguise(candidates: Array) -> void:
	if not is_multiplayer_authority() or not alive or role != "hider":
		return
	for type_id in candidates:
		if type_id == disguise:
			continue
		for rot in [disguise_rot, disguise_rot + PI / 2.0]:
			if _fits(type_id, rot):
				set_disguise.rpc(type_id, wrapf(rot, 0.0, TAU))
				return
	# Không loại nào vừa: dùng loại nhỏ nhất.
	set_disguise.rpc("bin" if disguise != "bin" else "lamp", 0.0)


func _fits(type_id: String, rot: float) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = PropTypes.make_shape(type_id, 2.0)
	params.transform = Transform2D(rot, global_position)
	params.collision_mask = 1
	params.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


# ---------------------------------------------------------------- Vũ khí (người tìm)

func select_weapon(w: String) -> void:
	if w == weapon or not Rules.WEAPONS.has(w):
		return
	if w == "shotgun" and not game.shotgun_unlocked():
		game.hud.show_message("Shotgun chỉ mở khóa trong %d giây cuối trận." % int(Rules.SHOTGUN_UNLOCK_TIME), Color("#ffb3a8"))
		return
	set_weapon.rpc(w)


@rpc("authority", "call_local", "reliable")
func set_weapon(w: String) -> void:
	if Rules.WEAPONS.has(w):
		weapon = w
		if is_multiplayer_authority():
			Sfx.play("weapon_switch")
		_attack_cd = maxf(_attack_cd, 0.2)   # đổi vũ khí mất chút thời gian


func _try_fire() -> void:
	if _attack_cd > 0.0 or not can_move or not alive:
		return
	if weapon == "shotgun" and not game.shotgun_unlocked():
		return
	_attack_cd = Rules.WEAPONS[weapon]["cooldown"]
	game.local_attack(weapon, get_global_mouse_position())


var _remote_aim := 0.0


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_position(pos: Vector2, aim: float) -> void:
	_target_pos = pos
	_remote_aim = aim


@rpc("authority", "call_local", "reliable")
func set_disguise(type_id: String, rot: float = 0.0) -> void:
	if role != "hider" or not alive:
		return
	if not PropTypes.TYPES.has(type_id):
		return   # không cho trở lại hình người
	var changed := type_id != disguise
	disguise = type_id
	disguise_rot = rot if type_id != "" else 0.0
	_update_shape()
	refresh_visibility()
	if changed:
		_spawn_smoke()


## Làn khói biến thân. Người tìm có thấy hay không tùy Rules.SMOKE_VISIBLE_TO_SEEKERS.
func _spawn_smoke() -> void:
	if game == null or not is_inside_tree():
		return
	if not Rules.SMOKE_VISIBLE_TO_SEEKERS and game.local_role() == "seeker":
		return
	var ext := PropTypes.get_extent(disguise)
	var puff := SmokePuff.new()
	puff.size = clampf(maxf(ext.x, ext.y) * 0.6 + 14.0, 28.0, 80.0)
	puff.position = position
	game.effects_root.add_child(puff)
	Sfx.play_at("poof", position)
	_pop = POP_TIME


# ---------------------------------------------------------------- Trạng thái

func set_dead() -> void:
	stop_observing()
	alive = false
	disguise = ""
	disguise_rot = 0.0
	velocity = Vector2.ZERO
	_update_shape()
	shape_owner_set_disabled(_shape_owner, true)
	refresh_visibility()


## Ẩn/hiện tên và nhân vật tùy người đang xem là ai.
func refresh_visibility() -> void:
	var viewer_is_seeker: bool = game != null and game.local_role() == "seeker"
	if not alive:
		visible = is_multiplayer_authority()   # chỉ mình thấy bóng ma của mình
		modulate.a = 0.35
	name_label.visible = alive and not (disguise != "" and viewer_is_seeker)
	if disguise != "":
		name_label.position.y = -_disguise_half_height() - 30.0
	else:
		name_label.position.y = -BODY_RADIUS - 34.0


func _disguise_half_height() -> float:
	var ext := PropTypes.get_extent(disguise)
	var sideways := absf(sin(disguise_rot)) > 0.5
	return (ext.x if sideways else ext.y) / 2.0


func _update_shape() -> void:
	if _shape_owner == -1:
		return
	shape_owner_clear_shapes(_shape_owner)
	var shape: Shape2D
	if disguise == "":
		var c := CircleShape2D.new()
		c.radius = BODY_RADIUS - 2.0
		shape = c
	else:
		shape = PropTypes.make_shape(disguise, 2.0)
	shape_owner_add_shape(_shape_owner, shape)
	shape_owner_set_transform(_shape_owner, Transform2D(disguise_rot, Vector2.ZERO))


# ---------------------------------------------------------------- Vẽ

func _draw() -> void:
	if _is_highlighted_for_observer():
		# Viền sáng nhấp nháy quanh đồng đội khi đang dùng camera quan sát.
		var ext := PropTypes.get_extent(disguise) if disguise != "" else Vector2.ONE * BODY_RADIUS * 2.0
		var r := maxf(ext.x, ext.y) / 2.0 + 10.0
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)
		draw_circle(Vector2.ZERO, r, Color(0.3, 0.85, 1.0, 0.18 * pulse))
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.95 * pulse), 3.0)
	if disguise != "":
		# Lúc vừa biến thân: đồ vật nảy từ nhỏ lên to rồi hơi bật lại.
		var pk := 1.0 - _pop / POP_TIME
		var sc := 1.0 if _pop <= 0.0 else 0.5 + 0.5 * pk + 0.15 * sin(pk * PI)
		draw_set_transform(Vector2.ZERO, disguise_rot, Vector2(sc, sc))
		PropTypes.draw(self, disguise)
		draw_set_transform(Vector2.ZERO, 0.0)
		if is_multiplayer_authority():
			# Chấm nhỏ chỉ mình thấy, để biết đồ vật nào là mình.
			draw_circle(Vector2.ZERO, 3.5, Color(1, 1, 1, 0.8))
		_draw_hider_hp()
		return

	if is_multiplayer_authority() and is_seeker() and alive and can_move:
		var rng: float = Rules.WEAPONS[weapon]["range"]
		if weapon == "hammer":
			draw_arc(Vector2.ZERO, rng, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0)
		else:
			# Đường ngắm mờ (chỉ mình thấy)
			var spread := deg_to_rad(Rules.WEAPONS[weapon]["spread"]) / 2.0
			var aim_len := minf(rng, (get_global_mouse_position() - position).length())
			draw_line(_facing * 26.0, _facing * aim_len, Color(1, 1, 1, 0.18), 1.5)
			if spread > 0.05:
				draw_line(_facing * 26.0, _facing.rotated(spread) * minf(rng, 260.0), Color(1, 1, 1, 0.1), 1.0)
				draw_line(_facing * 26.0, _facing.rotated(-spread) * minf(rng, 260.0), Color(1, 1, 1, 0.1), 1.0)

	var col := SEEKER_COLOR if is_seeker() else HIDER_COLOR
	draw_circle(Vector2(3, 4), BODY_RADIUS, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, BODY_RADIUS, col.darkened(0.45))
	draw_circle(Vector2.ZERO, BODY_RADIUS - 2.5, col)
	var side := _facing.orthogonal() * 5.5
	var front := _facing * 6.0
	for s in [-1.0, 1.0]:
		var eye: Vector2 = front + side * s
		draw_circle(eye, 3.8, Color.WHITE)
		draw_circle(eye + _facing * 1.5, 1.9, Color(0.1, 0.1, 0.15))

	if is_seeker() and alive:
		_draw_weapon()
		# Thanh máu
		var w := 38.0
		var y := -BODY_RADIUS - 12.0
		draw_rect(Rect2(-w / 2.0, y, w, 5), Color(0, 0, 0, 0.6))
		var ratio := clampf(float(hp) / Rules.SEEKER_MAX_HP, 0.0, 1.0)
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 5), Color("#5ee35e").lerp(Color("#ff4040"), 1.0 - ratio))


## Vẽ vũ khí đang cầm, hướng theo chỗ nhắm.
func _draw_weapon() -> void:
	draw_set_transform(Vector2.ZERO, _facing.angle())
	var dark := Color("#2b2d31")
	var metal := Color("#5d636b")
	var wood := Color("#7a4e2d")
	match weapon:
		"hammer":
			draw_line(Vector2(BODY_RADIUS - 2, 8), Vector2(BODY_RADIUS + 16, 8), wood, 4.0)
			draw_rect(Rect2(BODY_RADIUS + 12, 1, 9, 14), Color("#9aa3ad"))
			draw_rect(Rect2(BODY_RADIUS + 12, 1, 9, 14), dark, false, 1.5)
		"pistol":
			draw_rect(Rect2(BODY_RADIUS - 4, 3, 18, 7), dark)
			draw_rect(Rect2(BODY_RADIUS - 2, 5, 4, 8), dark)
		"rifle":
			draw_rect(Rect2(BODY_RADIUS - 10, 2, 12, 8), wood)
			draw_rect(Rect2(BODY_RADIUS, 3, 26, 6), dark)
			draw_rect(Rect2(BODY_RADIUS + 6, 9, 5, 6), metal)
		"shotgun":
			draw_rect(Rect2(BODY_RADIUS - 10, 1, 13, 10), wood)
			draw_rect(Rect2(BODY_RADIUS + 2, 2, 24, 8), metal)
			draw_rect(Rect2(BODY_RADIUS + 8, 3, 12, 6), wood.lightened(0.15))
	draw_set_transform(Vector2.ZERO, 0.0)


## Thanh máu của người trốn: chỉ người trốn (mình và đồng đội) nhìn thấy, người tìm không thấy.
func _draw_hider_hp() -> void:
	if role != "hider" or not alive or hp >= Rules.HIDER_MAX_HP or game == null:
		return
	if game.local_role() == "seeker":
		return
	var w := 40.0
	var y := -_disguise_half_height() - 12.0 if disguise != "" else -BODY_RADIUS - 12.0
	var ratio := clampf(float(hp) / Rules.HIDER_MAX_HP, 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0, y, w * ratio, 5), Color("#5ec8ff").lerp(Color("#ff4040"), 1.0 - ratio))
