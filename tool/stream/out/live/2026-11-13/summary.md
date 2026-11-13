| Cell | Prompt+tools tok | TTFT ms | First paint ms | First text ms | Complete ms | Out tok | tok/s | Ops | Applied | Rejected | Recovered | Lookups | Retries | Final errors | Final lints | Scripts | Works when used | Follow-up tok | Follow-up ms | In tok (uncached) | Cache read | Cache write |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flights@claude-haiku-5-5.compact.r1 | 7630 | 530 | 2024 | 2555 | 7906 | 2567 | 349.5 | 23 | 23 | 0 | 0 | - | 0 | - | - | 0 | True | 368 | 1374 | 315 | 0 | 7551 |
| flights@claude-haiku-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-opus-5-5.compact.r1 | 7630 | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-opus-5-5.full.r1 | 34262 | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-sonnet-5-5.compact.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| flights@claude-sonnet-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| weather@claude-haiku-5-5.compact.r1 | 7630 | 1646 | 2262 | 2873 | 15578 | 5120 | 367.7 | 57 | 57 | 0 | 0 | - | 0 | - | - | 0 | True | 264 | 3222 | 293 | 7551 | 0 |
| weather@claude-haiku-5-5.full.r1 | 34262 | 983 | 2633 | 2633 | 17123 | 5710 | 354.3 | 58 | 56 | 2 | 0 | - | 2 | - | - | 0 | True | 141 | 1036 | 293 | 0 | 34183 |
| weather@claude-opus-5-5.compact.r1 | 7630 | 2107 | 4151 | 5955 | 23361 | 3136 | 148.2 | 29 | 29 | 0 | 16 | - | 0 | - | - | 0 | True | 471 | 4634 | 170 | 0 | 7552 |
| weather@claude-opus-5-5.full.r1 | - | - | - | - | - | 0 | - | - | - | - | - | - | 0 | - | - | - | - | - | - | - | - | - |
| weather@claude-sonnet-5-5.compact.r1 | 7630 | 1033 | 4779 | 6051 | 16790 | 3165 | 211.8 | 29 | 29 | 0 | 0 | - | 0 | - | - | 0 | True | 269 | 2504 | 170 | 0 | 7551 |
| weather@claude-sonnet-5-5.full.r1 | 34262 | 882 | 2795 | 4036 | 27424 | 5639 | 213.9 | 63 | 63 | 0 | 0 | - | 0 | - | - | 0 | True | 963 | 5475 | 170 | 0 | 34183 |

Times are from the request (TTFT, complete: the API stream; first paint and first text: the replay of the generation on its recorded clock). Lookups are ui_docs topics (or ui_read) before ui_apply, in the generation and its retries. "Works when used": the scripted interaction of tool/stream/interactions/<ui>.json on the final UI.
