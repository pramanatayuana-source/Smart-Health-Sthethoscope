# Smart Health Monitor

A flutter project aimed at helping you monitor your own health, designed for Android.

# Building and Debugging

## REQUIREMENTS

- Complete flutter installation
- NDK version 28.1.13356709 (Install with Android Studio)

NOTE: If you have another NDK version, you can change the required ndkVersion in `android/app/build.gradle.kts`

## DEBUGGING

To set it up :

1. Make sure your have set up flutter properly (run `flutter doctor` to check)
2. Git clone the repo
3. Start up an emulator / connect an android device with USB Debugging
4. If you are on vscode, simply run and debug (`F5`).

The .vscode file contains basic launch parameters for debugging this project on vscode

## BUILDING

Each app can only have one language, which are defined as flavors.
Each language also needs to be supplied with a `LANG` environment variable
defined in --dart-define.

NOTE: Only EN and ID is supported. Flavor definition needs to be in **UPPERCASE**, while LANG definition needs to be **lowercase**.

**Example:**

`flutter build apk --flavor ID --dart-define id`

Builds an application with Indonesian as the locale.

# EDITING

The application follows flutters traditional page-based navigation. Please refer to the [official docs](https://docs.flutter.dev/) for more info.

Translations are defined and built with the `l10n` library and are defined in `lib/l10n`
