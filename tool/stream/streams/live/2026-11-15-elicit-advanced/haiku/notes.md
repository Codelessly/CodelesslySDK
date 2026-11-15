# Notes on the changing-parts forms

Convention used throughout: a bare `$name` is a value, and anything with an operator or call is quoted as an expression (`enabled:"$held > 0"`). Inside a string, `{expr}` shows a value.

1. **A value the card remembers**: a line of the form `$name = initial` at the top of the card, changed by a tap, e.g. `$step = 1` and `tap:"$step += 1"`. It felt natural because it reads like the initial state of the card and needs no extra declaration.

2. **A value worked out from others**: a line of the form `$name = expression` with no tap, e.g. `$total = $subtotal + $tax`, shown as `{total}`. It felt natural because it reads as a formula that stays true whenever its inputs change.

3. **What a tap or a choice does**: a `tap:"statement"` key on the control, or `change:"statement"` on a control that hands back a value (`value` is that value), e.g. `change:"$tiers[i].count = value"`. It felt natural because the action sits on the control it belongs to.

4. **Changing one record of a list**: a path into the list inside a loop, e.g. `for i, l in $lines` then `tap:"$lines[i].qty = $lines[i].qty + 1"`. It felt natural because the index names the one record without copying the list.

5. **A part shown only sometimes**: an `if:"expr"` key on the node, e.g. `Row between if:"l.qty == 0"`. It felt natural because it reads as a condition next to the thing it hides.

6. **A part repeated for each item of a list**: a `for i, x in $list` line with the repeated children indented under it, e.g. `for i, t in $tasks`. It felt natural because it mirrors the indentation rule the notation already has.

7. **Something that happens as time passes**: a `every:1s while:$running do:"statement"` key on the card, e.g. `Card every:1s while:$running do:"$secs = max(0, $secs - 1)"`. It felt natural as a sibling of the other keys and keeps the timer tied to the card that owns it.

Where I could not find a natural form:
- Derived values that depend on a list (sums, filters, sorts) use function calls (`sum`, `filter`, `sort`, `count`) that are not defined anywhere; a fixed set of list helpers would be needed.
- A conditional tone or color inside a key (`tone:"$right ? 'success' : 'danger'"`) mixes an expression into a word-valued key.
- Multi-step taps needed `;` separators in one attribute string; a block form for several statements would read better.
- A guard on a tap (`when cond: statement`) is invented and not in the notation.
- Per-control state such as "this option is the right one" had no word for it, so the quiz card shows feedback as text rather than highlighting the choice.
