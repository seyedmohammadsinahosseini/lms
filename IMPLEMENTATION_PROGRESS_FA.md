# برنامه و وضعیت اجرای اصلاحات OTMS

**شاخه:** `feat/full-remediation`
**مبنای شروع:** `c89f74a`
**تاریخ به‌روزرسانی:** ۱۴۰۵/۰۷/۱۰ (2026-10-02)
**قاعده:** هیچ قابلیت موردنیاز حذف نشده است؛ اصلاح باید قابلیت را واقعاً قابل استفاده کند.

## مراحل

- [x] ۰. ساخت شاخه، ثبت baseline و حذف remote حساس
- [x] ۱. زیرساخت backend: خطای استاندارد، validation، token hash، rate limit، audit و migration
- [x] ۲. عضویت امن با grant یک‌بارمصرف، فایل خصوصی، signed URL و transaction
- [x] ۳. lifecycle/versioning آزمون، snapshot، زمان‌بندی و انواع سؤال
- [x] ۴. نسخه‌بندی تکلیف، deadline/late/resubmit و feedback
- [x] ۵. Profile/password، داشبورد واقعی، Q&A و زیرساخت Live session
- [x] ۶. Flutter phone-first responsive و اتصال همهٔ مسیرهای فعال به API
- [x] ۷. secure storage، HTTPS release policy، Android package/signing configuration
- [x] ۸. تست‌های API/امنیت/Flutter، CI و مستندات جاری
- [x] ۹. demo sandbox، API نسخهٔ `v1`، بستهٔ deployment و مسیر release امضاشده
- [ ] ۱۰. استقرار آنلاین و تولید APK واقعی — نیازمند حساب میزبانی، application ID و keystore مالک

## نتیجه‌های تأییدشده

- تمام فایل‌های PHP با PHP 8.4 lint شده‌اند.
- schema تازه روی MariaDB 11.8 import شده و ۲۶ جدول ساخته است.
- migration نگهدارنده روی یک کپی از schema و دادهٔ baseline اجرا شده، شمارش
  کاربران/کلاس‌ها/آزمون‌ها را حفظ کرده و version خود را ثبت کرده است.
- `tools/demo_seed.sql` روی schema تازه import و fixtureهای کاربر/کلاس/آزمون/
  نسخهٔ تکلیف بررسی شده‌اند.
- مجموعهٔ lifecycle با **۴۸ تست از ۴۸ تست موفق** روی مسیر نسخهٔ `api/v1` اجرا شد.
- مجموعهٔ امنیتی با **۲۲ تست از ۲۲ تست موفق** اجرا شد.
- `flutter analyze` بدون issue و هر **۲۴ تست Flutter** موفق بوده‌اند.
- Web debug پس از آخرین تغییرات ساخته و با Playwright در viewport گوشی بدون
  خطای runtime/asset smoke-test شده است. دو build نوع release در sandbox به‌دلیل kill شدن
  `dart2js` با کمبود منابع تمام نشدند، نه خطای سورس.
- سه تلاش Android در sandbox به‌دلیل فشار RAM/زمان artifact نساختند؛ CI اکنون
  build Android debug و Web release را اجباری می‌کند.

## خروجی‌های آماده

- `.github/workflows/ci.yml`: PHP/schema/migration/API/security، Flutter، Web و Android
- `.github/workflows/release-android.yml`: ساخت و verify کردن APK امضاشده و GitHub Release
- `tools/package_deployment.sh`: بستهٔ هم‌دامنهٔ Alwaysdata
- `tools/build_signed_apk.sh`: APK universal با SHA-256 و بدون debug-sign fallback
- `docs/استقرار-رایگان.md`: راهنمای سادهٔ استقرار دمو
- `docs/انتشار-اندروید.md`: راهنمای keystore، secretها و release

## موارد بیرونی باقیمانده

1. ساخت حساب Alwaysdata، database و آدرس عمومی HTTPS
2. انتخاب application ID نهایی
3. ساخت و backup کردن keystore و افزودن GitHub Secrets
4. در صورت نیاز به Live تولیدی، دریافت credentialهای JaaS
5. اجرای runtime روی گوشی واقعی و انتشار artifact توسط مالک
