# 名前付き引数の移行確認表

初回抽出の 534 候補のうち、編集を含む保留のない 334 候補を確認し、manifest の review を approved にしてハッシュ付きで適用した。以下の proposal・held は初回抽出時の分類である。保留は individual-manifest.json と final.diff で個別に解決し、最終の全入力の型検査と旧構文の残数は final-inventory.json で確認した。

| 分類 | 件数 |
|---|---:|
| held | 196 |
| proposal | 338 |

## proposal

| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |
|---|---|---|---|---|
| e40ff335f51c327e6ddf | tools/bench/programs/cycle.bnt:[183, 219] | call | ['xs', 'i'] |  |
| 29c00c97b2de195cf46e | tools/bench/programs/cycle.bnt:[809, 845] | call | ['reference', 'value'] |  |
| 9186821d978df8bd5b37 | tools/bench/programs/eval.bnt:[891, 920] | call | ['a', 'b'] |  |
| 01119ffe639dac104a6e | tools/bench/programs/eval.bnt:[1720, 1787] | call | ['expression', 'count', 'total'] |  |
| 81cdbb532496c4dd9b6b | tools/bench/programs/eval.bnt:[2049, 2095] | call | ['expression', 'count', 'total'] |  |
| c8ccbe2a95ab017847d6 | tools/bench/programs/handler.bnt:[183, 219] | call | ['xs', 'i'] |  |
| dc38e8a1aced3583624c | tools/bench/programs/handler.bnt:[795, 825] | call | ['count', 'value'] |  |
| 0e612fcf4abd7a312f96 | tools/bench/programs/handler.bnt:[907, 923] | call | ['count', 'value'] |  |
| 5e19349a7492397b890e | tools/bench/programs/handler.bnt:[1077, 1093] | call | ['count', 'value'] |  |
| 46fdde515b23229f3526 | tools/bench/programs/handler.bnt:[1750, 1797] | call | ['count', 'mode', 'rounds', 'total'] |  |
| 01de9744c39d91be7b53 | tools/bench/programs/handler.bnt:[1910, 1942] | call | ['xs', 'i'] |  |
| 2bc0a9e21915339ccea0 | tools/bench/programs/handler.bnt:[2373, 2405] | call | ['xs', 'i'] |  |
| 3b6ecb4ae578f7cb92cd | tools/bench/programs/handler.bnt:[2492, 2525] | call | ['count', 'mode', 'rounds', 'total'] |  |
| 8ab96e2e2f21cf32e425 | tools/bench/programs/handler.bnt:[2634, 2668] | call | ['count', 'mode', 'rounds', 'total'] |  |
| c45a48940997a4bdc5a9 | tools/bench/programs/http.bnt:[1430, 1604] | component | [] |  |
| 583198bd2437bdc7ff48 | tools/bench/programs/http.bnt:[1204, 1290] | component | ['acc', 'value'] |  |
| 63c26e7a8963badd143f | tools/bench/programs/http.bnt:[224, 260] | call | ['xs', 'i'] |  |
| 2cf0aa4959c72c5e76f1 | tools/bench/programs/http.bnt:[914, 956] | call | ['done', 'value'] |  |
| 392d73a78954c6877752 | tools/bench/programs/http.bnt:[1172, 1291] | call | ['xs', 'initial', 'f'] |  |
| 16f50b7a914389c8e01f | tools/bench/programs/http.bnt:[1407, 1605] | call | ['group', 'action'] |  |
| 57f956a8a6e81c5f9680 | tools/bench/programs/http.bnt:[1487, 1530] | call | ['exchange', 'response'] |  |
| 3e3c01a5c2b505d8ccf2 | tools/bench/programs/http.bnt:[1509, 1529] | call | ['status', 's'] |  |
| 5d2d283a1b812915b02f | tools/bench/programs/http.bnt:[1610, 1669] | call | ['listener', 'group', 'count', 'tasks'] |  |
| 8ca74df5cae31389f01e | tools/bench/programs/http.bnt:[1644, 1668] | call | ['xs', 'x'] |  |
| 978c7b541b0fbaff2ca8 | tools/bench/programs/http.bnt:[1884, 1911] | call | ['host', 'port'] |  |
| 97085c34a4f06b44a571 | tools/bench/programs/http.bnt:[2042, 2151] | call | ['group', 'action'] |  |
| 045a96e9fbc794b69a13 | tools/bench/programs/http.bnt:[2112, 2128] | call | ['done', 'value'] |  |
| d2a29399df74bbceaaf4 | tools/bench/programs/http.bnt:[2240, 2273] | call | ['listener', 'group', 'count', 'tasks'] |  |
| 030e848c1e3045f46e44 | tools/bench/programs/http.bnt:[2278, 2303] | call | ['reference', 'value'] |  |
| efda3b064d13dbf470ca | tools/bench/programs/list.bnt:[924, 965] | component | ['value'] |  |
| df4012be5e86558af6c9 | tools/bench/programs/list.bnt:[1010, 1075] | component | ['value'] |  |
| 0fbed42b42e0d9a67caf | tools/bench/programs/list.bnt:[1120, 1184] | component | ['acc', 'value'] |  |
| de6a298a1faa42e39569 | tools/bench/programs/list.bnt:[865, 885] | call | ['start', 'stop'] |  |
| 95f4bbbc7dd983e5d386 | tools/bench/programs/list.bnt:[907, 966] | call | ['xs', 'f'] |  |
| ea487b4c88b042e7abe5 | tools/bench/programs/list.bnt:[990, 1076] | call | ['xs', 'p'] |  |
| 328ebcacf95ed1f349ee | tools/bench/programs/list.bnt:[1031, 1060] | call | ['a', 'b'] |  |
| 4a03da1c2bbffe544769 | tools/bench/programs/list.bnt:[1097, 1185] | call | ['xs', 'initial', 'f'] |  |
| bc7aa131ea7ab71b2ccb | tools/bench/programs/listget.bnt:[183, 219] | call | ['xs', 'i'] |  |
| dd0482ea3e6340167efd | tools/bench/programs/listget.bnt:[938, 971] | call | ['xs', 'i'] |  |
| 004a2d73ac7e9383b290 | tools/bench/programs/listget.bnt:[1054, 1108] | call | ['values', 'length', 'count', 'seed', 'total'] |  |
| 6f89079731cb2d82c8be | tools/bench/programs/listget.bnt:[1555, 1576] | call | ['start', 'stop'] |  |
| 5aa6ef67c1d4d64442ee | tools/bench/programs/listget.bnt:[1622, 1657] | call | ['values', 'length', 'count', 'seed', 'total'] |  |
| 697752eedd7174128eb2 | tools/bench/programs/loop.bnt:[762, 806] | call | ['current', 'limit', 'total'] |  |
| 0956a2805aabde2946d5 | tools/bench/programs/loop.bnt:[1085, 1105] | call | ['current', 'limit', 'total'] |  |
| 409b67ca0c00e9ff91c5 | tools/bench/programs/map.bnt:[1142, 1199] | component | ['acc', 'value'] |  |
| a3d174ae79baead45bb5 | tools/bench/programs/map.bnt:[259, 307] | call | ['count', 'seed', 'values'] |  |
| c0bb094244fe214d2083 | tools/bench/programs/map.bnt:[281, 306] | call | ['xs', 'x'] |  |
| cdc411f22a5f4db13628 | tools/bench/programs/map.bnt:[493, 516] | call | ['xs', 'i'] |  |
| 5d55462fe66acf28366d | tools/bench/programs/map.bnt:[586, 655] | call | ['values', 'index', 'm', 's'] |  |
| 365666d9f94c8fbc29e8 | tools/bench/programs/map.bnt:[616, 634] | call | ['m', 'k'] |  |
| 6b340f0943e9aed64f23 | tools/bench/programs/map.bnt:[636, 654] | call | ['s', 'x'] |  |
| 44f052dd4ccf78979157 | tools/bench/programs/map.bnt:[777, 836] | call | ['o', 'f'] |  |
| 7a962eda23ff5fc46e57 | tools/bench/programs/map.bnt:[788, 820] | call | ['xs', 'i'] |  |
| 946e4118429319b7e317 | tools/bench/programs/map.bnt:[1076, 1094] | call | ['count', 'seed', 'values'] |  |
| c2ba793ad599ff80469b | tools/bench/programs/map.bnt:[1111, 1200] | call | ['xs', 'initial', 'f'] |  |
| 7f3208fe022650894048 | tools/bench/programs/map.bnt:[1166, 1188] | call | ['m', 'k', 'value'] |  |
| c674212e07061d90854a | tools/bench/programs/map.bnt:[1217, 1301] | call | ['xs', 'initial', 'f'] |  |
| ece3d031864159a450e8 | tools/bench/programs/map.bnt:[1272, 1289] | call | ['s', 'x'] |  |
| f53d06e54926494ccbeb | tools/bench/programs/map.bnt:[1325, 1513] | call | ['xs', 'initial', 'f'] |  |
| c88be9c4eb818bfcbca5 | tools/bench/programs/map.bnt:[1390, 1405] | call | ['m', 'k'] |  |
| ecef7e74f89c8546f5d6 | tools/bench/programs/map.bnt:[1537, 1644] | call | ['xs', 'initial', 'f'] |  |
| 96d07b049ae075c03f52 | tools/bench/programs/map.bnt:[1591, 1611] | call | ['s', 'x'] |  |
| 02714e5e4b7a8df82197 | tools/bench/programs/map.bnt:[1669, 1696] | call | ['values', 'index', 'm', 's'] |  |
| c0d24566633457df12d8 | tools/bench/programs/println.bnt:[824, 854] | call | ['current', 'limit'] |  |
| e360553cfc0efbeadf4d | tools/bench/programs/println.bnt:[1095, 1115] | call | ['current', 'limit'] |  |
| fe4ac6eb0169ed739747 | tools/bench/programs/string.bnt:[867, 893] | call | ['s', 'n'] |  |
| 7f5fc342155936939745 | tools/bench/programs/string.bnt:[994, 1017] | call | ['s', 'separator'] |  |
| f25028ed7943e0f9a28c | tools/bench/programs/tasks.bnt:[1159, 1235] | component | [] |  |
| 78136ee74695b7124f87 | tools/bench/programs/tasks.bnt:[2103, 2161] | component | ['acc', 'value'] |  |
| 0598b2c73351471e272b | tools/bench/programs/tasks.bnt:[183, 219] | call | ['xs', 'i'] |  |
| a3c0ef7052d3bd737f57 | tools/bench/programs/tasks.bnt:[719, 766] | call | ['count', 'value'] |  |
| 76a44429718a678adb85 | tools/bench/programs/tasks.bnt:[1136, 1236] | call | ['group', 'action'] |  |
| df7231b7eaea0626529d | tools/bench/programs/tasks.bnt:[1204, 1220] | call | ['count', 'value'] |  |
| 3417197e86c02b526407 | tools/bench/programs/tasks.bnt:[1241, 1307] | call | ['group', 'gate', 'count', 'work', 'tasks'] |  |
| a5682261432caad369d9 | tools/bench/programs/tasks.bnt:[1282, 1306] | call | ['xs', 'x'] |  |
| 9e5d30744dab726cae62 | tools/bench/programs/tasks.bnt:[1772, 1837] | call | ['group', 'action'] |  |
| 350e26aa42df57756ac4 | tools/bench/programs/tasks.bnt:[1862, 1902] | call | ['group', 'gate', 'count', 'work', 'tasks'] |  |
| f9257878e29e888ff9ba | tools/bench/programs/tasks.bnt:[2047, 2072] | call | ['reference', 'value'] |  |
| 539e4574ca4ac67cbfde | tools/bench/programs/tasks.bnt:[2083, 2162] | call | ['xs', 'initial', 'f'] |  |
| 4e5165e93a7fa4abd3c4 | tools/bench/programs/trait.bnt:[183, 219] | call | ['xs', 'i'] |  |
| d6e9f37702d3596a2dfc | tools/bench/programs/trait.bnt:[907, 942] | call | ['count', 'value'] |  |
| fea9c0796c96a5da614b | tools/bench/programs/trait.bnt:[1205, 1221] | call | ['count', 'value'] |  |
| 59a2a8d7a181b75a0e4d | tools/bench/wasm/Runner.bnt:[410, 479] | call | ['o', 'error'] |  |
| 18b8a4cf6db198bd3c52 | tools/bench/wasm/Runner.bnt:[422, 458] | call | ['xs', 'i'] |  |
| feca8d63a0741bcf6453 | tools/bench/wasm/Runner.bnt:[681, 737] | call | ['o', 'error'] |  |
| e02bd7096331ae17e5ce | tools/bench/wasm/Runner.bnt:[1068, 1101] | call | ['remaining', 'last', 'work'] |  |
| 8360aaba9dbd9cc3de82 | tools/bench/wasm/Runner.bnt:[1550, 1580] | call | ['remaining', 'last', 'work'] |  |
| 4ae0a531191f5fa18254 | tools/bench/wasm/hash-a.bnt:[530, 595] | component | ['error'] |  |
| 5d7364d92dea5cdc65bb | tools/bench/wasm/hash-a.bnt:[492, 596] | call | ['r', 'f'] |  |
| d2abc3a150f961756a8c | tools/bench/wasm/hash-a.bnt:[606, 734] | call | ['count', 'work', 'render'] |  |
| 6a0bf60ee6c67116aaf4 | tools/bench/wasm/hash-c-fast.bnt:[668, 733] | component | ['error'] |  |
| e98071bcdce18206a996 | tools/bench/wasm/hash-c-fast.bnt:[630, 734] | call | ['r', 'f'] |  |
| c6a66f09e7f2b14fd35e | tools/bench/wasm/hash-c-fast.bnt:[744, 874] | call | ['count', 'work', 'render'] |  |
| 7c84403b4a853e997afa | tools/bench/wasm/hash-c-list.bnt:[668, 733] | component | ['error'] |  |
| ab40f25171e572893ee0 | tools/bench/wasm/hash-c-list.bnt:[630, 734] | call | ['r', 'f'] |  |
| c773d7b0155416751df6 | tools/bench/wasm/hash-c-list.bnt:[780, 996] | call | ['count', 'work', 'render'] |  |
| 3e41aea16411f78f12a3 | tools/bench/wasm/json-a.bnt:[353, 404] | call | ['o', 'fallback'] |  |
| b9afffa0966ca66f04de | tools/bench/wasm/json-a.bnt:[369, 386] | call | ['value', 'index'] |  |
| 039f9e86f0706f7819bf | tools/bench/wasm/json-a.bnt:[446, 593] | call | ['xs', 'f'] |  |
| a7a93ff6542d53f7924c | tools/bench/wasm/json-a.bnt:[527, 579] | call | ['o', 'fallback'] |  |
| c1c0a26223b394ba7640 | tools/bench/wasm/json-a.bnt:[543, 561] | call | ['value', 'k'] |  |
| 707afae57c39e1d64a69 | tools/bench/wasm/json-a.bnt:[1000, 1137] | call | ['xs', 'initial', 'f'] |  |
| b4572daa947ad71955eb | tools/bench/wasm/json-a.bnt:[1010, 1029] | call | ['start', 'stop'] |  |
| f593ecfc96cb5751f5c5 | tools/bench/wasm/json-a.bnt:[1149, 1313] | call | ['count', 'work', 'render'] |  |
| 36444d1e8cf693c5b9d0 | tools/bench/wasm/json-a.bnt:[1359, 1526] | call | ['count', 'work', 'render'] |  |
| 9e264c5d6651076c1aec | tools/bench/wasm/json-a.bnt:[1438, 1498] | call | ['r', 'f'] |  |
| 313d462e031dabcf1b0b | tools/bench/wasm/json-a.bnt:[1587, 1647] | call | ['r', 'f'] |  |
| 493a3e2abc2f1cbac802 | tools/bench/wasm/json-a.bnt:[1659, 1827] | call | ['count', 'work', 'render'] |  |
| 2f4e2333f6e198fbd24c | tools/bench/wasm/json-a.bnt:[1872, 2125] | call | ['count', 'work', 'render'] |  |
| 5b818a144f70a4d22e5e | tools/bench/wasm/json-a.bnt:[1964, 2024] | call | ['r', 'f'] |  |
| 0805f3aa2cd58b868c11 | tools/bench/wasm/json-a.bnt:[2172, 2441] | call | ['count', 'work', 'render'] |  |
| 0d8d121bbfab30dcec78 | tools/bench/wasm/json-a.bnt:[2264, 2324] | call | ['r', 'f'] |  |
| 1ee5a8205739c62d6d0d | tools/bench/wasm/json-a.bnt:[2490, 2762] | call | ['count', 'work', 'render'] |  |
| 33377c961fc9da147a12 | tools/bench/wasm/json-a.bnt:[2563, 2692] | call | ['r', 'f'] |  |
| 00cce2d296bd6b57a7b8 | tools/bench/wasm/json-a.bnt:[2574, 2634] | call | ['r', 'f'] |  |
| df052bfd7b55d3a9c3c5 | tools/bench/wasm/json-a.bnt:[2823, 2883] | call | ['r', 'f'] |  |
| 37a63296de71c4e5f7cb | tools/bench/wasm/json-a.bnt:[3011, 3071] | call | ['r', 'f'] |  |
| 26fcfa4325e9b1215daa | tools/bench/wasm/json-a.bnt:[3083, 3247] | call | ['count', 'work', 'render'] |  |
| 6a67cfb818a828075008 | tools/bench/wasm/regex-a.bnt:[619, 684] | component | ['error'] |  |
| 64a81c9fca99ed892dc4 | tools/bench/wasm/regex-a.bnt:[582, 685] | call | ['r', 'f'] |  |
| 3f0b92637aff48696195 | tools/bench/wasm/regex-a.bnt:[852, 881] | call | ['pattern', 'text'] |  |
| e49cb362859d7052ed28 | tools/bench/wasm/regex-a.bnt:[1123, 1152] | call | ['pattern', 'text'] |  |
| 03b2ac22d332ac91b5d1 | tools/bench/wasm/regex-a.bnt:[1331, 1360] | call | ['pattern', 'text'] |  |
| eef9233e50151e2e23e9 | tools/bench/wit-transfer/Runner.bnt:[401, 458] | call | ['o', 'error'] |  |
| 53bcc632559e6fe6e5d2 | tools/bench/wit-transfer/Runner.bnt:[413, 435] | call | ['xs', 'i'] |  |
| e72e77ce2102b76a5ea0 | tools/bench/wit-transfer/Runner.bnt:[479, 533] | call | ['o', 'error'] |  |
| b7e34714d78cd937afb2 | tools/bench/wit-transfer/Runner.bnt:[559, 618] | call | ['o', 'error'] |  |
| 98fa055cd3b13b1ea33e | tools/bench/wit-transfer/Runner.bnt:[571, 593] | call | ['xs', 'i'] |  |
| f301812daef6d8dcadea | tools/bench/wit-transfer/Runner.bnt:[640, 702] | call | ['o', 'error'] |  |
| e9ea382303815c9d9267 | tools/bench/wit-transfer/Runner.bnt:[1194, 1239] | call | ['remaining', 'work', 'correct'] |  |
| 41c620111d2b826bb031 | tools/bench/wit-transfer/Runner.bnt:[1491, 1517] | call | ['remaining', 'work', 'correct'] |  |
| 70d586f48b63dc17e7b4 | tools/bench/wit-transfer/flags.bnt:[1567, 1588] | call | ['xs', 'n'] |  |
| c6159a9a02429f8d12b4 | tools/bench/wit-transfer/flags.bnt:[1638, 1681] | call | ['a', 'n'] |  |
| 64c3a6061e836abab98c | tools/bench/wit-transfer/flags.bnt:[1659, 1680] | call | ['a', 'b'] |  |
| fba45f3cfd9fac4efdeb | tools/bench/wit-transfer/flags.bnt:[1718, 1788] | call | ['xs', 'n'] |  |
| 8048e62fddc9691a7e69 | tools/bench/wit-transfer/flags.bnt:[1887, 1930] | call | ['a', 'n'] |  |
| 47f9087eaee2ba59a00b | tools/bench/wit-transfer/flags.bnt:[1908, 1929] | call | ['a', 'b'] |  |
| 677faee69f7b5e540ccc | tools/bench/wit-transfer/flags.bnt:[1967, 2044] | call | ['xs', 'n'] |  |
| 84af2312908a2392be2c | tools/bench/wit-transfer/flags.bnt:[2150, 2193] | call | ['a', 'n'] |  |
| 2fc6a6e92d4e8f6abe18 | tools/bench/wit-transfer/flags.bnt:[2171, 2192] | call | ['a', 'b'] |  |
| cf287c30e4813807e6dd | tools/bench/wit-transfer/flags.bnt:[2231, 2380] | call | ['xs', 'n'] |  |
| b42dc14189d89056659b | tools/bench/wit-transfer/flags.bnt:[2559, 2603] | call | ['a', 'n'] |  |
| 8b23998920750003b5c8 | tools/bench/wit-transfer/flags.bnt:[2580, 2602] | call | ['a', 'b'] |  |
| 75945537317814ee7b0f | tools/bench/wit-transfer/flags.bnt:[2641, 2799] | call | ['xs', 'n'] |  |
| b61a22b350e54608d5a1 | tools/bench/wit-transfer/flags.bnt:[2987, 3031] | call | ['a', 'n'] |  |
| 23292ce7906def1473d5 | tools/bench/wit-transfer/flags.bnt:[3008, 3030] | call | ['a', 'b'] |  |
| 2f02fc1d770d5a250d92 | tools/bench/wit-transfer/flags.bnt:[3069, 3362] | call | ['xs', 'n'] |  |
| 031fc547f853fea0b280 | tools/bench/wit-transfer/flags.bnt:[3685, 3729] | call | ['a', 'n'] |  |
| 894a2ea499ddb9f3dac3 | tools/bench/wit-transfer/flags.bnt:[3706, 3728] | call | ['a', 'b'] |  |
| 47c54e265e87dfd76624 | tools/bench/wit-transfer/flags.bnt:[3745, 4144] | call | ['rounds', 'work'] |  |
| 8a9b3a7fb5747ec531bc | tools/bench/wit-transfer/large-bytes-adapter.bnt:[466, 590] | component | ['value'] |  |
| ce9a00afa77503a0e68c | tools/bench/wit-transfer/large-bytes-adapter.bnt:[439, 591] | call | ['xs', 'f'] |  |
| 7c8203ea891ff1ae5a62 | tools/bench/wit-transfer/large-bytes-adapter.bnt:[448, 464] | call | ['start', 'stop'] |  |
| 71b6eaf31637e4dfa9dd | tools/bench/wit-transfer/large-bytes-adapter.bnt:[627, 779] | call | ['xs', 'f'] |  |
| c521460b8f6d4ec75c05 | tools/bench/wit-transfer/large-bytes-adapter.bnt:[636, 652] | call | ['start', 'stop'] |  |
| 74ecec1b141d83ee12dc | tools/bench/wit-transfer/large-bytes-adapter.bnt:[791, 924] | call | ['rounds', 'work'] |  |
| 973cdf45141bf71485bf | tools/bench/wit-transfer/large-bytes-adapter.bnt:[853, 880] | call | ['ignored', 'v'] |  |
| 4f7157e30d620285c2e8 | tools/bench/wit-transfer/large-bytes-typed.bnt:[769, 893] | component | ['value'] |  |
| 856e41d7a9930f0da485 | tools/bench/wit-transfer/large-bytes-typed.bnt:[420, 473] | call | ['o', 'error'] |  |
| 7b563a7ee3364a6ca42e | tools/bench/wit-transfer/large-bytes-typed.bnt:[495, 550] | call | ['o', 'error'] |  |
| f4b681f2319e48841d75 | tools/bench/wit-transfer/large-bytes-typed.bnt:[570, 625] | call | ['o', 'error'] |  |
| 0dfd4f2ce8c014766ee4 | tools/bench/wit-transfer/large-bytes-typed.bnt:[654, 709] | call | ['o', 'error'] |  |
| 96524c422f029c4d468d | tools/bench/wit-transfer/large-bytes-typed.bnt:[742, 894] | call | ['xs', 'f'] |  |
| cab86bf2d3b0baf76cef | tools/bench/wit-transfer/large-bytes-typed.bnt:[751, 767] | call | ['start', 'stop'] |  |
| 532be1ed8faaba11236b | tools/bench/wit-transfer/large-bytes-typed.bnt:[930, 1089] | call | ['xs', 'f'] |  |
| a202c54c8a60866bc90e | tools/bench/wit-transfer/large-bytes-typed.bnt:[939, 955] | call | ['start', 'stop'] |  |
| 6a553d03451a8c7597d2 | tools/bench/wit-transfer/large-bytes-typed.bnt:[1101, 1216] | call | ['rounds', 'work'] |  |
| efc7f97e2a120a70d9bf | tools/bench/wit-transfer/large-bytes.bnt:[551, 675] | component | ['value'] |  |
| eca7ab81907c17ca263d | tools/bench/wit-transfer/large-bytes.bnt:[524, 676] | call | ['xs', 'f'] |  |
| d1bbaaf4d1fa10a10b66 | tools/bench/wit-transfer/large-bytes.bnt:[533, 549] | call | ['start', 'stop'] |  |
| 22fd9242ff11d3939dfe | tools/bench/wit-transfer/large-bytes.bnt:[712, 864] | call | ['xs', 'f'] |  |
| 1af6029e677b2a72198e | tools/bench/wit-transfer/large-bytes.bnt:[721, 737] | call | ['start', 'stop'] |  |
| 0805c42abb20b90a2840 | tools/bench/wit-transfer/large-bytes.bnt:[876, 1062] | call | ['rounds', 'work'] |  |
| 82ebab0e80b85e86d595 | tools/bench/wit-transfer/large-bytes.bnt:[970, 997] | call | ['ignored', 'v'] |  |
| 0269fc54adcee3673205 | tools/bench/wit-transfer/maps.bnt:[709, 799] | component | ['value'] |  |
| e74c3b67c45e206edfcd | tools/bench/wit-transfer/maps.bnt:[644, 660] | call | ['start', 'stop'] |  |
| 1de95206225931c57ee8 | tools/bench/wit-transfer/maps.bnt:[691, 800] | call | ['xs', 'f'] |  |
| 443abaad285f8ad6e5bc | tools/bench/wit-transfer/maps.bnt:[834, 947] | call | ['xs', 'f'] |  |
| c2fc0a534402633b0bc5 | tools/bench/wit-transfer/maps.bnt:[959, 1221] | call | ['rounds', 'work'] |  |
| 93f3fb7e5d9b17da0682 | tools/bench/wit-transfer/nested.bnt:[473, 626] | component | ['value'] |  |
| 229d3b5e16764a0589be | tools/bench/wit-transfer/nested.bnt:[446, 627] | call | ['xs', 'f'] |  |
| 2c9bf921a19f2d9bfc5f | tools/bench/wit-transfer/nested.bnt:[455, 471] | call | ['start', 'stop'] |  |
| 1521abc19e4ef1004921 | tools/bench/wit-transfer/nested.bnt:[647, 828] | call | ['xs', 'f'] |  |
| 082693a43a7ad0bcd06e | tools/bench/wit-transfer/nested.bnt:[656, 672] | call | ['start', 'stop'] |  |
| d278873e703d6b7230bd | tools/bench/wit-transfer/nested.bnt:[839, 946] | call | ['rounds', 'work'] |  |
| 8b66510c867d9e87adce | tools/bench/wit-transfer/numbers.bnt:[2381, 2510] | component | ['value'] |  |
| c1ec353ccba1755a78bd | tools/bench/wit-transfer/numbers.bnt:[2327, 2343] | call | ['start', 'stop'] |  |
| 9305c37e2a59d23f355a | tools/bench/wit-transfer/numbers.bnt:[2363, 2511] | call | ['xs', 'f'] |  |
| 8c77633acd3a45819409 | tools/bench/wit-transfer/numbers.bnt:[2533, 2681] | call | ['xs', 'f'] |  |
| fe97196a6152a418c3a1 | tools/bench/wit-transfer/numbers.bnt:[2702, 2858] | call | ['xs', 'f'] |  |
| 5b8ee6e417e303e7ba48 | tools/bench/wit-transfer/numbers.bnt:[2881, 3037] | call | ['xs', 'f'] |  |
| 9613b4f9e9a8e8f7cd22 | tools/bench/wit-transfer/numbers.bnt:[3058, 3224] | call | ['xs', 'f'] |  |
| 7efaaae92ccc2eec7a80 | tools/bench/wit-transfer/numbers.bnt:[3247, 3413] | call | ['xs', 'f'] |  |
| 8652844f28da64b0e44f | tools/bench/wit-transfer/numbers.bnt:[3434, 3595] | call | ['xs', 'f'] |  |
| 4a2220d236972773e373 | tools/bench/wit-transfer/numbers.bnt:[3618, 3779] | call | ['xs', 'f'] |  |
| a6125a3f3ce5ac3c57ce | tools/bench/wit-transfer/numbers.bnt:[3800, 3968] | call | ['xs', 'f'] |  |
| dd95d6fdf523f7d9e88e | tools/bench/wit-transfer/numbers.bnt:[3991, 4159] | call | ['xs', 'f'] |  |
| 9c4ddb0036b58a8f6cae | tools/bench/wit-transfer/numbers.bnt:[4180, 4372] | call | ['xs', 'f'] |  |
| f1f06080a5dbd5ef51d2 | tools/bench/wit-transfer/numbers.bnt:[4395, 4587] | call | ['xs', 'f'] |  |
| c14e40c8e6420877f991 | tools/bench/wit-transfer/numbers.bnt:[4608, 4768] | call | ['xs', 'f'] |  |
| 40547fb6ef753f3bbc7c | tools/bench/wit-transfer/numbers.bnt:[4791, 4952] | call | ['xs', 'f'] |  |
| 1a62e254c41577ddbd8f | tools/bench/wit-transfer/numbers.bnt:[4963, 6120] | call | ['rounds', 'work'] |  |
| f4822a2ebb62a6a15214 | tools/bench/wit-transfer/primitives.bnt:[927, 1051] | component | ['value'] |  |
| c96205f0fc2658710b18 | tools/bench/wit-transfer/primitives.bnt:[816, 867] | call | ['s', 'n'] |  |
| 9ab43792caa58fb54814 | tools/bench/wit-transfer/primitives.bnt:[842, 866] | call | ['a', 'b'] |  |
| 76035d9bcc5d802a7f46 | tools/bench/wit-transfer/primitives.bnt:[900, 1052] | call | ['xs', 'f'] |  |
| fa24998c3c2b9837eefa | tools/bench/wit-transfer/primitives.bnt:[909, 925] | call | ['start', 'stop'] |  |
| b40328b95747912d27f6 | tools/bench/wit-transfer/primitives.bnt:[1088, 1240] | call | ['xs', 'f'] |  |
| 671c22ca787949a3acdf | tools/bench/wit-transfer/primitives.bnt:[1097, 1113] | call | ['start', 'stop'] |  |
| 1fc3658ca5559a740e33 | tools/bench/wit-transfer/primitives.bnt:[1252, 1600] | call | ['rounds', 'work'] |  |
| bff13e5d79c8e2cccaff | tools/bench/wit-transfer/primitives.bnt:[1499, 1526] | call | ['ignored', 'v'] |  |
| 344fcd70171c1d106708 | tools/bench/wit-transfer/records.bnt:[892, 1415] | call | ['rounds', 'work'] |  |
| 3007b403934c28b48408 | tools/bench/wit-transfer/short-numbers-adapter.bnt:[425, 493] | call | ['o', 'error'] |  |
| 940da6e925583edb0c36 | tools/bench/wit-transfer/short-numbers-adapter.bnt:[584, 659] | call | ['o', 'error'] |  |
| aa18ae382c280a5de339 | tools/bench/wit-transfer/short-numbers-adapter.bnt:[669, 780] | call | ['rounds', 'work'] |  |
| f1d19ca0dd460349d6b7 | tools/bench/wit-transfer/short-numbers-typed.bnt:[483, 585] | call | ['rounds', 'work'] |  |
| 4abe7035007f552322c1 | tools/bench/wit-transfer/short-numbers.bnt:[507, 575] | call | ['o', 'error'] |  |
| 0dc2958c10d82e833322 | tools/bench/wit-transfer/short-numbers.bnt:[666, 741] | call | ['o', 'error'] |  |
| 9ecb6d0bb4c508ba6fa1 | tools/bench/wit-transfer/short-numbers.bnt:[751, 902] | call | ['rounds', 'work'] |  |
| 23dcf1b8f898d77ea9c4 | tools/bench/wit-transfer/tuples.bnt:[888, 1440] | call | ['rounds', 'work'] |  |
| 5c3fdfb8a22c9d29d2ef | tools/bench/wit-transfer/utf16.bnt:[516, 544] | call | ['s', 'n'] |  |
| 54679145446be4238e24 | tools/bench/wit-transfer/utf16.bnt:[564, 592] | call | ['s', 'n'] |  |
| 7e9fcd14944c96a10137 | tools/bench/wit-transfer/utf16.bnt:[603, 769] | call | ['rounds', 'work'] |  |
| dcd33794731d217c22f2 | tools/bench/wit-transfer/utf16.bnt:[698, 723] | call | ['ignored', 'v'] |  |
| 1bc1cdbbed5b51d0fb5f | tools/bench/wit-transfer/variants.bnt:[969, 1828] | call | ['rounds', 'work'] |  |
| d607e6476b794c654f5f | tools/skill-eval/tasks/csv_report/reference.bnt:[1412, 1570] | component | ['value'] |  |
| b5229d271d4248ceb9bd | tools/skill-eval/tasks/csv_report/reference.bnt:[1747, 1905] | component | ['value'] |  |
| 635fe77e08bc21321af2 | tools/skill-eval/tasks/csv_report/reference.bnt:[205, 254] | call | ['o', 'f'] |  |
| 7491133a2eb3a00ec26c | tools/skill-eval/tasks/csv_report/reference.bnt:[220, 238] | call | ['m', 'k'] |  |
| eb518c13578c4e971879 | tools/skill-eval/tasks/csv_report/reference.bnt:[560, 618] | call | ['o', 'error'] |  |
| 46e94f8b56a0be2904bf | tools/skill-eval/tasks/csv_report/reference.bnt:[572, 594] | call | ['m', 'k'] |  |
| 0cac7433a90c29ceccb2 | tools/skill-eval/tasks/csv_report/reference.bnt:[642, 664] | call | ['row', 'name'] |  |
| 5e064e4ef9660560b433 | tools/skill-eval/tasks/csv_report/reference.bnt:[685, 709] | call | ['row', 'name'] |  |
| e36f98409c94f1e6b5c5 | tools/skill-eval/tasks/csv_report/reference.bnt:[728, 751] | call | ['m', 'k'] |  |
| 0957484465ea98732d05 | tools/skill-eval/tasks/csv_report/reference.bnt:[805, 900] | call | ['m', 'k', 'value'] |  |
| a53870149a3378a43946 | tools/skill-eval/tasks/csv_report/reference.bnt:[1300, 1314] | call | ['totals', 'row'] |  |
| f4dfefa3fe9a8321d6fe | tools/skill-eval/tasks/csv_report/reference.bnt:[1394, 1571] | call | ['xs', 'f'] |  |
| c700fafca54afda3fde4 | tools/skill-eval/tasks/csv_report/reference.bnt:[1588, 1683] | call | ['path', 'text'] |  |
| a3f2ac675971e0e50ef0 | tools/skill-eval/tasks/csv_report/reference.bnt:[1629, 1681] | call | ['xs', 'x'] |  |
| d6cc181a67ad82842b4b | tools/skill-eval/tasks/csv_report/reference.bnt:[1725, 1906] | call | ['xs', 'f'] |  |
| 7cdb732a72c30be9fe7c | tools/skill-eval/tasks/dir_walk/reference.bnt:[384, 412] | call | ['s', 'suffix'] |  |
| 3b3cd7d9e2e74a0e60bf | tools/skill-eval/tasks/dir_walk/reference.bnt:[979, 1005] | call | ['paths', 'files', 'total'] |  |
| 2ede0f7ea2863f30ae67 | tools/skill-eval/tasks/dir_walk/reference.bnt:[1111, 1149] | call | ['paths', 'files', 'total'] |  |
| fa30473f583aa345025d | tools/skill-eval/tasks/dir_walk/reference.bnt:[1332, 1351] | call | ['paths', 'files', 'total'] |  |
| cae73ea2c86d63c87562 | tools/skill-eval/tasks/error_handling/reference.bnt:[800, 852] | component | ['acc', 'value'] |  |
| 2dd2732dd739b494d981 | tools/skill-eval/tasks/error_handling/reference.bnt:[771, 853] | call | ['xs', 'initial', 'f'] |  |
| 89afba20a4512f7fd859 | tools/skill-eval/tasks/error_handling/reference.bnt:[825, 841] | call | ['path', 'done'] |  |
| 86cdc654793db551b791 | tools/skill-eval/tasks/file_process/reference.bnt:[572, 613] | component | ['value'] |  |
| 1a7aeff235419a9da863 | tools/skill-eval/tasks/file_process/reference.bnt:[253, 319] | call | ['items', 'index', 'acc'] |  |
| fc5c78aa770804c03239 | tools/skill-eval/tasks/file_process/reference.bnt:[279, 318] | call | ['xs', 'x'] |  |
| b49f71abdc2c37424bf5 | tools/skill-eval/tasks/file_process/reference.bnt:[530, 614] | call | ['xs', 'p'] |  |
| 5947fab6b7a5d4cf196b | tools/skill-eval/tasks/file_process/reference.bnt:[542, 570] | call | ['xs', 'f'] |  |
| 06b21db2311f544a403c | tools/skill-eval/tasks/file_process/reference.bnt:[632, 673] | call | ['xs', 'separator'] |  |
| b11485c4577245c873a2 | tools/skill-eval/tasks/file_process/reference.bnt:[644, 666] | call | ['items', 'index', 'acc'] |  |
| afbd719e4ff36c211e63 | tools/skill-eval/tasks/file_process/reference.bnt:[697, 740] | call | ['path', 'text'] |  |
| c62de806ed87b2800973 | tools/skill-eval/tasks/http_client/reference.bnt:[304, 394] | call | ['o', 'error'] |  |
| 086e19f45b768d153663 | tools/skill-eval/tasks/http_client/reference.bnt:[316, 370] | call | ['o', 'f'] |  |
| c849fa7d4c54f303487f | tools/skill-eval/tasks/http_client/reference.bnt:[331, 354] | call | ['value', 'k'] |  |
| d0cc8b069d32751d7c70 | tools/skill-eval/tasks/http_client/reference.bnt:[415, 508] | call | ['o', 'error'] |  |
| 8418bc630e76389fc2db | tools/skill-eval/tasks/http_client/reference.bnt:[427, 483] | call | ['o', 'f'] |  |
| 1ef460cf875d042b822d | tools/skill-eval/tasks/http_client/reference.bnt:[442, 466] | call | ['value', 'k'] |  |
| cfca3da23633eebe7ae1 | tools/skill-eval/tasks/http_client/reference.bnt:[529, 622] | call | ['o', 'error'] |  |
| bc93dfd5ac7e4143ff62 | tools/skill-eval/tasks/http_client/reference.bnt:[541, 597] | call | ['o', 'f'] |  |
| a21126de6ec43da1bbbe | tools/skill-eval/tasks/http_client/reference.bnt:[556, 580] | call | ['value', 'k'] |  |
| b04b2c32e67ba75c21be | tools/skill-eval/tasks/http_client/reference.bnt:[764, 830] | call | ['o', 'fallback'] |  |
| 8a308b0536fe2da67a4e | tools/skill-eval/tasks/http_client/reference.bnt:[958, 1100] | call | ['o', 'error'] |  |
| 7b388fac3c82d8becf15 | tools/skill-eval/tasks/http_client/reference.bnt:[1461, 1526] | call | ['o', 'error'] |  |
| 803730b5589e49cb657e | tools/skill-eval/tasks/http_client/reference.bnt:[1547, 1745] | call | ['xs', 'initial', 'f'] |  |
| eddc286c1b71c2b3aba9 | tools/skill-eval/tasks/http_client/reference.bnt:[1605, 1731] | call | ['r', 'f'] |  |
| 3dd00b3ec4232fc61278 | tools/skill-eval/tasks/http_client/reference.bnt:[1643, 1719] | call | ['r', 'f'] |  |
| 10617fd611ba2ca4fea9 | tools/skill-eval/tasks/http_client/reference.bnt:[1685, 1707] | call | ['xs', 'x'] |  |
| 8e9523f42d2323e0e4f8 | tools/skill-eval/tasks/http_client/reference.bnt:[1791, 1862] | call | ['xs', 'p'] |  |
| 5a02fefa182a273d21da | tools/skill-eval/tasks/http_client/reference.bnt:[1897, 2004] | call | ['xs', 'separator'] |  |
| c59b24e2a65f03518b48 | tools/skill-eval/tasks/http_client/reference.bnt:[1909, 1997] | call | ['xs', 'f'] |  |
| 33805c5076439d3f5631 | tools/skill-eval/tasks/http_client/reference.bnt:[2048, 2146] | call | ['xs', 'initial', 'f'] |  |
| 413277e41da56825bd1c | tools/skill-eval/tasks/http_client/reference.bnt:[2183, 2263] | call | ['xs', 'f'] |  |
| 7c16b186bbce0e2bd9e1 | tools/skill-eval/tasks/http_client/reference.bnt:[2304, 2348] | call | ['method', 'url'] |  |
| bd23dd84b80bc92acbd6 | tools/skill-eval/tasks/json_convert/reference.bnt:[923, 1031] | component | ['key', 'value'] |  |
| 892b2034bd42bc60c551 | tools/skill-eval/tasks/json_convert/reference.bnt:[708, 873] | component | ['acc', 'value'] |  |
| c54653669545d99cc20a | tools/skill-eval/tasks/json_convert/reference.bnt:[216, 255] | call | ['o', 'fallback'] |  |
| 99823684135a3200104f | tools/skill-eval/tasks/json_convert/reference.bnt:[232, 250] | call | ['m', 'k'] |  |
| ea27992beba0f35cf418 | tools/skill-eval/tasks/json_convert/reference.bnt:[332, 388] | call | ['o', 'fallback'] |  |
| b88554fa9c92c96eb85a | tools/skill-eval/tasks/json_convert/reference.bnt:[362, 383] | call | ['row', 'name'] |  |
| c177673973933171413b | tools/skill-eval/tasks/json_convert/reference.bnt:[679, 874] | call | ['xs', 'initial', 'f'] |  |
| 021bde3af005ca386617 | tools/skill-eval/tasks/json_convert/reference.bnt:[740, 759] | call | ['row', 'name'] |  |
| 18c4aae626db97db36c4 | tools/skill-eval/tasks/json_convert/reference.bnt:[771, 860] | call | ['m', 'k', 'value'] |  |
| ea210cf0a0b02de8342b | tools/skill-eval/tasks/json_convert/reference.bnt:[788, 859] | call | ['xs', 'x'] |  |
| 0ac35f0bd50c9c48fe30 | tools/skill-eval/tasks/json_convert/reference.bnt:[800, 837] | call | ['o', 'fallback'] |  |
| aa96ae1558b48f1389ac | tools/skill-eval/tasks/json_convert/reference.bnt:[816, 832] | call | ['m', 'k'] |  |
| 8af1d3a8e0533ebfce74 | tools/skill-eval/tasks/json_convert/reference.bnt:[839, 858] | call | ['row', 'name'] |  |
| ec83cf668c90141c6046 | tools/skill-eval/tasks/json_convert/reference.bnt:[908, 1032] | call | ['m', 'f'] |  |
| 0dbf197d704a56f39df7 | tools/skill-eval/tasks/json_convert/reference.bnt:[972, 1017] | call | ['xs', 'f'] |  |
| 5d834371875b43f70167 | tools/skill-eval/tasks/json_convert/reference.bnt:[1050, 1107] | call | ['path', 'text'] |  |
| e4846f0d3841a88214c1 | tools/skill-eval/tasks/json_convert/reference.bnt:[1247, 1302] | call | ['o', 'error'] |  |
| b3ebbe29c3fd7f3ce450 | tools/skill-eval/tasks/json_convert/reference.bnt:[1320, 1435] | call | ['xs', 'initial', 'f'] |  |
| d29abd47c50523e3dbee | tools/skill-eval/tasks/json_convert/reference.bnt:[1474, 1496] | call | ['row', 'name'] |  |
| 20b52db02fc69691f6b9 | tools/skill-eval/tasks/json_summary/reference.bnt:[545, 603] | call | ['o', 'f'] |  |
| 50452b9e374a08d49e43 | tools/skill-eval/tasks/json_summary/reference.bnt:[560, 587] | call | ['value', 'k'] |  |
| 7747e430c83b1cb09d84 | tools/skill-eval/tasks/json_summary/reference.bnt:[751, 808] | call | ['o', 'f'] |  |
| 7b6966487e2b611d626c | tools/skill-eval/tasks/json_summary/reference.bnt:[766, 791] | call | ['value', 'k'] |  |
| e0799724039056ffdd16 | tools/skill-eval/tasks/json_summary/reference.bnt:[943, 968] | call | ['m', 'k'] |  |
| 696498483b1656ee9fb6 | tools/skill-eval/tasks/json_summary/reference.bnt:[1022, 1109] | call | ['m', 'k', 'value'] |  |
| 0c4e888c1b31abd8e3da | tools/skill-eval/tasks/json_summary/reference.bnt:[1559, 1712] | call | ['xs', 'initial', 'f'] |  |
| ae4cf403d2d3bd77aa24 | tools/skill-eval/tasks/json_summary/reference.bnt:[1631, 1698] | call | ['r', 'f'] |  |
| 8e9488fc598c5d38e43c | tools/skill-eval/tasks/json_summary/reference.bnt:[1668, 1686] | call | ['totals', 'order'] |  |
| aef13d3c96b7bfacc711 | tools/skill-eval/tasks/json_summary/reference.bnt:[1715, 1861] | call | ['m', 'f'] |  |
| 151814e45c23249d8981 | tools/skill-eval/tasks/json_summary/reference.bnt:[1923, 2018] | call | ['xs', 'initial', 'f'] |  |
| cbb1f4ca9863f2827daf | tools/skill-eval/tasks/process_run/reference.bnt:[600, 647] | component | ['value'] |  |
| 787d33f474e244bc76b2 | tools/skill-eval/tasks/process_run/reference.bnt:[320, 351] | call | ['program', 'arguments'] |  |
| 2a177a5247f4fc9f2550 | tools/skill-eval/tasks/process_run/reference.bnt:[580, 648] | call | ['xs', 'f'] |  |
| 863114335591acedf8b4 | tools/skill-eval/tasks/process_shell/reference.bnt:[388, 435] | component | ['value'] |  |
| dea520dc898d48ad77a3 | tools/skill-eval/tasks/process_shell/reference.bnt:[363, 436] | call | ['xs', 'f'] |  |
| 1d5a9374dfe6a64b9ace | tools/skill-eval/tasks/regex_text/reference.bnt:[790, 863] | component | ['key', 'value'] |  |
| cd636d899fb9eea532f8 | tools/skill-eval/tasks/regex_text/reference.bnt:[621, 710] | component | ['acc', 'value'] |  |
| aeca5ac8dd0bc9e74a8e | tools/skill-eval/tasks/regex_text/reference.bnt:[423, 449] | call | ['pattern', 'text'] |  |
| 594aa7aae6b0f93f486e | tools/skill-eval/tasks/regex_text/reference.bnt:[468, 571] | call | ['xs', 'f'] |  |
| 88046cdd0bb357329b2e | tools/skill-eval/tasks/regex_text/reference.bnt:[520, 558] | call | ['o', 'fallback'] |  |
| b45816c923dd34244562 | tools/skill-eval/tasks/regex_text/reference.bnt:[536, 553] | call | ['m', 'index'] |  |
| bf2edb0a1973f417d6bd | tools/skill-eval/tasks/regex_text/reference.bnt:[589, 711] | call | ['xs', 'initial', 'f'] |  |
| 3b82914125c0a48043b1 | tools/skill-eval/tasks/regex_text/reference.bnt:[645, 697] | call | ['m', 'k', 'value'] |  |
| 1c894e998c3d96a27340 | tools/skill-eval/tasks/regex_text/reference.bnt:[659, 692] | call | ['o', 'fallback'] |  |
| e215d589aa35dad89fc2 | tools/skill-eval/tasks/regex_text/reference.bnt:[675, 688] | call | ['m', 'k'] |  |
| 4d111977309563ec78d8 | tools/skill-eval/tasks/regex_text/reference.bnt:[770, 864] | call | ['m', 'f'] |  |
| 89940b519c01d8f08a74 | tools/skill-eval/tasks/regex_text/reference.bnt:[895, 966] | call | ['xs', 'separator'] |  |
| a9f800fee6ca35075a9c | tools/skill-eval/tasks/regex_text/reference.bnt:[907, 959] | call | ['xs', 'f'] |  |
| df6c0a65d3fc834ef1a4 | tools/skill-eval/tasks/regex_text/reference.bnt:[916, 941] | call | ['pattern', 'text'] |  |
| 782844178f63f0ec7a1c | tools/skill-eval/tasks/write_tests/reference.bnt:[668, 862] | component | ['acc', 'value'] |  |
| 4dc3e55d87cf3835cbe5 | tools/skill-eval/tasks/write_tests/reference.bnt:[162, 193] | call | ['s', 'prefix'] |  |
| 4425ef6ea90f8e3803e1 | tools/skill-eval/tasks/write_tests/reference.bnt:[240, 266] | call | ['s', 'separator'] |  |
| 44f7fbb29b7b8164e62a | tools/skill-eval/tasks/write_tests/reference.bnt:[371, 393] | call | ['xs', 'separator'] |  |
| 2b688a8c12754c05cee1 | tools/skill-eval/tasks/write_tests/reference.bnt:[638, 863] | call | ['xs', 'initial', 'f'] |  |
| ba2e3ae85a3594b77e29 | tools/skill-eval/tasks/write_tests/reference.bnt:[758, 807] | call | ['m', 'k', 'value'] |  |
| 5412e7b41c2244ef044c | tools/skill-eval/tasks/write_tests/reference.bnt:[979, 1057] | call | ['actual', 'expected'] |  |
| aa49de6c9431353e80e9 | tools/skill-eval/tasks/write_tests/reference.bnt:[1166, 1240] | call | ['actual', 'expected'] |  |
| cc52614145b3d1c3459f | tools/skill-eval/tasks/write_tests/reference.bnt:[1361, 1410] | call | ['actual', 'expected'] |  |
| 0219a9fddeda641c6c4c | tools/skill-eval/tasks/write_tests/reference.bnt:[1413, 1459] | call | ['actual', 'expected'] |  |
| 662a6da6e4bc7c2663b6 | tools/skill-eval/tasks/write_tests/reference.bnt:[1695, 1725] | call | ['actual', 'expected'] |  |
| 1a9109d9b142d8fa059b | tools/skill-eval/tasks/write_tests/reference.bnt:[1812, 1908] | call | ['actual', 'expected'] |  |

## held

| ID | パス・バイト範囲 | 種類 | 候補名 | 保留理由 |
|---|---|---|---|---|
| 32537c0fe89b78e99879 | tools/bench/programs/http.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 27be2c0e764ba271b002 | tools/bench/programs/http.bnt:[1349, 1389] | call | ['r', 'f'] | pipe_requires_review |
| f57f95817a82dafd7dde | tools/bench/programs/http.bnt:[1534, 1574] | call | ['r', 'f'] | pipe_requires_review |
| a71a88ee938145fac753 | tools/bench/programs/http.bnt:[1915, 1955] | call | ['r', 'f'] | pipe_requires_review |
| dfdc60620af6ad250621 | tools/bench/programs/map.bnt:[268, 298] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 0e9275c3a8342200c8fe | tools/bench/programs/map.bnt:[840, 871] | call | ['o', 'fallback'] | pipe_requires_review |
| ba3f357336f66592b6c6 | tools/bench/wasm/Runner.bnt:[1324, 1345] | component | None | component_not_determined |
| 88f99f2914514616b289 | tools/bench/wasm/Runner.bnt:[908, 950] | component | None | component_not_determined |
| 969a448daefe608f84a5 | tools/bench/wasm/Runner.bnt:[1057, 1063] | call | None | callee_contract_unresolved, component_not_determined |
| aff80ded7daf6341ea0f | tools/bench/wasm/Runner.bnt:[1475, 1481] | call | None | callee_contract_unresolved, component_not_determined |
| 01018bba1caecda70f1d | tools/bench/wasm/Runner.bnt:[1643, 1655] | call | None | callee_contract_unresolved, component_not_determined |
| cbcb11553d505b1cf107 | tools/bench/wasm/hash-a.bnt:[628, 720] | component | [] | public_contract |
| 62a89be1ce44739ec981 | tools/bench/wasm/hash-a.bnt:None | component | ['b'] | public_contract |
| 8896b2c29d1de1964403 | tools/bench/wasm/hash-c-fast.bnt:[766, 860] | component | [] | public_contract |
| cd2f9bdaee2a658eb1c7 | tools/bench/wasm/hash-c-fast.bnt:None | component | ['b'] | public_contract |
| ff3f69af79f40b089b2f | tools/bench/wasm/hash-c-list.bnt:[802, 905] | component | [] | public_contract |
| a53dc76293fe593d5a5f | tools/bench/wasm/hash-c-list.bnt:[907, 995] | component | ['value'] | public_contract |
| eca90d57cfdf93e30503 | tools/bench/wasm/json-a.bnt:[2636, 2691] | component | ['value'] | local_name_collision |
| ed7a6cfc6a64f1c6841b | tools/bench/wasm/json-a.bnt:[891, 956] | component | ['error'] | nested_or_unresolved_contract |
| f84bb54020a2e1d2d1ad | tools/bench/wasm/json-a.bnt:[1167, 1263] | component | [] | public_contract |
| a0a2db32d87b6fa4d1e8 | tools/bench/wasm/json-a.bnt:[1265, 1312] | component | ['value'] | local_name_collision, public_contract |
| c32b861ec3b37bb40a5e | tools/bench/wasm/json-a.bnt:[482, 592] | component | ['value'] | local_name_collision |
| 8a07b6c8a80b33a90446 | tools/bench/wasm/json-a.bnt:[1048, 1136] | component | ['acc', 'value'] | local_name_collision |
| 4658040309d528106cae | tools/bench/wasm/json-a.bnt:[414, 595] | call | ['value'] | local_name_collision, public_contract |
| 37ad7fcd449497b6c7e9 | tools/bench/wasm/json-a.bnt:[854, 957] | call | ['r', 'f'] | nested_or_unresolved_contract |
| 0854fc2371d0d2bacabc | tools/bench/wasm/json-a.bnt:[1230, 1251] | call | ['value'] | local_name_collision, public_contract |
| 0fb7db4b58a57a1284b6 | tools/bench/wasm/json-a.bnt:[1744, 1765] | call | ['value'] | local_name_collision, public_contract |
| e580f959e555406bcb69 | tools/bench/wasm/json-a.bnt:[2906, 2927] | call | ['value'] | local_name_collision, public_contract |
| a914d90b76ef02b8355d | tools/bench/wasm/json-a.bnt:[3164, 3185] | call | ['value'] | local_name_collision, public_contract |
| 5e6fac14fed17677e300 | tools/bench/wasm/json-b.bnt:[620, 730] | component | ['value'] | input_not_typed_successfully, local_name_collision |
| a7030ba6477b70fac14e | tools/bench/wasm/json-b.bnt:[1186, 1274] | component | ['acc', 'value'] | input_not_typed_successfully, local_name_collision |
| 89482038f0de1265816e | tools/bench/wasm/json-b.bnt:[2788, 2843] | component | ['value'] | input_not_typed_successfully, local_name_collision |
| 7209ef5f8d5d2cdfc24c | tools/bench/wasm/json-b.bnt:[1029, 1094] | component | ['error'] | input_not_typed_successfully, nested_or_unresolved_contract |
| 14be76d23e7829d49697 | tools/bench/wasm/json-b.bnt:[1305, 1403] | component | [] | input_not_typed_successfully, public_contract |
| ed7851f37ec7434f1312 | tools/bench/wasm/json-b.bnt:[1405, 1452] | component | ['value'] | input_not_typed_successfully, local_name_collision, public_contract |
| f2ff777cf6ec8fc1f65e | tools/bench/wasm/json-b.bnt:[491, 542] | call | ['o', 'fallback'] | input_not_typed_successfully |
| 71c89cf502846ac777c3 | tools/bench/wasm/json-b.bnt:[507, 524] | call | ['value', 'index'] | input_not_typed_successfully |
| 1b58c0fb4db950e2497f | tools/bench/wasm/json-b.bnt:[552, 733] | call | ['value'] | input_not_typed_successfully, local_name_collision, public_contract |
| 04ad4463e6a21a1a9090 | tools/bench/wasm/json-b.bnt:[584, 731] | call | ['xs', 'f'] | input_not_typed_successfully |
| 4de7f70f677b4f735fe0 | tools/bench/wasm/json-b.bnt:[665, 717] | call | ['o', 'fallback'] | input_not_typed_successfully |
| 252141656b48bf8dcf37 | tools/bench/wasm/json-b.bnt:[681, 699] | call | ['value', 'k'] | input_not_typed_successfully |
| 2f63011e2eee7b3de39e | tools/bench/wasm/json-b.bnt:[992, 1095] | call | ['r', 'f'] | input_not_typed_successfully, nested_or_unresolved_contract |
| 8d3aa48a9c36eb113dd9 | tools/bench/wasm/json-b.bnt:[1138, 1275] | call | ['xs', 'initial', 'f'] | input_not_typed_successfully |
| 4d30963a7779e9325b50 | tools/bench/wasm/json-b.bnt:[1148, 1167] | call | ['start', 'stop'] | input_not_typed_successfully |
| 4f566c2b9eda25afffeb | tools/bench/wasm/json-b.bnt:[1287, 1453] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 91e57ae1bb35a38bfe60 | tools/bench/wasm/json-b.bnt:[1499, 1668] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 0fcd90f027a9ad929b02 | tools/bench/wasm/json-b.bnt:[1578, 1640] | call | ['r', 'f'] | input_not_typed_successfully |
| 8909468575f42ba0a56d | tools/bench/wasm/json-b.bnt:[1729, 1789] | call | ['r', 'f'] | input_not_typed_successfully |
| 2b9978a3321c7f365bbd | tools/bench/wasm/json-b.bnt:[1801, 1971] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| bc900a140c6c18a5edde | tools/bench/wasm/json-b.bnt:[2016, 2271] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 67c05bc0391dd5ba7ad2 | tools/bench/wasm/json-b.bnt:[2108, 2170] | call | ['r', 'f'] | input_not_typed_successfully |
| fee4cd740aaeced9e6c3 | tools/bench/wasm/json-b.bnt:[2318, 2591] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| d91d359e63c122e27104 | tools/bench/wasm/json-b.bnt:[2410, 2472] | call | ['r', 'f'] | input_not_typed_successfully |
| 8107b6564e1a2ea1c508 | tools/bench/wasm/json-b.bnt:[2640, 2914] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| cb459c395c9d4b267348 | tools/bench/wasm/json-b.bnt:[2713, 2844] | call | ['r', 'f'] | input_not_typed_successfully |
| 63e8c3beab4a818ee2eb | tools/bench/wasm/json-b.bnt:[2724, 2786] | call | ['r', 'f'] | input_not_typed_successfully |
| 09b144f55fb26742ed75 | tools/bench/wasm/json-b.bnt:[2975, 3037] | call | ['r', 'f'] | input_not_typed_successfully |
| 36cdafdca0038cf58c22 | tools/bench/wasm/json-b.bnt:[3167, 3229] | call | ['r', 'f'] | input_not_typed_successfully |
| 19ddb6345268d904781d | tools/bench/wasm/json-b.bnt:[3241, 3407] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| bb975a8a3bd2bbfd9e4e | tools/bench/wasm/json-c.bnt:[1562, 1687] | component | ['value'] | input_not_typed_successfully, local_name_collision |
| 7cff72a399098aad34d8 | tools/bench/wasm/json-c.bnt:[714, 779] | component | ['error'] | input_not_typed_successfully, nested_or_unresolved_contract |
| ae1c6544e328b08b92de | tools/bench/wasm/json-c.bnt:[839, 968] | component | [] | input_not_typed_successfully, public_contract |
| 0875266c7962af20aefe | tools/bench/wasm/json-c.bnt:[1228, 1275] | component | ['value'] | input_not_typed_successfully, local_name_collision, public_contract |
| afa48005ed459c8253d9 | tools/bench/wasm/json-c.bnt:[677, 780] | call | ['r', 'f'] | input_not_typed_successfully, nested_or_unresolved_contract |
| 2bf10bfd87d02bb4258a | tools/bench/wasm/json-c.bnt:[817, 985] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 780b62bb7123821fc198 | tools/bench/wasm/json-c.bnt:[896, 957] | call | ['r', 'f'] | input_not_typed_successfully |
| 272f9f557cd89d1b1357 | tools/bench/wasm/json-c.bnt:[1046, 1106] | call | ['r', 'f'] | input_not_typed_successfully |
| 0485f6d5347c6607732f | tools/bench/wasm/json-c.bnt:[1118, 1276] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 27ec0ac8c15e49f755d5 | tools/bench/wasm/json-c.bnt:[1321, 1766] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 52e29b92b7d1a6cf6e95 | tools/bench/wasm/json-c.bnt:[1411, 1475] | call | ['r', 'f'] | input_not_typed_successfully |
| 048659b7875d31e01c4b | tools/bench/wasm/json-c.bnt:[1505, 1694] | call | ['xs', 'separator'] | input_not_typed_successfully |
| 9afa16bc36e682923cf2 | tools/bench/wasm/json-c.bnt:[1517, 1688] | call | ['xs', 'f'] | input_not_typed_successfully |
| f68f2c5f9fb5f2e3c5a5 | tools/bench/wasm/json-c.bnt:[1622, 1670] | call | ['o', 'fallback'] | input_not_typed_successfully |
| a7024ebeac77933793e4 | tools/bench/wasm/json-c.bnt:[1638, 1661] | call | ['document', 'pointer'] | input_not_typed_successfully |
| 0f74be631680a710b6d3 | tools/bench/wasm/json-c.bnt:[1813, 2011] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| b7e5c128130a4d9511b6 | tools/bench/wasm/json-c.bnt:[1888, 1950] | call | ['r', 'f'] | input_not_typed_successfully |
| 46d4dd161be556768de5 | tools/bench/wasm/json-c.bnt:[2060, 2267] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 6eee1b11388dfd945334 | tools/bench/wasm/json-c.bnt:[2133, 2197] | call | ['r', 'f'] | input_not_typed_successfully |
| 6c9013d6dd18ec13304b | tools/bench/wasm/json-c.bnt:[2328, 2389] | call | ['r', 'f'] | input_not_typed_successfully |
| d2d0fd3be83311c7b7f1 | tools/bench/wasm/json-c.bnt:[2522, 2583] | call | ['r', 'f'] | input_not_typed_successfully |
| 7c3f9fad31df0e6b010b | tools/bench/wasm/json-c.bnt:[2641, 2790] | call | ['count', 'work', 'render'] | input_not_typed_successfully |
| 824c09c0572eb45874a9 | tools/bench/wasm/regex-a.bnt:[788, 893] | component | [] | public_contract |
| f97461d25c174b43a9d6 | tools/bench/wasm/regex-a.bnt:[895, 978] | component | ['n'] | public_contract |
| 32f4bc59a19884cefb75 | tools/bench/wasm/regex-a.bnt:[766, 979] | call | ['count', 'work', 'render'] | public_contract |
| 9e9ba07a4299e74ac26d | tools/bench/wasm/regex-a.bnt:[1025, 1184] | call | ['count', 'work', 'render'] | public_contract |
| a1f18f650884ee947f68 | tools/bench/wasm/regex-a.bnt:[1233, 1392] | call | ['count', 'work', 'render'] | public_contract |
| 936a5bb0c5a9e84361f2 | tools/bench/wasm/regex-c-once.bnt:[293, 323] | component | None | component_not_determined, conflicting_expectations, input_not_typed_successfully, public_contract |
| 5ef2dd958a5355aef55b | tools/bench/wasm/regex-c-once.bnt:[761, 826] | component | ['error'] | input_not_typed_successfully |
| b424b41d63e58e8b1bab | tools/bench/wasm/regex-c-once.bnt:[886, 985] | component | [] | input_not_typed_successfully, public_contract |
| dfcde4b02cf699ad8019 | tools/bench/wasm/regex-c-once.bnt:[987, 1070] | component | ['n'] | input_not_typed_successfully, public_contract |
| bb99204b33ce02fd0017 | tools/bench/wasm/regex-c-once.bnt:[724, 827] | call | ['r', 'f'] | input_not_typed_successfully |
| d07e86d42c8b661088a2 | tools/bench/wasm/regex-c-once.bnt:[864, 1071] | call | ['count', 'work', 'render'] | input_not_typed_successfully, public_contract |
| f6228df9823d0e1481b7 | tools/bench/wasm/regex-c-once.bnt:[940, 974] | call | ['source', 'text'] | input_not_typed_successfully |
| 1a0755e6bf884be2d480 | tools/bench/wasm/regex-c-once.bnt:[1117, 1255] | call | ['count', 'work', 'render'] | input_not_typed_successfully, public_contract |
| 1ad03ecc58f90db3ce29 | tools/bench/wasm/regex-c-once.bnt:[1193, 1225] | call | ['source', 'text'] | input_not_typed_successfully |
| 70a8f374265188a38488 | tools/bench/wasm/regex-c-once.bnt:[1304, 1469] | call | ['count', 'work', 'render'] | input_not_typed_successfully, public_contract |
| 899ddd9b8e4d939ebda0 | tools/bench/wasm/regex-c-once.bnt:[1380, 1439] | call | ['r', 'f'] | input_not_typed_successfully |
| 13fc2d8f31c4154da6c0 | tools/bench/wasm/regex-c-once.bnt:[1391, 1425] | call | ['source', 'text'] | input_not_typed_successfully |
| 32e522cb36f5d19837ed | tools/bench/wasm/regex-c-resource.bnt:[761, 826] | component | ['error'] | input_not_typed_successfully |
| 95e2db99512110712075 | tools/bench/wasm/regex-c-resource.bnt:[932, 1039] | component | [] | input_not_typed_successfully, public_contract |
| 2048ea39a0b83069d675 | tools/bench/wasm/regex-c-resource.bnt:[1041, 1124] | component | ['n'] | input_not_typed_successfully, public_contract |
| 42817af9c02293f6cfa5 | tools/bench/wasm/regex-c-resource.bnt:[724, 827] | call | ['r', 'f'] | input_not_typed_successfully |
| 94a9c0f2e29d3858477e | tools/bench/wasm/regex-c-resource.bnt:[910, 1125] | call | ['count', 'work', 'render'] | input_not_typed_successfully, public_contract |
| b644e9e71f3204670438 | tools/bench/wasm/regex-c-resource.bnt:[996, 1027] | call | ['pattern', 'text'] | input_not_typed_successfully |
| 58bdde1f735c936204c0 | tools/bench/wasm/regex-c-resource.bnt:[1171, 1317] | call | ['count', 'work', 'render'] | input_not_typed_successfully, public_contract |
| 6b01e8e00149f06d66da | tools/bench/wasm/regex-c-resource.bnt:[1257, 1286] | call | ['pattern', 'text'] | input_not_typed_successfully |
| 5685d242b3fe925a48f8 | tools/bench/wasm/regex-c-resource.bnt:[1366, 1527] | call | ['count', 'work', 'render'] | input_not_typed_successfully, public_contract |
| 40452d9349b24d1442b1 | tools/bench/wasm/regex-c-resource.bnt:[1464, 1495] | call | ['pattern', 'text'] | input_not_typed_successfully |
| 5e8e8e3787e11a1a52ec | tools/bench/wit-transfer/Runner.bnt:[963, 984] | component | None | component_not_determined |
| 56498ed7f46992aef06b | tools/bench/wit-transfer/Runner.bnt:[1183, 1189] | call | None | callee_contract_unresolved, component_not_determined |
| 343ed1090b9f74f636bd | tools/bench/wit-transfer/flags.bnt:[3767, 4143] | component | [] | public_contract |
| de375365a8405c57aa33 | tools/bench/wit-transfer/large-bytes-adapter.bnt:[813, 923] | component | [] | public_contract |
| dc865b35af23a1df26a8 | tools/bench/wit-transfer/large-bytes-typed.bnt:[1123, 1215] | component | [] | public_contract |
| 6a110f9973c99aff2690 | tools/bench/wit-transfer/large-bytes.bnt:[898, 1061] | component | [] | public_contract |
| eaf64389e3c089481108 | tools/bench/wit-transfer/maps.bnt:[981, 1220] | component | [] | public_contract |
| 58b6d21b9f9a6e18f3a2 | tools/bench/wit-transfer/nested.bnt:[861, 945] | component | [] | public_contract |
| d9baeb306120d930a38f | tools/bench/wit-transfer/numbers.bnt:[4985, 6119] | component | [] | public_contract |
| 6d30ca5036d6672082b0 | tools/bench/wit-transfer/primitives.bnt:[1274, 1599] | component | [] | public_contract |
| 3eadf798680f7cc51283 | tools/bench/wit-transfer/records.bnt:[914, 1414] | component | [] | public_contract |
| b8014f773f05ae7174e8 | tools/bench/wit-transfer/short-numbers-adapter.bnt:[691, 779] | component | [] | public_contract |
| 6efb2d35ae9e1eb75b5b | tools/bench/wit-transfer/short-numbers-typed.bnt:[505, 584] | component | [] | public_contract |
| 338a6027acc5f7e72cf0 | tools/bench/wit-transfer/short-numbers.bnt:[773, 901] | component | [] | public_contract |
| 1375ae21c79deb0fab71 | tools/bench/wit-transfer/tuples.bnt:[910, 1439] | component | [] | public_contract |
| 299569fa52177ee58136 | tools/bench/wit-transfer/utf16.bnt:[625, 768] | component | [] | public_contract |
| 9dc1cc8253f26e4a0f5f | tools/bench/wit-transfer/variants.bnt:[991, 1827] | component | [] | public_contract |
| 810c4a96929eac81482a | tools/skill-eval/tasks/csv_report/reference.bnt:[580, 618] | component | None | component_not_determined, conflicting_expectations, public_contract |
| eaa6182ba4774f548798 | tools/skill-eval/tasks/csv_report/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, nested_or_unresolved_contract, public_contract |
| 80db3831e980c5add082 | tools/skill-eval/tasks/csv_report/reference.bnt:[1283, 1325] | component | ['value'] | simultaneous_rename_capture |
| e894431ebd9f60debb4b | tools/skill-eval/tasks/csv_report/reference.bnt:[1235, 1339] | component | ['acc', 'value'] | simultaneous_rename_capture |
| 65504cf8ab266c31bd56 | tools/skill-eval/tasks/csv_report/reference.bnt:[755, 785] | call | ['o', 'fallback'] | pipe_requires_review |
| 11957594609f26b9584a | tools/skill-eval/tasks/csv_report/reference.bnt:[1047, 1082] | call | ['r', 'f'] | pipe_requires_review |
| 2137a8c65e534da9c445 | tools/skill-eval/tasks/csv_report/reference.bnt:[1131, 1173] | call | ['r', 'f'] | pipe_requires_review |
| e341f738e76b491ac49d | tools/skill-eval/tasks/csv_report/reference.bnt:[1195, 1340] | call | ['xs', 'initial', 'f'] | simultaneous_rename_capture |
| a3ad30c86e27f4834b54 | tools/skill-eval/tasks/csv_report/reference.bnt:[1263, 1326] | call | ['r', 'f'] | simultaneous_rename_capture |
| 99a5d5e60c46e52bd47e | tools/skill-eval/tasks/csv_report/reference.bnt:[1687, 1722] | call | ['r', 'f'] | pipe_requires_review |
| be803c85b213bf4f6cf2 | tools/skill-eval/tasks/csv_report/reference.bnt:[1945, 2042] | call | ['xs', 'initial', 'f'] | simultaneous_rename_capture |
| 28eb80b79289130cb232 | tools/skill-eval/tasks/dir_walk/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 916ac55080ff584c06d8 | tools/skill-eval/tasks/dir_walk/reference.bnt:[206, 241] | call | ['r', 'f'] | pipe_requires_review |
| 2d9ffcaa3321985f0a76 | tools/skill-eval/tasks/dir_walk/reference.bnt:[497, 532] | call | ['r', 'f'] | pipe_requires_review |
| ecb7888ca162bb375abf | tools/skill-eval/tasks/dir_walk/reference.bnt:[552, 572] | call | None | callee_contract_unresolved |
| 6169392046a1a46d3977 | tools/skill-eval/tasks/dir_walk/reference.bnt:[1287, 1322] | call | ['r', 'f'] | pipe_requires_review |
| 2b33dea8057f9fe5fe73 | tools/skill-eval/tasks/error_handling/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 933746ceb29d0b76c7b6 | tools/skill-eval/tasks/error_handling/reference.bnt:[720, 755] | call | ['r', 'f'] | pipe_requires_review |
| a254e192d13041ccc35f | tools/skill-eval/tasks/file_process/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| b738a732cd22225d8fe9 | tools/skill-eval/tasks/file_process/reference.bnt:None | component | None | component_not_determined, conflicting_expectations, public_contract |
| 0b26bdfee44c59f83e70 | tools/skill-eval/tasks/file_process/reference.bnt:[478, 513] | call | ['r', 'f'] | pipe_requires_review |
| f27944ee5c60c52b6795 | tools/skill-eval/tasks/file_process/reference.bnt:[744, 779] | call | ['r', 'f'] | pipe_requires_review |
| 3d03dfdc825a17de21a1 | tools/skill-eval/tasks/http_client/reference.bnt:[580, 618] | component | ['value'] | public_contract |
| a8456c9cdc44dcdd0930 | tools/skill-eval/tasks/http_client/reference.bnt:[1665, 1718] | component | None | component_not_determined, conflicting_expectations, public_contract |
| ec2e67df5e24ed1489ae | tools/skill-eval/tasks/http_client/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, nested_or_unresolved_contract, public_contract |
| 1d242a7524819f24d293 | tools/skill-eval/tasks/http_client/reference.bnt:[1625, 1730] | component | ['value'] | local_name_collision, simultaneous_rename_capture |
| b96a7ee1c04722b20cb9 | tools/skill-eval/tasks/http_client/reference.bnt:[1923, 1996] | component | ['value'] | local_name_collision |
| 577660082b4d6aa14f21 | tools/skill-eval/tasks/http_client/reference.bnt:[1810, 1861] | component | ['value'] | local_name_collision |
| 7a574b3f1a089fe92fe8 | tools/skill-eval/tasks/http_client/reference.bnt:[1579, 1744] | component | ['acc', 'value'] | local_name_collision, simultaneous_rename_capture |
| b1b289045d7f77bfd5b7 | tools/skill-eval/tasks/http_client/reference.bnt:[796, 824] | call | None | callee_contract_unresolved |
| cacb11ca6e9c7bb1ebbc | tools/skill-eval/tasks/http_client/reference.bnt:[1029, 1064] | call | ['r', 'f'] | pipe_requires_review |
| f2a6decbcf308b636156 | tools/skill-eval/tasks/http_client/reference.bnt:[1152, 1192] | call | ['r', 'f'] | pipe_requires_review |
| 8f3930c53d42d806730b | tools/skill-eval/tasks/http_client/reference.bnt:[1301, 1341] | call | ['r', 'f'] | pipe_requires_review |
| d8576f52578abe00a8b8 | tools/skill-eval/tasks/http_client/reference.bnt:[1397, 1440] | call | ['r', 'f'] | pipe_requires_review |
| 6d94010e99174afd25c6 | tools/skill-eval/tasks/http_client/reference.bnt:[1749, 1776] | call | ['r', 'f'] | pipe_requires_review |
| c251c26193f115a54259 | tools/skill-eval/tasks/http_client/reference.bnt:[1830, 1846] | call | None | callee_contract_unresolved |
| b15b1b9b1a90d60c672c | tools/skill-eval/tasks/http_client/reference.bnt:[1946, 1961] | call | None | callee_contract_unresolved |
| 7b383c975d2a4fe96ee8 | tools/skill-eval/tasks/http_client/reference.bnt:[1966, 1982] | call | None | callee_contract_unresolved |
| 7ca6c081fce7e4ec2b04 | tools/skill-eval/tasks/http_client/reference.bnt:[2099, 2115] | call | None | callee_contract_unresolved |
| 383f300fb8c72a3f8c5a | tools/skill-eval/tasks/http_client/reference.bnt:[2118, 2134] | call | None | callee_contract_unresolved |
| 647e9e1eb2dde2badf83 | tools/skill-eval/tasks/http_client/reference.bnt:[2235, 2250] | call | None | callee_contract_unresolved |
| 5529a7f48d7e8f06cef7 | tools/skill-eval/tasks/http_client/reference.bnt:[2436, 2476] | call | ['r', 'f'] | pipe_requires_review |
| 82c21698b1aa0ff36ed4 | tools/skill-eval/tasks/http_client/reference.bnt:[2508, 2535] | call | None | callee_contract_unresolved |
| 73d40c479a53eb080f48 | tools/skill-eval/tasks/json_convert/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, nested_or_unresolved_contract, public_contract |
| 0abda121cd559884c75e | tools/skill-eval/tasks/json_convert/reference.bnt:None | component | ['value'] | nested_or_unresolved_contract |
| 2ad0b5627b08b9197c62 | tools/skill-eval/tasks/json_convert/reference.bnt:[536, 571] | call | ['r', 'f'] | pipe_requires_review |
| 75aebcd35ca63cbaf550 | tools/skill-eval/tasks/json_convert/reference.bnt:[620, 662] | call | ['r', 'f'] | pipe_requires_review |
| 49818df562c1bcd607e6 | tools/skill-eval/tasks/json_convert/reference.bnt:[1111, 1146] | call | ['r', 'f'] | pipe_requires_review |
| 56283fd06fabde908a5d | tools/skill-eval/tasks/json_summary/reference.bnt:[1735, 1860] | component | ['key', 'value'] | local_name_collision |
| 89c9b2c4e5e6ceff14f6 | tools/skill-eval/tasks/json_summary/reference.bnt:[580, 618] | component | ['value'] | public_contract |
| d5c1c4b9cb28494e3626 | tools/skill-eval/tasks/json_summary/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, nested_or_unresolved_contract, public_contract |
| f68077f6340a7085e7cd | tools/skill-eval/tasks/json_summary/reference.bnt:[1651, 1697] | component | ['value'] | local_name_collision, simultaneous_rename_capture |
| ee3290d0c542c7c4e7ad | tools/skill-eval/tasks/json_summary/reference.bnt:[1601, 1711] | component | ['acc', 'value'] | local_name_collision, simultaneous_rename_capture |
| d36890aaeea9f13728a0 | tools/skill-eval/tasks/json_summary/reference.bnt:[972, 1002] | call | ['o', 'fallback'] | pipe_requires_review |
| 899f6c42319dca25cdd1 | tools/skill-eval/tasks/json_summary/reference.bnt:[1246, 1281] | call | ['r', 'f'] | pipe_requires_review |
| eeefa9d91647aa09e896 | tools/skill-eval/tasks/json_summary/reference.bnt:[1322, 1365] | call | ['r', 'f'] | pipe_requires_review |
| ee4692a54223b8de92ca | tools/skill-eval/tasks/process_run/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 8d1dd98198de17722274 | tools/skill-eval/tasks/process_run/reference.bnt:[248, 283] | call | ['r', 'f'] | pipe_requires_review |
| 90e1f85cc6d348a7438b | tools/skill-eval/tasks/process_run/reference.bnt:[474, 509] | call | ['r', 'f'] | pipe_requires_review |
| 44cc1db705ac50357209 | tools/skill-eval/tasks/process_run/reference.bnt:[539, 576] | call | None | callee_contract_unresolved |
| e363cf9b828a94975f16 | tools/skill-eval/tasks/process_run/reference.bnt:[741, 772] | call | None | callee_contract_unresolved |
| 342f2ae1c7a8455b0674 | tools/skill-eval/tasks/process_shell/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| f3beefd6fea07339b872 | tools/skill-eval/tasks/process_shell/reference.bnt:[252, 287] | call | ['r', 'f'] | pipe_requires_review |
| e67e77bf7ebda89c1dbb | tools/skill-eval/tasks/process_shell/reference.bnt:[322, 359] | call | None | callee_contract_unresolved |
| 6b587616d7c026f6b2ec | tools/skill-eval/tasks/process_shell/reference.bnt:[577, 612] | call | ['r', 'f'] | pipe_requires_review |
| b5a0720f21295f143f61 | tools/skill-eval/tasks/process_shell/reference.bnt:[628, 658] | call | None | callee_contract_unresolved |
| 9349493e65ad8ce2d225 | tools/skill-eval/tasks/regex_text/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 9c16f709fa095cd4bf8d | tools/skill-eval/tasks/regex_text/reference.bnt:[484, 570] | component | None | component_not_determined, conflicting_expectations, public_contract |
| 22f8dae27a8e5124db7b | tools/skill-eval/tasks/regex_text/reference.bnt:[232, 267] | call | ['r', 'f'] | pipe_requires_review |
| dca05a68254ec2dce6a0 | tools/skill-eval/tasks/write_tests/reference.bnt:[597, 627] | component | None | component_not_determined, conflicting_expectations, public_contract |
| e6d0d5ec7d9f2d743c28 | tools/skill-eval/tasks/write_tests/reference.bnt:[583, 618] | call | ['r', 'f'] | pipe_requires_review |

## N1 との照合

抽出器を変更したため、字句候補の数を AST の移行件数とは扱わない。元の全候補と合流を reconciliation.json に残し、対応する AST の候補または未一致の理由を記録する。

```json
{
  "baseline_join_kinds": {
    "list": 45,
    "return": 127,
    "if": 22
  },
  "join_status": {
    "held_extraction_or_context_difference": 67,
    "held_generated_input_regenerate_from_source": 127
  },
  "call_status": {
    "held_lexical_candidate_requires_review": 3556,
    "excluded_by_design": 1604,
    "matched": 417,
    "held_ambiguous_ast_candidates": 16
  },
  "generated_snapshot_count": 300
}
```
