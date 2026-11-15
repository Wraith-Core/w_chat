local chatOpen = false
local chatLoaded = false
local activeTexts3D = {}

--- The chat's own commands in plain words, in the player's language (locales say.<command>). A command
--- another resource registers keeps the help text it sent.
local SAY_COMMANDS = { 'local', 'l', 'ooc', 'me', 'do', 'w', 's', 'try', 'roll', 'pm', 'clear', 'clearchat', 'police', 'medic', 'ann' }
local function sayLines()
    local out = {}
    for _, name in ipairs(SAY_COMMANDS) do
        local text = locale('say.' .. name)
        if type(text) == 'string' and text ~= '' and text ~= ('say.' .. name) then out[name] = text end
    end
    return out
end

-- تهيئة عند تشغيل السكربت
CreateThread(function()
    Wait(500)
    -- إرسال طلب الاقتراحات المبدئية من السيرفر
    TriggerServerEvent('w_chat:server:requestSuggestions')

    -- مزامنة اللغة مع w_lib
    local localeKey = Config.DefaultLocale or 'ar'
    local isRTL = true
    if w and w.language then
        localeKey = w.language.key() or localeKey
        isRTL = (localeKey == 'ar')
    end

    SendNUIMessage({
        action = 'SET_LOCALE',
        data = {
            locale = localeKey,
            isRTL = isRTL,
            fadeTimeout = Config.FadeTimeout or 8500,
            placeholder = locale('ui.placeholder') or 'اكتب رسالتك هنا...',
            closeHint = locale('ui.close_hint') or 'اضغط ESC للإلغاء أو Enter للإرسال',
            channelGeneral = locale('ui.channel_general') or 'عام',
            -- 1.2.0: the words the page used to write itself (the send button, the commands list,
            -- the channel shown while typing a command) come from the locales too
            send = locale('ui.send'),
            suggestionsTitle = locale('ui.suggestions_title'),
            suggestionsHint = locale('ui.suggestions_hint'),
            channels = {
                ['local'] = locale('tags.local'), me = locale('tags.me'), ['do'] = locale('tags.do'),
                whisper = locale('tags.whisper'), shout = locale('tags.shout'), try = locale('tags.try'),
                roll = locale('tags.roll'), pm = locale('tags.pm'), police = locale('tags.police'),
                medic = locale('tags.medic'), admin = locale('tags.admin'),
            },
            -- notebook: the keys row under the line, and one plain line per chat command (say.<command>)
            keys = { send = locale('ui.key_send'), close = locale('ui.key_close'), last = locale('ui.key_last'), pick = locale('ui.key_pick') },
            helps = sayLines(),
        }
    })
    chatLoaded = true
end)

-- فتح وإغلاق الشات
local function openChat()
    if chatOpen then return end
    chatOpen = true
    TriggerEvent('w_chat:client:opened')
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'OPEN_CHAT'
    })
end

local function closeChat()
    if not chatOpen then return end
    chatOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'CLOSE_CHAT'
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)

-- تسجيل اختصار زر الشات (T)
RegisterCommand('openChat', function()
    if not chatOpen then
        openChat()
    end
end, false)

-- English on purpose (owner 2026-11-15): the game's key-binding page draws Latin only, Arabic came out as boxes
RegisterKeyMapping('openChat', 'Open chat', 'keyboard', Config.DefaultKey or 'T')

-- استقبال رد الشات من واجهة NUI
RegisterNUICallback('chatResult', function(data, cb)
    closeChat()
    local text = data and data.message
    if text and text ~= '' then
        if text:sub(1, 1) == '/' then
            -- تنفيذ الأمر محلياً على الكلاينت
            ExecuteCommand(text:sub(2))
        else
            -- إرسال الرسالة العادية إلى السيرفر
            TriggerServerEvent('w_chat:server:sendMessage', text)
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeChat', function(data, cb)
    closeChat()
    cb('ok')
end)

-- أمر مسح الشات المحلي
RegisterCommand('clear', function()
    SendNUIMessage({ action = 'CLEAR_CHAT' })
    TriggerEvent('w_chat:client:addSystemMessage', locale('messages.cleared_local') or 'تم مسح الشات المحلي بنجاح.')
end, false)

-- ─────────────────────────────────────────────────────────────────────────────
-- أحداث استقبال الرسائل والاقتراحات
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- ألوان الرسائل: أبيض وأسود مثل ريد ديد
-- ─────────────────────────────────────────────────────────────────────────────
-- ★ Whatever colour a sender asks for ({r,g,b} in chat:addMessage, the colour of the words over a
--   head), the chat draws one of the theme's two text tones: paper (#F2F2F2) or dim paper (#B4B4B4),
--   whichever is nearer by luminance. A strong red is an error: its letters stay paper and the
--   interface marks the line with the one red, as a ribbon (web/style.css [data-tone="error"]).
local PAPER, PAPER_DIM = { 242, 242, 242 }, { 180, 180, 180 }

---@param color table|nil {r, g, b} or {r=, g=, b=}
---@return table rgb one of the two tones
---@return boolean isRed the sender meant an error
local function chatTone(color)
    if type(color) ~= 'table' then return PAPER, false end
    local r = tonumber(color[1] or color.r) or 255
    local g = tonumber(color[2] or color.g) or 255
    local b = tonumber(color[3] or color.b) or 255
    local isRed = r >= 150 and g <= 90 and b <= 90
    -- the midpoint between the two tones' luminance (242 and 180)
    local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return (isRed or lum >= 211) and PAPER or PAPER_DIM, isRed
end

-- استقبال رسالة مهيئة من سكريبت w_chat
RegisterNetEvent('w_chat:client:addMessage', function(data)
    if not data then return end
    SendNUIMessage({
        action = 'ADD_MESSAGE',
        data = data
    })
end)

-- استقبال رسالة نظام خفيفة
RegisterNetEvent('w_chat:client:addSystemMessage', function(text)
    if not text then return end
    SendNUIMessage({
        action = 'ADD_MESSAGE',
        data = {
            channel = 'system',
            tag = locale('tags.system') or 'النظام',
            sender = locale('tags.system') or 'النظام',
            message = text,
            color = Config.Channels.system.color,
            bgColor = Config.Channels.system.bgColor,
            borderColor = Config.Channels.system.borderColor,
            icon = Config.Channels.system.icon,
            time = GetTimeAsString()
        }
    })
end)

-- مسح سجل الشات
RegisterNetEvent('w_chat:client:clearChat', function()
    SendNUIMessage({ action = 'CLEAR_CHAT' })
end)

RegisterNetEvent('chat:clear', function()
    SendNUIMessage({ action = 'CLEAR_CHAT' })
end)

-- دعم حدث CFX الافتراضي chat:addMessage للتوافق الكامل مع w_core وباقي الموارد
RegisterNetEvent('chat:addMessage', function(data)
    if not data then return end

    local text = ''
    local sender = locale('tags.system') or 'النظام'

    if data.args and #data.args > 0 then
        if #data.args == 1 then
            text = tostring(data.args[1])
        else
            sender = tostring(data.args[1])
            text = tostring(data.args[2])
            for i = 3, #data.args do
                text = text .. ' ' .. tostring(data.args[i])
            end
        end
    elseif data.template or data.templateId then
        text = data.template or ''
    end

    if text == '' then return end

    local tone, isRed = chatTone(data.color)
    local color = ('rgb(%d, %d, %d)'):format(tone[1], tone[2], tone[3])

    SendNUIMessage({
        action = 'ADD_MESSAGE',
        data = {
            channel = 'system',
            tag = locale('tags.system') or 'النظام',
            sender = sender,
            message = text,
            color = color,
            tone = isRed and 'error' or nil,
            bgColor = 'rgba(242, 242, 242, 0.06)',
            borderColor = 'rgba(242, 242, 242, 0.15)',
            icon = 'fa-bell',
            time = GetTimeAsString()
        }
    })
end)

-- دعم إضافة وحذف الاقتراحات (Suggestions)
-- 1.1.11 (owner 2026-11-06): nothing goes to the page straight away. Every suggestion (chat:addSuggestion and the
-- plural chat:addSuggestions that w_core / w_lib's addCommand send - it was not handled before, so their
-- commands never showed) is kept here, and the server says which of them this player may SEE
-- (w_chat:server:filterSuggestions). Staff also get our resources' commands without a help text.
local known = {}          -- lower name without '/' -> { name = '/x', help, params }
local shown = {}          -- names on the page now
local flushPending, lastFlush = false, 0

local function clientCommands()
    local out = {}
    local ok, list = pcall(GetRegisteredCommands)
    if not ok or type(list) ~= 'table' then return out end
    for _, c in ipairs(list) do
        local name, res = type(c) == 'table' and c.name, type(c) == 'table' and c.resource
        if type(name) == 'string' and type(res) == 'string' and not name:find('^[%+%-]') then
            for _, pat in ipairs(Config.StaffCommandResources or {}) do
                if res:find(pat) then out[#out + 1] = name:lower() break end
            end
        end
    end
    return out
end

local function flushSuggestions()
    lastFlush = GetGameTimer()
    local names, seen = {}, {}
    for name in pairs(known) do names[#names + 1] = name; seen[name] = true end
    for _, name in ipairs(clientCommands()) do
        if not seen[name] then names[#names + 1] = name; seen[name] = true end
    end
    TriggerServerEvent('w_chat:server:filterSuggestions', names)
end

local function scheduleFlush()
    if flushPending then return end
    flushPending = true
    SetTimeout(1200, function()
        flushPending = false
        flushSuggestions()
    end)
end

local function remember(name, help, params)
    if type(name) ~= 'string' or name == '' then return end
    local key = name:gsub('^/', ''):lower()
    known[key] = { name = '/' .. key, help = type(help) == 'string' and help or '', params = type(params) == 'table' and params or {} }
    scheduleFlush()
end

RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    remember(name, help, params)
end)

RegisterNetEvent('chat:addSuggestions', function(list)
    if type(list) ~= 'table' then return end
    if list.name then list = { list } end                 -- w_lib's addCommand sends one at a time too
    for _, sg in pairs(list) do
        if type(sg) == 'table' then remember(sg.name, sg.help, sg.params) end
    end
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    if type(name) ~= 'string' then return end
    local key = name:gsub('^/', ''):lower()
    known[key] = nil
    shown[key] = nil
    SendNUIMessage({ action = 'REMOVE_SUGGESTION', data = { name = '/' .. key } })
end)

RegisterNetEvent('w_chat:client:allowedSuggestions', function(allowed, extra)
    local now = {}
    for _, name in ipairs(type(allowed) == 'table' and allowed or {}) do
        if type(name) == 'string' then
            now[name] = true
            local sg = known[name] or { name = '/' .. name, help = '', params = {} }
            SendNUIMessage({ action = 'ADD_SUGGESTION', data = sg })
        end
    end
    for _, e in ipairs(type(extra) == 'table' and extra or {}) do
        if type(e) == 'table' and type(e.name) == 'string' and not now[e.name] then
            now[e.name] = true
            SendNUIMessage({ action = 'ADD_SUGGESTION', data = { name = '/' .. e.name, help = '', params = {} } })
        end
    end
    for name in pairs(shown) do
        if not now[name] then SendNUIMessage({ action = 'REMOVE_SUGGESTION', data = { name = '/' .. name } }) end
    end
    shown = now
end)

-- the first list once the other resources sent theirs; again on opening the chat after a minute
-- (a rank given meanwhile shows its commands)
SetTimeout(4000, scheduleFlush)
AddEventHandler('w_chat:client:opened', function()
    if GetGameTimer() - lastFlush > 60000 then scheduleFlush() end
end)

-- دالة مساعدة لجلب الوقت بتنسيق 00:00
function GetTimeAsString()
    local hours = GetClockHours()
    local minutes = GetClockMinutes()
    return string.format('%02d:%02d', hours, minutes)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- عرض النصوص ثلاثية الأبعاد فوق رأس الشخصية (3D Floating Text)
-- ─────────────────────────────────────────────────────────────────────────────
if Config.Enable3DText then
    -- 1.1.11: the text goes to w_lib's page, where HTML is allowed: escape it
    local function escapeHtml(text)
        return (tostring(text):gsub('[&<>"\']', { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;', ["'"] = '&#39;' }))
    end

    RegisterNetEvent('w_chat:client:show3DText', function(targetSrc, text, color)
        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
        if not DoesEntityExist(targetPed) then return end

        local id = #activeTexts3D + 1
        activeTexts3D[id] = {
            ped = targetPed,
            text = escapeHtml(text),
            color = chatTone(color),
            time = GetGameTimer() + (Config.Display3DDuration or 7000)
        }
    end)

    -- 1.1.11: drawn by w_lib's page (the game font has no Arabic letters)
    local function DrawText3D(x, y, z, text, color, id)
        local r, g, b = tonumber(color and color[1]) or 242, tonumber(color and color[2]) or 242, tonumber(color and color[3]) or 242
        exports.w_lib:DrawText3D(x, y, z, ('<span style="color:rgb(%d,%d,%d)">%s</span>'):format(r, g, b, text), id)
    end

    CreateThread(function()
        while true do
            local waitTime = 500
            local now = GetGameTimer()
            local myCoords = GetEntityCoords(PlayerPedId())

            if next(activeTexts3D) then
                waitTime = 0
                for k, v in pairs(activeTexts3D) do
                    if now < v.time and DoesEntityExist(v.ped) then
                        local pedCoords = GetPedBoneCoords(v.ped, 12844, 0.0, 0.0, 0.0) -- Head bone
                        if #(myCoords - pedCoords) < 18.0 then
                            DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + 0.35, v.text, v.color, 'w_chat:3d:' .. k)
                        end
                    else
                        activeTexts3D[k] = nil
                    end
                end
            end
            Wait(waitTime)
        end
    end)
end
