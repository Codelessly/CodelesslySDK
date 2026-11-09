## 20.0.2

- `storage.<key>` in expressions reads what the app keeps on the device (`setStorage`), live. It read null.
- A list whose item updates rebuild nested lists no longer throws a concurrent modification.

## 20.0.1

- App variables: the publish model's variables (and a converted v1 publish's `app_variables`) are shared by every
  screen. 20.0.0 never declared them, so a screen reading one read null.

## 20.0.0

- The new format (`"schema": 2`), from the v2 rewrite. Projects made with the v1 editor are converted to it; a
  converted project can't be read by 10.x or older, and an unconverted one can't be read by 20.
