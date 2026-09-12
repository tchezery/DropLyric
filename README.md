# droplyric

A modern Flutter application.

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the App
```bash
flutter run
```

---

## 🖥️ Platform Support

If you need to add or regenerate platform runners (macOS, Web, Linux, Windows), run:

```bash
flutter create --platforms=macos,web,linux,windows .
```

---

## 📁 Folder Structure

```bash
lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── routes.dart
│   └── theme.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   └── services/
│
├── features/
│   ├── auth/
│   │   ├── pages/
│   │   ├── widgets/
│   │   ├── models/
│   │   ├── services/
│   │   └── repositories/
│   │
│   ├── home/
│   │   ├── pages/
│   │   └── widgets/
│   │
│   └── profile/
│       ├── pages/
│       ├── widgets/
│       └── models/
│
└── shared/
    ├── widgets/
    ├── models/
    └── components/
```