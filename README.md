A personal cycling tracker app built with Flutter and Firebase, designed as a gift for my boyfriend. Log and track rides with GPS recording, stats, history, and a performance dashboard — accessible on Android and via web.


Features

- **Dashboard** — performance snapshot with total distance, time, streak, goals, and pre-ride checklist
- **Add Ride** — log rides manually with distance, duration, elevation, heart rate, cadence, terrain, difficulty, skills, notes, and photos
- **GPS Tracker** — record routes in real time using the device's GPS
- **History** — browse all rides with terrain filters, sorting, and the ability to edit or delete entries
- **Stats** — charts, heatmap, and key metrics at a glance
- **All Routes Map** — visualize every recorded GPS route overlaid on a single canvas
- **Profile** — personal info, goals, and profile photo
- **Auth** — email/password and Google Sign-In, with email verification

Prerequisites
- Flutter SDK
- Firebase project with Android app configured
- `google-services.json` in `android/app/`

Run locally
```bash
flutter pub get
flutter run
```

Build Android APK
```bash
flutter build apk --release
```

Deploy to web
```bash
flutter build web --release
cd build/web
vercel --prod
```

---

## Live

🌐 [jscycling.vercel.app](https://jscycling.vercel.app)