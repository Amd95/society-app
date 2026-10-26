# Small Society Management App: CMP Development Roadmap

Source: *Small Society Management App, Business Plan* (26 Oct 2026). Amounts are in ₹ (the PDF dropped the symbol).

## 1. What the plan asks us to build

| Plan item | Engineering meaning |
|---|---|
| Committee app (Android, Kotlin and Compose) | Compose Multiplatform (CMP) app. Android ships first; iOS and desktop come later at low extra cost. |
| Residents pay and view the ledger from a WhatsApp link, with no install | Small public web page, token-based with no login. This is the most important surface. |
| Managed backend, free tier, Mumbai region | Supabase (Postgres, Auth, Storage) in `ap-south-1`. A Kotlin server is deferred. |
| Money goes straight to the society's account | The app never touches funds. MVP uses UPI deep links with manual confirmation. |
| Hindi and English | i18n from day one. Strings are never hard-coded. |
| MVP in about 12 weeks at 10–12 h/week | Roughly 130–145 hours in total. Scope is the binding constraint. |

MVP scope is five features: dues collection, expense ledger, complaints, notices and polls, and resident directory. Version 2 adds the monthly PDF report, vendor contacts and committee handover. Gate and visitor log come later, and only if societies ask for them. Adding anything to the MVP list requires cutting something else.

## 2. Key architecture decisions

### D1. Resident web page is not Compose Wasm (DECIDED)
A resident opens a WhatsApp link on a low-end phone over 4G. A Compose/Wasm bundle is multiple MB and slow to first paint. The resident page is a tiny server-rendered or static page (HTML, a little JS, and shared Kotlin DTOs if convenient). Compose for Web (Wasm) is reserved for a later committee web console, where load time matters less.

### D2. Backend: Supabase through the pilot, Ktor only when needed (DECIDED)
- Supabase gives Postgres (the plan wants SQL for ledger reports), phone OTP, file storage, row-level security (RLS) and edge functions, with no server to run.
- Add a `:server` Ktor module only when a feature needs it: scheduled reminders, PDF reports, or payment-gateway webhooks. Host it on Cloud Run `asia-south1` (scale to zero).
- Trade-off: a full Ktor backend would share more Kotlin code but adds ops work and cost. That fights the plan's "under ₹25,000 in year 1" goal.
- Open point: Supabase phone OTP needs an SMS provider (for example MSG91) and India DLT registration. Firebase Auth phone is the fallback. Decide in Week 1 with a spike.

### D3. Auth model
- Committee members and residents who install the app use phone OTP.
- Residents who don't install use a per-bill token in the link (a new link each month). The token grants access to that bill and the society ledger, read-only. It can be rotated and has no write access except "I've paid".

### D4. Payments (MVP)
1. Treasurer sets the society's UPI ID.
2. The bill link builds a `upi://pay?pa=…&pn=…&am=…&tn=…` deep link.
3. The resident pays, then taps "I've paid" and enters an optional UTR.
4. The treasurer confirms in the app, or marks cash payments manually. Pending confirmations are the treasurer's daily queue.
5. Payment gateway (Razorpay Route or Cashfree split) is a v2 decision, based on pilot feedback.

### D5. Reminders
MVP uses WhatsApp share links (`wa.me/?text=…`) so the treasurer sends them in one tap. The WhatsApp Business API is adopted only once revenue covers per-message cost.

## 3. Monorepo layout

> **Status (26 Oct 2026):** scaffold created. Present: `shared/{model,domain,design,app}`, `androidApp`, `webResident`, `backend/supabase` (init migration, RLS, public RPCs, seed), CI. Not yet created: `build-logic` convention plugins (add when module build files start to drift), `shared/data`, `shared/feature-*`, `iosApp`, `webAdmin`, `backend/server`. The tree below is the target layout.

```
society-app/
├── build-logic/                 # convention plugins (kmp-library, cmp-app, detekt, ktlint)
├── gradle/libs.versions.toml    # single version catalog
├── shared/
│   ├── model/                   # domain models + DTOs (kotlinx.serialization)
│   ├── data/                    # repositories, supabase-kt client, local cache (SQLDelight)
│   ├── domain/                  # use cases: bill generation, reconciliation, balance
│   ├── design/                  # CMP theme, components, Hindi/English strings
│   └── feature-*/               # dues, ledger, complaints, notices, directory, onboarding
├── androidApp/                  # Android entry point (Play Store)
├── iosApp/                      # added post-MVP, stub only
├── webResident/                 # public bill/ledger page (see D1)
├── webAdmin/                    # Compose Wasm console (post-MVP)
├── backend/
│   ├── supabase/                # migrations/, seed.sql, rls tests, edge functions
│   └── server/                  # Ktor, NOT created until Phase 4 (D2); Supabase edge functions cover the pilot
├── tools/                       # Excel/CSV import script for migrating a society's records
└── docs/                        # ADRs, DPDP notes, runbooks, pilot playbook
```

Stack:
- Kotlin and Compose Multiplatform, Navigation, Koin (DI), kotlinx-coroutines, kotlinx-serialization
- supabase-kt (auth, postgrest, storage)
- SQLDelight for offline cache
- Coil 3 for images
- Crashlytics (or Sentry) and a minimal analytics layer

Conventions:
- Feature modules are independent and share one design module.
- Money is stored as integer paise, never floating point.
- Every table carries `society_id`, and RLS enforces it.

## 4. Data model (Postgres, first cut)

| Table | Purpose |
|---|---|
| `societies` | name, city, UPI ID, plan, billing cycle, language default |
| `homes` | society, label (e.g. "B-12" or "Plot 86/4"), monthly amount |
| `members` | user, home, role (`owner`, `tenant`, `committee`, `treasurer`, `admin`), phone, visibility flags |
| `bill_cycles` / `bills` | one bill per home per month: amount, due date, status (`unpaid`, `claimed`, `paid`), `public_token` |
| `payments` | bill, mode (`upi`, `cash`, `bank`), UTR, claimed-by, confirmed-by, timestamps |
| `expenses` | amount, category, vendor, date, bill photo path, entered-by |
| `complaints` / `complaint_events` | issue, photo, assignee, status history |
| `notices`, `polls`, `poll_votes` | announcements and one-vote-per-home polls |
| `audit_log` | every money and role change (supports trust and the v2 handover) |

RLS rules:
- A member sees only their own society's rows.
- Directory fields are visible to members only.
- Only treasurer and admin roles write payments and expenses.
- The public token resolves through one narrow RPC function and never through open table access.

## 5. Phased roadmap (aligned to the plan's four phases and one gate)

### Phase 0: Validation, Nov to Dec 2026 (no product code)
Goal: confirm that committees will pay and see what treasurers actually do today.
- This week: list 15 committee contacts, photograph 3 treasurers' Excel sheets or registers, and ask the Faridabad Confederation of RWAs for a 15-minute meeting.
- Answer the plan's open questions: number of societies in Faridabad, share already paying for software, monthly fee per house.
- Engineering prep, about 8–10 h in Dec:
  - Spike A: Supabase phone OTP vs Firebase Auth, with SMS and DLT cost.
  - Spike B: CMP Android hello-world plus supabase-kt round trip.
  - Spike C: the UPI deep link from a WhatsApp in-app browser on 3 different phones. Check for UPI-app quirks.
- Exit criteria: at least 8 of 15 committees want a pilot, and at least 5 say the price is acceptable. Otherwise revisit the pricing and the go-to-market before building.

### Phase 1: MVP build, 4 Jan to 28 Mar 2027 (12 weeks, about 11 h/week)

| Wk | Focus | Deliverables |
|---|---|---|
| 1 | Foundation | Monorepo (scaffolded), convention plugins, CI lint (build + tests already wired), Supabase project in Mumbai, design tokens, en/hi string setup (started) |
| 2 | Schema and auth | Migrations, RLS policies with SQL tests, phone-OTP login, session handling |
| 3 | Society and homes | Onboarding wizard (create society, UPI ID, add homes), roles, member invites, resident directory |
| 4 | Dues engine | Monthly cycle config, bill generation per home (idempotent), paid/unpaid list |
| 5 | Pay link and resident web | `webResident` page: bill amount, UPI button, "I've paid" and UTR, token RPC, Hindi/English toggle |
| 6 | Reconciliation | Treasurer confirm queue, cash entry, WhatsApp reminder share links, audit log |
| 7 | Expense ledger | Add expense with compressed bill photo (Storage), categories, running balance, resident-visible totals on app and web |
| 8 | Complaints | Raise with photo, assign, status timeline, close |
| 9 | Notices and polls | Announcements (with share link), one-vote-per-home polls and results |
| 10 | Offline and polish | SQLDelight cache, empty and error states, low-end-device performance pass, full Hindi review by a native speaker |
| 11 | Hardening | Security review of RLS and token, Crashlytics, backups and restore drill, DPDP basics (privacy policy, consent screen, data export and delete), CSV import tool for pilot societies |
| 12 | Release | Play Store registration and closed testing, onboarding kit (one-page brochure, video, FAQ), buffer for slippage |

Definition of done per feature: works offline-tolerant, Hindi and English strings complete, RLS test written, crash-free on a low-end Android device.

Capacity check: 12 weeks × 10–12 h is about 120–145 h, and the table above is close to full. Protect the schedule with these rules:
- Weeks 10–12 absorb overrun; the cut order is notices and polls first, then offline cache depth.
- Remove iOS and the web admin console from the MVP entirely.
- No new features before 10 societies pay, as the plan already states.

### Phase 2: Pilot with 10 societies, Apr to Jul 2027
- Apr: onboard the first 3 societies personally (own society plus 2 friends). Migrate their Excel records with the import tool.
- May–Jun: add about 7 more through neighbouring sectors and the Confederation pitch. Offer free setup and 3 free months.
- Release cadence is every 2 weeks, driven by treasurer feedback. Support is by WhatsApp.
- Instrument the metrics that decide the gate:
  - Activation: society has generated bills and 50%+ of homes have a bill link opened.
  - Collection: percentage of bills marked paid in-app versus outside it.
  - Treasurer effort: minutes per month (target: 10).
  - Retention: societies still active after 60 days.
  - Willingness to pay: converted or signed intent after the free months.
  - Support load: hours per week.
- Allowed work in this phase: bug fixes and the v2 items that pilots ask for most (monthly PDF report, vendor contacts, committee handover). Payment gateway evaluation also starts here.

### Phase 3: Decision gate, Aug 2027
Scale only if most of these hold; otherwise take the fallback.

| Signal | Target |
|---|---|
| Pilot societies still active | at least 8 of 10 |
| Societies willing to pay (₹10/home, ₹299 minimum) | at least 5 |
| Treasurer time per month | 15 minutes or less |
| Visits needed to sign a society | 2 or fewer |

Fallback, per the plan: test selling to RWA federations or property-management companies. If usage is fine but no one pays, revisit pricing before anything else.

### Phase 4: Scale (only after a go), Sep 2027 onward
1. Payment gateway with split settlement, so payments reconcile automatically.
2. WhatsApp Business API reminders once revenue covers the per-message cost.
3. A `:server` Ktor module for scheduled jobs, PDF reports and webhooks.
4. iOS target (the shared UI is already in place) and the Compose Wasm committee console.
5. Part-time commissioned salesperson at 20 live societies; move off free tiers as volume demands.
6. Vendor marketplace (tank cleaning, motor AMC) only after 100+ societies; no ads.

## 6. Cross-cutting workstreams

- **Quality:** unit tests for the dues, reconciliation and balance logic; RLS tests in SQL; a small set of Android UI tests on the pay and confirm flows; Firebase Test Lab smoke run before each release.
- **CI/CD:** GitHub Actions with Gradle caching, lint (detekt, ktlint), Android release to Play internal track from tags, and Supabase migrations applied from CI with a staging project first.
- **Security and privacy (DPDP):** data minimisation, India region, consent at sign-up, privacy policy, delete and export on request, no personal data in logs or URLs, rotatable bill tokens.
- **Business and legal prerequisites:** register the business before charging, and handle GST invoices once turnover requires them. Neither is code, but both block the first paid society.
- **Cost guardrails (year 1 target under ₹25,000):** Play fee, domain, free-tier hosting, brochures. Track Supabase egress and storage monthly, and compress photos on-device.

## 7. Top technical risks

| Risk | Mitigation |
|---|---|
| Time: solo developer with a full-time job | Fixed scope, week 10–12 buffer, cut list agreed up front |
| UPI deep links behave differently across apps and WhatsApp's in-app browser | Spike C in Dec; always show the UPI ID and a QR as a fallback |
| Residents pay outside the app, so the ledger loses trust | Treasurer cash entry, "paid elsewhere" marking, audit log |
| Token links leak or get forwarded | Read-only scope, per-home tokens, rotation, no directory data on the public page |
| OTP cost or delivery problems in India | Week 1 spike, a fallback provider, and a cost cap in the plan |
| Free-tier limits hit sooner than the plan expects | Monitor monthly; the migration path is Supabase Pro, then own server only at several hundred societies |
| Compose Multiplatform web immaturity | Not on the MVP critical path (D1) |

## 8. Decisions needed from you

Decided:
1. D1: lightweight resident page, not Compose Wasm.
2. D2: Supabase-only until the pilot ends; Ktor `:server` deferred (so `backend/server/` stays empty and out of the build until Phase 4).

Still open:
3. Auth fallback if Supabase phone OTP costs too much: Firebase Auth (settled by the Week 1 spike).
4. Start date for Phase 1: this roadmap assumes 4 Jan 2027. A slip in validation moves everything after it.
5. Resident page tech: plain static HTML/JS calling Supabase RPC directly (simplest, no server), hosted on Cloudflare Pages or Netlify. Confirm in Week 5; use Kotlin/JS only if sharing DTOs proves worth the bundle size.
