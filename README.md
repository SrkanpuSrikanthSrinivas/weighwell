# WeighWell

Weigh your food, see its calories and protein, and plan your daily meals.
One Flutter codebase for **iOS, Android and the web**. Built to be easy for any age: big text and buttons, plain words, and a text-size setting.

## What it does

| Screen | What you can do |
|---|---|
| **Set my goal** (first launch) | Age, weight, height, activity and goal → daily calories and protein |
| **Today** | Calorie ring, protein bar, meals, and a 7-day chart |
| **Add food** | **Photo** (AI recognises the food), **Barcode** (packaged food via Open Food Facts) or **Type name** (60+ built-in foods, works offline) |
| **Weigh** | **Use my scale** (Bluetooth) or **Type grams**, with a Zero button for bowls. Calories, protein, carbs and fat update as you go |
| **My daily plan** | Pick Lose / Stay same / Build muscle. Targets are split across breakfast, lunch, snack and dinner, with food ideas |
| **Settings** | Text size (Normal / Large / Extra large), edit goal, delete data |

On wide screens (the web, tablets) the app switches to a dashboard layout with a side menu.

## Run it (Mac)

You need Flutter (https://docs.flutter.dev/get-started/install/macos). For iOS you also need Xcode, and for Android, Android Studio.

```bash
cd weighwell
./tool/setup.sh            # one time: creates ios/ android/ web/ and adds permissions
flutter test               # unit tests
flutter run -d chrome      # web
flutter run                # connected phone or simulator
```

## Build in the cloud (Codemagic)

No Xcode needed: push to GitHub and Codemagic builds an installable Android APK, and an iPhone TestFlight build. Step-by-step: `docs/CODEMAGIC.md`.

## Turn on photo recognition

The app asks *your own* small server to identify food photos. That way the AI key never ships inside the app.

1. Deploy the `backend/` folder to Vercel (`cd backend && npx vercel`).
2. In Vercel → Project → Settings → Environment Variables, add `ANTHROPIC_API_KEY`.
3. Build the app with the URL:
   ```bash
   flutter run --dart-define=RECOGNIZE_URL=https://YOUR-APP.vercel.app/api/recognize
   ```
   Use the same `--dart-define` for `flutter build web`, `flutter build ipa` and `flutter build appbundle`.

Without the URL, the app still works. The Photo tab tells the user to type the food name instead.

Backend tests: `cd backend && npm test`. For the web app, you can also set `ALLOWED_ORIGIN` in Vercel to your site's address to lock down CORS.

## Bluetooth scales

Works with scales that use the standard Bluetooth Weight Scale profile (service `0x181D`). Many cheap scales use private protocols, so see `docs/ADDING_A_SCALE.md` to add one. The web app always uses typed grams, because browsers can't reliably talk to scales.

## Project map

```
lib/
  main.dart                 app start, providers, text-size setting
  theme.dart                colours and fonts from the design
  models/models.dart        Food, LogEntry, Profile, Meal …
  data/food_database.dart   built-in foods (per 100 g, USDA-based)
  services/
    nutrition.dart          daily targets (Mifflin–St Jeor) and meal plan
    food_lookup.dart        Open Food Facts + photo recognizer client
    scale/                  Bluetooth scale (mobile) and web stub
  state/app_state.dart      saved data (on-device storage)
  screens/                  today, scan, weigh, plan, setup, settings, home_shell
  widgets/common.dart       cards, pills, calorie ring
backend/api/recognize.js    photo → foods (Vercel function)
test/logic_test.dart        maths, parsing and storage tests
```

## Good to know

- **Data stays on each device.** The phone app and the website don't share a log yet. Syncing them needs sign-in and a cloud database (Firebase or Supabase both work with Flutter). That's the natural next step.
- Nutrition numbers are estimates. The app tells users it isn't medical advice, and it never sets a daily target below 1,200 kcal (women) or 1,500 kcal (men).
- Before publishing, replace "WeighWell" if you pick another name. You'll also need an app icon (`flutter_launcher_icons`), plus Apple and Google developer accounts.
