"""What the render tool does to each card before its capture.

STEPS is the capture on the contact sheet (the card's main interaction driven); EXTRA are further states kept
under renders/states/<brief>-<label>.png. A node inside a block is named by the call's id and then the node's
own (`go/btn`); `#n` picks the n-th copy a list repeats.
"""
FORM = ['--type', 'name/field=Ada Lovelace', '--type', 'address/field=12 Analytical Street', '--type', 'city/field=London',
        '--type', 'zip/field=N1 9GU', '--type', 'email/field=ada@example.com', '--unfocus']

STEPS = {
    'approval': ['--tap', 'names/head'],
    'carousel': ['--drag', 'car/pages=-250,0', '--drag', 'car/pages=-250,0'],
    'comparison_wide': [],
    'gallery_strip': [],
    'gallery_pages': ['--drag', 'g/pages=-250,0'],
    'pages_content': ['--drag', 'pages=-250,0'],
    'table_wide': [],
    'checkout': ['--tap', 'line#0/stepPlus'],
    'code_diff': ['--tap', 'a/keep', '--tap', 'b/discard'],
    'comparison': [],
    'dashboard': ['--tap', 'head/h1'],
    'data_table': ['--tap', 'head/h3', '--tap', 'head/h3', '--tap', 'row#0/row', '--tap', 'row#2/row'],
    'flights': [],
    'image_gallery': [],
    'itinerary': ['--tap', 's1/head', '--tap', 'c1/item#0'],
    'map_list': ['--tap', 'map/p1'],
    'message_draft': [],
    'order_summary': ['--tap', 'line#1/stepPlus', '--type', 'promo/field=SAVE10', '--unfocus'],
    'plan_progress': ['--tap', 'go/btn', '--wait', '3000'],
    'question_flow': ['--tap', 'q1/opt#2'],
    'reservation': ['--tap', 'days/day#2', '--tap', 'party/stepPlus', '--tap', 'slots/chip#4'],
    'weather': [],
}

EXTRA = {
    'approval': {'approved': ['--tap', 'approve/btn'], 'denied': ['--tap', 'deny/btn']},
    'carousel': {'start': [], 'dot-tap': ['--tap', 'car/dotsHit#4'], 'arrow': ['--tap', 'car/next'],
                 'details': ['--tap', 'car/next', '--tap', 'car/tile#1/tile', '--tap', 'sizes/chip#2']},
    'comparison_wide': {'scrolled': ['--drag', 'table/scroller=-220,0'], 'chosen': ['--tap', 'table/fb1']},
    'gallery_strip': {'scrolled': ['--drag', 'g/strip=-260,0'], 'open': ['--tap', 'g/tile#1'], 'open-swiped': ['--tap', 'g/tile#1', '--drag', 'g/big=-250,0']},
    'gallery_pages': {'start': [], 'dot-tap': ['--tap', 'g/pdotsHit#3']},
    'pages_content': {'start': [], 'dot-tap': ['--tap', 'dots/dotsHit#2'], 'pager': ['--tap', 'pager/next', '--tap', 'pager/next', '--tap', 'pager/next']},
    'table_wide': {'scrolled': ['--drag', 'wide/scroller=-240,0']},
    'checkout': {'shipping-errors': ['--tap', 'next1/cta', '--tap', 'next2/btn'],
                 'payment': ['--tap', 'next1/cta', *FORM, '--tap', 'next2/btn', '--tap', 'ship/opt#1'],
                 'done': ['--tap', 'next1/cta', *FORM, '--tap', 'next2/btn', '--tap', 'pay/cta']},
    'code_diff': {'decided': ['--tap', 'a/keep', '--tap', 'b/discard', '--tap', 'c/keep']},
    'comparison': {'chosen': ['--tap', 'table/fb1']},
    'dashboard': {'90-days': ['--tap', 'range/cell2', '--tap', 'head/h3']},
    'data_table': {'overdue': ['--tap', 'status/cell3','--tap', 'head/tickBox'],
                   'search': ['--type', 'search/field=co', '--unfocus'], 'page-2': ['--tap', 'pager/next']},
    'flights': {'second': ['--tap', 'opt#1/card']},
    'image_gallery': {'open': ['--tap', 'g/cell#4', '--tap', 'g/next'], 'open-swiped': ['--tap', 'g/cell#4', '--drag', 'g/big=-250,0'],
                      'open-dot': ['--tap', 'g/cell#4', '--tap', 'g/vdotsHit#0']},
    'message_draft': {'firm': ['--tap', 'tone/cell1'], 'sent': ['--tap', 'send/btn']},
    'order_summary': {'confirmed': ['--tap', 'line#0/stepMinus', '--tap', 'confirm/cta'], 'cancelled': ['--tap', 'cancel/btn']},
    'plan_progress': {'done': ['--tap', 'go/btn', '--wait', '13000'], 'ready': []},
    'question_flow': {'result': ['--tap', 'q1/opt#2', '--tap', 'q2/opt#0', '--tap', 'q3/opt#1']},
    'reservation': {'booked': ['--tap', 'days/day#2', '--tap', 'party/stepPlus', '--tap', 'slots/chip#4', '--tap', 'confirm/cta']},
    'weather': {'alert': ['--tap', 'alert/btn']},
}
