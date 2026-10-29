# 版どうしの性能比較

候補: `f4eeca48bd71fc89aa09ef68c24136e661785aa3`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.015033 | 0.001846 |
| functions-main-0-0 | after | 0.015795 | 0.001150 |
| functions-main-0-1 | before | 0.014099 | 0.002124 |
| functions-main-0-1 | after | 0.015151 | 0.001069 |
| functions-main-64-0 | before | 0.013789 | 0.000762 |
| functions-main-64-0 | after | 0.014097 | 0.000339 |
| functions-main-256-0 | before | 0.016243 | 0.000597 |
| functions-main-256-0 | after | 0.016149 | 0.000595 |
| functions-main-1000-0 | before | 0.021106 | 0.000602 |
| functions-main-1000-0 | after | 0.021526 | 0.001821 |
| functions-main-1000-1 | before | 0.021529 | 0.000959 |
| functions-main-1000-1 | after | 0.022151 | 0.000901 |
| functions-args-0-0 | before | 0.014178 | 0.001081 |
| functions-args-0-0 | after | 0.013868 | 0.000952 |
| functions-args-0-1 | before | 0.014486 | 0.002141 |
| functions-args-0-1 | after | 0.014939 | 0.000534 |
| functions-args-1000-0 | before | 0.028566 | 0.000831 |
| functions-args-1000-0 | after | 0.028079 | 0.002175 |
| functions-args-1000-1 | before | 0.030715 | 0.002290 |
| functions-args-1000-1 | after | 0.030923 | 0.002219 |
| functions-modules-0-0 | before | 0.014991 | 0.001414 |
| functions-modules-0-0 | after | 0.014896 | 0.000639 |
| functions-modules-0-1 | before | 0.014841 | 0.001647 |
| functions-modules-0-1 | after | 0.015107 | 0.000583 |
| functions-modules-1000-0 | before | 0.022361 | 0.000671 |
| functions-modules-1000-0 | after | 0.022944 | 0.002206 |
| functions-modules-1000-1 | before | 0.021969 | 0.000796 |
| functions-modules-1000-1 | after | 0.022279 | 0.002127 |
| existing-fib | before | 0.014238 | 0.001361 |
| existing-fib | after | 0.014454 | 0.000266 |
| existing-loop | before | 0.014636 | 0.000931 |
| existing-loop | after | 0.014346 | 0.000162 |
| existing-string | before | 0.014096 | 0.001031 |
| existing-string | after | 0.014292 | 0.000185 |
| higher-0-0 | before | 0.013971 | 0.000578 |
| higher-0-0 | after | 0.013801 | 0.000363 |
| higher-1-0 | before | 0.014929 | 0.000303 |
| higher-1-0 | after | 0.015033 | 0.000739 |
| classes-0 | before | 0.018041 | 0.000493 |
| classes-0 | after | 0.018524 | 0.001682 |
| higher-0-300 | before | 0.028821 | 0.000527 |
| higher-0-300 | after | 0.030317 | 0.001052 |
| higher-1-300 | before | 0.031351 | 0.000253 |
| higher-1-300 | after | 0.032337 | 0.000974 |
| classes-300 | before | 0.039482 | 0.002384 |
| classes-300 | after | 0.040729 | 0.001628 |
| depth-0-8 | before | 0.015444 | 0.001122 |
| depth-0-8 | after | 0.015925 | 0.000761 |
| depth-1-8 | before | 0.015722 | 0.001429 |
| depth-1-8 | after | 0.015758 | 0.000540 |
| f1-nofail-call | before | 0.014674 | 0.001720 |
| f1-nofail-call | after | 0.014692 | 0.000565 |
| f1-join-effects | before | 0.014548 | 0.002110 |
| f1-join-effects | after | 0.015376 | 0.000811 |
| control-16.3 | before | 0.013884 | 0.001036 |
| control-16.3 | after | 0.014090 | 0.000895 |
| interval-bind-64 | before | 0.014603 | 0.002128 |
| interval-bind-64 | after | 0.014723 | 0.000737 |
| interval-bind-256 | before | 0.016286 | 0.001222 |
| interval-bind-256 | after | 0.015992 | 0.002191 |
| interval-add-64 | before | 0.014128 | 0.001262 |
| interval-add-64 | after | 0.013775 | 0.000378 |
| interval-add-256 | before | 0.015411 | 0.001242 |
| interval-add-256 | after | 0.015510 | 0.001960 |
| interval-flow-64 | before | 0.014622 | 0.000711 |
| interval-flow-64 | after | 0.015120 | 0.000438 |
| interval-flow-256 | before | 0.017397 | 0.000351 |
| interval-flow-256 | after | 0.017681 | 0.000215 |
| interval-range-0 | before | 0.019103 | 0.000515 |
| interval-range-0 | after | 0.019206 | 0.001239 |
| interval-range-64 | before | 0.023063 | 0.000209 |
| interval-range-64 | after | 0.023600 | 0.001163 |
| interval-range-256 | before | 0.036004 | 0.000761 |
| interval-range-256 | after | 0.036821 | 0.002052 |
| interval-http-0 | before | 0.019007 | 0.000586 |
| interval-http-0 | after | 0.019497 | 0.001103 |
| interval-http-64 | before | 0.022324 | 0.000345 |
| interval-http-64 | after | 0.023011 | 0.001470 |
| interval-http-256 | before | 0.029573 | 0.000354 |
| interval-http-256 | after | 0.030817 | 0.000965 |
| interval-width-Integer8-64 | before | 0.014381 | 0.001140 |
| interval-width-Integer8-64 | after | 0.014326 | 0.000247 |
| interval-width-Integer8-256 | before | 0.016764 | 0.001582 |
| interval-width-Integer8-256 | after | 0.017075 | 0.000780 |
| interval-width-Integer16-64 | before | 0.014269 | 0.000775 |
| interval-width-Integer16-64 | after | 0.014072 | 0.000308 |
| interval-width-Integer16-256 | before | 0.016712 | 0.000703 |
| interval-width-Integer16-256 | after | 0.016873 | 0.000274 |
| interval-width-Integer32-64 | before | 0.014101 | 0.000952 |
| interval-width-Integer32-64 | after | 0.013989 | 0.000122 |
| interval-width-Integer32-256 | before | 0.016856 | 0.000891 |
| interval-width-Integer32-256 | after | 0.017101 | 0.000193 |
| interval-width-Integer64-64 | before | 0.014310 | 0.001117 |
| interval-width-Integer64-64 | after | 0.014237 | 0.000354 |
| interval-width-Integer64-256 | before | 0.016678 | 0.000504 |
| interval-width-Integer64-256 | after | 0.017217 | 0.000248 |
| interval-width-UnsignedInteger16-64 | before | 0.013958 | 0.001233 |
| interval-width-UnsignedInteger16-64 | after | 0.014243 | 0.000152 |
| interval-width-UnsignedInteger16-256 | before | 0.016790 | 0.000469 |
| interval-width-UnsignedInteger16-256 | after | 0.016899 | 0.000350 |
| interval-width-UnsignedInteger32-64 | before | 0.014156 | 0.000954 |
| interval-width-UnsignedInteger32-64 | after | 0.014249 | 0.000120 |
| interval-width-UnsignedInteger32-256 | before | 0.016783 | 0.000459 |
| interval-width-UnsignedInteger32-256 | after | 0.017148 | 0.000621 |
| interval-width-UnsignedInteger64-64 | before | 0.014434 | 0.000541 |
| interval-width-UnsignedInteger64-64 | after | 0.014259 | 0.000144 |
| interval-width-UnsignedInteger64-256 | before | 0.016478 | 0.000530 |
| interval-width-UnsignedInteger64-256 | after | 0.016975 | 0.000347 |
| property-seven-24-20-1000-all-ok | before | 0.036972 | 0.001727 |
| property-seven-24-20-1000-all-ok | after | 0.037762 | 0.000554 |
| property-seven-24-20-1000-always-error | before | 0.036505 | 0.001316 |
| property-seven-24-20-1000-always-error | after | 0.037591 | 0.001454 |
| property-distinct-24-20-1000-all-ok | before | 0.036361 | 0.001660 |
| property-distinct-24-20-1000-all-ok | after | 0.037241 | 0.000685 |
| property-distinct-24-20-1000-always-error | before | 0.035598 | 0.001898 |
| property-distinct-24-20-1000-always-error | after | 0.036393 | 0.000266 |
| property-zero-24-20-1000-all-ok | before | 0.036714 | 0.001276 |
| property-zero-24-20-1000-all-ok | after | 0.037439 | 0.000455 |
| property-zero-24-20-1000-always-error | before | 0.035790 | 0.002192 |
| property-zero-24-20-1000-always-error | after | 0.036870 | 0.000173 |
| property-max-24-20-1000-all-ok | before | 0.037661 | 0.001187 |
| property-max-24-20-1000-all-ok | after | 0.038293 | 0.000703 |
| property-max-24-20-1000-always-error | before | 0.035630 | 0.000960 |
| property-max-24-20-1000-always-error | after | 0.036359 | 0.000166 |
| order-string-candidates | before | 0.035518 | 0.002931 |
| order-string-candidates | after | 0.036301 | 0.000374 |
| order-string-all-ok | before | 0.035847 | 0.001876 |
| order-string-all-ok | after | 0.037115 | 0.000487 |
| order-string-always-error | before | 0.034962 | 0.000941 |
| order-string-always-error | after | 0.036022 | 0.000061 |
| order-map-candidates | before | 0.035695 | 0.001053 |
| order-map-candidates | after | 0.036824 | 0.000518 |
| order-map-all-ok | before | 0.035983 | 0.001534 |
| order-map-all-ok | after | 0.036888 | 0.000620 |
| order-map-always-error | before | 0.035923 | 0.001269 |
| order-map-always-error | after | 0.036596 | 0.000611 |
| order-record-candidates | before | 0.035889 | 0.002673 |
| order-record-candidates | after | 0.036765 | 0.000863 |
| order-record-all-ok | before | 0.036201 | 0.001515 |
| order-record-all-ok | after | 0.037346 | 0.000379 |
| order-record-always-error | before | 0.036296 | 0.000863 |
| order-record-always-error | after | 0.037041 | 0.000175 |
| build-string-builder-8-0 | before | 0.016117 | 0.000433 |
| build-string-builder-8-0 | after | 0.016375 | 0.000554 |
| build-string-builder-all-8-0 | before | 0.016345 | 0.000470 |
| build-string-builder-all-8-0 | after | 0.016720 | 0.000753 |
| build-string-concatenate-8-0 | before | 0.016462 | 0.000429 |
| build-string-concatenate-8-0 | after | 0.016548 | 0.000480 |
| build-string-join-8-0 | before | 0.016112 | 0.000438 |
| build-string-join-8-0 | after | 0.015851 | 0.000143 |
| build-list-builder-8-0 | before | 0.016213 | 0.000498 |
| build-list-builder-8-0 | after | 0.016287 | 0.000261 |
| build-list-builder-all-8-0 | before | 0.016066 | 0.000493 |
| build-list-builder-all-8-0 | after | 0.016288 | 0.000331 |
| build-list-concatenate-8-0 | before | 0.016141 | 0.000405 |
| build-list-concatenate-8-0 | after | 0.016254 | 0.000225 |
| build-list-fold-8-0 | before | 0.016628 | 0.000474 |
| build-list-fold-8-0 | after | 0.016373 | 0.000357 |
| build-bytes-builder-8-0 | before | 0.016441 | 0.000419 |
| build-bytes-builder-8-0 | after | 0.016867 | 0.000951 |
| build-bytes-builder-all-8-0 | before | 0.016850 | 0.000477 |
| build-bytes-builder-all-8-0 | after | 0.016924 | 0.000660 |
| build-bytes-concatenate-8-0 | before | 0.016835 | 0.000699 |
| build-bytes-concatenate-8-0 | after | 0.017480 | 0.001141 |
| patterns-integer-100 | before | 0.014387 | 0.001415 |
| patterns-integer-100 | after | 0.014345 | 0.000506 |
| codegen-let-100 | before | 0.016889 | 0.000409 |
| codegen-let-100 | after | 0.017111 | 0.000233 |
| bridge-shared-8 | before | 0.004588 | 0.000540 |
| external-tests-normal-1 | before | 0.018064 | 0.000661 |
| external-tests-normal-1 | after | 0.018150 | 0.001578 |
| runtime-fib-short | before | 0.018340 | 0.000432 |
| runtime-fib-short | after | 0.018286 | 0.000520 |
| runtime-loop-short | before | 0.023763 | 0.000449 |
| runtime-loop-short | after | 0.024241 | 0.000988 |
| runtime-list-short | before | 0.029275 | 0.000691 |
| runtime-list-short | after | 0.029713 | 0.001385 |
| runtime-tree-short | before | 0.018575 | 0.000601 |
| runtime-tree-short | after | 0.018833 | 0.001255 |
| runtime-eval-short | before | 0.022260 | 0.000531 |
| runtime-eval-short | after | 0.022978 | 0.000716 |
| runtime-string-short | before | 0.017124 | 0.000783 |
| runtime-string-short | after | 0.017255 | 0.000713 |
| runtime-println-short | before | 0.017372 | 0.000569 |
| runtime-println-short | after | 0.017627 | 0.001043 |
| runtime-lines-short | before | 0.017231 | 0.000205 |
| runtime-lines-short | after | 0.017465 | 0.001465 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.9958e-05 | 2.708e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.5e-06 | 7.91e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.3458e-05 | 3.499e-06 |
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
    "after": "f4eeca48bd71fc89aa09ef68c24136e661785aa3"
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
    "after": "public API helper build failed (1); see <repo>/target/bench/builds/f4eeca48bd71fc89aa09ef68c24136e661785aa3-default/build.log"
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
| functions-main-1000-0 | 判定不能 | None | 0.002110570800000744 |
| functions-main-1000-1 | 判定不能 | None | 0.002152949999999976 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.002856570899999156 |
| functions-args-1000-1 | 判定不能 | None | 0.003071537499999977 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002236137500000268 |
| functions-modules-1000-1 | 判定不能 | None | 0.0021969082999987676 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002882058400000176 |
| higher-1-300 | 判定不能 | None | 0.003135095900000806 |
| classes-300 | 判定不能 | None | 0.003948170900000036 |
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
| interval-range-64 | 判定不能 | None | 0.002306254099998739 |
| interval-range-256 | 判定不能 | None | 0.0036003832999995213 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.002232370800000183 |
| interval-http-256 | 判定不能 | None | 0.002957316700000945 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0036971582999996144 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0036505167000001394 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003636066700001095 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0035598084000000086 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0036714041999999837 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.00357898329999955 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037661165999992364 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003562999999999761 |
| order-string-candidates | 判定不能 | None | 0.0035517749999996796 |
| order-string-all-ok | 判定不能 | None | 0.003584699999998975 |
| order-string-always-error | 達成 | 0.0010600000000096088 | 0.0034961666999990372 |
| order-map-candidates | 判定不能 | None | 0.0035695207999992817 |
| order-map-all-ok | 判定不能 | None | 0.0035983332999990126 |
| order-map-always-error | 判定不能 | None | 0.0035923332999999503 |
| order-record-candidates | 判定不能 | None | 0.0035888874999997714 |
| order-record-all-ok | 判定不能 | None | 0.00362009579999949 |
| order-record-always-error | 判定不能 | None | 0.0036296458999999005 |
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
| runtime-loop-short | 判定不能 | None | 0.0023762749999988843 |
| runtime-list-short | 判定不能 | None | 0.002927537499999744 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022260291999998574 |
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
    "verify": 0.9414469580000002,
    "cli": 5.588799958000024,
    "warmup": 0.6142189129999736,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.1508919169999956,
    "cli": 12.072988416000001,
    "warmup": 1.3815151710000464,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.293140500000007,
    "cli": 9.018844209000036,
    "warmup": 1.2489724170000045,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.41176116700000875,
    "cli": 3.61787241899998,
    "warmup": 0.35955558300000234,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09053858299999717,
    "cli": 0.2789273329999986,
    "warmup": 0.029471083999993652,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04228625000000363,
    "cli": 0.3311692500000021,
    "warmup": 0.034138083000001984,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.005568042000007267,
    "cli": 0.099445082999992,
    "warmup": 0.004666583000002333,
    "probe_warmup": 0.004057415999994873,
    "rss": 0,
    "stages": 0.024049832999992304,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04624983399999394,
    "cli": 0.34354633299999193,
    "warmup": 0.03766154199998084,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18299112600000456
  },
  "runtime": {
    "verify": 0.3576676670000012,
    "cli": 2.963636998999945,
    "warmup": 0.3332425820000111,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
