# The 16 requests, and the system message for the answers in natural/.
REQ = {
 'gauge_speed': 'An inline card with a speedometer gauge showing 72 km/h on a 0 to 180 scale, with the limit of 100 marked.',
 'dial_battery': 'An inline card with a battery dial at 64%, charging, and the time left to full.',
 'ring_goal': 'An inline card with a circular ring showing 7,240 of 10,000 steps with the percentage in the middle.',
 'knob_thermostat': 'An inline card with a thermostat: a round dial I can turn from 16 to 28 degrees, now 21, with the room name and a heat/cool switch.',
 'meter_storage': 'An inline card with a storage meter: 182 of 256 GB used, split into photos, apps and other, each a segment of the bar.',
 'countdown': 'An inline card with a countdown from 5 minutes that I can start, pause and reset, the time shown large.',
 'count_up': 'An inline card where the revenue figure counts up from 0 to $48,200 when the card appears.',
 'fill_bar': 'An inline card with an upload: a bar that fills smoothly as the percent goes up, then turns green with a check when done.',
 'pulse_button': 'An inline card with a record button that pulses while recording and shows the elapsed seconds.',
 'slide_rows': 'An inline card with a list of five notifications whose rows slide in one after another when the card appears.',
 'swipe_delete': 'An inline card with a to-do list where I can swipe a row left to delete it.',
 'reorder': 'An inline card with a playlist of six songs I can drag to reorder.',
 'sparkline': 'An inline card with three stocks, each a name, a price, a change in green or red, and a small sparkline.',
 'flip_card': 'An inline card with a flashcard that flips over when tapped to show the answer.',
 'skeleton': 'An inline card that shows shimmering placeholder rows for two seconds, then the three loaded articles.',
 'slider_tip': 'An inline card with a bill of $84.00, a tip slider from 0 to 30%, and the tip and total updating as I slide.',
}
NATURAL = ('You describe user interfaces as a compact indented outline: one element per line, children indented under their parent, '
           'each line an element name, then its text in quotes if it has one, then key:value properties. No JSON, no code, no explanation. '
           'There is no fixed vocabulary: use the element names, property names and values you find most natural and would expect a renderer to understand, '
           'including for state, behavior over time and motion.')
