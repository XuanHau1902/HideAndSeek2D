extends Node2D
## Màn chơi. Máy chủ (chủ phòng) quyết định mọi luật: giai đoạn, trúng đòn, thắng thua.
## Các máy khác chỉ gửi yêu cầu (ví dụ "tôi đánh vào điểm này") và nhận kết quả.

const Rules = preload("res://scripts/game_rules.gd")
const PropTypes = preload("res://scripts/prop_types.gd")
const PlayerScene = preload("res://scenes/player.tscn")
const HitEffect = preload("res://scripts/hit_effect.gd")
const ShotEffect = preload("res://scripts/shot_effect.gd")
const DamageNumber = preload("res://scripts/damage_number.gd")

enum Phase { LOADING, HIDING, HUNTING, ENDED }

var phase: int = Phase.LOADING
var time_left := 0.0
## peer_id -> Player
var players: Dictionary = {}
var total_hiders := 0

var _last_attack: Dictionary = {}   # chỉ dùng trên máy chủ
var _morph_count := 0               # số lần đã ép biến hình trong ván (máy chủ)
var _warned_morph := -1             # lần biến hình đã báo trước (mỗi máy)
var _shotgun_announced := false
var _last_tick := -1                # giây cuối cùng đã phát tiếng tích tắc
var _highlighted_prop: Node2D = null

@onready var floor_node: Node2D = $Floors/Grass
@onready var props_root: Node2D = $Props
@onready var players_root: Node2D = $Players
@onready var effects_root: Node2D = $Effects
@onready var hud = $HUD


func _ready() -> void:
	Network.player_left.connect(_on_player_left)
	_spawn_players()
	_update_hud()
	Network.notify_loaded()


func _spawn_players() -> void:
	var roles: Dictionary = Network.game_config.get("roles", {})
	var ids: Array = roles.keys()
	ids.sort()
	var hider_spawns := $SpawnPoints/Hiders.get_children()
	var seeker_spawns := $SpawnPoints/Seekers.get_children()
	var map_rect := Rect2(Vector2.ZERO, floor_node.size)
	var hi := 0
	var si := 0
	for id in ids:
		if not Network.players.has(id):
			continue
		var role: String = roles[id]
		var spawn: Node2D
		if role == "seeker":
			spawn = seeker_spawns[si % seeker_spawns.size()]
			si += 1
		else:
			spawn = hider_spawns[hi % hider_spawns.size()]
			hi += 1
			total_hiders += 1
		var p := PlayerScene.instantiate()
		p.setup(id, Network.players[id]["name"], role, spawn.global_position, self, map_rect)
		players_root.add_child(p)
		players[id] = p


func local_player() -> Node:
	return players.get(multiplayer.get_unique_id())


func local_role() -> String:
	var p := local_player()
	return p.role if p else ""


# ---------------------------------------------------------------- Giai đoạn

## Network gọi trên máy chủ mỗi khi có máy tải xong màn chơi.
func on_peer_loaded() -> void:
	if multiplayer.is_server() and phase == Phase.LOADING and Network.all_loaded():
		_set_phase.rpc(Phase.HIDING, Rules.HIDE_TIME)


@rpc("authority", "call_local", "reliable")
func _set_phase(new_phase: int, duration: float) -> void:
	phase = new_phase
	time_left = duration
	for p in players.values():
		p.net_ready = true
		p.can_move = new_phase == Phase.HUNTING or (new_phase == Phase.HIDING and p.role == "hider")
	var me := local_player()
	if new_phase == Phase.HIDING:
		Sfx.play("select")
		if me and me.role == "hider":
			hud.show_message("Chạy đi trốn! Đứng gần đồ vật và bấm E để hóa trang.", Color("#9fd3ff"))
	elif new_phase == Phase.HUNTING:
		Sfx.play("round_start")
		if me and me.role == "seeker":
			hud.show_message("Đi tìm thôi! Phím 1-3 đổi vũ khí, click chuột để đánh/bắn đồ vật khả nghi.", Color("#ffb3a8"))
		else:
			hud.show_message("Người tìm đã được thả! Đứng yên cho giống đồ vật...", Color("#9fd3ff"))
	_update_hud()


func _process(delta: float) -> void:
	if phase == Phase.HIDING or phase == Phase.HUNTING:
		time_left = maxf(0.0, time_left - delta)
		if multiplayer.is_server() and time_left <= 0.0:
			if phase == Phase.HIDING:
				_set_phase.rpc(Phase.HUNTING, Rules.HUNT_TIME)
				_morph_hiders(true)   # ai còn là hình người thì biến thành đồ vật luôn
			else:
				_end_game("hiders")
	if phase == Phase.HUNTING:
		_update_morph()
		if shotgun_unlocked() and not _shotgun_announced:
			_shotgun_announced = true
			_on_shotgun_unlocked()
	_update_countdown_sound()
	_update_prop_highlight()
	_update_hud()


## Tích tắc ở 5 giây cuối giờ ẩn nấp và 10 giây cuối trận.
func _update_countdown_sound() -> void:
	var sec := ceili(time_left)
	if sec == _last_tick:
		return
	_last_tick = sec
	if phase == Phase.HIDING and sec <= 5 and sec > 0:
		Sfx.play("tick")
	elif phase == Phase.HUNTING and sec <= 10 and sec > 0:
		Sfx.play("tick_high")


func _update_prop_highlight() -> void:
	var me := local_player()
	var target: Node2D = null
	if me and me.role == "hider" and me.alive and me.can_move and not me.observing:
		target = find_nearest_prop(me.position, Rules.DISGUISE_RANGE)
	if target != _highlighted_prop:
		if is_instance_valid(_highlighted_prop):
			_highlighted_prop.highlighted = false
		_highlighted_prop = target
		if target:
			target.highlighted = true


# ---------------------------------------------------------------- Ép biến hình

## Số giây còn lại tới lần biến hình kế tiếp (-1 nếu tắt hoặc không trong giai đoạn đi tìm).
func time_to_morph() -> float:
	if Rules.MORPH_INTERVAL <= 0.0 or phase != Phase.HUNTING:
		return -1.0
	var elapsed := Rules.HUNT_TIME - time_left
	var next_at: float = (floor(elapsed / Rules.MORPH_INTERVAL) + 1.0) * Rules.MORPH_INTERVAL
	if next_at >= Rules.HUNT_TIME:
		return -1.0   # không biến hình khi trận đã sắp hết giờ
	return next_at - elapsed


func _update_morph() -> void:
	if Rules.MORPH_INTERVAL <= 0.0:
		return
	var elapsed := Rules.HUNT_TIME - time_left
	var count := int(floor(elapsed / Rules.MORPH_INTERVAL))
	# Báo trước cho người trốn trên máy này.
	var t := time_to_morph()
	var me := local_player()
	if t > 0.0 and t <= Rules.MORPH_WARNING and _warned_morph != count:
		_warned_morph = count
		if me and me.role == "hider" and me.alive:
			hud.show_message("Cẩn thận! %d giây nữa bạn sẽ bị biến thành đồ vật ngẫu nhiên!" % ceili(t), Color("#ffd166"))
			Sfx.play("warning")
	# Máy chủ thực hiện biến hình.
	if multiplayer.is_server() and count > _morph_count:
		_morph_count = count
		_morph_hiders(false)


## Máy chủ: gửi cho từng người trốn còn sống một danh sách loại đồ vật đã xáo trộn.
func _morph_hiders(only_human: bool) -> void:
	if not multiplayer.is_server():
		return
	var any := false
	for p in players.values():
		if p.role != "hider" or not p.alive:
			continue
		if only_human and p.disguise != "":
			continue
		var types: Array = PropTypes.TYPES.keys()
		types.shuffle()
		_force_morph.rpc_id(p.peer_id, types)
		any = true
	if any and not only_human:
		_announce_morph.rpc()


@rpc("authority", "call_local", "reliable")
func _force_morph(candidates: Array) -> void:
	var me := local_player()
	if me:
		me.force_random_disguise(candidates)


@rpc("authority", "call_local", "reliable")
func _announce_morph() -> void:
	Sfx.play("morph_all")
	var me := local_player()
	if me and me.role == "hider" and me.alive:
		hud.show_message("Bạn đã bị biến thành %s! Mau tìm chỗ hợp lý mà núp." % PropTypes.get_data(me.disguise)["name"], Color("#ffd166"))
	else:
		hud.show_message("Người trốn vừa bị biến thành đồ vật ngẫu nhiên! Tìm món nào trông lạc chỗ...", Color("#ffe066"))


## Danh sách người trốn còn sống (trừ một người), sắp theo tên cho ổn định.
func alive_hiders_except(id: int) -> Array:
	var result: Array = []
	for p in players.values():
		if p.role == "hider" and p.alive and p.peer_id != id:
			result.append(p)
	result.sort_custom(func(a, b): return a.player_name < b.player_name)
	return result


func find_nearest_prop(from: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for prop in props_root.get_children():
		if prop.broken:
			continue
		var d := from.distance_to(prop.global_position)
		if d <= best_d:
			best_d = d
			best = prop
	return best


# ---------------------------------------------------------------- Vũ khí & bắn

func _on_shotgun_unlocked() -> void:
	Sfx.play("shotgun_unlock")
	var me := local_player()
	if me == null:
		return
	if me.role == "seeker" and me.alive:
		me.select_weapon("shotgun")
		hud.show_message("%d GIÂY CUỐI! Đã mở khóa SHOTGUN (phím 4)" % int(Rules.SHOTGUN_UNLOCK_TIME), Color("#ff9f43"))
	else:
		hud.show_message("%d giây cuối! Người tìm đã có SHOTGUN, cẩn thận!" % int(Rules.SHOTGUN_UNLOCK_TIME), Color("#ff9f43"))


func shotgun_unlocked() -> bool:
	return phase == Phase.HUNTING and time_left <= Rules.SHOTGUN_UNLOCK_TIME


## Người tìm trên máy này dùng vũ khí, nhắm vào điểm aim (tọa độ thế giới).
func local_attack(weapon: String, aim: Vector2) -> void:
	if phase != Phase.HUNTING:
		return
	if multiplayer.is_server():
		_handle_attack(1, weapon, aim)
	else:
		_request_attack.rpc_id(1, weapon, aim)


@rpc("any_peer", "call_remote", "reliable")
func _request_attack(weapon: String, aim: Vector2) -> void:
	if multiplayer.is_server():
		_handle_attack(multiplayer.get_remote_sender_id(), weapon, aim)


## Máy chủ xử lý một phát đánh/bắn.
func _handle_attack(attacker_id: int, weapon: String, aim: Vector2) -> void:
	if phase != Phase.HUNTING or not Rules.WEAPONS.has(weapon):
		return
	if weapon == "shotgun" and time_left > Rules.SHOTGUN_UNLOCK_TIME + 1.0:
		return
	var seeker = players.get(attacker_id)
	if seeker == null or not seeker.alive or seeker.role != "seeker":
		return
	var w: Dictionary = Rules.WEAPONS[weapon]
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_attack.get(attacker_id, -100.0) < w["cooldown"] * 0.8:
		return
	_last_attack[attacker_id] = now
	var origin: Vector2 = seeker.get_net_position()

	if weapon == "hammer":
		_hammer_hit(seeker, w, origin, aim)
		return

	# Súng: bắn từng viên theo đường thẳng, có độ tỏa.
	var base_dir := (aim - origin).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var hit_hiders := {}       # người trốn bị trúng trong phát này (mỗi người chỉ tính 1 lần)
	var wrong_hits := 0
	var ends := PackedVector2Array()
	var kinds := PackedInt32Array()
	for i in int(w["pellets"]):
		var ang := deg_to_rad(randf_range(-w["spread"], w["spread"]) / 2.0)
		var dir := base_dir.rotated(ang)
		var result := _trace(origin + dir * 20.0, dir, w["range"])
		ends.append(result["point"])
		kinds.append(result["kind"])
		match result["kind"]:
			2:
				hit_hiders[result["hider"].peer_id] = result["point"]
			1:
				wrong_hits += 1
				_bump_prop.rpc(String(result["prop"].name), attacker_id, w["miss_penalty"])
	_show_shot.rpc(origin + base_dir * 22.0, ends, kinds, weapon)
	for id in hit_hiders:
		_damage_hider(players[id], w["damage"], attacker_id, hit_hiders[id])
	if wrong_hits > 0:
		_penalize(seeker, wrong_hits * int(w["miss_penalty"]))


func _hammer_hit(seeker, w: Dictionary, origin: Vector2, aim: Vector2) -> void:
	var target := origin + (aim - origin).limit_length(w["range"])
	_play_sfx.rpc("hammer_swing", origin)
	for p in players.values():
		if p.role == "hider" and p.alive and p.contains_point(target):
			_show_hit.rpc(target, 0)
			_damage_hider(p, w["damage"], seeker.peer_id, target)
			return
	for prop in props_root.get_children():
		if prop.contains_point(target):
			_show_hit.rpc(target, 1)
			_bump_prop.rpc(String(prop.name), seeker.peer_id, w["miss_penalty"])
			_penalize(seeker, int(w["miss_penalty"]))
			return
	_show_hit.rpc(target, 0)


## Dò đường đạn: trả về điểm dừng và trúng gì (0 = tường/khoảng không, 1 = đồ vật thật, 2 = người trốn).
func _trace(from: Vector2, dir: Vector2, length: float) -> Dictionary:
	var to := from + dir * length
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var block_dist := length
	var collider: Object = null
	if not hit.is_empty():
		block_dist = from.distance_to(hit["position"])
		collider = hit["collider"]
	# Người trốn không nằm trong lớp va chạm của đạn, nên kiểm tra riêng bằng hình học.
	var best_d := block_dist
	var best_hider = null
	for p in players.values():
		if p.role != "hider" or not p.alive:
			continue
		var c: Vector2 = p.get_net_position()
		var ext := PropTypes.get_extent(p.disguise) if p.disguise != "" else Vector2.ONE * 32.0
		var bound := maxf(ext.x, ext.y) * 0.75 + 4.0
		var along := (c - from).dot(dir)
		if along < -bound or along > best_d + bound:
			continue
		if (from + dir * along).distance_to(c) > bound:
			continue
		var t := maxf(0.0, along - bound)
		var t_end := minf(best_d, along + bound)
		while t <= t_end:
			if p.contains_point(from + dir * t):
				if t < best_d:
					best_d = t
					best_hider = p
				break
			t += 5.0
	if best_hider != null:
		return {"kind": 2, "point": from + dir * best_d, "hider": best_hider}
	var point := from + dir * block_dist
	if collider != null and collider.has_method("bump"):
		return {"kind": 1, "point": point, "prop": collider}
	return {"kind": 0, "point": point}


func _damage_hider(p, damage: int, attacker_id: int, at: Vector2) -> void:
	if not p.alive:
		return
	var new_hp: int = maxi(0, p.hp - damage)
	_sync_hp.rpc(p.peer_id, new_hp)
	_show_damage.rpc(at, damage, true)
	if new_hp <= 0:
		_show_hit.rpc(p.get_net_position(), 2)
		_eliminate.rpc(p.peer_id, attacker_id)
		var seeker = players.get(attacker_id)
		if seeker and seeker.alive:
			_sync_hp.rpc(attacker_id, mini(Rules.SEEKER_MAX_HP, seeker.hp + Rules.HIT_REWARD))
		_check_win()


func _penalize(seeker, amount: int) -> void:
	if amount <= 0 or not seeker.alive:
		return
	var new_hp: int = maxi(0, seeker.hp - amount)
	_sync_hp.rpc(seeker.peer_id, new_hp)
	if new_hp <= 0:
		_eliminate.rpc(seeker.peer_id, 0)
		_check_win()


@rpc("authority", "call_local", "reliable")
func _eliminate(id: int, by_id: int) -> void:
	var p = players.get(id)
	if p == null or not p.alive:
		return
	p.set_dead()
	if by_id == 0:
		hud.show_message("%s đã kiệt sức vì bắn nhầm quá nhiều đồ thật!" % p.player_name, Color("#ffb3a8"))
	else:
		var by_name: String = players[by_id].player_name if players.has(by_id) else "?"
		hud.show_message("%s đã hạ gục %s!" % [by_name, p.player_name], Color("#ffe066"))
	if id == multiplayer.get_unique_id():
		hud.show_message("Bạn đã bị loại. Giờ bạn là bóng ma, bay đi xem mọi người nhé.", Color("#cccccc"))


@rpc("authority", "call_local", "reliable")
func _sync_hp(id: int, new_hp: int) -> void:
	var p = players.get(id)
	if p:
		var old_hp: int = p.hp
		p.hp = new_hp
		if id == multiplayer.get_unique_id() and p.role == "hider" and new_hp < old_hp and new_hp > 0:
			hud.show_message("Bạn bị trúng đòn! -%d máu (còn %d). Mau đổi chỗ trốn!" % [old_hp - new_hp, new_hp], Color("#ff8a80"))


@rpc("authority", "call_local", "reliable")
func _bump_prop(prop_name: String, attacker_id: int, penalty: int) -> void:
	var prop := props_root.get_node_or_null(prop_name)
	if prop:
		prop.bump()
	if attacker_id == multiplayer.get_unique_id() and penalty > 0:
		_show_damage(prop.global_position if prop else Vector2.ZERO, penalty, false)


@rpc("authority", "call_local", "unreliable")
func _play_sfx(sound: String, pos: Vector2) -> void:
	Sfx.play_at(sound, pos)


@rpc("authority", "call_local", "unreliable")
func _show_hit(pos: Vector2, kind: int) -> void:
	if kind == 1:
		Sfx.play_at("prop_thunk", pos)
	elif kind == 2:
		Sfx.play_at("eliminated", pos)
	var fx := HitEffect.new()
	fx.kind = kind
	fx.position = pos
	effects_root.add_child(fx)


@rpc("authority", "call_local", "unreliable")
func _show_shot(origin: Vector2, ends: PackedVector2Array, kinds: PackedInt32Array, weapon: String) -> void:
	var fx := ShotEffect.new()
	fx.origin = origin
	fx.ends = ends
	fx.kinds = kinds
	fx.weapon = weapon
	effects_root.add_child(fx)
	Sfx.play_at(weapon, origin)
	# Tiếng đạn chạm (tối đa vài tiếng cho shotgun để đỡ ồn)
	var played := 0
	var thunk := false
	for i in ends.size():
		if kinds[i] == 1 and not thunk:
			thunk = true
			Sfx.play_at("prop_thunk", ends[i])
		elif kinds[i] == 0 and played < 2:
			played += 1
			Sfx.play_at("impact", ends[i])


## Số bay lên: trúng người trốn (vàng) hoặc người tìm bị trừ máu vì bắn nhầm (đỏ, chỉ người đó thấy).
@rpc("authority", "call_local", "unreliable")
func _show_damage(pos: Vector2, amount: int, on_hider: bool) -> void:
	var fx := DamageNumber.new()
	fx.text = "-%d" % amount if on_hider else "Đồ thật! -%d máu" % amount
	fx.color = Color("#ffe066") if on_hider else Color("#ff6b6b")
	fx.position = pos + Vector2(0, -20)
	effects_root.add_child(fx)
	if on_hider:
		Sfx.play_at("hider_hit", pos)
	else:
		Sfx.play("wrong")


# ---------------------------------------------------------------- Thắng thua

func _count_alive(role: String) -> int:
	var n := 0
	for p in players.values():
		if p.role == role and p.alive:
			n += 1
	return n


func _check_win() -> void:
	if not multiplayer.is_server() or phase == Phase.ENDED or phase == Phase.LOADING:
		return
	if _count_alive("hider") == 0:
		_end_game("seekers")
	elif _count_alive("seeker") == 0:
		_end_game("hiders")


func _end_game(winner: String) -> void:
	if phase == Phase.ENDED:
		return
	_game_over.rpc(winner)
	get_tree().create_timer(Rules.END_SCREEN_TIME).timeout.connect(Network.return_to_lobby)


@rpc("authority", "call_local", "reliable")
func _game_over(winner: String) -> void:
	phase = Phase.ENDED
	time_left = 0.0
	for p in players.values():
		p.can_move = false
		p.net_ready = false   # ngừng gửi vị trí, tránh gói tin đến muộn sau khi đổi cảnh
		p.stop_observing()
	var me := local_player()
	var i_won: bool = me != null and ((winner == "seekers") == (me.role == "seeker"))
	var title := "NGƯỜI TÌM THẮNG!" if winner == "seekers" else "NGƯỜI TRỐN THẮNG!"
	var sub := "Bạn thắng rồi!" if i_won else "Bạn thua mất rồi..."
	hud.show_end("%s\n%s" % [title, sub], Color("#ffe066") if i_won else Color("#ff8a80"))
	Sfx.play("win" if i_won else "lose")
	_update_hud()


func _on_player_left(id: int) -> void:
	var p = players.get(id)
	if p == null:
		return
	var leaver_name: String = p.player_name
	players.erase(id)
	p.queue_free()
	hud.show_message("%s đã rời phòng." % leaver_name, Color("#cccccc"))
	if multiplayer.is_server():
		if phase == Phase.LOADING:
			on_peer_loaded()
		else:
			_check_win()


# ---------------------------------------------------------------- Giao diện

func _update_hud() -> void:
	var me := local_player()
	var t := int(ceil(time_left))
	var clock := "%d:%02d" % [t / 60, t % 60]
	match phase:
		Phase.LOADING:
			hud.top_label.text = "Đang chờ mọi người vào trận..."
		Phase.HIDING:
			hud.top_label.text = "Thời gian ẩn nấp  %s" % clock
		Phase.HUNTING:
			hud.top_label.text = "Đi tìm  %s" % clock
		Phase.ENDED:
			hud.top_label.text = "Kết thúc"

	hud.info_label.text = "Người trốn còn lại: %d/%d\nNgười tìm: %d" % [
		_count_alive("hider"), total_hiders, _count_alive("seeker")]
	var tm := time_to_morph()
	if tm >= 0.0:
		hud.info_label.text += "\nBiến hình ngẫu nhiên sau: %ds" % ceili(tm)

	if me == null:
		hud.role_label.text = ""
	elif not me.alive:
		hud.role_label.text = "Bạn đã bị loại — WASD: bay xem trận đấu"
	elif me.role == "seeker":
		var parts: PackedStringArray = []
		for wid in Rules.WEAPON_ORDER:
			var wd: Dictionary = Rules.WEAPONS[wid]
			var label := "[%d] %s" % [wd["key"], wd["name"]]
			if wid == "shotgun" and not shotgun_unlocked():
				label += " (khóa)"
			parts.append(label.to_upper() if wid == me.weapon else label)
		var cw: Dictionary = Rules.WEAPONS[me.weapon]
		var miss_text: String = "trúng nhầm đồ thật: không mất máu" if cw["miss_penalty"] == 0 \
			else "trúng nhầm đồ thật: -%d máu cho bạn" % cw["miss_penalty"]
		hud.role_label.text = "NGƯỜI TÌM  ·  Máu: %d/%d  ·  %s\n%s: trúng người trốn -%d máu cho họ  ·  %s%s" % [
			me.hp, Rules.SEEKER_MAX_HP, "   ".join(parts), cw["name"], cw["damage"], miss_text,
			"  ·  giữ chuột để bắn liên tục" if cw["auto"] else ""]
	elif me.observing:
		var follow: String = me.observe_target.player_name if me.observe_target else "camera tự do"
		hud.role_label.text = "CAMERA QUAN SÁT (%s)  ·  Thân bạn vẫn đứng yên tại chỗ và có thể bị đánh!\nWASD: lia camera  ·  Lăn chuột: phóng to/thu nhỏ  ·  Tab: theo dõi người trốn tiếp theo  ·  F: quay về" % follow
	else:
		var form: String = "hình người" if me.disguise == "" else PropTypes.get_data(me.disguise)["name"]
		hud.role_label.text = "Bạn là NGƯỜI TRỐN  ·  Máu: %d/%d  ·  Đang là: %s\nWASD: di chuyển  ·  E: hóa thành đồ vật gần nhất (viền vàng)  ·  R: xoay  ·  F: camera quan sát" % [me.hp, Rules.HIDER_MAX_HP, form]

	var blind_on: bool = phase == Phase.HIDING and me != null and me.role == "seeker"
	hud.set_blind(blind_on, "Bạn là NGƯỜI TÌM\n\nNgười trốn đang ẩn nấp...\nBạn sẽ được thả sau %d giây" % t)
