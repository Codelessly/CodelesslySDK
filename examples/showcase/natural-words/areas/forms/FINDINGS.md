# Forms and validation: findings

10 requests (see requests.json). Default width (420). The first run hit HTTP 429 from the API; the script was rerun and resumed, and all 20 answers were produced.

## Rejected

From issues.txt (expander) and render.txt (renderer).

| Form Sonnet wrote | Answers | Reported | What Sonnet meant |
|---|---|---|---|
| `DatePicker "Date" =date value:"2026-11-21" min:"2026-11-01" max:"2026-11-30" {"props": {"inline": true}}` (booking_datetime line 7) | 1 | expander: `line 7:1: A datePicker has no text of its own.` and `line 7:21: A DatePicker has no value to bind with =. Bind a prop: key:=expression.`; renderer: `A datePicker has no prop "min"`, `no prop "max"`, `no prop "inline"` (props are `value, firstDate, lastDate, enabled, format, ...`) | A labelled date field bound two-way to `date`, limited to November, shown as an always-open month calendar. |
| `Input "Current password" type:password =currentPw` (and the two other password inputs) | 1 answer (disabled_until_valid), 3 lines | renderer: `the text "password" is not a TextInputType ... Did you mean "visiblePassword"?` | A masked password field. `type:` maps to keyboardType, not to obscureText. |
| `Input "Password" "At least 8 characters" type:password =password` (signup_card) | 1 | Not reported. In site/signup_card.json it expanded to `"props.keyboardType": "${password}"`: `type:password` was read as a binding to the state variable named `password`. Same for Confirm password. | A masked password field. Rendered as plain text ("Lumen2024" visible). |
| `Input "Password" =password type:=show?"text":"password"` (login_card) | 1 | Not reported; expanded to `"props.keyboardType": "${= show?\"text\":\"password\"}"`. | Show/hide password toggle. No obscureText produced either way. |
| `IconButton "star" color:=rating>=1?"#FFF5B301":"#FFCCCCCC" -> rating=1` (x5) | 1 (rating_feedback) | renderer: `A iconButton has no prop "color". Its props: icon, enabled, style, autofocus, loading.` | Star rating input: stars 1..rating filled amber, rest grey. All five render dark grey. |
| `Input "Comment (optional)" ... =comment {"props": {"multiline": true, "minLines": 3}}` | 1 | renderer: `A textField has no prop "multiline".` | A textarea. (minLines was accepted; the field did render tall.) |
| `Input "Email" ... type:email =email border:=submitted&&trim(email)==""?"#FFD32F2F":"#FFBDBDBD"` and same on Confirm password | 1 (signup_card), 2 lines | renderer WARNING: `A textField has no box decoration: strokes is ignored` | Red border on the invalid field after submit. Borders stay grey. |

## Words it wanted

Counts are lines in natural/ across the 10 answers (files in parentheses).

| Natural word(s) | How often | What it did with the notation |
|---|---|---|
| `required:` | 17 lines (5 files) | Left out. No required marker anywhere in notation/. |
| `autocomplete:` | 19 lines (5 files) | Left out. |
| `Form` / `form` (with `on-submit`, `validation:failed`, `state:submitted`) | 8 lines (7 files) | Left out the container; faked submitted state with `state submitted=true` + `visible:=` on error texts (signup_card). |
| `ErrorText` / `error` / `hint ... style:error` / `HelperText ... color:red`, field `state:error` | about 10 lines (6 files) | Used `Text.danger` under the input, inside `if` or with `visible:=`. Field error state (red border, `aria-invalid`) left out or tried via `border:` (ignored). |
| `type:password`, `PasswordField`, `showToggle:true`, `toggle-visibility` | toggle words 6 lines (3 files); PasswordField 3 | Wrote `type:password`, which does not mask (see Rejected). Show/hide became a separate `Toggle "Show password"` row (login_card); trailing eye icon left out. |
| `StrengthMeter` with `Segment`s, `level:fair` | 1 file | Faked with `Progress value:=` and a computed text label. |
| `stepper` with `step state:done/current/upcoming`, `connector` | 1 file (multistep) | Faked from 4 `Box` circles with `fill:=`, `Icon "check" visible:=`, plus a `Progress` bar. No connectors. |
| `stepper value:4 min:1 max:12` (number stepper) | 1 file (booking) | Faked: `Button.outline "-"`, `Text`, `Button.outline "+"`. |
| `date-picker` with full month grid (`week-row`, `day`), `calendar-header` | 1 file, 35 `day` lines | `DatePicker` field (rejected forms above); no inline calendar. |
| `chip-row selection:single`, `ChipGroup selection:multiple` | 2 files | Separate `ChoiceChip`/`FilterChip` lines with hand-written `selected:=` and toggle expressions. |
| `RatingInput max:5 value:4` with `Star` | 1 file | Faked with 5 `IconButton "star"` + `color:=` (rejected). |
| `Textarea rows:4 resize:vertical` | 2 files | `Input` with raw `{"props": {"multiline": true, "minLines": 3}}` (multiline rejected) or `{"minLines": 4, "maxLines": 6}`. |
| `maxlength` / `counter "0/160"` | 9 lines (4 files) | `maxLength:160` on Input plus its own `Text.caption "{length(bio)}/160"`; the counter then shows twice. |
| `DropZone accept:"application/pdf"` with `dragover` state | 1 file | `Box ... drop:file -> emit coverLetter`. Accepted; no accept filter or drag-over state. |
| `Checklist` / `ChecklistItem status:met` / `Rule when:` | 9 lines (1 file) | Faked: per rule two `Icon` lines with opposite `visible:=` and a `Text.small` with `color:=`. |
| `banner kind:error role:alert` | 1 file | `Box fill:#FFFDECEA` + `Icon "error"` + `Text`, inside `if failed`. |
| `link` / `Link` | 6 lines (3 files) | `Button.tertiary "Forgot password?"` (renders as a grey pill) or `Text.strong "browse" color:...`. Terms links in signup left as plain checkbox text. |
| `depends-on:`, `enabled-when:`, `disabled-when:`, `on-change: reset(...)` | 3 + 5 lines (4 files) | Expressed with `items:=make=="Toyota"?[...]:[]`, `enabled:=`, `-> model=""; trim=""`. Works; no word needed. |
| `shake` motion on error | 5 lines (4 files) | Left out, except one `animate:shake` on the login banner Box (accepted; motion not checked). |
| `state:loading` / spinner on submit buttons | several files | Left out. |

Words with a counterpart (not missing): `placeholder:` (21 lines, became the second quoted string on `Input`), `Dropdown`/`Option` (became `Select items:[...]`), `ProgressBar` (became `Progress`), `keyboard:`/`inputmode:` (became `type:number|email|phone`).

## Looks wrong

- signup_card: password and confirm password show in plain text ("Lumen2024", "Lumen2025"); invalid Email and Confirm fields keep grey borders (only the red text under them shows the error). The top edge of the card is cut off in this and every other card picture (not checked whether that is the crop or the layout).
- login_card: the show/hide control is a separate toggle row under the field, not an eye icon in the field; "Forgot password?" is a grey filled pill, not a link.
- payment_form: the VISA badge sits outside the card number field to the right and higher than the field's center; the Expiry field is empty while "Card expired" shows under it.
- multistep_onboarding: the "0/160" counter appears twice (the field's own counter and Sonnet's caption); Job title select has no label above it (only the hint inside); no lines connect the step circles.
- booking_datetime: the date is a collapsed field showing "2026-11-21", not the November month calendar asked for; "Osteria Nonna" is small for a heading.
- rating_feedback: all five stars are the same dark grey and small; the 4 filled stars do not show.
- shipping_address: the State select has no "State" label above it (shows "CA" alone).
- disabled_until_valid: current and new password show in plain text ("oldpass1", "secret123"). The disabled button itself looks right.

## Looks right

- dependent_dropdowns (Trim's disabled state is not visible because it is enabled in this state, as asked).
- file_upload (Full name shows "Maria Lopez" as a grey placeholder rather than a filled value; otherwise clean).

## Counts

- Requests: 10
- Answers that expanded with no issue: 9 of 10 (booking_datetime had 2 issues)
- Renders with no error: 7 of 10 (errors in booking_datetime, disabled_until_valid, rating_feedback; signup_card has 2 warnings only)
