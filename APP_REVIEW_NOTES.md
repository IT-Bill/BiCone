# App Review Notes for BiCone (iOS / TestFlight)

Use this text in **App Store Connect → App Review Information**.

## Reviewer access

BiCone's production login uses **Bilibili QR-code login**, which requires a separate mobile device and an external Bilibili account. To make review possible without external credentials, the app includes an in-app **App Review Demo** mode.

### Steps

1. Launch the app
2. On the login screen, tap **App Review Demo**
3. The app will open with:
   - a seeded demo account
   - preloaded subscriptions
   - sample feed items
   - sample download states (completed / paused / failed / invalidated)

### Notes

- In **App Review Demo**, live RSS monitoring and real account binding are disabled on purpose.
- Reviewers can still evaluate the main app experience, including:
  - feed browsing
  - filtering and search
  - subscription management UI
  - download management UI
  - simulated download / pause / resume flows
  - settings and update UI

## Suggested App Review Information text

> BiCone normally uses Bilibili QR-code login, which requires a separate mobile device and an external Bilibili account. For App Review, please tap **App Review Demo** on the login screen. This opens the app with a preloaded demo account and seeded sample data so the core functionality can be reviewed without external credentials or QR scanning.
