# Jamf Protect Batch Delete

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013–15-blue)](#requirements)
[![Status](https://img.shields.io/badge/status-beta-orange)](#status)

Batch-delete computer records from your Jamf Protect tenant. This macOS app provides a fast UI to fetch stale devices by last check‑in or import a CSV of serial numbers, review the list, and safely delete in bulk.

### Status

This is an actively maintained fork of the original project by red5coder, with ongoing improvements to UX, reliability, and safety.

- Original repository: [red5coder/Jamf-Protect-Batch-Delete](https://github.com/red5coder/Jamf-Protect-Batch-Delete)
- Current status: beta (use with care; test in non‑production first)

## Features

- Fetch computers that have not checked in for a chosen timeframe (7–360 days or 0 days)
- Import a CSV of serial numbers (single column, no header)
- Search, sort, and select/deselect in a table view
- Bulk delete with confirmation dialog
- Optional Keychain storage for the API password
- Unified Logging integration for audit/troubleshooting
 - Non‑blocking progress overlay showing overall status (Queued/Running/Success/Failed)
 - Per‑item status updates in the table (Queued/Running/Retried/Failed/Success)
 - Retry failed items with exponential backoff
 - Error banner with expandable details and “Export failures CSV”
 - Export successful deletions to CSV (toolbar button and File → Export successes CSV)
 - Dark Mode and VoiceOver support
 - Statistics Dashboard with charts: status breakdown, success ratio, top error types
 - View menu integration: Show Dashboard (⇧⌘D)
 - Feedback entry points: toolbar Feedback button and App Menu → Send Feedback…

## Requirements

- A Mac running macOS Ventura (13), Sonoma (14), or Sequoia (15)
- Xcode 15 or newer (tested on recent Xcode versions)
- A Jamf Protect tenant
- A Jamf Protect API client with permissions:
  - Read and Write for Computers
  - Read and Write for Alerts

## Install / Build

🚀 Download and run the latest app – no Xcode required.

- **Download**: Grab the newest release from the [Releases](https://github.com/Layer-Group/Jamf-Protect-Batch-Delete/releases) page.
- **Install**: Open the downloaded `.dmg` or `.zip` and drag the app to `Applications`.
- **First run**: On first launch, macOS may show a Gatekeeper prompt. If needed, Control‑click the app and choose “Open”.
- **Permissions**: The app uses App Sandbox with “User Selected File Read/Write” and network access. You’ll be prompted when exporting files. 🔐

🧪 Prefer to build from source? You still can: open `Jamf Protect Batch Delete.xcodeproj` in Xcode and run the `Protect Batch Delete` scheme.

## Configure

You will need the following from your Jamf Protect environment:

- Jamf Protect URL (e.g., `https://your.protect.jamfcloud.com`)
- API Client ID
- API Client password

Ensure the API client has the permissions listed in Requirements.

## Usage

1. Launch the app and enter your Protect URL, Client ID, and Password.
2. (Optional) Enable “Save Password” to store the password in Keychain.
3. Choose a "Not Checked‑in" range and click "Fetch" to pull devices from Jamf Protect.
   - Or click "Import CSV" to bring in a single‑column list of serial numbers.
4. Use search, sort, and selection tools to review the list.
5. Click "Delete Selected" and confirm to proceed.

### During and after a run

- While deleting, a non‑blocking overlay shows overall progress; the table’s Status column updates per item.
- On completion:
  - If any items failed, a completion overlay appears with actions: Retry failed, Export failures CSV, Export successes CSV, Dismiss.
  - A top error banner summarizes failures and can expand to show detailed errors; it remains until dismissed.
  - If no items failed, the completion overlay is suppressed, but you can still export successes from the toolbar or File menu.

### Exporting results

- Export failures: use the button in the error banner or completion overlay.
- Export successes: use the toolbar button or File → Export successes CSV (⇧⌘E).

### Dashboard

- Open the Dashboard from the menu: View → Show Dashboard (⇧⌘D).
- Shows:
  - Status breakdown bar chart
  - Success ratio (donut on macOS 14+, stacked bars on macOS 13)
  - Top error types list (click‑to‑copy text)
  - Summary tiles for Success, Failed, Retried, Total

### CSV format (example)

```text
ZRFN72C5GI
ZRFN63C5GJ
ZRFN91C5GH
```

### Logging

The app writes to macOS Unified Logging. To stream logs:

```bash
log stream --predicate 'subsystem == "co.uk.mallion.jamf-protect-batch-delete"' --level info
```

### Screenshot

<img width="1014" alt="App screenshot showing batch delete UI" src="https://github.com/Layer-Group/Jamf-Protect-Batch-Delete/blob/main/Screenshot/Screenshot1.png?raw=true">

### Dashboard screenshot

<img width="1014" alt="Dashboard window with charts" src="https://github.com/Layer-Group/Jamf-Protect-Batch-Delete/blob/main/Screenshot/dashboard1.png?raw=true">

## Security & Privacy

- The URL and Client ID are saved to `UserDefaults` for convenience.
- If you enable “Save Password”, the password is stored in your Keychain under the service `co.uk.mallion.jamfprotect-batch-delete`.
- Deletions are permanent in Jamf Protect. Perform a small test first and consider exporting a list of devices before bulk actions.

### App Sandbox permissions

The app uses App Sandbox with “User Selected File Read/Write” so save/open panels can read and write files the user chooses. If you see “Unable to display save panel…” in a custom build, ensure your target’s entitlements include:

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
<key>com.apple.security.network.client</key><true/>
```

## Keyboard Shortcuts

- Export successes CSV: ⇧⌘E
- Show Dashboard: ⇧⌘D
- Send Feedback…: (no default shortcut)

## Feedback

- Click the “Feedback” toolbar button, or use the App Menu → Send Feedback…
- This opens the project’s GitHub “New issue” page so you can report bugs or request features.

## Troubleshooting

- 401/403 authentication errors: verify the URL, Client ID, and password; confirm API client permissions; ensure the URL includes `https://` and your correct tenant domain.
- No results when fetching: try a different last check‑in range; confirm devices actually meet the criteria.
- CSV import issues: ensure the file is plain text CSV with a single column of serial numbers and no header row.

## Roadmap

See detailed priorities, acceptance criteria, and UI flows in `ROADMAP.md`.

- Safer dry‑run preview before applying deletions
- CSV export of fetched computers and selected deletions
- Enhanced filters (check‑in ranges, alert state, hostname/serial patterns)
- Further refinements to progress UI and error reporting
- Keyboard shortcuts and accessibility improvements

## Contributing

Issues and pull requests are welcome. Please include clear steps to reproduce problems and proposed changes. For larger changes, open an issue first to discuss direction.

## License & Attribution

MIT License. See `LICENSE` for details.

This project builds on the original work by red5coder: [red5coder/Jamf-Protect-Batch-Delete](https://github.com/red5coder/Jamf-Protect-Batch-Delete).
