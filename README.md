# Suan Mouakhom Market — Flutter App (Buyer + Seller + Admin)

A single Flutter codebase with three basic apps, gated behind a role-select
screen: **Buyer**, **Seller Panel**, **Admin Dashboard**. Talks to the
NestJS backend (`suan-market-backend`) over REST.

⚠️ This was written without a local Flutter SDK to test-compile against
(sandbox doesn't have Flutter installed), so please run `flutter analyze`
after setup and fix anything that comes up — the code follows standard
Flutter/Dart conventions but hasn't been build-verified like the backend was.

## 1. Setup

This zip only contains `lib/`, `pubspec.yaml`, and config files — the
platform folders (android/, ios/, web/, etc.) need to be generated locally:

```bash
cd frontend
flutter create --org com.ldb --project-name suan_market_app .
```

This adds the missing platform folders without touching your existing
`lib/` or `pubspec.yaml` (Flutter only creates files that don't already exist).

Then install dependencies:

```bash
flutter pub get
```

## 2. Point it at your backend

Edit `lib/config/constants.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
}
```

- Running on Chrome (Flutter Web) on the same machine as the backend: `http://localhost:3000/api` works as-is.
- Running on an Android emulator: use `http://10.0.2.2:3000/api` instead (emulator's alias for host machine).
- Running on a real phone: use your computer's LAN IP, e.g. `http://192.168.1.50:3000/api`, and make sure your phone is on the same network and your Mac's firewall allows the connection.

## 3. Run

```bash
flutter run -d chrome        # Flutter Web
flutter run                  # whichever device/emulator is connected
```

## 4. What's included

```
lib/
  config/constants.dart        API base URL
  models/                      User, Store, Category, Product, CartItem, Order
  services/                    api_client.dart (token storage + HTTP helpers),
                                auth, catalog, store, product, cart, order,
                                dashboard services — one per backend module
  state/app_state.dart         Login state via Provider
  screens/
    role_select_screen.dart    Landing page: choose Buyer / Seller / Admin
    auth/                      Login, Register
    buyer/                     Home (categories+grid), product detail,
                                cart, checkout, my orders
    seller/                    Dashboard, create store, product list,
                                add product, order management
    admin/                     Dashboard (calls GET /api/dashboard/overview)
```

## 5. Known gaps (basic scaffold, not production-ready)

- **No role-based auto-routing** — the role-select screen lets you open
  any of the 3 apps regardless of your account's actual role. Add a
  check against `AppState.currentUser.role` once you're ready to lock
  each app down.
- **Checkout uses a raw Address ID text field** — there's no address
  book UI yet (add/list/select saved addresses). You'll need to create
  a `user_addresses` row via the API or Postman first, then type its ID
  into the checkout screen to test.
- **"My Stores" on the seller dashboard actually lists ALL stores** —
  add a `GET /api/stores?ownerId=me` style endpoint on the backend to
  scope this properly per logged-in seller.
- **No image upload** — product images are URL-only right now (matches
  the backend, which also expects URLs not file uploads).
- **Admin dashboard requires an `admin`-role account** — register a user
  normally, then manually update their `role` to `'admin'` in MySQL to
  test that screen (`UPDATE users SET role='admin' WHERE id=...`).
- No error-boundary/retry UI polish, no pagination on product lists,
  no pull-to-refresh on every screen — basic versions as requested.
