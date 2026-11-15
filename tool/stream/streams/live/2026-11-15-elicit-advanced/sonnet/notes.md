# Notes (sonnet)

1. Remembered value: `state name = initial` lines at the top of the card, before the root node, e.g. `state qty = 1`, `state tasks = [{"id":1,...}]`. It reads like declaring a variable; the initial value sits right there and `{name}` in strings already matches the notation.

2. Worked out from others: `let name = expression` lines, e.g. `let total = subtotal + tax`, `let valid = amount != null and amount >= 0`. Distinguishes "derived, never assigned" from `state`; ordinary arithmetic, ternary `a ? b : c`, and small helpers (`sum`, `count`, `trim`, `contains`, `format`, `pad`).

3. Tap or choice: an indented child line under the node, `onPressed: stmt; stmt` or `onChanged: x = value` (`value` is what the control reports). The component list already says "tells you when: pressed/changed", so naming the event and giving a short assignment felt direct. `if c then a = b` for a conditional step.

4. Changing one record of a list: reassign the list with map/filter/append, e.g. `tasks = tasks.map(x => x.id == t.id ? {...x, "done": value} : x)`, `tasks = tasks.filter(x => x.id != t.id)`, `tasks = tasks + [{...}]`. Inside a `for` loop I also allowed the shorthand `item.qty = value` meaning "update this loop item" (used in cart_lines), which is shorter but is a slightly different form than the explicit map.

5. Part shown only sometimes: `if cond` as its own line with the children indented beneath, plus an `else` line at the same indent. `if confirmed` / `else` can also swap whole cards at the root.

6. Part repeated per item: `for item in items` line with the template indented beneath; `{item.name}` and `item.price` used inside. Reads like a loop.

7. Time passing: `every 1s when running` as a top-level line with the actions indented beneath, e.g. `remaining = remaining - 1`. The interval plus a guard condition felt like a timer that is only live while the guard holds.

Things I could not find a natural form for:
- Component props that are expressions vs. literals (`value:picked`, `enabled:count > 0`, `max:standing + (6 - count)`): I wrote bare expressions and strings with `{}` and `${}` interpolation, but there is no marker to tell an expression from a literal.
- Two-way binding: I wrote value:x plus an explicit onChanged assignment every time; a shorthand such as `bind:x` would have been natural.
- `Undo` restoring the previous quantity rather than a fixed 1 (needs remembering a previous value per item).
- Sorting toggle that cycles none / ascending / descending; I used a nullable state and a ternary, which is clumsy.
- Where `state`/`let`/`every` declarations sit relative to the root card (I put them above it).
- Money formatting (`${format(x, 2)}` vs `${x}`) was left inconsistent in spirit; no formatting form exists.
- Disabling a single option or computing a counter's max from the rest of the pool (seat_limit) is awkward as an expression.
