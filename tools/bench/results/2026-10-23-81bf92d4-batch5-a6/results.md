# 版どうしの性能比較

候補: `81bf92d4a6fe7c79e7193f716c0b286ef1a3ed93`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013046 | 0.000119 |
| functions-main-0-0 | after | 0.013060 | 0.000713 |
| functions-main-0-1 | before | 0.013194 | 0.000309 |
| functions-main-0-1 | after | 0.012987 | 0.000088 |
| functions-main-1000-0 | before | 0.031136 | 0.000570 |
| functions-main-1000-0 | after | 0.031396 | 0.000479 |
| functions-main-1000-1 | before | 0.031084 | 0.000219 |
| functions-main-1000-1 | after | 0.031387 | 0.000294 |
| functions-args-0-0 | before | 0.013318 | 0.000898 |
| functions-args-0-0 | after | 0.013581 | 0.000346 |
| functions-args-0-1 | before | 0.013100 | 0.000132 |
| functions-args-0-1 | after | 0.013204 | 0.000154 |
| functions-args-1000-0 | before | 0.047616 | 0.000501 |
| functions-args-1000-0 | after | 0.047385 | 0.000597 |
| functions-args-1000-1 | before | 0.047419 | 0.000411 |
| functions-args-1000-1 | after | 0.047446 | 0.000375 |
| functions-modules-0-0 | before | 0.012978 | 0.000071 |
| functions-modules-0-0 | after | 0.013037 | 0.000209 |
| functions-modules-0-1 | before | 0.013182 | 0.000793 |
| functions-modules-0-1 | after | 0.013266 | 0.000286 |
| functions-modules-1000-0 | before | 0.024033 | 0.000309 |
| functions-modules-1000-0 | after | 0.024550 | 0.000830 |
| functions-modules-1000-1 | before | 0.024008 | 0.000351 |
| functions-modules-1000-1 | after | 0.024414 | 0.000502 |
| existing-fib | before | 0.013498 | 0.000686 |
| existing-fib | after | 0.013595 | 0.000163 |
| existing-loop | before | 0.013576 | 0.000538 |
| existing-loop | after | 0.013622 | 0.000231 |
| existing-string | before | 0.013541 | 0.000551 |
| existing-string | after | 0.013705 | 0.000185 |
| higher-0-0 | before | 0.013325 | 0.000816 |
| higher-0-0 | after | 0.013070 | 0.000485 |
| higher-1-0 | before | 0.014000 | 0.000573 |
| higher-1-0 | after | 0.013837 | 0.000195 |
| classes-0 | before | 0.019021 | 0.000392 |
| classes-0 | after | 0.018948 | 0.000578 |
| higher-0-300 | before | 0.026191 | 0.000229 |
| higher-0-300 | after | 0.026756 | 0.000708 |
| higher-1-300 | before | 0.028899 | 0.000246 |
| higher-1-300 | after | 0.029732 | 0.000743 |
| classes-300 | before | 0.037345 | 0.001161 |
| classes-300 | after | 0.037811 | 0.000397 |
| depth-0-8 | before | 0.014372 | 0.001031 |
| depth-0-8 | after | 0.014504 | 0.000156 |
| depth-1-8 | before | 0.014643 | 0.000744 |
| depth-1-8 | after | 0.014710 | 0.000110 |
| f1-nofail-call | before | 0.013975 | 0.000420 |
| f1-nofail-call | after | 0.014019 | 0.000097 |
| f1-join-effects | before | 0.013770 | 0.000615 |
| f1-join-effects | after | 0.013899 | 0.000109 |
| control-16.3 | before | 0.012926 | 0.000165 |
| control-16.3 | after | 0.012998 | 0.000087 |
| property-seven-24-20-1000-all-ok | before | 0.039444 | 0.001104 |
| property-seven-24-20-1000-all-ok | after | 0.039620 | 0.000251 |
| property-seven-24-20-1000-always-error | before | 0.037940 | 0.001116 |
| property-seven-24-20-1000-always-error | after | 0.037979 | 0.000338 |
| property-distinct-24-20-1000-all-ok | before | 0.038296 | 0.001087 |
| property-distinct-24-20-1000-all-ok | after | 0.038988 | 0.000478 |
| property-distinct-24-20-1000-always-error | before | 0.038305 | 0.000643 |
| property-distinct-24-20-1000-always-error | after | 0.038261 | 0.000287 |
| property-zero-24-20-1000-all-ok | before | 0.038951 | 0.001115 |
| property-zero-24-20-1000-all-ok | after | 0.039388 | 0.000243 |
| property-zero-24-20-1000-always-error | before | 0.038039 | 0.000832 |
| property-zero-24-20-1000-always-error | after | 0.038099 | 0.000132 |
| property-max-24-20-1000-all-ok | before | 0.039643 | 0.001436 |
| property-max-24-20-1000-all-ok | after | 0.040011 | 0.000341 |
| property-max-24-20-1000-always-error | before | 0.038130 | 0.000817 |
| property-max-24-20-1000-always-error | after | 0.038130 | 0.000458 |
| order-string-candidates | before | 0.037374 | 0.000912 |
| order-string-candidates | after | 0.037762 | 0.000425 |
| order-string-all-ok | before | 0.038415 | 0.001116 |
| order-string-all-ok | after | 0.038339 | 0.000225 |
| order-string-always-error | before | 0.037483 | 0.001030 |
| order-string-always-error | after | 0.038179 | 0.000483 |
| order-map-candidates | before | 0.037957 | 0.001103 |
| order-map-candidates | after | 0.038286 | 0.000203 |
| order-map-all-ok | before | 0.038133 | 0.001082 |
| order-map-all-ok | after | 0.038500 | 0.000294 |
| order-map-always-error | before | 0.037804 | 0.001090 |
| order-map-always-error | after | 0.038254 | 0.000289 |
| order-record-candidates | before | 0.038526 | 0.000853 |
| order-record-candidates | after | 0.038568 | 0.000267 |
| order-record-all-ok | before | 0.038665 | 0.000892 |
| order-record-all-ok | after | 0.038772 | 0.000469 |
| order-record-always-error | before | 0.038348 | 0.000835 |
| order-record-always-error | after | 0.038752 | 0.000301 |
| build-string-builder-8-0 | before | 0.015712 | 0.000180 |
| build-string-builder-8-0 | after | 0.015683 | 0.000125 |
| build-string-builder-all-8-0 | before | 0.015687 | 0.000224 |
| build-string-builder-all-8-0 | after | 0.015916 | 0.000089 |
| build-string-concatenate-8-0 | before | 0.015461 | 0.000451 |
| build-string-concatenate-8-0 | after | 0.015717 | 0.000287 |
| build-string-join-8-0 | before | 0.015805 | 0.000809 |
| build-string-join-8-0 | after | 0.015648 | 0.000176 |
| build-list-builder-8-0 | before | 0.015767 | 0.000457 |
| build-list-builder-8-0 | after | 0.015892 | 0.000079 |
| build-list-builder-all-8-0 | before | 0.015777 | 0.000685 |
| build-list-builder-all-8-0 | after | 0.015773 | 0.000135 |
| build-list-concatenate-8-0 | before | 0.016063 | 0.000291 |
| build-list-concatenate-8-0 | after | 0.015984 | 0.000088 |
| build-list-fold-8-0 | before | 0.015862 | 0.000596 |
| build-list-fold-8-0 | after | 0.015866 | 0.000070 |
| build-bytes-builder-8-0 | before | 0.015830 | 0.000217 |
| build-bytes-builder-8-0 | after | 0.016008 | 0.000350 |
| build-bytes-builder-all-8-0 | before | 0.015899 | 0.000233 |
| build-bytes-builder-all-8-0 | after | 0.015863 | 0.000189 |
| build-bytes-concatenate-8-0 | before | 0.016142 | 0.000382 |
| build-bytes-concatenate-8-0 | after | 0.016107 | 0.000898 |
| patterns-integer-100 | before | 0.014230 | 0.000423 |
| patterns-integer-100 | after | 0.014318 | 0.000206 |
| codegen-let-100 | before | 0.016701 | 0.000267 |
| codegen-let-100 | after | 0.016519 | 0.000135 |
| bridge-shared-8 | before | 0.004393 | 0.000118 |
| bridge-shared-8 | after | 0.004207 | 0.000399 |
| external-tests-normal-1 | before | 0.017639 | 0.000229 |
| external-tests-normal-1 | after | 0.017852 | 0.000254 |
| runtime-fib-short | before | 0.017858 | 0.000419 |
| runtime-fib-short | after | 0.017840 | 0.000613 |
| runtime-loop-short | before | 0.023340 | 0.000168 |
| runtime-loop-short | after | 0.023614 | 0.000641 |
| runtime-list-short | before | 0.028989 | 0.000272 |
| runtime-list-short | after | 0.029238 | 0.000791 |
| runtime-tree-short | before | 0.017927 | 0.000398 |
| runtime-tree-short | after | 0.018358 | 0.000535 |
| runtime-eval-short | before | 0.021729 | 0.000149 |
| runtime-eval-short | after | 0.022202 | 0.000670 |
| runtime-string-short | before | 0.016581 | 0.000301 |
| runtime-string-short | after | 0.016444 | 0.000199 |
| runtime-println-short | before | 0.016661 | 0.000351 |
| runtime-println-short | after | 0.016823 | 0.000109 |
| runtime-lines-short | before | 0.016477 | 0.000439 |
| runtime-lines-short | after | 0.016502 | 0.000166 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5333e-05 | 2.041e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.75e-06 | 4.17e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8333e-05 | 2.625e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.2041e-05 | 6.67e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.834e-06 | 1.25e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.4833e-05 | 7.92e-07 |
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
    "after": "81bf92d4a6fe7c79e7193f716c0b286ef1a3ed93"
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
| functions-main-1000-0 | 判定不能 | None | 0.0031135790999996973 |
| functions-main-1000-1 | 判定不能 | None | 0.0031083792000003996 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004761633299999346 |
| functions-args-1000-1 | 判定不能 | None | 0.004741862500000593 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0024033458000005227 |
| functions-modules-1000-1 | 判定不能 | None | 0.002400766700000645 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0026191125000011085 |
| higher-1-300 | 判定不能 | None | 0.0028898583000000148 |
| classes-300 | 判定不能 | None | 0.003734545799999012 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003944362499998988 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003793958299999645 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003829558399999655 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038304624999994986 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0038951457999999665 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003803916700000798 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003964324999999747 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0038130249999994703 |
| order-string-candidates | 判定不能 | None | 0.0037374499999998536 |
| order-string-all-ok | 判定不能 | None | 0.0038414583000005113 |
| order-string-always-error | 判定不能 | None | 0.003748291699999129 |
| order-map-candidates | 判定不能 | None | 0.003795695800000942 |
| order-map-all-ok | 判定不能 | None | 0.003813333399999408 |
| order-map-always-error | 判定不能 | None | 0.003780391600000144 |
| order-record-candidates | 判定不能 | None | 0.0038526332999992974 |
| order-record-all-ok | 判定不能 | None | 0.0038664707999998883 |
| order-record-always-error | 判定不能 | None | 0.0038347833999992534 |
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
| runtime-loop-short | 判定不能 | None | 0.002333970800000884 |
| runtime-list-short | 判定不能 | None | 0.0028989041999992085 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0021729416000013657 |
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
    "verify": 1.828122042000004,
    "cli": 5.284758081999996,
    "warmup": 0.6594457880000562,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.8999172500000014,
    "cli": 3.5634673749999877,
    "warmup": 0.4232065000000631,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3286737500000072,
    "cli": 9.262843915000005,
    "warmup": 1.3162480019999663,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3611764169999958,
    "cli": 3.476005624000038,
    "warmup": 0.3506462900000571,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09799845799999218,
    "cli": 0.27461166700000206,
    "warmup": 0.028871083999987945,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.036206250000006435,
    "cli": 0.32406279200000654,
    "warmup": 0.033596000000002846,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009384249999996541,
    "cli": 0.1972834999999975,
    "warmup": 0.008817373999988831,
    "probe_warmup": 0.0075230419999883225,
    "rss": 0,
    "stages": 0.037808665999989444,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.038525874999990606,
    "cli": 0.3338652090000096,
    "warmup": 0.03525458300001105,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17646795799997506
  },
  "runtime": {
    "verify": 0.33614733299999955,
    "cli": 2.865280501000001,
    "warmup": 0.32372754300003237,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
