# Foodly

A small food-ordering app in Flutter: sign in, browse the menu, add to the basket, check out.
It exists so that [huntingdogs](https://github.com/huntingdogsai) has an app to test on every
pull request: the tests run on a fresh Android emulator and report on the pull request.

## Build

The QA build includes the `huntingdogs` package and tells it which port the test machine talks to:

```sh
flutter pub get
flutter build apk --debug --dart-define=OPERATOR_LIVE_BRIDGE_PORT=8799 --dart-define=FOODLY_API_BASE_URL=https://huntingdogs-foodly-api-snbl7sdvbq-ew.a.run.app
```

## Backend

`backend/foodly_api_server.mjs` is the app's API: products, sessions, orders, in memory. Run it
with `node backend/foodly_api_server.mjs` (port 8787) or deploy it anywhere Node.js runs; it
listens on `$PORT` when that is set. The copy huntingdogs tests against runs at
https://huntingdogs-foodly-api-snbl7sdvbq-ew.a.run.app (in memory, reset on every restart).
