# Antagonistic Trader

Antagonistic Trader is a separate installable trading application owned by
CodePhantom Technologies. It inherits the visual identity of the original
Antagonistic Trading Co. website while remaining technically isolated from the
public CodePhantom subscription product.

## AT-001 scope

- Android application flavor: `antagonistic`
- package id: `com.codephantom.antagonistictrader`
- Flutter entrypoint: `lib/main_antagonistic.dart`
- legacy Antagonistic dark/blue theme
- execution abstraction for Deriv API contracts vs Deriv MT5 CFDs
- founder/private product boundary

AT-001 contains no live trading strategy and no trading credential.

## Product boundary

CodePhantom remains the public multi-strategy product.

Antagonistic Trader is intended for:
- private/founder synthetic research;
- later separately licensed synthetic access;
- later standalone order-flow products or research views where explicitly
  enabled;
- experimental strategies that are not part of the CodePhantom subscription.

Entitlements must be enforced by the backend. Hiding a Flutter screen is never
treated as a security boundary.

## Execution routes

### Deriv API

Use when the selected strategy can be expressed using a contract type actually
offered by Deriv's authenticated API for the selected underlying. Public tick
data may be consumed without an account token; account trading must be
authenticated server-side.

### MT5 CFD

Use when the strategy requires the CFD product available through Deriv MT5.
The logged-in MT5 terminal must remain online on an always-on Windows host.
This does not imply one strategy or one EA per VM: a single execution service
may route multiple strategy IDs, and independent terminals can also coexist
when host resources and account separation require it.

## Security

- no Deriv token in the APK;
- no MT5 password in the APK;
- no founder strategy rules in the APK;
- licence generation/revocation is server-side;
- execution fails closed until strategy, account and entitlement are approved.

## Build commands

CodePhantom Android:

```bash
flutter run --flavor codephantom -t lib/main.dart
flutter build apk --debug --flavor codephantom -t lib/main.dart
```

Antagonistic Trader Android:

```bash
flutter run --flavor antagonistic -t lib/main_antagonistic.dart
flutter build apk --debug --flavor antagonistic -t lib/main_antagonistic.dart
```

The packages are distinct, so both Android apps can be installed on the same device. Their auth callback schemes are also distinct to prevent one app from intercepting the other's callback.
