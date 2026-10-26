# Society App

Dues, expense ledger, complaints and notices for small housing societies and plotted-colony RWAs (Faridabad first).
Plan and phases: [docs/ROADMAP.md](docs/ROADMAP.md).

## Layout

| Path | What |
|---|---|
| `shared/model` | Domain models, `Paise` money type (KMP, serialization) |
| `shared/domain` | Pure logic: `BillGenerator`, `UpiLink` (unit-tested) |
| `shared/design` | Compose Multiplatform theme and en/hi string resources |
| `shared/app` | Root `App()` composable shared by every platform host |
| `androidApp` | Android host (Play Store build) |
| `webResident` | No-login resident bill page (static HTML/JS, token link) |
| `backend/supabase` | Postgres migrations, RLS, public RPCs, seed data |

iOS, the Compose Wasm admin console and a Ktor server are intentionally absent until the roadmap calls for them.

## Build (Windows)

Use JDK 21 and the Bash tool or Git Bash. The Android Studio bundled JDK may be too new for the Kotlin plugin.

```bash
export JAVA_HOME="C:\Program Files\Java\jdk-21.0.10"
./gradlew :androidApp:assembleDebug
./gradlew :shared:model:testDebugUnitTest :shared:domain:testDebugUnitTest
```

`local.properties` (git-ignored) must contain `sdk.dir`.

## Backend

1. Create a Supabase project in the Mumbai region (`ap-south-1`).
2. Install the Supabase CLI, then `supabase link --workdir backend --project-ref <ref>`.
3. `supabase db push --workdir backend` applies `backend/supabase/migrations`. Load `seed.sql` on a dev project only.

## Resident page

```bash
cp webResident/config.example.js webResident/config.js   # fill in URL + anon key
# serve webResident/ with any static server, then open index.html?t=demo-token-a1
```

Host it on Cloudflare Pages or Netlify. The page only calls `get_public_bill` and `claim_payment`.

## Conventions

- Money is integer paise (`Paise`), never floating point.
- Every table has `society_id`; row-level security enforces tenancy.
- Strings live in `shared/design/.../composeResources` (en + hi); no hard-coded UI text.
- Application id and package (`app.society.*`) are placeholders; rename before the Play Store listing.
