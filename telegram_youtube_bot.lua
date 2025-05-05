-- إعداد المتغيرات الأساسية
local bot_token = "YOUR_BOT_TOKEN"  -- استبدلها بتوكن البوت
local admin_id = "YOUR_ADMIN_CHAT_ID"  -- استبدلها بمعرف الأدمن
local members = {}
local banned_users = {}

-- دالة إرسال رسالة تيليجرام
function send_message(chat_id, text)
    os.execute(string.format(
        "curl -s -X POST https://api.telegram.org/bot%s/sendMessage -d chat_id=%s -d text="%s"",
        bot_token, chat_id, text))
end

-- دالة تحميل من يوتيوب
function download_youtube(url, format)
    local cmd = string.format("yt-dlp --cookies cookies.txt -f %s %s", format, url)
    local result = os.execute(cmd)
    return result == 0 -- يرجع true إذا نجح
end

-- دالة إذاعة للكل
function broadcast(message)
    for _, user_id in ipairs(members) do
        send_message(user_id, message)
    end
end

-- دالة حظر مستخدم
function ban_user(user_id)
    banned_users[user_id] = true
end

-- دالة تحقق إذا محظور
function is_banned(user_id)
    return banned_users[user_id] or false
end

-- دالة التعامل مع الرسائل
function handle_command(user_id, command, args)
    if is_banned(user_id) then
        send_message(user_id, "أنت محظور من استخدام البوت.")
        return
    end

    if not members[user_id] then
        members[user_id] = true
        send_message(admin_id, string.format("دخل مستخدم جديد: %s", user_id))
    end

    if command == "/start" then
        send_message(user_id, "أهلاً بك! اختَر الصيغة:
/vid لتحميل فيديو
/audio لتحميل صوت")
    elseif command == "/vid" or command == "/audio" then
        send_message(user_id, "أرسل رابط الفيديو من يوتيوب.")
    elseif command == "/broadcast" and user_id == admin_id then
        broadcast(args)
        send_message(admin_id, "تمت الإذاعة بنجاح.")
    elseif command == "/count" and user_id == admin_id then
        local count = 0
        for _ in pairs(members) do count = count + 1 end
        send_message(admin_id, string.format("عدد الأعضاء: %d", count))
    elseif string.match(command, "https?://") then
        local format = args or "best"
        local success = download_youtube(command, format)
        if success then
            send_message(user_id, "تم تحميل الفيديو بنجاح!")
            -- هنا تقدر تضيف إرسال الملف للتيليجرام
        else
            send_message(user_id, "فشل تحميل الفيديو. تأكد من الرابط أو الصيغة.")
        end
    else
        send_message(user_id, "أمر غير معروف.")
    end
end

-- دالة لجلب الرسائل من تيليجرام باستخدام Long Polling
function get_updates(offset)
    local url = string.format("https://api.telegram.org/bot%s/getUpdates?offset=%s", bot_token, offset or "")
    local response = io.popen("curl -s " .. url):read("*a")
    return response
end

-- دالة معالجة التحديثات الجديدة
function process_updates()
    local offset = 0
    while true do
        local response = get_updates(offset)
        local updates = response:match(""result":%s*(%b[])") -- استخراج الرسائل من الاستجابة
        if updates then
            for update in updates:gmatch("{.-}") do
                local message = update:match(""text":"(.-)"")
                local user_id = update:match(""from":{"id":(%d+)}")
                local command = message and message:match("^/(%S+)") or ""
                local args = message and message:sub(#command + 2) or ""
                offset = tonumber(update:match(""update_id":(%d+)")) + 1

                if user_id and command then
                    handle_command(tonumber(user_id), command, args)
                end
            end
        end
        os.execute("sleep 1") -- إيقاف لمدة 1 ثانية بين الطلبات
    end
end

-- بدء الـ Long Polling
process_updates()
