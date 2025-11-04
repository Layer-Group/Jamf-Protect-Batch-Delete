## Roadmap (GUI-focused, aligned with Apple HIG)

This roadmap prioritizes safety, clarity, and accessibility. It complements the high-level list in `README.md` with concrete acceptance criteria and concise UI flows.

### Now (Top 5)

#### 1) Dry‑run preview sheet
- Acceptance criteria
  - Shows counts by category (Will Delete, Kept, Excluded) and a diff-style table.
  - "Export preview CSV" and "Copy summary" actions are available.
  - Destructive confirmation disabled until user types `DELETE <count>`.
  - Sheet uses system destructive button styling and supports Dark Mode.
  - VoiceOver announces counts, table updates, and button states.
- UI flow
  - Run → Dry‑run executes → Sheet appears with results summary → User can Export/Copy → Type-to-confirm → Confirm Delete or Cancel.

#### 2) Filters sidebar + quick search
- Acceptance criteria
  - Persistent sidebar with presets list and a Save preset action.
  - Tokenized search for hostname/serial, date pickers for check‑in ranges, and regex/wildcard toggle with validation feedback.
  - Quick search filters the table instantly; preset selection is persisted across launches.
  - All inputs are reachable via keyboard; labels read correctly with VoiceOver.
- UI flow
  - View → Show Filters → Adjust tokens/ranges → Results update live → Save preset → Reuse from sidebar.

#### 3) Progress and error UI
- Acceptance criteria
  - Non‑blocking progress overlay shows overall status; table shows per‑item states (queued/running/retried/failed/success).
  - Error banner provides expandable details and an "Export failures CSV" action.
  - "Retry failed" re-queues only failures with exponential backoff.
  - Progress and failures remain visible until dismissed; supports Dark Mode and VoiceOver.
- UI flow
  - Start run → Overlay shows progress → Per‑item status updates → On completion, show summary with Retry/Export.

#### 4) Table UX enhancements
- Acceptance criteria
  - Column chooser (show/hide) with persisted order; column pinning and sticky header.
  - Multi‑sort (e.g., by last check‑in then hostname) with visual sort indicators.
  - Selection count displayed; context menu includes Copy Serial, Show in Jamf, Exclude.
  - Works with large lists (pagination or incremental loading) without stutter.
- UI flow
  - Click Columns → Toggle visibility/pin → Sort via header; right‑click row for actions; selection updates count.

#### 5) Keyboard shortcuts and menu bar
- Acceptance criteria
  - Shortcuts: ⌘F (search), ⌘R (dry‑run), ⌘↩ (confirm deletion), ⌥⌘S (save preset), ⌘E (export CSV).
  - All actions mirrored in the app menu with correct states and help tags.
  - Focus order is logical; shortcuts are discoverable via menu and Help.
  - Works under VoiceOver without trapping focus.
- UI flow
  - User invokes shortcuts; menu items reflect availability; actions trigger the corresponding views/sheets.

### Next
- Undo window (soft delete) with 10‑minute banner and countdown.
- Schedules window for safe hours/blackout times.
- Status bar item (menu extra) to run saved presets and open last report.
- Onboarding tour and inline help popovers.
- Accessibility deepening (custom rotor for columns, non‑color error cues).

### Later
- Preset sharing/import-export.
- Notifications preferences (Slack/Email) and webhook integration.
- Localization-ready UI including right‑to‑left support.
- Advanced selection tooling (paste list, fuzzy matches, preview hit counts).
- Resume-after-crash UX (restore last session on launch).

### Design references
- Apple Human Interface Guidelines: `https://developer.apple.com/design/human-interface-guidelines/`
- AppleDesignTips (provided): hit‑target size, legibility, contrast, spacing, asset quality, alignment.

### Success metrics (definition of done)
- No WCAG AA contrast violations in Light/Dark Mode.
- All controls keyboard-accessible; basic VoiceOver labels verified.
- CSV exports open correctly in Numbers/Excel; UTF‑8 with headers.
- State persists across relaunch (presets, table columns, sort).
- Dry‑run prevents deletion unless explicit typed confirmation matches count.


