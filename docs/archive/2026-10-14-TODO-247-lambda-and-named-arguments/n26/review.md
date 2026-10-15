# N26 移行確認表

147 件の通常の複数引数呼び出しと、4 ラムダの改名を確認した。公開・内部の外側の宣言名は変更していない。

## 確認の根拠

- `manifest.json` は確認済みの 149 候補（呼び出し 147、ラムダの成分 2）。適用時の SHA-256 は `232de1238dd853304eb54a1d29474a24be88a235074a49bc4f24e66d03a23784`。
- `individual-manifest.json` は Map.fold の局所の別名と HTTP の生成元の例。SHA-256 は `dde07e1dd6d09614e426edf8d392f8efb395978888e873b7dae3e2cf7e9827cf`。
- 両 manifest はハッシュ・範囲の検査を通して順に適用した。`.applied.json` はそれぞれの適用直後の受領記録であり、前者は中間状態を記録する。
- `migration.diff` と `individual.diff` は、それぞれ確認した段の差分である。元の未確認の抽出は `inventory.json` に残す。
- `reconciliation.json` は N1 の標準ライブラリの 188 字句候補を全件分類した記録である。通常の関数 147、直接の構成子・パターン・宣言 36、レコード構築 5。同じ行の同名呼び出しは組全体で確認し、N20 で移った List.append は現在の appendToList と対応付けた。
- `contracts.json` と `contract-summary.json` は 52 モジュール・564 宣言の表との照合結果である。宣言行は基準のコミットと同一で、内側の関数型 56 件とラムダ 12 件も調べた。
- 全呼び出しを AST で確認した。複数引数の通常呼び出しは名前付き 147 件、直接の位置構成子は 17 件、零・一引数は 152 件である。
- 二度目の抽出は全 52 入力の型検査が成功し、編集 0 件であった。`second-pass.diff` は空である。

## 個別に解消した保留

Trait の Show[List]・Show[Map]・Show[Set] のラムダは、List.map の明示済みの `value` に合わせた。名前解決した三つの束縛と参照だけを変更し、文字列や入れ子の別の束縛は変えていない。これらを含む成分と依存する呼び出しの元の保留理由と解消の理由は、manifest の `original_hold_reasons` と `review_resolution` に残す。

二度目の抽出に残る三つの保守的な保留には編集がない。applyFrom の fs 内の型はすでに `function(value: A)` であり、そこから得る f も List.map の value に適合する。Option の apply 内の f(v) も、fs に含まれる同じ一引数型を使う。関数値の出どころの自動追跡を広げず、宣言と型検査で最終契約を確認した。移行の保留は残さない。

## テストの作成時の関門

| 追加するテスト | 守る契約と想定する退行 | 既存のテストでは届かない理由 | 本番の差し込み口 |
|---|---|---|---|
| `test_named_contracts_and_reordered_arguments_need_no_second_migration` | 移行済みの名前付き型と、順を変えた名前付き呼び出しに追加の編集を出さない。既存のラベルや型へ名前を重ねて挿入する退行を検出する | N17 の適用のテストは旧入力と同じ manifest の再適用を調べ、移行後のソースの再抽出を調べない | 追加なし。本物の道具と処理系を使う |
| `test_stdlib_module_identity_and_non_prelude_contracts` | UnsignedInteger64 の AST を別のモジュールと取り違えず、HTTP の呼び出しの契約とソース位置を得る | N17 の入力は利用者のファイルだけであり、標準モジュールの読み込みと選択を通らない | 追加なし。既存の読み取り用 example の入口を使う |
| `standard_library_calls_do_not_migrate_legacy_user_input` | 標準の本体が名前付きでも旧入力を corpus 7 に保ち、利用者の名前付き入力は corpus 8 へ出す | 既存の全件書き出しは長い検査に限られる。通常の書き出しの成功例は正の名前付き入力だけである | 追加なし。一般の解析・型検査と既存の書き出しの境界を使う |

三つのテストは修正前に想定した理由で失敗し、修正後に成功することを確認した。既存の assert・期待値・ignore は変更していない。テストの削除はない。本番の公開 API の追加と型・シグネチャの変更もない。

## 候補ごとの判断

状態の `approved` は確認して適用した候補、`unchanged` は既存の最終契約のため編集不要、`individually verified` は前節の個別確認で編集不要と判断した候補である。

| ID | ファイル・元の行またはバイト位置 | 種類 | 契約名 | 判断 |
|---|---|---|---|---|
| 777f9c855d67722bdd1a | IO/File.bnt:69 | call | path, content | approved |
| b632a8cdfb312d0204bc | Integer64.bnt:20 | call | a, b | approved |
| 65220c6c8c99c4bb768c | Integer64.bnt:25 | call | a, b | approved |
| 3d83a7f09d686be6f200 | Integer64.bnt:35 | call | a, b | approved |
| 13ddf075d362808430bc | Integer64.bnt:40 | call | a, b | approved |
| 0be601090bf274e07c83 | Integer64.bnt:45 | call | a, b | approved |
| 7239b0da12759a019f37 | Integer64.bnt:50 | call | a, b | approved |
| 56e99860fada7a64ebbd | Integer64.bnt:55 | call | a, b | approved |
| e878addf0655175394bd | Integer64.bnt:65 | call | a, n | approved |
| 3382f5fe81cdc4d682ef | Integer64.bnt:70 | call | a, n | approved |
| 36ec4a019724227c8758 | Integer64.bnt:75 | call | a, n | approved |
| 8d058e2914065584ab3e | Json.bnt:36 | call | m, k | approved |
| 2432948b07b1c7419605 | Json.bnt:44 | call | xs, i | approved |
| b530b9550fbe949c9b16 | List.bnt:byte 2217 | component | value | unchanged |
| 2d6113499851b2766841 | List.bnt:byte 2731 | component | value | unchanged |
| ab8fd0db63381dba748b | List.bnt:byte 3349 | component | acc, value | unchanged |
| 9190b04ea50e412d9b65 | List.bnt:byte 3815 | component | value | unchanged |
| 5ae1bfa393c157547220 | List.bnt:byte 4321 | component | value | unchanged |
| 3581f362824e28f50e27 | List.bnt:byte 4823 | component | value | unchanged |
| 080ec224291c65c93cd9 | List.bnt:byte 5325 | component | value | unchanged |
| a2784ceda7397527776e | List.bnt:61 | call | xs, f, i, acc | approved |
| acf18b882eee539d08ac | List.bnt:65 | call | xs, i | approved |
| 2ed88d33bce974e4a3c9 | List.bnt:69 | call | xs, f, i, acc | approved |
| 07f0503703486e316041 | List.bnt:69 | call | xs, x | approved |
| 479fcf20774b93773264 | List.bnt:75 | call | xs, p, i, acc | approved |
| 64632720eb70a08c0c0a | List.bnt:79 | call | xs, i | approved |
| 4be4cc35a518e4c1d8db | List.bnt:83 | call | xs, p, i, acc | approved |
| 93f750b29e64d6a6b587 | List.bnt:83 | call | xs, x | approved |
| 2b665eb72b589109bdbc | List.bnt:85 | call | xs, p, i, acc | approved |
| 7987382a6f06de800696 | List.bnt:92 | call | xs, acc, f, i | approved |
| 64e58c6f8028787620af | List.bnt:96 | call | xs, i | approved |
| 25a36188e1168c121785 | List.bnt:98 | call | xs, acc, f, i | approved |
| 5c1b472378b31118df8c | List.bnt:98 | call | acc, value | approved |
| 8a9b35129fa1b882ef4f | List.bnt:104 | call | xs, f, i | approved |
| e9bd77907aff488d3127 | List.bnt:108 | call | xs, i | approved |
| ef743accce7214e4ce22 | List.bnt:112 | call | xs, f, i | approved |
| 7a45c5d72f2ec6c34916 | List.bnt:118 | call | xs, p, i | approved |
| 8d6da91099515211bd2f | List.bnt:122 | call | xs, i | approved |
| 6c767c00f60f9ec8f8b7 | List.bnt:124 | call | xs, p, i | approved |
| 6fbb927a4c1a65ac34f5 | List.bnt:130 | call | xs, p, i | approved |
| 9bd26086b56ab5195f41 | List.bnt:134 | call | xs, i | approved |
| 272f32e9cc7af59ff08c | List.bnt:136 | call | xs, p, i | approved |
| 59020e21e90d4d73eade | List.bnt:142 | call | xs, p, i | approved |
| 0d69fb216a407af2ae09 | List.bnt:146 | call | xs, i | approved |
| 6a09e17cbae76bc5f462 | List.bnt:152 | call | xs, p, i | approved |
| aa32a489254bd72b9d1b | Map.bnt:44 | component | key, value | unchanged |
| b5cdd7ac8ed1d5965e5c | Map.bnt:49 | component | key, value | unchanged |
| 6352f45b4d6f1a6c3b61 | Map.bnt:54 | component | acc, key, value | unchanged |
| 5794025950b85dba6ddf | Map.bnt:59 | component | key, value | unchanged |
| 0c62eeb1734f7b29462e | Map.bnt:45 | component | value | unchanged |
| e81e5589861accc310c2 | Map.bnt:50 | component | value | unchanged |
| 99b1f22d1ce00f95ed81 | Map.bnt:55 | component | acc, value | unchanged |
| ecbf2d93baf2e9185ebd | Map.bnt:60 | component | value | unchanged |
| 4574b7d558dbe1141b1d | Map.bnt:45 | call | xs, f | approved |
| 230442765d64aef2f40c | Map.bnt:45 | call | key, value | approved |
| 0849171676555c17f78b | Map.bnt:50 | call | xs, p | approved |
| c7cb9c572824d034f6e8 | Map.bnt:50 | call | key, value | approved |
| 5edc95f4fbfccec9aabc | Map.bnt:55 | call | xs, initial, f | approved |
| 7ec304d0976b9a0cb082 | Map.bnt:55 | call | acc, key, value | approved |
| e6e4fc48ad21c539471a | Map.bnt:60 | call | xs, f | approved |
| d1ba5d1c3b42ebe30d96 | Map.bnt:60 | call | key, value | approved |
| 9f5387cd6d7b485408a4 | Network/Http.bnt:81 | component |  | unchanged |
| f6661bbe9ec2fecedeba | Network/Http.bnt:byte 3259 | component | request | unchanged |
| f3c608d0493820e278a1 | Network/Http.bnt:107 | component | value | approved |
| e4e4e29b2f7fe39da229 | Network/Http.bnt:73 | call | host, port | approved |
| b03f36855e72701c84d1 | Network/Http.bnt:75 | call | listener, group, handler | approved |
| 625a9701113f01ce09ce | Network/Http.bnt:81 | call | group, action | approved |
| b2bc209611635573c48d | Network/Http.bnt:83 | call | exchange, response | approved |
| ebbe4425df069b3e16d1 | Network/Http.bnt:86 | call | listener, group, handler | approved |
| 9f4e0cfecbffbb985c59 | Network/Http.bnt:107 | call | xs, p | approved |
| f9a9caa294f3b785d43c | Network/Http.bnt:120 | call | method, url | approved |
| c4d62729ca7841bcb43c | Option.bnt:10 | component | value | unchanged |
| 870b2f82c7cc19c775ed | Option.bnt:18 | component | value | unchanged |
| ea968ecb035646f75461 | Reference.bnt:17 | component | value | unchanged |
| 070590fa0726a89116c2 | Regex.bnt:byte 2583 | component | matched | unchanged |
| a7c4b4db748332fdfb75 | Regex.bnt:18 | call | pattern, text, start, afterMatch, acc | approved |
| 94d363b2e91436dea5ac | Regex.bnt:47 | call | pattern, text, replacement, start, afterMatch, parts | approved |
| 98495646eee1ff0d2829 | Regex.bnt:52 | call | pattern, text, start, afterMatch, acc | approved |
| 7536711c9d9bbc9944db | Regex.bnt:57 | call | pattern, text, f, start, afterMatch, parts | approved |
| 5109e102dcb553310987 | Regex.bnt:70 | call | pattern, text, start, afterMatch | approved |
| 306b0c95d3a84d3273be | Regex.bnt:72 | call | pattern, text, start, afterMatch, acc | approved |
| c3e8d5f26ff53e2e0c83 | Regex.bnt:72 | call | xs, x | approved |
| b4edd37becc046f25339 | Regex.bnt:77 | call | pattern, text, start, afterMatch | approved |
| 45b22a3dec66964e5961 | Regex.bnt:78 | call | xs, x | approved |
| affdd8d07b7c3ae0c793 | Regex.bnt:78 | call | text, start, stop | approved |
| fa6778708ef3974b210f | Regex.bnt:79 | call | pattern, text, start, afterMatch, acc | approved |
| 3d5e86d220ef94907aec | Regex.bnt:79 | call | xs, x | approved |
| fa2bff0ef531baa7cf4a | Regex.bnt:79 | call | text, start, stop | approved |
| 8d12d91c613c2982eac9 | Regex.bnt:84 | call | pattern, text, start, afterMatch | approved |
| 7a41e8c0d010a5faa1ba | Regex.bnt:85 | call | parts, part | approved |
| 7c8fb25c831dda14c3fa | Regex.bnt:85 | call | text, start, stop | approved |
| 113adefafbfbb3397f78 | Regex.bnt:87 | call | parts, part | approved |
| 9681f3149590de478f65 | Regex.bnt:87 | call | parts, part | approved |
| 41a1ad1951d87e1097e1 | Regex.bnt:87 | call | text, start, stop | approved |
| c6e54f12305ab1418788 | Regex.bnt:88 | call | pattern, text, replacement, start, afterMatch, parts | approved |
| 5260f97a50e8083e0933 | Regex.bnt:93 | call | pattern, text, start, afterMatch | approved |
| b4b0ecb4a5c0398df09c | Regex.bnt:94 | call | parts, part | approved |
| 9ee381069f5da3d2f9b5 | Regex.bnt:94 | call | text, start, stop | approved |
| 62938b59fc3f91a4e711 | Regex.bnt:97 | call | parts, part | approved |
| a1e48249a5e4fe41cbd2 | Regex.bnt:97 | call | parts, part | approved |
| a56052383ff955bf9ecb | Regex.bnt:97 | call | text, start, stop | approved |
| 3a016ae8a61685fe7c2c | Regex.bnt:98 | call | pattern, text, f, start, afterMatch, parts | approved |
| e050014e90d57007fbcd | Regex.bnt:108 | call | xs, x | approved |
| d99d3cdd7ab458d5d4e0 | Regex.bnt:114 | call | xs, x | approved |
| d3eafae859fcc4c31daa | Regex.bnt:114 | call | xs, separator | approved |
| b8d903b38522f8d9a6b1 | Regex.bnt:122 | call | xs, separator | approved |
| 19466bd1e735f52a4cf3 | Regex.bnt:122 | call | xs, x | approved |
| 7977978ea6334bcceccd | Regex.bnt:122 | call | xs, separator | approved |
| e31383790e872a33f060 | Regex.bnt:126 | call | o, fallback | approved |
| 52e5a84d564b33b308a4 | Regex.bnt:126 | call | s, start, stop | approved |
| 263dc1bbec0d2897dcf0 | Result.bnt:10 | component | value | unchanged |
| f85be6003506b5fd45d2 | Result.bnt:18 | component | error | unchanged |
| d2bc2ad1a34f8abc0a5f | Result.bnt:26 | component | value | unchanged |
| 8ff3a06c26eab6af2ffd | Set.bnt:byte 1587 | component | value | unchanged |
| b7b49d6e6637019908f7 | Set.bnt:byte 1802 | component | value | unchanged |
| c45a05555ba54d6cb3dd | Set.bnt:byte 2054 | component | acc, value | unchanged |
| 111d6153931ccaf2a2f3 | Set.bnt:byte 2260 | component | value | unchanged |
| 407e8b72800d6f20a91f | Set.bnt:45 | call | xs, f | approved |
| 9a32cc224fbc9ea07d6e | Set.bnt:50 | call | xs, p | approved |
| fb993539c40c961c75b2 | Set.bnt:55 | call | xs, initial, f | approved |
| cfeaf27ccdaf17a1f355 | Set.bnt:60 | call | xs, f | approved |
| babe5ffe682ada1dd39d | Task.bnt:20 | component |  | unchanged |
| b9736c1848160a3281d6 | Task.bnt:7 | component |  | unchanged |
| bd6a4fd85c4706e97cbd | Task.bnt:12 | component |  | unchanged |
| 0c0e7811b0912a40c145 | Task.bnt:16 | component |  | unchanged |
| 93a2bc870d8b7f9e6d35 | TaskGroup.bnt:9 | component |  | unchanged |
| 37cf0d0715aea3039e17 | Trait.bnt:byte 11367 | component | value | unchanged |
| 82f3dd58ac91d3544253 | Trait.bnt:byte 11949 | component | value | unchanged |
| 172a100a5d55cf627f40 | Trait.bnt:393 | component | value | unchanged |
| 4c668fc6e4f0dadadb42 | Trait.bnt:408 | component | acc, value | unchanged |
| 81eb3690ab1ec440db0b | Trait.bnt:417 | component | value | unchanged |
| 96a6ef0fc2320521f1b5 | Trait.bnt:byte 1250 | component | value | unchanged |
| 0f135e82bc11efb664ca | Trait.bnt:438 | component | value | unchanged |
| 4a15d2c0cbe21e0274b9 | Trait.bnt:byte 13292 | component | value | individually verified |
| 3e239ba5ef70d79928bf | Trait.bnt:byte 13636 | component | value | unchanged |
| bb7e56fedd633aea4a42 | Trait.bnt:byte 14365 | component | value | unchanged |
| 50f97cd17553fb92c408 | Trait.bnt:51 | component | value | unchanged |
| 7f661fbbec4250aa12cd | Trait.bnt:525 | component | value | unchanged |
| cf4ae1045f92948fd796 | Trait.bnt:57 | component | acc, value | unchanged |
| 727a1d3a1839c2cd63cb | Trait.bnt:63 | component | value | unchanged |
| e36fec0bdbbac9b048bd | Trait.bnt:420 | component | value | unchanged |
| 7d9ab5893450c53f98dd | Trait.bnt:166 | component | value | approved |
| cf14856a96d7b22e9834 | Trait.bnt:byte 14149 | component | acc, value | unchanged |
| 8127ae61423796147bf0 | Trait.bnt:166 | call | xs, f | approved |
| 9659b9c1b4f6ee608a0c | Trait.bnt:167 | call | xs, separator | approved |
| 40bbe199b9f166256c4d | Trait.bnt:300 | call | x, y, i | approved |
| 5b5bf68f2cfa38e8bc63 | Trait.bnt:305 | call | xs, i | approved |
| 86a288f62c034e48735c | Trait.bnt:305 | call | xs, i | approved |
| da76fc76d116c242dea9 | Trait.bnt:310 | call | x, y | approved |
| a7b1c9bf8a8b1e797328 | Trait.bnt:311 | call | x, y, i | approved |
| 1eae491ba8f0cc12100a | Trait.bnt:320 | call | x, y | approved |
| 16b86386f93d50c830ef | Trait.bnt:332 | call | x, y | approved |
| f3474f1b52034d791d71 | Trait.bnt:333 | call | x, y | approved |
| bfaf67d85c81e170602e | Trait.bnt:343 | call | x, y | approved |
| 11a94d60dcb0024d7368 | Trait.bnt:345 | call | x, y | approved |
| ace2869623a0560f8116 | Trait.bnt:346 | call | x, y | approved |
| d7f142fbc4f920da29fd | Trait.bnt:370 | call | xs, ys | approved |
| f6deae0a66b5c827a9fd | Trait.bnt:384 | call | o, f | approved |
| d124e7969486c89b71f7 | Trait.bnt:395 | call |  | individually verified |
| f9a9e603e3d128b5af5c | Trait.bnt:403 | call | o, f | approved |
| 1cd0137e080e7d191a8e | Trait.bnt:410 | call | acc, value | approved |
| 47c49b416d02d87b3177 | Trait.bnt:420 | call | x, f | approved |
| b7afca5b49c42026cbac | Trait.bnt:429 | call | xs, f | approved |
| 127d3ee85c1366192906 | Trait.bnt:439 | call | fs, xs, i, acc | approved |
| 416143ff32c5bfe15ccf | Trait.bnt:444 | call | xs, i | approved |
| c173a9e8b400556ef7ec | Trait.bnt:446 | call | fs, xs, i, acc | approved |
| 1e2f892195cd2b632e52 | Trait.bnt:446 | call | xs, ys | approved |
| f5ac79a8fd746b9b7f12 | Trait.bnt:446 | call | xs, f | approved |
| ac09954332b55d11a581 | Trait.bnt:452 | call | xs, f, i, acc | approved |
| 63ca9fa10b805fad8d19 | Trait.bnt:457 | call | xs, i | approved |
| a0487a51655bf714a4a2 | Trait.bnt:459 | call | xs, f, i, acc | approved |
| b3b1abcb1e537ebd7937 | Trait.bnt:459 | call | xs, ys | approved |
| 39db320e9ecebb53dbfc | Trait.bnt:465 | call | xs, initial, f | approved |
| c35738a87f532228bfd6 | Trait.bnt:471 | call | xs, f, i, acc | approved |
| 56ffe9494e50dea96cb6 | Trait.bnt:476 | call | xs, i | approved |
| ba0dcabdb117e314ab6f | Trait.bnt:479 | call | x, f | approved |
| 3fdf40d0bf3d5fcfb0b1 | Trait.bnt:480 | call | xs, f, i, acc | approved |
| 3d781fddaf67c145e5e7 | Trait.bnt:480 | call | fs, x | approved |
| c74c8d910d83e701d403 | Trait.bnt:488 | call | xs, f | approved |
| 064dc97f41cf886b1f6a | Trait.bnt:489 | call | xs, separator | approved |
| 7b25e8bc8bafaa3e4a55 | Trait.bnt:495 | call | xs, f | approved |
| 04a147c720a543c4b35e | Trait.bnt:496 | call | xs, separator | approved |
| 2e50dce3bd5fe3f74490 | Trait.bnt:502 | call | xs, ys | approved |
| abbd8f9764ff6312bf89 | Trait.bnt:514 | call | a, b | approved |
| 2c28f7cfbd18249f4458 | Trait.bnt:525 | call | xs, x | approved |
| 9fcfebe96b2c35e25ae7 | UnsignedInteger.bnt:45 | call | a, b | approved |
| 6664f09091b43481d98b | UnsignedInteger.bnt:50 | call | a, b | approved |
| 56391e34de1399b2521f | UnsignedInteger.bnt:55 | call | a, b | approved |
| 5fe9837914f5d425082c | UnsignedInteger.bnt:60 | call | a, b | approved |
| 048666d50f918d87ff3b | UnsignedInteger.bnt:65 | call | a, b | approved |
| 73039fb948852884f986 | UnsignedInteger.bnt:70 | call | a, b | approved |
| 48b4c5e2682d729f97f3 | UnsignedInteger.bnt:75 | call | a, b | approved |
| 9416cf8b50d6038dbda6 | UnsignedInteger.bnt:85 | call | a, n | approved |
| 108e27ec89d6c8907305 | UnsignedInteger.bnt:90 | call | a, n | approved |
| 39379b7a9d2aa1ca6452 | UnsignedInteger8.bnt:20 | call | a, b | approved |
| ebb660051fae196f9a6f | UnsignedInteger8.bnt:25 | call | a, b | approved |
| 290e6f6287c8fa4b8c00 | UnsignedInteger8.bnt:30 | call | a, b | approved |
| 56dd7da89649f498df1c | UnsignedInteger8.bnt:40 | call | a, n | approved |
| 0d2a8037183f77d36bef | UnsignedInteger8.bnt:45 | call | a, n | approved |
