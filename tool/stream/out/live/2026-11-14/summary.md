| Cell | Prompt+tools tok | TTFT ms | First paint ms | First text ms | Complete ms | Out tok | tok/s | Ops | Applied | Rejected | Recovered | Lookups | Retries | Final errors | Final lints | Scripts | Works when used | Follow-up tok | Follow-up ms | In tok (uncached) | Cache read | Cache write |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| approval@claude-haiku-5-5.compact.r1 | 20530 | 576 | 1508 | 1810 | 6754 | 2055 | 334.5 | 18 | 18 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 322 | 20451 | 0 |
| approval@claude-sonnet-5-5.compact.r1 | 20530 | 1109 | 3762 | 4996 | 17368 | 3507 | 226.0 | 30 | 29 | 1 | 0 | - | 1 | - | - | 0 | - | - | - | 199 | 20451 | 0 |
| carousel@claude-haiku-5-5.compact.r1 | 20530 | 690 | 1350 | 4575 | 12584 | 3912 | 329.8 | 32 | 32 | 0 | 29 | - | 0 | - | - | 0 | - | - | - | 316 | 20451 | 0 |
| carousel@claude-sonnet-5-5.compact.r1 | 20530 | 1109 | 5100 | 5843 | 19942 | 3980 | 220.7 | 30 | 28 | 2 | 0 | node-pageView, lists-a-carousel-pages-and-pagination | 2 | - | empty_button dot | 0 | - | - | - | 193 | 20451 | 0 |
| checkout@claude-haiku-5-5.compact.r1 | 20775 | 572 | 3007 | 3007 | 17345 | 5832 | 348.4 | 46 | 46 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 331 | 0 | 20696 |
| checkout@claude-sonnet-5-5.compact.r1 | 20775 | 721 | 6784 | 6784 | 36313 | 7493 | 214.1 | 52 | 52 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 208 | 0 | 20696 |
| code_diff@claude-haiku-5-5.compact.r1 | 20530 | 537 | 1509 | 1767 | 11391 | 3807 | 351.8 | 32 | 32 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 324 | 20451 | 0 |
| code_diff@claude-sonnet-5-5.compact.r1 | 20530 | 1031 | 3962 | 4374 | 24673 | 4909 | 215.3 | 33 | 32 | 1 | 0 | - | 1 | - | - | 0 | - | - | - | 201 | 20451 | 0 |
| comparison@claude-haiku-5-5.compact.r1 | 20530 | 945 | 1890 | 2136 | 12910 | 4258 | 356.9 | 42 | 42 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 312 | 20451 | 0 |
| comparison@claude-sonnet-5-5.compact.r1 | 20530 | 1219 | 4292 | 4670 | 15436 | 2910 | 215.9 | 25 | 25 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 189 | 20451 | 0 |
| dashboard@claude-haiku-5-5.compact.r1 | 20530 | 823 | 1565 | 3447 | 11445 | 3554 | 335.7 | 31 | 29 | 2 | 0 | - | 2 | wrong_type /nodes/revChart/props/data, wrong_type /nodes/chanChart/props/values, dangling_child /nodes/card/children/4, dangling_child /nodes/card/children/6 | - | 0 | - | 409 | 1911 | 342 | 0 | 20451 |
| dashboard@claude-sonnet-5-5.compact.r1 | 20530 | 765 | - | - | 8415 | 542 | 64.4 | 0 | 0 | 0 | 0 | lineChart, barChart, node-segmentedButton, state-formula-functions, state-formula-functions-lists, lists-a-table-from-one-template | 2 | - | - | 0 | - | 1036 | 5660 | 21546 | 122706 | 20451 |
| data_table@claude-haiku-5-5.compact.r1 | 20530 | 482 | 3490 | 3748 | 11901 | 3843 | 337.4 | 30 | 30 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 328 | 20451 | 0 |
| data_table@claude-sonnet-5-5.compact.r1 | 20530 | 1446 | 8468 | 8872 | 24209 | 4802 | 213.3 | 27 | 26 | 1 | 0 | - | 1 | - | - | 0 | - | - | - | 205 | 20451 | 0 |
| image_gallery@claude-haiku-5-5.compact.r1 | 20530 | 402 | 1261 | 1261 | 7295 | 2224 | 323.7 | 17 | 14 | 3 | 0 | - | 2 | invalid_parent /ops/0/parent, unknown_id /ops/5/parent | - | 0 | - | - | - | 319 | 20451 | 0 |
| image_gallery@claude-sonnet-5-5.compact.r1 | 20530 | 1050 | 9159 | 9159 | 18081 | 3181 | 217.3 | 21 | 21 | 0 | 0 | keyDown | 2 | - | low_contrast cellCap | 0 | - | - | - | 1232 | 40902 | 0 |
| itinerary@claude-haiku-5-5.compact.r1 | 20530 | 493 | 1216 | 2032 | 19187 | 6334 | 339.4 | 47 | 47 | 0 | 0 | - | 0 | - | - | 0 | - | 118 | 783 | 313 | 20451 | 0 |
| itinerary@claude-sonnet-5-5.compact.r1 | 20530 | 697 | 9519 | 10335 | 20563 | 3501 | 181.1 | 25 | 25 | 0 | 0 | - | 0 | - | - | 0 | - | 1183 | 6394 | 190 | 20451 | 0 |
| map_list@claude-haiku-5-5.compact.r1 | 20530 | 716 | 3169 | 8407 | 10222 | 3273 | 345.5 | 24 | 24 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 322 | 20451 | 0 |
| map_list@claude-sonnet-5-5.compact.r1 | 20530 | 998 | 4461 | 4929 | 9339 | 1675 | 219.6 | 13 | 12 | 1 | 10 | ui_read | 2 | - | - | 0 | - | - | - | 199 | 20451 | 0 |
| message_draft@claude-haiku-5-5.compact.r1 | 20530 | 443 | 2427 | 2693 | 6457 | 2058 | 344.0 | 13 | 13 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 332 | 20451 | 0 |
| message_draft@claude-sonnet-5-5.compact.r1 | 20530 | 1233 | 4058 | 5700 | 18623 | 3616 | 217.6 | 22 | 21 | 1 | 10 | ui_read | 1 | - | - | 0 | - | - | - | 209 | 20451 | 0 |
| order_summary@claude-haiku-5-5.compact.r1 | 20530 | 628 | 2652 | 2918 | 13122 | 4308 | 345.7 | 37 | 36 | 1 | 0 | - | 2 | - | - | 0 | - | 688 | 2410 | 331 | 20451 | 0 |
| order_summary@claude-sonnet-5-5.compact.r1 | 20530 | 915 | 4527 | 4988 | 21130 | 4161 | 209.4 | 35 | 34 | 1 | 0 | - | 1 | - | - | 0 | - | 1037 | 5722 | 208 | 20451 | 0 |
| plan_progress@claude-haiku-5-5.compact.r1 | 20530 | 524 | 1545 | 1812 | 8780 | 2824 | 344.1 | 31 | 30 | 1 | 0 | - | 1 | - | - | 0 | - | - | - | 319 | 20451 | 0 |
| plan_progress@claude-sonnet-5-5.compact.r1 | 20530 | 1121 | 7473 | 8373 | 18837 | 3206 | 213.3 | 24 | 23 | 1 | 0 | timer | 1 | - | - | 0 | - | - | - | 1174 | 40902 | 0 |
| question_flow@claude-haiku-5-5.compact.r1 | 20530 | 704 | 1544 | 2423 | 5293 | 1527 | 334.9 | 12 | 12 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 304 | 20451 | 0 |
| question_flow@claude-sonnet-5-5.compact.r1 | 20530 | 708 | 6760 | 8677 | 23654 | 4660 | 208.0 | 35 | 34 | 1 | 0 | - | 1 | - | - | 0 | - | - | - | 181 | 20451 | 0 |
| reservation@claude-haiku-5-5.compact.r1 | 20530 | 459 | - | - | 12620 | 4346 | 358.3 | 24 | 3 | 21 | 0 | - | 1 | - | - | 0 | - | 598 | 2180 | 313 | 20451 | 0 |
| reservation@claude-sonnet-5-5.compact.r1 | 20530 | 760 | 2380 | 2842 | 15520 | 3043 | 214.2 | 19 | 18 | 1 | 0 | - | 1 | - | - | 0 | - | 471 | 2892 | 190 | 20451 | 0 |

Times are from the request (TTFT, complete: the API stream; first paint and first text: the replay of the generation on its recorded clock). Lookups are ui_docs topics (or ui_read) before ui_apply, in the generation and its retries. "Works when used": the scripted interaction of tool/stream/interactions/<ui>.json on the final UI.
