# 版どうしの性能比較

候補: `78c34404b4283c4731d460ce6bd87a81fe440960`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013384 | 0.000227 |
| functions-main-0-0 | after | 0.013689 | 0.000713 |
| functions-main-0-1 | before | 0.013158 | 0.000614 |
| functions-main-0-1 | after | 0.013133 | 0.000153 |
| functions-main-1000-0 | before | 0.030794 | 0.000614 |
| functions-main-1000-0 | after | 0.031645 | 0.000199 |
| functions-main-1000-1 | before | 0.030805 | 0.000325 |
| functions-main-1000-1 | after | 0.031809 | 0.000326 |
| functions-args-0-0 | before | 0.013268 | 0.000377 |
| functions-args-0-0 | after | 0.013425 | 0.000152 |
| functions-args-0-1 | before | 0.013385 | 0.000458 |
| functions-args-0-1 | after | 0.013508 | 0.000250 |
| functions-args-1000-0 | before | 0.047449 | 0.000860 |
| functions-args-1000-0 | after | 0.048278 | 0.000406 |
| functions-args-1000-1 | before | 0.047413 | 0.000625 |
| functions-args-1000-1 | after | 0.048196 | 0.000442 |
| functions-modules-0-0 | before | 0.013187 | 0.000108 |
| functions-modules-0-0 | after | 0.013320 | 0.000220 |
| functions-modules-0-1 | before | 0.013069 | 0.000332 |
| functions-modules-0-1 | after | 0.013279 | 0.000237 |
| functions-modules-1000-0 | before | 0.024388 | 0.000131 |
| functions-modules-1000-0 | after | 0.025018 | 0.000593 |
| functions-modules-1000-1 | before | 0.024255 | 0.000098 |
| functions-modules-1000-1 | after | 0.025171 | 0.000804 |
| existing-fib | before | 0.013914 | 0.000516 |
| existing-fib | after | 0.013867 | 0.000698 |
| existing-loop | before | 0.013621 | 0.000664 |
| existing-loop | after | 0.013795 | 0.000212 |
| existing-string | before | 0.013753 | 0.000439 |
| existing-string | after | 0.013727 | 0.000037 |
| higher-0-0 | before | 0.013182 | 0.000477 |
| higher-0-0 | after | 0.013239 | 0.000157 |
| higher-1-0 | before | 0.014133 | 0.000510 |
| higher-1-0 | after | 0.014119 | 0.000259 |
| classes-0 | before | 0.019223 | 0.000275 |
| classes-0 | after | 0.019735 | 0.000864 |
| higher-0-300 | before | 0.026340 | 0.000344 |
| higher-0-300 | after | 0.027221 | 0.000908 |
| higher-1-300 | before | 0.029291 | 0.000650 |
| higher-1-300 | after | 0.030023 | 0.000574 |
| classes-300 | before | 0.037668 | 0.000815 |
| classes-300 | after | 0.038334 | 0.000265 |
| depth-0-8 | before | 0.014729 | 0.000436 |
| depth-0-8 | after | 0.014638 | 0.000079 |
| depth-1-8 | before | 0.014824 | 0.000477 |
| depth-1-8 | after | 0.014849 | 0.000150 |
| f1-nofail-call | before | 0.014141 | 0.000592 |
| f1-nofail-call | after | 0.014236 | 0.000103 |
| f1-join-effects | before | 0.013991 | 0.000429 |
| f1-join-effects | after | 0.014263 | 0.000116 |
| control-16.3 | before | 0.013239 | 0.000145 |
| control-16.3 | after | 0.013217 | 0.000117 |
| property-seven-24-20-1000-all-ok | before | 0.039815 | 0.000870 |
| property-seven-24-20-1000-all-ok | after | 0.039966 | 0.000248 |
| property-seven-24-20-1000-always-error | before | 0.038226 | 0.000963 |
| property-seven-24-20-1000-always-error | after | 0.038346 | 0.000241 |
| property-distinct-24-20-1000-all-ok | before | 0.038535 | 0.001045 |
| property-distinct-24-20-1000-all-ok | after | 0.039304 | 0.000316 |
| property-distinct-24-20-1000-always-error | before | 0.038408 | 0.001496 |
| property-distinct-24-20-1000-always-error | after | 0.038828 | 0.000812 |
| property-zero-24-20-1000-all-ok | before | 0.039120 | 0.001279 |
| property-zero-24-20-1000-all-ok | after | 0.039521 | 0.000688 |
| property-zero-24-20-1000-always-error | before | 0.038326 | 0.001147 |
| property-zero-24-20-1000-always-error | after | 0.038393 | 0.000279 |
| property-max-24-20-1000-all-ok | before | 0.039376 | 0.001056 |
| property-max-24-20-1000-all-ok | after | 0.039882 | 0.000212 |
| property-max-24-20-1000-always-error | before | 0.038202 | 0.000632 |
| property-max-24-20-1000-always-error | after | 0.038545 | 0.000289 |
| order-string-candidates | before | 0.038123 | 0.001268 |
| order-string-candidates | after | 0.038649 | 0.001092 |
| order-string-all-ok | before | 0.038553 | 0.000726 |
| order-string-all-ok | after | 0.038879 | 0.000100 |
| order-string-always-error | before | 0.037690 | 0.000983 |
| order-string-always-error | after | 0.038301 | 0.000345 |
| order-map-candidates | before | 0.038158 | 0.000588 |
| order-map-candidates | after | 0.038611 | 0.000388 |
| order-map-all-ok | before | 0.038559 | 0.001132 |
| order-map-all-ok | after | 0.038878 | 0.000331 |
| order-map-always-error | before | 0.038407 | 0.000887 |
| order-map-always-error | after | 0.038520 | 0.000383 |
| order-record-candidates | before | 0.038463 | 0.000897 |
| order-record-candidates | after | 0.038936 | 0.000300 |
| order-record-all-ok | before | 0.039085 | 0.000733 |
| order-record-all-ok | after | 0.039169 | 0.000509 |
| order-record-always-error | before | 0.038815 | 0.001380 |
| order-record-always-error | after | 0.039238 | 0.000267 |
| build-string-builder-8-0 | before | 0.016113 | 0.000359 |
| build-string-builder-8-0 | after | 0.015924 | 0.000170 |
| build-string-builder-all-8-0 | before | 0.015982 | 0.000148 |
| build-string-builder-all-8-0 | after | 0.016203 | 0.000302 |
| build-string-concatenate-8-0 | before | 0.015811 | 0.000347 |
| build-string-concatenate-8-0 | after | 0.015975 | 0.000227 |
| build-string-join-8-0 | before | 0.015765 | 0.000392 |
| build-string-join-8-0 | after | 0.015805 | 0.000143 |
| build-list-builder-8-0 | before | 0.016023 | 0.000284 |
| build-list-builder-8-0 | after | 0.016216 | 0.000049 |
| build-list-builder-all-8-0 | before | 0.015976 | 0.000278 |
| build-list-builder-all-8-0 | after | 0.016102 | 0.000267 |
| build-list-concatenate-8-0 | before | 0.016120 | 0.000347 |
| build-list-concatenate-8-0 | after | 0.016182 | 0.000126 |
| build-list-fold-8-0 | before | 0.016160 | 0.000423 |
| build-list-fold-8-0 | after | 0.016058 | 0.000219 |
| build-bytes-builder-8-0 | before | 0.016006 | 0.000418 |
| build-bytes-builder-8-0 | after | 0.016033 | 0.000159 |
| build-bytes-builder-all-8-0 | before | 0.016201 | 0.000394 |
| build-bytes-builder-all-8-0 | after | 0.016093 | 0.000156 |
| build-bytes-concatenate-8-0 | before | 0.016390 | 0.000464 |
| build-bytes-concatenate-8-0 | after | 0.016626 | 0.000348 |
| patterns-integer-100 | before | 0.014299 | 0.000850 |
| patterns-integer-100 | after | 0.014457 | 0.000067 |
| codegen-let-100 | before | 0.016839 | 0.000225 |
| codegen-let-100 | after | 0.017011 | 0.000879 |
| bridge-shared-8 | before | 0.004442 | 0.000340 |
| bridge-shared-8 | after | 0.004311 | 0.000468 |
| external-tests-normal-1 | before | 0.017884 | 0.000199 |
| external-tests-normal-1 | after | 0.018057 | 0.001427 |
| runtime-fib-short | before | 0.018087 | 0.000280 |
| runtime-fib-short | after | 0.018236 | 0.000546 |
| runtime-loop-short | before | 0.023689 | 0.000475 |
| runtime-loop-short | after | 0.024277 | 0.001021 |
| runtime-list-short | before | 0.029208 | 0.000990 |
| runtime-list-short | after | 0.029517 | 0.000503 |
| runtime-tree-short | before | 0.018399 | 0.000277 |
| runtime-tree-short | after | 0.018588 | 0.000920 |
| runtime-eval-short | before | 0.022012 | 0.000502 |
| runtime-eval-short | after | 0.022203 | 0.000719 |
| runtime-string-short | before | 0.016726 | 0.000307 |
| runtime-string-short | after | 0.016776 | 0.000102 |
| runtime-println-short | before | 0.017125 | 0.000228 |
| runtime-println-short | after | 0.017268 | 0.000162 |
| runtime-lines-short | before | 0.016676 | 0.000301 |
| runtime-lines-short | after | 0.016876 | 0.000175 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.4666e-05 | 4.17e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.833e-06 | 2.51e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.7499e-05 | 6.68e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.425e-05 | 7.07e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.5e-06 | 5e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8333e-05 | 1.082e-06 |
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
    "after": "78c34404b4283c4731d460ce6bd87a81fe440960"
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
| functions-main-1000-0 | 達成 | 0.0008509169999939559 | 0.003079429199999595 |
| functions-main-1000-1 | 達成 | 0.001004125000008571 | 0.0030804916999997546 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.00474494160000063 |
| functions-args-1000-1 | 判定不能 | None | 0.004741258299999629 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002438804099999459 |
| functions-modules-1000-1 | 達成 | 0.000915749999990112 | 0.002425541700000622 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002634037499998954 |
| higher-1-300 | 判定不能 | None | 0.002929108300000394 |
| classes-300 | 判定不能 | None | 0.0037667541999994118 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003981458300000895 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0038225749999995177 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0038535124999995677 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038408250000003365 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003911983300000088 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0038325834000005445 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003937625000000367 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003820191699999498 |
| order-string-candidates | 判定不能 | None | 0.0038122915999991847 |
| order-string-all-ok | 判定不能 | None | 0.0038553417000002812 |
| order-string-always-error | 判定不能 | None | 0.003768954099999178 |
| order-map-candidates | 判定不能 | None | 0.003815833299999838 |
| order-map-all-ok | 判定不能 | None | 0.0038559375000005503 |
| order-map-always-error | 判定不能 | None | 0.003840741599999831 |
| order-record-candidates | 判定不能 | None | 0.003846291600000029 |
| order-record-all-ok | 判定不能 | None | 0.003908454199999767 |
| order-record-always-error | 判定不能 | None | 0.00388149999999996 |
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
| runtime-loop-short | 判定不能 | None | 0.002368862499999125 |
| runtime-list-short | 判定不能 | None | 0.0029207624999997963 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022011917000000383 |
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
    "verify": 1.8180002079999866,
    "cli": 5.330971000999995,
    "warmup": 0.6695693370000271,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.9208529579999976,
    "cli": 3.6117310439999954,
    "warmup": 0.4288509569999803,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3598852079999943,
    "cli": 9.354168751000046,
    "warmup": 1.3285820050000154,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3620210830000019,
    "cli": 3.5286431669999985,
    "warmup": 0.3575728339999955,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09760395799999344,
    "cli": 0.2767756249999991,
    "warmup": 0.0295300839999868,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03631320800000992,
    "cli": 0.32989695799999197,
    "warmup": 0.03470799900000543,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009909457999995652,
    "cli": 0.20119079100000192,
    "warmup": 0.0086128750000114,
    "probe_warmup": 0.007578666000000567,
    "rss": 0,
    "stages": 0.038315332999985685,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.042575541000005046,
    "cli": 0.34120245799999793,
    "warmup": 0.03593170799999257,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17849874899998497
  },
  "runtime": {
    "verify": 0.33031991600000765,
    "cli": 2.916327542000019,
    "warmup": 0.3275698329999699,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
