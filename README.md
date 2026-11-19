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
| **Exercise** | Weekly schedule (Mon–Sun) and log: sets, reps and weight for strength; minutes and distance for cardio. 40 built-in exercises with calorie burn. **Suggest a plan** asks the AI coach for a schedule based on goal, days, home or gym, and level |
| **Daily check-in** | Body weight, steps (auto from Apple Health / Health Connect, or typed), water, sleep, food habits, notes |
| **Progress** | Calories in vs. out for today (resting + daily living + walking + exercise), last 7 days, where weight is heading, 30-day weight chart, and **AI health coach** weekly review |
| **Today's goals** | Seven clear daily goals with progress: calories, protein, steps, exercise, water, sleep, weigh-in |
| **Account** | Continue with Google or an email link; data backed up to the cloud and shared between phone and web; sign out; delete account |
| **Settings** | Text size (Normal / Large / Extra large), step and water goals, edit goal |

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

## Turn on sign-in, cloud backup, photo recognition and the AI coach

Fill in `lib/config.dart` (Vercel backend address + Supabase project) and push. Step-by-step: **`docs/ACCOUNTS.md`**.

Until then, the app runs on the device only, without login, and Photo and AI coach say they are not switched on.

## How calories out are worked out

| Part | Formula |
|---|---|
| Resting (BMR) | Mifflin–St Jeor, using today's weigh-in if there is one |
| Daily living | 15 % of BMR (digestion, light moving around) |
| Walking | steps × stride (height × 0.414) → km; 0.5 kcal per kg per km |
| Exercise | (MET − 1) × 3.5 × kg ÷ 200 × minutes; strength sets ≈ 2.5 min each |
| Phone data | If Apple Health / Health Connect active calories are higher than our walking + exercise estimate, the measured value is used |
| Weight direction | about 7,700 kcal ≈ 1 kg |

## AI coach

`backend/api/coach.js` does two jobs: the weekly health review (`task: "insights"`) and a workout schedule (`task: "plan"`). It is deployed with the photo endpoint. The app finds it from `RECOGNIZE_URL`, or you can set `--dart-define=API_BASE=https://YOUR-APP.vercel.app/api`. The app sends only numbers and food names, never the user's name or email.

## Bluetooth scales

Works with scales that use the standard Bluetooth Weight Scale profile (service `0x181D`). Many cheap scales use private protocols, so see `docs/ADDING_A_SCALE.md` to add one. The web app always uses typed grams, because browsers can't reliably talk to scales.

## Project map

```
lib/
  main.dart                 app start, login gate, providers, text-size setting
  config.dart               ← fill in: backend URL and Supabase project
  theme.dart                colours and fonts from the design
  models/models.dart        Food, LogEntry, Profile, Meal …
  data/food_database.dart   built-in foods (per 100 g, USDA-based)
  data/exercise_catalog.dart 40 exercises with MET values
  models/fitness.dart       weekly plan, workouts, daily check-in
  services/
    nutrition.dart          daily targets (Mifflin–St Jeor) and meal plan
    goals.dart              the seven daily goals
    auth_service.dart       Google / email sign-in, sign out, delete account
    cloud_sync.dart         Supabase records, merge on sign-in
    energy.dart             calories out, walking, exercise burn
    coach_client.dart       AI coach (insights + workout plan)
    health/                 Apple Health / Health Connect (mobile) and web stub
    food_lookup.dart        Open Food Facts + photo recognizer client
    scale/                  Bluetooth scale (mobile) and web stub
  state/app_state.dart      saved data (on-device storage)
  screens/                  today, scan, weigh, plan, setup, settings, home_shell
  widgets/common.dart       cards, pills, calorie ring
backend/api/recognize.js    photo → foods (Vercel function)
backend/api/coach.js        weekly review + workout plan (Vercel function)
backend/api/delete-account.js  deletes the signed-in user's account
backend/supabase.sql        database table + row-level security
test/logic_test.dart        maths, parsing and storage tests
```

## Good to know

- **Data stays on each device.** The phone app and the website don't share a log yet. Syncing them needs sign-in and a cloud database (Firebase or Supabase both work with Flutter). That's the natural next step.
- Nutrition numbers are estimates. The app tells users it isn't medical advice, and it never sets a daily target below 1,200 kcal (women) or 1,500 kcal (men).
- Before publishing, replace "WeighWell" if you pick another name. You'll also need an app icon (`flutter_launcher_icons`), plus Apple and Google developer accounts.
