
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")
local os = require("os")
local io = require("io")

-- إعداد التوكن ومسار API
local token = "953062624:AAHSr4IHh7hLeZiDk4NVJYPrqSK1ZLwcn2M"
local api = "https://api.telegram.org/bot" .. token

-- معرف الأدمن
local admins = {426795071}

-- مسار ملف الأعضاء
local users_file = "users.txt"

-- تابع لجلب التحديثات
function get_updates(offset)
    local resp = {}
    https.request{
        url = api .. "/getUpdates?timeout=60&offset=" .. offset,
        sink = ltn12.sink.table(resp)
    }
    return table.concat(resp)
end

-- تابع لإرسال رسالة نصية
function send_message(chat_id, text)
    https.request(api .. "/sendMessage?chat_id=" .. chat_id .. "&text=" .. text)
end

-- تابع لإرسال فيديو
function send_video(chat_id, filename)
    os.execute(string.format(
        'curl -F chat_id=%s -F video=@%s %s/sendVideo',
        chat_id, filename, api
    ))
end

-- تابع لإرسال صوت
function send_audio(chat_id, filename)
    os.execute(string.format(
        'curl -F chat_id=%s -F audio=@%s %s/sendAudio',
        chat_id, filename, api
    ))
end

-- تابع لتحميل الفيديو أو الصوت باستخدام yt-dlp
function download_media(url, format, output)
    local cmd
    if format == "video" then
        cmd = string.format("yt-dlp -f mp4 -o %s %s", output, url)
    else
        cmd = string.format("yt-dlp --extract-audio --audio-format mp3 -o %s %s", output, url)
    end
    return os.execute(cmd)
end

-- تابع للتحقق من الأدمن
function is_admin(user_id)
    for _, id in ipairs(admins) do
        if id == user_id then return true end
    end
    return false
end

-- تحميل قائمة الأعضاء من الملف
function load_users()
    local users = {}
    local file = io.open(users_file, "r")
    if file then
        for line in file:lines() do
            users[tonumber(line)] = true
        end
        file:close()
    end
    return users
end

-- حفظ عضو جديد في الملف
function save_user(user_id)
    local users = load_users()
    if not users[user_id] then
        local file = io.open(users_file, "a")
        file:write(user_id .. "\n")
        file:close()
        return true
    end
    return false
end

-- الحلقة الرئيسية للمعالجة
local last_update = 0

while true do
    local body = get_updates(last_update + 1)
    local data = json.decode(body)

    if data and data.result then
        for _, update in ipairs(data.result) do
            last_update = update.update_id
            local msg = update.message
            if msg and msg.text then
                local chat_id = msg.chat.id
                local user_id = msg.from.id
                local text = msg.text

                if text == "/start" then
                    local is_new = save_user(user_id)
                    send_message(chat_id, "أهلاً بيك! أرسل رابط يوتيوب وسأحمله لك.")
                    if is_new then
                        for _, admin_id in ipairs(admins) do
                            send_message(admin_id, "🆕 مستخدم جديد دخل: " .. user_id)
                        end
                    end

                elseif text == "/count" and is_admin(user_id) then
                    local users = load_users()
                    local count = 0
                    for _ in pairs(users) do count = count + 1 end
                    send_message(chat_id, "عدد المستخدمين الحالي: " .. count)

                elseif text:match("^/اذاعة (.+)") and is_admin(user_id) then
                    local broadcast_msg = text:match("^/اذاعة (.+)")
                    local users = load_users()
                    for uid in pairs(users) do
                        send_message(uid, "📢 إذاعة:\n" .. broadcast_msg)
                    end
                    send_message(chat_id, "✅ تمت الإذاعة للجميع.")

                elseif text:match("youtube%.com") or text:match("youtu%.be") then
                    send_message(chat_id, "جاري التحميل...")
                    -- محاولة تحميل فيديو أولاً
                    local video_file = "video.mp4"
                    local status = download_media(text, "video", video_file)
                    if status == 0 and io.open(video_file, "r") then
                        send_video(chat_id, video_file)
                        send_message(chat_id, "✅ تم إرسال الفيديو!")
                    else
                        -- تحميل الصوت إذا فشل تحميل الفيديو
                        local audio_file = "audio.mp3"
                        download_media(text, "audio", audio_file)
                        if io.open(audio_file, "r") then
                            send_audio(chat_id, audio_file)
                            send_message(chat_id, "✅ تم إرسال الصوت!")
                        else
                            send_message(chat_id, "❌ فشل تحميل الوسيط.")
                        end
                    end
                end
            end
        end
    end

    os.execute("sleep 1")
end
