Config = {}

-- اللغة الافتراضية إذا لم تكن محددة من w_lib (ar | en)
Config.DefaultLocale = 'ar'

-- مدة بقاء الرسائل مرئية قبل التلاشي التلقائي (بالمللي ثانية)
Config.FadeTimeout = 8500

-- الحد الأقصى لطول الرسالة
Config.MaxMessageLength = 250
Config.FloodMax = 6           -- messages a player may send (chat + chat commands) per window; more are dropped
Config.FloodWindowMs = 10000  -- the flood window (audit 2026-10-18)

-- زر فتح الشات الافتراضي (RedM Key Mapping)
Config.DefaultKey = 'T'

-- هل تظهر نصوص 3D ثلاثية الأبعاد فوق رأس الشخصية عند كتابة /me و /do؟
Config.Enable3DText = true
Config.Display3DDuration = 7000 -- مدة بقاء النص الثلاثي الأبعاد بالمللي ثانية

-- مسافات قنوات القرب (بالأمتار)
Config.Distances = {
    Local = 20.0,
    Me = 15.0,
    Do = 15.0,
    Whisper = 4.0,
    Shout = 32.0,
    OocProximity = false, -- إذا كان true تصبح رسائل OOC قريبة، وإذا false تكون عامة للسيرفر
    OocDistance = 20.0,
}

-- ألوان وتنسيقات القنوات الأساسية
-- ★ أبيض وأسود مثل ريد ديد: كل القنوات بلون الورق (#F2F2F2) أو الورق الباهت (#B4B4B4)، وتُعرف القناة
--   بكلمتها وأيقونتها لا بلونها. الأحمر الوحيد (#CB0101) علامة فقط، وتضعه الواجهة (web/style.css)
--   شريطًا بجانب إعلان الإدارة وسطر الخطأ، ولا يُكتب به نص أبدًا.
--   (Black and white like Red Dead: paper or dim paper only; a channel is told by its word and glyph.)
Config.Channels = {
    localChat = {
        name = 'local',
        tag = 'محلي | Local',
        icon = 'fa-location-dot',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.08)',
        borderColor = 'rgba(242, 242, 242, 0.3)'
    },
    ooc = {
        name = 'ooc',
        tag = 'OOC',
        icon = 'fa-comments',
        color = '#F2F2F2',
        bgColor = '#111111',
        borderColor = 'rgba(242, 242, 242, 0.25)'
    },
    me = {
        name = 'me',
        tag = 'ME',
        icon = 'fa-user',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.12)',
        borderColor = 'rgba(242, 242, 242, 0.35)'
    },
    doChannel = {
        name = 'do',
        tag = 'DO',
        icon = 'fa-eye',
        color = '#B4B4B4',
        bgColor = 'rgba(180, 180, 180, 0.12)',
        borderColor = 'rgba(180, 180, 180, 0.35)'
    },
    whisper = {
        name = 'whisper',
        tag = 'همس',
        icon = 'fa-comment-dots',
        color = '#B4B4B4',
        bgColor = 'rgba(180, 180, 180, 0.12)',
        borderColor = 'rgba(180, 180, 180, 0.35)'
    },
    shout = {
        name = 'shout',
        tag = 'صراخ',
        icon = 'fa-bullhorn',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.15)',
        borderColor = 'rgba(242, 242, 242, 0.4)'
    },
    tryChannel = {
        name = 'try',
        tag = 'قرعة',
        icon = 'fa-dice',
        -- النجاح والفشل تقولهما الكلمة [نجاح] / [فشل]، لا اللون
        successColor = '#F2F2F2',
        failColor = '#B4B4B4'
    },
    police = {
        name = 'police',
        tag = 'الشرطة',
        icon = 'fa-shield-halved',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.15)',
        borderColor = 'rgba(242, 242, 242, 0.4)',
        job = 'police'
    },
    medic = {
        name = 'medic',
        tag = 'الإسعاف',
        icon = 'fa-staff-snake',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.15)',
        borderColor = 'rgba(242, 242, 242, 0.4)',
        job = 'doctor' -- w_medic's job (was 'ambulance', w_ambulancejob)
    },
    admin = {
        name = 'admin',
        tag = 'الإدارة',
        icon = 'fa-crown',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.18)',
        borderColor = 'rgba(242, 242, 242, 0.45)',
        permission = 'admin'
    },
    system = {
        name = 'system',
        tag = 'النظام',
        icon = 'fa-gear',
        color = '#F2F2F2',
        bgColor = '#111111',
        borderColor = 'rgba(242, 242, 242, 0.3)'
    }
}

-- ألوان وتنسيقات رتب اللاعبين
-- ★ الرتبة شريط ورق بحبر داكن في الواجهة؛ تُعرف بكلمتها وأيقونتها (التاج، الدرع، النجمة)، لا بلون.
--   1.1.2: only the store's VIP tiers have a hue (owner 2026-10-21).
Config.Ranks = {
    god = {
        label = 'مطور',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.2)',
        borderColor = 'rgba(242, 242, 242, 0.5)',
        icon = 'fa-crown',
    },
    admin = {
        label = 'إدارة',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.2)',
        borderColor = 'rgba(242, 242, 242, 0.5)',
        icon = 'fa-shield-halved',
    },
    mod = {
        label = 'مشرف',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.2)',
        borderColor = 'rgba(242, 242, 242, 0.5)',
        icon = 'fa-user-shield',
    },
    vip = {
        label = 'VIP',
        color = '#F2F2F2',
        bgColor = 'rgba(242, 242, 242, 0.2)',
        borderColor = 'rgba(242, 242, 242, 0.5)',
        icon = 'fa-star',
    },
    -- 1.1.2: the store's VIP tiers (w_vip): each tier's own band (bgColor) and ink (color), '#rrggbb' only.
    -- The staff ranks always come first; the plain `vip` above stays for a 'wcore.vip' given by hand.
    vip_bronze = {
        label = 'VIP برونزي',
        color = '#1A0F06',
        bgColor = '#B4773F',
        borderColor = '#7A4E26',
        icon = 'fa-star',
    },
    vip_silver = {
        label = 'VIP فضي',
        color = '#15181B',
        bgColor = '#C3C8CE',
        borderColor = '#8C939B',
        icon = 'fa-star',
    },
    vip_gold = {
        label = 'VIP ذهبي',
        color = '#1E1604',
        bgColor = '#D9B44A',
        borderColor = '#9C7F26',
        icon = 'fa-star',
    },
    vip_platinum = {
        label = 'VIP بلاتيني',
        color = '#101A22',
        bgColor = '#A9BCCB',
        borderColor = '#6F8496',
        icon = 'fa-gem',
    },
    vip_diamond = {
        label = 'VIP ماسي',
        color = '#05222C',
        bgColor = '#8FDDF2',
        borderColor = '#4FA9C2',
        icon = 'fa-gem',
    },
}

-- 1.1.2: exports.w_vip:Tier (1..5) -> its key in Config.Ranks
Config.VipTiers = { 'vip_bronze', 'vip_silver', 'vip_gold', 'vip_platinum', 'vip_diamond' }

-- 1.1.3 (2026-10-21): the colour of a name bought in the server store («لون اسم مميز في الدردشة»)
Config.StoreNameColor = '#E8B84A'
