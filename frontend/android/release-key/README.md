# This signing key is PUBLIC

**The key in this folder is public on purpose. Anyone can sign an app with it.**

The owner decided this on 22 November 2026, knowing the repository is public:
"Just put it in the repo" ... "App is not being sent to the play store yet. Custom
installs only. We'll rotate it when publishing."

- It is for **sideloaded installs only** (an APK handed to friends).
- Do not trust "signed by this key" to mean "made by us": anyone can copy it.
- **Before any store release, replace it with a private key** kept as a build
  secret (never in the repository), and replace the fingerprint in
  `frontend/web/.well-known/assetlinks.json` with the new key's.
- Do not add any other secret to the repository.

## The files

| File | What |
|---|---|
| `midnight-village-public.jks` | The keystore (PKCS12, RSA 2048, valid 100 years from 22 Nov 2026). |
| `key.properties` | Its file name, alias and passwords, read by `../app/build.gradle.kts`. All four values are plainly named `midnight-village-public`. |

Alias: `midnight-village-public`. Store and key password: `midnight-village-public`.

SHA-256 fingerprint (what `assetlinks.json` carries):

```
09:0C:3F:15:6B:0D:B8:95:43:A1:FB:8C:80:AD:45:07:27:34:C5:2B:CB:B6:7B:89:68:A6:4D:2F:F7:E6:3B:A7
```

Check it with:

```bash
keytool -list -v -keystore midnight-village-public.jks -storepass midnight-village-public | grep SHA256
```

A test (`frontend/test/core/config/android_release_test.dart`) fails when `assetlinks.json` and this
key disagree.

## What this does to people who already have the app

Until now release APKs were signed with the debug key. Android refuses to update an app
in place with a different signing key: **anyone with an older APK uninstalls once**, then
installs the new one. (Their seat at a table is the server's; reopening restores it.)

## Replacing it (before a store release)

1. Make a private key (`keytool -genkeypair ...`) and keep it, and its passwords, in the
   build's secrets (never here).
2. Make `build.gradle.kts` read it from there, and delete this folder.
3. Put the new SHA-256 in `assetlinks.json` (Google Play's app signing may use a
   different key again: add its fingerprint too) and redeploy the web app.
