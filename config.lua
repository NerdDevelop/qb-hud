-- NERD HUD - الإعدادات
-- (c) 2026 Nerd. All rights reserved.
--
-- كل اللي بعد `--` هو شرح بالعربي ما يأثر على الكود. القيم نفسها
-- (true/false/الأرقام/أسماء الـ keys) هي اللي تتغير، وأي تعديل عليها
-- يطبّق على كل لاعب في السيرفر.

Config = {}


-- ============ عام ============

Config.Command         = 'hudsettings'   -- اسم الكوماند اللي يفتح بانل الإعدادات للاعب
Config.OpenKey         = nil             -- مفتاح اختصار اختياري (مثل 'F2'). خله nil إذا تبي تعتمد على الكوماند بس
Config.UpdateRate      = 200             -- كم ميلي ثانية بين كل تحديث للستاتس (الصحة/الجوع/إلخ)
Config.VehicleRate     = 100             -- كم ميلي ثانية بين كل تحديث لبيانات السيارة (السرعة/الفيول)
Config.CompassRate     = 200             -- كم ميلي ثانية بين كل تحديث للبوصلة والشارع والمنطقة


-- ============ حدود الستاتس ============

Config.MaxHealth       = 100             -- أعلى قيمة لشريط الصحة (المعادلة الفعلية: GetEntityHealth(ped) - 100)
Config.MaxArmor        = 100             -- أعلى قيمة لشريط الدرع
Config.MaxStamina      = 100             -- أعلى قيمة لشريط الستامينا (القدرة)
Config.MaxOxygen       = 100             -- أعلى قيمة لشريط الأكسجين تحت الماء

-- من وين تجيب قيمة الجوع/العطش. اختر اللي يطابق فريمورك سيرفرك:
--   'qb-core'  -> QBCore PlayerData (الافتراضي على سيرفرات QB)
--   'esx'      -> ESX PlayerData
--   'metadata' -> ميتاداتا اللاعب مباشرة
--   'manual'   -> القيم تجي يدوياً عبر event من سكربتك (شوف nerd-hud:updateHungerThirst)
Config.HungerThirstSource = 'manual'


-- ============ السيارة ============

Config.VehicleMaxSpeed = 350             -- أقصى رقم في عداد السرعة (كم/س)
Config.UseMPH          = false           -- true = ميل، false = كيلو متر


-- ============ الألوان والمؤثرات الافتراضية ============

-- الألوان اللي يشوفها اللاعب أول مرة. اللاعب يقدر يبدلها من /hudsettings
-- ما لم تقفل تاب الألوان من SettingsPanel.colorsTab.
Config.DefaultColors = {
    health  = '#FF3B30',   -- أحمر للصحة
    armor   = '#00A3FF',   -- أزرق للدرع
    hunger  = '#FFB800',   -- أصفر للجوع
    thirst  = '#06B6D4',   -- سماوي للعطش
    stamina = '#00D26A',   -- أخضر للستامينا
    mic     = '#ED0246',   -- وردي لمؤشر المايك
    brand   = '#ED0246',   -- لون البراند العام (التوهج والـ accents)
}

Config.DefaultEffects = {
    crit    = true,    -- نبضة على الستات لو نزل لمستوى حرج
    mic     = true,    -- نبضة على مؤشر المايك وقت الكلام
    ping    = true,    -- نبضة على الـ ping في المينيماب
    live    = true,    -- محاكاة حية / animations عامة
    glow    = 100,     -- قوة التوهج (0-200)، 100 = الافتراضي
    opacity = 85,      -- شفافية الخلفية (40-100)، 85 = الافتراضي
}


-- ============ المايك ============

-- pma-voice هو الخيار الشائع على سيرفرات QBCore
Config.VoiceSystem = 'pma-voice'   -- 'pma-voice' | 'mumble' | 'manual'


-- ============ المينيماب ============

Config.HideDefaultMinimap = false  -- true = إخفاء مينيماب GTA الأصلية كاملة

-- متى تظهر المينيماب:
--   'vehicle' -> تظهر بس وقت ركوب السيارة (الافتراضي)
--   'always'  -> تظهر دايماً
-- اللاعب يقدر يبدلها من /hudsettings إذا SettingsPanel.minimapMode = true.
Config.MinimapMode = 'vehicle'


-- ============ التوتر (Stress) ============
--
-- يرتفع لما:    يسوق بسرعة عالية، يطلق سلاح، يأخذ ضرر
-- ينزل لما:    يدخن (سيجارة = مهدّئ)
-- محفوظ في:    metadata.stress (QBCore) ويرجع لما يدخل اللاعب مرة ثانية

Config.DisableStress           = true  -- true = تعطيل نظام التوتر كاملاً
Config.StressMinSpeed          = 100    -- أقل سرعة (مع حزام) قبل ما يبدأ التوتر يرتفع
Config.StressMinSpeedUnbuckled = 80     -- أقل سرعة (بدون حزام) قبل ما يبدأ التوتر يرتفع
Config.StressShootChance       = 0.10   -- احتمالية رفع التوتر لكل طلقة (0.0 إلى 1.0)
Config.SmokeRelief             = 5      -- كم ينزل التوتر مع كل tick من التدخين
Config.SmokeInterval           = 1500   -- كم ميلي ثانية بين كل tick من التدخين
Config.MinimumStressFX         = 50     -- مؤثرات الشاشة تبدأ من هذا المستوى

-- أسلحة ما تسبب توتر (طفاية، كشاف، taser، إلخ)
Config.WhitelistedWeaponStress = {
    [`WEAPON_UNARMED`]          = true,
    [`WEAPON_FIST`]             = true,
    [`WEAPON_PETROLCAN`]        = true,
    [`WEAPON_HAZARDCAN`]        = true,
    [`WEAPON_FIREEXTINGUISHER`] = true,
    [`WEAPON_STUNGUN`]          = true,
    [`WEAPON_FLASHLIGHT`]       = true,
    [`WEAPON_BALL`]             = true,
    [`WEAPON_SNOWBALL`]         = true,
    [`WEAPON_FLARE`]            = true,
}

-- فئات السيارات اللي ترفع التوتر عند السرعة العالية.
-- المرجع: https://docs.fivem.net/natives/?_0x29439776AAA00A62
Config.VehClassStress = {
    ['0']  = true,   -- Compacts (صغيرة)
    ['1']  = true,   -- Sedans (سيدان)
    ['2']  = true,   -- SUVs
    ['3']  = true,   -- Coupes
    ['4']  = true,   -- Muscle
    ['5']  = true,   -- Sports Classics
    ['6']  = true,   -- Sports
    ['7']  = true,   -- Super
    ['8']  = true,   -- Motorcycles (دبابات)
    ['9']  = false,  -- Off-road (طلعات)
    ['10'] = false,  -- Industrial
    ['11'] = false,  -- Utility
    ['12'] = false,  -- Vans
    ['13'] = false,  -- Cycles (دراجات هوائية)
    ['14'] = false,  -- Boats
    ['15'] = false,  -- Helicopters
    ['16'] = false,  -- Planes
    ['17'] = false,  -- Service
    ['18'] = false,  -- Emergency
    ['19'] = false,  -- Military
    ['20'] = false,  -- Commercial
    ['21'] = false,  -- Trains
}

-- هاشات سيارات معينة تنّقذ من التوتر حتى لو فئتها مفعّلة فوق
Config.WhitelistedVehicles = {
    -- [`adder`] = true,
}

-- وظايف ما يطلع لها توتر إطلاقاً
Config.WhitelistedJobs = {
    ['police']    = 'leo',
    ['ambulance'] = 'ems',
}

-- قوة الـ blur على الشاشة حسب مستوى التوتر
Config.StressIntensity = {
    { min = 50,  max = 60,  intensity = 2000 },
    { min = 60,  max = 70,  intensity = 3000 },
    { min = 70,  max = 80,  intensity = 4000 },
    { min = 80,  max = 100, intensity = 6000 },
}

-- الفترة بين كل تأثير شاشة (ملي ثانية)، حسب مستوى التوتر
Config.StressEffectInterval = {
    { min = 50, max = 60,  timeout = 60000 },
    { min = 60, max = 70,  timeout = 45000 },
    { min = 70, max = 80,  timeout = 30000 },
    { min = 80, max = 100, timeout = 15000 },
}


-- ============ مفاتيح إيقاف العناصر ============
--
-- خل أي قيمة هنا = false، وذاك العنصر ما يطلع في الـ HUD أبداً.
-- مفيد لو فيه سكربت ثاني يعرض نفس الستات، أو ما تبيه أصلاً.

Config.Elements = {
    health    = true,
    armor     = true,
    hunger    = true,
    thirst    = true,
    stamina   = true,
    oxygen    = true,   -- شريط الأكسجين تحت الماء
    mic       = true,
    stress    = true,
    parachute = true,
    compass   = true,   -- البوصلة + اسم الشارع/المنطقة
    speedo    = true,   -- عداد السرعة داخل السيارة
    seatbelt  = true,   -- مؤشر حزام الأمان على العداد
    engine    = true,   -- مؤشر صحة المحرك على العداد
    minimap   = true,   -- مينيماب GTA (الخريطة المربعة)
}


-- ============ تحكّم بانل الإعدادات ============
--
-- true  = السطر يظهر في /hudsettings ويقدر اللاعب يبدّله
-- false = السطر يتخفى، والقيمة تتقفل على الديفلت من هذا الملف
--
-- مثال: تبي كل لاعب يكون عنده المينيماب تظهر بس داخل السيارة، بدون استثناء:
--     Config.SettingsPanel.minimapMode = false
--     Config.MinimapMode               = 'vehicle'

Config.SettingsPanel = {
    colorsTab    = true,   -- تاب الألوان كاملة (ألوان الستاتس + لون البراند)
    dragMode     = true,   -- وضع السحب (تحريك العناصر بالماوس)
    mouseResize  = true,   -- تكبير/تصغير بعجلة الماوس
    hideCompass  = true,   -- toggle إخفاء البوصلة
    hideStats    = true,   -- toggle إخفاء شريط الستاتس
    minimapMode  = true,   -- toggle "إظهار الخريطة دايماً"
    hudSize      = true,   -- سلايدر حجم الـ HUD العام
    lowStatPulse = true,   -- toggle نبضة الستات المنخفض
    micPulse     = true,   -- toggle نبضة المايك
    glow         = true,   -- سلايدر قوة التوهج
    opacity      = true,   -- سلايدر شفافية الخلفية
    cinemaMode   = true,   -- toggle سنما مود (خطوط سوداء + إخفاء HUD)
}


-- ============ الديفلتات المقفلة ============
--
-- هذي تكمل DefaultColors / DefaultEffects أعلاه. لو السطر المناظر في
-- SettingsPanel = false، القيمة هنا هي اللي تتطبق على اللاعب وأي حفظ
-- قديم في الـ KVP يتجاهل.

Config.DefaultHideCompass = false  -- false = البوصلة ظاهرة من البداية
Config.DefaultHideStats   = false  -- false = شريط الستاتس ظاهر من البداية
Config.DefaultHudSize     = 100    -- 70..150 (بالمية)
Config.DefaultCinemaMode  = false  -- false = سنما مود مطفي
