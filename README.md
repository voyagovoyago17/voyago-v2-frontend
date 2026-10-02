# 🦜 Voyagooo — Frontend Flutter

> Application mobile **Voyagooo** — planification de voyage gamifiée. Construite avec **Flutter + Riverpod + flutter_map**.

[![Flutter](https://img.shields.io/badge/Flutter-3-02569B?logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart)](https://dart.dev/)
[![Riverpod](https://img.shields.io/badge/Riverpod-2-00BCD4)](https://riverpod.dev/)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-green)](https://flutter.dev/)

---

## 📋 Table des matières

1. [Concept](#-concept)
2. [Stack technique](#-stack-technique)
3. [Architecture](#-architecture)
4. [Écrans](#-écrans)
5. [Installation locale](#-installation-locale)
6. [Configuration](#-configuration)
7. [Lancer l'app](#-lancer-lapp)

---

## 💡 Concept

**Voyagooo** transforme la planification de voyage en jeu :
- 🃏 Swipe Tinder pour choisir tes envies
- 🤖 IA Claude génère un itinéraire personnalisé avec GPS, photos et météo
- 🏆 Gagne des XP, monte de niveau, débloque des badges
- 👥 Partage tes voyages avec la communauté
- 💎 Voyagooo Pro pour les voyageurs sérieux

---

## 🛠 Stack technique

| Technologie | Usage |
|---|---|
| **Flutter 3** | Framework UI cross-platform |
| **Riverpod 2** | Gestion d'état |
| **GoRouter** | Navigation déclarative |
| **Dio** | Client HTTP |
| **flutter_map** | Cartes OpenStreetMap (natif) |
| **SharedPreferences** | Stockage local (token, user_id) |
| **url_launcher** | Ouverture Stripe Checkout |
| **cached_network_image** | Images optimisées |
| **flutter_animate** | Animations fluides |

---

## 🏗 Architecture

```
lib/
├── main.dart           # Point d'entrée, initialisation
├── router.dart         # GoRouter — 16 routes
├── theme.dart          # ThemeData Voyagooo (dark, #58CC02)
├── models/             # Dart models avec fromJson/toJson
│   ├── auth_user.dart
│   ├── trip.dart
│   ├── poi.dart
│   ├── day_weather.dart
│   ├── interest.dart
│   └── user_profile.dart
├── services/
│   ├── api_service.dart     # Tous les appels API (Dio)
│   └── storage_service.dart # SharedPreferences wrapper
├── providers/               # Riverpod StateNotifier & FutureProvider
│   ├── auth_provider.dart
│   ├── trips_provider.dart
│   ├── interests_provider.dart
│   └── profile_provider.dart
├── screens/                 # 14 écrans
└── widgets/                 # 18 widgets réutilisables
```

---

## 📱 Écrans

| Écran | Route | Description |
|---|---|---|
| Bienvenue | `/welcome` | Écran d'accueil non connecté |
| Onboarding | `/onboarding` | Profil obligatoire après inscription |
| Home | `/` | Accueil, XP/niveau, navigation |
| Auth | `/auth` | Connexion / Inscription (email + Google) |
| Mot de passe oublié | `/forgot-password` | Reset 2 étapes |
| Swipe | `/swipe` | Sélection Tinder des intérêts |
| Configure | `/configure` | Paramètres du voyage |
| Itinéraire | `/itinerary/:tripId` | Carte + POIs + météo |
| Pricing | `/pricing` | Offres Voyagooo Pro |
| Profil | `/profile` | Profil, XP, badges, voyages |
| Communauté | `/community` | Feed public |
| Récompenses XP | `/xp-rewards` | Système de niveaux |
| Profil public | `/user/:id` | Voir le profil d'un autre |
| Cercle | `/circle/:circleId` | Détail d'un cercle communautaire |

---

## 🚀 Installation locale

### Prérequis
- Flutter SDK 3.x
- Android Studio (émulateur) ou Xcode (iOS)
- Backend Voyagooo lancé sur port 3333

### Étapes

```bash
# Cloner le repo
git clone https://github.com/AndyDev77/voyago-v2-frontend.git
cd voyago-v2-frontend

# Installer les dépendances
flutter pub get

# Lancer l'app
flutter run
```

---

## ⚙️ Configuration

L'environnement backend est géré dans `lib/core/config/app_environment.dart` (`AppConfig`) :

| Environnement | URL backend | Activé par |
|---|---|---|
| **LOCAL** | `http://127.0.0.1:3333` | par défaut en `flutter run` (debug/profile) |
| **PROD** | `https://api.voyagooo.com` ([docs](https://api.voyagooo.com/api/docs)) | par défaut en `flutter build` (release) |

```bash
flutter run                                  # LOCAL
flutter run --dart-define=APP_ENV=prod       # PROD depuis un build de dev
flutter build apk --dart-define=APP_ENV=local # release pointant sur le local
flutter run --dart-define=BACKEND_URL=http://192.168.1.81:3333  # URL personnalisée (prioritaire)
```

- Un bandeau **LOCAL** (bleu) ou **PROD** (rouge) s'affiche en haut à droite, sauf dans une release de prod.
- L'environnement et l'URL sont loggés au démarrage (`🌍 [ENV] ...`).
- En changeant de backend entre deux lancements, la session est automatiquement réinitialisée (un compte local n'existe pas en prod).
- Téléphone physique en local : `adb reverse tcp:3333 tcp:3333`, ou passer `useLanIpForDevice` à `true` / utiliser `BACKEND_URL`.

## ▶️ Lancer l'app

```bash
# Vérifier les appareils disponibles
flutter devices

# Lancer sur l'émulateur Android
flutter run

# Hot reload (pendant l'exécution)
# Appuie sur 'r' dans le terminal

# Hot restart
# Appuie sur 'R' dans le terminal

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

---

## 🎨 Design System

| Élément | Valeur |
|---|---|
| Couleur primaire | `#58CC02` (Voyagooo Green) |
| Fond | `#0F1117` (dark) |
| Surface | `#1A1D27` |
| Texte | `#FFFFFF` |
| Mode | Dark uniquement |
| Border radius | 16px (standard), 24px (cards) |
| Mascotte | 🦜 |

---

## 🗺 Cartes

L'app utilise **flutter_map** avec les tuiles **OpenStreetMap** — aucune clé API requise.
Les marqueurs POI sont numérotés avec la couleur Voyagooo Green (`#58CC02`).

---

*Voyagooo — Voyage. Joue. Découvre. 🦜*
