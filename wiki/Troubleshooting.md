# Troubleshooting

## Xcode Preview Does Not Show

Try the central preview catalog:

`Mac Setup Buddy/Previews/PreviewCatalog.swift`

If previews still fail, clean the build folder in Xcode and build the `Mac Setup Buddy` scheme once.

## App Builds But Package Fails

Confirm Xcode command line tools are installed and selected:

```bash
xcode-select -p
```

Then run:

```bash
./build_package.sh
```

## Light Or Dark Mode Looks Wrong

Most colors should come from:

`Mac Setup Buddy/Theme/Theme.swift`

Avoid adding hard-coded screen colors unless the view is intentionally special purpose.

## Screens Feel Clipped

Review the configured window size and any fixed-width panels. The deployment view has a right-side status column, so smaller windows may need a narrower column or less horizontal padding.
