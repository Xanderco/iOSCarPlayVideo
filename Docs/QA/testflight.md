# TestFlight uploads

`.github/workflows/testflight.yml` archives DashCast in Release and uploads it to
App Store Connect. You start it by hand (`workflow_dispatch`): **Actions → TestFlight → Run workflow**.

| Input | Default | Meaning |
|---|---|---|
| `build_number` | `100 + run number` | `CFBundleVersion`. It must be higher than every build already uploaded for the same version. |
| `marketing_version` | value in `DashCast/Info.plist` | `CFBundleShortVersionString`, for example `1.0.1`. |

These overrides change only the copy of `Info.plist` on the runner. Nothing is committed.

## Required repository secrets

Add these under **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Where to get it |
|---|---|
| `ASC_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API → *Team Keys*. This is the **Key ID** column (10 characters). |
| `ASC_ISSUER_ID` | The **Issuer ID** shown above the key list on the same page (a UUID). |
| `ASC_KEY_P8` | Contents of the `AuthKey_<KEY_ID>.p8` file you downloaded when you created the key. Paste the PEM text as-is (`-----BEGIN PRIVATE KEY----- …`), or paste it base64-encoded (`base64 -i AuthKey_XXXX.p8 \| pbcopy`). The workflow accepts either form. |

The team ID `96YG38576A` is set in the workflow (`env.TEAM_ID`) and in `project.yml`. It is not a secret.

### API key role

Signing is automatic: `xcodebuild -allowProvisioningUpdates` uses the API key and
**cloud-managed distribution certificates**. You don't need to install a certificate or a
`.mobileprovision` file on the runner. To make this work:

- Create the key with the **Admin** role. App Manager can upload builds, but it can't create
  cloud-managed certificates unless that permission is granted separately.
- Register the bundle ID `com.xanderco.dashcast` under Certificates, Identifiers & Profiles.
  Create the app record in App Store Connect with that bundle ID.

## One-time App Store Connect setup

1. Create the app record (My Apps → +) with bundle ID `com.xanderco.dashcast`.
2. **Export compliance:** `Info.plist` has no `ITSAppUsesNonExemptEncryption` key, so App Store
   Connect asks about encryption on every build before testers can install it. If the app only
   uses HTTPS and system encryption, add `ITSAppUsesNonExemptEncryption = NO` to skip that question.
   The app owner must make this decision.
3. **CarPlay:** a CarPlay scene only runs on real head units and in the CarPlay Simulator once
   Apple has granted the CarPlay entitlement (for example `com.apple.developer.carplay-audio`)
   and it is enabled on the App ID. Without it, the TestFlight build still installs and runs
   on iPhone, but the app doesn't show up in CarPlay.
4. Add internal testers under TestFlight → Internal Testing. Builds reach internal testers after
   App Store Connect finishes processing them (usually 5–30 min).

## Troubleshooting

| Symptom (in `archive.log` / `export.log`, uploaded as the `testflight-logs` artifact) | Fix |
|---|---|
| `Missing secret ASC_…` | Add the secret. Names are case-sensitive. |
| `No Accounts` / `Authentication failed` | Key ID, Issuer ID, or `.p8` content is wrong, or the key was revoked. |
| `Cloud signing permission error` | Give the API key the Admin role. |
| `No profiles for 'com.xanderco.dashcast' were found` | Register the bundle ID, and check the key belongs to team `96YG38576A`. |
| `The bundle version must be higher than the previously uploaded version` | Run again with a larger `build_number`. |
| `Missing required icon` / asset validation errors | Fix `AppIcon` in `DashCast/Assets.xcassets`. |
