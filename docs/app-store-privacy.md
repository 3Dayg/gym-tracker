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

App Store Connect asks for a public URL. Until you host one (a GitHub page is enough), testers can still read the same text in the app: **Profile → Privacy**.

When you publish a page, paste the on-device Privacy screen there word for word so they stay the same.

## Encryption

`ITSAppUsesNonExemptEncryption` is already `false` in the app. In App Store Connect, say the app does **not** use non-exempt encryption (standard HTTPS is not involved; there is no network).
