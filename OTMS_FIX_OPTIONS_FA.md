# گزینه‌ها و بهترین روش‌های اصلاح مشکلات OTMS

این سند فقط برنامه و گزینه‌های اصلاح است؛ هنوز هیچ فایل اصلی پروژه تغییر نکرده است.

## اقدام صفر: قبل از تغییر کد

1. توکن GitHub افشاشده را revoke کنید.
2. از دیتابیس فعلی backup بگیرید.
3. یک branch مثل `fix/security-and-stability` بسازید.
4. اصلاحات را به commitهای کوچک و مستقل تقسیم کنید.
5. در دیتابیس واقعی هرگز برای اعمال تغییرات، `schema.sql` را دوباره import نکنید؛ migration غیرمخرب بسازید.

---

# ۱. انتخاب روش کلی

## روش A — وصلهٔ سریع برای دمو

**مناسب:** دفاع پروژه، نمایش محدود، محیط لوکال
**زمان تقریبی:** ۲ تا ۴ روز کاری
**کارها:** فقط باگ‌های P0 و crashها اصلاح می‌شوند.

شامل:

- بستن bypass عضویت کلاس
- اصلاح `content` → `contents`
- اصلاح سؤال‌های False/No
- اصلاح navigation نتیجهٔ آزمون
- رفع stale شدن تب‌ها
- برگرداندن کد استاد و Q&A به داشبورد فعال
- حذف داده‌های ساختگی یا الصاق برچسب واضح DEMO
- رفع crash description

**مزیت:** سریع و کم‌ریسک.
**ضعف:** هنوز برای کاربر واقعی و انتشار عمومی کافی نیست؛ آزمون، فایل‌ها، HTTPS و release security کامل نمی‌شوند.

---

## روش B — تثبیت اصولی پروژه

**مناسب:** بهترین انتخاب برای همین پروژه
**زمان تقریبی:** ۲ تا ۴ هفته برای یک توسعه‌دهنده
**پیشنهاد اصلی:** این روش.

علاوه بر روش A:

- lifecycle واقعی آزمون
- دانلود فایل authenticated
- deadline و resubmit درست تکلیف
- طراحی responsive موبایل
- validation مرکزی backend
- migrationهای دیتابیس
- تست integration و CI
- release signing و HTTPS
- حذف UIهای قدیمی و کد مرده

**مزیت:** ساختار فعلی PHP + Flutter حفظ می‌شود و پروژه واقعاً قابل استفاده می‌شود.
**ضعف:** نیاز به چند migration و بازطراحی محدود API دارد.

---

## روش C — Production Hardening کامل

**مناسب:** استفادهٔ عمومی، کاربران واقعی، دادهٔ آموزشی حساس
**زمان تقریبی:** ۱ تا ۲ ماه یا بیشتر

علاوه بر روش B:

- session cookie امن برای web یا معماری token پیشرفته
- rate limiting قوی‌تر
- audit log
- object storage یا storage service
- pagination و query optimization
- monitoring، backup، restore و disaster recovery
- تست نفوذ و بررسی امنیت deployment
- privacy policy و retention policy برای فایل‌ها و داده‌ها

**مزیت:** مناسب محصول واقعی.
**ضعف:** هزینه و پیچیدگی بیشتر.

---

## روش D — بازنویسی backend

گزینه‌ها: Laravel، NestJS، Supabase، Firebase یا backend کاملاً Dart.

**پیشنهاد فعلی:** فعلاً انجام نشود. بیشتر مشکلات موجود با اصلاح PHP فعلی حل می‌شوند. بازنویسی قبل از تثبیت رفتارها معمولاً همان باگ‌ها را با هزینهٔ بیشتر بازتولید می‌کند.

بازنویسی فقط وقتی منطقی است که یکی از این موارد قطعی باشد:

- تیم با PHP خام نمی‌خواهد ادامه دهد.
- نیاز جدی به realtime، push notification یا مقیاس بزرگ وجود دارد.
- قرار است معماری offline/sync چنددستگاهی پیاده شود.
- قرارداد محصول و نیازمندی‌ها ابتدا نهایی شده‌اند.

---

# ۲. روش‌های اصلاح هر مشکل مهم

## ۲.۱. عضویت بدون کد استاد

### گزینه ۱ — ارسال code همراه enroll

کلاینت برای هر کلاس این payload را بفرستد:

```json
{
  "class_id": 12,
  "teacher_code": "ABC123"
}
```

سرور در یک query بررسی کند:

- code فعال است.
- class متعلق به همان teacher است.
- کاربر student است.

**مزیت:** ساده و سریع.
**ضعف:** کد قابل replay و share است؛ البته کد استاد ذاتاً shareable طراحی شده است.
**مناسب:** دمو و نسخهٔ اولیه.

### گزینه ۲ — Join Ticket کوتاه‌عمر

`code_lookup` پس از کد معتبر، یک token تصادفی کوتاه‌عمر تولید کند. `enroll` فقط ticket را قبول کند. در DB فقط hash ticket با teacher/student/expiry ذخیره شود.

**مزیت:** قرارداد امن‌تر، امکان محدود کردن زمان و مصرف.
**ضعف:** جدول و endpoint پیچیده‌تر.
**مناسب:** نسخهٔ production.

### گزینه ۳ — تأیید استاد

دانش‌آموز درخواست عضویت می‌دهد و استاد approve می‌کند.

**مزیت:** بیشترین کنترل.
**ضعف:** UX کندتر و نیازمند صفحهٔ pending requests.

### پیشنهاد

اکنون گزینهٔ ۱؛ اگر پروژه عمومی شد گزینهٔ ۲ یا ۳.

---

## ۲.۲. حذف محتوا

### روش درست

1. نام جدول در هر دو query به `contents` اصلاح شود.
2. فایل متصل به content قبل از حذف خوانده شود.
3. رکورد در transaction حذف شود.
4. پس از commit، فایل در صورت نداشتن reference دیگر پاک شود.
5. تست create → list → delete → list نوشته شود.

فقط تغییر نام جدول، باگ فوری را حل می‌کند؛ ولی file cleanup باید در فاز بعد اضافه شود.

---

## ۲.۳. True/False و Yes/No

### گزینه ۱ — حفظ قرارداد فعلی backend

کلاینت برای این نوع‌ها `correct` بفرستد:

```dart
payload['correct'] = selectedValue; // true/false/yes/no
```

**مزیت:** سریع‌ترین راه.

### گزینه ۲ — یکسان‌سازی کامل قرارداد سؤال

تمام سؤال‌های objective فقط `options` داشته باشند و backend از همان آرایه استفاده کند. Backend برای single-choice دقیقاً یک گزینهٔ صحیح را enforce کند.

**مزیت:** API ساده‌تر و کم‌خطاتر.
**ضعف:** نیازمند اصلاح تست‌ها و قرارداد API.

### پیشنهاد

برای hotfix گزینهٔ ۱؛ سپس در نسخهٔ بعد گزینهٔ ۲.

---

## ۲.۴. آزمون زمان‌دار، تعداد تلاش و نمایش جواب

### روش نامناسب

قرار دادن یک `Timer` فقط در Flutter کافی نیست. کاربر می‌تواند API را مستقیم صدا بزند یا زمان دستگاه را تغییر دهد.

### روش اصولی پیشنهادی

#### تغییر جدول assessments

فیلدهای پیشنهادی:

- `status`: draft/published/closed
- `max_attempts`
- `opens_at`
- `closes_at`
- `answer_release_policy`: immediately/after_close/teacher_release/never

#### تغییر جدول attempts

- `started_at`
- `deadline_at`
- `submitted_at`
- `attempt_no`
- `status`: in_progress/submitted/graded/expired
- unique مناسب روی assessment/student/attempt_no

#### API پیشنهادی

1. `attempt_start.php`
   - assessment را بررسی می‌کند.
   - تعداد تلاش را کنترل می‌کند.
   - `deadline_at` را از زمان سرور می‌سازد.
   - یک attempt id برمی‌گرداند.

2. `attempt_questions.php?attempt_id=...`
   - فقط برای attempt فعال سؤال‌ها را می‌دهد.

3. `attempt_submit.php`
   - `attempt_id` می‌گیرد، نه صرفاً assessment id.
   - مالکیت و deadline را کنترل می‌کند.
   - idempotent باشد تا تکرار request attempt دوم نسازد.

4. `attempt_get.php`
   - جواب صحیح را فقط طبق `answer_release_policy` بدهد.

#### Snapshot

بهترین حالت این است که هنگام start یا publish، نسخهٔ سؤال/گزینه/امتیاز برای attempt ثابت شود. در غیر این صورت ویرایش بعدی استاد نتیجهٔ قبلی را خراب می‌کند.

### پیشنهاد

برای دمو می‌توان موقتاً یک attempt برای هر دانش‌آموز enforce کرد و جواب صحیح را از response دانش‌آموز حذف کرد. برای نسخهٔ واقعی، معماری بالا لازم است.

---

## ۲.۵. stale شدن تب‌ها هنگام تعویض کلاس

### گزینه ۱ — Key روی subtree کلاس

```dart
KeyedSubtree(
  key: ValueKey(classId),
  child: ClassTabs(classId: classId),
)
```

**مزیت:** سریع و کم‌تغییر؛ state تب‌ها با تغییر کلاس از نو ساخته می‌شود.

### گزینه ۲ — پیاده‌سازی didUpdateWidget

در هر tab تغییر `classId` تشخیص داده و Future دوباره ساخته شود.

**مزیت:** کنترل بیشتر و امکان حفظ state مناسب.
**ضعف:** باید در چند فایل تکرار شود.

### گزینه ۳ — state management مرکزی

استفاده از Provider/Riverpod/BLoC و cache بر اساس classId.

**مزیت:** مناسب رشد پروژه.
**ضعف:** برای رفع فوری این باگ بیش از حد بزرگ است.

### پیشنهاد

اکنون گزینهٔ ۱ به‌علاوهٔ `ValueKey(lesson.id)` برای lesson cardها. بعداً در refactor از repository/state management مرکزی استفاده شود.

---

## ۲.۶. داشبورد استاد و کد مرده

### گزینه ۱ — بازگشت موقت به TeacherHome

route اصلی از `TeacherDashboard` به `TeacherHome` برگردد.

**مزیت:** کد عضویت، Q&A و delete class سریع برمی‌گردند.
**ضعف:** طراحی داشبورد جدید کنار گذاشته می‌شود.

### گزینه ۲ — انتقال قابلیت‌ها به TeacherDashboard

موارد زیر از فایل‌های قدیمی منتقل شوند:

- Join code card و regenerate
- `QaTab`
- Live demo navigation
- delete class
- theme/account actions مورد نیاز

سپس `TeacherHome` و `TeacherClassDetail` حذف شوند.

**مزیت:** راه تمیز و نهایی.
**ضعف:** کمی کار ادغام می‌خواهد.

### پیشنهاد

گزینهٔ ۲. بازگشت به TeacherHome فقط به‌عنوان hotfix یک‌روزه.

---

## ۲.۷. navigation نتیجهٔ آزمون

### روش ساده

از این الگو استفاده شود:

```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => ResultScreen(...)),
  result: true,
);
```

یا route آزمون با `pop(true)` بسته شود و list پس از دریافت true، نتیجه را باز کند.

**پیشنهاد:** `pushReplacement(..., result: true)` و widget test برای این مسیر.

---

## ۲.۸. طراحی responsive موبایل

### روش پیشنهادی

با `LayoutBuilder` دو layout ساخته شود:

- عرض بزرگ‌تر از حدود ۸۴۰: sidebar ثابت
- عرض کوچک: `NavigationDrawer` داخل Scaffold

همچنین:

- پنجرهٔ user menu با `Dialog` و `ConstrainedBox(maxWidth: 500)` ساخته شود، نه width ثابت.
- bottom sheetها scrollable شوند.
- headerهای دارای چند دکمه از `Wrap` استفاده کنند.
- breakpoint grid بر اساس `constraints.maxWidth` باشد.
- تست widget برای عرض‌های ۳۶۰، ۶۰۰ و ۱۲۸۰ اضافه شود.

---

## ۲.۹. داده‌های ساختگی داشبورد

### گزینه ۱ — حذف کامل

تا زمان API واقعی، کارت‌ها و لیست‌های ساختگی نمایش داده نشوند.

### گزینه ۲ — برچسب DEMO

کل dashboard با banner واضح «Demo data» نمایش داده شود.

### گزینه ۳ — API آمار واقعی

endpointهای aggregate ساخته شوند:

- teacher dashboard summary
- student dashboard summary
- upcoming assessments
- pending homework
- average score

### پیشنهاد

در نسخهٔ فعلی گزینهٔ ۱؛ سپس گزینهٔ ۳. نمایش دادهٔ ساختگی بدون برچسب بدترین حالت است.

---

## ۲.۱۰. تکلیف، feedback و resubmit

### قرارداد پیشنهادی

- `my_submission` شامل `id`, `text`, `file`, `submitted_at`, `grade`, `feedback`, `status` باشد.
- sheet ویرایش با دادهٔ قبلی prefill شود.
- کاربر بتواند مشخص کند فایل قبلی نگه داشته یا حذف شود.
- resubmit داخل transaction انجام شود.
- با resubmit، grade/feedback یا reset شوند یا version جدید submission ساخته شود.

### دو روش نگهداری تاریخچه

1. **روش ساده:** یک submission، update و reset نمره.
2. **روش بهتر:** جدول `submission_versions`؛ هر resubmit نسخهٔ جدید می‌سازد و استاد تاریخچه را می‌بیند.

### پیشنهاد

برای پروژهٔ فعلی روش ساده؛ برای سیستم واقعی versioning بهتر است.

---

## ۲.۱۱. فایل‌های آپلودی

### گزینه ۱ — endpoint دانلود authenticated

فایل‌ها بیرون web root ذخیره شوند. یک جدول metadata داشته باشند:

- id
- storage_name
- original_name
- mime
- size
- owner/context
- created_at

`download.php?id=...` پس از auth و ownership فایل را با header مناسب stream کند.

**مزیت:** بهترین روش برای PHP فعلی.

### گزینه ۲ — Signed URL کوتاه‌عمر

اگر S3/MinIO/object storage استفاده شود، backend URL کوتاه‌عمر صادر کند.

**مزیت:** مناسب مقیاس.
**ضعف:** زیرساخت بیشتر.

### گزینه ۳ — حفظ URL تصادفی فعلی

فقط برای demo قابل قبول است، نه دادهٔ واقعی.

### پیشنهاد

گزینهٔ ۱. همچنین cleanup فایل هنگام delete/replace و job دوره‌ای برای orphanها اضافه شود.

---

## ۲.۱۲. HTTPS، token و session

### Mobile

- در release فقط HTTPS.
- cleartext فقط در debug با Network Security Config.
- token در `flutter_secure_storage`.
- token در DB به‌صورت hash ذخیره شود.
- امکان revoke همهٔ نشست‌ها و session rotation اضافه شود.

### Web

دو گزینه:

1. ادامهٔ Bearer token در storage — ساده ولی در برابر XSS ضعیف‌تر.
2. session cookie با `HttpOnly`, `Secure`, `SameSite` و CSRF protection — بهترین روش production web.

### پیشنهاد

برای اپ Android: secure storage + HTTPS.
برای web واقعی: cookie امن.
برای دمو لوکال: HTTP فقط در build debug.

---

## ۲.۱۳. حساب‌های demo و محیط production

فایل‌ها جدا شوند:

- `schema.sql`: فقط ساخت جدول‌ها
- `seed_demo.sql`: حساب و دادهٔ نمونه
- `migrations/`: تغییرات مرحله‌ای

UI نیز با build flag کنترل شود:

```bash
--dart-define=OTMS_DEMO=true
```

Demo credentials فقط در حالت demo نمایش داده شوند.

---

## ۲.۱۴. release اندروید

کارهای لازم:

1. تعیین application ID واقعی.
2. ساخت release keystore خارج repository.
3. گرفتن مقادیر signing از environment یا `key.properties` ignored.
4. حذف debug signing از release.
5. HTTPS اجباری.
6. ساخت flavorهای `dev`, `staging`, `prod`.
7. بررسی backup policy و obfuscation/minify در صورت نیاز.

---

## ۲.۱۵. validation و error handling backend

### روش پیشنهادی

یک لایهٔ validation مشترک بسازید:

- `require_json_body()`
- `required_string(name, maxLength)`
- `optional_string(...)`
- `required_int(...)`
- `enum_value(...)`
- `valid_date(...)`

همچنین exception handler مرکزی:

- خطای validation → 400/422
- auth → 401/403
- not found → 404
- conflict → 409
- خطای غیرمنتظره → JSON عمومی 500 و log داخلی

در production، `display_errors=Off` باشد.

---

## ۲.۱۶. schema و transaction

Constraints پیشنهادی:

- `UNIQUE(attempt_id, question_id)` روی answers
- indexهای foreign key و queryهای پرتکرار
- CHECK برای points و duration و statusها، در نسخهٔ DB سازگار
- عدم پذیرش option متعلق به سؤال دیگر در application layer یا طراحی composite relation
- transaction برای register، regenerate code، submit/replace file، grade و start attempt
- versioning یا immutability برای assessment منتشرشده

Migrationها باید idempotent یا حداقل versioned و قابل rollback باشند.

---

## ۲.۱۷. performance

### اصلاح کوتاه‌مدت

- join و aggregate query به‌جای query داخل loop
- دریافت تمام options سؤال‌ها با یک query و group کردن در PHP
- latest attempt با derived table/window function یا query جدا برای همهٔ assessmentها
- submission counts با `GROUP BY`

### اصلاح بلندمدت

- pagination
- indexها
- cache summaryها در صورت نیاز
- profiling با دادهٔ حجیم واقعی

---

## ۲.۱۸. تست و CI

### تست‌های ضروری اول

1. enroll بدون کد معتبر → 403
2. enroll با کد استاد دیگر → 403
3. content create/delete
4. False و No واقعاً درست ذخیره شوند
5. تلاش دوم طبق policy رد شود
6. submit بعد از deadline رد شود
7. answer key زودتر از policy نشان داده نشود
8. دانش‌آموز به فایل کلاس دیگر دسترسی نداشته باشد
9. resubmit وضعیت grade را درست تغییر دهد
10. تغییر classId دادهٔ tab را reload کند
11. submit آزمون route نتیجه را باز نگه دارد
12. layout در عرض ۳۶۰ overflow ندهد

### CI پیشنهادی

GitHub Actions tracked:

- `flutter analyze`
- `flutter test`
- syntax/lint PHP
- MySQL service
- import schema + migrations
- API integration tests روی DB موقت
- web build
- smoke test که روی console/page error واقعاً fail شود

تست‌ها باید DB اختصاصی بسازند و در پایان پاک کنند؛ روی DB توسعه اجرا نشوند.

---

## ۲.۱۹. مستندات

پس از تثبیت کد:

- حداقل نسخهٔ واقعی Flutter/Dart ثبت شود.
- فقط platformهای موجود ذکر شوند.
- راهنمای preview یک روش اصلی داشته باشد.
- حساب‌های demo از seed واقعی خوانده/هماهنگ شوند.
- قابلیت‌های ناقص مثل Live و offline صریحاً «demo/planned» باشند.
- deployment checklist امنیتی اضافه شود.
- hash و تعداد commit از مستندات حذف شوند چون سریع stale می‌شوند.

---

# ۳. کارهایی که نباید انجام شوند

1. تکیه به مخفی بودن `class_id` به‌عنوان امنیت.
2. تکیه به CORS به‌عنوان authorization.
3. کنترل زمان آزمون فقط در Flutter.
4. نمایش جواب صحیح بلافاصله، وقتی تلاش مجدد ممکن است.
5. نگهداری فایل حساس در web root فقط با نام تصادفی.
6. استفاده از token GitHub داخل URL یا فایل config.
7. امضای release با debug key.
8. استفاده از schema destructive برای update دیتابیس واقعی.
9. بازنویسی کامل پروژه قبل از نوشتن تست رفتار فعلی.
10. اصلاح ده‌ها مشکل در یک commit بزرگ.

---

# ۴. ترتیب اجرایی پیشنهادی

## مرحلهٔ ۱ — امنیت و باگ‌های قطعی

1. عضویت با کد
2. content delete
3. False/No
4. navigation نتیجه
5. stale tabها و key کارت lesson
6. crash description
7. join code استاد
8. Q&A استاد

## مرحلهٔ ۲ — تست قفل‌کننده

برای هر مورد مرحلهٔ ۱ ابتدا یا هم‌زمان تست regression نوشته شود. CI نیز در همین مرحله فعال شود.

## مرحلهٔ ۳ — آزمون و تکلیف

1. lifecycle آزمون
2. attempt policy
3. snapshot/immutability
4. deadline تکلیف
5. resubmit و feedback
6. statusهای grading

## مرحلهٔ ۴ — فایل و امنیت release

1. storage بیرون web root
2. download authenticated
3. HTTPS
4. secure storage
5. release signing
6. حذف demo account از production

## مرحلهٔ ۵ — UI و پاک‌سازی

1. responsive drawer
2. API واقعی dashboard
3. حذف صفحات قدیمی
4. validation و error states یکدست
5. اصلاح مستندات

---

# پیشنهاد نهایی

برای این مخزن، بهترین مسیر **روش B: تثبیت اصولی بدون بازنویسی کامل** است. ابتدا هشت اصلاح مرحلهٔ ۱ انجام شوند؛ سپس lifecycle آزمون و فایل‌ها بازطراحی شوند. مهاجرت به Laravel/Firebase/Supabase در حال حاضر سود کمتری از هزینه‌اش دارد، چون عمدهٔ مشکلات از قرارداد API، authorization، state UI و نبود تست ناشی می‌شوند و با تغییر فناوری خودبه‌خود حل نخواهند شد.
