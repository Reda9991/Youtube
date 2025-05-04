
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")

local bot_token = "953062624:AAHSr4IHh7hLeZiDk4NVJYPrqSK1ZLwcn2M"
local api_url = "https://api.telegram.org/bot" .. bot_token

-- دالة إرسال رسالة
function sendMessage(chat_id, text)
    local url = api_url .. "/sendMessage"
    local res, code = https.request{
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded"
        },
        source = ltn12.source.string("chat_id=" .. chat_id .. "&text=" .. text)
    }
end

-- دالة إرسال ملف فيديو
function sendVideo(chat_id, file_path)
    os.execute('curl -F "chat_id=' .. chat_id .. '" -F "video=@' .. file_path .. '" ' .. api_url .. '/sendVideo')
end

-- دالة جلب التحديثات
function getUpdates(offset)
    local res = {}
    local _, code = https.request{
        url = api_url .. "/getUpdates?timeout=20&offset=" .. offset,
        sink = ltn12.sink.table(res)
    }
    local body = table.concat(res)
    return json.decode(body)
end

-- بدء الحلقة الرئيسية
local offset = 0
print("البوت يعمل...")

while true do
    local updates = getUpdates(offset)
    if updates and updates.result then
        for _, update in ipairs(updates.result) do
            offset = update.update_id + 1
            local message = update.message
            if message then
                local chat_id = message.chat.id
                local text = message.text

                if text == "/start" then
                    sendMessage(chat_id, "أهلاً بيك! أرسل لي رابط يوتيوب وانزّله لك.")
                elseif text:match("https://") then
                    sendMessage(chat_id, "جاري تنزيل الفيديو، انتظر شوي...")

                    -- حمّل الفيديو
                    local output_file = "downloaded_video.mp4"
                    local cmd = 'yt-dlp -f mp4 -o "' .. output_file .. '" "' .. text .. '"'
                    os.execute(cmd)

                    -- أرسل الفيديو
                    sendVideo(chat_id, output_file)

                    -- احذف الملف
                    os.remove(output_file)
                else
                    sendMessage(chat_id, "أرسل لي رابط يوتيوب صحيح أو اكتب /start.")
                end
            end
        end
    end
end
