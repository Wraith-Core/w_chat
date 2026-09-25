local chatOpen = false
local chatLoaded = false
local activeTexts3D = {}

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
            channelGeneral = locale('ui.channel_general') or 'عام'
        }
    })
    chatLoaded = true
end)

-- فتح وإغلاق الشات
local function openChat()
    if chatOpen then return end
    chatOpen = true
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

RegisterKeyMapping('openChat', 'فتح الشات (Wraith Chat)', 'keyboard', Config.DefaultKey or 'T')

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
--   head), the chat draws one of the theme's two text tones: paper (#EDE6D6) or dim paper (#B9AF9C),
--   whichever is nearer by luminance. A strong red is an error: its letters stay paper and the
--   interface marks the line with the one red, as a ribbon (web/style.css [data-tone="error"]).
local PAPER, PAPER_DIM = { 237, 230, 214 }, { 185, 175, 156 }

---@param color table|nil {r, g, b} or {r=, g=, b=}
---@return table rgb one of the two tones
---@return boolean isRed the sender meant an error
local function chatTone(color)
    if type(color) ~= 'table' then return PAPER, false end
    local r = tonumber(color[1] or color.r) or 255
    local g = tonumber(color[2] or color.g) or 255
    local b = tonumber(color[3] or color.b) or 255
    local isRed = r >= 150 and g <= 90 and b <= 90
    -- the midpoint between the two tones' luminance (230 and 176)
    local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return (isRed or lum >= 203) and PAPER or PAPER_DIM, isRed
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
            bgColor = 'rgba(237, 230, 214, 0.06)',
            borderColor = 'rgba(237, 230, 214, 0.15)',
            icon = 'fa-bell',
            time = GetTimeAsString()
        }
    })
end)

-- دعم إضافة وحذف الاقتراحات (Suggestions)
RegisterNetEvent('chat:addSuggestion', function(name, help, params)
    SendNUIMessage({
        action = 'ADD_SUGGESTION',
        data = {
            name = name,
            help = help or '',
            params = params or {}
        }
    })
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    SendNUIMessage({
        action = 'REMOVE_SUGGESTION',
        data = {
            name = name
        }
    })
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
    RegisterNetEvent('w_chat:client:show3DText', function(targetSrc, text, color)
        local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
        if not DoesEntityExist(targetPed) then return end

        local id = #activeTexts3D + 1
        activeTexts3D[id] = {
            ped = targetPed,
            text = text,
            color = chatTone(color),
            time = GetGameTimer() + (Config.Display3DDuration or 7000)
        }
    end)

    local function DrawText3D(x, y, z, text, color)
        local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
        if not onScreen then return end

        SetTextScale(0.35, 0.35)
        local r, g, b = color[1], color[2], color[3]
        SetTextColor(r, g, b, 220)
        SetTextCentre(1)

        -- استخدام نمط الخط المناسب لـ RedM
        local str = CreateVarString(10, "LITERAL_STRING", text)
        DisplayText(str, _x, _y)
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
                            DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + 0.35, v.text, v.color)
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
