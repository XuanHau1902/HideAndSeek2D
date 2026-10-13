extends Node
## Autoload "Sfx": phát hiệu ứng âm thanh.
##   Sfx.play("click")                  -> âm giao diện (nghe như nhau ở mọi nơi)
##   Sfx.play_at("pistol", vị_trí)      -> âm trong thế giới game: càng xa càng nhỏ, có hướng trái/phải
## Phím M: bật/tắt tiếng.
## File âm thanh nằm trong thư mục res://sounds/ (thay file .wav cùng tên là đổi được tiếng).

const NAMES := [
	"pistol", "rifle", "shotgun", "hammer_swing", "prop_thunk", "impact", "hider_hit", "eliminated",
	"poof", "warning", "morph_all", "tick", "tick_high", "round_start", "weapon_switch",
	"shotgun_unlock", "wrong", "win", "lose", "click", "select", "join", "leave", "step",
]
## Âm lượng riêng cho từng tiếng (dB). Không có trong danh sách = 0 dB.
const VOLUME := {
	"rifle": -3.0, "impact": -8.0, "step": -10.0, "tick": -4.0, "click": -6.0,
	"hammer_swing": -4.0, "morph_all": -3.0,
}
## Độ lệch cao độ ngẫu nhiên để tiếng lặp lại (súng trường, bước chân) đỡ nhàm.
const PITCH_JITTER := {"rifle": 0.06, "pistol": 0.04, "impact": 0.15, "step": 0.12, "prop_thunk": 0.08, "hider_hit": 0.06, "poof": 0.06}

const MAX_DISTANCE := 1500.0
const POOL_SIZE := 24

var muted := false
var _streams := {}
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _next_2d := 0
var _next_ui := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = MAX_DISTANCE
		p.attenuation = 1.6
		add_child(p)
		_pool_2d.append(p)
	for i in 8:
		var u := AudioStreamPlayer.new()
		add_child(u)
		_pool_ui.append(u)
	if not InputMap.has_action("toggle_mute"):
		InputMap.add_action("toggle_mute")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_M
		InputMap.action_add_event("toggle_mute", ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		muted = not muted
		AudioServer.set_bus_mute(0, muted)


func play(sound: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := _pool_ui[_next_ui]
	_next_ui = (_next_ui + 1) % _pool_ui.size()
	p.stream = _streams[sound]
	p.volume_db = VOLUME.get(sound, 0.0) + volume_db
	p.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * PITCH_JITTER.get(sound, 0.0)
	p.play()


func play_at(sound: String, pos: Vector2, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	p.stream = _streams[sound]
	p.global_position = pos
	p.volume_db = VOLUME.get(sound, 0.0) + volume_db
	p.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * PITCH_JITTER.get(sound, 0.0)
	p.play()
