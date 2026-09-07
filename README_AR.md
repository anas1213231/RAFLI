# RAFLI iOS Native V5 — ULTRA ENGINE + PUBLISH GUARD

V5 تضيف طبقة تحقق بعد الرفع الرسمي، بدل أن ينتهي التطبيق عند "تم الإرسال".

## المحرك
- Native iOS / AVFoundation + Core Image
- H.264 High Profile + CABAC
- 1080×1920 أو 1920×1080
- ULTRA MAX حتى 30 Mbps
- AAC 48 kHz / 256 kbps
- GOP مضبوط
- Fast Start
- FPS حقيقي من المصدر حتى 60fps، بدون 30→60 وهمي

## طرق النشر
1. Save Exact Export إلى Photos
2. Save + Open TikTok
3. Official TikTok Draft Upload عبر خادم RAFLI

## الجديد في V5: Publish Guard
بعد Official Upload يحتفظ التطبيق بـ `publish_id` ويستطيع فحص:
- PROCESSING_UPLOAD
- SEND_TO_USER_INBOX
- PUBLISH_COMPLETE
- FAILED + سبب الفشل
- uploaded_bytes

Backend يستخدم TikTok الرسمي:
`POST /v2/post/publish/status/fetch/`

## الأمان
Client Secret وRefresh Token لا يدخلان الـIPA إطلاقًا؛ يبقيان في الخادم.

## البناء
شغّل GitHub Actions:
`.github/workflows/build-unsigned-ipa.yml`

ثم حمّل Unsigned IPA ووقّعه بشهادتك عبر ESign.

## ملاحظة واقعية
RAFLI يستطيع إنتاج ملف مصدر قوي ومتوافق ومتابعة حالة الرفع الرسمية، لكنه لا يستطيع إجبار خوادم TikTok على الاحتفاظ بbitrate أو rendition معيّن بعد المعالجة.
