# 版どうしの性能比較

候補: `678aba50ae8f6ad52d0bdb26e7847d62bcbb7b5c`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013657 | 0.000296 |
| functions-main-0-0 | after | 0.013912 | 0.000198 |
| functions-main-0-1 | before | 0.013648 | 0.000372 |
| functions-main-0-1 | after | 0.013710 | 0.000155 |
| functions-main-1000-0 | before | 0.030928 | 0.000438 |
| functions-main-1000-0 | after | 0.031675 | 0.000603 |
| functions-main-1000-1 | before | 0.030745 | 0.000418 |
| functions-main-1000-1 | after | 0.031603 | 0.000607 |
| functions-args-0-0 | before | 0.013132 | 0.000203 |
| functions-args-0-0 | after | 0.013275 | 0.000119 |
| functions-args-0-1 | before | 0.013029 | 0.000182 |
| functions-args-0-1 | after | 0.013062 | 0.000118 |
| functions-args-1000-0 | before | 0.047404 | 0.000622 |
| functions-args-1000-0 | after | 0.048050 | 0.000330 |
| functions-args-1000-1 | before | 0.047481 | 0.000389 |
| functions-args-1000-1 | after | 0.048001 | 0.000266 |
| functions-modules-0-0 | before | 0.013180 | 0.000443 |
| functions-modules-0-0 | after | 0.013143 | 0.000165 |
| functions-modules-0-1 | before | 0.013050 | 0.000196 |
| functions-modules-0-1 | after | 0.013156 | 0.000103 |
| functions-modules-1000-0 | before | 0.024337 | 0.000192 |
| functions-modules-1000-0 | after | 0.025364 | 0.000636 |
| functions-modules-1000-1 | before | 0.024253 | 0.000191 |
| functions-modules-1000-1 | after | 0.025141 | 0.000734 |
| existing-fib | before | 0.013643 | 0.000523 |
| existing-fib | after | 0.013772 | 0.000152 |
| existing-loop | before | 0.013745 | 0.001140 |
| existing-loop | after | 0.013721 | 0.000158 |
| existing-string | before | 0.013661 | 0.000640 |
| existing-string | after | 0.013716 | 0.000116 |
| higher-0-0 | before | 0.013059 | 0.000252 |
| higher-0-0 | after | 0.013238 | 0.000183 |
| higher-1-0 | before | 0.014006 | 0.000617 |
| higher-1-0 | after | 0.014184 | 0.000241 |
| classes-0 | before | 0.019101 | 0.000282 |
| classes-0 | after | 0.019395 | 0.000471 |
| higher-0-300 | before | 0.026438 | 0.001145 |
| higher-0-300 | after | 0.027267 | 0.000691 |
| higher-1-300 | before | 0.028943 | 0.000220 |
| higher-1-300 | after | 0.030170 | 0.000902 |
| classes-300 | before | 0.037569 | 0.000864 |
| classes-300 | after | 0.039037 | 0.000344 |
| depth-0-8 | before | 0.014516 | 0.000653 |
| depth-0-8 | after | 0.014599 | 0.000210 |
| depth-1-8 | before | 0.014858 | 0.000575 |
| depth-1-8 | after | 0.014808 | 0.000070 |
| f1-nofail-call | before | 0.014146 | 0.000787 |
| f1-nofail-call | after | 0.014085 | 0.000153 |
| f1-join-effects | before | 0.014047 | 0.000603 |
| f1-join-effects | after | 0.014154 | 0.000298 |
| control-16.3 | before | 0.013070 | 0.000707 |
| control-16.3 | after | 0.013171 | 0.000135 |
| property-seven-24-20-1000-all-ok | before | 0.039627 | 0.000867 |
| property-seven-24-20-1000-all-ok | after | 0.039956 | 0.000620 |
| property-seven-24-20-1000-always-error | before | 0.038147 | 0.000850 |
| property-seven-24-20-1000-always-error | after | 0.038869 | 0.000331 |
| property-distinct-24-20-1000-all-ok | before | 0.038817 | 0.001031 |
| property-distinct-24-20-1000-all-ok | after | 0.039225 | 0.000181 |
| property-distinct-24-20-1000-always-error | before | 0.038190 | 0.000638 |
| property-distinct-24-20-1000-always-error | after | 0.038283 | 0.000466 |
| property-zero-24-20-1000-all-ok | before | 0.039388 | 0.001333 |
| property-zero-24-20-1000-all-ok | after | 0.039795 | 0.000187 |
| property-zero-24-20-1000-always-error | before | 0.038093 | 0.000863 |
| property-zero-24-20-1000-always-error | after | 0.038371 | 0.000254 |
| property-max-24-20-1000-all-ok | before | 0.039469 | 0.001259 |
| property-max-24-20-1000-all-ok | after | 0.040010 | 0.000228 |
| property-max-24-20-1000-always-error | before | 0.038207 | 0.000794 |
| property-max-24-20-1000-always-error | after | 0.038380 | 0.000194 |
| order-string-candidates | before | 0.038991 | 0.000497 |
| order-string-candidates | after | 0.039188 | 0.000648 |
| order-string-all-ok | before | 0.039659 | 0.001412 |
| order-string-all-ok | after | 0.039949 | 0.000216 |
| order-string-always-error | before | 0.037725 | 0.000895 |
| order-string-always-error | after | 0.038268 | 0.000708 |
| order-map-candidates | before | 0.038536 | 0.000812 |
| order-map-candidates | after | 0.038761 | 0.000274 |
| order-map-all-ok | before | 0.038407 | 0.001090 |
| order-map-all-ok | after | 0.039055 | 0.000143 |
| order-map-always-error | before | 0.037935 | 0.000884 |
| order-map-always-error | after | 0.038502 | 0.000270 |
| order-record-candidates | before | 0.038669 | 0.001193 |
| order-record-candidates | after | 0.039026 | 0.000308 |
| order-record-all-ok | before | 0.038652 | 0.001076 |
| order-record-all-ok | after | 0.039195 | 0.000415 |
| order-record-always-error | before | 0.038785 | 0.000894 |
| order-record-always-error | after | 0.039315 | 0.000380 |
| build-string-builder-8-0 | before | 0.015940 | 0.000381 |
| build-string-builder-8-0 | after | 0.016071 | 0.000088 |
| build-string-builder-all-8-0 | before | 0.016009 | 0.000506 |
| build-string-builder-all-8-0 | after | 0.016117 | 0.000077 |
| build-string-concatenate-8-0 | before | 0.015886 | 0.000299 |
| build-string-concatenate-8-0 | after | 0.015985 | 0.000089 |
| build-string-join-8-0 | before | 0.015694 | 0.000327 |
| build-string-join-8-0 | after | 0.015883 | 0.000246 |
| build-list-builder-8-0 | before | 0.016120 | 0.000195 |
| build-list-builder-8-0 | after | 0.016170 | 0.000276 |
| build-list-builder-all-8-0 | before | 0.015932 | 0.000334 |
| build-list-builder-all-8-0 | after | 0.015946 | 0.000268 |
| build-list-concatenate-8-0 | before | 0.016080 | 0.000332 |
| build-list-concatenate-8-0 | after | 0.016198 | 0.000174 |
| build-list-fold-8-0 | before | 0.015916 | 0.000463 |
| build-list-fold-8-0 | after | 0.016086 | 0.000418 |
| build-bytes-builder-8-0 | before | 0.016067 | 0.000262 |
| build-bytes-builder-8-0 | after | 0.016163 | 0.000155 |
| build-bytes-builder-all-8-0 | before | 0.016217 | 0.000329 |
| build-bytes-builder-all-8-0 | after | 0.016247 | 0.000093 |
| build-bytes-concatenate-8-0 | before | 0.016287 | 0.000257 |
| build-bytes-concatenate-8-0 | after | 0.016489 | 0.000496 |
| patterns-integer-100 | before | 0.014342 | 0.000649 |
| patterns-integer-100 | after | 0.014497 | 0.000233 |
| codegen-let-100 | before | 0.016796 | 0.000178 |
| codegen-let-100 | after | 0.017145 | 0.000747 |
| bridge-shared-8 | before | 0.004474 | 0.000128 |
| bridge-shared-8 | after | 0.004295 | 0.000373 |
| external-tests-normal-1 | before | 0.017698 | 0.000353 |
| external-tests-normal-1 | after | 0.017949 | 0.000368 |
| runtime-fib-short | before | 0.018148 | 0.000321 |
| runtime-fib-short | after | 0.018174 | 0.000700 |
| runtime-loop-short | before | 0.023768 | 0.000350 |
| runtime-loop-short | after | 0.023646 | 0.001139 |
| runtime-list-short | before | 0.029122 | 0.000267 |
| runtime-list-short | after | 0.029463 | 0.000539 |
| runtime-tree-short | before | 0.018121 | 0.000176 |
| runtime-tree-short | after | 0.018528 | 0.000699 |
| runtime-eval-short | before | 0.021968 | 0.000294 |
| runtime-eval-short | after | 0.022289 | 0.000558 |
| runtime-string-short | before | 0.016819 | 0.000421 |
| runtime-string-short | after | 0.016927 | 0.000819 |
| runtime-println-short | before | 0.017345 | 0.000252 |
| runtime-println-short | after | 0.017214 | 0.000905 |
| runtime-lines-short | before | 0.016749 | 0.000374 |
| runtime-lines-short | after | 0.016698 | 0.000093 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5417e-05 | 9.58e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.041e-06 | 2.92e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8501e-05 | 1.416e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.3625e-05 | 1.24e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.958e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.6708e-05 | 5.82e-07 |
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
    "after": "678aba50ae8f6ad52d0bdb26e7847d62bcbb7b5c"
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
| functions-main-1000-0 | 判定不能 | None | 0.003092808299999206 |
| functions-main-1000-1 | 判定不能 | None | 0.0030745415999987816 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004740383299998996 |
| functions-args-1000-1 | 判定不能 | None | 0.004748062500000572 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.001027708999998822 | 0.002433675000000335 |
| functions-modules-1000-1 | 判定不能 | None | 0.0024252915999994685 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002643824999999822 |
| higher-1-300 | 達成 | 0.0012267080000185615 | 0.0028943457999986324 |
| classes-300 | 達成 | 0.0014677919999996902 | 0.003756904200000122 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003962654100000407 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0038147334000001366 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.00388168329999985 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038190124999999855 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003938770799999248 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038093250000002855 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.00394685419999945 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0038207041999996252 |
| order-string-candidates | 判定不能 | None | 0.003899124999999515 |
| order-string-all-ok | 判定不能 | None | 0.0039659000000000335 |
| order-string-always-error | 判定不能 | None | 0.003772495900000195 |
| order-map-candidates | 判定不能 | None | 0.0038535707999997728 |
| order-map-all-ok | 判定不能 | None | 0.003840699999999231 |
| order-map-always-error | 判定不能 | None | 0.0037934708000008756 |
| order-record-candidates | 判定不能 | None | 0.003866862499999968 |
| order-record-all-ok | 判定不能 | None | 0.0038652374999998077 |
| order-record-always-error | 判定不能 | None | 0.003878474999999071 |
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
| runtime-loop-short | 判定不能 | None | 0.0023767790999997375 |
| runtime-list-short | 判定不能 | None | 0.0029121957999990403 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0021968333000003783 |
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
    "verify": 1.837332707999991,
    "cli": 5.3238698319999855,
    "warmup": 0.6638463760000235,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9054799999999972,
    "cli": 3.601979914999987,
    "warmup": 0.42693495800003234,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3408550000000048,
    "cli": 9.383711416999986,
    "warmup": 1.334262458999973,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36226870900000563,
    "cli": 3.514268833000017,
    "warmup": 0.3550984929999572,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.0994015419999954,
    "cli": 0.27718462500000385,
    "warmup": 0.02931304199999829,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03767050000000438,
    "cli": 0.32875758400000166,
    "warmup": 0.03419279100000949,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009833708000002161,
    "cli": 0.1993049999999954,
    "warmup": 0.008620124999993095,
    "probe_warmup": 0.007757333000000699,
    "rss": 0,
    "stages": 0.03761275200001535,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04193500000000938,
    "cli": 0.33732612499998993,
    "warmup": 0.03544845899999416,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17783866700001738
  },
  "runtime": {
    "verify": 0.3334934169999997,
    "cli": 2.9021575010000333,
    "warmup": 0.32675453999998183,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
