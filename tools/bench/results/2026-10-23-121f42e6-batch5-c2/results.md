# 版どうしの性能比較

候補: `121f42e675da43362d0664a3be40539f36824856`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013175 | 0.000240 |
| functions-main-0-0 | after | 0.013415 | 0.000577 |
| functions-main-0-1 | before | 0.013126 | 0.000494 |
| functions-main-0-1 | after | 0.013399 | 0.000207 |
| functions-main-1000-0 | before | 0.030667 | 0.000686 |
| functions-main-1000-0 | after | 0.032085 | 0.000791 |
| functions-main-1000-1 | before | 0.030560 | 0.000104 |
| functions-main-1000-1 | after | 0.031662 | 0.000197 |
| functions-args-0-0 | before | 0.013141 | 0.000961 |
| functions-args-0-0 | after | 0.013362 | 0.000098 |
| functions-args-0-1 | before | 0.013213 | 0.000470 |
| functions-args-0-1 | after | 0.013434 | 0.000143 |
| functions-args-1000-0 | before | 0.047585 | 0.000629 |
| functions-args-1000-0 | after | 0.048336 | 0.000581 |
| functions-args-1000-1 | before | 0.047586 | 0.000650 |
| functions-args-1000-1 | after | 0.048537 | 0.000555 |
| functions-modules-0-0 | before | 0.013082 | 0.000613 |
| functions-modules-0-0 | after | 0.013439 | 0.000060 |
| functions-modules-0-1 | before | 0.013138 | 0.000403 |
| functions-modules-0-1 | after | 0.013441 | 0.000082 |
| functions-modules-1000-0 | before | 0.024267 | 0.000181 |
| functions-modules-1000-0 | after | 0.025154 | 0.000650 |
| functions-modules-1000-1 | before | 0.024311 | 0.000768 |
| functions-modules-1000-1 | after | 0.025576 | 0.000485 |
| existing-fib | before | 0.013734 | 0.000375 |
| existing-fib | after | 0.014004 | 0.000130 |
| existing-loop | before | 0.013812 | 0.000568 |
| existing-loop | after | 0.013974 | 0.000123 |
| existing-string | before | 0.013708 | 0.000733 |
| existing-string | after | 0.013934 | 0.000087 |
| higher-0-0 | before | 0.013237 | 0.000563 |
| higher-0-0 | after | 0.013466 | 0.000107 |
| higher-1-0 | before | 0.014195 | 0.001017 |
| higher-1-0 | after | 0.014308 | 0.000131 |
| classes-0 | before | 0.019002 | 0.000476 |
| classes-0 | after | 0.019618 | 0.000661 |
| higher-0-300 | before | 0.026291 | 0.000270 |
| higher-0-300 | after | 0.028500 | 0.000429 |
| higher-1-300 | before | 0.029316 | 0.000962 |
| higher-1-300 | after | 0.031292 | 0.000631 |
| classes-300 | before | 0.037573 | 0.000723 |
| classes-300 | after | 0.039557 | 0.000565 |
| depth-0-8 | before | 0.014463 | 0.000707 |
| depth-0-8 | after | 0.014964 | 0.000130 |
| depth-1-8 | before | 0.014810 | 0.000570 |
| depth-1-8 | after | 0.015039 | 0.000129 |
| f1-nofail-call | before | 0.014073 | 0.000526 |
| f1-nofail-call | after | 0.014462 | 0.000186 |
| f1-join-effects | before | 0.014618 | 0.000624 |
| f1-join-effects | after | 0.014890 | 0.000827 |
| control-16.3 | before | 0.013606 | 0.000497 |
| control-16.3 | after | 0.013755 | 0.000191 |
| property-seven-24-20-1000-all-ok | before | 0.039917 | 0.001110 |
| property-seven-24-20-1000-all-ok | after | 0.041252 | 0.000289 |
| property-seven-24-20-1000-always-error | before | 0.038767 | 0.001185 |
| property-seven-24-20-1000-always-error | after | 0.039406 | 0.000877 |
| property-distinct-24-20-1000-all-ok | before | 0.038751 | 0.000514 |
| property-distinct-24-20-1000-all-ok | after | 0.040007 | 0.000401 |
| property-distinct-24-20-1000-always-error | before | 0.038107 | 0.000941 |
| property-distinct-24-20-1000-always-error | after | 0.039279 | 0.000322 |
| property-zero-24-20-1000-all-ok | before | 0.039385 | 0.001079 |
| property-zero-24-20-1000-all-ok | after | 0.040604 | 0.000043 |
| property-zero-24-20-1000-always-error | before | 0.037918 | 0.001264 |
| property-zero-24-20-1000-always-error | after | 0.039428 | 0.000257 |
| property-max-24-20-1000-all-ok | before | 0.039508 | 0.000763 |
| property-max-24-20-1000-all-ok | after | 0.040751 | 0.000175 |
| property-max-24-20-1000-always-error | before | 0.038061 | 0.000560 |
| property-max-24-20-1000-always-error | after | 0.039801 | 0.000609 |
| order-string-candidates | before | 0.038026 | 0.000655 |
| order-string-candidates | after | 0.039248 | 0.000221 |
| order-string-all-ok | before | 0.038575 | 0.001016 |
| order-string-all-ok | after | 0.039804 | 0.000196 |
| order-string-always-error | before | 0.038245 | 0.000897 |
| order-string-always-error | after | 0.039307 | 0.000367 |
| order-map-candidates | before | 0.038367 | 0.001320 |
| order-map-candidates | after | 0.039361 | 0.000307 |
| order-map-all-ok | before | 0.038601 | 0.001152 |
| order-map-all-ok | after | 0.039692 | 0.000295 |
| order-map-always-error | before | 0.038354 | 0.000427 |
| order-map-always-error | after | 0.039605 | 0.000326 |
| order-record-candidates | before | 0.038948 | 0.000958 |
| order-record-candidates | after | 0.039886 | 0.000303 |
| order-record-all-ok | before | 0.038805 | 0.000851 |
| order-record-all-ok | after | 0.040073 | 0.000324 |
| order-record-always-error | before | 0.038788 | 0.000701 |
| order-record-always-error | after | 0.040256 | 0.000457 |
| build-string-builder-8-0 | before | 0.016073 | 0.000815 |
| build-string-builder-8-0 | after | 0.016131 | 0.000122 |
| build-string-builder-all-8-0 | before | 0.016059 | 0.000234 |
| build-string-builder-all-8-0 | after | 0.016343 | 0.000266 |
| build-string-concatenate-8-0 | before | 0.015864 | 0.000380 |
| build-string-concatenate-8-0 | after | 0.016047 | 0.000189 |
| build-string-join-8-0 | before | 0.015664 | 0.000295 |
| build-string-join-8-0 | after | 0.016069 | 0.000127 |
| build-list-builder-8-0 | before | 0.015830 | 0.000365 |
| build-list-builder-8-0 | after | 0.016272 | 0.000158 |
| build-list-builder-all-8-0 | before | 0.015813 | 0.000275 |
| build-list-builder-all-8-0 | after | 0.016334 | 0.000224 |
| build-list-concatenate-8-0 | before | 0.016095 | 0.000399 |
| build-list-concatenate-8-0 | after | 0.016487 | 0.000181 |
| build-list-fold-8-0 | before | 0.016053 | 0.000442 |
| build-list-fold-8-0 | after | 0.016315 | 0.000220 |
| build-bytes-builder-8-0 | before | 0.015915 | 0.000360 |
| build-bytes-builder-8-0 | after | 0.016342 | 0.000307 |
| build-bytes-builder-all-8-0 | before | 0.016383 | 0.000346 |
| build-bytes-builder-all-8-0 | after | 0.016464 | 0.000146 |
| build-bytes-concatenate-8-0 | before | 0.016128 | 0.000341 |
| build-bytes-concatenate-8-0 | after | 0.016515 | 0.000345 |
| patterns-integer-100 | before | 0.014488 | 0.000539 |
| patterns-integer-100 | after | 0.014665 | 0.000176 |
| codegen-let-100 | before | 0.016942 | 0.000176 |
| codegen-let-100 | after | 0.017191 | 0.000052 |
| bridge-shared-8 | before | 0.004442 | 0.000044 |
| bridge-shared-8 | after | 0.004320 | 0.000374 |
| external-tests-normal-1 | before | 0.017999 | 0.000238 |
| external-tests-normal-1 | after | 0.018290 | 0.000808 |
| runtime-fib-short | before | 0.017839 | 0.000254 |
| runtime-fib-short | after | 0.018420 | 0.000743 |
| runtime-loop-short | before | 0.023661 | 0.000336 |
| runtime-loop-short | after | 0.023640 | 0.000706 |
| runtime-list-short | before | 0.029172 | 0.000187 |
| runtime-list-short | after | 0.029786 | 0.000933 |
| runtime-tree-short | before | 0.018166 | 0.000315 |
| runtime-tree-short | after | 0.018599 | 0.001299 |
| runtime-eval-short | before | 0.021942 | 0.000182 |
| runtime-eval-short | after | 0.022575 | 0.000440 |
| runtime-string-short | before | 0.016826 | 0.000175 |
| runtime-string-short | after | 0.016998 | 0.000227 |
| runtime-println-short | before | 0.017121 | 0.000211 |
| runtime-println-short | after | 0.017300 | 0.000105 |
| runtime-lines-short | before | 0.016584 | 0.000252 |
| runtime-lines-short | after | 0.017001 | 0.000065 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5334e-05 | 6.67e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.916e-06 | 2.5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8209e-05 | 6.67e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4291e-05 | 4.58e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.042e-06 | 4.17e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7333e-05 | 9.17e-07 |
| unique_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | after | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | after | 5 | 7 | 0 |
| runtime_compilations | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| runtime_compilations | count | external-tests-normal-1 | after | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | after | 5 | 1 | 0 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a",
    "after": "121f42e675da43362d0664a3be40539f36824856"
  },
  "features": {
    "before": {
      "shrink_steps": true,
      "builders": true
    },
    "after": {
      "shrink_steps": true,
      "builders": true
    }
  },
  "skipped": [],
  "unavailable_probes": {}
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| functions-main-0-0 | 判定不能 | None | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.0030667000000008217 |
| functions-main-1000-1 | 達成 | 0.001101583000007622 | 0.003055999999999415 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004758529200000795 |
| functions-args-1000-1 | 判定不能 | None | 0.004758583299999942 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.0008868339999992259 | 0.0024267125000008607 |
| functions-modules-1000-1 | 達成 | 0.0012654169999990472 | 0.0024311083000000625 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0022090830000109918 | 0.002629129199999625 |
| higher-1-300 | 達成 | 0.001976207999987878 | 0.002931558400000256 |
| classes-300 | 達成 | 0.001983916000000363 | 0.003757258400000296 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003991679199999965 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003876725000000647 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.001255916000005186 | 0.0038750583999998867 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038106666999993878 |
| property-zero-24-20-1000-all-ok | 達成 | 0.0012183750000076543 | 0.0039385499999994526 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003791820799999357 |
| property-max-24-20-1000-all-ok | 達成 | 0.0012424170000002732 | 0.0039508083000001195 |
| property-max-24-20-1000-always-error | 達成 | 0.0017397509999881322 | 0.0038060958000002646 |
| order-string-candidates | 達成 | 0.0012224170000081358 | 0.0038025707999992165 |
| order-string-all-ok | 達成 | 0.0012287920000062513 | 0.003857487499999479 |
| order-string-always-error | 判定不能 | None | 0.0038245457999991576 |
| order-map-candidates | 判定不能 | None | 0.003836745899999983 |
| order-map-all-ok | 判定不能 | None | 0.003860070799998994 |
| order-map-always-error | 達成 | 0.001251375999999027 | 0.0038353665999991907 |
| order-record-candidates | 判定不能 | None | 0.0038947667000002184 |
| order-record-all-ok | 達成 | 0.0012678339999894206 | 0.0038805125000010324 |
| order-record-always-error | 達成 | 0.0014684999999872161 | 0.003878787500001124 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 達成 | 0.0005207079999962616 | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0023661250000003523 |
| runtime-list-short | 判定不能 | None | 0.002917233399999475 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 達成 | 0.0006333740000172838 | 0.0021942083999988427 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 達成 | 0.00041654300000004696 | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 達成 | 0.00024979100000166454 | 0.002 |
| bridge-shared-8 | 判定不能 | None | 0.002 |
| external-tests-normal-1 | 判定不能 | None | 0.002 |

時間差が2 ms未満、非正、または両標本集合のIQRの和以下なら比率は判定不能。確保量と整数計数には2 msを適用しない。標本数不足も合格にしない。

## 別実行と未取得

段別時間は補助バイナリのload_parse・resolve・typeck。読み込みとlex/parseは公開loaderの一つの区間に含む。reparseは同じ読み込み済みバイト列の別パスであり、load_parseへ加算しない。
RSSは既存rss.pyの独立実行。alloc-statsは別targetのバイナリ。全標本・照合出力・コマンドはsection JSONに保存する。
Fail正規化の内部訪問節数・縮小器内部の生成/比較回数は未取得。shrinksとshrinkWorkは実出力から検査する。
samplyはprofile.shの別実行で取得する。未取得のプロファイルから原因を断定しない。

## 段ごとの外側時間

```json
{
  "16.2": {
    "verify": 1.8283644579999958,
    "cli": 5.34496670999998,
    "warmup": 0.6657620370000075,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9161216659999951,
    "cli": 3.6634861640000054,
    "warmup": 0.43672254199999827,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3717692499999998,
    "cli": 9.455131500000022,
    "warmup": 1.3450044560000123,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36348241700000017,
    "cli": 3.5441584170000056,
    "warmup": 0.35912199899998143,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09826654200000462,
    "cli": 0.28165350000000444,
    "warmup": 0.02984095799999409,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03610991700000454,
    "cli": 0.3296066670000073,
    "warmup": 0.03463154099999599,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009128791999998498,
    "cli": 0.20138074999999844,
    "warmup": 0.008852625000017156,
    "probe_warmup": 0.0078007080000048745,
    "rss": 0,
    "stages": 0.03831221099999027,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.041278458000007845,
    "cli": 0.3423578750000047,
    "warmup": 0.03593812399999763,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17908545600002412
  },
  "runtime": {
    "verify": 0.33185954200000367,
    "cli": 2.9148444579999904,
    "warmup": 0.32796629100000985,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
