extends RefCounted
## Luật chơi. Muốn chỉnh độ khó, thời gian... thì sửa các con số ở đây.

## Thời gian ẩn nấp (giây): người tìm bị che màn hình và đứng yên.
const HIDE_TIME := 20.0
## Thời gian đi tìm (giây). Hết giờ mà còn người trốn thì người trốn thắng.
const HUNT_TIME := 180.0
## Thời gian hiện màn hình kết quả trước khi quay về phòng chờ.
const END_SCREEN_TIME := 6.0

## Máu tối đa của người tìm và người trốn.
const SEEKER_MAX_HP := 100
const HIDER_MAX_HP := 100
## Hạ gục được một người trốn thì người tìm hồi bao nhiêu máu.
const HIT_REWARD := 25

## Vũ khí của người tìm.
##   damage       : người trốn bị trúng mất bao nhiêu máu
##   miss_penalty : người tìm mất bao nhiêu máu cho MỖI viên/nhát trúng nhầm đồ vật thật
##                  (trúng tường hay khoảng trống thì không mất)
##   cooldown     : thời gian giữa 2 phát (giây)
##   range        : tầm (pixel)
##   spread       : độ tỏa đạn (độ)
##   pellets      : số viên mỗi phát (shotgun bắn chùm)
##   auto         : giữ chuột để bắn liên tục
## Shotgun: mỗi phát chỉ gây "damage" một lần cho mỗi người trốn bị trúng (không cộng dồn theo số viên).
const WEAPONS := {
	"hammer": {"name": "Búa", "key": 1, "damage": 5, "miss_penalty": 0, "cooldown": 0.45, "range": 110.0, "spread": 0.0, "pellets": 1, "auto": false},
	"pistol": {"name": "Súng lục", "key": 2, "damage": 10, "miss_penalty": 1, "cooldown": 0.35, "range": 650.0, "spread": 2.0, "pellets": 1, "auto": false},
	"rifle": {"name": "Súng trường", "key": 3, "damage": 15, "miss_penalty": 2, "cooldown": 0.13, "range": 950.0, "spread": 4.0, "pellets": 1, "auto": true},
	"shotgun": {"name": "Shotgun", "key": 4, "damage": 20, "miss_penalty": 0, "cooldown": 0.85, "range": 420.0, "spread": 24.0, "pellets": 7, "auto": false},
}
const WEAPON_ORDER := ["hammer", "pistol", "rifle", "shotgun"]
## Shotgun chỉ dùng được trong bấy nhiêu giây cuối của trận.
const SHOTGUN_UNLOCK_TIME := 30.0

## Cứ mỗi MORPH_INTERVAL giây trong giai đoạn đi tìm, mọi người trốn còn sống
## bị biến thành một đồ vật NGẪU NHIÊN khác (thường lạc lõng với căn phòng -> dễ bị phát hiện).
## Đặt 0 để tắt.
const MORPH_INTERVAL := 30.0
## Người trốn được báo trước bao nhiêu giây.
const MORPH_WARNING := 5.0

## Làn khói biến thân có hiện cho người tìm thấy không.
## true: người tìm thấy khói -> đổi hình là có thể bị lộ vị trí. false: chỉ người trốn thấy.
const SMOKE_VISIBLE_TO_SEEKERS := true

## Người trốn phải đứng cách đồ vật tối đa bao xa thì mới hóa trang được.
const DISGUISE_RANGE := 90.0

