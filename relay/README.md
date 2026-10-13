# Máy chủ chuyển tiếp — Trốn Tìm Hóa Trang

Chỉ cần Node.js 18 trở lên, không cần cài thư viện nào.

    node server.js            # chạy ở cổng 8080 (hoặc biến môi trường PORT)

Mở http://localhost:8080 sẽ thấy dòng "Tron Tim relay OK".
Trong game, đặt RELAY_URL trong scripts/online_config.gd thành địa chỉ máy chủ,
ví dụ "wss://ten-cua-ban.onrender.com" (dùng wss:// khi máy chủ có https).
