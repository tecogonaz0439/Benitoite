# 版どうしの性能比較

候補: `849079b69c7ca28653e5071488c91efee8f7f574`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013279 | 0.000367 |
| functions-main-0-0 | after | 0.013479 | 0.000627 |
| functions-main-0-1 | before | 0.014526 | 0.001403 |
| functions-main-0-1 | after | 0.014118 | 0.000728 |
| functions-main-1000-0 | before | 0.031413 | 0.000230 |
| functions-main-1000-0 | after | 0.031623 | 0.000588 |
| functions-main-1000-1 | before | 0.031217 | 0.001261 |
| functions-main-1000-1 | after | 0.031382 | 0.002674 |
| functions-args-0-0 | before | 0.012954 | 0.000317 |
| functions-args-0-0 | after | 0.013052 | 0.000230 |
| functions-args-0-1 | before | 0.013145 | 0.000402 |
| functions-args-0-1 | after | 0.013032 | 0.000107 |
| functions-args-1000-0 | before | 0.047602 | 0.000533 |
| functions-args-1000-0 | after | 0.047337 | 0.000540 |
| functions-args-1000-1 | before | 0.049023 | 0.000353 |
| functions-args-1000-1 | after | 0.049664 | 0.003204 |
| functions-modules-0-0 | before | 0.013313 | 0.000872 |
| functions-modules-0-0 | after | 0.013467 | 0.000151 |
| functions-modules-0-1 | before | 0.013448 | 0.000968 |
| functions-modules-0-1 | after | 0.013041 | 0.000521 |
| functions-modules-1000-0 | before | 0.024443 | 0.000179 |
| functions-modules-1000-0 | after | 0.024993 | 0.001352 |
| functions-modules-1000-1 | before | 0.024288 | 0.000202 |
| functions-modules-1000-1 | after | 0.024690 | 0.000537 |
| existing-fib | before | 0.014261 | 0.000893 |
| existing-fib | after | 0.013649 | 0.000282 |
| existing-loop | before | 0.013835 | 0.000564 |
| existing-loop | after | 0.014113 | 0.000140 |
| existing-string | before | 0.014575 | 0.000624 |
| existing-string | after | 0.013887 | 0.000207 |
| higher-0-0 | before | 0.013417 | 0.001310 |
| higher-0-0 | after | 0.013437 | 0.000310 |
| higher-1-0 | before | 0.014082 | 0.000497 |
| higher-1-0 | after | 0.014131 | 0.000873 |
| classes-0 | before | 0.018981 | 0.000501 |
| classes-0 | after | 0.019329 | 0.001586 |
| higher-0-300 | before | 0.027761 | 0.000894 |
| higher-0-300 | after | 0.027090 | 0.000943 |
| higher-1-300 | before | 0.029630 | 0.000131 |
| higher-1-300 | after | 0.030446 | 0.000407 |
| classes-300 | before | 0.038398 | 0.001882 |
| classes-300 | after | 0.039095 | 0.002062 |
| depth-0-8 | before | 0.014533 | 0.000753 |
| depth-0-8 | after | 0.014526 | 0.000064 |
| depth-1-8 | before | 0.014684 | 0.000508 |
| depth-1-8 | after | 0.014847 | 0.000054 |
| f1-nofail-call | before | 0.014108 | 0.000565 |
| f1-nofail-call | after | 0.014163 | 0.000097 |
| f1-join-effects | before | 0.013895 | 0.000641 |
| f1-join-effects | after | 0.014014 | 0.000140 |
| control-16.3 | before | 0.013368 | 0.001325 |
| control-16.3 | after | 0.013470 | 0.000330 |
| property-seven-24-20-1000-all-ok | before | 0.040772 | 0.002215 |
| property-seven-24-20-1000-all-ok | after | 0.041131 | 0.001089 |
| property-seven-24-20-1000-always-error | before | 0.038296 | 0.000949 |
| property-seven-24-20-1000-always-error | after | 0.038480 | 0.001973 |
| property-distinct-24-20-1000-all-ok | before | 0.038819 | 0.001266 |
| property-distinct-24-20-1000-all-ok | after | 0.038799 | 0.000380 |
| property-distinct-24-20-1000-always-error | before | 0.039514 | 0.000679 |
| property-distinct-24-20-1000-always-error | after | 0.039407 | 0.001215 |
| property-zero-24-20-1000-all-ok | before | 0.040771 | 0.002861 |
| property-zero-24-20-1000-all-ok | after | 0.041098 | 0.001404 |
| property-zero-24-20-1000-always-error | before | 0.038211 | 0.000879 |
| property-zero-24-20-1000-always-error | after | 0.038217 | 0.000528 |
| property-max-24-20-1000-all-ok | before | 0.039942 | 0.001209 |
| property-max-24-20-1000-all-ok | after | 0.040110 | 0.000573 |
| property-max-24-20-1000-always-error | before | 0.039429 | 0.001040 |
| property-max-24-20-1000-always-error | after | 0.039186 | 0.001742 |
| order-string-candidates | before | 0.039137 | 0.000772 |
| order-string-candidates | after | 0.038924 | 0.001042 |
| order-string-all-ok | before | 0.038495 | 0.001663 |
| order-string-all-ok | after | 0.039150 | 0.000220 |
| order-string-always-error | before | 0.037833 | 0.001146 |
| order-string-always-error | after | 0.038195 | 0.001839 |
| order-map-candidates | before | 0.039556 | 0.001216 |
| order-map-candidates | after | 0.039208 | 0.000343 |
| order-map-all-ok | before | 0.039376 | 0.001354 |
| order-map-all-ok | after | 0.039696 | 0.000590 |
| order-map-always-error | before | 0.038477 | 0.000868 |
| order-map-always-error | after | 0.038761 | 0.000403 |
| order-record-candidates | before | 0.039044 | 0.000532 |
| order-record-candidates | after | 0.038938 | 0.000557 |
| order-record-all-ok | before | 0.039760 | 0.002697 |
| order-record-all-ok | after | 0.039118 | 0.000596 |
| order-record-always-error | before | 0.040979 | 0.002070 |
| order-record-always-error | after | 0.040215 | 0.000600 |
| build-string-builder-8-0 | before | 0.016161 | 0.000375 |
| build-string-builder-8-0 | after | 0.016068 | 0.001279 |
| build-string-builder-all-8-0 | before | 0.016063 | 0.000350 |
| build-string-builder-all-8-0 | after | 0.016096 | 0.000341 |
| build-string-concatenate-8-0 | before | 0.016277 | 0.001444 |
| build-string-concatenate-8-0 | after | 0.016216 | 0.001029 |
| build-string-join-8-0 | before | 0.016255 | 0.000397 |
| build-string-join-8-0 | after | 0.016046 | 0.000457 |
| build-list-builder-8-0 | before | 0.018186 | 0.000749 |
| build-list-builder-8-0 | after | 0.017503 | 0.000844 |
| build-list-builder-all-8-0 | before | 0.016441 | 0.000391 |
| build-list-builder-all-8-0 | after | 0.016378 | 0.000603 |
| build-list-concatenate-8-0 | before | 0.016583 | 0.000296 |
| build-list-concatenate-8-0 | after | 0.016239 | 0.000433 |
| build-list-fold-8-0 | before | 0.016017 | 0.000370 |
| build-list-fold-8-0 | after | 0.016016 | 0.000118 |
| build-bytes-builder-8-0 | before | 0.016139 | 0.001126 |
| build-bytes-builder-8-0 | after | 0.016275 | 0.001021 |
| build-bytes-builder-all-8-0 | before | 0.016179 | 0.000342 |
| build-bytes-builder-all-8-0 | after | 0.016387 | 0.000278 |
| build-bytes-concatenate-8-0 | before | 0.016440 | 0.000493 |
| build-bytes-concatenate-8-0 | after | 0.016174 | 0.000260 |
| patterns-integer-100 | before | 0.014828 | 0.000671 |
| patterns-integer-100 | after | 0.014731 | 0.000151 |
| codegen-let-100 | before | 0.017054 | 0.001551 |
| codegen-let-100 | after | 0.018125 | 0.001046 |
| bridge-shared-8 | before | 0.004560 | 0.000147 |
| bridge-shared-8 | after | 0.004320 | 0.000920 |
| external-tests-normal-1 | before | 0.018090 | 0.000281 |
| external-tests-normal-1 | after | 0.018194 | 0.001171 |
| runtime-fib-short | before | 0.018125 | 0.000521 |
| runtime-fib-short | after | 0.017992 | 0.001530 |
| runtime-loop-short | before | 0.024283 | 0.001543 |
| runtime-loop-short | after | 0.024719 | 0.000854 |
| runtime-list-short | before | 0.030071 | 0.000203 |
| runtime-list-short | after | 0.030369 | 0.000977 |
| runtime-tree-short | before | 0.018658 | 0.000485 |
| runtime-tree-short | after | 0.018509 | 0.000606 |
| runtime-eval-short | before | 0.022215 | 0.001202 |
| runtime-eval-short | after | 0.022816 | 0.000765 |
| runtime-string-short | before | 0.016884 | 0.000266 |
| runtime-string-short | after | 0.016880 | 0.000343 |
| runtime-println-short | before | 0.017623 | 0.000703 |
| runtime-println-short | after | 0.017626 | 0.000576 |
| runtime-lines-short | before | 0.017329 | 0.000449 |
| runtime-lines-short | after | 0.017261 | 0.001299 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.6166e-05 | 2.875e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.958e-06 | 3.75e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.0083e-05 | 3.25e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4167e-05 | 1.082e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.875e-06 | 1.25e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7042e-05 | 1.207e-06 |
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
    "after": "849079b69c7ca28653e5071488c91efee8f7f574"
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
| functions-main-1000-0 | 判定不能 | None | 0.0031412541999998214 |
| functions-main-1000-1 | 判定不能 | None | 0.003121737500001132 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004760150000001318 |
| functions-args-1000-1 | 判定不能 | None | 0.004902279099999874 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002444329200000084 |
| functions-modules-1000-1 | 判定不能 | None | 0.002428808399997706 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0027760624999984885 |
| higher-1-300 | 達成 | 0.0008152919999986352 | 0.0029630292000007333 |
| classes-300 | 判定不能 | None | 0.0038397750000001454 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.004077208300000734 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003829558300000713 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038819124999974978 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003951383400001874 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0040771167000002604 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003821129199999973 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003994154200000821 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.00394288749999987 |
| order-string-candidates | 判定不能 | None | 0.0039137250000010225 |
| order-string-all-ok | 判定不能 | None | 0.003849458299998787 |
| order-string-always-error | 判定不能 | None | 0.0037833083999998965 |
| order-map-candidates | 判定不能 | None | 0.0039556250000003955 |
| order-map-all-ok | 判定不能 | None | 0.003937591600001156 |
| order-map-always-error | 判定不能 | None | 0.0038476666999997635 |
| order-record-candidates | 判定不能 | None | 0.003904433299999255 |
| order-record-all-ok | 判定不能 | None | 0.003975950000000239 |
| order-record-always-error | 判定不能 | None | 0.00409788749999791 |
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
| runtime-loop-short | 判定不能 | None | 0.002428279200000816 |
| runtime-list-short | 判定不能 | None | 0.0030070542000004254 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022215125000002445 |
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
    "verify": 2.243284625000001,
    "cli": 5.390229916000067,
    "warmup": 0.6710688769999251,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 1.0117058329999793,
    "cli": 3.640845211000027,
    "warmup": 0.4343886219999149,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.354807333000025,
    "cli": 9.527957294000032,
    "warmup": 1.3511884190000103,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3697036659999924,
    "cli": 3.6009550839999918,
    "warmup": 0.36345575600000757,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09726012499999115,
    "cli": 0.2845850419999749,
    "warmup": 0.029549459000008937,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.035195625000000064,
    "cli": 0.34152783299998646,
    "warmup": 0.0355060419999802,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009190875000001597,
    "cli": 0.2007156669999972,
    "warmup": 0.008452583000007508,
    "probe_warmup": 0.007960083000000395,
    "rss": 0,
    "stages": 0.03841858300000922,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04323895900000707,
    "cli": 0.343845167000012,
    "warmup": 0.036030292000020836,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18441912800003024
  },
  "runtime": {
    "verify": 0.3353567910000095,
    "cli": 2.9670840820000137,
    "warmup": 0.33490795600002343,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
