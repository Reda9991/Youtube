
local telegram_bot_token = "953062624:AAHSr4IHh7hLeZiDk4NVJYPrqSK1ZLwcn2M"
local admin_id = "426795071"
local users_file = "users.txt"
local banned_file = "banned.txt"

print("### البوت يعمل الآن... ###")

-- تحميل قائمة من ملف نصي
local function load_list(filename)
    local list = {}
    local file = io.open(filename, "r")
    if file then
        for line in file:lines() do
            list[line] = true
        end
        file:close()
    end
    return list
end

-- إضافة عنصر إلى ملف نصي
local function add_to_file(filename, item)
    local file = io.open(filename, "a")
    file:write(item .. "\n")
    file:close()
end

local users = load_list(users_file)
local banned = load_list(banned_file)

while true do
    local updates = io.popen('curl -s https://api.telegram.org/bot' .. telegram_bot_token .. '/getUpdates'):read("*a")
    local data = require("dkjson").decode(updates)
    if data and data.result then
        for _, update in ipairs(data.result) do
            local msg = update.message
            if msg then
                local user_id = tostring(msg.from.id)
                local text = msg.text

                if banned[user_id] then
                    print("تحذير: مستخدم محظور حاول الدخول - ID: " .. user_id)
                    goto continue
                end

                -- خزن المستخدم الجديد
                if not users[user_id] then
                    users[user_id] = true
                    add_to_file(users_file, user_id)
                    os.execute(string.format(
                        'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="مستخدم جديد دخل: %s"',
                        telegram_bot_token, admin_id, user_id
                    ))
                    print("مستخدم جديد تم تسجيله - ID: " .. user_id)
                end

                -- أوامر الإدمن
                if user_id == admin_id then
                    if text:match("^/broadcast (.+)") then
                        local msg_text = text:match("^/broadcast (.+)")
                        for uid, _ in pairs(users) do
                            os.execute(string.format(
                                'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="%s"',
                                telegram_bot_token, uid, msg_text
                            ))
                        end
                        print("تم إرسال إذاعة لكل المستخدمين.")
                    elseif text:match("^/ban (%d+)") then
                        local ban_id = text:match("^/ban (%d+)")
                        banned[ban_id] = true
                        add_to_file(banned_file, ban_id)
                        os.execute(string.format(
                            'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="تم حظر المستخدم %s"',
                            telegram_bot_token, admin_id, ban_id
                        ))
                        print("تم حظر المستخدم - ID: " .. ban_id)
                    elseif text == "/count" then
                        local count = 0
                        for _ in pairs(users) do count = count + 1 end
                        os.execute(string.format(
                            'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="عدد المستخدمين: %d"',
                            telegram_bot_token, admin_id, count
                        ))
                        print("عدد المستخدمين الحاليين: " .. count)
                    end
                end

                -- أوامر المستخدم
                if text == "/start" then
                    os.execute(string.format(
                        'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="أهلاً بك! أرسل رابط يوتيوب وسأعطيك خيار تحميله كفيديو أو صوت."',
                        telegram_bot_token, user_id
                    ))
                    print("أرسل رسالة ترحيب للمستخدم - ID: " .. user_id)
                elseif text and text:match("https?://") then
                    local url = text
                    local pending_file = user_id .. "_pending.txt"
                    local f = io.open(pending_file, "w")
                    f:write(url)
                    f:close()
                    os.execute(string.format(
    "curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text=\"اختار النوع:\n/vid → فيديو\n/audio → صوت\"",
    bot_token, chat_id))                  
               
                 print("تم حفظ الرابط للمستخدم - ID: " .. user_id)
                elseif text == "/vid" then
                    local pending_file = user_id .. "_pending.txt"
                    local f = io.open(pending_file, "r")
                    if f then
                        local url = f:read("*l")
                        f:close()
                        local filename = user_id .. "_video.mp4"
                        print("جارٍ تحميل الفيديو...")
                        local status = os.execute('yt-dlp -f mp4 -o ' .. filename .. ' ' .. url)
                        if status then
                            os.execute(string.format(
                                'curl -F "chat_id=%s" -F "video=@%s" https://api.telegram.org/bot%s/sendVideo',
                                user_id, filename, telegram_bot_token
                            ))
                            os.remove(filename)
                            print("تم إرسال الفيديو وحذف الملف.")
                        else
                            os.execute(string.format(
                                'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="فشل تحميل الفيديو!"',
                                telegram_bot_token, user_id
                            ))
                            print("تحذير: فشل تحميل الفيديو.")
                        end
                        os.remove(pending_file)
                    end
                elseif text == "/audio" then
                    local pending_file = user_id .. "_pending.txt"
                    local f = io.open(pending_file, "r")
                    if f then
                        local url = f:read("*l")
                        f:close()
                        local filename = user_id .. "_audio.mp3"
                        print("جارٍ تحميل الصوت...")
                        local status = os.execute('yt-dlp -f bestaudio --extract-audio --audio-format mp3 -o ' .. filename .. ' ' .. url)
                        if status then
                            os.execute(string.format(
                                'curl -F "chat_id=%s" -F "audio=@%s" https://api.telegram.org/bot%s/sendAudio',
                                user_id, filename, telegram_bot_token
                            ))
                            os.remove(filename)
                            print("تم إرسال الصوت وحذف الملف.")
                        else
                            os.execute(string.format(
                                'curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="فشل تحميل الصوت!"',
                                telegram_bot_token, user_id
                            ))
                            print("تحذير: فشل تحميل الصوت.")
                        end
                        os.remove(pending_file)
                    end
                end
            end
            ::continue::
        end
    end
    os.execute("sleep 2")
end
