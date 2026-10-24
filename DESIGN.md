---
name: AkshatOS
description: A warm native personal desk lit from one corner, marked in violet.
colors:
  accent: "rgb(66.3% 54.5% 100%)"
  support: "rgb(35.7% 75.3% 56.1%)"
  tungsten: "rgb(6.3% 4.7% 3.5%)"
  surface: "rgb(15.7% 12.2% 10.2%)"
  series-recorded: "rgb(43.1% 31.0% 83.9%)"
  series-above-usual: "rgb(16.5% 58.0% 47.1%)"
  series-best: "rgb(75.3% 41.6% 22.7%)"
typography:
  display:
    fontFamily: "ui-rounded, system-ui"
    fontSize: "48px"
    fontWeight: 500
    fontFeature: "tabular-nums"
  headline:
    fontFamily: "system-ui"
    fontWeight: 600
  title:
    fontFamily: "system-ui"
    fontWeight: 600
  body:
    fontFamily: "system-ui"
  label:
    fontFamily: "system-ui"
rounded:
  paper-edge: "3px"
  calendar-day: "8px"
  selected-bar: "9px"
  paper-turn: "22px"
  instrument: "24px"
spacing:
  tight: "4px"
  small: "8px"
  row: "12px"
  instrument-inset: "16px"
  paper-inset: "18px"
  page-inset: "22px"
  history-section: "24px"
  today-section: "26px"
components:
  button-study:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.tungsten}"
    typography: "{typography.headline}"
  button-focus:
    textColor: "{colors.accent}"
  input-quick-add:
    typography: "{typography.body}"
  instrument:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.instrument}"
    padding: "{spacing.instrument-inset}"
  journal-paper:
    backgroundColor: "{colors.surface}"
    padding: "{spacing.paper-inset}"
  navigation:
    textColor: "{colors.accent}"
  study-dial:
    typography: "{typography.display}"
---

# Design System: AkshatOS

## Overview

**Creative North Star: "A warm desk under one lamp"**

A warm near-black ground, lit by a violet light from the top corner and a warmer one low on the opposite side, with fine grain so the two never band into each other. Violet marks study time and actions; a clear green distinguishes completed tasks. The character comes from the light, a useful instrument, recorded block graphics and a small book illustration. These details explain the work without adding a theme to the language.

This replaces the earlier graphite/copper/sage system, which was retired for a measured reason rather than a preference: on a dark ground the old copper and sage were both far above the lightness band a mark needs, carried almost no chroma, and sat only 8.9 apart in OKLab — 3.7 under simulated protanopia. Nothing could stand out, and the weekly chart's two series were near-identical. `look-and-feel.md` owns that finding; `UnitTests/HubInkTests.swift` holds it as an executable contract, including the retired pair as a negative fixture.

This documents the implemented personal-hub SwiftUI system: Today, To-do, Apps, study history, Watchlist and Spending. Journal is retired from navigation, settings, search, reminders, shortcuts and the combined full-day challenge. Its existing store, media, optional authentication and full-backup recovery remain; the paper tokens and unused Journal components below are legacy references. Native controls, the system font, SF Symbols and deliberate sheet presentation supply the iPhone feel. The app pins dark appearance. The older `Palette`, `Surface`, `ProgressOrbit` and `ActionStyle` in `DesignSystem.swift` remain a separate visual boundary for retained modules; this document does not restyle those modules or the PageVault reader.

This is a source extraction, not a release-acceptance claim. Source is authoritative for the latest navigation and control changes; fresh CI, capture and finish-review evidence is tracked separately in the release documents. The HTML design reference establishes the approved direction, not native pixel geometry. Frontmatter uses portable CSS units: numeric `px` values represent the corresponding SwiftUI point values at the base content size; semantic fonts and Dynamic Type still control native layout.

**Key Characteristics:**

- A warm tungsten ground lit from one corner, with restrained violet and support-green roles.
- Native navigation and controls with plain, visible labels.
- Purposeful graphics grounded in actual records.
- Scrolling and Dynamic Type reflow instead of a fixed phone composition.
- Flat tonal surfaces with a quiet book silhouette; legacy paper is retained as a reference.

## Colors

The custom colors come directly from `HubInk` in `ios/AkshatOS/shared/design-system/PersonalHubStyle.swift`; frontmatter preserves its sRGB channel values without rounding them to eight-bit hex.

### Primary

- **Violet** (`accent`): app tint, the study action, time arc, selected calendar outline and earned study marks. It is never a chart series, which is why it is allowed to sit brighter than the series band. The dial alone adds a lighter endpoint from its local gradient; that one-off endpoint is not a global accent token.

### Secondary

- **Support Green** (`support`): completed task symbols and priority segments, dial ticks, Watchlist symbols, the rising-momentum comparison and the readable To-do quick-add prompt. Its opacity variants show tracks and supporting artwork; they do not change what completion means. It stays distinct from the accent so "done" never reads as "in progress".

### Chart series

Only these three encode categories, and only together. They are validated as a set against `surface` for lightness, chroma, adjacent separation in normal vision and under simulated color blindness.

- **`series-recorded`**: ordinary recorded study time.
- **`series-above-usual`**: time above the trailing-seven-day baseline.
- **`series-best`**: a personal best, in the week bars and in the history label.

### Neutral

- **Tungsten** (`tungsten`): the personal-hub ground and the dark foreground on prominent violet actions.
- **Instrument Surface** (`surface`): the study instrument, unqualified elapsed calendar cells and legacy Journal writing field.

Native `.primary` and `.secondary` supply text hierarchy. System list rows, segmented controls, separators, alerts, navigation and tab-bar material retain their platform colors. The weekly chart includes a text legend and inspected values, so color is accompanied by words — that pairing is what keeps the chart honest regardless of the palette, and it is not optional.

**The Validated Series Rule.** A chart series takes one of the three `series` tokens. Adding a fourth category, or changing one of the three, requires re-validating the whole set and updating `HubInkTests`; do not reach for a semantic SwiftUI color or a new hex value to add a category.

**The Recorded Color Rule.** Progress color follows stored facts; empty, future and unavailable data remain distinct states.

## Typography

**Display Font:** the native system rounded design for the dial numeral.
**Body Font:** the native system font throughout the personal hub.
**Label/Mono Font:** system semantic text styles; tabular digits stabilize changing time and money values. No bundled display face or separate monospace family is installed by this system.

The hierarchy is familiar and restrained. Frontmatter records explicit weights and the one explicit base display size; it deliberately omits fixed sizes, line heights and tracking for platform-managed text styles.

### Hierarchy

- **Display:** `StudyDial` uses a medium rounded numeral with `@ScaledMetric(relativeTo: .largeTitle)`, monospaced digits, one line and a minimum scale factor of 0.6. The base size is in `typography.display`; the native metric grows with Dynamic Type.
- **Headline:** `.headline` identifies the main study action, period heading and block/day headings.
- **Title:** Today section headings use `.title3.weight(.semibold)`; the Apps PageVault title instead uses `.title3.weight(.medium)`. Navigation titles remain native.
- **Body:** ordinary content, task titles, writing and native form fields use the system defaults. Secondary descriptive content uses `.subheadline` where specified.
- **Label:** `.caption`, `.caption2` and `.footnote` distinguish dates, chart values, explanations and save status. They are native scalable roles, not a web font-size scale.

**The Native Type Rule.** Preserve semantic text styles and the dial's scaled metric; do not replace them with a fixed-size mockup transcription.

## Layout

Each of the three tabs, Today, To-do and Apps, owns a native `NavigationStack`. Today and study history are vertically scrolling compositions; To-do, Apps, Watchlist, Spending and settings use native lists or forms. The page inset, instrument inset, legacy paper inset and section rhythm are recorded in frontmatter. Native lists retain their own row geometry rather than borrowing these scroll-view insets.

The study instrument is one rounded container, with the status row, dial, explicit studied/block or break readout, primary timer action and thought capture. At accessibility Dynamic Type sizes, the main action moves above the dial, the date abbreviates and `AdaptiveRow` stacks its values. `StudyDial` changes its maximum width from 280 to 380 points and retains an aspect ratio of 1.12. It is allowed to scroll; there is no web-style viewport lock or documented width breakpoint.

Build-39 Focus uses the same dial on a flat tungsten desk surface, taking the ground without the lights or grain because the screen stays on. In compact-height landscape with
at least 560 points of available width, the dial and controls align at the top side by side, with
the dial sized to the usable height and an 8-point inner button inset instead of the portrait
24-point inset, keeping the full countdown and single-line label readable. Narrow and accessibility
layouts stack and scroll. Native navigation, safe areas and 44-point actions remain. Keep screen awake
is one native switch; optional Live Activity controls are collapsed. The lock-screen card uses plain
white semantic-sized text on tungsten, system timer text and no animation or private topic content.
`study-display.md` owns functional and device acceptance; source changes alone are not visual proof.

Weekly blocks use a horizontal scroll area with day buttons at least 44 points wide, 24-point-wide block marks and a 100-point plot height. The month calendar has seven columns with 44-point minimum cells, a 320-point minimum grid width and horizontal overflow. Inspection happens by tapping a day. Future days have an explicit upcoming state rather than a fabricated total.

Study history opens as one closable sheet. Focus opens a full-screen native cover with a Close action. Topic, task, priority and record editing use native sheets. Apps opens occasional tools through standard navigation. A retained Journal route opens Apps without exposing the retired editor. The daily hub has no fitness cards or fitness completion requirements; retained fitness recovery remains behind settings.

## Elevation & Depth

The personal-hub custom surfaces use no custom shadows. Depth comes from the lit ground, the difference between tungsten and the instrument surface, the dial's strokes and layered book shapes. The unused Journal paper retains its corner turn. Native sheets, navigation, list rows and the tab bar retain the platform's own material and presentation. The dial's violet gradient communicates measured progress; it does not create a global gradient background. There is no custom perpetual animation or app-defined motion token in these components. Native control and presentation behavior remain system-owned.

`HubBackground` is the ground: the tungsten fill, and when `lit`, two radial lights — violet past the top-trailing corner, warmer past the bottom-leading one — over a 96-point tile of static monochrome noise at 5% in overlay. The noise is not decoration: without it the two lights band visibly where they meet. The whole view is decorative, so it is hidden from assistive technology and carries no meaning. It is static; nothing here animates.

**The Lit Ground Rule.** The lights and grain are the expensive part of this system, so they are spent deliberately, not applied everywhere by default. Today takes `HubBackground()`. Focus takes `HubBackground(lit: false)` because it holds the screen on for a whole study block. Lists and forms take the flat `HubInk.background` through `personalList()`. Extending the lit ground to another screen is a decision with a battery cost, not a consistency fix.

**The Tonal Surface Rule.** Use surface contrast and purposeful geometry for the personal hub; retain native presentation materials rather than adding ornamental shadow layers.

## Shapes

The study instrument uses the rounded silhouette in `rounded.instrument`. Legacy Journal paper uses three small corners from `rounded.paper-edge` and a larger top-trailing corner from `rounded.paper-turn`; it is a dark writing surface, not a white notebook texture. Calendar cells and selected weekly-bar wells use their frontmatter radii. Priority progress uses capsules, and task states use native circle/checkmark-circle SF Symbols.

The PageVault launcher book is `HubBookArtwork`: a 54 × 72-point composition with two rounded rectangles, a 5-point horizontal/4-point vertical back-layer offset, a violet outline inset by 10 points and a system book symbol. It is decorative and accessibility-hidden. It is separate from actual library covers. Native prominent and bordered buttons, form fields and segmented pickers retain intrinsic system corner shapes; no custom radius is asserted for them.

## Components

### Buttons

The study control is full-width, prominent and plain in meaning. It uses native `.borderedProminent`, violet tint, tungsten foreground, `.headline` text and a label at least 44 points high. Its label changes between Start studying, Pause studying and Resume studying according to the timer. The unused legacy Journal Done action retains the same prominent treatment and is disabled while writing is empty or unsaved.

Text actions inherit the violet tint. Today Focus has an explicit 44 × 44-point minimum label frame; add icons and task checks likewise have explicit hit frames where specified. Thought capture's plus action is disabled for whitespace-only input. Bordered alternatives use native `.bordered`. Press, keyboard focus, disabled appearance and presentation transitions are intrinsic native behavior; there is no custom hover/focus animation vocabulary to copy from the HTML reference.

### Cards / Containers

The study instrument uses `HubInk.surface`, the instrument corner token and inset token with no overlay border or custom shadow. The unused legacy Journal writing container shares the surface color but uses its asymmetric paper silhouette and paper inset. These are contextual containers, not a generic card grid or a replacement for native list rows.

### Inputs / Fields

To-do quick add is a native single-line `TextField` beside a plus-circle action. A persistent **Add a task** section header names the purpose; the example prompt uses support green explicitly. Submission adds the task and clears focus only after the store reports success. The thought field is a native vertical field limited to one through four lines; successful capture presents a short saved-location message.

The unused legacy Journal editor retains a native `TextEditor` with hidden scroll background and a minimum height of 240 points inside the paper. Its label stays visible. Draft saved, draft not saved and Done are explicit statuses; a failed draft exposes Retry save. Native forms supply task, Watchlist and Spending editors, including validation, disabled Save actions and system alerts. No custom focus ring, input fill or validation border is defined by this system.

### Navigation

`HubRootView` uses the actual native `TabView` with Today/calendar, To-do/checklist and Apps/square.grid.2x2 labels and SF Symbols, in that order. Violet supplies the selected tint; native chrome supplies sizing, inactive treatment and material. To-do's My To-do/After study switch and history's Week/Month switch use native segmented `Picker`s, not custom chips.

The Apps PageVault row has the book artwork and a live continuation description when a current book exists; Watchlist and Spending use ordinary symbol-and-label rows. Settings and backup remain explicit destinations. Apps search covers tasks and parked thoughts. Unavailable stores, empty records and app-background privacy curtains remain distinct native states. Retained Journal authentication remains optional; recovery exports are not encrypted.

### Study Dial and Recorded Blocks

The dial is a three-quarter circle rotated from 135 degrees, with an eight-point round-capped track and progress stroke. Progress clamps studied time divided by the target to the range zero through one. Its 37 support-green tick marks distinguish every sixth tick with a longer stroke. Tapping the central button switches the labelled number between Remaining and Studied; an accessibility value supplies studied time and target. The labelled studied readout remains visible below the dial.

Weekly bars stack pieces derived from actual study blocks, with small gaps; the three validated `series` tokens encode ordinary time, above-usual time and personal best respectively, never a semantic SwiftUI color. Selection adds a faint accent well, a textual readout and the selected accessibility trait. Zero elapsed time and future days have different labels. History retains empty and unavailable states, and comparisons appear only when their record coverage exists. No production example values are prescribed here.

The local `.impeccable/design.json` sidecar provides illustrative HTML/CSS inspection adapters for these source-backed patterns. They are not executable SwiftUI, do not emulate SF Symbols or certify native geometry, Dynamic Type, semantics, hit testing or system chrome. Its generated tonal ramps are inspection aids, not additional app colors. Native source and native captures remain the implementation and verification authorities.

## Do's and Don'ts

### Do:

- **Do** preserve the tungsten ground, the violet accent and the support-green roles while retaining native semantic text and control colors.
- **Do** keep chart categories on the three validated `series` tokens, always paired with words.
- **Do** keep the three native tabs, Today, To-do and Apps, and deliberate, closable history and editing presentations.
- **Do** preserve semantic typography, Dynamic Type reflow and explicit 44-point action frames where implemented.
- **Do** pair progress graphics with actual records, labels and honest empty, future, locked or unavailable states.
- **Do** keep labels visible at rest and retain clear saved, unsaved and disabled states.
- **Do** keep legacy module styles and reader-specific presentation within their existing boundaries.

### Don't:

- **Don't** turn the approved dial, paper or book treatment into game metaphors, themed labels or ornamental motion.
- **Don't** add fitness tiles or fitness requirements to the personal daily hub.
- **Don't** substitute prototype CSS geometry or sidecar adapters for native controls and native verification.
- **Don't** fill missing history, comparisons or earned progress with production demo values.
- **Don't** treat a screen lock, successful source extraction or a prior capture as evidence for unverified release behavior.
