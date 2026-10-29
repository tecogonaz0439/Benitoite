# 版どうしの性能比較

候補: `606a77db939936f46e6576fe592e5daa8ada0373`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013323 | 0.000325 |
| functions-main-0-0 | after | 0.013882 | 0.001207 |
| functions-main-0-1 | before | 0.013355 | 0.000653 |
| functions-main-0-1 | after | 0.013487 | 0.000303 |
| functions-main-64-0 | before | 0.013546 | 0.000771 |
| functions-main-64-0 | after | 0.013794 | 0.000315 |
| functions-main-256-0 | before | 0.015173 | 0.000773 |
| functions-main-256-0 | after | 0.015355 | 0.000261 |
| functions-main-1000-0 | before | 0.020355 | 0.000468 |
| functions-main-1000-0 | after | 0.020788 | 0.001094 |
| functions-main-1000-1 | before | 0.020562 | 0.000291 |
| functions-main-1000-1 | after | 0.021093 | 0.001569 |
| functions-args-0-0 | before | 0.013447 | 0.001068 |
| functions-args-0-0 | after | 0.013420 | 0.000207 |
| functions-args-0-1 | before | 0.013359 | 0.001302 |
| functions-args-0-1 | after | 0.013320 | 0.000208 |
| functions-args-1000-0 | before | 0.026624 | 0.000581 |
| functions-args-1000-0 | after | 0.027582 | 0.001021 |
| functions-args-1000-1 | before | 0.026594 | 0.000337 |
| functions-args-1000-1 | after | 0.027801 | 0.001002 |
| functions-modules-0-0 | before | 0.013395 | 0.000899 |
| functions-modules-0-0 | after | 0.013549 | 0.000309 |
| functions-modules-0-1 | before | 0.013720 | 0.000892 |
| functions-modules-0-1 | after | 0.013543 | 0.000268 |
| functions-modules-1000-0 | before | 0.021824 | 0.000831 |
| functions-modules-1000-0 | after | 0.022135 | 0.001268 |
| functions-modules-1000-1 | before | 0.020963 | 0.000526 |
| functions-modules-1000-1 | after | 0.021366 | 0.000323 |
| existing-fib | before | 0.013588 | 0.000887 |
| existing-fib | after | 0.013893 | 0.000204 |
| existing-loop | before | 0.013866 | 0.000475 |
| existing-loop | after | 0.014126 | 0.000228 |
| existing-string | before | 0.014042 | 0.002464 |
| existing-string | after | 0.014321 | 0.000412 |
| higher-0-0 | before | 0.013820 | 0.000551 |
| higher-0-0 | after | 0.013669 | 0.000460 |
| higher-1-0 | before | 0.014381 | 0.000960 |
| higher-1-0 | after | 0.014832 | 0.000493 |
| classes-0 | before | 0.017910 | 0.000617 |
| classes-0 | after | 0.018403 | 0.000245 |
| higher-0-300 | before | 0.028607 | 0.000886 |
| higher-0-300 | after | 0.029349 | 0.001871 |
| higher-1-300 | before | 0.031220 | 0.000674 |
| higher-1-300 | after | 0.032596 | 0.001298 |
| classes-300 | before | 0.036905 | 0.002112 |
| classes-300 | after | 0.038240 | 0.001269 |
| depth-0-8 | before | 0.014426 | 0.001474 |
| depth-0-8 | after | 0.014863 | 0.000242 |
| depth-1-8 | before | 0.014924 | 0.001433 |
| depth-1-8 | after | 0.015456 | 0.000216 |
| f1-nofail-call | before | 0.014227 | 0.000751 |
| f1-nofail-call | after | 0.014681 | 0.000158 |
| f1-join-effects | before | 0.014832 | 0.001655 |
| f1-join-effects | after | 0.015221 | 0.000136 |
| control-16.3 | before | 0.013199 | 0.000737 |
| control-16.3 | after | 0.013665 | 0.000259 |
| interval-bind-64 | before | 0.013463 | 0.000584 |
| interval-bind-64 | after | 0.013706 | 0.000153 |
| interval-bind-256 | before | 0.014200 | 0.001439 |
| interval-bind-256 | after | 0.014415 | 0.000247 |
| interval-add-64 | before | 0.013883 | 0.002714 |
| interval-add-64 | after | 0.013918 | 0.000260 |
| interval-add-256 | before | 0.015310 | 0.001055 |
| interval-add-256 | after | 0.015502 | 0.000053 |
| interval-flow-64 | before | 0.014262 | 0.001543 |
| interval-flow-64 | after | 0.014575 | 0.000096 |
| interval-flow-256 | before | 0.017383 | 0.000545 |
| interval-flow-256 | after | 0.017741 | 0.000587 |
| interval-range-0 | before | 0.018837 | 0.000517 |
| interval-range-0 | after | 0.019415 | 0.000919 |
| interval-range-64 | before | 0.023296 | 0.000387 |
| interval-range-64 | after | 0.024209 | 0.000947 |
| interval-range-256 | before | 0.036232 | 0.001313 |
| interval-range-256 | after | 0.037361 | 0.000509 |
| interval-http-0 | before | 0.019220 | 0.002458 |
| interval-http-0 | after | 0.019802 | 0.001921 |
| interval-http-64 | before | 0.022330 | 0.000240 |
| interval-http-64 | after | 0.023370 | 0.001334 |
| interval-http-256 | before | 0.029979 | 0.000231 |
| interval-http-256 | after | 0.031119 | 0.000345 |
| interval-width-Integer8-64 | before | 0.014659 | 0.000932 |
| interval-width-Integer8-64 | after | 0.014581 | 0.000481 |
| interval-width-Integer8-256 | before | 0.017260 | 0.000534 |
| interval-width-Integer8-256 | after | 0.017465 | 0.000216 |
| interval-width-Integer16-64 | before | 0.014053 | 0.000978 |
| interval-width-Integer16-64 | after | 0.014066 | 0.000096 |
| interval-width-Integer16-256 | before | 0.016959 | 0.001193 |
| interval-width-Integer16-256 | after | 0.017317 | 0.000386 |
| interval-width-Integer32-64 | before | 0.013883 | 0.001229 |
| interval-width-Integer32-64 | after | 0.014339 | 0.000173 |
| interval-width-Integer32-256 | before | 0.016956 | 0.000450 |
| interval-width-Integer32-256 | after | 0.017077 | 0.000377 |
| interval-width-Integer64-64 | before | 0.014035 | 0.001428 |
| interval-width-Integer64-64 | after | 0.014719 | 0.000437 |
| interval-width-Integer64-256 | before | 0.016652 | 0.000760 |
| interval-width-Integer64-256 | after | 0.017131 | 0.000252 |
| interval-width-UnsignedInteger16-64 | before | 0.014027 | 0.001166 |
| interval-width-UnsignedInteger16-64 | after | 0.014293 | 0.000437 |
| interval-width-UnsignedInteger16-256 | before | 0.016676 | 0.000799 |
| interval-width-UnsignedInteger16-256 | after | 0.017053 | 0.000607 |
| interval-width-UnsignedInteger32-64 | before | 0.014156 | 0.001783 |
| interval-width-UnsignedInteger32-64 | after | 0.014392 | 0.000246 |
| interval-width-UnsignedInteger32-256 | before | 0.016700 | 0.000852 |
| interval-width-UnsignedInteger32-256 | after | 0.017265 | 0.000301 |
| interval-width-UnsignedInteger64-64 | before | 0.013881 | 0.001403 |
| interval-width-UnsignedInteger64-64 | after | 0.014096 | 0.000117 |
| interval-width-UnsignedInteger64-256 | before | 0.016918 | 0.000476 |
| interval-width-UnsignedInteger64-256 | after | 0.017172 | 0.000250 |
| property-seven-24-20-1000-all-ok | before | 0.036977 | 0.002265 |
| property-seven-24-20-1000-all-ok | after | 0.038167 | 0.000641 |
| property-seven-24-20-1000-always-error | before | 0.035448 | 0.001018 |
| property-seven-24-20-1000-always-error | after | 0.036671 | 0.000180 |
| property-distinct-24-20-1000-all-ok | before | 0.036814 | 0.000982 |
| property-distinct-24-20-1000-all-ok | after | 0.037749 | 0.000865 |
| property-distinct-24-20-1000-always-error | before | 0.035830 | 0.001172 |
| property-distinct-24-20-1000-always-error | after | 0.036702 | 0.000258 |
| property-zero-24-20-1000-all-ok | before | 0.036985 | 0.001447 |
| property-zero-24-20-1000-all-ok | after | 0.038321 | 0.000688 |
| property-zero-24-20-1000-always-error | before | 0.035530 | 0.001432 |
| property-zero-24-20-1000-always-error | after | 0.036783 | 0.000409 |
| property-max-24-20-1000-all-ok | before | 0.037228 | 0.001430 |
| property-max-24-20-1000-all-ok | after | 0.038405 | 0.000239 |
| property-max-24-20-1000-always-error | before | 0.035599 | 0.001971 |
| property-max-24-20-1000-always-error | after | 0.036526 | 0.000358 |
| order-string-candidates | before | 0.035725 | 0.001779 |
| order-string-candidates | after | 0.036551 | 0.000387 |
| order-string-all-ok | before | 0.036866 | 0.001850 |
| order-string-all-ok | after | 0.037701 | 0.001272 |
| order-string-always-error | before | 0.035538 | 0.002375 |
| order-string-always-error | after | 0.036772 | 0.000696 |
| order-map-candidates | before | 0.036505 | 0.001816 |
| order-map-candidates | after | 0.037956 | 0.000981 |
| order-map-all-ok | before | 0.037024 | 0.001985 |
| order-map-all-ok | after | 0.037994 | 0.001007 |
| order-map-always-error | before | 0.036592 | 0.001764 |
| order-map-always-error | after | 0.037731 | 0.000811 |
| order-record-candidates | before | 0.037650 | 0.001658 |
| order-record-candidates | after | 0.037982 | 0.000523 |
| order-record-all-ok | before | 0.037057 | 0.002199 |
| order-record-all-ok | after | 0.037773 | 0.000831 |
| order-record-always-error | before | 0.037078 | 0.001848 |
| order-record-always-error | after | 0.038321 | 0.000665 |
| build-string-builder-8-0 | before | 0.016391 | 0.000580 |
| build-string-builder-8-0 | after | 0.016755 | 0.000626 |
| build-string-builder-all-8-0 | before | 0.016520 | 0.000745 |
| build-string-builder-all-8-0 | after | 0.016494 | 0.000456 |
| build-string-concatenate-8-0 | before | 0.015981 | 0.000081 |
| build-string-concatenate-8-0 | after | 0.016596 | 0.000578 |
| build-string-join-8-0 | before | 0.015990 | 0.000427 |
| build-string-join-8-0 | after | 0.016364 | 0.000226 |
| build-list-builder-8-0 | before | 0.016093 | 0.000520 |
| build-list-builder-8-0 | after | 0.016423 | 0.000227 |
| build-list-builder-all-8-0 | before | 0.016175 | 0.000561 |
| build-list-builder-all-8-0 | after | 0.016322 | 0.000357 |
| build-list-concatenate-8-0 | before | 0.016165 | 0.000391 |
| build-list-concatenate-8-0 | after | 0.016663 | 0.000350 |
| build-list-fold-8-0 | before | 0.016471 | 0.000329 |
| build-list-fold-8-0 | after | 0.016528 | 0.000163 |
| build-bytes-builder-8-0 | before | 0.016425 | 0.000497 |
| build-bytes-builder-8-0 | after | 0.016711 | 0.000164 |
| build-bytes-builder-all-8-0 | before | 0.016490 | 0.000352 |
| build-bytes-builder-all-8-0 | after | 0.016676 | 0.000403 |
| build-bytes-concatenate-8-0 | before | 0.016252 | 0.000681 |
| build-bytes-concatenate-8-0 | after | 0.016699 | 0.000353 |
| patterns-integer-100 | before | 0.014550 | 0.001262 |
| patterns-integer-100 | after | 0.014707 | 0.000411 |
| codegen-let-100 | before | 0.016803 | 0.000437 |
| codegen-let-100 | after | 0.017336 | 0.000455 |
| bridge-shared-8 | before | 0.004571 | 0.000353 |
| external-tests-normal-1 | before | 0.018537 | 0.000503 |
| external-tests-normal-1 | after | 0.018796 | 0.002195 |
| runtime-fib-short | before | 0.018599 | 0.000657 |
| runtime-fib-short | after | 0.018810 | 0.001386 |
| runtime-loop-short | before | 0.023847 | 0.000377 |
| runtime-loop-short | after | 0.024455 | 0.001209 |
| runtime-list-short | before | 0.029546 | 0.000083 |
| runtime-list-short | after | 0.030043 | 0.000758 |
| runtime-tree-short | before | 0.018779 | 0.000392 |
| runtime-tree-short | after | 0.019131 | 0.002714 |
| runtime-eval-short | before | 0.022658 | 0.000891 |
| runtime-eval-short | after | 0.022764 | 0.000928 |
| runtime-string-short | before | 0.017276 | 0.000361 |
| runtime-string-short | after | 0.017659 | 0.002202 |
| runtime-println-short | before | 0.017142 | 0.000747 |
| runtime-println-short | after | 0.017388 | 0.000529 |
| runtime-lines-short | before | 0.017025 | 0.000349 |
| runtime-lines-short | after | 0.017496 | 0.001401 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.9292e-05 | 2.042e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.375e-06 | 2.5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.2667e-05 | 2.292e-06 |
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
    "after": "606a77db939936f46e6576fe592e5daa8ada0373"
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
    "after": "public API helper build failed (1); see <repo>/target/bench/builds/606a77db939936f46e6576fe592e5daa8ada0373-default/build.log"
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
| functions-main-1000-0 | 判定不能 | None | 0.0020354583000013805 |
| functions-main-1000-1 | 判定不能 | None | 0.002056191699999488 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.002662395899999126 |
| functions-args-1000-1 | 判定不能 | None | 0.0026593750000003524 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021824209000001816 |
| functions-modules-1000-1 | 判定不能 | None | 0.002096258399998874 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002860749999999257 |
| higher-1-300 | 判定不能 | None | 0.0031219540999998688 |
| classes-300 | 判定不能 | None | 0.003690500000000441 |
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
| interval-range-64 | 判定不能 | None | 0.0023296125000001667 |
| interval-range-256 | 判定不能 | None | 0.0036231791999995267 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.0022329916000003894 |
| interval-http-256 | 達成 | 0.0011401660000132097 | 0.0029979041999993686 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0036977333999999476 |
| property-seven-24-20-1000-always-error | 達成 | 0.0012227499999966085 | 0.0035448250000001736 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0036813791000000155 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0035830333000006933 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003698475000000201 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003553045799999666 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003722774999999956 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0035598958000008455 |
| order-string-candidates | 判定不能 | None | 0.0035725374999998395 |
| order-string-all-ok | 判定不能 | None | 0.0036865917000000084 |
| order-string-always-error | 判定不能 | None | 0.0035537750000003143 |
| order-map-candidates | 判定不能 | None | 0.0036504833999998713 |
| order-map-all-ok | 判定不能 | None | 0.0037024415999994177 |
| order-map-always-error | 判定不能 | None | 0.0036592167000009113 |
| order-record-candidates | 判定不能 | None | 0.003764987499999961 |
| order-record-all-ok | 判定不能 | None | 0.0037056917000001023 |
| order-record-always-error | 判定不能 | None | 0.0037077874999994266 |
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
| runtime-loop-short | 判定不能 | None | 0.002384662499999024 |
| runtime-list-short | 判定不能 | None | 0.0029546124999995983 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022657667000004268 |
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
    "verify": 0.9601956669999936,
    "cli": 5.270154582999993,
    "warmup": 0.587795752999952,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.1636982919999923,
    "cli": 11.962687956999957,
    "warmup": 1.373192495000012,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2840465410000093,
    "cli": 9.147133042000007,
    "warmup": 1.263058043000001,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3826548330000037,
    "cli": 3.6144497100000024,
    "warmup": 0.36349316400001896,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.0828755829999892,
    "cli": 0.28305408399999976,
    "warmup": 0.030182416000002377,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03686012500000402,
    "cli": 0.3335888329999932,
    "warmup": 0.034184750000008535,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.005746166999998081,
    "cli": 0.09939175000000944,
    "warmup": 0.004727416999998013,
    "probe_warmup": 0.004197415999996679,
    "rss": 0,
    "stages": 0.026474667000002228,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04369541599999138,
    "cli": 0.3542128329999912,
    "warmup": 0.03742141700000445,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18829245900001013
  },
  "runtime": {
    "verify": 0.3416521660000029,
    "cli": 2.992189249000006,
    "warmup": 0.33226583399999754,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
