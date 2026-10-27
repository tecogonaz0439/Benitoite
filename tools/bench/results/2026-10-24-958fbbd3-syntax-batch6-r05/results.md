# 版どうしの性能比較

候補: `958fbbd3228c8d379304fea16f4c00129a026a3b`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013855 | 0.000470 |
| functions-main-0-0 | after | 0.013834 | 0.000386 |
| functions-main-0-1 | before | 0.013751 | 0.000819 |
| functions-main-0-1 | after | 0.013794 | 0.000209 |
| functions-main-1000-0 | before | 0.031905 | 0.000442 |
| functions-main-1000-0 | after | 0.032297 | 0.000614 |
| functions-main-1000-1 | before | 0.031773 | 0.000261 |
| functions-main-1000-1 | after | 0.031998 | 0.001078 |
| functions-args-0-0 | before | 0.013953 | 0.001162 |
| functions-args-0-0 | after | 0.013762 | 0.000365 |
| functions-args-0-1 | before | 0.013828 | 0.001414 |
| functions-args-0-1 | after | 0.013755 | 0.000213 |
| functions-args-1000-0 | before | 0.048616 | 0.001103 |
| functions-args-1000-0 | after | 0.048989 | 0.000913 |
| functions-args-1000-1 | before | 0.049766 | 0.001114 |
| functions-args-1000-1 | after | 0.048669 | 0.000491 |
| functions-modules-0-0 | before | 0.014517 | 0.000999 |
| functions-modules-0-0 | after | 0.014407 | 0.000516 |
| functions-modules-0-1 | before | 0.014092 | 0.002552 |
| functions-modules-0-1 | after | 0.013811 | 0.000047 |
| functions-modules-1000-0 | before | 0.025358 | 0.000638 |
| functions-modules-1000-0 | after | 0.025547 | 0.000989 |
| functions-modules-1000-1 | before | 0.025872 | 0.000362 |
| functions-modules-1000-1 | after | 0.026065 | 0.001986 |
| existing-fib | before | 0.014375 | 0.001046 |
| existing-fib | after | 0.014174 | 0.000476 |
| existing-loop | before | 0.014849 | 0.001138 |
| existing-loop | after | 0.014487 | 0.000511 |
| existing-string | before | 0.015101 | 0.001703 |
| existing-string | after | 0.014454 | 0.000153 |
| higher-0-0 | before | 0.015024 | 0.000620 |
| higher-0-0 | after | 0.014652 | 0.000660 |
| higher-1-0 | before | 0.014664 | 0.001163 |
| higher-1-0 | after | 0.014929 | 0.000500 |
| classes-0 | before | 0.020080 | 0.000762 |
| classes-0 | after | 0.020224 | 0.001994 |
| higher-0-300 | before | 0.027627 | 0.000422 |
| higher-0-300 | after | 0.027686 | 0.002295 |
| higher-1-300 | before | 0.030270 | 0.001241 |
| higher-1-300 | after | 0.030119 | 0.000529 |
| classes-300 | before | 0.038680 | 0.000658 |
| classes-300 | after | 0.039114 | 0.001237 |
| depth-0-8 | before | 0.015618 | 0.000691 |
| depth-0-8 | after | 0.015501 | 0.000475 |
| depth-1-8 | before | 0.015710 | 0.000551 |
| depth-1-8 | after | 0.016079 | 0.000355 |
| f1-nofail-call | before | 0.015316 | 0.000954 |
| f1-nofail-call | after | 0.015193 | 0.000429 |
| f1-join-effects | before | 0.015160 | 0.001007 |
| f1-join-effects | after | 0.015162 | 0.000235 |
| control-16.3 | before | 0.014824 | 0.000960 |
| control-16.3 | after | 0.014266 | 0.000623 |
| property-seven-24-20-1000-all-ok | before | 0.040699 | 0.002526 |
| property-seven-24-20-1000-all-ok | after | 0.041788 | 0.001248 |
| property-seven-24-20-1000-always-error | before | 0.039461 | 0.003253 |
| property-seven-24-20-1000-always-error | after | 0.039906 | 0.000943 |
| property-distinct-24-20-1000-all-ok | before | 0.041601 | 0.001425 |
| property-distinct-24-20-1000-all-ok | after | 0.040898 | 0.000989 |
| property-distinct-24-20-1000-always-error | before | 0.042455 | 0.001772 |
| property-distinct-24-20-1000-always-error | after | 0.040218 | 0.001057 |
| property-zero-24-20-1000-all-ok | before | 0.040246 | 0.001659 |
| property-zero-24-20-1000-all-ok | after | 0.040208 | 0.001507 |
| property-zero-24-20-1000-always-error | before | 0.041181 | 0.002852 |
| property-zero-24-20-1000-always-error | after | 0.040340 | 0.000292 |
| property-max-24-20-1000-all-ok | before | 0.042165 | 0.004020 |
| property-max-24-20-1000-all-ok | after | 0.042280 | 0.001249 |
| property-max-24-20-1000-always-error | before | 0.039215 | 0.001032 |
| property-max-24-20-1000-always-error | after | 0.040035 | 0.000864 |
| order-string-candidates | before | 0.039294 | 0.001382 |
| order-string-candidates | after | 0.039157 | 0.000962 |
| order-string-all-ok | before | 0.039907 | 0.003081 |
| order-string-all-ok | after | 0.040402 | 0.000539 |
| order-string-always-error | before | 0.040040 | 0.002106 |
| order-string-always-error | after | 0.039120 | 0.000989 |
| order-map-candidates | before | 0.041376 | 0.001094 |
| order-map-candidates | after | 0.042045 | 0.001347 |
| order-map-all-ok | before | 0.041714 | 0.002770 |
| order-map-all-ok | after | 0.040534 | 0.000823 |
| order-map-always-error | before | 0.039825 | 0.001326 |
| order-map-always-error | after | 0.039836 | 0.001126 |
| order-record-candidates | before | 0.040426 | 0.001267 |
| order-record-candidates | after | 0.040051 | 0.000373 |
| order-record-all-ok | before | 0.042290 | 0.002469 |
| order-record-all-ok | after | 0.041660 | 0.001637 |
| order-record-always-error | before | 0.042452 | 0.001290 |
| order-record-always-error | after | 0.041439 | 0.001065 |
| build-string-builder-8-0 | before | 0.017870 | 0.001044 |
| build-string-builder-8-0 | after | 0.017903 | 0.000879 |
| build-string-builder-all-8-0 | before | 0.017804 | 0.000434 |
| build-string-builder-all-8-0 | after | 0.018079 | 0.001007 |
| build-string-concatenate-8-0 | before | 0.017037 | 0.000331 |
| build-string-concatenate-8-0 | after | 0.017061 | 0.001186 |
| build-string-join-8-0 | before | 0.016382 | 0.000432 |
| build-string-join-8-0 | after | 0.016275 | 0.000275 |
| build-list-builder-8-0 | before | 0.016824 | 0.000214 |
| build-list-builder-8-0 | after | 0.016638 | 0.000927 |
| build-list-builder-all-8-0 | before | 0.016684 | 0.001201 |
| build-list-builder-all-8-0 | after | 0.016947 | 0.000547 |
| build-list-concatenate-8-0 | before | 0.016999 | 0.001108 |
| build-list-concatenate-8-0 | after | 0.016978 | 0.001090 |
| build-list-fold-8-0 | before | 0.016958 | 0.000719 |
| build-list-fold-8-0 | after | 0.017262 | 0.001522 |
| build-bytes-builder-8-0 | before | 0.017853 | 0.000393 |
| build-bytes-builder-8-0 | after | 0.017615 | 0.000793 |
| build-bytes-builder-all-8-0 | before | 0.018333 | 0.000824 |
| build-bytes-builder-all-8-0 | after | 0.018321 | 0.001135 |
| build-bytes-concatenate-8-0 | before | 0.017813 | 0.000790 |
| build-bytes-concatenate-8-0 | after | 0.017183 | 0.001632 |
| patterns-integer-100 | before | 0.014987 | 0.001539 |
| patterns-integer-100 | after | 0.015033 | 0.000393 |
| codegen-let-100 | before | 0.017836 | 0.000626 |
| codegen-let-100 | after | 0.017408 | 0.001042 |
| bridge-shared-8 | before | 0.004830 | 0.000220 |
| bridge-shared-8 | after | 0.004737 | 0.000377 |
| external-tests-normal-1 | before | 0.019021 | 0.000332 |
| external-tests-normal-1 | after | 0.018919 | 0.001013 |
| runtime-fib-short | before | 0.020162 | 0.000666 |
| runtime-fib-short | after | 0.020609 | 0.004048 |
| runtime-loop-short | before | 0.026954 | 0.001096 |
| runtime-loop-short | after | 0.027094 | 0.000579 |
| runtime-list-short | before | 0.031227 | 0.001308 |
| runtime-list-short | after | 0.031521 | 0.001124 |
| runtime-tree-short | before | 0.019434 | 0.000816 |
| runtime-tree-short | after | 0.020298 | 0.001277 |
| runtime-eval-short | before | 0.026247 | 0.001901 |
| runtime-eval-short | after | 0.027097 | 0.003977 |
| runtime-string-short | before | 0.019332 | 0.001420 |
| runtime-string-short | after | 0.019035 | 0.002529 |
| runtime-println-short | before | 0.018550 | 0.001494 |
| runtime-println-short | after | 0.019303 | 0.001652 |
| runtime-lines-short | before | 0.018124 | 0.000833 |
| runtime-lines-short | after | 0.017560 | 0.001430 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.425e-05 | 5.42e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.084e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.7375e-05 | 1.042e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4542e-05 | 7.91e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.041e-06 | 1.25e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7542e-05 | 6.66e-07 |
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
    "before": "706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8",
    "after": "958fbbd3228c8d379304fea16f4c00129a026a3b"
  },
  "features": {
    "before": {
      "shrink_steps": true,
      "builders": true,
      "timing_probe": true
    },
    "after": {
      "shrink_steps": true,
      "builders": true,
      "timing_probe": true
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
| functions-main-1000-0 | 判定不能 | None | 0.0031905207999983532 |
| functions-main-1000-1 | 判定不能 | None | 0.003177333399997906 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0048616166000016395 |
| functions-args-1000-1 | 判定不能 | None | 0.00497661250000192 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0025357667000008633 |
| functions-modules-1000-1 | 判定不能 | None | 0.0025872499999991306 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002008041599998478 |
| higher-0-300 | 判定不能 | None | 0.002762662499998214 |
| higher-1-300 | 判定不能 | None | 0.0030269707999991628 |
| classes-300 | 判定不能 | None | 0.0038680458000015963 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.004069870800000786 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003946074999998927 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0041601417000009635 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.00424551250000036 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.004024566700002197 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.004118099999999458 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.004216462499999807 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003921487499999899 |
| order-string-candidates | 判定不能 | None | 0.003929404100000511 |
| order-string-all-ok | 判定不能 | None | 0.00399071660000061 |
| order-string-always-error | 判定不能 | None | 0.004004041700000016 |
| order-map-candidates | 判定不能 | None | 0.004137608299998874 |
| order-map-all-ok | 判定不能 | None | 0.004171416600001976 |
| order-map-always-error | 判定不能 | None | 0.0039824500000008815 |
| order-record-candidates | 判定不能 | None | 0.004042649999999526 |
| order-record-all-ok | 判定不能 | None | 0.0042289667000005695 |
| order-record-always-error | 判定不能 | None | 0.004245212500001117 |
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
| runtime-fib-short | 判定不能 | None | 0.002016187499998523 |
| runtime-loop-short | 判定不能 | None | 0.0026954250000017057 |
| runtime-list-short | 判定不能 | None | 0.003122737499998607 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002624708400000486 |
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
    "verify": 2.3854615420000016,
    "cli": 5.563753832999993,
    "warmup": 0.6872877489999496,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9345587500000079,
    "cli": 3.8314312510000264,
    "warmup": 0.44854033400005733,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3746285839999928,
    "cli": 9.870420456999994,
    "warmup": 1.3787589590000096,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3825397499999781,
    "cli": 3.8146662069999593,
    "warmup": 0.3829572090000113,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10199933299998065,
    "cli": 0.29050820800000565,
    "warmup": 0.03133729199998925,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04040912499999649,
    "cli": 0.34370691699999156,
    "warmup": 0.03478141700000492,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010225541000011162,
    "cli": 0.20798104200000012,
    "warmup": 0.00878979200001595,
    "probe_warmup": 0.008032624000009037,
    "rss": 0,
    "stages": 0.039223957999979575,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04317337500000917,
    "cli": 0.3589739580000071,
    "warmup": 0.03580066600000009,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.19551758100007532
  },
  "runtime": {
    "verify": 0.3450654160000113,
    "cli": 3.2689040829999954,
    "warmup": 0.3595773739999686,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
