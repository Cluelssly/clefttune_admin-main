# CleftTune Admin

Flutter admin dashboard connected to the `appcleft2026-55337` Firebase project.
The web and Android Firebase options are configured in `lib/firebase_options.dart`.

## Firestore data

- `users` is read in real time. Supported fields include `name` or
  `displayName`, `email`, `level` or `userLevel`, `streak` or `currentStreak`,
  and `createdAt` or `joinedDate`.
- `feedback` is read in real time. Supported fields include `userId`,
  `userName` or `name`, `rating`, `comment`, `feedback`, or `message`, and
  `createdAt` or `date`.
- `badges` is loaded from Firestore and managed from the Badges screen.
  Documents use `badge_name`, `emoji`, `min_level`, and optional `tasks`,
  `badge_description`, and numeric `color`.

The app displays Firestore records; it does not seed demo users, feedback, or
badge tiers. Ensure the deployed Firestore security rules grant the appropriate
read access and authorized badge writes for the admin app.

## Run

```sh
flutter pub get
flutter run -d chrome
```

For Android, run `flutter run` with an Android device or emulator.
