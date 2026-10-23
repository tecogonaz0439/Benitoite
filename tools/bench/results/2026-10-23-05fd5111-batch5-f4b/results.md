# 版どうしの性能比較

候補: `05fd5111c9cd3707e66994eebbb9536eb9a0e1eb`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013061 | 0.000105 |
| functions-main-0-0 | after | 0.013309 | 0.000440 |
| functions-main-0-1 | before | 0.013145 | 0.000553 |
| functions-main-0-1 | after | 0.013266 | 0.000209 |
| functions-main-1000-0 | before | 0.030616 | 0.000330 |
| functions-main-1000-0 | after | 0.031713 | 0.000534 |
| functions-main-1000-1 | before | 0.030591 | 0.000248 |
| functions-main-1000-1 | after | 0.031472 | 0.000410 |
| functions-args-0-0 | before | 0.013077 | 0.000254 |
| functions-args-0-0 | after | 0.013185 | 0.000123 |
| functions-args-0-1 | before | 0.013039 | 0.000639 |
| functions-args-0-1 | after | 0.013259 | 0.000079 |
| functions-args-1000-0 | before | 0.047914 | 0.000821 |
| functions-args-1000-0 | after | 0.048118 | 0.000456 |
| functions-args-1000-1 | before | 0.047250 | 0.000517 |
| functions-args-1000-1 | after | 0.048105 | 0.000347 |
| functions-modules-0-0 | before | 0.013069 | 0.000126 |
| functions-modules-0-0 | after | 0.013100 | 0.000569 |
| functions-modules-0-1 | before | 0.013095 | 0.000557 |
| functions-modules-0-1 | after | 0.013234 | 0.000076 |
| functions-modules-1000-0 | before | 0.024203 | 0.000340 |
| functions-modules-1000-0 | after | 0.025106 | 0.000343 |
| functions-modules-1000-1 | before | 0.024287 | 0.000325 |
| functions-modules-1000-1 | after | 0.025207 | 0.000785 |
| existing-fib | before | 0.013605 | 0.000423 |
| existing-fib | after | 0.013796 | 0.000189 |
| existing-loop | before | 0.013558 | 0.000437 |
| existing-loop | after | 0.013693 | 0.000166 |
| existing-string | before | 0.013628 | 0.000738 |
| existing-string | after | 0.013704 | 0.000175 |
| higher-0-0 | before | 0.013221 | 0.000264 |
| higher-0-0 | after | 0.013225 | 0.000131 |
| higher-1-0 | before | 0.013882 | 0.000585 |
| higher-1-0 | after | 0.014062 | 0.000185 |
| classes-0 | before | 0.019019 | 0.000121 |
| classes-0 | after | 0.019164 | 0.000764 |
| higher-0-300 | before | 0.026305 | 0.000268 |
| higher-0-300 | after | 0.027401 | 0.000604 |
| higher-1-300 | before | 0.029085 | 0.000183 |
| higher-1-300 | after | 0.030163 | 0.000488 |
| classes-300 | before | 0.037767 | 0.000600 |
| classes-300 | after | 0.038538 | 0.000446 |
| depth-0-8 | before | 0.014531 | 0.002113 |
| depth-0-8 | after | 0.014781 | 0.000192 |
| depth-1-8 | before | 0.014840 | 0.000594 |
| depth-1-8 | after | 0.014808 | 0.000307 |
| f1-nofail-call | before | 0.014176 | 0.000644 |
| f1-nofail-call | after | 0.014200 | 0.000108 |
| f1-join-effects | before | 0.013885 | 0.000799 |
| f1-join-effects | after | 0.014069 | 0.000244 |
| control-16.3 | before | 0.013098 | 0.000244 |
| control-16.3 | after | 0.013146 | 0.000179 |
| property-seven-24-20-1000-all-ok | before | 0.039550 | 0.000820 |
| property-seven-24-20-1000-all-ok | after | 0.040341 | 0.000179 |
| property-seven-24-20-1000-always-error | before | 0.037928 | 0.001025 |
| property-seven-24-20-1000-always-error | after | 0.038565 | 0.000242 |
| property-distinct-24-20-1000-all-ok | before | 0.038493 | 0.000927 |
| property-distinct-24-20-1000-all-ok | after | 0.039095 | 0.000298 |
| property-distinct-24-20-1000-always-error | before | 0.038128 | 0.001107 |
| property-distinct-24-20-1000-always-error | after | 0.038405 | 0.000472 |
| property-zero-24-20-1000-all-ok | before | 0.040301 | 0.001213 |
| property-zero-24-20-1000-all-ok | after | 0.039620 | 0.000611 |
| property-zero-24-20-1000-always-error | before | 0.038045 | 0.001418 |
| property-zero-24-20-1000-always-error | after | 0.038407 | 0.000257 |
| property-max-24-20-1000-all-ok | before | 0.039500 | 0.000492 |
| property-max-24-20-1000-all-ok | after | 0.039928 | 0.000260 |
| property-max-24-20-1000-always-error | before | 0.038314 | 0.000936 |
| property-max-24-20-1000-always-error | after | 0.038360 | 0.000305 |
| order-string-candidates | before | 0.037917 | 0.001076 |
| order-string-candidates | after | 0.038327 | 0.000473 |
| order-string-all-ok | before | 0.038663 | 0.000559 |
| order-string-all-ok | after | 0.039182 | 0.000390 |
| order-string-always-error | before | 0.037791 | 0.000969 |
| order-string-always-error | after | 0.038463 | 0.000468 |
| order-map-candidates | before | 0.038124 | 0.000979 |
| order-map-candidates | after | 0.038865 | 0.000783 |
| order-map-all-ok | before | 0.038547 | 0.000870 |
| order-map-all-ok | after | 0.038533 | 0.000224 |
| order-map-always-error | before | 0.038196 | 0.000931 |
| order-map-always-error | after | 0.038709 | 0.000509 |
| order-record-candidates | before | 0.038553 | 0.000955 |
| order-record-candidates | after | 0.038913 | 0.000274 |
| order-record-all-ok | before | 0.038932 | 0.001362 |
| order-record-all-ok | after | 0.039016 | 0.000461 |
| order-record-always-error | before | 0.038672 | 0.000944 |
| order-record-always-error | after | 0.039104 | 0.000468 |
| build-string-builder-8-0 | before | 0.015745 | 0.000388 |
| build-string-builder-8-0 | after | 0.016013 | 0.000343 |
| build-string-builder-all-8-0 | before | 0.015929 | 0.000270 |
| build-string-builder-all-8-0 | after | 0.016027 | 0.000143 |
| build-string-concatenate-8-0 | before | 0.015825 | 0.000350 |
| build-string-concatenate-8-0 | after | 0.015826 | 0.000171 |
| build-string-join-8-0 | before | 0.015708 | 0.000317 |
| build-string-join-8-0 | after | 0.015791 | 0.000114 |
| build-list-builder-8-0 | before | 0.015933 | 0.000258 |
| build-list-builder-8-0 | after | 0.016075 | 0.000178 |
| build-list-builder-all-8-0 | before | 0.015910 | 0.000450 |
| build-list-builder-all-8-0 | after | 0.016076 | 0.000061 |
| build-list-concatenate-8-0 | before | 0.016179 | 0.000847 |
| build-list-concatenate-8-0 | after | 0.016330 | 0.000812 |
| build-list-fold-8-0 | before | 0.015889 | 0.000393 |
| build-list-fold-8-0 | after | 0.016046 | 0.000131 |
| build-bytes-builder-8-0 | before | 0.015963 | 0.000495 |
| build-bytes-builder-8-0 | after | 0.016178 | 0.000247 |
| build-bytes-builder-all-8-0 | before | 0.015992 | 0.000312 |
| build-bytes-builder-all-8-0 | after | 0.016178 | 0.000152 |
| build-bytes-concatenate-8-0 | before | 0.016104 | 0.000505 |
| build-bytes-concatenate-8-0 | after | 0.016341 | 0.000194 |
| patterns-integer-100 | before | 0.014254 | 0.001222 |
| patterns-integer-100 | after | 0.014473 | 0.000131 |
| codegen-let-100 | before | 0.016694 | 0.000232 |
| codegen-let-100 | after | 0.016816 | 0.000809 |
| bridge-shared-8 | before | 0.004443 | 0.000084 |
| bridge-shared-8 | after | 0.004399 | 0.000884 |
| external-tests-normal-1 | before | 0.017779 | 0.000111 |
| external-tests-normal-1 | after | 0.018208 | 0.000812 |
| runtime-fib-short | before | 0.017953 | 0.000183 |
| runtime-fib-short | after | 0.018185 | 0.000764 |
| runtime-loop-short | before | 0.023557 | 0.000279 |
| runtime-loop-short | after | 0.023835 | 0.001065 |
| runtime-list-short | before | 0.028905 | 0.000308 |
| runtime-list-short | after | 0.029747 | 0.000347 |
| runtime-tree-short | before | 0.018107 | 0.000308 |
| runtime-tree-short | after | 0.018569 | 0.001035 |
| runtime-eval-short | before | 0.021890 | 0.000403 |
| runtime-eval-short | after | 0.022511 | 0.000730 |
| runtime-string-short | before | 0.016722 | 0.000328 |
| runtime-string-short | after | 0.016774 | 0.000175 |
| runtime-println-short | before | 0.017125 | 0.000444 |
| runtime-println-short | after | 0.017192 | 0.000435 |
| runtime-lines-short | before | 0.016438 | 0.000288 |
| runtime-lines-short | after | 0.016734 | 0.000137 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5333e-05 | 5.42e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.833e-06 | 2.92e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8166e-05 | 8.35e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.2958e-05 | 6.26e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.834e-06 | 4.2e-08 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.5792e-05 | 6.68e-07 |
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
    "after": "05fd5111c9cd3707e66994eebbb9536eb9a0e1eb"
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
| functions-main-1000-0 | 達成 | 0.0010968749999875627 | 0.00306156670000064 |
| functions-main-1000-1 | 達成 | 0.0008809580000104233 | 0.003059075000000178 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004791412499999126 |
| functions-args-1000-1 | 判定不能 | None | 0.004724991599999839 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.0009029589999869359 | 0.0024203416000005973 |
| functions-modules-1000-1 | 判定不能 | None | 0.0024287207999989847 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.001096207999992771 | 0.002630516700000385 |
| higher-1-300 | 達成 | 0.0010775420000044278 | 0.002908545799999729 |
| classes-300 | 判定不能 | None | 0.0037766666999999644 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003955025000000489 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0037928249999993114 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003849299999998834 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038128291999996126 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.004030066699999679 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003804454199999441 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003950008399999661 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0038314291000006054 |
| order-string-candidates | 判定不能 | None | 0.003791733299999578 |
| order-string-all-ok | 判定不能 | None | 0.00386627500000003 |
| order-string-always-error | 判定不能 | None | 0.003779074999999921 |
| order-map-candidates | 判定不能 | None | 0.0038123750000011117 |
| order-map-all-ok | 判定不能 | None | 0.0038547416000000116 |
| order-map-always-error | 判定不能 | None | 0.003819558300000381 |
| order-record-candidates | 判定不能 | None | 0.003855325000000676 |
| order-record-all-ok | 判定不能 | None | 0.0038932208000005634 |
| order-record-always-error | 判定不能 | None | 0.0038672165999997787 |
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
| runtime-loop-short | 判定不能 | None | 0.002355699999999672 |
| runtime-list-short | 達成 | 0.0008420409999985168 | 0.0028905459000000636 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0021889582999989445 |
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
    "verify": 1.8586858329999956,
    "cli": 5.298703249000027,
    "warmup": 0.6621016230000549,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.901446957999994,
    "cli": 3.605342499999992,
    "warmup": 0.42978562499997963,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3362299169999972,
    "cli": 9.343194207999986,
    "warmup": 1.3273733720000251,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36263416699999595,
    "cli": 3.515875331999979,
    "warmup": 0.35565066799998135,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09827166700000589,
    "cli": 0.27683754200000976,
    "warmup": 0.02923383299999216,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.037949500000010516,
    "cli": 0.32763374999998973,
    "warmup": 0.034573790999985476,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009191749999999388,
    "cli": 0.20015775000000247,
    "warmup": 0.008707750000013448,
    "probe_warmup": 0.007761875000014129,
    "rss": 0,
    "stages": 0.03783174900000574,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04093454200000224,
    "cli": 0.3382382500000034,
    "warmup": 0.03536416700001155,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17822387500000048
  },
  "runtime": {
    "verify": 0.33702345800000444,
    "cli": 2.8981124569999963,
    "warmup": 0.326120584000023,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
