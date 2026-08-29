# App Store privacy answers

Copy these into App Store Connect when you submit. They match how Gym Tracker actually works: **data never leaves the iPhone**.

Apple’s word “collect” means transmitting data off the device so you (or a partner) can access it. This app does not do that.

## Privacy nutrition label

1. **Does this app collect data from this app?**  
   **No, this app does not collect data.**

2. **Data Used to Track You**  
   Do not declare any. Tracking is off.

3. **Data Linked to the User / Data Not Linked to the User**  
   Leave empty. There is no account and no off-device storage.

## Privacy policy URL

App Store Connect asks for a public URL. Use:

**https://github.com/3Dayg/gym-tracker/blob/main/docs/privacy.md**

That page is the same wording as the in-app screen: **Settings → Privacy**. Edit [docs/privacy.md](privacy.md) and the in-app `PrivacyPolicyView` together so they stay the same.

## Encryption

`ITSAppUsesNonExemptEncryption` is already `false` in the app. In App Store Connect, say the app does **not** use non-exempt encryption (standard HTTPS is not involved; there is no network).
