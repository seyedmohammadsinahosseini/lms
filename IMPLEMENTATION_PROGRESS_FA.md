# برنامه و وضعیت اجرای LMS

**شاخهٔ انتشار:** `portfolio/lms-rebrand`
**مبنای این مرحله:** `ce11318`
**تاریخ به‌روزرسانی:** ۱۴۰۵/۰۷/۱۷ (2026-10-09)
**قاعده:** هیچ قابلیت موردنیاز حذف یا پنهان نشده است؛ هر اصلاح باید قابلیت را واقعاً قابل استفاده نگه دارد.

## مراحل انجام‌شده

- [x] ۰. ثبت baseline و نگه‌داشتن تاریخچهٔ کامل تغییرات
- [x] ۱. زیرساخت backend: خطای استاندارد، validation، token hash، rate limit، audit و migration
- [x] ۲. عضویت امن با grant یک‌بارمصرف، فایل خصوصی، signed URL و transaction
- [x] ۳. lifecycle/versioning آزمون، snapshot، زمان‌بندی و شش نوع سؤال
- [x] ۴. نسخه‌بندی تکلیف، deadline/late/resubmit و feedback
- [x] ۵. Profile/password، داشبورد واقعی، Q&A و زیرساخت Live session
- [x] ۶. رابط Flutter واکنش‌گرا و phone-first و اتصال همهٔ مسیرهای فعال به API
- [x] ۷. secure storage، HTTPS release policy و تنظیم signing اندروید
- [x] ۸. تست‌های API/امنیت/Flutter، CI و مستندات
- [x] ۹. demo sandbox ایزوله، API نسخهٔ `v1`، بستهٔ deployment و مسیر release امضاشده
- [x] ۱۰. تغییر کامل و دائمی هویت پروژه به **LMS**، namespace اندروید، آیکون، README حرفه‌ای، نمودار معماری و اسکرین‌شات‌های واقعی رابط
- [ ] ۱۱. تأیید CI شاخهٔ نهایی، ادغام در `main` و عمومی‌کردن repository
- [ ] ۱۲. استقرار آنلاین و تولید APK امضاشدهٔ واقعی — نیازمند حساب میزبانی و keystore مالک

## نتیجه‌های تأییدشده در 2026-10-09

- تمام فایل‌های PHP با PHP 8.4 lint شده‌اند.
- `shellcheck` و parse تمام اسکریپت‌های shell بدون خطا یا هشدار است.
- schema تازه روی MariaDB 11.8 import شده و **۲۶ جدول** ساخته است.
- migration نگه‌دارنده روی schema قدیمی اجرا و marker نسخهٔ خود را ثبت کرده است.
- seed محلی روی schema تازه import شده و fixtureهای آن بررسی شده‌اند.
- مجموعهٔ lifecycle با **۴۸ تست از ۴۸ تست موفق** روی `api/v1` اجرا شد.
- مجموعهٔ امنیتی با **۲۲ تست از ۲۲ تست موفق** اجرا شد.
- `flutter analyze` بدون issue و **۲۵ تست از ۲۵ تست Flutter** موفق بوده‌اند.
- Flutter Web release با Flutter 3.47.6 به‌صورت محلی ساخته شد.
- Playwright بوت نسخهٔ Web را در viewport گوشی بدون خطای runtime/asset تأیید کرد.
- build نسخهٔ showcase در حالت release موفق شد و چهار تصویر login، داشبورد معلم، داشبورد دانش‌آموز و فضای کلاس از خود Flutter تولید شدند.
- یک ایراد واقعی Material در sidebar دسکتاپ هنگام تولید تصاویر کشف، اصلاح و با widget test جدید پوشش داده شد.
- باقی‌ماندهٔ هویت قدیمی در درخت پروژه صفر است؛ مسیر نهایی Flutter برابر `lms_flutter/` است.
- application ID نهایی اندروید: `io.github.seyedmohammadsinahosseini.lms`

## خروجی‌های آماده

- `README.md`: معرفی انگلیسی portfolio، قابلیت‌ها، امنیت، معماری، evidence و راه‌اندازی
- `docs/images/`: لوگو، نمودار معماری و چهار screenshot واقعی رابط
- `.github/workflows/ci.yml`: PHP/schema/migration/API/security، Flutter، Web و Android
- `.github/workflows/screenshots.yml`: بازتولید deterministic تصاویر portfolio
- `.github/workflows/release-android.yml`: ساخت و verify کردن APK امضاشده و GitHub Release
- `tools/package_deployment.sh`: بستهٔ هم‌دامنه و مستقل از شرکت میزبان
- `tools/package_serv00.sh`: adapter آماده برای Serv00 با `public_html` و private storage
- `tools/build_signed_apk.sh`: APK universal با SHA-256 و بدون fallback به debug signing
- `docs/استقرار-رایگان.md`: راهنمای سادهٔ استقرار دمو
- `docs/انتشار-اندروید.md`: راهنمای keystore، secretها و release

## موارد بیرونی باقیمانده

1. اجرای CI روی commit نهایی و ادغام حرفه‌ای در `main`
2. عمومی‌کردن `seyedmohammadsinahosseini/lms` و تنظیم description/topics
3. ساخت و backup کردن keystore مالک و افزودن GitHub Secrets
4. استقرار روی Foojan در صورت سازگاری کامل؛ Serv00 به‌عنوان fallback
5. برای Live تولیدی، دریافت credentialهای JaaS
6. اجرای نهایی روی گوشی واقعی و انتشار artifact امضاشده
