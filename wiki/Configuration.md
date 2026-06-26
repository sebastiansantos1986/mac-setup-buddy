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
- Brand colors in `Theme.swift`

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
