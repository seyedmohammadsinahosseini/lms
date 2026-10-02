# برنامهٔ نهایی اصلاح، موبایل‌سازی و انتشار رایگان OTMS

**تاریخ:** ۲۰۲۶-۱۰-۰۲
**مبنای بررسی:** شاخهٔ `main`، کامیت `c89f74a`
**وضعیت:** این سند برنامهٔ اجرایی است؛ هیچ فایل اصلی برنامه یا دیتابیس هنوز تغییر نکرده است.

این سند نتیجهٔ نهایی دو گزارش قبلی است:

- `OTMS_REVIEW_FA.md`: شرح فنی ۴۴ مشکل با محل دقیق در کد
- `OTMS_FIX_OPTIONS_FA.md`: مقایسهٔ روش‌های مختلف اصلاح

اصل تصمیم‌گیری در این برنامه این است که **هیچ قابلیت موردنظر پروژه حذف یا پنهان نشود**. هر چیزی که اکنون ناقص، ساختگی یا از route اصلی خارج است باید به قابلیت واقعی و قابل‌آزمایش تبدیل شود.

---

# ۱) تصمیم نهایی در یک نگاه

## معماری‌ای که حفظ می‌شود

- **کلاینت اصلی گوشی:** Flutter برای Android
- **نسخهٔ قابل‌نمایش در رزومه:** Flutter Web responsive از همان codebase
- **backend:** PHP فعلی، پس از ساختاربندی و امن‌سازی
- **دیتابیس:** MariaDB/MySQL فعلی با migrationهای غیرمخرب
- **Live class:** سرویس WebRTC آماده، نه ساختن video server داخل PHP

بازنویسی کامل با Laravel، Firebase، Supabase یا Node.js در این مرحله توصیه نمی‌شود. PHP/MySQL فعلی برای این اندازهٔ پروژه کافی است و با اصلاح قراردادها، تست و امنیت می‌تواند همهٔ قابلیت‌های موردنظر را اجرا کند.

## شکل نهایی مناسب رزومه

1. یک URL عمومی که در مرورگر گوشی و دسکتاپ باز شود.
2. یک دکمهٔ «شروع دموی اختصاصی» که برای هر بازدیدکننده دادهٔ موقت مستقل بسازد.
3. امکان ورود در نقش استاد و دانش‌آموز و دیدن همان کلاس مشترک.
4. یک APK واقعی و امضاشدهٔ Android برای دانلود.
5. README عمومی با معماری، screenshot، حساب/روش دمو، تست‌ها، محدودیت زیرساخت رایگان و لینک APK.
6. هیچ دادهٔ شخصی واقعی در محیط دمو قرار نگیرد.

## پیشنهاد میزبانی رایگان

برای ساده‌ترین deployment متناسب با PHP/MySQL فعلی، پیشنهاد اول برای **دموی رزومه** این است:

- Flutter Web + PHP API روی یک PHP Site رایگان در **alwaysdata**
- MariaDB مدیریت‌شده در همان حساب
- دامنهٔ رایگان `username.alwaysdata.net`
- APK روی یک GitHub Release عمومی
- در صورت نیاز، Firebase App Distribution فقط برای تسترهای دعوت‌شده

قرار گرفتن وب و API روی یک origin، CORS و deployment را ساده‌تر می‌کند. پلن رایگان alwaysdata محدود است و برای محصول واقعی توصیه نمی‌شود، اما برای دموی کم‌ترافیک مناسب‌تر از سرویس‌هایی است که صریحاً API موبایل را در free hosting خود پشتیبانی نمی‌کنند.

## نتیجهٔ مهم

**بله، انتشار آنلاین رایگان برای رزومه ممکن است.** اما «دموی رایگان» با «production امن برای کاربران واقعی» یکی نیست. محیط رایگان باید دادهٔ ساختگی، quota محدود، پاک‌سازی خودکار و پیام واضح Demo داشته باشد.

---

# ۲) معماری موبایل‌محور پیشنهادی

## ۲.۱. هدف پلتفرم

اولویت‌ها به این ترتیب باشند:

1. Android native با Flutter؛ محصول اصلی روی گوشی
2. Flutter Web responsive؛ راه فوری و بدون نصب برای recruiter
3. مرورگر iPhone/iPad؛ برای نمایش امکانات پایه
4. iOS native در فاز بعد، فقط اگر حساب Apple Developer و پوشهٔ iOS ایجاد شد

مخزن فعلی Android و Web دارد، اما target آمادهٔ iOS ندارد. بنابراین نباید در رزومه ادعای native iOS شود. نسخهٔ وب روی Safari می‌تواند مسیر رایگان نمایش روی iPhone باشد.

## ۲.۲. navigation روی گوشی

### دانش‌آموز

- نوار پایین: خانه، کلاس‌ها، تکالیف/آزمون‌ها، حساب
- صفحهٔ کلاس: درس‌ها، آزمون‌ها، تکالیف، پرسش‌وپاسخ
- دکمه‌های مهم مثل Join class و Continue assessment به‌صورت FAB یا CTA واضح

### استاد

- نوار پایین: خانه، کلاس‌ها، بررسی/نمره‌دهی، حساب
- صفحهٔ کلاس: درس‌ها، آزمون‌ها، تکالیف، دانش‌آموزان، Q&A، Live
- کد استاد و regenerate در بالای صفحهٔ کلاس/داشبورد، نه در UI قدیمی خارج از route

### breakpointها

بر اساس **عرض واقعی container با `LayoutBuilder`** تصمیم گرفته شود، نه صرفاً `MediaQuery` کل صفحه:

- کمتر از ۶۰۰px: `NavigationBar` یا `Drawer`، بدون sidebar ثابت
- ۶۰۰ تا ۱۰۲۴px: `NavigationRail`
- بیشتر از ۱۰۲۴px: sidebar کامل

تمام sheetها و dialogها باید `SafeArea`، حداکثر عرض، scroll و سازگاری با keyboard داشته باشند. target لمسی حداقل حدود ۴۸px، متن قابل‌بزرگ‌کردن، و landscape نیز آزمایش شود.

## ۲.۳. ساختار کد Flutter

ساختار پیشنهادی تدریجی، بدون بازنویسی یک‌باره:

```text
lib/
  app/                    # router, theme, dependency wiring
  core/
    config/               # API URL و build flavor
    network/              # ApiClient, error mapping, auth interceptor
    storage/              # secure storage و cache
    widgets/              # widgetهای واقعاً مشترک
  features/
    auth/
      data/ domain/ presentation/
    classes/
      data/ domain/ presentation/
    lessons/
    assessments/
    homework/
    qa/
    live/
    profile/
```

قانون مهم: screen نباید مستقیماً JSON خام endpoint را تفسیر کند. هر feature یک repository و model مشخص داشته باشد. خطاها به نوع‌های واحد مثل `Unauthorized`, `Validation`, `Network`, `Server` تبدیل شوند.

## ۲.۴. رفتار مناسب شبکهٔ موبایل

- فهرست کلاس‌ها، درس‌ها و تکالیف در cache محلی نگه‌داری شود تا قطع لحظه‌ای شبکه صفحه را خالی نکند.
- عملیات حساس مثل submit آزمون، enroll و start live نیازمند اتصال باشند و پیام دقیق بدهند.
- عملیات قابل‌تکرار با `idempotency_key` ارسال شوند تا retry شبکه رکورد تکراری نسازد.
- فایل بزرگ stream شود؛ قبل از خواندن کامل در RAM، اندازه بررسی شود.
- هر Future/Stream پس از تغییر class و پس از resume شدن برنامه قابلیت refresh داشته باشد.
- برای فاز بعد، notification تکلیف/Live می‌تواند اضافه شود؛ برای سالم شدن نسخهٔ فعلی ضروری نیست.

## ۲.۵. Live class واقعی

PHP/MySQL به‌تنهایی media server نیست. برای اینکه این قابلیت واقعاً کار کند:

1. جدول `live_sessions` شامل `class_id`, `provider_room_id`, `starts_at`, `ended_at`, `created_by` ساخته شود.
2. فقط استاد همان کلاس بتواند جلسه را شروع/تمام کند.
3. دانش‌آموز فقط در صورت عضویت در کلاس join token بگیرد.
4. secret سرویس Live فقط در backend باشد؛ کلاینت هیچ secretی نداشته باشد.
5. روی Android از Jitsi Flutter SDK استفاده شود؛ روی Web از integration رسمی وب یا باز کردن اتاق محافظت‌شده استفاده شود. SDK رسمی فعلی Jitsi برای Android حداقل `minSdk 24` می‌خواهد؛ اگر پشتیبانی Android قدیمی‌تر الزام باشد، به‌جای SDK از fallback مرورگر استفاده شود.
6. برای دموی رایگان می‌توان از JaaS Dev استفاده کرد که در زمان نگارش ۲۵ کاربر فعال ماهانهٔ رایگان اعلام کرده است. اگر quota تمام شد، UI باید خطای واقعی «ظرفیت دموی Live تمام شده» نشان دهد، نه موفقیت ساختگی.
7. برای production باید JaaS پولی، LiveKit Cloud/سرویس مشابه، یا Jitsi self-hosted با منابع کافی انتخاب شود.

---

# ۳) راه‌حل قطعی برای تک‌تک ۴۴ مشکل

جزئیات و شماره‌خط‌های هر مورد در `OTMS_REVIEW_FA.md` قرار دارد. این بخش روش انتخاب‌شده و معیار پایان را مشخص می‌کند.

## P0 — مسدودکننده‌های انتشار

### ۱. دورزدن کد استاد هنگام عضویت

**راه‌حل انتخاب‌شده:** `code_lookup` پس از کد معتبر یک `join_grant` تصادفی، یک‌بارمصرف و کوتاه‌عمر بسازد. در DB فقط hash آن همراه `student_id`, `teacher_id`, `expires_at`, `used_at` ذخیره شود. `enroll` به‌جای اعتماد به `class_id`، grant را در transaction قفل کند، تطابق استاد مالک کلاس را بررسی کند و سپس آن را مصرف کند.

**معیار پایان:** enroll بدون grant، grant منقضی، grant دانش‌آموز دیگر و کلاس استاد دیگر همگی 403؛ grant معتبر فقط یک بار موفق شود.

### ۲. خرابی حذف محتوا به‌دلیل جدول `content`

**راه‌حل انتخاب‌شده:** هر دو query به `contents` اصلاح شوند. ابتدا مالکیت و مسیر فایل خوانده شود، delete در transaction انجام شود و پس از commit، فایل بدون reference پاک شود.

**معیار پایان:** تست `create → list → delete → list` موفق و حذف دوباره 404 باشد؛ فایل متصل orphan نماند.

### ۳. ذخیرهٔ غلط False/No

**راه‌حل انتخاب‌شده:** قرارداد همهٔ سؤال‌های objective یکسان شود. payload شامل `type`, `options[{text,is_correct}]` باشد. برای true/false و yes/no، backend دقیقاً دو option مجاز و دقیقاً یک جواب صحیح را validate کند. migration داده‌های قبلی غلط نیز نوشته شود.

**معیار پایان:** تست جداگانهٔ True، False، Yes و No در API و Flutter؛ مقدار انتخاب‌شدهٔ استاد عیناً در نتیجه دیده شود.

### ۴. آزمون زمان‌دار و تعداد تلاش واقعی نیست

**راه‌حل انتخاب‌شده:** lifecycle کامل سمت سرور:

- assessment: `draft/published/closed`, `opens_at`, `closes_at`, `duration_min`, `max_attempts`, `answer_release_policy`
- endpoint `attempt_start`: ساخت attempt و `deadline_at` از ساعت سرور
- endpoint `attempt_submit`: فقط attempt فعال همان دانش‌آموز، قبل از deadline و به‌شکل idempotent
- attemptهای رهاشده پس از deadline به `expired` تبدیل شوند
- answer key فقط مطابق policy استاد برگردد

Timer Flutter فقط countdown UX است و تصمیم امنیتی با زمان سرور گرفته می‌شود.

**معیار پایان:** تلاش دوم بیش از limit رد شود؛ submit پس از deadline رد شود؛ دستکاری ساعت گوشی اثری نداشته باشد؛ answer key زودتر از policy لو نرود.

### ۵. stale شدن تب‌ها بعد از تغییر کلاس

**راه‌حل انتخاب‌شده:** subtree هر کلاس `ValueKey(classId)` بگیرد و tabهای stateful نیز در `didUpdateWidget` تغییر `classId` را reload کنند. request قبلی نباید نتیجه‌اش را روی کلاس جدید بنویسد؛ از request generation/cancellation استفاده شود.

**معیار پایان:** widget test سریع بین دو کلاس جابه‌جا شود و هیچ عنوان/داده/عملیات کلاس اول در کلاس دوم باقی نماند.

### ۶. کد استاد در route فعال دیده نمی‌شود

**راه‌حل انتخاب‌شده:** card کد استاد، copy و regenerate به feature فعال Teacher Dashboard منتقل شود. regenerate تأیید کاربر، transaction و invalidation امن کد قبلی داشته باشد.

**معیار پایان:** استاد از مسیر اصلی کد را ببیند/کپی/بازسازی کند و دانش‌آموز با کد جدید lookup کند؛ کد قدیمی غیرفعال باشد.

### ۷. طراحی برای گوشی responsive نیست

**راه‌حل انتخاب‌شده:** sidebar ثابت در compact layout به NavigationBar/Drawer تبدیل شود؛ popup ثابت ۵۰۰×۵۸۰ با `ConstrainedBox` و scroll جایگزین شود؛ bottom sheetها draggable/scrollable و gridها بر اساس عرض واقعی container باشند.

**معیار پایان:** تست تصویری و دستی حداقل در ۳۶۰×۸۰۰، ۴۱۲×۹۱۵، landscape و tablet؛ هیچ overflow و ناحیهٔ غیرقابل‌دسترسی وجود نداشته باشد.

## P1 — باگ‌ها و ریسک‌های جدی

### ۸. بسته شدن فوری صفحهٔ نتیجه

**راه‌حل انتخاب‌شده:** آزمون با `pushReplacement` فقط به Result برود؛ Result هنگام خروج نتیجهٔ refresh را به assessment list برگرداند. `Navigator.pop` بلافاصله بعد از replacement حذف شود.

**معیار پایان:** پس از submit صفحهٔ نتیجه پایدار بماند و با Back فهرست refresh‌شده دیده شود.

### ۹. Q&A و Live استاد ناقص‌اند

**راه‌حل انتخاب‌شده:** Q&A فعال از UI قدیمی به feature مشترک منتقل شود و teacher reply واقعی داشته باشد. Live طبق معماری Jitsi/JaaS بالا با session واقعی، authorization و join token پیاده شود؛ callback خالی و `LiveDemoScreen` ساختگی باقی نماند.

**معیار پایان:** سؤال دانش‌آموز در حساب استاد ظاهر شود، پاسخ به همان thread برگردد؛ استاد جلسه را شروع و دانش‌آموز همان کلاس به آن وارد شود.

### ۱۰. حذف کلاس در UI اصلی نیست

**راه‌حل انتخاب‌شده:** action حذف به منوی کلاس فعال اضافه شود. قبل از حذف، impact شامل تعداد درس/تکلیف/دانش‌آموز نمایش داده شود. backend ownership را دوباره بررسی و عملیات را transactionally انجام دهد؛ فایل‌های متعلق cleanup شوند.

**معیار پایان:** استاد فقط کلاس خود را حذف کند؛ دانش‌آموز یا استاد دیگر 403؛ UI پس از حذف به overview سالم برگردد.

### ۱۱. داشبورد دادهٔ ساختگی را واقعی نشان می‌دهد

**راه‌حل انتخاب‌شده:** endpointهای aggregation واقعی برای آمار استاد و دانش‌آموز ساخته شوند. average، pending grading، upcoming assessment، activity و progress از DB محاسبه شوند. دادهٔ seed فقط داخل محیط Demo باشد و هرگز به‌صورت constant در widget نباشد.

**معیار پایان:** تغییر دادهٔ DB عدد dashboard را تغییر دهد؛ هیچ Alice/Bob، میانگین ثابت یا دکمهٔ بی‌عمل باقی نماند.

### ۱۲. انتخاب خودکار کلاس اول و بلعیدن خطا

**راه‌حل انتخاب‌شده:** شروع dashboard روی overview باشد؛ آخرین کلاس انتخاب‌شده فقط در صورت وجود restore شود. stateهای loading/error/empty جدا شوند و Retry داشته باشند. اگر کلاس حذف شد، selection پاک و پیام مناسب نشان داده شود.

**معیار پایان:** خطای API با empty state اشتباه نشود و `firstWhere` exception رخ ندهد.

### ۱۳. crash و description تکراری کلاس

**راه‌حل انتخاب‌شده:** description فقط یک بار و با null-safe check رسم شود؛ model نیز nullable بودن را صحیح بازنمایی کند.

**معیار پایان:** کلاس با `NULL`, رشتهٔ خالی و متن عادی هر سه بدون crash و بدون تکرار نمایش داده شوند.

### ۱۴. جابه‌جایی cache محتوای lesson

**راه‌حل انتخاب‌شده:** کارت‌ها `ValueKey(lesson.id)` بگیرند و در `didUpdateWidget` در صورت تغییر id، cache و Future reset شوند. ترجیح بهتر، cache در repository با کلید lesson id است نه داخل state وابسته به index.

**معیار پایان:** حذف/reorder درس هرگز محتوای درس دیگری را نشان ندهد.

### ۱۵. feedback تکلیف به دانش‌آموز نمی‌رسد

**راه‌حل انتخاب‌شده:** `feedback`, `graded_at`, `grader` و وضعیت submission در API دانش‌آموز بازگردد و UI card/detail آن را نمایش دهد.

**معیار پایان:** متن استاد پس از grading با همان حساب دانش‌آموز قابل‌مشاهده باشد.

### ۱۶. resubmit تکلیف خراب است

**راه‌حل انتخاب‌شده:** submissionها version شوند؛ هر resubmit نسخهٔ جدید می‌سازد، نه overwrite مبهم. متن/فایل قبلی در فرم نمایش داده شود، grade قبلی روی نسخهٔ جدید به حالت `pending` برگردد و تاریخچه حفظ شود. policy استاد مشخص کند resubmit و late submit مجاز است یا نه.

**معیار پایان:** نسخهٔ قبلی قابل‌ردیابی، grade قدیمی روی فایل جدید اعمال‌نشده، فایل جایگزین orphan نشده و deadline enforce شده باشد.

### ۱۷. فایل‌ها عمومی و بدون authorization هستند

**راه‌حل انتخاب‌شده:** فایل‌ها بیرون document root ذخیره شوند. endpoint دانلود پس از احراز هویت، عضویت/مالکیت و permission، فایل را با MIME و header صحیح stream کند. برای preview بزرگ Range request پشتیبانی شود. cleanup به service مرکزی وصل شود.

**معیار پایان:** URL مستقیم بدون token/cookie فایل را ندهد؛ دانش‌آموز کلاس دیگر 403؛ حذف رکورد فایل را نیز طبق retention policy پاک کند.

### ۱۸. HTTP و token در SharedPreferences

**راه‌حل انتخاب‌شده:** release فقط HTTPS و `usesCleartextTraffic=false`. HTTP محلی فقط با Android Network Security Config در debug مجاز باشد. Android access/refresh token را در secure storage نگه دارد و rotation داشته باشد. Flutter Web از cookie `HttpOnly + Secure + SameSite` و CSRF token استفاده کند، نه localStorage.

**معیار پایان:** build release هیچ HTTP endpointی نپذیرد؛ token در SharedPreferences یا JavaScript-readable storage نباشد.

### ۱۹. حساب Demo در schema اصلی

**راه‌حل انتخاب‌شده:** `schema`، `migration` و `demo_seed` کاملاً جدا شوند. production هیچ credential پیش‌فرض نسازد. محیط رزومه به‌جای حساب مشترک ثابت، demo session موقت بسازد.

**معیار پایان:** import production هیچ user نسازد؛ build production hint رمز Demo نداشته باشد.

### ۲۰. امضای release با debug key

**راه‌حل انتخاب‌شده:** `applicationId` واقعی مانند `ee.<owner>.otms`، نسخه‌گذاری، keystore release خارج repo و `key.properties` ignored. release به config release وصل شود؛ `minifyEnabled` و resource shrinking پس از تست فعال شوند.

**معیار پایان:** `apksigner verify` موفق، fingerprint با debug متفاوت، و APK بعدی با همان release key قابل update باشد.

### ۲۱. attempt با تغییر سؤال‌ها خراب می‌شود

**راه‌حل انتخاب‌شده:** هنگام publish یک assessment version immutable ساخته شود. attempt به همان version وصل و متن سؤال، گزینه‌ها، امتیاز و answer key snapshot شود. ویرایش بعدی draft version جدید بسازد و attempt قدیمی دست‌نخورده بماند.

**معیار پایان:** افزودن/حذف/ویرایش سؤال بعد از submit، نتیجه و score attempt قبلی را تغییر ندهد.

### ۲۲. وضعیت essay ناسازگار است

**راه‌حل انتخاب‌شده:** status صریح `pending_grading/graded` و `graded_at` منبع حقیقت باشد؛ نه `is_correct`. migration و demo seed مقادیر قبلی را هماهنگ کنند.

**معیار پایان:** essay نمره‌داده‌شده در pending ظاهر نشود و Result status یکسان نشان دهد.

### ۲۳. badge attempt استاد وارونه است

**راه‌حل انتخاب‌شده:** enum مشترک mapping شود: `submitted/pending_grading` با hourglass؛ `graded` با check؛ `expired` با warning. متن و رنگ از یک mapper واحد بیاید.

**معیار پایان:** API/model/widget test برای همهٔ statusها وجود داشته باشد.

### ۲۴. deadline تکلیف enforce نمی‌شود

**راه‌حل انتخاب‌شده:** تاریخ با parser واقعی و timezone مشخص validate شود. due time بهتر است `DATETIME UTC` باشد، نه فقط رشتهٔ date. backend policy `allow_late_submission` و `allow_resubmit_until` را enforce کند.

**معیار پایان:** تاریخ نامعتبر 422؛ submit دیرهنگام مطابق policy رد یا با برچسب Late ثبت شود.

### ۲۵. validation و error handling ناکافی است

**راه‌حل انتخاب‌شده:** middleware/helper مرکزی برای method، JSON معتبر، type، length، enum و required fields ساخته شود. error envelope ثابت:

```json
{
  "ok": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "...",
    "fields": {"title": "..."}
  }
}
```

Exception داخلی log شود ولی SQL/path در response نباشد؛ `display_errors=Off` در release.

**معیار پایان:** JSON خراب 400، validation 422، auth 401/403، not found 404 و خطای ناشناخته JSON 500 بدون جزئیات داخلی باشد.

## P2 — پایداری و نگه‌داری

### ۲۶. option متعلق به سؤال دیگر پذیرفته می‌شود

**راه‌حل انتخاب‌شده:** query/constraint بررسی کند `(option_id, question_id)` معتبر است. در schema unique مرکب روی option و FK یا validation transactionally اعمال شود.

**معیار پایان:** option سؤال دیگر 422 و هیچ answer ناسازگار در DB ساخته نشود.

### ۲۷. Multiple Choice چند جواب صحیح دارد ولی UI radio است

**راه‌حل انتخاب‌شده:** دو نوع صریح ساخته شود:

- `single_choice`: دقیقاً یک جواب صحیح، Radio
- `multiple_select`: یک یا چند جواب صحیح، Checkbox

رکوردهای قبلی با یک correct به single و با چند correct به multiple-select migrate شوند. scoring اولیه برای multiple-select «تطابق دقیق مجموعه» باشد تا قانون مبهم نباشد.

**معیار پایان:** UI استاد و دانش‌آموز، backend validation و scoring هر دو نوع هماهنگ باشند.

### ۲۸. خطای load محتوا به‌شکل No content دیده می‌شود

**راه‌حل انتخاب‌شده:** loading/error/empty/data چهار state مستقل با Retry. خطاهای auth و network متن متفاوت داشته باشند.

**معیار پایان:** 500 یا قطع شبکه هرگز empty state نمایش ندهد.

### ۲۹. `setState` بعد از dispose

**راه‌حل انتخاب‌شده:** بعد از await، `if (!mounted) return`; request قابل cancel شود و دکمه در زمان lookup درخواست تکراری نفرستد.

**معیار پایان:** بستن صفحه هنگام request هیچ exception در log نسازد.

### ۳۰. edge caseهای upload

**راه‌حل انتخاب‌شده:** تمام `UPLOAD_ERR_*`ها پیام دقیق داشته باشند؛ MIME با `finfo` و magic bytes بررسی شود؛ نام تصادفی و allowlist حفظ شود؛ اندازه قبل از خواندن کل فایل در Flutter کنترل و فایل stream شود. اگر DB fail شد فایل تازه پاک شود.

**معیار پایان:** فایل جعلی با extension مجاز، فایل بزرگ، upload ناقص و DB failure همگی تست شوند و orphan نسازند.

### ۳۱. N+1 و نبود pagination

**راه‌حل انتخاب‌شده:** queryها با JOIN/batched `IN` بازنویسی و list endpointها cursor یا `page/per_page` با سقف مشخص داشته باشند. index روی FKها، statusها و تاریخ‌های پرتکرار اضافه شود.

**معیار پایان:** تعداد query برای N سؤال/تکلیف ثابت یا محدود باشد و response metadata صفحه‌بندی داشته باشد.

### ۳۲. race condition position و code

**راه‌حل انتخاب‌شده:** position داخل transaction با lock یا sequence مناسب تولید و unique constraint بر `(parent_id, position)` اعمال شود. کد استاد با unique DB و retry ساخته شود؛ regenerate ابتدا کد جدید را بسازد و سپس کد قدیمی را در همان transaction غیرفعال کند.

**معیار پایان:** تست concurrent هیچ position تکراری یا استاد بدون کد فعال نسازد.

### ۳۳. token خام در DB

**راه‌حل انتخاب‌شده:** کلاینت token تصادفی را می‌گیرد، ولی DB فقط SHA-256/HMAC hash را نگه می‌دارد. refresh token rotation، revoke device/logout all، expiry index و cleanup دوره‌ای اضافه شود.

**معیار پایان:** dump دیتابیس به‌تنهایی امکان استفاده از session فعال را ندهد.

### ۳۴. password policy و rate limit

**راه‌حل انتخاب‌شده:** حداقل ۱۰ تا ۱۲ کاراکتر یا policy passphrase، rate limit روی login/register/code lookup/demo create و پاسخ یکنواخت برای جلوگیری از enumeration. ساخت teacher در production فقط با invite/admin approval؛ ثبت‌نام دانش‌آموز و join feature حفظ شود.

**معیار پایان:** brute-force و teacher creation آزاد محدود؛ دمو همچنان با ساخت session موقت قابل‌استفاده باشد.

### ۳۵. scheme لینک ویدیو محدود نیست

**راه‌حل انتخاب‌شده:** backend و client فقط `https` را در release قبول کنند؛ `http` فقط build توسعه. schemeهای `file`, `intent`, `javascript` و مانند آن رد شوند. قبل از خروج از app، hostname نمایش داده شود.

**معیار پایان:** تست URL مجاز/غیرمجاز در هر دو سمت.

### ۳۶. Profile و Change password نمایشی‌اند

**راه‌حل انتخاب‌شده:** قابلیت واقعاً پیاده شود:

- `profile_get/profile_update`
- `password_change` با رمز فعلی، policy جدید و revoke سایر sessionها
- upload avatar امن در صورت نیاز

controllerها dispose شوند و lifecycle overlay بدون `setState` در dispose اصلاح شود.

**معیار پایان:** تغییر نام/رمز در DB و login بعدی قابل‌آزمایش؛ پیام `(demo)` و callback ساختگی حذف شود.

### ۳۷. دو نسل UI و کد مرده

**راه‌حل انتخاب‌شده:** قابلیت‌های درست UI قدیمی ابتدا به featureهای فعال منتقل و با test پوشش داده شوند؛ سپس screenهای duplicate حذف شوند. **قابلیت حذف نمی‌شود، فقط implementation موازی حذف می‌شود.**

**معیار پایان:** تنها یک route برای هر flow وجود داشته باشد و کد عضویت، حذف کلاس، Q&A و Live در همان route کار کنند.

## تست، CI و مستندات

### ۳۸. CI حذف/ignore شده

**راه‌حل انتخاب‌شده:** `.github/workflows/ci.yml` tracked و exception مربوط از `.gitignore` حذف شود. jobها: PHP lint، migration check، API integration با MariaDB، `flutter analyze`, `flutter test`, web build و smoke test.

**معیار پایان:** PR دارای status check اجباری و branch protection باشد؛ secret فقط GitHub Secrets.

### ۳۹. smoke test روی page error fail نمی‌شود

**راه‌حل انتخاب‌شده:** console error/pageerror/request failure جمع‌آوری شوند؛ پس از allowlist محدود، وجود هر خطا exit code 1 بدهد. selector semantic به‌جای click coordinate استفاده شود.

**معیار پایان:** تزریق یک exception عمدی CI را قرمز کند.

### ۴۰. تست‌ها با باگ‌ها هم‌جهت‌اند

**راه‌حل انتخاب‌شده:** test matrix شامل authorization منفی، join grant، content delete، چهار حالت boolean، assessment lifecycle، class switching، resubmit/version، deadline، file authorization/cleanup و profile باشد. تستی که direct enroll را مجاز فرض می‌کند اصلاح شود.

**معیار پایان:** هر یک از ۴۴ مورد حداقل unit/integration/widget/manual acceptance متناظر داشته باشد؛ P0ها حتماً خودکار باشند.

### ۴۱. نسخهٔ Flutter مستند با pubspec سازگار نیست

**راه‌حل انتخاب‌شده:** نسخهٔ دقیق Flutter متناظر با Dart موردنیاز پروژه pin شود؛ `fvm_config` یا فایل نسخه و CI همان نسخه را استفاده کنند. README به‌جای «3.13+» نسخهٔ آزمایش‌شده را بنویسد.

**معیار پایان:** clone تازه با همان نسخه و یک فرمان مستند build شود.

### ۴۲. ادعای پلتفرم‌هایی که در مخزن وجود ندارند

**راه‌حل انتخاب‌شده:** فعلاً فقط Android و Web در README Supported Platforms ذکر شوند. اگر iOS لازم شد، `flutter create --platforms=ios .` در branch جدا، permissions/signing و تست واقعی اضافه شود؛ سپس ادعا شود.

**معیار پایان:** هر پلتفرم ادعاشده پوشه، CI build و راهنمای اجرا داشته باشد.

### ۴۳. مستندات stale/غلط

**راه‌حل انتخاب‌شده:** docs از behavior تست‌شده تولید/به‌روزرسانی شوند: فایل‌ها از backend، حساب‌های seed دقیق، پنج نوع سؤال پس از تفکیک، timed assessment واقعی، commandهای current و hashهای تاریخچه حذف یا به changelog منتقل شوند.

**معیار پایان:** walkthrough مستند روی clone تمیز بدون دانش قبلی قابل‌اجرا باشد.

### ۴۴. حافظهٔ Gradle بیش از حد

**راه‌حل انتخاب‌شده:** پیش‌فرض معقول مثل `-Xmx2G`space محدود؛ CI با توجه به runner override کند. parallelism و daemon نیز بر اساس RAM تنظیم شوند.

**معیار پایان:** build روی دستگاه/runner حدود ۴ تا ۸GB RAM بدون kill شدن انجام شود.

---

# ۴) تغییرات دیتابیس و API که این راه‌حل نیاز دارد

این موارد باید به‌صورت migration شماره‌دار اعمال شوند، نه import دوبارهٔ `schema.sql` روی دیتابیس موجود.

## migrationهای پیشنهادی

1. `001_join_grants_and_session_hashes.sql`
   - join grant کوتاه‌عمر
   - hash token و index expiry
2. `002_assessment_lifecycle.sql`
   - status، زمان باز/بسته شدن، max attempts، release policy
3. `003_assessment_versions_and_attempt_snapshots.sql`
   - version immutable و snapshot سؤال/گزینه
4. `004_submission_versions_and_deadlines.sql`
   - نسخه‌های تکلیف، late/resubmit policy، graded status
5. `005_live_and_demo_sessions.sql`
   - live session و demo sandbox expiry
6. `006_constraints_and_indexes.sql`
   - option/question consistency، position، pagination/indexها
7. `007_profile_and_audit.sql`
   - profile، session revoke و audit رخدادهای حساس

## قرارداد endpoint

- URLها ترجیحاً versioned باشند: `/api/v1/...`
- method صحیح enforce شود.
- response و error envelope ثابت باشد.
- تمام زمان‌ها UTC و ISO-8601 باشند.
- actionهای retryable، `idempotency_key` بگیرند.
- pagination metadata استاندارد باشد.
- endpoint قدیمی تا یک release با warning سازگاری بماند و سپس طبق changelog retire شود.

---

# ۵) طراحی دموی امن و واقعاً قابل‌استفاده

حساب مشترک ثابت برای رزومه مناسب نیست؛ یک بازدیدکننده می‌تواند داده‌ها را خراب کند و نفر بعدی پروژهٔ شکسته ببیند.

## راه‌حل پیشنهادی: sandbox موقت برای هر بازدیدکننده

دکمهٔ «شروع دمو» این کارها را انجام دهد:

1. rate limit و captcha سبک/اختیاری را بررسی کند.
2. یک teacher و student موقت با شناسه‌های تصادفی بسازد.
3. کلاس، درس، پنج نوع سؤال، تکلیف، Q&A و دادهٔ نمونه را در transaction seed کند.
4. دو انتخاب «ورود به‌عنوان استاد» و «ورود به‌عنوان دانش‌آموز» بدهد؛ هر دو متعلق به همان sandbox باشند.
5. `expires_at` مثلاً دو ساعت بعد قرار دهد.
6. banner دائمی «محیط آزمایشی؛ داده‌ها خودکار حذف می‌شوند» نمایش دهد.
7. cleanup هنگام ساخت sandbox جدید و یک job زمان‌بندی‌شده انجام شود.
8. قبل از حذف DB، فایل‌های همان sandbox نیز پاک شوند.

این روش اجازه می‌دهد create/delete/regenerate/resubmit واقعاً کار کنند، بدون اینکه نمایش نفر بعد خراب شود. همهٔ featureها فعال می‌مانند و هیچ دکمه‌ای نمایشی نیست.

## حفاظت از سهمیهٔ رایگان

- حداکثر ۳ sandbox در ساعت برای هر IP hash‌شده
- سقف ۸MB هر فایل و سقف کلی کوچک‌تر برای هر sandbox
- حذف خودکار پس از ۲ ساعت
- عدم پذیرش دادهٔ حساس واقعی
- logging حداقلی و بدون نگه‌داری طولانی IP خام
- اگر quota پر شد، پاسخ 429/503 شفاف و قابل‌فهم

---

# ۶) استقرار رایگان، مرحله‌به‌مرحله

## ۶.۱. چرا alwaysdata برای این دمو؟

در زمان نگارش، پلن رایگان alwaysdata حدود ۱GB فضا و ۲۵۶MB RAM ارائه می‌کند، سایت PHP و MariaDB/MySQL مدیریت‌شده دارد، SSH/SFTP ارائه می‌دهد و آدرس `alwaysdata.net` دارای HTTPS است. محدودیت‌های پلن رایگان، از جمله آدرس خود سرویس، نبود service daemon و منع استفادهٔ سودآور، باید رعایت شوند.

این deployment یک **PHP Site** معمولی است؛ media server یا daemon روی alwaysdata اجرا نمی‌شود. Live به سرویس WebRTC بیرونی متصل است.

## ۶.۲. ساخت حساب و دیتابیس

1. حساب رایگان alwaysdata بسازید.
2. از بخش `Databases > MySQL` یک database و user بسازید.
3. نام host، database، user و password را یادداشت کنید؛ database فقط از پنل/API ساخته می‌شود.
4. فایل migration بدون `CREATE DATABASE` و `USE` را از phpMyAdmin یا SSH import کنید.
5. charset را `utf8mb4` قرار دهید.

نمونهٔ اتصال SSH برای import:

```bash
mysql -h mysql-USERNAME.alwaysdata.net \
  -u DB_USER -p DB_NAME < migrations/combined.sql
```

## ۶.۳. ساخت سایت PHP

1. در `Web > Sites` یک سایت از نوع PHP بسازید.
2. نسخهٔ PHP آزمایش‌شده، ترجیحاً 8.3 یا نسخهٔ pin‌شده، انتخاب شود.
3. document root فقط پوشهٔ public باشد؛ نمونه:

```text
/home/USERNAME/www/otms/public
```

4. Force HTTPS فعال شود.
5. `display_errors=Off`, `log_errors=On`, timezone مناسب و upload limit تنظیم شود.

ساختار سرور:

```text
/home/USERNAME/www/otms/
  app/                    # source/deployment metadata، خارج public
  config/otms.env         # secret، permission 600، خارج public
  storage/uploads/        # فایل کاربران، خارج public
  public/
    index.html            # Flutter Web build
    assets/
    api/v1/*.php          # PHP endpoints
```

Credential دیتابیس و JaaS در Git یا Flutter قرار نگیرد. config از environment یا فایل فقط‌خواندنی خارج public خوانده شود.

## ۶.۴. تنظیم URL محیط‌ها

در Flutter:

```dart
const apiBaseUrl = String.fromEnvironment(
  'OTMS_API_BASE',
  defaultValue: '/api/v1',
);
```

سه config مستقل:

- local debug
- portfolio demo
- production

هیچ URL ثابت LAN یا localhost وارد release نشود.

## ۶.۵. build وب

روی سیستم دارای نسخهٔ pin‌شدهٔ Flutter:

```bash
cd otms_flutter
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build web --release \
  --base-href=/ \
  --dart-define=OTMS_API_BASE=https://USERNAME.alwaysdata.net/api/v1 \
  --dart-define=OTMS_APP_MODE=portfolio_demo
```

محتوای `build/web/` در `public/` قرار گیرد؛ پوشهٔ `api` overwrite نشود. برای routeهای وب، fallback به `index.html` فقط برای مسیرهای غیر API تنظیم شود.

## ۶.۶. تست پس از استقرار

حداقل این‌ها اجرا شوند:

1. `/api/v1/health` نسخهٔ app، DB status بدون secret و زمان server را بدهد.
2. شروع sandbox دمو
3. ورود استاد و دانش‌آموز
4. join با grant
5. create/delete content
6. هر پنج نوع سؤال
7. start/submit/result assessment و policy جواب
8. submit/resubmit/grade homework
9. Q&A دوطرفه
10. شروع/join Live
11. فایل مجاز و تست 403 کلاس دیگر
12. responsive test روی عرض ۳۶۰px

## ۶.۷. CI/CD بعد از اولین deployment دستی

پس از سالم شدن deployment دستی، GitHub Actions:

1. testها را اجرا کند.
2. web release را بسازد.
3. با SFTP/SSH key محدود، artifact را در staging upload کند.
4. migrationها را با backup و lock اجرا کند.
5. smoke test را اجرا کند.
6. با symlink/current directory یا روش atomic، staging را active کند.

secretهای SSH/DB در GitHub Secrets باشند؛ هیچ password داخل workflow یا repository نباشد.

---

# ۷) ساخت و انتشار APK واقعی Android

## ۷.۱. پیش‌نیازهای release

- application ID واقعی و ثابت
- نام و icon نهایی
- versionCode/versionName
- keystore امن و backupشده خارج repository
- HTTPS API
- permissionهای Camera/Microphone فقط به‌خاطر Live
- privacy notice برای فایل، دوربین و میکروفون

نمونهٔ ساخت keystore:

```bash
keytool -genkeypair -v \
  -keystore ~/otms-release.jks \
  -alias otms \
  -keyalg RSA -keysize 2048 -validity 10000
```

مسیر و رمزها در `android/key.properties` محلی باشد و این فایل commit نشود.

## ۷.۲. ساخت APK

برای recruiter، universal APK ساده‌تر از چند ABI است:

```bash
flutter build apk --release \
  --dart-define=OTMS_API_BASE=https://USERNAME.alwaysdata.net/api/v1 \
  --dart-define=OTMS_APP_MODE=portfolio_demo
```

سپس:

```bash
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

نام قابل‌فهم:

```text
OTMS-demo-v1.0.0-android.apk
```

## ۷.۳. کجا قرار بگیرد؟

### پیشنهاد عمومی رزومه

یک GitHub Release عمومی با این موارد:

- APK
- SHA-256
- changelog
- حداقل نسخهٔ Android
- لینک دموی وب
- هشدار اینکه فایل خارج از Play Store است

اگر source اصلی private باقی می‌ماند، یک repository عمومی جداگانهٔ Showcase/Release بسازید. برای تست محدود تیم، Firebase App Distribution رایگان و مناسب است، ولی برای recruiter ناشناس اصطکاک login/invite دارد و جای لینک عمومی وب را نمی‌گیرد.

### وضعیت مهم Android در ۲۰۲۶

در تاریخ این سند، اجرای اولیهٔ Developer Verification از ۳۰ سپتامبر ۲۰۲۶ فقط برای فروشگاه‌های مشارکت‌کننده در برزیل، اندونزی، سنگاپور و تایلند شروع شده و طبق FAQ رسمی، sideload مستقیم در این مرحله تغییر نکرده است؛ گسترش جهانی برای ۲۰۲۷ برنامه‌ریزی شده است. برای آینده می‌توان package را ثبت کرد، از حساب رایگان Limited Distribution تا ۲۰ دستگاه استفاده کرد، یا کاربر حرفه‌ای مسیر Advanced Installation را فعال کند. در هر صورت، در رزومه **لینک وب باید مسیر اصلی** و APK مدرک واقعی mobile build باشد. انتشار در Google Play اصطکاک نصب را کمتر می‌کند، ولی حساب توسعه‌دهنده هزینهٔ یک‌بارهٔ ۲۵ دلار دارد و حساب شخصی جدید در حال حاضر به closed test با دست‌کم ۱۲ tester برای ۱۴ روز نیاز دارد.

## ۷.۴. iPhone

نمایش Flutter Web در Safari رایگان است. انتشار عمومی native iOS معمولاً به Apple Developer Program با هزینهٔ سالانه نیاز دارد؛ پس جزو مسیر صفرهزینهٔ فعلی نیست.

---

# ۸) گزینه‌هایی که برای مسیر اصلی انتخاب نشدند

## GitHub Pages یا Firebase Hosting به‌تنهایی

برای Flutter Web عالی‌اند، اما PHP اجرا نمی‌کنند. API و DB همچنان به host جدا نیاز دارد. پس اگر استفاده شوند فقط frontend را میزبانی می‌کنند و CORS/دو deployment به پروژه اضافه می‌شود.

## InfinityFree

با وجود تبلیغ PHP/MySQL رایگان، راهنمای رسمی انجمن آن free hosting را برای website مرورگری می‌داند، نه API hosting. درخواست‌های Flutter Android ممکن است توسط لایهٔ امنیتی/محدودیت‌ها مسدود شوند؛ بنابراین گزینهٔ قابل‌اعتماد برای API موبایل نیست.

## Koyeb و سرویس‌های container رایگان

می‌توانند PHP container را اجرا کنند، اما free service ممکن است پس از بی‌کاری sleep شود و دیتابیس رایگان آن‌ها drop-in MySQL دائمی نیست. برای فرد تازه‌کار و همین stack، migration/پیچیدگی بیشتری دارد.

## Firebase/Supabase به‌عنوان backend

برای free tier جذاب‌اند ولی به معنی بازنویسی auth، schema، permission و API هستند. این هزینه اکنون لازم نیست و ریسک از دست رفتن featureهای فعلی را بالا می‌برد.

---

# ۹) تفاوت دموی رزومه با production

| موضوع | دموی رایگان رزومه | production واقعی |
|---|---|---|
| داده | فقط ساختگی و موقت | دادهٔ واقعی با policy نگه‌داری |
| host | free shared hosting | سرویس پولی با SLA یا VPS مدیریت‌شده |
| ظرفیت | کم و بدون تضمین | براساس کاربر و load test |
| database | یک MariaDB کوچک | DB جدا، backup، replica/restore آزمایش‌شده |
| فایل | quota محدود و cleanup سریع | object storage خصوصی + signed URL |
| Live | free quota و بدون SLA | سرویس پولی یا cluster خودمیزبان |
| حساب‌ها | sandbox موقت | ایمیل تأییدشده، invite/approval و recovery |
| مانیتورینگ | health check و log محدود | alert، error tracking، metrics و audit |
| امنیت | برای دادهٔ ساختگی سخت‌سازی می‌شود | threat model، تست نفوذ، rotation و incident plan |
| پشتیبان | پیش از deploy و دوره‌ای | خودکار، رمزگذاری‌شده و restore drill |
| حقوقی | اعلان Demo و عدم ورود دادهٔ واقعی | privacy policy، رضایت، GDPR و retention |

برای production آموزشی در اتحادیهٔ اروپا باید حداقل حریم خصوصی، محل پردازش داده، قرارداد پردازش‌گرها، حذف حساب/داده، export و رضایت برای محتوای دانش‌آموز بررسی شود. free shared hosting محل مناسبی برای اطلاعات واقعی دانش‌آموزان نیست.

---

# ۱۰) ترتیب اجرای عملی

## فاز صفر — امنیت و شاخه‌بندی، نیم‌روز

- revoke کردن PAT ارسال‌شده در چت
- backup دیتابیس
- branch `fix/security-and-stability`
- pin Flutter
- اضافه کردن CI پایه

## فاز یک — P0 و جریان‌های اصلی، حدود ۳ تا ۵ روز

- join grant
- content delete
- قرارداد سؤال‌ها
- stale tab/card
- result navigation
- کد استاد، حذف کلاس و Q&A در route فعال
- responsive shell گوشی
- error/empty states

## فاز دو — featureهای کامل، حدود ۱ تا ۲ هفته

- assessment lifecycle/version/snapshot
- homework version/deadline/feedback
- profile/password واقعی
- file authorization/cleanup
- dashboard واقعی
- Live provider integration

## فاز سه — سخت‌سازی و تست، حدود ۱ هفته

- HTTPS/token/cookie
- validation/error envelope
- rate limits و session hash
- pagination/N+1/transactions
- test matrix و smoke test
- release signing

## فاز چهار — دمو و انتشار، حدود ۲ تا ۴ روز

- demo sandbox
- alwaysdata deployment
- web smoke test روی گوشی
- signed APK و GitHub Release
- README، screenshot، QR و ویدیوی کوتاه

زمان‌ها تقریبی و برای یک توسعه‌دهنده‌اند؛ کیفیت داده‌های فعلی و تغییرات schema می‌تواند آن‌ها را تغییر دهد.

---

# ۱۱) چک‌لیست «آمادهٔ رزومه»

دمو فقط وقتی public شود که همهٔ موارد زیر برقرار باشند:

- [ ] PAT قبلی revoke شده است.
- [ ] هیچ secret یا release keystore در Git نیست.
- [ ] تمام P0ها test خودکار دارند.
- [ ] هیچ دکمهٔ اصلی callback خالی یا برچسب fake ندارد.
- [ ] کد استاد، Join، Lessons، Assessment، Homework، Q&A، Live، Profile و Delete واقعاً کار می‌کنند.
- [ ] داشبورد فقط دادهٔ API را نشان می‌دهد.
- [ ] HTTPS اجباری و فایل‌ها private هستند.
- [ ] Android release با کلید release امضا شده است.
- [ ] عرض ۳۶۰px بدون overflow است.
- [ ] sandbox هر بازدیدکننده مستقل و دارای expiry است.
- [ ] web demo، APK، source/showcase و README لینک متقابل دارند.
- [ ] محدودیت free hosting و Demo بودن داده‌ها واضح است.
- [ ] restore دیتابیس حداقل یک بار آزمایش شده است.

---

# ۱۲) منابع رسمی مرتبط با تصمیم میزبانی و انتشار

- alwaysdata Free و محدودیت‌ها: https://help.alwaysdata.com/en/docs/admin-billing/billing/public-cloud-prices/
- PHP در alwaysdata: https://help.alwaysdata.com/en/languages/php/configuration/
- MariaDB/MySQL در alwaysdata: https://help.alwaysdata.com/en/docs/web-hosting/databases/mariadb/
- HTTPS خودکار alwaysdata: https://help.alwaysdata.com/en/security/ssl-tls/lets-encrypt/
- SSH alwaysdata: https://help.alwaysdata.com/en/docs/web-hosting/remote-access/ssh/
- GitHub Pages و نبود پشتیبانی PHP: https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site
- Firebase Hosting: https://firebase.google.com/products/hosting
- Firebase App Distribution: https://firebase.google.com/products/app-distribution
- Android app signing: https://developer.android.com/studio/publish/app-signing
- Google Play registration: https://support.google.com/googleplay/android-developer/answer/6112435
- Android developer verification: https://developer.android.com/developer-verification/guides
- Apple Developer Program: https://developer.apple.com/programs/whats-included/
- Jitsi Flutter SDK: https://jitsi.github.io/handbook/docs/dev-guide/dev-guide-flutter-sdk/
- Jitsi as a Service: https://jaas.8x8.vc/

---

# نتیجهٔ نهایی

برای OTMS، بهترین مسیر این نیست که قابلیت‌ها حذف شوند یا backend از صفر بازنویسی شود. مسیر مناسب عبارت است از:

1. تثبیت و امن‌سازی PHP/MySQL فعلی؛
2. تبدیل تمام UIهای ساختگی/قدیمی به feature فعال واقعی؛
3. Android-first کردن Flutter و ساخت Web responsive از همان codebase؛
4. اضافه کردن assessment lifecycle، file authorization و demo sandbox؛
5. انتشار رایگان وب+API روی alwaysdata برای رزومه؛
6. انتشار APK امضاشده در GitHub Release؛
7. مهاجرت به زیرساخت پولی و دارای SLA فقط هنگام ورود کاربران و دادهٔ واقعی.

این روش همهٔ قابلیت‌های مدنظر را نگه می‌دارد، هر مشکل شناخته‌شده را با معیار تست‌پذیر می‌بندد و بدون تحمیل بازنویسی غیرضروری، یک نمونهٔ رزومه‌ای قابل‌نمایش روی گوشی می‌سازد.
