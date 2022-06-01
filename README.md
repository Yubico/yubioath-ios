# iOS application for OATH with YubiKeys

This app is hosted on the iOS App Store as 
[Yubico Authenticator](https://apps.apple.com/se/app/yubico-authenticator/id1476679808).

See the file LICENSE for copyright and license information.

## OATH functionality

This is an authenticator app compatible with the OATH standard for time and
counter based numeric OTPs, as used by many online services. To store these
credentials and generate the codes, it uses a compatible YubiKey, connected
either via NFC or the Lightning port.

Add credentials by tapping the menu icon, selecting `Add account` and then
either add a credential by scanning a QR code, or by tapping the `Enter manually`
button.

Once credentials have been added, simply tap or connect your YubiKey to display
codes.

## CryptTokenKit extension

Besides the OATH functionality this app also support authetication using the CTK extension
functionality provided by Apple. The authentication is handled using certificates stored 
in the Smart card application on the YubiKey.

## Development

This app is developed in Xcode and the only external dependency is the
[YubiKit iOS SDK](https://github.com/Yubico/yubikit-ios) which is added using
the Swift Package Manager. To build the app simply open the project file and hit
the build button.

## Issues

Please report app issues in
[the issue tracker on GitHub](https://github.com/Yubico/yubioath-ios).
