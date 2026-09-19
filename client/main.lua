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

    local color = '#EDEDED'
    if data.color and type(data.color) == 'table' then
        color = string.format('rgb(%d, %d, %d)', data.color[1] or 255, data.color[2] or 255, data.color[3] or 255)
    end

    SendNUIMessage({
        action = 'ADD_MESSAGE',
        data = {
            channel = 'system',
            tag = locale('tags.system') or 'النظام',
            sender = sender,
            message = text,
            color = color,
            bgColor = 'rgba(255, 255, 255, 0.06)',
            borderColor = 'rgba(255, 255, 255, 0.15)',
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
            color = color or {255, 255, 255},
            time = GetGameTimer() + (Config.Display3DDuration or 7000)
        }
    end)

    local function DrawText3D(x, y, z, text, color)
        local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
        if not onScreen then return end

        SetTextScale(0.35, 0.35)
        SetTextColor(color[1] or 255, color[2] or 255, color[3] or 255, 220)
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
