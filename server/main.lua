-- دالة مساعدة للحصول على اسم الشخصية عبر w_lib
local function getPlayerDisplayName(source)
    local ok, name = pcall(function() return exports.w_lib:FwGetCharacterName(source) end)
    if ok and type(name) == 'string' and name ~= '' and name ~= ' ' then
        return name
    end
    if w and w.framework then
        local wname = w.framework:getCharacterName(source)
        if wname and wname ~= '' and wname ~= ' ' then
            return wname
        end
    end
    return GetPlayerName(source) or ('Player %s'):format(source)
end

-- The id printed beside a sender's name is the one a reader types into /pm, so it is his citizen
-- id (fixed per character), never the server id: since citizen ids are plain digits, "/pm 5" to
-- someone shown as [5] by server id reached citizen 5, a different person. A player with no
-- character in play yet shows '#<server id>', which /pm reads as a server id.
local function chatId(source)
    -- the console has no id to show (the interface hides a missing one, as it hid the old 0)
    if not source or source <= 0 then return nil end
    local ok, cid = pcall(function() return w.citizen.idOf(source) end)
    if ok and cid then return cid end
    return ('#%s'):format(source)
end

-- فحص الصلاحيات الإدارية عبر w_lib
local function isPlayerAdmin(source)
    if source == 0 then return true end
    local ok, allowed = pcall(function() return exports.w_lib:FwHasPermission(source, 'admin') end)
    if ok and allowed == true then return true end
    local okAdm, isAdm = pcall(function() return exports.w_lib:IsAdmin(source) end)
    return okAdm and isAdm == true
end

-- فحص وظيفة اللاعب عبر w_lib
local function hasPlayerJob(source, jobName)
    local ok, job = pcall(function() return exports.w_lib:FwGetJob(source) end)
    if ok and type(job) == 'string' and job ~= '' then
        return job == jobName
    end
    local okU, user = pcall(function() return w.framework:getUser(source) end)
    if okU and user and user.getJob then
        local okJob, ujob = pcall(function() return user:getJob() end)
        return okJob and ujob == jobName
    end
    return false
end

-- فحص واستخراج رتبة اللاعب للتلوين والشارات
--- 1.1.3 (2026-10-21): the name colour bought in the server store (w_vip perk chat_color), or nil.
local function nameColorOf(source)
    if GetResourceState('w_vip') ~= 'started' then return nil end
    local ok, n = pcall(function() return exports.w_vip:Perk(source, 'chat_color', 0) end)
    if ok and (tonumber(n) or 0) > 0 then return Config.StoreNameColor end
    return nil
end

local function hasRankPerm(source, rankName)
    local ok, res = pcall(function() return exports.w_lib:FwHasPermission(source, rankName) end)
    return ok and res == true
end

local function getPlayerRank(source)
    if source == 0 then
        if Config.Ranks and Config.Ranks.god then
            local r = Config.Ranks.god
            return { name = 'god', label = r.label, color = r.color, bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon }
        end
        return { name = 'god', label = 'Console', color = '#F2F2F2', icon = 'fa-terminal' }
    end
    if not Config.Ranks then return nil end

    if hasRankPerm(source, 'god') then
        local r = Config.Ranks.god or {}
        return { name = 'god', label = r.label or 'مطور', color = r.color or '#F2F2F2', bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon or 'fa-crown' }
    end
    if hasRankPerm(source, 'admin') then
        local r = Config.Ranks.admin or {}
        return { name = 'admin', label = r.label or 'إدارة', color = r.color or '#F2F2F2', bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon or 'fa-shield-halved' }
    end
    if hasRankPerm(source, 'mod') then
        local r = Config.Ranks.mod or {}
        return { name = 'mod', label = r.label or 'مشرف', color = r.color or '#F2F2F2', bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon or 'fa-user-shield' }
    end
    -- 1.1.2: a VIP tier from the store (w_vip) wears its own colours; the staff above keep precedence and
    -- the plain VIP badge below stays for a vip permission given by hand
    local tier = 0
    if GetResourceState('w_vip') == 'started' then
        local ok, t = pcall(function() return exports.w_vip:Tier(source) end)
        tier = ok and tonumber(t) or 0
    end
    local tierKey = tier > 0 and Config.VipTiers and Config.VipTiers[tier]
    if tierKey and Config.Ranks[tierKey] then
        local r = Config.Ranks[tierKey]
        return { name = tierKey, label = r.label, color = r.color, bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon, tier = tier }
    end
    if hasRankPerm(source, 'vip') then
        local r = Config.Ranks.vip or {}
        return { name = 'vip', label = r.label or 'VIP', color = r.color or '#F2F2F2', bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon or 'fa-star' }
    end

    local okGrp, perm = pcall(function() return exports.w_lib:GetPlayerGroup(source) end)
    if okGrp and perm and Config.Ranks[perm] then
        local r = Config.Ranks[perm]
        return { name = perm, label = r.label, color = r.color, bgColor = r.bgColor, borderColor = r.borderColor, icon = r.icon }
    end
    return nil
end

-- إرسال رسالة شات لجميع اللاعبين القريبين ضمن مسافة معينة
local function sendProximityMessage(source, distance, messageData, text3D)
    local ped = GetPlayerPed(source)
    if not DoesEntityExist(ped) then return end
    local coords = GetEntityCoords(ped)

    local players = GetPlayers()
    for i = 1, #players do
        local targetSrc = tonumber(players[i])
        local targetPed = GetPlayerPed(targetSrc)
        if DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(coords - targetCoords)
            if dist <= distance then
                TriggerClientEvent('w_chat:client:addMessage', targetSrc, messageData)
            end
        end
    end

    -- إظهار النص ثلاثي الأبعاد إذا كان مفعلاً
    if Config.Enable3DText and text3D then
        TriggerClientEvent('w_chat:client:show3DText', -1, source, text3D.text, text3D.color)
    end
end

-- إرسال رسالة لجميع اللاعبين
local function sendGlobalMessage(messageData)
    TriggerClientEvent('w_chat:client:addMessage', -1, messageData)
end

-- تصدير وظيفة إضافة رسالة متوافقة مع chat الأصلي
local function addMessageExport(target, data)
    if target == -1 then
        sendGlobalMessage(data)
    else
        TriggerClientEvent('w_chat:client:addMessage', target, data)
    end
end

exports('addMessage', addMessageExport)

-- معالجة حدث chat:addMessage القياسي من RedM
RegisterNetEvent('chat:addMessage', function(data)
    local src = source
    if src == 0 or not src then
        sendGlobalMessage(data)
    else
        TriggerClientEvent('w_chat:client:addMessage', src, data)
    end
end)

-- Audit (2026-10-18): one flood limit for everything a player sends to the chat (the NUI message and every chat
-- command below): Config.FloodMax messages per Config.FloodWindowMs; above it the message is dropped and the sender
-- told once per window. Before, one player could send to everyone as fast as he liked.
local floodLog = {}
local function flooding(src)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    local now, window = GetGameTimer(), Config.FloodWindowMs or 10000
    local f = floodLog[src]
    if not f or now - f.at > window then
        f = { at = now, n = 0 }
        floodLog[src] = f
    end
    f.n = f.n + 1
    if f.n <= (Config.FloodMax or 6) then return false end
    if not f.told then
        f.told = true
        TriggerClientEvent('w_chat:client:addSystemMessage', src, locale('messages.slow_down') or 'على مهلك، انتظر قليلًا ثم أرسل.')
    end
    return true
end

AddEventHandler('playerDropped', function()
    floodLog[source] = nil
end)

--- RegisterCommand with the flood limit in front (every chat command of this file goes through it)
local function chatCommand(name, handler, restricted)
    RegisterCommand(name, function(source, args, raw)
        if flooding(source) then return end
        -- a command line longer than a chat message (+ room for the command and a target) is dropped
        if tonumber(source) and tonumber(source) > 0 and type(raw) == 'string'
            and #raw > (Config.MaxMessageLength or 250) + 40 then return end
        return handler(source, args, raw)
    end, restricted)
end

-- معالجة إرسال الرسائل من واجهة NUI
RegisterNetEvent('w_chat:server:sendMessage', function(rawText)
    local src = source
    if not rawText or type(rawText) ~= 'string' then return end
    if flooding(src) then return end

    -- إزالة الفراغات الزائدة
    local text = rawText:gsub('^%s*(.-)%s*$', '%1')
    if text == '' then return end

    -- التحقق من طول الرسالة
    if #text > Config.MaxMessageLength then
        text = text:sub(1, Config.MaxMessageLength)
    end

    -- A command never reaches this event: the client runs it itself (client/main.lua chatResult).
    -- ! Executing it here ran it as the CONSOLE (ExecuteCommand on the server has no player), so a
    --    forged event could run any restricted command, e.g. '/additem 12 ...' against a citizen.
    if text:sub(1, 1) == '/' then
        return
    end

    -- Commands only (owner 2026-11-06): plain text goes to nobody; the writer is told why.
    if Config.CommandsOnly then
        TriggerClientEvent('w_chat:client:addSystemMessage', src, locale('messages.commands_only') or 'الشات للأوامر فقط. اكتب الأمر بعد علامة /')
        return
    end

    -- الرسائل العادية بدون أمر تذهب إلى OOC (أو العام)
    local name = getPlayerDisplayName(src)
    local rank = getPlayerRank(src)
    local payload = {
        channel = 'ooc',
        tag = locale('tags.ooc') or 'OOC',
        sender = name,
        id = chatId(src),
        rank = rank,
        nameColor = nameColorOf(src),   -- 1.1.3: a coloured name bought in the server store
        message = text,
        color = Config.Channels.ooc.color,
        bgColor = Config.Channels.ooc.bgColor,
        borderColor = Config.Channels.ooc.borderColor,
        icon = Config.Channels.ooc.icon,
        time = os.date('%H:%M')
    }

    if Config.Distances.OocProximity then
        sendProximityMessage(src, Config.Distances.OocDistance, payload)
    else
        sendGlobalMessage(payload)
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- أوامر الرول بلاي الأساسية (Roleplay Commands)
-- ─────────────────────────────────────────────────────────────────────────────

-- 0. أمر المحادثة المحلية (Local Proximity Chat)
local function handleLocalChat(source, args, raw)
    if source == 0 then return end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة الرسالة.')
        return
    end
    local name = getPlayerDisplayName(source)
    local rank = getPlayerRank(source)
    local payload = {
        channel = 'local',
        tag = locale('tags.local') or 'محلي',
        sender = name,
        id = chatId(source),
        rank = rank,
        nameColor = nameColorOf(source),   -- 1.1.3: a coloured name bought in the server store
        message = text,
        color = Config.Channels.localChat and Config.Channels.localChat.color or '#F2F2F2',
        bgColor = Config.Channels.localChat and Config.Channels.localChat.bgColor or 'rgba(242, 242, 242, 0.08)',
        borderColor = Config.Channels.localChat and Config.Channels.localChat.borderColor or 'rgba(242, 242, 242, 0.3)',
        icon = Config.Channels.localChat and Config.Channels.localChat.icon or 'fa-location-dot',
        time = os.date('%H:%M')
    }
    sendProximityMessage(source, Config.Distances.Local or 20.0, payload)
end

chatCommand('local', handleLocalChat, false)
chatCommand('l', handleLocalChat, false)

-- 1. أمر OOC
chatCommand('ooc', function(source, args, raw)
    if source == 0 then return end
    if Config.CommandsOnly then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.commands_only') or 'الشات للأوامر فقط. اكتب الأمر بعد علامة /')
        return
    end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة الرسالة.')
        return
    end
    local name = getPlayerDisplayName(source)
    local rank = getPlayerRank(source)
    local payload = {
        channel = 'ooc',
        tag = locale('tags.ooc') or 'OOC',
        sender = name,
        id = chatId(source),
        rank = rank,
        nameColor = nameColorOf(source),   -- 1.1.3: a coloured name bought in the server store
        message = text,
        color = Config.Channels.ooc.color,
        bgColor = Config.Channels.ooc.bgColor,
        borderColor = Config.Channels.ooc.borderColor,
        icon = Config.Channels.ooc.icon,
        time = os.date('%H:%M')
    }
    if Config.Distances.OocProximity then
        sendProximityMessage(source, Config.Distances.OocDistance, payload)
    else
        sendGlobalMessage(payload)
    end
end, false)

-- 2. أمر ME
chatCommand('me', function(source, args, raw)
    if source == 0 then return end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة الفعل.')
        return
    end
    local name = getPlayerDisplayName(source)
    local payload = {
        channel = 'me',
        tag = locale('tags.me') or 'ME',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.me.color,
        bgColor = Config.Channels.me.bgColor,
        borderColor = Config.Channels.me.borderColor,
        icon = Config.Channels.me.icon,
        time = os.date('%H:%M')
    }
    -- 1.1.11 (owner 2026-11-06): /me is shown only above the head, to the players near enough to see it
    if Config.Enable3DText and Config.MeAboveHeadOnly ~= false then
        local ped = GetPlayerPed(source)
        if not DoesEntityExist(ped) then return end
        local coords = GetEntityCoords(ped)
        local players = GetPlayers()
        for i = 1, #players do
            local targetSrc = tonumber(players[i])
            local targetPed = GetPlayerPed(targetSrc)
            if DoesEntityExist(targetPed) and #(coords - GetEntityCoords(targetPed)) <= Config.Distances.Me then
                TriggerClientEvent('w_chat:client:show3DText', targetSrc, source, '* ' .. text .. ' *', {242, 242, 242})
            end
        end
        return
    end
    sendProximityMessage(source, Config.Distances.Me, payload, { text = '* ' .. text .. ' *', color = {242, 242, 242} })
end, false)

-- 3. أمر DO
chatCommand('do', function(source, args, raw)
    if source == 0 then return end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة الوصف.')
        return
    end
    local name = getPlayerDisplayName(source)
    local payload = {
        channel = 'do',
        tag = locale('tags.do') or 'DO',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.doChannel.color,
        bgColor = Config.Channels.doChannel.bgColor,
        borderColor = Config.Channels.doChannel.borderColor,
        icon = Config.Channels.doChannel.icon,
        time = os.date('%H:%M')
    }
    sendProximityMessage(source, Config.Distances.Do, payload, { text = '** ' .. text .. ' **', color = {180, 180, 180} })
end, false)

-- 4. أمر الهمس (Whisper)
local function handleWhisper(source, args)
    if source == 0 then return end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة النص.')
        return
    end
    local name = getPlayerDisplayName(source)
    local payload = {
        channel = 'whisper',
        tag = locale('tags.whisper') or 'همس',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.whisper.color,
        bgColor = Config.Channels.whisper.bgColor,
        borderColor = Config.Channels.whisper.borderColor,
        icon = Config.Channels.whisper.icon,
        time = os.date('%H:%M')
    }
    sendProximityMessage(source, Config.Distances.Whisper, payload)
end

chatCommand('w', handleWhisper, false)
chatCommand('whisper', handleWhisper, false)

-- 5. أمر الصراخ (Shout)
local function handleShout(source, args)
    if source == 0 then return end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة النص.')
        return
    end
    local name = getPlayerDisplayName(source)
    local payload = {
        channel = 'shout',
        tag = locale('tags.shout') or 'صراخ',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.shout.color,
        bgColor = Config.Channels.shout.bgColor,
        borderColor = Config.Channels.shout.borderColor,
        icon = Config.Channels.shout.icon,
        time = os.date('%H:%M')
    }
    sendProximityMessage(source, Config.Distances.Shout, payload)
end

chatCommand('s', handleShout, false)
chatCommand('shout', handleShout, false)

-- 6. أمر القرعة (Try)
chatCommand('try', function(source, args, raw)
    if source == 0 then return end
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة المحاولة.')
        return
    end
    local isSuccess = math.random(1, 2) == 1
    local name = getPlayerDisplayName(source)
    local resultText = isSuccess and (locale('tags.try_success') or 'نجاح') or (locale('tags.try_fail') or 'فشل')
    local resultColor = isSuccess and Config.Channels.tryChannel.successColor or Config.Channels.tryChannel.failColor
    local bgCol = isSuccess and 'rgba(242, 242, 242, 0.15)' or 'rgba(180, 180, 180, 0.12)'
    local bdrCol = isSuccess and 'rgba(242, 242, 242, 0.4)' or 'rgba(180, 180, 180, 0.35)'

    local payload = {
        channel = 'try',
        tag = (locale('tags.roll') or 'قرعة') .. ' [' .. resultText .. ']',
        sender = name,
        id = chatId(source),
        message = text,
        color = resultColor,
        bgColor = bgCol,
        borderColor = bdrCol,
        icon = Config.Channels.tryChannel.icon,
        time = os.date('%H:%M')
    }
    sendProximityMessage(source, Config.Distances.Me, payload, { text = ('[%s] %s'):format(resultText, text), color = isSuccess and {242, 242, 242} or {180, 180, 180} })
end, false)

-- 7. أمر رمي النرد (Roll)
chatCommand('roll', function(source, args, raw)
    if source == 0 then return end
    local maxRoll = tonumber(args[1]) or 100
    if maxRoll < 2 then maxRoll = 100 end
    local score = math.random(1, maxRoll)
    local name = getPlayerDisplayName(source)
    local msg = (locale('messages.roll_result') or '%s رمى النرد وحصل على: %s من %s'):format(name, score, maxRoll)

    local payload = {
        channel = 'roll',
        tag = locale('tags.roll') or 'نرد',
        sender = name,
        id = chatId(source),
        message = ('%s / %s'):format(score, maxRoll),
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.15)',
        borderColor = 'rgba(242, 242, 242, 0.4)',
        icon = 'fa-dice-d20',
        time = os.date('%H:%M')
    }
    sendProximityMessage(source, Config.Distances.Me, payload)
end, false)

-- 8. أمر الرسائل الخاصة (PM)
chatCommand('pm', function(source, args, raw)
    if source == 0 then return end
    if not args[1] then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, w.citizen.reasonText('invalid_id', source))
        return
    end

    -- The recipient is named by his citizen id ('#5' = a server id); a private message is live, so
    -- he has to be in the game. An offline citizen is named in the answer so the sender knows who.
    local target, reason, offline = w.citizen.requireOnline(args[1], { self = source })
    if not target and reason == 'not_found' then
        -- '#5' reaches any connected player, even one with no character in play yet: the chat shows
        -- such a sender as '#5' (chatId), so a reply typed from what is on screen has to land
        local kind, serverId = w.citizen.parse(args[1])
        if kind == 'server' and GetPlayerName(serverId) then target = { source = serverId } end
    end
    if not target then
        local text = w.citizen.reasonText(reason, source)
        if offline then text = ('%s: %s'):format(w.citizen.label(offline), text) end
        TriggerClientEvent('w_chat:client:addSystemMessage', source, text)
        return
    end
    local targetId = target.source

    table.remove(args, 1)
    local text = table.concat(args, ' ')
    if text == '' then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.missing_text') or 'يرجى كتابة الرسالة.')
        return
    end

    local senderName = getPlayerDisplayName(source)
    local targetName = getPlayerDisplayName(targetId)

    -- إشعار الراسل
    -- (the id beside the name is drawn by the interface from `id`: the citizen id to reply to)
    TriggerClientEvent('w_chat:client:addMessage', source, {
        channel = 'pm',
        tag = locale('tags.pm') or 'خاص',
        sender = (locale('messages.pm_to_sender') or 'إلى %s'):format(targetName),
        id = target.citizenid or chatId(targetId),
        message = text,
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.15)',
        borderColor = 'rgba(242, 242, 242, 0.4)',
        icon = 'fa-paper-plane',
        time = os.date('%H:%M')
    })

    -- إشعار المستلم
    TriggerClientEvent('w_chat:client:addMessage', targetId, {
        channel = 'pm',
        tag = locale('tags.pm') or 'خاص',
        sender = (locale('messages.pm_from_sender') or 'من %s'):format(senderName),
        id = chatId(source),
        message = text,
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.15)',
        borderColor = 'rgba(242, 242, 242, 0.4)',
        icon = 'fa-envelope-open-text',
        time = os.date('%H:%M')
    })
end, false)

-- 9. أمر مسح الشات العام (Clearchat)
chatCommand('clearchat', function(source, args, raw)
    if not isPlayerAdmin(source) then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.no_permission') or 'ليس لديك صلاحية.')
        return
    end
    TriggerClientEvent('w_chat:client:clearChat', -1)
    TriggerClientEvent('w_chat:client:addSystemMessage', -1, locale('messages.cleared_all') or 'تم مسح الشات بواسطة الإدارة.')
end, false)

-- 10. أمر إعلان الشرطة (Police)
chatCommand('police', function(source, args, raw)
    if source ~= 0 and not hasPlayerJob(source, Config.Channels.police.job) and not isPlayerAdmin(source) then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.no_permission') or 'ليس لديك صلاحية.')
        return
    end
    local text = table.concat(args, ' ')
    if text == '' then return end
    local name = getPlayerDisplayName(source)

    sendGlobalMessage({
        channel = 'police',
        tag = locale('tags.police') or 'الشرطة',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.police.color,
        bgColor = Config.Channels.police.bgColor,
        borderColor = Config.Channels.police.borderColor,
        icon = Config.Channels.police.icon,
        time = os.date('%H:%M')
    })
end, false)

-- 11. أمر إعلان الإسعاف (Medic)
chatCommand('medic', function(source, args, raw)
    if source ~= 0 and not hasPlayerJob(source, Config.Channels.medic.job) and not isPlayerAdmin(source) then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.no_permission') or 'ليس لديك صلاحية.')
        return
    end
    local text = table.concat(args, ' ')
    if text == '' then return end
    local name = getPlayerDisplayName(source)

    sendGlobalMessage({
        channel = 'medic',
        tag = locale('tags.medic') or 'الإسعاف',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.medic.color,
        bgColor = Config.Channels.medic.bgColor,
        borderColor = Config.Channels.medic.borderColor,
        icon = Config.Channels.medic.icon,
        time = os.date('%H:%M')
    })
end, false)

-- 12. أمر إعلان الإدارة (Announce)
local function handleAnnounce(source, args)
    if not isPlayerAdmin(source) then
        TriggerClientEvent('w_chat:client:addSystemMessage', source, locale('messages.no_permission') or 'ليس لديك صلاحية.')
        return
    end
    local text = table.concat(args, ' ')
    if text == '' then return end
    local name = source == 0 and 'Console' or getPlayerDisplayName(source)

    -- The announcement on everyone's screen as well: w_hud's white text under the compass. An
    -- optional first word sets how long it stays (/ann 5m <text>, /ann 30s <text>; 10 s otherwise).
    if GetResourceState('w_hud') == 'started' then
        pcall(function()
            local seconds, rest = exports.w_hud:SplitDuration(text)
            if seconds then text = rest end
            exports.w_hud:Announce(text, seconds, { by = name })
        end)
    end

    sendGlobalMessage({
        channel = 'admin',
        tag = locale('tags.admin') or 'الإدارة',
        sender = name,
        id = chatId(source),
        message = text,
        color = Config.Channels.admin.color,
        bgColor = Config.Channels.admin.bgColor,
        borderColor = Config.Channels.admin.borderColor,
        icon = Config.Channels.admin.icon,
        time = os.date('%H:%M')
    })
end

chatCommand('ann', handleAnnounce, false)
-- /announce belongs to w_admin when it is on the server (its rights, its log on both panels); two
-- resources holding one command name swap owners on every hot restart (2026-10-22).
-- 1.1.7: w_connector 2.2.2 holds it whenever w_admin is not running (the website decides who may), so
-- this one is only for a server that has neither
if GetResourceState('w_admin') == 'missing' and GetResourceState('w_connector') == 'missing' then
    chatCommand('announce', handleAnnounce, false)
end

-- إرسال قائمة الاقتراحات المبدئية عند انضمام اللاعب
local defaultSuggestions = {
    { name = '/local', help = 'محادثة محلية مسموعة لمن حولك فقط (20 متراً)', params = { { name = 'الرسالة', help = 'نص الكلام المحلي' } } },
    { name = '/l', help = 'اختصار للمحادثة المحلية القريبة', params = { { name = 'الرسالة', help = 'نص الكلام المحلي' } } },
    { name = '/ooc', help = 'إرسال رسالة عامة خارج نطاق الرول بلاي', params = { { name = 'الرسالة', help = 'نص الرسالة' } } },
    { name = '/me', help = 'وصف حركة أو فعل تقوم به شخصيتك', params = { { name = 'الفعل', help = 'ما تفعله الشخصية' } } },
    { name = '/do', help = 'وصف بيئي أو حالة للشخصية', params = { { name = 'الوصف', help = 'تفاصيل البيئة المحيطة' } } },
    { name = '/w', help = 'همس بصوت خافت جداً لمن بجانبك', params = { { name = 'الرسالة', help = 'نص الهمس' } } },
    { name = '/s', help = 'صراخ يسمعه من في المنطقة الواسعة', params = { { name = 'الرسالة', help = 'نص الصراخ' } } },
    { name = '/try', help = 'إجراء محاولة بنسبة نجاح 50%', params = { { name = 'المحاولة', help = 'ما تحاول فعله' } } },
    { name = '/roll', help = 'رمي نرد عشوائي بين 1 و 100', params = { { name = 'الحد الأقصى (اختياري)', help = 'الرقم الأقصى' } } },
    { name = '/pm', help = 'إرسال رسالة خاصة للاعب محدد', params = { { name = 'رقم المواطن', help = 'رقم المواطن الثابت (لرقم السيرفر اكتب # قبله)' }, { name = 'الرسالة', help = 'نص الرسالة' } } },
    { name = '/clear', help = 'مسح سجل الشات المحلي من الشاشة' },
    { name = '/clearchat', help = 'مسح الشات العام لجميع اللاعبين (إدارة)' },
    { name = '/police', help = 'إعلان رسمي لقوات الشرطة والمارشال', params = { { name = 'الإعلان', help = 'نص الإعلان' } } },
    { name = '/medic', help = 'إعلان رسمي من الأطباء والإسعاف', params = { { name = 'الإعلان', help = 'نص الإعلان' } } },
    { name = '/ann', help = 'إرسال إعلان إداري عام للسيرفر', params = { { name = 'الرسالة', help = 'نص الإعلان الإداري' } } },
}

RegisterNetEvent('w_chat:server:requestSuggestions', function()
    local src = source
    for i = 1, #defaultSuggestions do
        local sg = defaultSuggestions[i]
        if not (Config.CommandsOnly and sg.name == '/ooc') then   -- /ooc is off in commands-only mode
            TriggerClientEvent('chat:addSuggestion', src, sg.name, sg.help, sg.params)
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- 1.1.11 (owner 2026-11-06): which commands a player SEES in the list under the input
--   Every suggestion any resource sends (chat:addSuggestion(s)) and the client's own commands go through
--   this filter before the page shows them. A player sees Config.PlayerCommands, his job's commands and
--   any command his ACE allows; staff see every command they may run, plus the commands of our resources
--   (Config.StaffCommandResources) that nobody wrote a help text for. Only what is shown changes here:
--   running a command is still checked by the command itself.
-- ─────────────────────────────────────────────────────────────────────────────
local playerSet = {}
for _, name in ipairs(Config.PlayerCommands or {}) do playerSet[name:lower()] = true end

local function ourResource(res)
    if type(res) ~= 'string' then return false end
    for _, pat in ipairs(Config.StaffCommandResources or {}) do
        if res:find(pat) then return true end
    end
    return false
end

-- server commands by name -> resource (refreshed at most every 30 s)
local serverCmds, serverCmdsAt = {}, 0
local function serverCommands()
    local now = GetGameTimer()
    if now - serverCmdsAt > 30000 or serverCmdsAt == 0 then
        local map = {}
        for _, c in ipairs(GetRegisteredCommands() or {}) do
            if type(c) == 'table' and type(c.name) == 'string' then map[c.name:lower()] = c.resource or '' end
        end
        serverCmds, serverCmdsAt = map, now
    end
    return serverCmds
end

local function maySee(src, name, staff)
    if Config.CommandsOnly and name == 'ooc' then return false end
    if playerSet[name] then return true end
    local channel = Config.JobCommands and Config.JobCommands[name]
    if channel then
        local ch = Config.Channels[channel]
        return staff or (ch and ch.job and hasPlayerJob(src, ch.job)) or false
    end
    if IsPlayerAceAllowed(src, 'command.' .. name) then return true end
    -- a command only the client knows (no server side to check): staff only
    return staff and serverCommands()[name] == nil
end

local filterAt = {}
AddEventHandler('playerDropped', function() filterAt[source] = nil end)

RegisterNetEvent('w_chat:server:filterSuggestions', function(names)
    local src = source
    if type(names) ~= 'table' then return end
    local now = GetGameTimer()
    if filterAt[src] and now - filterAt[src] < 1000 then return end   -- the client batches; once a second at most
    filterAt[src] = now
    local staff = isPlayerAdmin(src)
    local allowed, n = {}, 0
    for i = 1, math.min(#names, 800) do
        local name = names[i]
        if type(name) == 'string' and #name <= 64 then
            name = name:gsub('^/', ''):lower()
            if name ~= '' and maySee(src, name, staff) then
                n = n + 1
                allowed[n] = name
            end
        end
    end
    -- staff also get every command of our resources that nobody suggested
    local extra = {}
    if staff then
        local seen = {}
        for i = 1, #names do if type(names[i]) == 'string' then seen[names[i]:gsub('^/', ''):lower()] = true end end
        for name, res in pairs(serverCommands()) do
            if not seen[name] and ourResource(res) and not name:find('^[%+%-]')
                and IsPlayerAceAllowed(src, 'command.' .. name) then
                extra[#extra + 1] = { name = name, resource = res }
            end
        end
    end
    TriggerClientEvent('w_chat:client:allowedSuggestions', src, allowed, extra, staff)
end)
