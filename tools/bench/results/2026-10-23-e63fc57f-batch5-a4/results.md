# 版どうしの性能比較

候補: `e63fc57fffc65a00ed7cafa4eb3ef06070b325bb`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013448 | 0.000307 |
| functions-main-0-0 | after | 0.013552 | 0.000186 |
| functions-main-0-1 | before | 0.013663 | 0.000747 |
| functions-main-0-1 | after | 0.013379 | 0.000304 |
| functions-main-1000-0 | before | 0.030712 | 0.000247 |
| functions-main-1000-0 | after | 0.031151 | 0.000445 |
| functions-main-1000-1 | before | 0.030801 | 0.000432 |
| functions-main-1000-1 | after | 0.031395 | 0.000583 |
| functions-args-0-0 | before | 0.013461 | 0.000724 |
| functions-args-0-0 | after | 0.013273 | 0.000243 |
| functions-args-0-1 | before | 0.013189 | 0.000525 |
| functions-args-0-1 | after | 0.013159 | 0.000220 |
| functions-args-1000-0 | before | 0.047904 | 0.000652 |
| functions-args-1000-0 | after | 0.047697 | 0.000433 |
| functions-args-1000-1 | before | 0.047376 | 0.000424 |
| functions-args-1000-1 | after | 0.047936 | 0.000379 |
| functions-modules-0-0 | before | 0.013488 | 0.000807 |
| functions-modules-0-0 | after | 0.013261 | 0.000138 |
| functions-modules-0-1 | before | 0.013199 | 0.000159 |
| functions-modules-0-1 | after | 0.013159 | 0.000125 |
| functions-modules-1000-0 | before | 0.024239 | 0.000244 |
| functions-modules-1000-0 | after | 0.024767 | 0.000827 |
| functions-modules-1000-1 | before | 0.024251 | 0.000102 |
| functions-modules-1000-1 | after | 0.024597 | 0.000576 |
| existing-fib | before | 0.013737 | 0.001234 |
| existing-fib | after | 0.013665 | 0.000101 |
| existing-loop | before | 0.013691 | 0.001345 |
| existing-loop | after | 0.013582 | 0.000544 |
| existing-string | before | 0.013556 | 0.000498 |
| existing-string | after | 0.013674 | 0.000267 |
| higher-0-0 | before | 0.013282 | 0.000427 |
| higher-0-0 | after | 0.013111 | 0.000087 |
| higher-1-0 | before | 0.014473 | 0.000756 |
| higher-1-0 | after | 0.014022 | 0.000296 |
| classes-0 | before | 0.018908 | 0.000459 |
| classes-0 | after | 0.019095 | 0.001147 |
| higher-0-300 | before | 0.026260 | 0.000277 |
| higher-0-300 | after | 0.026793 | 0.000758 |
| higher-1-300 | before | 0.029255 | 0.000324 |
| higher-1-300 | after | 0.030330 | 0.001090 |
| classes-300 | before | 0.037662 | 0.000718 |
| classes-300 | after | 0.038346 | 0.000463 |
| depth-0-8 | before | 0.014757 | 0.000613 |
| depth-0-8 | after | 0.014534 | 0.000069 |
| depth-1-8 | before | 0.014832 | 0.000759 |
| depth-1-8 | after | 0.014825 | 0.000123 |
| f1-nofail-call | before | 0.014049 | 0.000636 |
| f1-nofail-call | after | 0.014161 | 0.000167 |
| f1-join-effects | before | 0.014038 | 0.000547 |
| f1-join-effects | after | 0.013974 | 0.000147 |
| control-16.3 | before | 0.012988 | 0.000447 |
| control-16.3 | after | 0.013048 | 0.000120 |
| property-seven-24-20-1000-all-ok | before | 0.039754 | 0.000805 |
| property-seven-24-20-1000-all-ok | after | 0.039927 | 0.000165 |
| property-seven-24-20-1000-always-error | before | 0.039059 | 0.000823 |
| property-seven-24-20-1000-always-error | after | 0.038355 | 0.000252 |
| property-distinct-24-20-1000-all-ok | before | 0.038983 | 0.000530 |
| property-distinct-24-20-1000-all-ok | after | 0.039176 | 0.000302 |
| property-distinct-24-20-1000-always-error | before | 0.038372 | 0.001048 |
| property-distinct-24-20-1000-always-error | after | 0.038422 | 0.000357 |
| property-zero-24-20-1000-all-ok | before | 0.039106 | 0.000712 |
| property-zero-24-20-1000-all-ok | after | 0.039590 | 0.000624 |
| property-zero-24-20-1000-always-error | before | 0.038156 | 0.001116 |
| property-zero-24-20-1000-always-error | after | 0.038356 | 0.000415 |
| property-max-24-20-1000-all-ok | before | 0.039883 | 0.001139 |
| property-max-24-20-1000-all-ok | after | 0.040066 | 0.000347 |
| property-max-24-20-1000-always-error | before | 0.038322 | 0.000540 |
| property-max-24-20-1000-always-error | after | 0.038585 | 0.000591 |
| order-string-candidates | before | 0.037909 | 0.000783 |
| order-string-candidates | after | 0.038369 | 0.000222 |
| order-string-all-ok | before | 0.038667 | 0.001266 |
| order-string-all-ok | after | 0.038725 | 0.000346 |
| order-string-always-error | before | 0.037950 | 0.000530 |
| order-string-always-error | after | 0.038092 | 0.000314 |
| order-map-candidates | before | 0.038375 | 0.000850 |
| order-map-candidates | after | 0.038541 | 0.000418 |
| order-map-all-ok | before | 0.038636 | 0.001059 |
| order-map-all-ok | after | 0.038749 | 0.000182 |
| order-map-always-error | before | 0.038347 | 0.000866 |
| order-map-always-error | after | 0.038641 | 0.000177 |
| order-record-candidates | before | 0.038482 | 0.000753 |
| order-record-candidates | after | 0.039136 | 0.000177 |
| order-record-all-ok | before | 0.039175 | 0.001025 |
| order-record-all-ok | after | 0.039126 | 0.000490 |
| order-record-always-error | before | 0.038923 | 0.000862 |
| order-record-always-error | after | 0.039291 | 0.000184 |
| build-string-builder-8-0 | before | 0.015888 | 0.000221 |
| build-string-builder-8-0 | after | 0.015835 | 0.000194 |
| build-string-builder-all-8-0 | before | 0.016097 | 0.000187 |
| build-string-builder-all-8-0 | after | 0.016015 | 0.000168 |
| build-string-concatenate-8-0 | before | 0.015882 | 0.000443 |
| build-string-concatenate-8-0 | after | 0.015791 | 0.000083 |
| build-string-join-8-0 | before | 0.015798 | 0.000394 |
| build-string-join-8-0 | after | 0.015844 | 0.000203 |
| build-list-builder-8-0 | before | 0.015934 | 0.000560 |
| build-list-builder-8-0 | after | 0.016141 | 0.000196 |
| build-list-builder-all-8-0 | before | 0.016068 | 0.000426 |
| build-list-builder-all-8-0 | after | 0.015984 | 0.000164 |
| build-list-concatenate-8-0 | before | 0.016101 | 0.000489 |
| build-list-concatenate-8-0 | after | 0.016228 | 0.000131 |
| build-list-fold-8-0 | before | 0.016053 | 0.000350 |
| build-list-fold-8-0 | after | 0.016111 | 0.000346 |
| build-bytes-builder-8-0 | before | 0.015919 | 0.000300 |
| build-bytes-builder-8-0 | after | 0.016132 | 0.000183 |
| build-bytes-builder-all-8-0 | before | 0.016362 | 0.000492 |
| build-bytes-builder-all-8-0 | after | 0.016068 | 0.000140 |
| build-bytes-concatenate-8-0 | before | 0.016338 | 0.000232 |
| build-bytes-concatenate-8-0 | after | 0.016308 | 0.000200 |
| patterns-integer-100 | before | 0.014541 | 0.001784 |
| patterns-integer-100 | after | 0.014528 | 0.000634 |
| codegen-let-100 | before | 0.016919 | 0.000392 |
| codegen-let-100 | after | 0.017010 | 0.000497 |
| bridge-shared-8 | before | 0.004415 | 0.000222 |
| bridge-shared-8 | after | 0.004372 | 0.001012 |
| external-tests-normal-1 | before | 0.017975 | 0.000388 |
| external-tests-normal-1 | after | 0.017860 | 0.000314 |
| runtime-fib-short | before | 0.018010 | 0.000389 |
| runtime-fib-short | after | 0.018174 | 0.000807 |
| runtime-loop-short | before | 0.023684 | 0.000163 |
| runtime-loop-short | after | 0.023936 | 0.000673 |
| runtime-list-short | before | 0.029159 | 0.000114 |
| runtime-list-short | after | 0.029368 | 0.000766 |
| runtime-tree-short | before | 0.018078 | 0.000102 |
| runtime-tree-short | after | 0.018532 | 0.000797 |
| runtime-eval-short | before | 0.021992 | 0.000272 |
| runtime-eval-short | after | 0.022054 | 0.000951 |
| runtime-string-short | before | 0.016728 | 0.000350 |
| runtime-string-short | after | 0.016801 | 0.000338 |
| runtime-println-short | before | 0.017113 | 0.000434 |
| runtime-println-short | after | 0.017060 | 0.000139 |
| runtime-lines-short | before | 0.016698 | 0.000255 |
| runtime-lines-short | after | 0.016666 | 0.000062 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.4958e-05 | 3.25e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3e-06 | 8.75e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8666e-05 | 4.208e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4667e-05 | 3.34e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.5e-06 | 5e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8166e-05 | 2.5e-07 |
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
    "after": "e63fc57fffc65a00ed7cafa4eb3ef06070b325bb"
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
| functions-main-1000-0 | 判定不能 | None | 0.003071158400000229 |
| functions-main-1000-1 | 判定不能 | None | 0.003080116599998917 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004790429199999835 |
| functions-args-1000-1 | 判定不能 | None | 0.004737562500000081 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0024238874999994667 |
| functions-modules-1000-1 | 判定不能 | None | 0.002425079100000005 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002626049999999225 |
| higher-1-300 | 判定不能 | None | 0.002925450000000751 |
| classes-300 | 判定不能 | None | 0.003766195800000105 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003975400000000207 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0039058500000010102 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003898337500000082 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038371792000006623 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.00391057500000045 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038155666999998062 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003988270800000748 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003832187499999407 |
| order-string-candidates | 判定不能 | None | 0.003790912499999877 |
| order-string-all-ok | 判定不能 | None | 0.003866658299999415 |
| order-string-always-error | 判定不能 | None | 0.0037949834000002626 |
| order-map-candidates | 判定不能 | None | 0.0038375291000008363 |
| order-map-all-ok | 判定不能 | None | 0.0038636207999999785 |
| order-map-always-error | 判定不能 | None | 0.0038347165999994106 |
| order-record-candidates | 判定不能 | None | 0.0038481666000009795 |
| order-record-all-ok | 判定不能 | None | 0.0039174708000004445 |
| order-record-always-error | 判定不能 | None | 0.0038923124999996617 |
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
| runtime-loop-short | 判定不能 | None | 0.002368408300000624 |
| runtime-list-short | 判定不能 | None | 0.002915949999999157 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002199229099998945 |
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
    "verify": 1.8223858339999879,
    "cli": 5.312821128000024,
    "warmup": 0.6634217929999977,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9120694169999979,
    "cli": 3.5993970419999926,
    "warmup": 0.4279403320000341,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3518285829999996,
    "cli": 9.347165544000006,
    "warmup": 1.3267988749999802,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.37653662499999996,
    "cli": 3.512061625999962,
    "warmup": 0.3572344569999899,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10072287500000243,
    "cli": 0.2820723749999985,
    "warmup": 0.029053250000004027,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03672479100001169,
    "cli": 0.3282242090000125,
    "warmup": 0.03419779099999687,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010126749999997742,
    "cli": 0.20089345899999955,
    "warmup": 0.008661999999986847,
    "probe_warmup": 0.007710916999997153,
    "rss": 0,
    "stages": 0.03794420699996692,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04285333300001071,
    "cli": 0.3382337919999969,
    "warmup": 0.03549341700001207,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17879570700000613
  },
  "runtime": {
    "verify": 0.3408992089999998,
    "cli": 2.893740419000011,
    "warmup": 0.32590199700000255,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
