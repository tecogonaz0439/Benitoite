# 版どうしの性能比較

候補: `52fc6f0a244f0f4dd8dcd4a3bf6fe7c23f5051c7`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.012264 | 0.000280 |
| functions-main-0-0 | after | 0.012623 | 0.001187 |
| functions-main-0-1 | before | 0.012523 | 0.000215 |
| functions-main-0-1 | after | 0.012591 | 0.000111 |
| functions-main-1000-0 | before | 0.029306 | 0.000322 |
| functions-main-1000-0 | after | 0.030026 | 0.000954 |
| functions-main-1000-1 | before | 0.029135 | 0.000457 |
| functions-main-1000-1 | after | 0.029934 | 0.000861 |
| functions-args-0-0 | before | 0.012170 | 0.000250 |
| functions-args-0-0 | after | 0.012552 | 0.000080 |
| functions-args-0-1 | before | 0.012396 | 0.000256 |
| functions-args-0-1 | after | 0.012615 | 0.000150 |
| functions-args-1000-0 | before | 0.045149 | 0.000916 |
| functions-args-1000-0 | after | 0.046162 | 0.000746 |
| functions-args-1000-1 | before | 0.044849 | 0.000778 |
| functions-args-1000-1 | after | 0.046142 | 0.000611 |
| functions-modules-0-0 | before | 0.012486 | 0.000348 |
| functions-modules-0-0 | after | 0.012630 | 0.000161 |
| functions-modules-0-1 | before | 0.012468 | 0.000874 |
| functions-modules-0-1 | after | 0.012957 | 0.000477 |
| functions-modules-1000-0 | before | 0.022967 | 0.000328 |
| functions-modules-1000-0 | after | 0.024510 | 0.000939 |
| functions-modules-1000-1 | before | 0.023152 | 0.000356 |
| functions-modules-1000-1 | after | 0.024313 | 0.000497 |
| existing-fib | before | 0.012697 | 0.000235 |
| existing-fib | after | 0.013115 | 0.000329 |
| existing-loop | before | 0.013039 | 0.000237 |
| existing-loop | after | 0.013062 | 0.000096 |
| existing-string | before | 0.012971 | 0.000138 |
| existing-string | after | 0.013128 | 0.000160 |
| higher-0-0 | before | 0.012494 | 0.000115 |
| higher-0-0 | after | 0.012670 | 0.000198 |
| higher-1-0 | before | 0.013410 | 0.000224 |
| higher-1-0 | after | 0.013648 | 0.000299 |
| classes-0 | before | 0.017900 | 0.000554 |
| classes-0 | after | 0.018605 | 0.000989 |
| higher-0-300 | before | 0.025147 | 0.000302 |
| higher-0-300 | after | 0.027171 | 0.000906 |
| higher-1-300 | before | 0.027937 | 0.000204 |
| higher-1-300 | after | 0.030494 | 0.001048 |
| classes-300 | before | 0.036270 | 0.000796 |
| classes-300 | after | 0.038148 | 0.000275 |
| depth-0-8 | before | 0.013721 | 0.000583 |
| depth-0-8 | after | 0.014165 | 0.000136 |
| depth-1-8 | before | 0.013999 | 0.000671 |
| depth-1-8 | after | 0.014202 | 0.000188 |
| f1-nofail-call | before | 0.013279 | 0.000086 |
| f1-nofail-call | after | 0.013631 | 0.000151 |
| f1-join-effects | before | 0.013220 | 0.000481 |
| f1-join-effects | after | 0.013704 | 0.000400 |
| control-16.3 | before | 0.012277 | 0.000201 |
| control-16.3 | after | 0.012614 | 0.000311 |
| property-seven-24-20-1000-all-ok | before | 0.037797 | 0.001355 |
| property-seven-24-20-1000-all-ok | after | 0.038914 | 0.000409 |
| property-seven-24-20-1000-always-error | before | 0.037043 | 0.001486 |
| property-seven-24-20-1000-always-error | after | 0.037759 | 0.000241 |
| property-distinct-24-20-1000-all-ok | before | 0.037428 | 0.001020 |
| property-distinct-24-20-1000-all-ok | after | 0.038545 | 0.000528 |
| property-distinct-24-20-1000-always-error | before | 0.036453 | 0.001624 |
| property-distinct-24-20-1000-always-error | after | 0.037660 | 0.000529 |
| property-zero-24-20-1000-all-ok | before | 0.037267 | 0.001455 |
| property-zero-24-20-1000-all-ok | after | 0.038906 | 0.000426 |
| property-zero-24-20-1000-always-error | before | 0.036790 | 0.001130 |
| property-zero-24-20-1000-always-error | after | 0.037609 | 0.000285 |
| property-max-24-20-1000-all-ok | before | 0.037836 | 0.001208 |
| property-max-24-20-1000-all-ok | after | 0.038937 | 0.000473 |
| property-max-24-20-1000-always-error | before | 0.036285 | 0.001402 |
| property-max-24-20-1000-always-error | after | 0.037756 | 0.000500 |
| order-string-candidates | before | 0.036455 | 0.001453 |
| order-string-candidates | after | 0.037402 | 0.000357 |
| order-string-all-ok | before | 0.036911 | 0.001633 |
| order-string-all-ok | after | 0.037923 | 0.000443 |
| order-string-always-error | before | 0.036087 | 0.000937 |
| order-string-always-error | after | 0.037295 | 0.000491 |
| order-map-candidates | before | 0.036615 | 0.001553 |
| order-map-candidates | after | 0.037901 | 0.000532 |
| order-map-all-ok | before | 0.036864 | 0.001185 |
| order-map-all-ok | after | 0.038439 | 0.000328 |
| order-map-always-error | before | 0.036626 | 0.001116 |
| order-map-always-error | after | 0.037964 | 0.000532 |
| order-record-candidates | before | 0.037107 | 0.001423 |
| order-record-candidates | after | 0.038367 | 0.000351 |
| order-record-all-ok | before | 0.037289 | 0.001122 |
| order-record-all-ok | after | 0.038339 | 0.000209 |
| order-record-always-error | before | 0.037307 | 0.001158 |
| order-record-always-error | after | 0.038610 | 0.000320 |
| build-string-builder-8-0 | before | 0.015158 | 0.000860 |
| build-string-builder-8-0 | after | 0.015283 | 0.000175 |
| build-string-builder-all-8-0 | before | 0.015097 | 0.000200 |
| build-string-builder-all-8-0 | after | 0.015595 | 0.000158 |
| build-string-concatenate-8-0 | before | 0.015093 | 0.000839 |
| build-string-concatenate-8-0 | after | 0.015358 | 0.000120 |
| build-string-join-8-0 | before | 0.015139 | 0.000587 |
| build-string-join-8-0 | after | 0.015185 | 0.000236 |
| build-list-builder-8-0 | before | 0.015339 | 0.000585 |
| build-list-builder-8-0 | after | 0.015545 | 0.000251 |
| build-list-builder-all-8-0 | before | 0.015267 | 0.000920 |
| build-list-builder-all-8-0 | after | 0.015437 | 0.000195 |
| build-list-concatenate-8-0 | before | 0.015596 | 0.001133 |
| build-list-concatenate-8-0 | after | 0.015897 | 0.000260 |
| build-list-fold-8-0 | before | 0.015265 | 0.000309 |
| build-list-fold-8-0 | after | 0.015594 | 0.000224 |
| build-bytes-builder-8-0 | before | 0.015272 | 0.000753 |
| build-bytes-builder-8-0 | after | 0.015598 | 0.000182 |
| build-bytes-builder-all-8-0 | before | 0.015442 | 0.000644 |
| build-bytes-builder-all-8-0 | after | 0.015655 | 0.000196 |
| build-bytes-concatenate-8-0 | before | 0.015611 | 0.000195 |
| build-bytes-concatenate-8-0 | after | 0.015786 | 0.000327 |
| patterns-integer-100 | before | 0.013704 | 0.001153 |
| patterns-integer-100 | after | 0.014206 | 0.000307 |
| codegen-let-100 | before | 0.016233 | 0.000187 |
| codegen-let-100 | after | 0.016406 | 0.000165 |
| bridge-shared-8 | before | 0.004276 | 0.000244 |
| bridge-shared-8 | after | 0.004469 | 0.000766 |
| external-tests-normal-1 | before | 0.017312 | 0.000339 |
| external-tests-normal-1 | after | 0.017457 | 0.000214 |
| runtime-fib-short | before | 0.017423 | 0.000921 |
| runtime-fib-short | after | 0.017776 | 0.000383 |
| runtime-loop-short | before | 0.022776 | 0.000304 |
| runtime-loop-short | after | 0.023115 | 0.001074 |
| runtime-list-short | before | 0.028414 | 0.000509 |
| runtime-list-short | after | 0.028914 | 0.000732 |
| runtime-tree-short | before | 0.017506 | 0.000292 |
| runtime-tree-short | after | 0.017776 | 0.001364 |
| runtime-eval-short | before | 0.021103 | 0.000209 |
| runtime-eval-short | after | 0.021525 | 0.000708 |
| runtime-string-short | before | 0.016194 | 0.000266 |
| runtime-string-short | after | 0.016412 | 0.000075 |
| runtime-println-short | before | 0.016447 | 0.000294 |
| runtime-println-short | after | 0.016659 | 0.000171 |
| runtime-lines-short | before | 0.015928 | 0.000089 |
| runtime-lines-short | after | 0.016315 | 0.000269 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.4875e-05 | 1.042e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.708e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.7583e-05 | 1.25e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6208e-05 | 2.792e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.625e-06 | 2.49e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8791e-05 | 2.417e-06 |
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
    "after": "52fc6f0a244f0f4dd8dcd4a3bf6fe7c23f5051c7"
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
| functions-main-1000-0 | 判定不能 | None | 0.0029305665999999953 |
| functions-main-1000-1 | 判定不能 | None | 0.0029134665999999143 |
| functions-args-0-0 | 達成 | 0.0003823329999992353 | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004514904099999839 |
| functions-args-1000-1 | 判定不能 | None | 0.004484941700000001 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.0015432499999974425 | 0.0022967000000001293 |
| functions-modules-1000-1 | 達成 | 0.00116112499999943 | 0.00231515420000008 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0020242499999998387 | 0.0025147249999999846 |
| higher-1-300 | 達成 | 0.0025569159999996316 | 0.002793745900000033 |
| classes-300 | 達成 | 0.001878291000000587 | 0.0036269624999999196 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 達成 | 0.0003525830000015162 | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0037797125000000875 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0037043458999999504 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0037427707999999173 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0036453333000000757 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003726720799999939 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0036789709000000673 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037835874999998967 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0036285458999998355 |
| order-string-candidates | 判定不能 | None | 0.0036455207999999575 |
| order-string-all-ok | 判定不能 | None | 0.0036911167000003076 |
| order-string-always-error | 判定不能 | None | 0.0036087334000001192 |
| order-map-candidates | 判定不能 | None | 0.0036614832999998016 |
| order-map-all-ok | 達成 | 0.0015750000000025466 | 0.0036863665999998575 |
| order-map-always-error | 判定不能 | None | 0.0036626459000000723 |
| order-record-candidates | 判定不能 | None | 0.00371067079999996 |
| order-record-all-ok | 判定不能 | None | 0.0037288707999998394 |
| order-record-always-error | 判定不能 | None | 0.003730679199999898 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 達成 | 0.0004974589999982015 | 0.002 |
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
| runtime-loop-short | 判定不能 | None | 0.0022776042000000273 |
| runtime-list-short | 判定不能 | None | 0.002841358399999905 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.00211031669999997 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 達成 | 0.00038762599999841996 | 0.002 |
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
    "verify": 1.7538980840000002,
    "cli": 5.046698335999995,
    "warmup": 0.6298678759999987,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.8623462919999998,
    "cli": 3.459991126000002,
    "warmup": 0.41328187600000277,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2734947920000002,
    "cli": 9.036979001999995,
    "warmup": 1.2852483310000054,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3430871670000002,
    "cli": 3.3911497900000036,
    "warmup": 0.3412939139999871,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.0925747079999999,
    "cli": 0.27166583299999303,
    "warmup": 0.028444874000008724,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03514958300000082,
    "cli": 0.31827879099999734,
    "warmup": 0.03283745800000304,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.00906470899999956,
    "cli": 0.19435916699999467,
    "warmup": 0.008306791000002534,
    "probe_warmup": 0.0074527090000060525,
    "rss": 0,
    "stages": 0.037119621999977426,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.038663832999999315,
    "cli": 0.3273821659999996,
    "warmup": 0.03428054200000474,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1733104179999927
  },
  "runtime": {
    "verify": 0.31430837499999953,
    "cli": 2.8072048350000003,
    "warmup": 0.31599970600001726,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
