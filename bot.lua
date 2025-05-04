
local https = require("ssl.https")
local json = require("dkjson")
local io = require("io")

local bot_token = '953062624:AAHSr4IHh7hLeZiDk4NVJYPrqSK1ZLwcn2M'
local admin_id = 426795071  -- هنا تحط Telegram ID مالك

local api_url = 'https://api.telegram.org/bot' .. bot_token .. '/'

function saveUser(user_id)
    local users = {}
    for line in io.lines('users.txt') do
        users[line] = true
    end
    if not users[tostring(user_id)] then
        local file = io.open('users.txt', 'a')
        file:write(user_id .. '\n')
        file:close()
    end
end

function isBanned(user_id)
    for line in io.lines('banned.txt') do
        if line == tostring(user_id) then
            return true
        end
    end
    return false
end

function banUser(user_id)
    local file = io.open('banned.txt', 'a')
    file:write(user_id .. '\n')
    file:close()
end

function unbanUser(user_id)
    local lines = {}
    for line in io.lines('banned.txt') do
        if line ~= tostring(user_id) then
            table.insert(lines, line)
        end
    end
    local file = io.open('banned.txt', 'w')
    for _, l in ipairs(lines) do
        file:write(l .. '\n')
    end
    file:close()
end

function countUsers()
    local count = 0
    for _ in io.lines('users.txt') do
        count = count + 1
    end
    return count
end

function getUpdates(offset)
    local url = api_url .. 'getUpdates?timeout=20'
    if offset then
        url = url .. '&offset=' .. offset
    end
    local res, code = https.request(url)
    if code == 200 then
        local data = json.decode(res)
        return data.result
    else
        return nil
    end
end

function sendMessage(chat_id, text)
    local url = api_url .. 'sendMessage?chat_id=' .. chat_id .. '&text=' .. text
    https.request(url)
end

function sendPhoto(chat_id, photo_url, caption)
    local url = api_url .. 'sendPhoto?chat_id=' .. chat_id .. '&photo=' .. photo_url .. '&caption=' .. caption
    https.request(url)
end

function sendVideo(chat_id, video_url, caption)
    local url = api_url .. 'sendVideo?chat_id=' .. chat_id .. '&video=' .. video_url .. '&caption=' .. caption
    https.request(url)
end

function broadcastMessage(text)
    for line in io.lines('users.txt') do
        sendMessage(line, text)
        os.execute("sleep 0.5")
    end
end

local offset = nil

while true do
    local updates = getUpdates(offset)
    if updates then
        for _, update in ipairs(updates) do
            offset = update.update_id + 1
            if update.message then
                local chat_id = update.message.chat.id
                local text = update.message.text or ''
                local from_id = chat_id

                if isBanned(from_id) then
                    sendMessage(chat_id, 'انت محظور من استخدام البوت.')
                else
                    saveUser(chat_id)

                    if from_id == admin_id then
                        if text == '/users' then
                            local count = countUsers()
                            sendMessage(chat_id, 'عدد المستخدمين: ' .. count)
                        elseif text:match('^/bc (.+)') then
                            local bc_text = text:match('^/bc (.+)')
                            sendMessage(chat_id, 'جاري الإذاعة...')
                            broadcastMessage(bc_text)
                            sendMessage(chat_id, 'تم الإرسال.')
                        elseif text:match('^/ban (%d+)$') then
                            local ban_id = text:match('^/ban (%d+)$')
                            banUser(ban_id)
                            sendMessage(chat_id, 'تم حظر المستخدم: ' .. ban_id)
                        elseif text:match('^/unban (%d+)$') then
                            local unban_id = text:match('^/unban (%d+)$')
                            unbanUser(unban_id)
                            sendMessage(chat_id, 'تم رفع الحظر عن: ' .. unban_id)
                        elseif text:match('^/photo (.+) (.+)$') then
                            local url, caption = text:match('^/photo (.+) (.+)$')
                            for line in io.lines('users.txt') do
                                sendPhoto(line, url, caption)
                                os.execute("sleep 0.5")
                            end
                            sendMessage(chat_id, 'تم إرسال الصورة.')
                        elseif text:match('^/video (.+) (.+)$') then
                            local url, caption = text:match('^/video (.+) (.+)$')
                            for line in io.lines('users.txt') do
                                sendVideo(line, url, caption)
                                os.execute("sleep 0.5")
                            end
                            sendMessage(chat_id, 'تم إرسال الفيديو.')
                        else
                            sendMessage(chat_id, 'أوامر الادمن:\n/users\n/bc <رسالة>\n/ban <ID>\n/unban <ID>\n/photo <رابط> <تعليق>\n/video <رابط> <تعليق>')
                        end
                    else
                        sendMessage(chat_id, 'اهلا بك! ارسل /start للبدء.')
                    end
                end
            end
        end
    end
    os.execute("sleep 1")
end
