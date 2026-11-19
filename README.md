# HomeLink — Updated VS Code Project

**HomeLink** is a Flutter + Express + TiDB Cloud demonstration project for condominium residents and juristic officers. The theme uses `#123C69`, `#247BA0`, `#D9F0FA`, `#F5F9FC`, `#FFFFFF`.

## What's included

- **Resident:** registration and login, profile editing, facility booking with date/time picker, repair requests (optional image URL), vehicle CRUD, parcels, bills (status display only), suggestions, rules, messages, and home service requests.
- **Juristic:** resident approval, booking approval/rejection, repair status, vehicle list, parcel registration/collection, bill creation/status, suggestion replies, rules CRUD, message replies, home-service request status.
- **Backend:** Express REST API, JWT auth, bcrypt password hashing, SQL schema, sample units, seeded juristic account, Vercel config, simple automated HTTP tests.
- **Frontend:** separated Dart source files under `lib/core`, `lib/app`, `lib/screens`, and `lib/models`, sharing one Dart library through `part` directives. This is a deliberate choice so the course-sized app can share its types and helpers without fragile circular imports.

## Required installations

1. VS Code with Flutter and Dart extensions.
2. Flutter SDK (check with `flutter doctor`), Android Studio emulator or connected Android phone; Chrome is also an option.
3. Node.js 20+, npm, TiDB Cloud database and DBeaver (or other MySQL client).

## Step A — TiDB database

1. Create TiDB Cloud database and get connection details.
2. Open `backend/sql/schema.sql` in DBeaver and execute it **once**.
3. Execute `backend/sql/sample_units.sql` once. Sample registration uses **Building A / Unit 1205**.
4. Never publish DB credentials or `.env`.

## Step B — Backend (VS Code terminal)

```powershell
cd backend
Copy-Item .env.example .env
npm install
npm test
node src/seed_admin.js
npm run dev
```

Edit `.env` before seeding: `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL=true`, `JWT_SECRET` (at least 32 characters), `ADMIN_EMAIL`, `ADMIN_PASSWORD`. Check `http://localhost:3000/api/health`. Backend tests run without a live database but a real TiDB connection is needed for `/api/health` and data operations.

## Step C — Flutter (new VS Code terminal)

```powershell
cd flutter_app
flutter create --platforms=android,web .
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

**Important:** Flutter SDK is not bundled. `flutter create` generates standard Android/web runner folders, platform config, and `.metadata`. This is the official reproducible approach, not missing HomeLink application source. On Windows with Chrome, use `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api`. On a physical phone use your PC's LAN IP instead of `10.0.2.2`. For Android emulator local HTTP you may need to set `android:usesCleartextTraffic="true"` in the `<application>` element of `android/app/src/main/AndroidManifest.xml`; deployed environments should use HTTPS. You can generate iOS runner files only on macOS (`flutter create --platforms=ios .`).

## Step D — Test both roles

1. Log in with juristic credentials from `.env` (seeded via `seed_admin.js`).
2. Register a resident with an existing sample unit. Account starts unapproved.
3. Juristic > Residents > Approve.
4. Resident logs in again (approval is included in the login token).
5. Resident makes a facility booking; juristic approves it; resident checks history.
6. Resident creates a repair request; juristic updates status.
7. Test vehicles, parcels, suggestions, bills, rules, and messages.

## Deploying backend

Deploy `backend/` as Vercel project root, configure the same environment variables, and ensure TiDB allows outbound connections from the deployment. Use the deployed HTTPS URL with `/api` in `API_BASE_URL`.

## Project limitations — please read

- **Not a fully validated production release.** The build environment used to package this archive does not have Flutter SDK or TiDB credentials. Backend JavaScript syntax and ZIP integrity can be checked here; Flutter build and end-to-end database operations must be verified on your machine.
- Repair photos are stored as **optional HTTPS image URLs**, not native gallery uploads. A real upload workflow needs an image storage provider and upload API.
- Bills are for viewing and manually marking paid/unpaid, **not real payment processing**.
- Messages are asynchronous, not WebSocket real-time chat. No push notifications, visitor e-stamp, or e-voting.
- `flutter create` is required once to generate standard platform runner files. Do not overwrite HomeLink's `lib/` content if prompted.
- A secure production deployment requires further testing, monitoring, account recovery, and audit logging.

## Team split

- Member 1: Resident UI and API integration.
- Member 2: Juristic UI and API integration.
- Member 3: Node/Express, TiDB schema, Vercel deployment, and API tests.

All three should run end-to-end tests and understand their code for presentation.
