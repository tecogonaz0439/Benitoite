# 版どうしの性能比較

候補: `c4b3f0262dc8683705e61fab58e1e1a4d49d36a6`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013724 | 0.000967 |
| functions-main-0-0 | after | 0.014064 | 0.000218 |
| functions-main-0-1 | before | 0.013734 | 0.000642 |
| functions-main-0-1 | after | 0.014143 | 0.000239 |
| functions-main-1000-0 | before | 0.031388 | 0.000379 |
| functions-main-1000-0 | after | 0.032604 | 0.000334 |
| functions-main-1000-1 | before | 0.032171 | 0.001075 |
| functions-main-1000-1 | after | 0.032296 | 0.000432 |
| functions-args-0-0 | before | 0.013875 | 0.000848 |
| functions-args-0-0 | after | 0.013837 | 0.000285 |
| functions-args-0-1 | before | 0.013720 | 0.001001 |
| functions-args-0-1 | after | 0.013858 | 0.000180 |
| functions-args-1000-0 | before | 0.048366 | 0.000439 |
| functions-args-1000-0 | after | 0.048948 | 0.000260 |
| functions-args-1000-1 | before | 0.048095 | 0.000752 |
| functions-args-1000-1 | after | 0.048588 | 0.000276 |
| functions-modules-0-0 | before | 0.013647 | 0.000999 |
| functions-modules-0-0 | after | 0.013990 | 0.000293 |
| functions-modules-0-1 | before | 0.013829 | 0.000435 |
| functions-modules-0-1 | after | 0.014081 | 0.000401 |
| functions-modules-1000-0 | before | 0.024778 | 0.000271 |
| functions-modules-1000-0 | after | 0.025769 | 0.000659 |
| functions-modules-1000-1 | before | 0.025042 | 0.000244 |
| functions-modules-1000-1 | after | 0.025902 | 0.000799 |
| existing-fib | before | 0.014336 | 0.000714 |
| existing-fib | after | 0.014563 | 0.000338 |
| existing-loop | before | 0.014428 | 0.001113 |
| existing-loop | after | 0.014523 | 0.000370 |
| existing-string | before | 0.014588 | 0.000781 |
| existing-string | after | 0.014575 | 0.000169 |
| higher-0-0 | before | 0.013583 | 0.000975 |
| higher-0-0 | after | 0.014015 | 0.000193 |
| higher-1-0 | before | 0.015249 | 0.000756 |
| higher-1-0 | after | 0.014934 | 0.000112 |
| classes-0 | before | 0.019606 | 0.000497 |
| classes-0 | after | 0.020095 | 0.001021 |
| higher-0-300 | before | 0.027085 | 0.000242 |
| higher-0-300 | after | 0.028292 | 0.000891 |
| higher-1-300 | before | 0.029860 | 0.000390 |
| higher-1-300 | after | 0.030753 | 0.000774 |
| classes-300 | before | 0.038583 | 0.000604 |
| classes-300 | after | 0.039114 | 0.000892 |
| depth-0-8 | before | 0.015376 | 0.000604 |
| depth-0-8 | after | 0.015323 | 0.000091 |
| depth-1-8 | before | 0.015269 | 0.000780 |
| depth-1-8 | after | 0.015345 | 0.000424 |
| f1-nofail-call | before | 0.014798 | 0.000564 |
| f1-nofail-call | after | 0.014826 | 0.000201 |
| f1-join-effects | before | 0.014471 | 0.000727 |
| f1-join-effects | after | 0.014685 | 0.000239 |
| control-16.3 | before | 0.013521 | 0.000442 |
| control-16.3 | after | 0.013683 | 0.000162 |
| property-seven-24-20-1000-all-ok | before | 0.040195 | 0.001109 |
| property-seven-24-20-1000-all-ok | after | 0.040755 | 0.000208 |
| property-seven-24-20-1000-always-error | before | 0.039217 | 0.000997 |
| property-seven-24-20-1000-always-error | after | 0.039671 | 0.001369 |
| property-distinct-24-20-1000-all-ok | before | 0.039691 | 0.001583 |
| property-distinct-24-20-1000-all-ok | after | 0.040003 | 0.000120 |
| property-distinct-24-20-1000-always-error | before | 0.038511 | 0.001050 |
| property-distinct-24-20-1000-always-error | after | 0.038956 | 0.000245 |
| property-zero-24-20-1000-all-ok | before | 0.039894 | 0.001223 |
| property-zero-24-20-1000-all-ok | after | 0.040005 | 0.000246 |
| property-zero-24-20-1000-always-error | before | 0.038742 | 0.001240 |
| property-zero-24-20-1000-always-error | after | 0.038880 | 0.000425 |
| property-max-24-20-1000-all-ok | before | 0.039720 | 0.000956 |
| property-max-24-20-1000-all-ok | after | 0.040509 | 0.000389 |
| property-max-24-20-1000-always-error | before | 0.038721 | 0.000868 |
| property-max-24-20-1000-always-error | after | 0.039034 | 0.000509 |
| order-string-candidates | before | 0.038483 | 0.000812 |
| order-string-candidates | after | 0.038664 | 0.000270 |
| order-string-all-ok | before | 0.038870 | 0.001314 |
| order-string-all-ok | after | 0.039327 | 0.000315 |
| order-string-always-error | before | 0.038330 | 0.001309 |
| order-string-always-error | after | 0.039059 | 0.000295 |
| order-map-candidates | before | 0.038699 | 0.001488 |
| order-map-candidates | after | 0.039139 | 0.000085 |
| order-map-all-ok | before | 0.038849 | 0.001140 |
| order-map-all-ok | after | 0.039535 | 0.000284 |
| order-map-always-error | before | 0.038886 | 0.001411 |
| order-map-always-error | after | 0.039149 | 0.000345 |
| order-record-candidates | before | 0.039319 | 0.000986 |
| order-record-candidates | after | 0.039671 | 0.000248 |
| order-record-all-ok | before | 0.039360 | 0.000702 |
| order-record-all-ok | after | 0.040031 | 0.000622 |
| order-record-always-error | before | 0.039406 | 0.001348 |
| order-record-always-error | after | 0.039872 | 0.000251 |
| build-string-builder-8-0 | before | 0.016430 | 0.000223 |
| build-string-builder-8-0 | after | 0.016384 | 0.000380 |
| build-string-builder-all-8-0 | before | 0.016390 | 0.000315 |
| build-string-builder-all-8-0 | after | 0.016635 | 0.001453 |
| build-string-concatenate-8-0 | before | 0.016440 | 0.000157 |
| build-string-concatenate-8-0 | after | 0.016468 | 0.000325 |
| build-string-join-8-0 | before | 0.016546 | 0.000309 |
| build-string-join-8-0 | after | 0.016585 | 0.000258 |
| build-list-builder-8-0 | before | 0.016504 | 0.000215 |
| build-list-builder-8-0 | after | 0.016804 | 0.000633 |
| build-list-builder-all-8-0 | before | 0.016525 | 0.000277 |
| build-list-builder-all-8-0 | after | 0.016540 | 0.000149 |
| build-list-concatenate-8-0 | before | 0.016498 | 0.000444 |
| build-list-concatenate-8-0 | after | 0.016743 | 0.000117 |
| build-list-fold-8-0 | before | 0.016451 | 0.000441 |
| build-list-fold-8-0 | after | 0.016653 | 0.000205 |
| build-bytes-builder-8-0 | before | 0.016432 | 0.000267 |
| build-bytes-builder-8-0 | after | 0.016596 | 0.000253 |
| build-bytes-builder-all-8-0 | before | 0.016673 | 0.000491 |
| build-bytes-builder-all-8-0 | after | 0.016843 | 0.000235 |
| build-bytes-concatenate-8-0 | before | 0.016865 | 0.000256 |
| build-bytes-concatenate-8-0 | after | 0.016800 | 0.000126 |
| patterns-integer-100 | before | 0.014803 | 0.000903 |
| patterns-integer-100 | after | 0.015215 | 0.000116 |
| codegen-let-100 | before | 0.017304 | 0.000133 |
| codegen-let-100 | after | 0.017696 | 0.000095 |
| bridge-shared-8 | before | 0.004844 | 0.000127 |
| bridge-shared-8 | after | 0.004775 | 0.000401 |
| external-tests-normal-1 | before | 0.018487 | 0.000303 |
| external-tests-normal-1 | after | 0.018896 | 0.000781 |
| runtime-fib-short | before | 0.018494 | 0.000277 |
| runtime-fib-short | after | 0.018620 | 0.000571 |
| runtime-loop-short | before | 0.024154 | 0.000099 |
| runtime-loop-short | after | 0.024169 | 0.001360 |
| runtime-list-short | before | 0.029613 | 0.000159 |
| runtime-list-short | after | 0.030200 | 0.000314 |
| runtime-tree-short | before | 0.018661 | 0.000293 |
| runtime-tree-short | after | 0.019191 | 0.000713 |
| runtime-eval-short | before | 0.022426 | 0.000173 |
| runtime-eval-short | after | 0.023303 | 0.000973 |
| runtime-string-short | before | 0.017283 | 0.000311 |
| runtime-string-short | after | 0.017532 | 0.000625 |
| runtime-println-short | before | 0.017648 | 0.000338 |
| runtime-println-short | after | 0.017765 | 0.000910 |
| runtime-lines-short | before | 0.017163 | 0.000191 |
| runtime-lines-short | after | 0.017263 | 0.000340 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.6417e-05 | 1.583e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.291e-06 | 5.42e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.925e-05 | 1.917e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4459e-05 | 7.91e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.875e-06 | 2.92e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7334e-05 | 1.083e-06 |
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
    "after": "c4b3f0262dc8683705e61fab58e1e1a4d49d36a6"
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
| functions-main-1000-0 | 達成 | 0.001215667000010967 | 0.0031387957999996275 |
| functions-main-1000-1 | 判定不能 | None | 0.0032171458000007647 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004836645800000383 |
| functions-args-1000-1 | 判定不能 | None | 0.004809520800000655 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.0009909580000169171 | 0.0024777708999991436 |
| functions-modules-1000-1 | 判定不能 | None | 0.002504183300000307 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0012074580000103197 | 0.0027084500000000844 |
| higher-1-300 | 判定不能 | None | 0.0029860207999988122 |
| classes-300 | 判定不能 | None | 0.0038582583000007276 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.004019508400000405 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0039216874999993935 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003969091700000149 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003851129199999548 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003989445800000624 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038741999999999167 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003971954200000028 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003872129100000166 |
| order-string-candidates | 判定不能 | None | 0.0038482874999999695 |
| order-string-all-ok | 判定不能 | None | 0.0038869874999988953 |
| order-string-always-error | 判定不能 | None | 0.003833045899999377 |
| order-map-candidates | 判定不能 | None | 0.003869887499999436 |
| order-map-all-ok | 判定不能 | None | 0.0038848791999996028 |
| order-map-always-error | 判定不能 | None | 0.003888616700000114 |
| order-record-candidates | 判定不能 | None | 0.003931862500000704 |
| order-record-all-ok | 判定不能 | None | 0.00393602919999978 |
| order-record-always-error | 判定不能 | None | 0.003940562500000056 |
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
| runtime-loop-short | 判定不能 | None | 0.002415449999999453 |
| runtime-list-short | 達成 | 0.000586416999993844 | 0.0029613125000011566 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022425624999996784 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 達成 | 0.0003921240000011039 | 0.002 |
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
    "verify": 1.8645454589999986,
    "cli": 5.525588126000002,
    "warmup": 0.6847183310000133,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9329634580000032,
    "cli": 3.7491716680000167,
    "warmup": 0.4421027489999858,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3820371660000035,
    "cli": 9.541673082000003,
    "warmup": 1.3451403759999891,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.38954629100000204,
    "cli": 3.6404002090000205,
    "warmup": 0.3681187899999969,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10438908300000094,
    "cli": 0.28897604099999796,
    "warmup": 0.030395334000004937,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.0378516669999982,
    "cli": 0.3393293329999949,
    "warmup": 0.03535433300000079,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.011245915999992917,
    "cli": 0.20907050000000993,
    "warmup": 0.009820582999992666,
    "probe_warmup": 0.008516416000006188,
    "rss": 0,
    "stages": 0.04023016699999005,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04414125000000979,
    "cli": 0.35101345799999706,
    "warmup": 0.036166333000011264,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18417083300001025
  },
  "runtime": {
    "verify": 0.352938917000003,
    "cli": 2.987637250000006,
    "warmup": 0.33549358300000165,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
