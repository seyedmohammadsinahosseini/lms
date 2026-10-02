# گزارش بازبینی کامل مخزن OTMS

**تاریخ بازبینی:** ۲۰۲۶-۱۰-۰۲
**شاخه:** `main`
**کامیت بررسی‌شده:** `c89f74acbc6b79b67c7d73d315f963f06a82330e` (`c89f74a`)
**حجم بررسی:** ۱۴۰ فایل tracked؛ ۱۳۰ فایل متنی/کد/پیکربندی و ۱۰ تصویر؛ حدود ۱۲٬۵۸۴ خط کد در backend، Flutter و ابزارها.

## هشدار فوری دربارهٔ توکن

توکن GitHub در پیام چت به‌صورت واضح ارسال شده است. حتی اگر فقط برای همین بررسی ساخته شده، باید **همین حالا revoke شود** و در صورت نیاز یک Fine-grained PAT تازه با کمترین دسترسی ممکن ساخته شود. خود توکن در این گزارش تکرار نشده و در remote یا فایل‌های پروژه ذخیره نشده است.

---

## جمع‌بندی مدیریتی

پروژه از نظر ساختار اولیه قابل‌فهم است و چند اقدام امنیتی خوب دارد، اما در وضعیت فعلی **آمادهٔ انتشار واقعی نیست**. مهم‌ترین موانع عبارت‌اند از:

1. دانش‌آموز می‌تواند بدون داشتن کد استاد، فقط با حدس `class_id` وارد هر کلاس شود.
2. حذف محتوا همیشه به‌خاطر نام اشتباه جدول SQL خراب است.
3. سؤال‌های «False» و «No» از UI عملاً با جواب صحیح «True» و «Yes» ذخیره می‌شوند.
4. زمان آزمون فقط یک عدد نمایشی است؛ سرور آن را اعمال نمی‌کند، API چند تلاش می‌پذیرد و بعد از تلاش اول کل جواب‌های صحیح را نشان می‌دهد.
5. با تعویض کلاس در داشبورد جدید، تب‌ها ممکن است دادهٔ کلاس قبلی را زیر عنوان کلاس جدید نشان دهند.
6. داشبورد فعلی استاد کد عضویت را نشان نمی‌دهد و Q&A و Live آن ناقص/غیرفعال‌اند؛ پیاده‌سازی‌های درست‌تر در فایل‌های قدیمی وجود دارند ولی route اصلی به آن‌ها نمی‌رود.
7. طراحی فعلی روی گوشی با sidebar ثابت ۲۶۰ پیکسلی و پنجرهٔ ثابت ۵۰۰×۵۸۰ عملاً مشکل جدی دارد.
8. نسخهٔ release اندروید با کلید debug امضا می‌شود و cleartext HTTP برای کل برنامه باز است.

---

# یافته‌ها، به‌ترتیب اولویت

## ⛔ P0 — مسدودکنندهٔ انتشار

### 1) دورزدن کامل کد استاد هنگام عضویت در کلاس

**فایل:** `backend/api/enroll.php:7-15`

endpoint فقط وجود `class_id` را چک می‌کند و هیچ ارتباطی میان درخواست و کدی که دانش‌آموز lookup کرده برقرار نمی‌کند. شناسه‌های کلاس عددی و قابل حدس‌اند؛ بنابراین هر دانش‌آموز authenticated می‌تواند `1, 2, 3, ...` را امتحان کند و مستقیماً عضو کلاس‌ها شود.

**اثر:** دورزدن کنترل دسترسی و مشاهدهٔ درس‌ها، آزمون‌ها، تکالیف و Q&A کلاس‌های ناخواسته.

**اصلاح پیشنهادی:** عضویت باید در همان transaction، کد فعال استاد را با `classes.teacher_id` تطبیق دهد؛ یا `code_lookup` یک grant کوتاه‌عمر و یک‌بارمصرف صادر کند که `enroll` آن را اعتبارسنجی کند. تست منفی «عضویت بدون کد معتبر = 403» ضروری است.

---

### 2) endpoint حذف محتوا به جدول غیرموجود وصل می‌شود

**فایل:** `backend/api/content_delete.php:10-20`
**جدول واقعی:** `contents` در `backend/schema.sql:88`

در دو query از `content` مفرد استفاده شده، در حالی که schema جدول `contents` دارد. در نتیجه حذف محتوا با خطای SQL/HTTP 500 شکست می‌خورد.

**اصلاح:** هر دو مورد `content` به `contents` تغییر کنند؛ سپس تست integration برای create → delete → list اضافه شود.

---

### 3) قرارداد UI و backend برای True/False و Yes/No ناسازگار است

**کلاینت:** `otms_flutter/lib/screens/teacher/assessment_builder.dart:287-299`
**سرور:** `backend/api/question_add.php:43-50`

کلاینت انتخاب درست را در آرایهٔ `options` می‌فرستد، اما سرور برای این دو نوع، آرایه را نادیده می‌گیرد و فقط فیلد `correct` را می‌خواند. چون UI این فیلد را نمی‌فرستد:

- انتخاب **False** در UI، روی سرور **True** ذخیره می‌شود.
- انتخاب **No** در UI، روی سرور **Yes** ذخیره می‌شود.

**اصلاح:** کلاینت باید `payload['correct'] = 'false'/'true'` یا `'no'/'yes'` بفرستد؛ بهتر است قرارداد backend نیز یکدست شود و فقط یک قالب برای همهٔ انواع سؤال پذیرفته شود. تست هر چهار حالت لازم است.

---

### 4) «آزمون زمان‌دار» و محدودیت تلاش در سرور وجود ندارد

**فایل‌ها:**

- `backend/schema.sql:109,132-142`
- `backend/api/attempt_submit.php:15-39`
- `backend/api/attempt_get.php:34-52`
- `otms_flutter/lib/screens/student/take_assessment.dart` — هیچ `Timer` یا enforcement ندارد.

مشکلات ترکیبی:

- `duration_min` ذخیره می‌شود ولی هنگام submit بررسی نمی‌شود.
- `started_at` تازه هنگام submit ساخته می‌شود؛ endpoint شروع آزمون وجود ندارد.
- هیچ unique constraint یا policy برای یک تلاش وجود ندارد؛ API هر بار attempt جدید می‌سازد.
- بعد از اولین submit، `attempt_get.php` جواب صحیح همهٔ سؤال‌ها را به همان دانش‌آموز برمی‌گرداند.

بنابراین دانش‌آموز می‌تواند تلاش خالی ثبت کند، جواب‌ها را ببیند و با درخواست مستقیم API تلاش دوم کامل بفرستد. همچنین محدودیت زمانی را کاملاً دور بزند.

**اصلاح معماری:** endpoint جدا برای start، ثبت زمان سمت سرور، attempt فعال، محدودیت تعداد تلاش، قفل submit پس از deadline، policy انتشار نتیجه/answer key، و unique/index مناسب. زمان کلاینت فقط برای UX باشد، نه مرجع امنیتی.

---

### 5) دادهٔ تب‌ها پس از تعویض کلاس stale می‌ماند

**والدها:**

- `student_dashboard.dart:744-770`
- `teacher_dashboard.dart:650-679`

**تب‌ها:** `LessonsTab`, `AssessmentsTab`, `HomeworkTab`, `QaTab`, `TLessonsTab`, `TAssessmentsTab`, `THomeworkTab`, `TStudentsTab` فقط در `initState()` بر اساس `widget.classId` Future می‌سازند و هیچ‌کدام `didUpdateWidget` ندارند.

وقتی `_selectedClassId` عوض می‌شود، Flutter معمولاً state همان widgetهای هم‌نوع و بدون key را reuse می‌کند. نتیجه: عنوان کلاس جدید است ولی Future و فهرست می‌تواند متعلق به کلاس قبلی بماند.

**اثر:** نمایش دادهٔ اشتباه، عملیات روی آیتم‌های کلاس قبلی، و سردرگمی جدی کاربر.

**اصلاح:** روی subtree کلاس `ValueKey(classId)` قرار گیرد یا همهٔ تب‌ها در `didUpdateWidget` تغییر `classId` را تشخیص دهند و reload کنند. برای کارت‌های lesson نیز `ValueKey(lesson.id)` لازم است چون `_contents` cache شده است.

---

### 6) مسیر اصلی استاد، قابلیت حیاتی «کد عضویت» را حذف کرده است

**route فعال:** `otms_flutter/lib/app.dart:63` → `TeacherDashboard`
**پیاده‌سازی کد:** `teacher_home.dart:27,135`، اما `TeacherHome` از route اصلی استفاده نمی‌شود.

دانش‌آموز در صفحهٔ join می‌بیند «کد را از داشبورد استاد بگیرید»، ولی داشبورد فعلی استاد آن کد را نمایش نمی‌دهد. بدون دسترسی مستقیم به DB یا نسخهٔ قدیمی UI، جریان اصلی عضویت قابل تکمیل نیست.

**اصلاح:** کارت کد و regenerate از `TeacherHome` به `TeacherDashboard` منتقل شود یا route اصلی موقتاً به `TeacherHome` برگردد.

---

### 7) اپ اندروید فعلی واقعاً mobile-responsive نیست

**فایل:** `otms_flutter/lib/screens/shared/sidebar.dart`

- sidebar همیشه در یک `Row` با عرض اولیهٔ ۲۶۰ پیکسل نمایش داده می‌شود (`:39-42`, `:496+`). روی گوشی ۳۶۰ پیکسلی تقریباً فقط ۱۰۰ پیکسل برای محتوا باقی می‌ماند.
- منوی کاربر دقیقاً ۵۰۰×۵۸۰ است (`:97-102`) و روی اکثر گوشی‌ها از صفحه بیرون می‌زند.
- چند bottom sheet بزرگ نیز `Column` بدون scroll دارند، مخصوصاً question builder.
- gridهای dashboard گاهی breakpoint را از کل `MediaQuery` می‌گیرند، نه عرض واقعی باقی‌مانده بعد از sidebar.

**اصلاح:** در عرض کوچک از `Drawer`/`NavigationDrawer` استفاده شود، overlay با `ConstrainedBox` و padding امن ساخته شود، و sheetها `DraggableScrollableSheet` یا `SingleChildScrollView` داشته باشند.

---

## 🔴 P1 — باگ‌ها و ریسک‌های جدی

### 8) صفحهٔ نتیجه بلافاصله بعد از submit pop می‌شود

**فایل:** `otms_flutter/lib/screens/student/take_assessment.dart:83-86`

ابتدا `pushReplacement(Result)` اجرا می‌شود و بلافاصله `Navigator.pop(true)` همان route نتیجه را می‌بندد. نتیجه معمولاً نمایش داده نمی‌شود یا فقط لحظه‌ای دیده می‌شود.

**اصلاح:** از `pushReplacement(..., result: true)` استفاده شود، یا ابتدا route آزمون با نتیجه بسته شود و صفحهٔ list خودش result را باز کند.

---

### 9) Q&A و Live استاد در داشبورد فعال ناقص‌اند

- داشبورد فعلی استاد به‌جای `QaTab` یک placeholder می‌سازد: `teacher_dashboard.dart:687-714`.
- دکمهٔ `Go live (demo)` در همین داشبورد callback خالی دارد: `teacher_dashboard.dart:880`.
- پیاده‌سازی قابل استفاده در `teacher_class_detail.dart:44` و `LiveDemoScreen` وجود دارد، ولی آن صفحه از مسیر اصلی قابل دسترسی نیست.

**اثر:** استاد از UI فعلی نمی‌تواند سؤال‌های دانش‌آموز را پاسخ دهد و دکمهٔ Live هیچ کاری نمی‌کند.

---

### 10) حذف کلاس از UI فعلی استاد قابل دسترسی نیست

API و UI قدیمی برای delete وجود دارند (`teacher_home.dart:280-312`)، اما route فعال `TeacherDashboard` است و در آن delete class وجود ندارد. README نیز این محدودیت را پذیرفته، ولی برای محصول واقعی نقص عملیاتی است.

---

### 11) داشبوردها دادهٔ ساختگی را مثل دادهٔ واقعی نشان می‌دهند

**دانش‌آموز:**

- آزمون‌های آینده hard-coded: `student_dashboard.dart:280-305`
- میانگین ثابت `78.5`: `:783-786`
- رتبه، streak و زمان ثابت: `:481-484`
- دکمه‌های `View All` و `Details` بدون عمل: `:273-275`, `:404-406`

**استاد:**

- اسامی و نمره‌های ساختگی Alice/Bob/...: `teacher_dashboard.dart:392-396`
- آزمون‌های آینده hard-coded و برخی دکمه‌های بدون عمل: `:277-310`, `:383`
- تعداد assessment و pending grading تخمینی/placeholder: `:727-735`

این داده‌ها با DB واقعی یکی نیستند و می‌توانند تصمیم کاربر را اشتباه کنند. باید یا از API واقعی بیایند یا صریحاً با برچسب DEMO پنهان/تفکیک شوند.

---

### 12) داشبورد پس از load خودکار وارد اولین کلاس می‌شود و خطاها را می‌بلعد

- `student_dashboard.dart:43-56`
- `teacher_dashboard.dart:42-55`

اگر کلاس وجود داشته باشد `_selectedClassId` خودکار روی اولین کلاس می‌رود، بنابراین dashboard overview اولیه دیده نمی‌شود. خطای load نیز فقط loading را خاموش می‌کند و هیچ پیام/Retry نمی‌دهد؛ کاربر خطای شبکه را با «هیچ کلاسی ندارم» اشتباه می‌گیرد.

همچنین اگر کلاس انتخاب‌شده بیرون از این صفحه حذف شود، `firstWhere` در `_buildClassDetail` می‌تواند exception بدهد.

---

### 13) crash و متن تکراری در کارت کلاس دانش‌آموز

**فایل:** `student_dashboard.dart:689-710`

description یک بار داخل شرط null/empty و بار دوم بدون شرط با `cls.description!` نمایش داده می‌شود. اگر DB مقدار NULL داشته باشد crash رخ می‌دهد؛ در حالت عادی متن دوبار تکرار می‌شود.

---

### 14) cache محتوای lesson با جابه‌جایی آیتم‌ها اشتباه می‌شود

`_LessonCard` و `_TLessonCard` stateful هستند، `_contents` را cache می‌کنند و کارت‌ها در `ListView.builder` key ندارند. پس از حذف یا reorder درس، state یک index ممکن است روی lesson دیگری reuse شود و محتوای درس قبلی زیر عنوان درس جدید دیده شود.

**فایل‌ها:**

- `student/tabs/lessons_tab.dart:65-74`
- `teacher/tabs/t_lessons_tab.dart:88-99`

---

### 15) feedback تکلیف به دانش‌آموز هرگز نمی‌رسد

UI در `student/tabs/homework_tab.dart:111-124` دنبال `my_submission.feedback` می‌گردد، ولی backend در `homework_list.php:20` فقط `id, submitted_at, grade` را انتخاب می‌کند و response نیز feedback ندارد.

**اصلاح:** `feedback` به query و response اضافه شود و تست widget/API برای نمایش بازخورد نوشته شود.

---

### 16) resubmit تکلیف داده را خراب یا قدیمی نگه می‌دارد

**فایل:** `backend/api/submission_submit.php:23-34`

- sheet متن قبلی را prefill نمی‌کند.
- ارسال فایل جدید بدون متن، متن قبلی را با رشتهٔ خالی پاک می‌کند.
- grade و feedback قبلی هنگام resubmit پاک نمی‌شوند؛ نمره می‌تواند برای نسخهٔ جدید باقی بماند.
- فایل قبلی پس از جایگزینی حذف نمی‌شود و orphan می‌ماند.
- deadline تکلیف بررسی نمی‌شود.

بهتر است semantics واضح `PATCH`/replace تعریف شود و روی resubmit، grade/feedback بر اساس policy reset شوند.

---

### 17) فایل‌های کاربران عمومی و بدون authorization هستند

مسیرهایی مثل `backend/uploads/<random>.pdf` مستقیم از web root سرو می‌شوند. هرکس URL را داشته باشد بدون token فایل را می‌خواند. README این را در Security notes به‌عنوان محدودیت پذیرفته است، اما برای تکلیف دانش‌آموز و محتوای کلاس ریسک حریم خصوصی جدی است.

همچنین delete شدن submission/homework/lesson/class فقط رکورد DB را پاک می‌کند و هیچ `unlink`ی وجود ندارد؛ فایل‌ها دائماً orphan می‌شوند.

**اصلاح:** فایل‌ها بیرون web root ذخیره و از endpoint دانلود دارای auth/ownership سرو شوند؛ عملیات DB و فایل cleanup نیز هماهنگ شود.

---

### 18) ترکیب HTTP ساده و ذخیرهٔ token در SharedPreferences

- `AndroidManifest.xml:12`، cleartext برای کل app باز است.
- token در `api_client.dart:48-90` داخل SharedPreferences ذخیره می‌شود.
- راهنمای گوشی از HTTP روی LAN استفاده می‌کند.

روی Wi-Fi نامطمئن، email/password و bearer token قابل شنودند. روی Android نیز SharedPreferences جای secure storage نیست؛ روی web token در storage قابل دسترس JavaScript است.

**اصلاح:** release فقط HTTPS؛ Network Security Config محدود به debug؛ برای mobile از secure storage؛ برای web در معماری production ترجیحاً session cookie امن/HttpOnly و CSRF مناسب.

---

### 19) حساب‌های demo با رمز عمومی داخل schema اصلی ساخته می‌شوند

**فایل:** `backend/schema.sql:203-210`
**UI:** `login_screen.dart:158-185`

هر deployment که schema را بدون پاک‌سازی import کند، یک teacher و student با رمز شناخته‌شده `password` دارد؛ صفحهٔ login نیز آن‌ها را علنی نشان می‌دهد.

**اصلاح:** seed از schema production جدا شود؛ demo hint فقط در build flavor دمو نمایش داده شود؛ checklist deployment حذف/تغییر حساب‌ها داشته باشد.

---

### 20) نسخهٔ release با debug key امضا می‌شود

**فایل:** `otms_flutter/android/app/build.gradle.kts:22-38`

- `applicationId` هنوز `test.otms.otms_flutter` است.
- release صریحاً از `signingConfigs.getByName("debug")` استفاده می‌کند.

این build برای انتشار فروشگاه/به‌روزرسانی امن مناسب نیست. باید application ID واقعی، keystore release خارج از repo، و تنظیمات minify/shrink مناسب تعریف شود.

---

### 21) دادهٔ attempt snapshot نیست و با ویرایش سؤال‌ها خراب می‌شود

`attempt_get.php:23-30` پاسخ قدیمی را با جدول **فعلی** questions join می‌کند. اگر استاد بعد از submit سؤال را حذف یا سؤال جدید اضافه کند:

- سؤال حذف‌شده و answer آن cascade می‌شود.
- سؤال جدید در نتیجهٔ attempt قدیمی به‌صورت بی‌پاسخ ظاهر می‌شود.
- score ذخیره‌شده دیگر با سؤال‌های نمایشی هم‌خوان نیست.

Schema همچنین `UNIQUE(attempt_id, question_id)` ندارد و FK فعلی تضمین نمی‌کند `option_id` متعلق به همان `question_id` باشد.

**اصلاح:** پس از publish/اولین attempt، سؤال‌ها immutable شوند یا نسخه/snapshot assessment و answer key ذخیره شود؛ constraints دیتابیس تقویت شوند.

---

### 22) وضعیت essay در seed و UI ناسازگار است

`tools/demo_seed.sql:173,178,...` برای essayهای نمره‌داده‌شده `points_earned` دارد ولی `is_correct` را NULL گذاشته است. UI grading با `isCorrect == null` تشخیص pending می‌دهد (`essay_grading_screen.dart:42-45`)، در حالی که backend با `points_earned IS NULL` تشخیص می‌دهد.

**نتیجه:** essay نمره‌خورده دوباره در صفحهٔ grading نمایش داده می‌شود و result ممکن است هم‌زمان header «Graded» و آیکون hourglass نشان دهد.

**اصلاح:** معیار واحد `points_earned == null` یا فیلد مستقل `graded_at/status`؛ seed نیز مطابق همان معیار اصلاح شود.

---

### 23) badge وضعیت attempt استاد برعکس مفهوم backend است

**فایل:** `teacher/tabs/attempts_screen.dart:115-121`

در backend، `completed` یعنی essay هنوز منتظر grading است و `graded` یعنی تمام شده؛ UI برای `completed` آیکون سبز check و برای `graded` hourglass نارنجی می‌گذارد.

---

### 24) deadline تکلیف و اعتبار واقعی تاریخ enforce نمی‌شود

- `homework_create.php:14` فقط regex شکل `YYYY-MM-DD` دارد؛ تاریخ‌هایی مثل `2026-99-99` از regex عبور می‌کنند و بسته به SQL mode خطا/تبدیل می‌شوند.
- `submission_submit.php` اصلاً `due_date` را نمی‌خواند؛ submit و resubmit بعد از deadline آزاد است.

باید `DateTime::createFromFormat` با بررسی خطا و policy صریح late submission استفاده شود.

---

### 25) کنترل ورودی و مدیریت خطای API ناکافی است

نمونه‌ها:

- `body()` در `helpers.php:7-16`، JSON خراب را به‌جای 400 مثل body خالی می‌پذیرد.
- طول name/title/email/grade با محدودیت ستون‌ها چک نمی‌شود؛ ورودی بلند به exception و 500 می‌رسد.
- exception handler مرکزی و JSON error envelope برای خطاهای غیرمنتظره وجود ندارد؛ در سروری با `display_errors=On` جزئیات SQL ممکن است لو برود.
- بسیاری از endpointهای GET، method را enforce نمی‌کنند.
- `json_encode` failure بررسی نشده است.

---

## 🟠 P2 — مشکلات متوسط، پایداری و نگه‌داری

### 26) option نامعتبر از سؤال دیگر پذیرفته و در DB ذخیره می‌شود

در `attempt_submit.php:64-74` اگر `option_id` متعلق به سؤال دیگری باشد، نمره صفر می‌شود ولی همان option به‌خاطر FK عمومی `options(id)` در answer ذخیره می‌شود. این داده ناسازگار است و گزارش نتیجه chosen option را پیدا نمی‌کند.

**اصلاح:** قبل از insert، option باید صریحاً در options همان سؤال وجود داشته باشد؛ ورودی نامعتبر 400 بگیرد.

---

### 27) Multiple Choice می‌تواند چند جواب صحیح داشته باشد ولی UI دانش‌آموز radio است

builder و backend چند `is_correct=true` را قبول می‌کنند، اما دانش‌آموز فقط یک Radio انتخاب می‌کند. فعلاً هرکدام از گزینه‌های صحیح امتیاز کامل می‌گیرند. اگر هدف single-choice است، دقیقاً یک جواب صحیح enforce شود؛ اگر multi-select است، مدل پاسخ و UI باید checkbox باشد.

---

### 28) خطای load محتوای lesson به‌صورت «No content» نمایش داده می‌شود

FutureBuilder داخلی content در هر دو فایل `lessons_tab.dart` و `t_lessons_tab.dart` `snap.hasError` را بررسی نمی‌کند. قطع شبکه یا 500 با empty state اشتباه گرفته می‌شود.

---

### 29) setState بعد از dispose در lookup کد ممکن است رخ دهد

**فایل:** `student/join_teacher_screen.dart:35-36`

بعد از `await lookupCode` بدون `if (!mounted) return` مستقیماً `setState` شده است. اگر کاربر در حین درخواست صفحه را ببندد، exception رخ می‌دهد.

---

### 30) upload handling در چند edge case ضعیف است

- `save_upload()` برای خطاهای `UPLOAD_ERR_PARTIAL`, `NO_TMP_DIR`, `CANT_WRITE` فقط null برمی‌گرداند (`helpers.php:126-130`) و پیام دقیق ندارد.
- اعتبارسنجی اصلی بر مبنای extension است؛ MIME/magic bytes بررسی نمی‌شود.
- فایل پیش از insert DB ذخیره می‌شود؛ failure دیتابیس فایل orphan می‌سازد.
- کلاینت با `withData: true` و `readAsBytes()` کل فایل را قبل از محدودیت ۸ MB وارد RAM می‌کند (`file_helper.dart:15,27`)؛ فایل بسیار بزرگ می‌تواند فشار حافظه ایجاد کند.

اقدامات امنیتی فعلی مثل allowlist، نام تصادفی و `.htaccess` خوب‌اند، ولی این edge caseها باقی مانده‌اند.

---

### 31) queryهای N+1 و نبود pagination

نمونه‌ها:

- `assessment_get.php` برای هر سؤال یک query options.
- `attempt_submit.php` برای هر سؤال یک query options.
- `attempt_get.php` برای هر سؤال یک query options.
- `assessments_list.php` برای هر assessment یک query latest attempt.
- `homework_list.php` برای هر homework یک query submission/count.

همهٔ listها نیز بدون limit/pagination هستند. با رشد کلاس، latency و بار DB سریع بالا می‌رود.

---

### 32) race condition در position و ساخت کد

`MAX(position)+1` بیرون transaction/lock محاسبه می‌شود (`lesson_create.php`, `question_add.php`)، پس دو درخواست هم‌زمان position تکراری می‌گیرند. register و regenerate نیز check-then-insert دارند؛ regenerate ابتدا همهٔ کدها را غیرفعال می‌کند و transaction ندارد، پس failure می‌تواند استاد را بی‌کد بگذارد.

---

### 33) نشست‌ها به‌صورت token خام ذخیره می‌شوند

`backend/schema.sql:34-40` token bearer را به‌صورت plaintext و primary key نگه می‌دارد. نشت DB یعنی دسترسی مستقیم به نشست‌های فعال. بهتر است فقط hash token در DB نگه داشته شود. cleanup نشست منقضی نیز فقط هنگام login انجام می‌شود.

---

### 34) password policy و rate limit کامل نیست

- حداقل رمز فقط ۶ کاراکتر است (`register.php:13`).
- rate limit فقط login و فقط زوج email+IP را پوشش می‌دهد؛ register و code lookup throttle ندارند.
- هرکس می‌تواند teacher account بسازد؛ اگر پلتفرم عمومی نیست، باید invite/admin approval وجود داشته باشد.
- کد استاد فقط ۶ hex یعنی ۲۴ بیت entropy دارد؛ پس بعد از اصلاح enroll، lookup باید rate-limit شود.

---

### 35) لینک ویدیو scheme محدود ندارد

`content_create.php` URL را validate نمی‌کند و `content_viewer.dart` هر URI قابل parse را با `LaunchMode.externalApplication` باز می‌کند. بهتر است فقط `https` و در محیط توسعه `http` پذیرفته شوند تا schemeهایی مثل `intent:`, `file:` یا deep link ناخواسته باز نشوند.

---

### 36) profile و change password نمایشی‌اند اما مثل قابلیت واقعی ارائه شده‌اند

`sidebar.dart:358-493` فرم‌ها را می‌گیرد ولی هیچ API ندارد و فقط پیام `(demo)` نشان می‌دهد. controllerهای موقت نیز dispose نمی‌شوند. این قابلیت باید یا واقعاً پیاده‌سازی شود یا به‌وضوح غیرفعال/حذف شود.

همچنین `dispose()` خود Sidebar، `_removeUserMenuOverlay()` را صدا می‌زند و آن تابع در صورت mounted بودن `setState` می‌کند (`:55-58`, `:125-128`)؛ setState در چرخهٔ dispose می‌تواند assertion ایجاد کند.

---

### 37) کد مرده و دو نسل UI هم‌زمان نگه داشته شده‌اند

`StudentHome`, `TeacherHome`, `ClassDetail`, `TeacherClassDetail` پیاده‌سازی قدیمی و بعضاً کامل‌ترند، ولی app به Dashboardهای جدید route می‌شود. این وضعیت باعث regression فعلی شده: کد عضویت، delete class، Q&A و Live در فایل قدیمی وجود دارند ولی در UI فعال نیستند.

راه درست، ادغام قابلیت‌ها و حذف نسل مرده پس از تست است، نه نگهداری دو مسیر موازی.

---

## 🧪 تست، CI و ابزارها

### 38) CI عمداً از repository حذف و ignore شده است

`.gitignore:29-34` فایل `.github/workflows/ci.yml` را ignore می‌کند و هیچ workflow فعالی در مخزن نیست. بنابراین merge/pushها هیچ `flutter analyze`, `flutter test` یا تست API خودکاری ندارند.

**اصلاح:** workflow باید tracked باشد؛ برای push از fine-grained token/GitHub App یا web UI با دسترسی مناسب استفاده شود، نه حذف CI از محصول.

---

### 39) web smoke test برخلاف توضیحش روی page error fail نمی‌شود

`tools/web_smoke_test.js:42-46` خطاهای console و `pageerror` را فقط چاپ می‌کند و exit code را تغییر نمی‌دهد. فقط خطای top-level promise در `:73` باعث exit 1 می‌شود. بنابراین تستی که exception مرورگر دیده، همچنان سبز تمام می‌شود.

**اصلاح:** خطاها در آرایه جمع شوند و قبل از پایان، اگر آرایه non-empty بود `process.exitCode = 1` شود؛ allowlist برای خطاهای قابل انتظار هم تعریف شود.

---

### 40) تست‌ها دقیقاً با چند باگ بحرانی هم‌جهت‌اند

- `tools/api_test.sh` و `api_security_test.sh` خودشان مستقیم با `class_id` enroll می‌کنند؛ بنابراین bypass کد استاد را رفتار عادی فرض کرده‌اند.
- content delete تست نمی‌شود.
- حالت False/No تست نمی‌شود.
- timer، تلاش دوم، answer-key policy و deadline تست نمی‌شوند.
- فقط ۴ widget test وجود دارد و dashboard/tab/navigation اصلی تست نشده است.
- web smoke بر click coordinate تکیه دارد و شکننده است.

لازم است تست authorization منفی، قرارداد سؤال‌ها، lifecycle آزمون، update classId، resubmit و file cleanup اضافه شوند.

---

## 📚 مستندات و build

### 41) نسخهٔ Flutter مستندشده با pubspec سازگار نیست

README خط ۴۵ می‌گوید Flutter 3.13 یا جدیدتر، ولی `pubspec.yaml:22` به Dart `^3.10.4` نیاز دارد و کد از APIهای بسیار جدید مانند `RadioGroup` و null-aware collection elements استفاده می‌کند. Flutter 3.13 این پروژه را build نمی‌کند.

باید حداقل Flutter دقیق متناظر با Dart 3.10.4 ثبت و ترجیحاً FVM/pinned SDK اضافه شود.

---

### 42) مستندات از پلتفرم‌هایی حرف می‌زنند که در repo وجود ندارند

README از desktop و iOS simulator نام می‌برد، ولی پروژه فقط پوشه‌های `android/` و `web/` دارد. `ios/`, `linux/`, `macos/`, `windows/` وجود ندارند. اجرای مستقیم آن targetها از clone فعلی ممکن نیست مگر platformها دوباره generate شوند.

---

### 43) چند ادعای مستندات اشتباه یا stale است

- `docs/اجرا-روی-گوشی.md:236` می‌گوید فایل‌ها روی گوشی داخل APK بسته‌بندی می‌شوند؛ در واقع uploadها همچنان از Apache/backend سرو می‌شوند.
- `docs/پیش‌نمایش-مرورگر.md:164,177` حساب‌های `student1...student6` را ذکر می‌کند، ولی seed حساب‌های `student2...student7` دارد.
- همان سند در خط ۱۶۶ می‌گوید «چهار نوع سؤال» ولی پنج نوع را فهرست می‌کند.
- README «timed assessments» را وعده می‌دهد، در حالی که enforcement وجود ندارد.
- سند push تعداد ۱۵/۱۶ commit و hashهای قدیمی را ثبت کرده؛ تاریخچهٔ فعلی ۲۰ commit دارد و چند hash دیگر وجود ندارند.
- `docs/راهنمای-اجرا.md` هنوز مسیر قدیمی preview با symlink را در بخش اصلی نشان می‌دهد، در حالی که README مسیر جدید `--base-href` را توصیه می‌کند.

---

### 44) تنظیم حافظهٔ Gradle برای بیشتر سیستم‌ها بیش از حد است

`android/gradle.properties:1` مقدار `-Xmx8G` و metaspace چهار گیگ دارد. روی لپ‌تاپ‌های ۸ گیگ یا محیط CI می‌تواند باعث فشار حافظه/kill شدن daemon شود. خود مستندات نیز این مشکل را پیش‌بینی کرده‌اند. مقدار معقول‌تر پیش‌فرض و امکان override در CI بهتر است.

---

# نکات مثبت مشاهده‌شده

- بیشتر queryهای ورودی از PDO prepared statements استفاده می‌کنند؛ SQL injection مستقیم در مسیرهای بررسی‌شده پیدا نشد.
- passwordها با `password_hash`/`password_verify` نگه‌داری می‌شوند.
- token با `random_bytes(32)` ساخته می‌شود.
- بررسی role و ownership در اکثر endpointها منظم است؛ مشکل اصلی استثنای `enroll.php` است.
- uploadها extension allowlist، سقف ۸ MB، نام تصادفی و دفاع `.htaccess` دارند.
- CORS allowlist دارد و origin دلخواه را پیش‌فرض reflect نمی‌کند.
- login throttling اضافه شده است.
- secret واقعی یا PAT داخل tree فعلی پیدا نشد؛ فقط credentialهای demo وجود دارند.
- Bash، JavaScript، JSON، XML و YAMLهای قابل parse از نظر syntax پایه بررسی و سالم بودند.
- ۷۴ dependency از ecosystem `Pub` با OSV query شدند و در زمان این بازبینی vulnerability شناخته‌شده‌ای گزارش نشد.

---

# ترتیب پیشنهادی اصلاح

## فاز ۱ — فوری، قبل از هر دمو جدی

1. revoke کردن توکن افشاشده.
2. بستن bypass عضویت.
3. اصلاح `contents` در content delete.
4. اصلاح payload سؤال True/False و Yes/No.
5. اصلاح navigation بعد از submit.
6. افزودن key/didUpdateWidget برای تغییر کلاس و lesson cardها.
7. برگرداندن کد عضویت و Q&A به داشبورد فعال استاد.
8. حذف crash description و پیام خطای load کلاس.

## فاز ۲ — قبل از انتشار محدود

1. طراحی lifecycle واقعی assessment: draft/published، start، deadline، attempt limit، answer-key policy.
2. دانلود فایل authenticated و cleanup فایل‌ها.
3. HTTPS اجباری در release، secure token storage و signing واقعی Android.
4. responsive navigation برای گوشی.
5. رفع feedback/resubmit homework و وضعیت essay.
6. جدا کردن demo seed از schema production.

## فاز ۳ — کیفیت و مقیاس

1. CI tracked و fail واقعی smoke test.
2. تست‌های authorization و widget/integration برای مسیرهای بحرانی.
3. validation مرکزی، error handler JSON، schema constraints و transactionها.
4. حذف N+1 و افزودن pagination.
5. حذف UI قدیمی/مرده و یکپارچه‌سازی dashboardها.
6. اصلاح README/docs و pin کردن Flutter SDK.

---

# محدودیت این بازبینی

این بررسی فایل‌به‌فایل و static بود. در sandbox حاضر `php`, `dart` و `flutter` نصب نبودند و MySQL آماده وجود نداشت؛ بنابراین `flutter analyze`, `flutter test` و تست‌های end-to-end PHP اجرا نشدند. در عوض syntax فایل‌های Bash/JS/JSON/XML/YAML، تطابق نام جدول‌های SQL، جریان‌های authorization، قرارداد JSON بین Flutter و PHP، schema، ابزارها و مستندات بررسی شدند.
