# Cookie Studio

A local-only SwiftUI utility for inspecting and editing Apple WebKit `Cookies.binarycookies` files.

## Features
- Import multiple `.binarycookies` files using the iOS document picker
- Parse Apple Binary Cookies pages and records
- Browse cookies and search by domain, name, path, or value
- Edit cookie fields; add and delete records
- View the imported file as raw hexadecimal bytes
- Export a JSON representation
- Rebuild a `.binarycookies` file
- Keep an untouched copy of every imported source file in the app's temporary workspace
- Dark interface; no network access or analytics

## Important compatibility notes
`Cookies.binarycookies` is a private/implementation-level WebKit persistence format, not a public stable interchange API. This project implements the commonly documented `cook` page container and cookie record layout. Apple may change the format between OS releases. Always keep the original backup and test exported files only with data you own and are authorized to modify.

The parser validates bounds and rejects malformed input rather than attempting unsafe reads. Rebuilding preserves cookie flags and dates represented by the format, but does not preserve undocumented padding bytes or unknown record extensions. The app therefore keeps the original file separately.

## Build from iPhone using GitHub
1. Create a new GitHub repository.
2. Upload the contents of this ZIP (not the enclosing folder).
3. Open **Actions** and run **Build unsigned iOS IPA**.
4. Download the `CookieStudio-unsigned-ipa` artifact.
5. The artifact contains `CookieStudio.ipa`.

The workflow uses a macOS GitHub-hosted runner, Xcode and XcodeGen. The resulting IPA is unsigned and will need a compatible signing method before installation.

## Local build
Requires macOS, Xcode, and XcodeGen:
```bash
brew install xcodegen
xcodegen generate
xcodebuild -project CookieStudio.xcodeproj -scheme CookieStudio -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO
```

## Privacy
All parsing, editing, conversion and export happen on-device. The app does not make network requests. Cookie values can contain authentication/session secrets; do not share exports or screenshots containing them.
