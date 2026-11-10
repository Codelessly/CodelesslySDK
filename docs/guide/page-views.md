# Runtime page views

A `pageView` repeats its first child as a page. Bind `data` to a list to
provide `${item}` and `${index}`, or set `props.itemCount` for counted pages.
The running app supports horizontal and vertical swipes, reverse direction,
viewport fractions, end padding, physics and page snapping. The design canvas
continues to show the pages around `initialPage` at rest.

Inside each page, `${pageOffset}` is the page's index minus the viewport's
fractional current page. It is zero for the centered page and changes during
a swipe, including without a `pageMotion`. Bind scenery transforms to this
value for parallax. `pageMotion` applies the same interpolated pose that the
design canvas shows, including rotation, perspective, scale and opacity.

Set or bind `props.initialPage` to navigate from a button or bookmark. Changes
jump by default; `props.animationDuration` (milliseconds) animates them using
`props.animationCurve` (`linear`, `easeIn`, `easeOut`, `easeInOut`, or default
`easeOutCubic`). The existing controller stays alive across those updates.

The pager fires `changed` with `${result.index}` and `${result.page}` when
the selected page changes. Save that index in a persisted bookmark variable.
The `scroll` trigger receives `${result.page}` (fractional) and
`${result.offset}` (pixels). These events belong to the pager; `${pageOffset}`
is local to each repeated page and does not overwrite app variables.
