# viz_flutter

A new Flutter project.

## API server

The app defaults to the production backend:

```text
https://www.viz24.net/api
```

You can override it with `API_BASE_URL` when testing against a local backend.

For the normal production backend:

```bash
flutter run
```

For the Android emulator with a local Laravel server running on your computer:

```bash
cd ../viz-app
php artisan serve --port=8000
cd ../viz_flutter
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

For a physical phone with a local Laravel server, replace the host with your computer's LAN IP:

```bash
cd ../viz-app
php artisan serve --host=0.0.0.0 --port=8000
cd ../viz_flutter
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

For production builds:

```bash
flutter build apk
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
