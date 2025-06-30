# Lockity Flutter

## Setup

1. Copy environment file:
```bash
cp assets/config/.env.example assets/config/.env
```

2. Edit `assets/config/.env` with your actual values:
   - Replace `your-client-id-here` with your Laravel OAuth client ID
   - Update BASE_URL if needed

3. Run the app:
```bash
flutter pub get
flutter run
```

## Important
Never commit the `.env` file with real credentials!