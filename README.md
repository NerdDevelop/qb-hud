# NERD HUD · FiveM Resource

سكربت HUD احترافي لـ FiveM بتصميم NERD الفريد (شفرات متوازية).

## صور

![NERD HUD - screenshot 1](https://i.ibb.co/FLTgXS7P/image.png)

![NERD HUD - screenshot 2](https://i.ibb.co/ycz2RGGJ/image.png)

## التركيب

1. انسخ مجلد `nerd-hud` كامل إلى مجلد `resources` في سيرفرك:
   ```
   resources/
     └── nerd-hud/
         ├── fxmanifest.lua
         ├── config.lua
         ├── client.lua
         ├── README.md
         └── html/
             ├── index.html
             ├── style.css
             ├── script.js
             └── nerd-theme.css
   ```

2. أضف للـ `server.cfg`:
   ```
   ensure nerd-hud
   ```

3. أعد تشغيل السيرفر أو شغّل الريسورس مباشرة:
   ```
   refresh
   start nerd-hud
   ```

## الكوماندز

| الكوماند | الوظيفة |
|---------|---------|
| `/hudsettings` | فتح لوحة إعدادات الـ HUD |
| `/hudtoggle`   | إخفاء/إظهار الـ HUD كاملاً |

## الميزات

- **شفرات متوازية** للستاتس (هوية NERD)
- بوصلة مع اسم الشارع والمنطقة
- عداد سرعة دائري + شريط فيول وانجن (Blade Pattern)
- مؤشر مايك (يدعم pma-voice)
- مؤشر أوكسجين (يطلع تلقائياً تحت الماء)
- لوحة إعدادات كاملة (ألوان/ترتيب/تأثيرات)
- وضع السحب لتحريك العناصر
- حفظ الإعدادات لكل لاعب

## التهيئة (config.lua)

### الكوماند
```lua
Config.Command = 'hudsettings'   -- اسم الكوماند
Config.OpenKey = 'F2'            -- مفتاح اختياري (اتركه nil للكوماند فقط)
```

### مصدر الجوع/العطش
```lua
Config.HungerThirstSource = 'qb-core'  -- 'qb-core' | 'esx' | 'manual'
```

### عداد السرعة
```lua
Config.UseMPH = false              -- false = km/h
Config.VehicleMaxSpeed = 350       -- الحد الأقصى للعداد
```

### نظام الصوت
```lua
Config.VoiceSystem = 'pma-voice'   -- 'pma-voice' | 'mumble' | 'manual'
```

## التحكم اليدوي (Events)

### تحديث الجوع/العطش (للسيرفرات اللي ما تستخدم QBCore/ESX)
```lua
TriggerEvent('nerd-hud:updateHungerThirst', 75, 60)
-- hunger = 75%, thirst = 60%
```

### تفعيل/إيقاف الميك يدوياً
```lua
TriggerEvent('nerd-hud:setMic', true)   -- ON
TriggerEvent('nerd-hud:setMic', false)  -- OFF
```

## التكامل مع QBCore

السكربت يستمع تلقائياً لـ:
- `hud:client:UpdateNeeds` (للجوع/العطش)
- `pma-voice:setTalkingMode` (للمايك)

### pma-voice (المايك):
- **3 مستويات** يقرأها السكربت تلقائياً:
  - `1` = هَمس (Whisper) — شريط ربع تقريباً
  - `2` = عادي (Normal) — شريط نصف
  - `3` = صياح (Shout) — شريط كامل
- لما تغيّر المستوى من pma-voice (افتراضياً مفتاح `Z`)، الـ HUD يتحدث فوراً
- لما تتكلم فعلاً، الأيقونة تنبض (ضغطة الـ N للتكلم)
- لو تستخدم الراديو، الأيقونة تتحول لبرتقالية

## التكامل مع ESX

يستمع تلقائياً لـ:
- `esx_status:onTick` (للجوع/العطش)
- ESX PlayerData metadata

## استخدام الإعدادات

1. اكتب في الشات: `/hudsettings`
2. تفتح اللوحة (الفأرة تشتغل في الـ NUI)
3. غيّر الألوان / الترتيب / التأثيرات
4. اضغط **حفظ** (الإعدادات تتحفظ بشكل دائم لحسابك)
5. اضغط **ESC** أو زر الإغلاق للخروج

### وضع السحب
- في تاب "الترتيب"، فعّل **وضع السحب**
- اسحب أي عنصر بالماوس
- اضغط **R** لإرجاع كل شي للوضع الافتراضي
- احفظ لما تخلص

## الستاتس المعروضة

| الستات | المصدر |
|-------|--------|
| Health | `GetEntityHealth(ped)` |
| Armor | `GetPedArmour(ped)` |
| Hunger | حسب `Config.HungerThirstSource` |
| Thirst | حسب `Config.HungerThirstSource` |
| Stamina | `GetPlayerSprintStaminaRemaining` |
| Oxygen | `GetPlayerUnderwaterTimeRemaining` (يطلع تحت الماء) |
| Mic | حسب `Config.VoiceSystem` |

## الدعم

- النسخة: 1.0.0
- الأطر المدعومة: QBCore · ESX · Standalone
- الفريم ريت: 200ms للستاتس · 100ms للسيارة

## المؤلف

**Sultan** — NERD Dev Service
