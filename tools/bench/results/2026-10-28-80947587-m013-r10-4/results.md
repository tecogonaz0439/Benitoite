# 版どうしの性能比較

候補: `8094758783cf5dadf955404884ee39b8a8e4090b`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.015956 | 0.001271 |
| functions-main-0-0 | after | 0.015476 | 0.000733 |
| functions-main-0-1 | before | 0.015135 | 0.000604 |
| functions-main-0-1 | after | 0.015153 | 0.000939 |
| functions-main-64-0 | before | 0.015784 | 0.000539 |
| functions-main-64-0 | after | 0.015721 | 0.000686 |
| functions-main-256-0 | before | 0.015838 | 0.000435 |
| functions-main-256-0 | after | 0.016433 | 0.000511 |
| functions-main-1000-0 | before | 0.021278 | 0.000483 |
| functions-main-1000-0 | after | 0.021494 | 0.001610 |
| functions-main-1000-1 | before | 0.021924 | 0.000528 |
| functions-main-1000-1 | after | 0.022823 | 0.001764 |
| functions-args-0-0 | before | 0.013843 | 0.001890 |
| functions-args-0-0 | after | 0.014041 | 0.000579 |
| functions-args-0-1 | before | 0.014351 | 0.000858 |
| functions-args-0-1 | after | 0.014804 | 0.000487 |
| functions-args-1000-0 | before | 0.028070 | 0.000436 |
| functions-args-1000-0 | after | 0.028978 | 0.001883 |
| functions-args-1000-1 | before | 0.027143 | 0.000203 |
| functions-args-1000-1 | after | 0.027954 | 0.001470 |
| functions-modules-0-0 | before | 0.013549 | 0.001205 |
| functions-modules-0-0 | after | 0.013712 | 0.000183 |
| functions-modules-0-1 | before | 0.013917 | 0.001686 |
| functions-modules-0-1 | after | 0.013962 | 0.000166 |
| functions-modules-1000-0 | before | 0.022248 | 0.000282 |
| functions-modules-1000-0 | after | 0.023407 | 0.001704 |
| functions-modules-1000-1 | before | 0.022171 | 0.000518 |
| functions-modules-1000-1 | after | 0.023123 | 0.000480 |
| existing-fib | before | 0.015153 | 0.000808 |
| existing-fib | after | 0.015447 | 0.000368 |
| existing-loop | before | 0.014810 | 0.000379 |
| existing-loop | after | 0.014835 | 0.000796 |
| existing-string | before | 0.015505 | 0.000708 |
| existing-string | after | 0.015726 | 0.000687 |
| higher-0-0 | before | 0.015335 | 0.000392 |
| higher-0-0 | after | 0.015646 | 0.000958 |
| higher-1-0 | before | 0.015847 | 0.001263 |
| higher-1-0 | after | 0.015681 | 0.001588 |
| classes-0 | before | 0.019390 | 0.002343 |
| classes-0 | after | 0.019624 | 0.000850 |
| higher-0-300 | before | 0.031297 | 0.000491 |
| higher-0-300 | after | 0.032216 | 0.000538 |
| higher-1-300 | before | 0.033611 | 0.001375 |
| higher-1-300 | after | 0.033207 | 0.001248 |
| classes-300 | before | 0.040083 | 0.002105 |
| classes-300 | after | 0.040397 | 0.001058 |
| depth-0-8 | before | 0.015170 | 0.000579 |
| depth-0-8 | after | 0.015229 | 0.000341 |
| depth-1-8 | before | 0.015309 | 0.001090 |
| depth-1-8 | after | 0.015534 | 0.000336 |
| f1-nofail-call | before | 0.015507 | 0.001219 |
| f1-nofail-call | after | 0.015835 | 0.000570 |
| f1-join-effects | before | 0.014606 | 0.000946 |
| f1-join-effects | after | 0.015250 | 0.000533 |
| control-16.3 | before | 0.014074 | 0.000655 |
| control-16.3 | after | 0.014076 | 0.000170 |
| interval-bind-64 | before | 0.014123 | 0.000669 |
| interval-bind-64 | after | 0.014619 | 0.000953 |
| interval-bind-256 | before | 0.014517 | 0.001095 |
| interval-bind-256 | after | 0.014732 | 0.000458 |
| interval-add-64 | before | 0.013867 | 0.001627 |
| interval-add-64 | after | 0.014336 | 0.000606 |
| interval-add-256 | before | 0.015507 | 0.001699 |
| interval-add-256 | after | 0.015780 | 0.000356 |
| interval-flow-64 | before | 0.014987 | 0.000911 |
| interval-flow-64 | after | 0.015666 | 0.000648 |
| interval-flow-256 | before | 0.017883 | 0.000975 |
| interval-flow-256 | after | 0.018633 | 0.000784 |
| interval-range-0 | before | 0.019220 | 0.000322 |
| interval-range-0 | after | 0.019967 | 0.002167 |
| interval-range-64 | before | 0.023768 | 0.000803 |
| interval-range-64 | after | 0.024949 | 0.001062 |
| interval-range-256 | before | 0.036114 | 0.001011 |
| interval-range-256 | after | 0.037028 | 0.000545 |
| interval-http-0 | before | 0.019155 | 0.000347 |
| interval-http-0 | after | 0.019838 | 0.000991 |
| interval-http-64 | before | 0.022267 | 0.000434 |
| interval-http-64 | after | 0.023465 | 0.000891 |
| interval-http-256 | before | 0.030106 | 0.000178 |
| interval-http-256 | after | 0.031206 | 0.003171 |
| interval-width-Integer8-64 | before | 0.014270 | 0.000826 |
| interval-width-Integer8-64 | after | 0.014357 | 0.000620 |
| interval-width-Integer8-256 | before | 0.017299 | 0.000339 |
| interval-width-Integer8-256 | after | 0.017390 | 0.000224 |
| interval-width-Integer16-64 | before | 0.014346 | 0.000934 |
| interval-width-Integer16-64 | after | 0.014589 | 0.000823 |
| interval-width-Integer16-256 | before | 0.017281 | 0.000378 |
| interval-width-Integer16-256 | after | 0.017543 | 0.000330 |
| interval-width-Integer32-64 | before | 0.014401 | 0.001334 |
| interval-width-Integer32-64 | after | 0.014558 | 0.000238 |
| interval-width-Integer32-256 | before | 0.017062 | 0.000484 |
| interval-width-Integer32-256 | after | 0.017400 | 0.000185 |
| interval-width-Integer64-64 | before | 0.014789 | 0.001374 |
| interval-width-Integer64-64 | after | 0.014942 | 0.000459 |
| interval-width-Integer64-256 | before | 0.016796 | 0.000502 |
| interval-width-Integer64-256 | after | 0.017572 | 0.000339 |
| interval-width-UnsignedInteger16-64 | before | 0.014229 | 0.000920 |
| interval-width-UnsignedInteger16-64 | after | 0.014369 | 0.000154 |
| interval-width-UnsignedInteger16-256 | before | 0.016908 | 0.000457 |
| interval-width-UnsignedInteger16-256 | after | 0.017404 | 0.000338 |
| interval-width-UnsignedInteger32-64 | before | 0.014464 | 0.001069 |
| interval-width-UnsignedInteger32-64 | after | 0.014411 | 0.000376 |
| interval-width-UnsignedInteger32-256 | before | 0.017028 | 0.000578 |
| interval-width-UnsignedInteger32-256 | after | 0.017111 | 0.000238 |
| interval-width-UnsignedInteger64-64 | before | 0.014256 | 0.001218 |
| interval-width-UnsignedInteger64-64 | after | 0.014481 | 0.000350 |
| interval-width-UnsignedInteger64-256 | before | 0.016966 | 0.000436 |
| interval-width-UnsignedInteger64-256 | after | 0.017276 | 0.000301 |
| property-seven-24-20-1000-all-ok | before | 0.037487 | 0.001436 |
| property-seven-24-20-1000-all-ok | after | 0.038745 | 0.000816 |
| property-seven-24-20-1000-always-error | before | 0.036078 | 0.000806 |
| property-seven-24-20-1000-always-error | after | 0.036850 | 0.000800 |
| property-distinct-24-20-1000-all-ok | before | 0.036423 | 0.002272 |
| property-distinct-24-20-1000-all-ok | after | 0.037555 | 0.000928 |
| property-distinct-24-20-1000-always-error | before | 0.035910 | 0.001846 |
| property-distinct-24-20-1000-always-error | after | 0.036746 | 0.000158 |
| property-zero-24-20-1000-all-ok | before | 0.037146 | 0.001996 |
| property-zero-24-20-1000-all-ok | after | 0.038167 | 0.000754 |
| property-zero-24-20-1000-always-error | before | 0.035904 | 0.001975 |
| property-zero-24-20-1000-always-error | after | 0.036730 | 0.000413 |
| property-max-24-20-1000-all-ok | before | 0.037282 | 0.002170 |
| property-max-24-20-1000-all-ok | after | 0.038160 | 0.000668 |
| property-max-24-20-1000-always-error | before | 0.035951 | 0.001520 |
| property-max-24-20-1000-always-error | after | 0.036269 | 0.000480 |
| order-string-candidates | before | 0.036063 | 0.000761 |
| order-string-candidates | after | 0.036147 | 0.001147 |
| order-string-all-ok | before | 0.036421 | 0.002592 |
| order-string-all-ok | after | 0.037480 | 0.000462 |
| order-string-always-error | before | 0.038067 | 0.001774 |
| order-string-always-error | after | 0.037528 | 0.001934 |
| order-map-candidates | before | 0.036537 | 0.002680 |
| order-map-candidates | after | 0.036762 | 0.000361 |
| order-map-all-ok | before | 0.037398 | 0.001511 |
| order-map-all-ok | after | 0.037234 | 0.000561 |
| order-map-always-error | before | 0.036206 | 0.000855 |
| order-map-always-error | after | 0.037110 | 0.000460 |
| order-record-candidates | before | 0.036674 | 0.001728 |
| order-record-candidates | after | 0.037018 | 0.000481 |
| order-record-all-ok | before | 0.036645 | 0.001327 |
| order-record-all-ok | after | 0.037530 | 0.000600 |
| order-record-always-error | before | 0.036929 | 0.001774 |
| order-record-always-error | after | 0.037983 | 0.000317 |
| build-string-builder-8-0 | before | 0.017139 | 0.000786 |
| build-string-builder-8-0 | after | 0.017084 | 0.000995 |
| build-string-builder-all-8-0 | before | 0.016640 | 0.000619 |
| build-string-builder-all-8-0 | after | 0.017044 | 0.002227 |
| build-string-concatenate-8-0 | before | 0.016683 | 0.000637 |
| build-string-concatenate-8-0 | after | 0.017132 | 0.000761 |
| build-string-join-8-0 | before | 0.016522 | 0.000184 |
| build-string-join-8-0 | after | 0.016628 | 0.000083 |
| build-list-builder-8-0 | before | 0.016885 | 0.000431 |
| build-list-builder-8-0 | after | 0.017024 | 0.000969 |
| build-list-builder-all-8-0 | before | 0.016541 | 0.000358 |
| build-list-builder-all-8-0 | after | 0.017036 | 0.000062 |
| build-list-concatenate-8-0 | before | 0.016898 | 0.000363 |
| build-list-concatenate-8-0 | after | 0.016886 | 0.000771 |
| build-list-fold-8-0 | before | 0.016668 | 0.000674 |
| build-list-fold-8-0 | after | 0.016560 | 0.000830 |
| build-bytes-builder-8-0 | before | 0.016266 | 0.000529 |
| build-bytes-builder-8-0 | after | 0.016350 | 0.000239 |
| build-bytes-builder-all-8-0 | before | 0.016439 | 0.000459 |
| build-bytes-builder-all-8-0 | after | 0.016582 | 0.000316 |
| build-bytes-concatenate-8-0 | before | 0.017403 | 0.000612 |
| build-bytes-concatenate-8-0 | after | 0.017046 | 0.000451 |
| patterns-integer-100 | before | 0.015914 | 0.000613 |
| patterns-integer-100 | after | 0.016368 | 0.001761 |
| codegen-let-100 | before | 0.018384 | 0.000544 |
| codegen-let-100 | after | 0.018548 | 0.000931 |
| bridge-shared-8 | before | 0.004858 | 0.000770 |
| external-tests-normal-1 | before | 0.019425 | 0.000333 |
| external-tests-normal-1 | after | 0.019988 | 0.001949 |
| runtime-fib-short | before | 0.019117 | 0.000828 |
| runtime-fib-short | after | 0.020482 | 0.001772 |
| runtime-loop-short | before | 0.025520 | 0.000581 |
| runtime-loop-short | after | 0.025841 | 0.001896 |
| runtime-list-short | before | 0.032505 | 0.000676 |
| runtime-list-short | after | 0.032749 | 0.001084 |
| runtime-tree-short | before | 0.019562 | 0.000525 |
| runtime-tree-short | after | 0.020509 | 0.001589 |
| runtime-eval-short | before | 0.023043 | 0.000638 |
| runtime-eval-short | after | 0.023494 | 0.000828 |
| runtime-string-short | before | 0.018109 | 0.000546 |
| runtime-string-short | after | 0.018573 | 0.002132 |
| runtime-println-short | before | 0.018702 | 0.000916 |
| runtime-println-short | after | 0.019426 | 0.001938 |
| runtime-lines-short | before | 0.018262 | 0.000355 |
| runtime-lines-short | after | 0.018340 | 0.001701 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 2.2e-05 | 2.917e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.542e-06 | 3.34e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.5542e-05 | 3.251e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| runtime_compilations | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| runtime_compilations | count | external-tests-normal-1 | after | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | after | 5 | 1 | 0 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "6124775788579e60530f55fb85570f26ef7fa900",
    "after": "8094758783cf5dadf955404884ee39b8a8e4090b"
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
      "timing_probe": false
    }
  },
  "skipped": [
    {
      "case": "bridge-shared-8",
      "state": "after",
      "reason": "missing features: timing_probe"
    }
  ],
  "unavailable_probes": {
    "after": "public API helper build failed (1); see <repo>/target/bench/builds/8094758783cf5dadf955404884ee39b8a8e4090b-default/build.log"
  }
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| functions-main-0-0 | 判定不能 | None | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.002127837500000851 |
| functions-main-1000-1 | 判定不能 | None | 0.002192366599999218 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0028069999999999597 |
| functions-args-1000-1 | 判定不能 | None | 0.0027143249999994623 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0022248125000004395 |
| functions-modules-1000-1 | 判定不能 | None | 0.002217141600000616 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.003129712500000892 |
| higher-1-300 | 判定不能 | None | 0.0033611415999999397 |
| classes-300 | 判定不能 | None | 0.004008258300000023 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 判定不能 | None | 0.002 |
| interval-range-64 | 判定不能 | None | 0.002376829199999975 |
| interval-range-256 | 判定不能 | None | 0.0036114207999986547 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.002226699999999937 |
| interval-http-256 | 判定不能 | None | 0.0030106459000009524 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.00374868340000063 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003607804199999976 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003642333300000189 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0035909500000002484 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.00371459999999928 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003590383399999553 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.00372822080000077 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0035950542000009024 |
| order-string-candidates | 判定不能 | None | 0.0036063249999997993 |
| order-string-all-ok | 判定不能 | None | 0.0036421000000004256 |
| order-string-always-error | 判定不能 | None | 0.003806737500001134 |
| order-map-candidates | 判定不能 | None | 0.003653733400000192 |
| order-map-all-ok | 判定不能 | None | 0.0037397540999990044 |
| order-map-always-error | 判定不能 | None | 0.0036205875000007385 |
| order-record-candidates | 判定不能 | None | 0.00366741659999974 |
| order-record-all-ok | 判定不能 | None | 0.0036645250000006515 |
| order-record-always-error | 判定不能 | None | 0.003692858399999466 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 達成 | 0.000495291999982328 | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0025520082999989317 |
| runtime-list-short | 判定不能 | None | 0.003250504199999682 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0023043208000018468 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002 |
| bridge-shared-8 | 判定不能 | None | None |
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
    "verify": 1.0419465840000015,
    "cli": 5.637701662999987,
    "warmup": 0.6258419590000273,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.285353958999991,
    "cli": 12.310439416999998,
    "warmup": 1.4086669569999657,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3575792089999936,
    "cli": 9.156508750000057,
    "warmup": 1.2658020819999933,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.41169441700000675,
    "cli": 3.70101820699999,
    "warmup": 0.37251749900005393,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09046654200000148,
    "cli": 0.3113937500000077,
    "warmup": 0.031192125000046644,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04388591700001143,
    "cli": 0.3577204999999992,
    "warmup": 0.039322500000025684,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.007553040999994209,
    "cli": 0.10393691699999863,
    "warmup": 0.005106874999995625,
    "probe_warmup": 0.006831250000004729,
    "rss": 0,
    "stages": 0.02555983299998843,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.05016791699999601,
    "cli": 0.3714272499999822,
    "warmup": 0.03807320800004277,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.19331616599995982
  },
  "runtime": {
    "verify": 0.3721717499999926,
    "cli": 3.193724666999998,
    "warmup": 0.3548674590000189,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
