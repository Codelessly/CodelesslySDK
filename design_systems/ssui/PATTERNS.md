# Soft SaaS UI: patterns

How screens are put together from the components (adapted from soft_saas_ui's STYLE.md).

## In brief

- **Inline card** (a chat answer): a column on `primaryBackground`, radius 8 (`${theme.radii.panel}`), a hairline
  (`primaryBorder`), padding 12, children 12 apart; a `panelTitle` or `sectionTitle` heading, then content, then a
  right-aligned footer row of Buttons 6 apart (ghost Cancel, one primary).
- **Form**: a column of Fields 12 apart (16 between groups); each Field wraps one control (TextInput, Select,
  TextArea...) with its label above and its help or error below; the control and the Field share the error
  (`error: true` on the control, the message on the Field). Submit row: ghost Cancel + primary Submit, 28 px.
- **List**: a Card or a bordered column holding a SectionHeader (title, count) and ListRows (36 px, a hairline
  between, `dense` 28 in inspectors); the trailing slot holds a Badge, a value or an xs IconButton. A list that can be
  empty shows an EmptyState instead.
- **Choosing one of a few**: 2–5 options side by side: SegmentedControl; a list of options with details: Radios in
  a column 8 apart, or selectable Cards/ListRows (`selected`); many options: Select.
- **States**: loading is a ProgressBar (or the core `circularProgressIndicator`, 16 px, in `primary`) where the
  content will be; empty is EmptyState; an error is an error Banner above the content with a retry Button; success
  after an action is a success Banner or the card re-rendered in its new state.
- **Density**: controls 28 by default; 24 inside rows and chips; never mix sizes in one row. Text 13, secondary 12.

## Inline card

```
Card (or a column: primaryBackground, radius 8, hairline, padding 12, spacing 12)
  title (panelTitle) + subtitle (caption)
  content
  footer: row, mainAxisAlignment end, spacing 6: Button ghost "Cancel", Button primary "Confirm"
```

- The card is at most 390 wide in chat; it hugs its height.
- Put prices and totals in a row with `mainAxisAlignment: spaceBetween`: label `bodySecondary`, value `body` 600.
- A selected option (a flight, a plan) is a ListRow or a bordered row with `selected` bound: the active tint and a
  primary hairline. The confirm Button stays disabled (`enabled: false`) until something is chosen.

## Form with validation

- A Field per input; its `required` mark after the label.
- Validate on submit: a variable per field error (`"emailError"`), set by the submit Button's reaction with formulas
  (`${= !contains(email, '@') ? 'Enter a valid email.' : ''}`), bound into the Field's `error` and the control's
  `error` (`${= emailError != ''}`); send only when every error is empty.
- After sending: replace the form with a success Banner or an EmptyState-like confirmation, not a toast alone.

## Lists and tables

- Header: SectionHeader (title, count badge, trailing actions: an xs IconButton or an outline xs Button).
- Rows: ListRow with icon, title, subtitle; trailing Badge for a status, a value in `bodySecondary`, or a Chip.
- Quantity steppers: an xs outline IconButton `remove`, the value (`body`, tabular figures), an xs outline
  IconButton `add`, 6 apart.

## Dialogs

A modal canvas whose body is a Dialog: title (and description), the content (a Field or a line of text), actions
in its `actions` slot: ghost Cancel + one primary (destructive for a delete). Every destructive action asks first.

## Don't

- Don't put shadows on cards or rows; don't use a Banner for every message (inline text in `caption` is enough for
  hints).
- Don't make the page background white: it is `secondaryBackground`; cards are `primaryBackground`.
- Don't use `primary` for more than one button per view, or color text for emphasis: use weight 600.
