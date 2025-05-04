
تعليمات التشغيل:

1. ثبّت الحزم:
sudo apt update && sudo apt install lua5.3 luarocks curl yt-dlp -y
sudo luarocks install luasec dkjson

2. ضع توكن البوت و ID الادمن داخل bot.lua

3. شغّل:
lua5.3 bot.lua

4. لتشغيل تلقائي بعد الريستارت:
- ضع ملف luabot.service في /etc/systemd/system/
- ثم:
sudo systemctl daemon-reload
sudo systemctl enable luabot
sudo systemctl start luabot
sudo systemctl status luabot
