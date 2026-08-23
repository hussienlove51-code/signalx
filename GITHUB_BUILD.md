# 🚀 رفع SignalX على GitHub وبناء APK

## الخطوة 1 — أضف Secrets على GitHub

Settings → Secrets and variables → Actions → New repository secret

| الاسم | القيمة |
|-------|--------|
| `SUPABASE_URL` | رابط مشروع Supabase مثل https://xxxx.supabase.co |
| `SUPABASE_ANON_KEY` | المفتاح العام من Supabase |
| `MAPS_API_KEY` | مفتاح Google Maps (من console.cloud.google.com) |

> بدون Secrets يُبنى التطبيق لكن Supabase والخريطة لن تعملا.

---

## الخطوة 2 — أضف ملفات الخط

ضع هذه الملفات في مجلد `assets/fonts/`:
- `Cairo-Regular.ttf`
- `Cairo-Bold.ttf`
- `Cairo-SemiBold.ttf`

**تحميل مجاني:** https://fonts.google.com/specimen/Cairo

---

## الخطوة 3 — ضع بيانات SAS4

في `lib/services/sas4_service.dart` عدّل:
```dart
static const String _baseUrl  = 'http://رابط-سيرفر-SAS4';
static const String _username = 'اسم-المدير';
static const String _password = 'كلمة-المرور';
```

---

## الخطوة 4 — ارفع على GitHub

```bash
git init
git add .
git commit -m "SignalX v1.0 — initial release"
git branch -M main
git remote add origin https://github.com/username/signalx.git
git push -u origin main
```

---

## الخطوة 5 — ابني الـ APK

GitHub → Actions → Build SignalX APK → Run workflow

⏱ ينتهي خلال 8-12 دقيقة

بعد النجاح: Actions → آخر run → Artifacts → **signalx-release-apk**

---

## المشاكل الشائعة

| المشكلة | الحل |
|---------|------|
| البناء فشل بسبب الخطوط | ضع ملفات Cairo في assets/fonts/ |
| الخريطة بيضاء | أضف MAPS_API_KEY في Secrets |
| Supabase لا يتصل | تأكد من SUPABASE_URL و SUPABASE_ANON_KEY |
| SAS4 لا يتصل | تأكد من الـ URL في sas4_service.dart |
