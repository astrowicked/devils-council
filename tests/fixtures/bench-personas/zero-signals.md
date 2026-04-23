# RFC: Add a color picker to the preferences pane

## Background

Users have asked for a way to customize accent colors in the preferences pane.
Today the preferences pane exposes a small number of static theme choices —
light, dark, and high-contrast. None of these let users tweak the accent hue.

## Proposal

Add a color picker beneath the existing theme selector. The picker shows a
hue wheel plus four saved swatches. Picking a color updates the preview
panel in real time. Saving persists the choice alongside the existing theme
preference.

## UX notes

- The picker collapses to an icon on narrow viewports.
- Swatches remember the last eight colors the user selected.
- A reset-to-default button restores the theme's stock accent.

## Rollout

Ship behind a preference-flag that defaults on for beta users and off for
everyone else. Expand to general availability after two weeks of use.

## Open questions

- Should the picker be available in the compact preferences view?
- Do we expose the picker to the keyboard-shortcut layer?
- Is there a way to share accent palettes across devices without a
  full sync subsystem?
