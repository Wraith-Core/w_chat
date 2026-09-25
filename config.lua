Config = {}

-- اللغة الافتراضية إذا لم تكن محددة من w_lib (ar | en)
Config.DefaultLocale = 'ar'

-- مدة بقاء الرسائل مرئية قبل التلاشي التلقائي (بالمللي ثانية)
Config.FadeTimeout = 8500

-- الحد الأقصى لطول الرسالة
Config.MaxMessageLength = 250

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
-- ★ أبيض وأسود مثل ريد ديد: كل القنوات بلون الورق (#EDE6D6) أو الورق الباهت (#B9AF9C)، وتُعرف القناة
--   بكلمتها وأيقونتها لا بلونها. الأحمر الوحيد (#CB0101) علامة فقط، وتضعه الواجهة (web/style.css)
--   شريطًا بجانب إعلان الإدارة وسطر الخطأ، ولا يُكتب به نص أبدًا.
--   (Black and white like Red Dead: paper or dim paper only; a channel is told by its word and glyph.)
Config.Channels = {
    localChat = {
        name = 'local',
        tag = 'محلي | Local',
        icon = 'fa-location-dot',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.08)',
        borderColor = 'rgba(237, 230, 214, 0.3)'
    },
    ooc = {
        name = 'ooc',
        tag = 'OOC',
        icon = 'fa-comments',
        color = '#EDE6D6',
        bgColor = '#15130F',
        borderColor = 'rgba(237, 230, 214, 0.25)'
    },
    me = {
        name = 'me',
        tag = 'ME',
        icon = 'fa-user',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.12)',
        borderColor = 'rgba(237, 230, 214, 0.35)'
    },
    doChannel = {
        name = 'do',
        tag = 'DO',
        icon = 'fa-eye',
        color = '#B9AF9C',
        bgColor = 'rgba(185, 175, 156, 0.12)',
        borderColor = 'rgba(185, 175, 156, 0.35)'
    },
    whisper = {
        name = 'whisper',
        tag = 'همس',
        icon = 'fa-comment-dots',
        color = '#B9AF9C',
        bgColor = 'rgba(185, 175, 156, 0.12)',
        borderColor = 'rgba(185, 175, 156, 0.35)'
    },
    shout = {
        name = 'shout',
        tag = 'صراخ',
        icon = 'fa-bullhorn',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.15)',
        borderColor = 'rgba(237, 230, 214, 0.4)'
    },
    tryChannel = {
        name = 'try',
        tag = 'قرعة',
        icon = 'fa-dice',
        -- النجاح والفشل تقولهما الكلمة [نجاح] / [فشل]، لا اللون
        successColor = '#EDE6D6',
        failColor = '#B9AF9C'
    },
    police = {
        name = 'police',
        tag = 'الشرطة',
        icon = 'fa-shield-halved',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.15)',
        borderColor = 'rgba(237, 230, 214, 0.4)',
        job = 'police'
    },
    medic = {
        name = 'medic',
        tag = 'الإسعاف',
        icon = 'fa-staff-snake',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.15)',
        borderColor = 'rgba(237, 230, 214, 0.4)',
        job = 'ambulance'
    },
    admin = {
        name = 'admin',
        tag = 'الإدارة',
        icon = 'fa-crown',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.18)',
        borderColor = 'rgba(237, 230, 214, 0.45)',
        permission = 'admin'
    },
    system = {
        name = 'system',
        tag = 'النظام',
        icon = 'fa-gear',
        color = '#EDE6D6',
        bgColor = '#15130F',
        borderColor = 'rgba(237, 230, 214, 0.3)'
    }
}

-- ألوان وتنسيقات رتب اللاعبين
-- ★ الرتبة شريط ورق بحبر داكن في الواجهة؛ تُعرف بكلمتها وأيقونتها (التاج، الدرع، النجمة)، لا بلون.
Config.Ranks = {
    god = {
        label = 'مطور',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.2)',
        borderColor = 'rgba(237, 230, 214, 0.5)',
        icon = 'fa-crown',
    },
    admin = {
        label = 'إدارة',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.2)',
        borderColor = 'rgba(237, 230, 214, 0.5)',
        icon = 'fa-shield-halved',
    },
    mod = {
        label = 'مشرف',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.2)',
        borderColor = 'rgba(237, 230, 214, 0.5)',
        icon = 'fa-user-shield',
    },
    vip = {
        label = 'VIP',
        color = '#EDE6D6',
        bgColor = 'rgba(237, 230, 214, 0.2)',
        borderColor = 'rgba(237, 230, 214, 0.5)',
        icon = 'fa-star',
    },
}
