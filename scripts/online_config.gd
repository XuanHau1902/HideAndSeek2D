extends RefCounted
## Địa chỉ máy chủ chuyển tiếp (relay). Sau khi đưa thư mục relay/ lên Render.com,
## dán địa chỉ vào đây, bắt đầu bằng wss:// (ví dụ "wss://tron-tim-relay.onrender.com").
##
## Để trống "" thì bản cài trên máy chỉ chơi được trong mạng LAN (như trước),
## còn bản web sẽ không vào được phòng nào.
const RELAY_URL := "wss://tron-tim-relay.onrender.com"
