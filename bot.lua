
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")
local os = require("os")
local io = require("io")

local token = "953062624:AAHSr4IHh7hLeZiDk4NVJYPrqSK1ZLwcn2M"
local api = "https://api.telegram.org/bot" .. token

-- معرفات الأدمن
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

-- تابع لإرسال رسالة
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

-- تابع لتحميل فيديو
function download_video(url, filename)
    os.execute("youtube-dl -f mp4 -o " .. filename .. " " .. url)
end

-- تابع للتحقق من الأدمن
function is_admin(user_id)
    for _, id in ipairs(admins) do
        if id == user_id then return true end
    end
    return false
end

-- تابع لتحميل قائمة الأعضاء
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

-- تابع لحفظ عضو جديد
function save_user(user_id)
    local users = load_users()
    if not users[user_id] then
        local file = io.open(users_file, "a")
        file:write(user_id .. "\n")
        file:close()
        return true -- مستخدم جديد
    end
    return false -- مستخدم قديم
end

-- حلقة رئيسية
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
                    send_message(chat_id, "جاري تحميل الفيديو...")
                    local filename = "video.mp4"
                    download_video(text, filename)
                    send_video(chat_id, filename)
                    send_message(chat_id, "✅ تم الإرسال!")
                end
            end
        end
    end

    os.execute("sleep 1")
end
