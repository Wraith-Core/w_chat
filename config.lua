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
Config.Channels = {
    localChat = {
        name = 'local',
        tag = 'محلي | Local',
        icon = 'fa-location-dot',
        color = '#E0E0E0',
        bgColor = 'rgba(255, 255, 255, 0.08)',
        borderColor = 'rgba(255, 255, 255, 0.3)'
    },
    ooc = {
        name = 'ooc',
        tag = 'OOC',
        icon = 'fa-comments',
        color = '#EDEDED',
        bgColor = '#1f1f1f',
        borderColor = 'rgba(255, 255, 255, 0.25)'
    },
    me = {
        name = 'me',
        tag = 'ME',
        icon = 'fa-user',
        color = '#E5A93C',
        bgColor = 'rgba(229, 169, 60, 0.12)',
        borderColor = 'rgba(229, 169, 60, 0.35)'
    },
    doChannel = {
        name = 'do',
        tag = 'DO',
        icon = 'fa-eye',
        color = '#9C6ADE',
        bgColor = 'rgba(156, 106, 222, 0.12)',
        borderColor = 'rgba(156, 106, 222, 0.35)'
    },
    whisper = {
        name = 'whisper',
        tag = 'همس',
        icon = 'fa-comment-dots',
        color = '#64B5F6',
        bgColor = 'rgba(100, 181, 246, 0.12)',
        borderColor = 'rgba(100, 181, 246, 0.35)'
    },
    shout = {
        name = 'shout',
        tag = 'صراخ',
        icon = 'fa-bullhorn',
        color = '#FF7043',
        bgColor = 'rgba(255, 112, 67, 0.15)',
        borderColor = 'rgba(255, 112, 67, 0.4)'
    },
    tryChannel = {
        name = 'try',
        tag = 'قرعة',
        icon = 'fa-dice',
        successColor = '#4CAF50',
        failColor = '#CB0101'
    },
    police = {
        name = 'police',
        tag = 'الشرطة',
        icon = 'fa-shield-halved',
        color = '#3884ff',
        bgColor = 'rgba(56, 132, 255, 0.15)',
        borderColor = 'rgba(56, 132, 255, 0.4)',
        job = 'police'
    },
    medic = {
        name = 'medic',
        tag = 'الإسعاف',
        icon = 'fa-staff-snake',
        color = '#26A69A',
        bgColor = 'rgba(38, 166, 154, 0.15)',
        borderColor = 'rgba(38, 166, 154, 0.4)',
        job = 'ambulance'
    },
    admin = {
        name = 'admin',
        tag = 'الإدارة',
        icon = 'fa-crown',
        color = '#CB0101',
        bgColor = 'rgba(203, 1, 1, 0.18)',
        borderColor = 'rgba(203, 1, 1, 0.45)',
        permission = 'admin'
    },
    system = {
        name = 'system',
        tag = 'النظام',
        icon = 'fa-gear',
        color = '#EDEDED',
        bgColor = '#1f1f1f',
        borderColor = 'rgba(255, 255, 255, 0.3)'
    }
}

-- ألوان وتنسيقات رتب اللاعبين
Config.Ranks = {
    god = {
        label = 'مطور',
        color = '#E53935',
        bgColor = 'rgba(229, 57, 53, 0.2)',
        borderColor = 'rgba(229, 57, 53, 0.5)',
        icon = 'fa-crown',
    },
    admin = {
        label = 'إدارة',
        color = '#CB0101',
        bgColor = 'rgba(203, 1, 1, 0.2)',
        borderColor = 'rgba(203, 1, 1, 0.5)',
        icon = 'fa-shield-halved',
    },
    mod = {
        label = 'مشرف',
        color = '#FB8C00',
        bgColor = 'rgba(251, 140, 0, 0.2)',
        borderColor = 'rgba(251, 140, 0, 0.5)',
        icon = 'fa-user-shield',
    },
    vip = {
        label = 'VIP',
        color = '#FDD835',
        bgColor = 'rgba(253, 216, 53, 0.2)',
        borderColor = 'rgba(253, 216, 53, 0.5)',
        icon = 'fa-star',
    },
}
