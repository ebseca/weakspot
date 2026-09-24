# Release process

Status of each step, and what is left. Mirrors eyetrainer's release on
purpose (`C:\bigideas\eyetrainer\store\RELEASE.md`).

---

## 1. Upload signing key — DONE

Created 24 September 2026 by `tool/create_upload_key.ps1`.

| | |
|---|---|
| Keystore | `C:\bigideas\vault\flashcards\weakspot-upload.p12` |
| Properties | `C:\bigideas\vault\flashcards\key.properties` |
| Format | PKCS12 |
| Alias | `upload` |
| Owner | `CN=Weakspot, O=bigideas, C=GB` |
| Valid until | 9 February 2054 |
| SHA-256 | `54:2C:D8:6E:06:CC:9F:BB:ED:39:B1:AB:B3:E4:BF:15:73:9F:C9:20:58:91:1A:1A:70:7D:17:74:82:04:D6:08` |

The password was generated at random (40 characters), written directly into
`key.properties`, and never printed. It exists in exactly one place.

> ### Back this up
>
> **If you lose `C:\bigideas\vault\flashcards\` you can never update this app
> again.** Copy the whole directory somewhere private and durable — not a
> public repo, not a shared cloud folder.

When Play offers Play App Signing on the first upload, accept it: the key above
then becomes the *upload* key and can be rotated if it is ever lost.

## 2. Build configuration — DONE

`android/app/build.gradle.kts` reads the properties file from
`WEAKSPOT_KEY_PROPERTIES` (set at user scope), falling back to
`android/key.properties`, then to debug signing — which Play rejects.
R8 and resource shrinking are on.

The minified build was verified on the phone: launches, launcher alias intact,
nothing in the crash buffer.

## 3. Build and verify the bundle — DONE

```bash
flutter build appbundle --release
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Must print `Owner: CN=Weakspot, O=bigideas, C=GB`. Version `1.0.0+17`,
46.8 MB (per-device download is much smaller; Play ships one ABI).

## 4. GitHub — DONE

Public repo `github.com/ebseca/weakspot`, GPL-3.0. Pages serves `docs/` at
`https://ebseca.github.io/weakspot/` — the privacy policy Play links to.

## 5. Play Console — DONE

App `Weakspot`, package `com.ebseca.weakspot`, created on the
"Bad Decisions Make Good Apps" personal account.

| Section | Status |
|---|---|
| Store listing — name, short and full description | done |
| Icon 512, feature graphic, 7 phone screenshots | done (screenshot order to tidy) |
| Category Education, contact email and website | done |
| Privacy policy URL | done |
| Ads — none | done |
| Sign in details — nothing restricted | done |
| Advertising ID — not used | done |
| Government / financial / health — none | done |
| Target audience — 13–15, 16–17, 18+ | done |
| Data safety — collects and shares nothing | done |
| Content rating — ESRB Everyone, PEGI 3, USK all ages | done |
| Internal testing testers — lists `ben` and `biz` | done |
| Internal testing release `1.0.0 (17)` | **live** — published 24 Sep 2026, available to internal testers |

Every answer and its reason is in `LISTING.md`.

Play reports **8.25 MB** per-device download for the 46.8 MB bundle.

### Uploading bundles

The browser automation can only hand files under 10 MB to a page, and the
bundle is 46.8 MB, so the upload itself is a drag-and-drop by hand:
`build/app/outputs/bundle/release/app-release.aab` into the release's
"App bundles" box. Everything else in a release can be filled in for you.

## 6. After internal testing

Personal developer account: production needs a **closed test with 12+ testers
for 14 days** first, same as eyetrainer.

## Version bumps

The number after `+` in `pubspec.yaml` is the `versionCode` and must increase
on every upload.

## Screenshots

`store/assets/screens/` — device captures cropped to 1220×2440. Play caps a
screenshot's long side at twice its short side, and the phone's native
1220×2712 is 2.22:1, so raw captures are rejected. The crop removes the status
bar and gesture bar.
