| Stream | Size | Source | TTFT ms | First paint ms | First section ms | Complete ms | Output tokens | Ops applied / rejected | Re-applied boxes per op (min/med/p90/max) | Pumps > 16.7 ms | Render errors |
|---|---|---|---|---|---|---|---|---|---|---|---|
| flights@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 2653 | 3720 | 19328 | 2825~ | 45 / 0 | 0/0/6/9 | 0 of 1310 | 0 |
| flights@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 2653 | 3720 | 19328 | 2825~ | 45 / 0 | 0/0/6/9 | 10 of 1310 | 0 |
| flights@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 1300 | 1708 | 7561 | 2825~ | 45 / 0 | 0/0/6/9 | 2 of 1275 | 0 |
| flights@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 1300 | 1708 | 7561 | 2825~ | 45 / 0 | 0/0/6/9 | 15 of 1275 | 0 |
| flights@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 5833 | 8533 | 47571 | 2825~ | 45 / 0 | 0/0/6/9 | 2 of 1326 | 0 |
| flights@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 5833 | 8533 | 47571 | 2825~ | 45 / 0 | 0/0/6/9 | 9 of 1326 | 0 |
| flights_sort@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 607 | 607 | 608 | 17~ | 1 / 0 | 4/4/4/4 | 1 of 31 | 0 |
| flights_sort@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 607 | 607 | 608 | 17~ | 1 / 0 | 4/4/4/4 | 2 of 31 | 0 |
| restaurant_menu@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 4747 | 10087 | 86100 | 12840~ | 149 / 1 | 0/2/8/114 | 23 of 5354 | 0 |
| restaurant_menu@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 4747 | 10087 | 86100 | 12840~ | 149 / 1 | 0/1/7/113 | 30 of 5354 | 0 |
| restaurant_menu@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 2090 | 4098 | 32600 | 12840~ | 149 / 1 | 0/2/8/114 | 23 of 5292 | 0 |
| restaurant_menu@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 2090 | 4098 | 32600 | 12840~ | 149 / 1 | 0/1/7/113 | 34 of 5292 | 0 |
| restaurant_menu@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 11100 | 24483 | 214500 | 12840~ | 149 / 1 | 0/2/8/114 | 21 of 5280 | 0 |
| restaurant_menu@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 11100 | 24483 | 214500 | 12840~ | 149 / 1 | 0/1/7/113 | 31 of 5280 | 0 |
| saas_pricing@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 5133 | 9627 | 101527 | 15154~ | 202 / 0 | 0/1/15/51 | 31 of 6272 | 0 |
| saas_pricing@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 5133 | 9627 | 101527 | 15154~ | 202 / 0 | 0/1/14/51 | 57 of 6272 | 0 |
| saas_pricing@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 2240 | 3925 | 38385 | 15154~ | 202 / 0 | 0/1/15/51 | 38 of 6214 | 0 |
| saas_pricing@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 2240 | 3925 | 38385 | 15154~ | 202 / 0 | 0/1/14/51 | 59 of 6214 | 0 |
| saas_pricing@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 12100 | 23350 | 253067 | 15154~ | 202 / 0 | 0/1/15/51 | 39 of 6244 | 0 |
| saas_pricing@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 12100 | 23350 | 253067 | 15154~ | 202 / 0 | 0/1/14/51 | 52 of 6244 | 0 |
| weather@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 2580 | 3620 | 18445 | 2692~ | 55 / 0 | 0/2/6/13 | 3 of 1251 | 0 |
| weather@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 2580 | 3620 | 18445 | 2692~ | 55 / 0 | 0/2/6/13 | 8 of 1251 | 0 |
| weather@400tps.jsonl | 1440x900 | synthetic 400 tok/s | 500 | 1278 | 1670 | 7229 | 2692~ | 55 / 0 | 0/2/6/13 | 1 of 1206 | 0 |
| weather@400tps.jsonl | 390x844 | synthetic 400 tok/s | 500 | 1278 | 1670 | 7229 | 2692~ | 55 / 0 | 0/2/6/13 | 6 of 1206 | 0 |
| weather@60tps.jsonl | 1440x900 | synthetic 60 tok/s | 500 | 5717 | 8283 | 45363 | 2692~ | 55 / 0 | 0/2/6/13 | 2 of 1267 | 0 |
| weather@60tps.jsonl | 390x844 | synthetic 60 tok/s | 500 | 5717 | 8283 | 45363 | 2692~ | 55 / 0 | 0/2/6/13 | 7 of 1267 | 0 |
| weather_dark@150tps.jsonl | 1440x900 | synthetic 150 tok/s | 500 | 973 | 973 | 1538 | 156~ | 5 / 0 | 1/3/7/7 | 1 of 100 | 0 |
| weather_dark@150tps.jsonl | 390x844 | synthetic 150 tok/s | 500 | 973 | 973 | 1538 | 156~ | 5 / 0 | 1/3/7/7 | 3 of 100 | 0 |

~ estimated (characters / 4). Times are on the replay's virtual clock from the request: the stream file's delta times.
