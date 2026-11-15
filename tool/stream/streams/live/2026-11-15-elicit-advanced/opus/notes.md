# How I wrote the changing parts

General rule I settled on: braces mean code. `{expr}` inside a string interpolates (as the notation already does), and `key:{expr}` binds a prop to an expression or a handler. Expressions are JS-like (`? :`, `&&`, arrow functions, `.sum`, `.filter`).

1. **A value the card remembers**
   `state qty = 1` / `state items = [{"name":"Ceramic mug","price":18,"qty":1}]`
   One line per value, the first children of the card, like a variable declaration. `state` is the word UI people already use, and JSON for initial records matches the notation's own lists.

2. **A value worked out from others**
   `derived total = subtotal + tax` / `derived left = tasks.count(t => !t.done)`
   Same shape as `state` so the two read as a pair, but a different keyword makes clear it is never assigned.

3. **What a tap or a choice does**
   `Button "Add" onPressed:{tasks.add({...}); draft = ""}` / `Segments ... value:{tip} onChanged:{tip = value}`
   The component list already says "It tells you when: pressed/changed", so `on` + that event name was the obvious key; the body is statements in braces, `;`-separated, with `value` as the new value. A bound prop is `enabled:{count > 0}`.

4. **Changing one record of a list**
   `for item in items` ... `CartLine ... qty:{item.qty} onChanged:{item.qty = max(value, 0)}`; removing is `tasks.remove(task)`, adding `tasks.add({...})`.
   Inside a loop the loop variable *is* the record, so assigning to its field felt more natural than indexing `items[i].qty`.

5. **A part shown only sometimes**
   ```
   if doneCount > 0
     Button.ghost "Clear completed" ...
   else
     ...
   ```
   A structural line with the shown nodes indented under it, like any other child. Reads like the sentence in the brief and handles `else` cleanly, which a `hidden:{...}` prop would not.

6. **A part repeated for each item of a list**
   ```
   for t in tickets
     Counter "{t.name}" "${t.price} each" value:{t.qty} ...
   ```
   Same structural-line shape as `if`, with the loop variable usable in strings and props below it.

7. **Something that happens as time passes**
   `every 1s while:{running} onTick:{remaining = remaining - 1; if (remaining == 0) { running = false }}`
   A non-visual line with a period, a condition, and an `on…` handler, so it is consistent with how taps are written; stopping is just the condition becoming false.

## What I wanted but found no natural form for
- **Formatting**: money and clock text. I wrote `"${total.toFixed(2)}"` and an assumed `pad2(...)` helper; a pipe like `{total | money}` or `{remaining | mm:ss}` would be nicer but I didn't want to invent a second mini-language.
- **Conditional style**: a done task should be struck through / muted. A variant (`Text.muted`) cannot be made conditional, so I fell back to `color:{task.done ? ... : ...}`.
- **Sort tap on TableHeader**: TableHeader only advertises `toggleAll`, so I hand-built the header row with a `Button.ghost "Amount ↑"` to get a tap for sorting.
- **Undo restoring the previous quantity**: I restore to 1; remembering the last quantity per record would need a hidden field (`item.prev`) that has no tidy form.
- **Per-record disabled state inside a component** (e.g. greying out quiz choices after answering): OptionList has no `disabled`, so the handler just ignores later picks.
- **Where the "else if" chain goes**: for the wizard steps I used three separate `if step == n` blocks rather than an `else if` form.
