# Build and Packaging

## Build In Xcode

Open:

`Mac Setup Buddy.xcodeproj`

Then build the `Mac Setup Buddy` scheme.

## Command Line Build

```bash
xcodebuild \
  -project "Mac Setup Buddy.xcodeproj" \
  -scheme "Mac Setup Buddy" \
  -configuration Debug \
  build
```

## Package

Run:

```bash
./build_package.sh
```

The package script builds the app and creates installer output under `dist/`.

## Source Control Notes

Keep generated output out of Git:

- `build/`
- `dist/`
- Xcode DerivedData
- local signing artifacts
