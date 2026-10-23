# 版どうしの性能比較

候補: `4a4bb1ad86927dd8edd0e00dfe29c66b855554ef`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013420 | 0.000517 |
| functions-main-0-0 | after | 0.013576 | 0.000389 |
| functions-main-0-1 | before | 0.013107 | 0.000937 |
| functions-main-0-1 | after | 0.013202 | 0.000316 |
| functions-main-1000-0 | before | 0.030681 | 0.000278 |
| functions-main-1000-0 | after | 0.030861 | 0.000193 |
| functions-main-1000-1 | before | 0.030674 | 0.000112 |
| functions-main-1000-1 | after | 0.031074 | 0.000400 |
| functions-args-0-0 | before | 0.013153 | 0.000635 |
| functions-args-0-0 | after | 0.013196 | 0.000242 |
| functions-args-0-1 | before | 0.013202 | 0.000304 |
| functions-args-0-1 | after | 0.013083 | 0.000349 |
| functions-args-1000-0 | before | 0.047493 | 0.000429 |
| functions-args-1000-0 | after | 0.047935 | 0.000446 |
| functions-args-1000-1 | before | 0.047490 | 0.000467 |
| functions-args-1000-1 | after | 0.048164 | 0.000896 |
| functions-modules-0-0 | before | 0.013151 | 0.000467 |
| functions-modules-0-0 | after | 0.013082 | 0.000268 |
| functions-modules-0-1 | before | 0.013254 | 0.000153 |
| functions-modules-0-1 | after | 0.013028 | 0.000175 |
| functions-modules-1000-0 | before | 0.024272 | 0.000299 |
| functions-modules-1000-0 | after | 0.024885 | 0.001137 |
| functions-modules-1000-1 | before | 0.024327 | 0.000143 |
| functions-modules-1000-1 | after | 0.024464 | 0.000558 |
| existing-fib | before | 0.014016 | 0.000795 |
| existing-fib | after | 0.013611 | 0.000059 |
| existing-loop | before | 0.013601 | 0.000950 |
| existing-loop | after | 0.013651 | 0.000108 |
| existing-string | before | 0.013786 | 0.000923 |
| existing-string | after | 0.013592 | 0.000191 |
| higher-0-0 | before | 0.013102 | 0.000687 |
| higher-0-0 | after | 0.013073 | 0.000268 |
| higher-1-0 | before | 0.014187 | 0.000363 |
| higher-1-0 | after | 0.014080 | 0.000215 |
| classes-0 | before | 0.019086 | 0.000298 |
| classes-0 | after | 0.019208 | 0.000845 |
| higher-0-300 | before | 0.026601 | 0.000225 |
| higher-0-300 | after | 0.026665 | 0.002217 |
| higher-1-300 | before | 0.029278 | 0.000241 |
| higher-1-300 | after | 0.029902 | 0.000617 |
| classes-300 | before | 0.037783 | 0.000609 |
| classes-300 | after | 0.038243 | 0.000623 |
| depth-0-8 | before | 0.014510 | 0.000312 |
| depth-0-8 | after | 0.014535 | 0.000154 |
| depth-1-8 | before | 0.014841 | 0.000415 |
| depth-1-8 | after | 0.014671 | 0.000107 |
| f1-nofail-call | before | 0.014111 | 0.000542 |
| f1-nofail-call | after | 0.014122 | 0.000286 |
| f1-join-effects | before | 0.014118 | 0.000688 |
| f1-join-effects | after | 0.014157 | 0.000431 |
| control-16.3 | before | 0.013068 | 0.000168 |
| control-16.3 | after | 0.012977 | 0.000214 |
| property-seven-24-20-1000-all-ok | before | 0.039685 | 0.001223 |
| property-seven-24-20-1000-all-ok | after | 0.039447 | 0.000506 |
| property-seven-24-20-1000-always-error | before | 0.038378 | 0.000751 |
| property-seven-24-20-1000-always-error | after | 0.038080 | 0.000204 |
| property-distinct-24-20-1000-all-ok | before | 0.038666 | 0.000568 |
| property-distinct-24-20-1000-all-ok | after | 0.038968 | 0.000435 |
| property-distinct-24-20-1000-always-error | before | 0.038301 | 0.000598 |
| property-distinct-24-20-1000-always-error | after | 0.037987 | 0.000411 |
| property-zero-24-20-1000-all-ok | before | 0.039194 | 0.000563 |
| property-zero-24-20-1000-all-ok | after | 0.039224 | 0.000358 |
| property-zero-24-20-1000-always-error | before | 0.038132 | 0.000711 |
| property-zero-24-20-1000-always-error | after | 0.037997 | 0.000482 |
| property-max-24-20-1000-all-ok | before | 0.039504 | 0.001315 |
| property-max-24-20-1000-all-ok | after | 0.039666 | 0.000265 |
| property-max-24-20-1000-always-error | before | 0.038338 | 0.000954 |
| property-max-24-20-1000-always-error | after | 0.038111 | 0.000242 |
| order-string-candidates | before | 0.038019 | 0.001137 |
| order-string-candidates | after | 0.038071 | 0.000398 |
| order-string-all-ok | before | 0.038660 | 0.000891 |
| order-string-all-ok | after | 0.038814 | 0.000425 |
| order-string-always-error | before | 0.038290 | 0.000899 |
| order-string-always-error | after | 0.037829 | 0.000463 |
| order-map-candidates | before | 0.038486 | 0.001063 |
| order-map-candidates | after | 0.038364 | 0.000555 |
| order-map-all-ok | before | 0.038508 | 0.001192 |
| order-map-all-ok | after | 0.038622 | 0.000318 |
| order-map-always-error | before | 0.038376 | 0.000780 |
| order-map-always-error | after | 0.038377 | 0.000507 |
| order-record-candidates | before | 0.038616 | 0.000972 |
| order-record-candidates | after | 0.038866 | 0.000497 |
| order-record-all-ok | before | 0.038741 | 0.001057 |
| order-record-all-ok | after | 0.038746 | 0.000400 |
| order-record-always-error | before | 0.039032 | 0.001302 |
| order-record-always-error | after | 0.038996 | 0.000151 |
| build-string-builder-8-0 | before | 0.015841 | 0.000239 |
| build-string-builder-8-0 | after | 0.015996 | 0.000201 |
| build-string-builder-all-8-0 | before | 0.016112 | 0.000366 |
| build-string-builder-all-8-0 | after | 0.015931 | 0.000101 |
| build-string-concatenate-8-0 | before | 0.015770 | 0.000340 |
| build-string-concatenate-8-0 | after | 0.015834 | 0.000141 |
| build-string-join-8-0 | before | 0.015860 | 0.000481 |
| build-string-join-8-0 | after | 0.015980 | 0.000277 |
| build-list-builder-8-0 | before | 0.016129 | 0.000426 |
| build-list-builder-8-0 | after | 0.016031 | 0.000171 |
| build-list-builder-all-8-0 | before | 0.016049 | 0.000235 |
| build-list-builder-all-8-0 | after | 0.016016 | 0.000151 |
| build-list-concatenate-8-0 | before | 0.016051 | 0.000317 |
| build-list-concatenate-8-0 | after | 0.016063 | 0.000210 |
| build-list-fold-8-0 | before | 0.016047 | 0.000330 |
| build-list-fold-8-0 | after | 0.015972 | 0.000081 |
| build-bytes-builder-8-0 | before | 0.015940 | 0.000385 |
| build-bytes-builder-8-0 | after | 0.015958 | 0.000141 |
| build-bytes-builder-all-8-0 | before | 0.016000 | 0.000575 |
| build-bytes-builder-all-8-0 | after | 0.016143 | 0.000132 |
| build-bytes-concatenate-8-0 | before | 0.016200 | 0.000380 |
| build-bytes-concatenate-8-0 | after | 0.016113 | 0.000139 |
| patterns-integer-100 | before | 0.014461 | 0.000958 |
| patterns-integer-100 | after | 0.014420 | 0.000084 |
| codegen-let-100 | before | 0.016971 | 0.000194 |
| codegen-let-100 | after | 0.016788 | 0.000147 |
| bridge-shared-8 | before | 0.004910 | 0.000545 |
| bridge-shared-8 | after | 0.004852 | 0.000543 |
| external-tests-normal-1 | before | 0.018263 | 0.000277 |
| external-tests-normal-1 | after | 0.018234 | 0.001611 |
| runtime-fib-short | before | 0.017857 | 0.000251 |
| runtime-fib-short | after | 0.017897 | 0.000648 |
| runtime-loop-short | before | 0.023437 | 0.000236 |
| runtime-loop-short | after | 0.023774 | 0.000954 |
| runtime-list-short | before | 0.029160 | 0.000379 |
| runtime-list-short | after | 0.029360 | 0.000598 |
| runtime-tree-short | before | 0.018393 | 0.000357 |
| runtime-tree-short | after | 0.018420 | 0.000860 |
| runtime-eval-short | before | 0.022183 | 0.000367 |
| runtime-eval-short | after | 0.022045 | 0.000475 |
| runtime-string-short | before | 0.016852 | 0.000288 |
| runtime-string-short | after | 0.016702 | 0.000077 |
| runtime-println-short | before | 0.017144 | 0.000763 |
| runtime-println-short | after | 0.017031 | 0.000606 |
| runtime-lines-short | before | 0.016725 | 0.000177 |
| runtime-lines-short | after | 0.016740 | 0.000135 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.625e-05 | 1.166e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.208e-06 | 3.74e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.9458e-05 | 1.874e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.2792e-05 | 6.25e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.55e-05 | 8.33e-07 |
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
    "after": "4a4bb1ad86927dd8edd0e00dfe29c66b855554ef"
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
| functions-main-1000-0 | 判定不能 | None | 0.0030681166999997345 |
| functions-main-1000-1 | 判定不能 | None | 0.0030673792000001756 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004749266700000022 |
| functions-args-1000-1 | 判定不能 | None | 0.004748970800000052 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002427174999999693 |
| functions-modules-1000-1 | 判定不能 | None | 0.002432712499999923 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0026600833999992804 |
| higher-1-300 | 判定不能 | None | 0.002927758299999539 |
| classes-300 | 判定不能 | None | 0.0037783082999993667 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0039684665999999424 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003837762499999542 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003866600000000631 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038300709000012034 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0039194083000012375 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003813212500000418 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003950387499999409 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0038338207999998987 |
| order-string-candidates | 判定不能 | None | 0.003801854200000321 |
| order-string-all-ok | 判定不能 | None | 0.0038660165999999663 |
| order-string-always-error | 判定不能 | None | 0.0038289833000007436 |
| order-map-candidates | 判定不能 | None | 0.0038486457999994173 |
| order-map-all-ok | 判定不能 | None | 0.003850820899999974 |
| order-map-always-error | 判定不能 | None | 0.0038375916999996208 |
| order-record-candidates | 判定不能 | None | 0.003861570800000891 |
| order-record-all-ok | 判定不能 | None | 0.0038741000000001692 |
| order-record-always-error | 判定不能 | None | 0.003903208399999869 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0023437208999993685 |
| runtime-list-short | 判定不能 | None | 0.002916016700000057 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.00221830830000016 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002 |
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
    "verify": 1.8388008330000076,
    "cli": 5.288609832000034,
    "warmup": 0.6590243360000017,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9096750829999962,
    "cli": 3.601252333000005,
    "warmup": 0.4283709140000127,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3357195410000031,
    "cli": 9.329895961000005,
    "warmup": 1.328879331000067,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3642739579999983,
    "cli": 3.5050122060000035,
    "warmup": 0.3552716249999719,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09746633299999985,
    "cli": 0.2772750419999994,
    "warmup": 0.0290069999999929,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03626237499999263,
    "cli": 0.3274180840000014,
    "warmup": 0.0338644580000107,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009067333000004396,
    "cli": 0.21202400000001376,
    "warmup": 0.008809125000013296,
    "probe_warmup": 0.008380415999994284,
    "rss": 0,
    "stages": 0.03936254199999212,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04107283400000483,
    "cli": 0.34752712499999916,
    "warmup": 0.036733125000012024,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18000112499997556
  },
  "runtime": {
    "verify": 0.33171412500000486,
    "cli": 2.899969208000016,
    "warmup": 0.3273270820000391,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
