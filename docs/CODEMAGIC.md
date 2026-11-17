# Build and install WeighWell with Codemagic

Codemagic builds the app in the cloud, so you don't need Xcode or Android Studio on your Mac. The first build also compiles and tests the code.

## 1. Put the project on GitHub

From the unzipped `weighwell` folder:

```bash
git init
git add .
git commit -m "WeighWell first version"
git branch -M main
gh repo create weighwell --private --source=. --push
```

(Without the `gh` tool, create an empty private repo on github.com, then run `git remote add origin <url>` and `git push -u origin main`.)

## 2. Connect Codemagic

1. Sign in at https://codemagic.io with GitHub.
2. Click **Add application**, pick **GitHub**, choose the `weighwell` repo, and select **Flutter App (via codemagic.yaml)**.
3. Codemagic finds `codemagic.yaml` on its own.
4. In `codemagic.yaml`, change `YOUR_EMAIL@example.com` to your email, then commit and push.

## 3. Android: install on your phone (free, no store account)

1. In Codemagic, click **Start new build**, choose the **Android test build (APK)** workflow and the `main` branch.
2. It takes about 10–15 minutes. When it's done, you get an email, and the build page shows `app-release.apk`.
3. On your Android phone, open the email or the build page and download the APK.
4. Tap it to install. If asked, allow your browser or email app to "install unknown apps".

Every push to `main` builds a new APK automatically. Forward the email link to anyone who wants to test.

## 4. iPhone: TestFlight (needs the Apple Developer Program, $99/year)

Apple doesn't let cloud services install apps on iPhones with a free account.

1. **Join** the Apple Developer Program at https://developer.apple.com/programs/.
2. **Create the app** in App Store Connect (https://appstoreconnect.apple.com). Go to **Apps → + → New App**, and use the bundle ID `com.aiqeacademy.weighwell`. You may first need to register it under Certificates, Identifiers & Profiles → Identifiers. Copy the app's **Apple ID**, a number shown under App Information.
3. **Create an API key.** In App Store Connect, go to Users and Access → Integrations → **App Store Connect API**. Generate a key with **App Manager** access. Download the `.p8` file and note the Issuer ID and Key ID.
4. **Add the key to Codemagic.** Go to Team settings → Team integrations → **Developer Portal** → Manage keys. Add the key and name it **Codemagic**, which matches `codemagic.yaml`.
5. **Add a signing certificate.** In Codemagic, go to Team settings → codemagic.yaml settings → **Code signing identities**. Under iOS certificates, click **Generate certificate**.
6. **Fill in the Apple ID.** In `codemagic.yaml`, replace `"0000000000"` with your app's Apple ID. Commit and push.
7. **Build.** Run the **iPhone build to TestFlight** workflow.
8. **Add testers.** In App Store Connect → TestFlight → Internal Testing, add yourself as a tester. Install the **TestFlight** app on your iPhone and accept the invite.

## Turn on photo recognition in builds

1. Deploy `backend/` to Vercel (see README).
2. In Codemagic, go to the app → **Environment variables**. Add `RECOGNIZE_URL` = `https://YOUR-APP.vercel.app/api/recognize` in a group named `weighwell`.
3. In `codemagic.yaml`, remove the `#` from the two `groups:` lines, then push.

## If a build fails

Open the failed step in Codemagic and copy the red error text. Paste it into Claude to get a fix.
