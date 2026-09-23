# Store listing drafts — Google Play (2026-09-23, audit §12.21)

Ready-to-paste listing copy for the Play Console, in English and Arabic,
matching the app's honesty policy (demo disclosures are part of the copy,
not an afterthought). Character counts are against Play's hard limits:
title ≤ 30, short description ≤ 80, full description ≤ 4000.

Generated companion assets (from `scripts/gen_feature_graphic.py`, D-01
tokens): `store_assets/feature_graphic.png` (1024x500 RGB opaque) and
`store_assets/play_icon_512.png` (512x512 RGB opaque).

---

## English

**Title** (30-char limit) — 25 chars:

```
LegalHub – Legal Services
```

**Short description** (80-char limit) — 78 chars:

```
Consultations, matters, documents, and messaging — a complete legal platform.
```

**Full description:**

```
LegalHub brings legal services into one place — consultations, matter
discovery, documents, messaging, and organization management in a single
app.

FEATURES
• Consultations — request and track legal consultations
• Discovery — find the right lawyer by specialty and location
• Matters — follow your legal matters and their progress
• Documents — keep case documents organized in one place
• Messaging — communicate directly with your lawyer
• Organizations — law firms manage teams and workflows

LANGUAGES
English, Arabic (full right-to-left interface), and Turkish.

TRANSPARENCY NOTE
This build is a portfolio demonstration running on demo data only. It
collects no real personal data, does not provide actual legal advice, and
is not a substitute for a licensed lawyer.

ENGINEERING QUALITY
34 screens, 1,400+ automated tests, clean architecture, and a governed
release pipeline.
```

## العربية

**العنوان** (حد 30 حرفًا) — 28 حرفًا:

```
ليغال هب – الخدمات القانونية
```

**الوصف المختصر** (حد 80 حرفًا) — 71 حرفًا:

```
استشارات وقضايا ومستندات ومراسلة — منصة قانونية متكاملة في تطبيق واحد.
```

**الوصف الكامل:**

```
يجمع ليغال هب (LegalHub) الخدمات القانونية في مكان واحد: الاستشارات،
والبحث عن المحامي المناسب، وإدارة القضايا والمستندات، والمراسلة، وإدارة
المؤسسات القانونية — كل ذلك في تطبيق واحد.

الميزات
• الاستشارات: طلب الاستشارات القانونية ومتابعتها
• البحث: العثور على المحامي المناسب حسب التخصص والموقع
• القضايا: متابعة قضايك ومسارها
• المستندات: تنظيم مستندات القضايا في مكان واحد
• المراسلة: تواصل مباشر مع المحامي
• المؤسسات: إدارة فرق العمل في مكاتب المحاماة

اللغات
العربية والإنجليزية والتركية، بواجهة عربية كاملة من اليمين إلى اليسار.

تنويه الشفافية
هذا الإصدار نسخة تجريبية لعرض القدرات، يعمل ببيانات تجريبية فقط؛ لا يجمع
بيانات شخصية حقيقية، ولا يقدّم استشارات قانونية فعلية، ولا يُغني عن
المحامي المرخّص.

الجودة الهندسية
34 شاشة، وأكثر من 1400 اختبار آلي، وبنية برمجية نظيفة، ومسار إصدار مُدار.
```

---

## Console checklist (what remains owner-side)

- [ ] **Phone screenshots** (min 2, up to 8) — needs an emulator/device;
      suggested set: home, consultations, documents, messaging — capture
      the same set in Arabic to show the RTL story.
- [ ] **Privacy policy URL** — Play requires a hosted policy before
      publishing; not yet produced.
- [ ] **Data safety form** — answer per the final backend configuration
      (demo build runs on local demo data; Supabase email/password auth
      exists in the code — answer honestly per what ships).
- [ ] **Category** — recommend *Productivity* (no Legal category exists);
      *Business* is the alternative.
- [ ] **Content rating questionnaire** — standard, no sensitive categories.
- [ ] **App contact email** — owner's choice.
- [x] App icon 512x512 — `store_assets/play_icon_512.png` (generated).
- [x] Feature graphic 1024x500 — `store_assets/feature_graphic.png`
      (generated).
