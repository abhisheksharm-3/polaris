# Mobile stack overlay

<!-- Loaded for React Native, Expo, SwiftUI, and Flutter projects. Framework-specific APIs come -->
<!-- from fresh docs per the docs protocol; this holds what holds across all three. -->

## Detect

- React Native or Expo: `react-native` or `expo` in `package.json`. Expo Router when `expo-router`
  is present. Check `app.json` or `app.config.*` for the SDK version.
- SwiftUI: `Package.swift`, an `.xcodeproj`, or `.xcworkspace`; read the deployment target.
- Flutter: `pubspec.yaml`; read the Dart and Flutter constraints.

## Structure

- Screens are thin: they read state and render it. Data fetching, caching, and offline queues live
  in their own layer (TanStack Query or a store on React Native, an observable model on SwiftUI, a
  repository and provider on Flutter).
- Navigation is declared in one place. A deep link resolves through the same routes as a tap.
- Platform branches (`Platform.OS`, `#if os(iOS)`, `Platform.isIOS`) sit at the edge, never spread
  through business logic.

## Performance

- Virtualized lists only: `FlatList` or `FlashList`, `List` or `LazyVStack`, `ListView.builder`.
- Images sized to their container and cached.
- Animations on the native or UI thread: Reanimated worklets, SwiftUI animations, Flutter's
  implicit animations. Never drive a per-frame animation through JS state or `setState`.
- Measure startup and frame drops on a mid-range Android device, not the newest iPhone.

## Release

- Every user-visible change that could fail ships behind a remote flag.
- The server keeps old API versions until the installed base has moved off them.
- Over-the-air updates (EAS Update, CodePush) change JS and assets only, never native code or
  permissions, and follow store rules.
- Version and build numbers are bumped by the pipeline, never by hand.

## Testing

Per `rules/testing.md`: logic in plain unit tests, screens through the testing library for the
framework (React Native Testing Library, ViewInspector or XCUITest, `flutter_test`), and a handful of
end-to-end journeys in Maestro or Detox for the flows whose failure costs the business. No snapshot
of a whole screen.
