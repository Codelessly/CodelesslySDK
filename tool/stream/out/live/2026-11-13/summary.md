| Cell | Prompt+tools tok | TTFT ms | First paint ms | First text ms | Complete ms | Out tok | tok/s | Ops | Applied | Rejected | Recovered | Lookups | Retries | Final errors | Final lints | Scripts | Works when used | Follow-up tok | Follow-up ms | In tok (uncached) | Cache read | Cache write |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| basketball@claude-haiku-5-5.compact.r1 | 7864 | 409 | 2581 | 2581 | 6945 | 2188 | 336.4 | 18 | 18 | 0 | 15 | - | 0 | - | - | 0 | False | - | - | 309 | 7785 | 0 |
| basketball@claude-opus-5-5.compact.r1 | 7864 | 654 | 38859 | 40310 | 61721 | 7368 | 214.9 | 29 | 28 | 1 | 0 | drag, scripts | 1 | - | - | 5 | False | - | - | 2705 | 23358 | 0 |
| basketball@claude-sonnet-5-5.compact.r1 | 7864 | 845 | - | - | 23020 | 4117 | 209.7 | 21 | 19 | 2 | 0 | drag | 2 | - | - | 1 | False | - | - | 1146 | 15570 | 0 |
| basketball@claude-sonnet-5-5.compact.scripts-off.r1 | 7626 | 1647 | - | - | 26477 | 3892 | 182.5 | 21 | 19 | 2 | 0 | drag, conditions | 2 | - | - | 0 | True | - | - | 1142 | 15094 | 0 |
| flights@claude-haiku-5-5.compact.r1 | 7630 | 530 | 2024 | 2555 | 7906 | 2567 | 349.5 | 23 | 23 | 0 | 0 | - | 0 | - | - | 0 | True | 368 | 1374 | 315 | 0 | 7551 |
| flights@claude-haiku-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-opus-5-5.compact.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-opus-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-sonnet-5-5.compact.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-sonnet-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| form_builder@claude-haiku-5-5.compact.r1 | 7864 | 521 | 1765 | 1765 | 6720 | 2149 | 348.2 | 20 | 18 | 2 | 0 | - | 0 | unknown_prop /nodes/fieldsList/props/padding, unknown_prop /nodes/preview/props/padding, dangling_child /nodes/main/children/3, dangling_child /nodes/main/children/5 | - | 0 | False | - | - | 326 | 0 | 7785 |
| form_builder@claude-opus-5-5.compact.r1 | 7864 | 5111 | 30296 | 30296 | 71412 | 8848 | 176.2 | 49 | 47 | 2 | 0 | scripts | 1 | - | - | 7 | False | - | - | 1516 | 7786 | 7786 |
| form_builder@claude-sonnet-5-5.compact.r1 | 7864 | 992 | 7054 | 15758 | 26955 | 5369 | 211.8 | 38 | 23 | 15 | 0 | - | 1 | - | - | 6 | False | - | - | 203 | 0 | 7785 |
| habits@claude-haiku-5-5.compact.r1 | 7864 | 442 | 1959 | 1959 | 11099 | 3766 | 354.4 | 31 | 23 | 8 | 0 | - | 2 | - | - | 0 | False | - | - | 283 | 7785 | 0 |
| habits@claude-opus-5-5.compact.r1 | 7864 | 1174 | 11327 | 11931 | 42845 | 5569 | 168.9 | 42 | 42 | 0 | 0 | scripts | 0 | - | - | 2 | True | - | - | 1003 | 15572 | 0 |
| habits@claude-sonnet-5-5.compact.r1 | 7864 | 856 | 3084 | 3546 | 18948 | 3812 | 218.0 | 29 | 28 | 1 | 0 | - | 2 | - | - | 0 | False | - | - | 160 | 7785 | 0 |
| kanban@claude-haiku-5-5.compact.r1 | 7864 | 455 | 1886 | 1886 | 9835 | 3328 | 356.4 | 24 | 20 | 4 | 16 | - | 1 | - | - | 0 | False | - | - | 287 | 7785 | 0 |
| kanban@claude-opus-5-5.compact.r1 | 7864 | 1354 | 10652 | 11256 | 30028 | 3584 | 174.5 | 22 | 19 | 3 | 0 | draggable, drop | 1 | - | - | 2 | False | - | - | 2127 | 23358 | 0 |
| kanban@claude-sonnet-5-5.compact.r1 | 7864 | 759 | 8813 | 9227 | 20918 | 3640 | 228.9 | 25 | 22 | 3 | 0 | draggable, dropTarget, drop, scripts | 1 | - | - | 2 | False | - | - | 5446 | 38925 | 0 |
| memory@claude-haiku-5-5.compact.r1 | 7864 | 501 | 2741 | 2741 | 6160 | 1750 | 349.6 | 13 | 10 | 3 | 0 | scripts | 3 | - | - | 0 | False | - | - | 1109 | 15570 | 0 |
| memory@claude-opus-5-5.compact.r1 | 7864 | 611 | 16124 | 17475 | 26076 | 3343 | 176.1 | 16 | 16 | 0 | 0 | scripts | 0 | - | - | 3 | True | - | - | 918 | 15572 | 0 |
| memory@claude-sonnet-5-5.compact.r1 | 7864 | 1454 | - | - | 19899 | 2966 | 203.5 | 18 | 16 | 2 | 0 | scripts | 1 | - | - | 4 | True | - | - | 891 | 15570 | 0 |
| restaurant_menu@claude-haiku-5-5.compact.r1 | 7628 | 477 | 1900 | 1900 | 15635 | 5082 | 336.0 | 46 | 46 | 0 | 0 | - | 0 | - | - | 0 | - | - | - | 347 | 0 | 7549 |
| restaurant_menu@claude-sonnet-5-5.compact.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| saas_pricing@claude-haiku-5-5.compact.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| saas_pricing@claude-sonnet-5-5.compact.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| sudoku@claude-haiku-5-5.compact.r1 | 7864 | 380 | 3832 | 3832 | 8216 | 2515 | 322.3 | 23 | 23 | 0 | 16 | - | 0 | - | - | 0 | False | - | - | 326 | 7785 | 0 |
| sudoku@claude-opus-5-5.compact.r1 | 7864 | 487 | 39247 | 39247 | 54792 | 6814 | 203.0 | 22 | 21 | 1 | 0 | scripts, timer | 3 | - | - | 6 | False | - | - | 2525 | 23358 | 0 |
| sudoku@claude-sonnet-5-5.compact.r1 | 7864 | 1130 | 15159 | 16146 | 29019 | 4414 | 188.2 | 20 | 17 | 3 | 0 | scripts, timer | 1 | - | - | 4 | False | - | - | 2490 | 23355 | 0 |
| sudoku@claude-sonnet-5-5.compact.scripts-off.r1 | 7626 | 1243 | - | - | 9586 | 574 | 59.9 | 0 | 0 | 0 | 0 | scripts, variables, timer, lists, setValue, formula functions +2 | 3 | wrong_type /nodes/cellNum/bind/decoration.fills[0].color | - | 0 | False | - | - | 18521 | 45282 | 7547 |
| weather@claude-haiku-5-5.compact.r1 | 7630 | 1646 | 2262 | 2873 | 15578 | 5120 | 367.7 | 57 | 57 | 0 | 0 | - | 0 | - | - | 0 | True | 264 | 3222 | 293 | 7551 | 0 |
| weather@claude-haiku-5-5.full.r1 | 34262 | 983 | 2633 | 2633 | 17123 | 5710 | 354.3 | 58 | 56 | 2 | 0 | - | 2 | - | - | 0 | True | 141 | 1036 | 293 | 0 | 34183 |
| weather@claude-opus-5-5.compact.r1 | 7630 | 2107 | 4151 | 5955 | 23361 | 3136 | 148.2 | 29 | 29 | 0 | 16 | - | 0 | - | - | 0 | True | 471 | 4634 | 170 | 0 | 7552 |
| weather@claude-opus-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| weather@claude-sonnet-5-5.compact.r1 | 7630 | 1033 | 4779 | 6051 | 16790 | 3165 | 211.8 | 29 | 29 | 0 | 0 | - | 0 | - | - | 0 | True | 269 | 2504 | 170 | 0 | 7551 |
| weather@claude-sonnet-5-5.full.r1 | 34262 | 882 | 2795 | 4036 | 27424 | 5639 | 213.9 | 63 | 63 | 0 | 0 | - | 0 | - | - | 0 | True | 963 | 5475 | 170 | 0 | 34183 |

Times are from the request (TTFT, complete: the API stream; first paint and first text: the replay of the generation on its recorded clock). Lookups are ui_docs topics (or ui_read) before ui_apply, in the generation and its retries. "Works when used": the scripted interaction of tool/stream/interactions/<ui>.json on the final UI.
