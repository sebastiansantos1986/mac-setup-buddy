# Configuration

Mac Setup Buddy is designed to keep organization-specific details configurable.

## Common Items To Customize

- App title and subtitle
- Welcome message
- Estimated setup time
- Step labels
- Support contact text
- Authentication placeholder text
- Installation item names, descriptions, icons, and triggers
- Banner image path
- Preview Mode behavior
- Brand colors in `Theme.swift`

## JSON Configuration

Mac Setup Buddy supports JSON configuration through `--config`.

```bash
open "Mac Setup Buddy.app" --args --config /Library/Application\ Support/Mac\ Setup\ Buddy/config.json
```

The repository includes:

- `config/mac-setup-buddy.schema.json`
- `config/sample-config.json`

Use the schema in your editor to validate keys and catch typos before deployment.

You can also validate a config with the app:

```bash
"Mac Setup Buddy.app/Contents/MacOS/Mac Setup Buddy" --validate-config /path/to/config.json
```

## Preview Mode

Preview Mode lets admins review the app screens without running installs, policies, scripts, or account actions.

```bash
open "Mac Setup Buddy.app" --args --preview
```

Preview Mode can also be enabled in JSON:

```json
{
  "ui": {
    "previewMode": true,
    "windowWidth": 1180,
    "windowHeight": 780
  }
}
```

## Network Required Gate

Use the Network Required gate to stop setup until the Mac is online.

```json
{
  "ui": {
    "requireNetwork": true,
    "networkCheckHosts": ["https://apple.com"]
  }
}
```

`networkCheckHosts` is optional. If omitted, the app checks the Mac's local network state only.

## Banner Artwork

The built-in default banner is stored in:

`Mac Setup Buddy/Assets.xcassets/DefaultBanner.imageset`

It includes separate Light Mode and Dark Mode artwork. macOS chooses the correct image automatically.

To use your own banner, set `branding.bannerImagePath` in configuration. A configured banner image path takes priority over the built-in default banner.

## Theme

The shared theme lives in:

`Mac Setup Buddy/Theme/Theme.swift`

The theme uses adaptive colors, so Light Mode and Dark Mode are handled automatically by macOS appearance.

## Screens

The main user-facing views live in:

`Mac Setup Buddy/Views`

The central preview catalog lives in:

`Mac Setup Buddy/Previews/PreviewCatalog.swift`

Use the preview catalog in Xcode to review the main screens in both Light Mode and Dark Mode.
