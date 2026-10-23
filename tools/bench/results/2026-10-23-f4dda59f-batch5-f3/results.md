# 版どうしの性能比較

候補: `f4dda59f35807b7555992ea7c8ac74ab0e31aa8f`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013138 | 0.000074 |
| functions-main-0-0 | after | 0.013220 | 0.000697 |
| functions-main-0-1 | before | 0.013107 | 0.000122 |
| functions-main-0-1 | after | 0.013193 | 0.000129 |
| functions-main-1000-0 | before | 0.030567 | 0.000150 |
| functions-main-1000-0 | after | 0.031737 | 0.000724 |
| functions-main-1000-1 | before | 0.030812 | 0.000346 |
| functions-main-1000-1 | after | 0.031573 | 0.000359 |
| functions-args-0-0 | before | 0.013034 | 0.000141 |
| functions-args-0-0 | after | 0.013125 | 0.000101 |
| functions-args-0-1 | before | 0.013111 | 0.000507 |
| functions-args-0-1 | after | 0.013203 | 0.000091 |
| functions-args-1000-0 | before | 0.047206 | 0.000402 |
| functions-args-1000-0 | after | 0.047833 | 0.000455 |
| functions-args-1000-1 | before | 0.047272 | 0.000658 |
| functions-args-1000-1 | after | 0.047870 | 0.000604 |
| functions-modules-0-0 | before | 0.013065 | 0.000710 |
| functions-modules-0-0 | after | 0.013172 | 0.000047 |
| functions-modules-0-1 | before | 0.013022 | 0.000217 |
| functions-modules-0-1 | after | 0.013142 | 0.000115 |
| functions-modules-1000-0 | before | 0.024264 | 0.000204 |
| functions-modules-1000-0 | after | 0.024998 | 0.000586 |
| functions-modules-1000-1 | before | 0.024472 | 0.000799 |
| functions-modules-1000-1 | after | 0.025600 | 0.000926 |
| existing-fib | before | 0.013767 | 0.000587 |
| existing-fib | after | 0.013782 | 0.000175 |
| existing-loop | before | 0.013628 | 0.000702 |
| existing-loop | after | 0.013680 | 0.000179 |
| existing-string | before | 0.013556 | 0.000737 |
| existing-string | after | 0.013815 | 0.000236 |
| higher-0-0 | before | 0.013048 | 0.000402 |
| higher-0-0 | after | 0.013326 | 0.000115 |
| higher-1-0 | before | 0.014088 | 0.000723 |
| higher-1-0 | after | 0.014149 | 0.000050 |
| classes-0 | before | 0.019062 | 0.000241 |
| classes-0 | after | 0.020077 | 0.000601 |
| higher-0-300 | before | 0.026185 | 0.000127 |
| higher-0-300 | after | 0.027241 | 0.000796 |
| higher-1-300 | before | 0.029036 | 0.000247 |
| higher-1-300 | after | 0.029573 | 0.000753 |
| classes-300 | before | 0.037546 | 0.000426 |
| classes-300 | after | 0.038514 | 0.000361 |
| depth-0-8 | before | 0.014502 | 0.000765 |
| depth-0-8 | after | 0.014567 | 0.000056 |
| depth-1-8 | before | 0.014806 | 0.000640 |
| depth-1-8 | after | 0.014880 | 0.000101 |
| f1-nofail-call | before | 0.013964 | 0.000591 |
| f1-nofail-call | after | 0.014082 | 0.000148 |
| f1-join-effects | before | 0.013951 | 0.000550 |
| f1-join-effects | after | 0.014149 | 0.000156 |
| control-16.3 | before | 0.012917 | 0.000089 |
| control-16.3 | after | 0.013220 | 0.000135 |
| property-seven-24-20-1000-all-ok | before | 0.039398 | 0.001206 |
| property-seven-24-20-1000-all-ok | after | 0.039810 | 0.000326 |
| property-seven-24-20-1000-always-error | before | 0.038209 | 0.001709 |
| property-seven-24-20-1000-always-error | after | 0.038190 | 0.000105 |
| property-distinct-24-20-1000-all-ok | before | 0.038846 | 0.001256 |
| property-distinct-24-20-1000-all-ok | after | 0.039125 | 0.000382 |
| property-distinct-24-20-1000-always-error | before | 0.038010 | 0.000630 |
| property-distinct-24-20-1000-always-error | after | 0.038522 | 0.000204 |
| property-zero-24-20-1000-all-ok | before | 0.039178 | 0.001340 |
| property-zero-24-20-1000-all-ok | after | 0.039609 | 0.000434 |
| property-zero-24-20-1000-always-error | before | 0.038031 | 0.000854 |
| property-zero-24-20-1000-always-error | after | 0.038288 | 0.000300 |
| property-max-24-20-1000-all-ok | before | 0.039323 | 0.001250 |
| property-max-24-20-1000-all-ok | after | 0.039670 | 0.000177 |
| property-max-24-20-1000-always-error | before | 0.038276 | 0.001105 |
| property-max-24-20-1000-always-error | after | 0.038221 | 0.000277 |
| order-string-candidates | before | 0.038479 | 0.000864 |
| order-string-candidates | after | 0.038236 | 0.000230 |
| order-string-all-ok | before | 0.038481 | 0.000384 |
| order-string-all-ok | after | 0.038805 | 0.000470 |
| order-string-always-error | before | 0.037884 | 0.000943 |
| order-string-always-error | after | 0.038221 | 0.000261 |
| order-map-candidates | before | 0.038595 | 0.001209 |
| order-map-candidates | after | 0.038442 | 0.000230 |
| order-map-all-ok | before | 0.038807 | 0.000898 |
| order-map-all-ok | after | 0.038878 | 0.000192 |
| order-map-always-error | before | 0.038209 | 0.000754 |
| order-map-always-error | after | 0.038353 | 0.000314 |
| order-record-candidates | before | 0.038383 | 0.001699 |
| order-record-candidates | after | 0.038970 | 0.000239 |
| order-record-all-ok | before | 0.038624 | 0.000810 |
| order-record-all-ok | after | 0.039164 | 0.000283 |
| order-record-always-error | before | 0.038693 | 0.000896 |
| order-record-always-error | after | 0.038917 | 0.000165 |
| build-string-builder-8-0 | before | 0.015999 | 0.000189 |
| build-string-builder-8-0 | after | 0.015922 | 0.000162 |
| build-string-builder-all-8-0 | before | 0.015910 | 0.000321 |
| build-string-builder-all-8-0 | after | 0.016000 | 0.000154 |
| build-string-concatenate-8-0 | before | 0.015819 | 0.000280 |
| build-string-concatenate-8-0 | after | 0.015877 | 0.000190 |
| build-string-join-8-0 | before | 0.015688 | 0.000294 |
| build-string-join-8-0 | after | 0.015885 | 0.000242 |
| build-list-builder-8-0 | before | 0.015811 | 0.000578 |
| build-list-builder-8-0 | after | 0.016102 | 0.000347 |
| build-list-builder-all-8-0 | before | 0.016104 | 0.000556 |
| build-list-builder-all-8-0 | after | 0.016044 | 0.000187 |
| build-list-concatenate-8-0 | before | 0.016089 | 0.000315 |
| build-list-concatenate-8-0 | after | 0.016148 | 0.000215 |
| build-list-fold-8-0 | before | 0.015951 | 0.000338 |
| build-list-fold-8-0 | after | 0.016020 | 0.000076 |
| build-bytes-builder-8-0 | before | 0.015972 | 0.000343 |
| build-bytes-builder-8-0 | after | 0.016054 | 0.000099 |
| build-bytes-builder-all-8-0 | before | 0.016158 | 0.000344 |
| build-bytes-builder-all-8-0 | after | 0.016180 | 0.000102 |
| build-bytes-concatenate-8-0 | before | 0.016278 | 0.000279 |
| build-bytes-concatenate-8-0 | after | 0.016287 | 0.000112 |
| patterns-integer-100 | before | 0.014239 | 0.000728 |
| patterns-integer-100 | after | 0.014490 | 0.000171 |
| codegen-let-100 | before | 0.016878 | 0.000121 |
| codegen-let-100 | after | 0.016807 | 0.000709 |
| bridge-shared-8 | before | 0.004393 | 0.000163 |
| bridge-shared-8 | after | 0.004347 | 0.000982 |
| external-tests-normal-1 | before | 0.017814 | 0.000247 |
| external-tests-normal-1 | after | 0.017988 | 0.000860 |
| runtime-fib-short | before | 0.017992 | 0.000122 |
| runtime-fib-short | after | 0.018028 | 0.001003 |
| runtime-loop-short | before | 0.023750 | 0.000185 |
| runtime-loop-short | after | 0.023853 | 0.002683 |
| runtime-list-short | before | 0.029091 | 0.000333 |
| runtime-list-short | after | 0.029255 | 0.001108 |
| runtime-tree-short | before | 0.018207 | 0.000247 |
| runtime-tree-short | after | 0.018439 | 0.000791 |
| runtime-eval-short | before | 0.021912 | 0.000130 |
| runtime-eval-short | after | 0.022138 | 0.000669 |
| runtime-string-short | before | 0.016624 | 0.000250 |
| runtime-string-short | after | 0.016728 | 0.000295 |
| runtime-println-short | before | 0.017023 | 0.000357 |
| runtime-println-short | after | 0.017138 | 0.000118 |
| runtime-lines-short | before | 0.016701 | 0.000292 |
| runtime-lines-short | after | 0.016789 | 0.000292 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5166e-05 | 4.17e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.958e-06 | 5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8124e-05 | 1.084e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.2583e-05 | 9.17e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.708e-06 | 3.33e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.5291e-05 | 1.25e-06 |
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
    "after": "f4dda59f35807b7555992ea7c8ac74ab0e31aa8f"
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
| functions-main-1000-0 | 達成 | 0.0011697489999988875 | 0.003056720899999732 |
| functions-main-1000-1 | 達成 | 0.0007604169999950727 | 0.0030812208000000397 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004720641599999454 |
| functions-args-1000-1 | 判定不能 | None | 0.004727183299999638 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0024263959000009553 |
| functions-modules-1000-1 | 判定不能 | None | 0.0024472457999991093 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 達成 | 0.0010153340000016442 | 0.002 |
| higher-0-300 | 達成 | 0.001055708999999183 | 0.002618516600000476 |
| higher-1-300 | 判定不能 | None | 0.002903558399999895 |
| classes-300 | 達成 | 0.0009677500000009331 | 0.0037545958000009707 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 達成 | 0.00030283399998154437 | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003939837500000465 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003820862500000999 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038845875000006916 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038009957999989297 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003917754200000445 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038031290999995804 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003932316700000627 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0038276458999987996 |
| order-string-candidates | 判定不能 | None | 0.003847866599998895 |
| order-string-all-ok | 判定不能 | None | 0.003848075000000506 |
| order-string-always-error | 判定不能 | None | 0.0037884209000011992 |
| order-map-candidates | 判定不能 | None | 0.0038595000000000825 |
| order-map-all-ok | 判定不能 | None | 0.0038807167000001644 |
| order-map-always-error | 判定不能 | None | 0.00382094579999972 |
| order-record-candidates | 判定不能 | None | 0.003838274999999669 |
| order-record-all-ok | 判定不能 | None | 0.0038623541000006867 |
| order-record-always-error | 判定不能 | None | 0.003869316700000525 |
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
| runtime-loop-short | 判定不能 | None | 0.002374983299999656 |
| runtime-list-short | 判定不能 | None | 0.0029091000000008196 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002191229100000669 |
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
    "verify": 1.849526333,
    "cli": 5.298375790000023,
    "warmup": 0.6617696669999589,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9078391669999917,
    "cli": 3.596640915999984,
    "warmup": 0.4290965409999643,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3400766249999947,
    "cli": 9.334226042000026,
    "warmup": 1.3266432059999858,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3606800829999912,
    "cli": 3.510651334000002,
    "warmup": 0.35692862600002684,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09781116700000325,
    "cli": 0.2768935830000032,
    "warmup": 0.0292683750000009,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03654395800000998,
    "cli": 0.3281561659999994,
    "warmup": 0.0344286259999933,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.00944441699999743,
    "cli": 0.20066004199999554,
    "warmup": 0.00869291699999053,
    "probe_warmup": 0.007907332999991468,
    "rss": 0,
    "stages": 0.03788108500000931,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04112045800000885,
    "cli": 0.33970620899999915,
    "warmup": 0.03603995800000348,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17822441699999558
  },
  "runtime": {
    "verify": 0.33225137499999846,
    "cli": 2.897278084000021,
    "warmup": 0.32558875000003695,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
