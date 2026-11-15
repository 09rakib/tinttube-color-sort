# Android QA and release preparation

## Debug builds

Install the Godot 4.7.2 export templates and configure the Android SDK and JDK 17 in Godot's editor settings. The QA preset uses API 36 for Gradle builds, supports ARM64 and x86_64, and uses the test package ID `com.tinttube.colorsort.qa`.

From PowerShell at the repository root:

```powershell
./scripts/build_android_qa.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
adb install -r build/tinttube-admob-qa.apk
adb shell monkey -p com.tinttube.colorsort.qa -c android.intent.category.LAUNCHER 1
```

The script verifies the SHA-256 of the [Poing AdMob 5.1.0 release archives](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0) and installs the addon in a staging copy. The QA build uses Google's [demo rewarded unit](https://developers.google.com/admob/android/test-ads) and the plugin's demo application ID. Choose **Find ad** in Shop, then **Watch ad** once loaded. Android debug builds with the addon expose the offer; `-Offline` instead builds `build/tinttube-offline-qa.apk` without the addon. Both variants use the same package ID and share progress when installed with the same debug key.

| Check | Expected result |
| --- | --- |
| Tap, pour, undo, restart | One pour per valid tap pair; undo and restart restore the correct board. |
| Home, Levels, Daily, Shop, Settings, Android Back | Navigation preserves the campaign attempt when leaving for Daily. System Back returns from gameplay and submenus to Home. In Levels, it returns to the screen that opened Levels. |
| Background during a pour, then return | Move settles once; tubes and sound recover. |
| Force-stop and reopen after a win or shop purchase | Wallet and progress persist; an unfinished attempt restarts. |
| Physical phone: vibration on/off, frame pacing | Feedback follows the toggle; record frame intervals during idle and repeated pours on Level 50. |
| Watch a full demo ad, close it and relaunch | Wallet increases by 20 once and survives restart. |
| Close a demo ad early | Wallet stays unchanged. |
| Request an ad with networking unavailable, then retry online | Shop and gameplay remain usable, balance stays unchanged, and the next request can succeed. |
| Test UMP with a configured test app/message | Before loading ads, resolve consent. Verify **Ad privacy options** appears when required and lets the player reopen the form. Verify consent errors leave gameplay available. |

## Google Play Billing interface

Keep cash purchases separate from the local cosmetic shop. A future Play Billing adapter should expose these operations to the UI and entitlement code:

| Operation | Contract |
| --- | --- |
| `query_products(product_ids)` | Returns product ID, title, localized price, and the offer token where required. The UI uses the store price. |
| `launch_purchase(product_id, offer_token)` | Starts Play's purchase UI. An accepted launch, cancellation, or pending transaction does not grant an item. |
| `query_owned_purchases()` / `purchase_updated` | Reconcile at startup and resume; include product IDs, purchase token, and purchase state. |
| `verify_and_fulfill(purchase)` | Verify a `PURCHASED` token with a trusted backend and apply the entitlement once per token. Acknowledge durable purchases or consume consumables after fulfillment. Retry unfinished work after relaunch. |

No paid products are configured. Select a supported [Google Play Billing Library version](https://developer.android.com/google/play/billing/deprecation-faq) when implementing the adapter, and use [Play's purchase processing guidance](https://developer.android.com/google/play/billing/integrate) for pending purchases, verification, and acknowledgement. Use Play license testers before exposing any paid offer.

## Release inputs and checks

- Confirm the final application ID, Play Console ownership, and upload signing key. Keep keystore paths/passwords out of Git. Create a separate release preset and export a signed AAB with [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).
- Verify the final AAB against the [target API requirement](https://support.google.com/googleplay/android-developer/answer/11926878) and [16 KB page-size guidance](https://developer.android.com/guide/practices/page-sizes). Test the actual release build on ARM64.
- Complete the store listing, app content, ads declaration, privacy policy, and Data safety answers for the SDKs that actually ship. Before enabling production ads, configure the real AdMob app and ad unit, publish the relevant UMP messages, and verify the privacy flow in test mode.
- Use the Play testing track required for the account. Check the [closed testing requirement for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465) if it applies.
