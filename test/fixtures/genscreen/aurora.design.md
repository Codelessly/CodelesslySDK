---
name: Aurora
version: 1.0.0
description: Calm, precise productivity and fintech. Indigo on cool white, soft depth.
---

# Aurora design kit

## Brand

Personality: calm, precise, quietly premium
Voice: plain and direct; short sentences; numbers before adjectives
Tone: confident, never playful; reassuring on errors

Aurora is for money and work apps where people need to trust what they see. Space and alignment do the work that decoration would do elsewhere.

Do:
- Lead every screen with one clear title and one primary action.
- Use sentence case for every label and title.
- Show real numbers with units ("$1,240.50", "3 tasks").

Don't:
- Use exclamation marks or emoji in UI copy.
- Put two primary buttons side by side.

## Colors

| Token | Light | Dark | Usage |
|---|---|---|---|
| primary | #4F46E5 | #818CF8 | Primary actions, links, focus, active nav |
| onPrimary | #FFFFFF | #1E1B4B | Text and icons on primary |
| secondary | #E0E7FF | #312E81 | Secondary buttons, selected chips |
| onSecondary | #312E81 | #E0E7FF | Text on secondary |
| background | #F7F8FC | #0B0D17 | Page background |
| surface | #FFFFFF | #151827 | Cards, sheets, app bars, inputs |
| surfaceVariant | #EEF0F7 | #1F2335 | Placeholders, skeletons, subtle fills |
| onSurface | #111827 | #F3F4F6 | Primary text |
| onSurfaceVariant | #5B6275 | #A1A7BB | Secondary text, captions, inactive icons |
| outline | #E2E5EE | #2C3147 | Borders, dividers |
| error | #DC2626 | #F87171 | Errors, destructive actions |
| onError | #FFFFFF | #450A0A | Text on error |
| success | #059669 | #34D399 | Positive values, success banners |
| warning | #D97706 | #FBBF24 | Warnings |

## Typography

| Token | Family | Size | Weight | Line height | Letter spacing | Case | Usage |
|---|---|---|---|---|---|---|---|
| display | Manrope | 40 | 800 | 1.1 | -1 | - | Hero numbers and landing titles |
| headline | Manrope | 28 | 700 | 1.2 | -0.5 | - | Screen titles on desktop |
| title | Manrope | 20 | 700 | 1.3 | -0.2 | - | Screen titles on mobile, card titles |
| subtitle | Inter | 16 | 600 | 1.4 | 0 | - | List row titles, section titles |
| body | Inter | 15 | 400 | 1.5 | 0 | - | Paragraphs and descriptions |
| label | Inter | 14 | 600 | 1.2 | 0.1 | - | Buttons, tabs, chips, field labels |
| caption | Inter | 12 | 500 | 1.4 | 0.2 | - | Metadata, helper text, timestamps |

## Spacing

| Token | Value |
|---|---|
| xxs | 2 |
| xs | 4 |
| sm | 8 |
| md | 16 |
| lg | 24 |
| xl | 32 |
| xxl | 48 |

## Radius

| Token | Value |
|---|---|
| none | 0 |
| sm | 8 |
| md | 12 |
| lg | 16 |
| pill | 999 |

## Elevation

| Token | Shadow |
|---|---|
| flat | none |
| low | 0 1 2 0 #111827/6, 0 1 3 0 #111827/10 |
| medium | 0 4 12 -2 #111827/10 |
| high | 0 12 32 -4 #111827/16 |

## Components

### Button

Height: 48
Radius: md
Padding x: lg
Text: label
Icon size: 18

| Variant | Fill | Text | Border |
|---|---|---|---|
| primary | primary | onPrimary | none |
| secondary | secondary | onSecondary | none |
| outline | surface | onSurface | outline |
| ghost | none | primary | none |
| destructive | error | onError | none |

Rules:
- One primary button per section; the rest are secondary, outline or ghost.
- Full width on mobile in forms and empty states; hug content on desktop.

Do:
- Start labels with a verb ("Pay invoice", "Add task").

Don't:
- Use ghost buttons for the main action of a screen.

### Card

Fill: surface
Border: outline
Radius: lg
Padding: md
Gap: sm
Shadow: low

Rules:
- Cards group one subject. Don't nest cards.

### List row

Min height: 56
Padding x: md
Padding y: sm
Gap: md
Title: subtitle
Subtitle: caption
Leading size: 40
Icon color: onSurfaceVariant
Divider: yes

Rules:
- A row that opens something ends with a chevron.

### Input

Height: 48
Fill: surface
Border: outline
Focus border: primary
Radius: md
Padding x: md
Text: body
Label: label
Label color: onSurface
Hint color: onSurfaceVariant

Rules:
- Every field has a visible label above it, never only a placeholder.

### App bar

Height: 64
Fill: surface
Title: title
Icon color: onSurface
Border: outline
Align: start

### Nav bar

Mobile: bottom
Desktop: rail
Fill: surface
Active: primary
Inactive: onSurfaceVariant
Height: 64
Width: 88

### Chip

Fill: surfaceVariant
Text: onSurface
Selected fill: secondary
Selected text: onSecondary
Radius: pill
Height: 32
Text style: label

### Badge

Fill: secondary
Text: onSecondary
Radius: pill
Text style: caption

### Avatar

Size: 40
Radius: pill

### Banner

Radius: md
Padding: md

| Tone | Fill | Text |
|---|---|---|
| info | secondary | onSecondary |
| success | success | onPrimary |
| warning | warning | onPrimary |
| error | error | onError |

### Switch

Active: primary
Inactive: outline

### Divider

Color: outline
Thickness: 1

## Layout

| Breakpoint | Min width | Columns | Margin | Gutter | Max content |
|---|---|---|---|---|---|
| mobile | 0 | 4 | md | md | 600 |
| tablet | 600 | 8 | lg | md | 840 |
| desktop | 1024 | 12 | xl | lg | 1120 |

Section gap: lg
Section title: subtitle
Form width: 440
List detail: desktop splits 1:2 with the list on the left; mobile stacks
Dashboard: desktop puts stats in one row and charts in a 2-column grid; mobile stacks everything

Rules:
- Pin content to the top-left of its column; center only auth and empty states.
- Content never touches the screen edge: use the breakpoint margin.

## Motion

| Token | Duration | Curve | Usage |
|---|---|---|---|
| fast | 120ms | easeOut | Hover, press, toggles |
| standard | 220ms | easeInOut | Expanding, state changes |
| emphasized | 360ms | fastOutSlowIn | Screen transitions, sheets |

Rules:
- Motion explains a change of state; nothing loops for decoration.
- Screens slide in from the right on push and fade on replace.

## Imagery

Style: clean product shots and abstract gradients; no stock people
Radius: md
Placeholder: surfaceVariant
Hero aspect: 16:9
Cover aspect: 1:1

## Iconography

Set: Material Symbols
Style: outlined
Size: 24
Color: onSurfaceVariant

## Accessibility

Min contrast: 4.5
Min touch target: 48
Focus: 2px primary ring on every interactive element
Motion: respect reduce-motion; replace slides with fades

Rules:
- Every icon-only button has a label for screen readers.
- Never use color alone to show an error: add an icon or message.
