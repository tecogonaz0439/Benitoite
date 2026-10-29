# 版どうしの性能比較

候補: `41b4bda37b3cf2a8c3f6a3ef7232955e41d90431`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013268 | 0.000704 |
| functions-main-0-0 | after | 0.013950 | 0.001459 |
| functions-main-0-1 | before | 0.014096 | 0.001335 |
| functions-main-0-1 | after | 0.014282 | 0.000587 |
| functions-main-64-0 | before | 0.013714 | 0.000478 |
| functions-main-64-0 | after | 0.013698 | 0.000098 |
| functions-main-256-0 | before | 0.014762 | 0.001883 |
| functions-main-256-0 | after | 0.014948 | 0.000080 |
| functions-main-1000-0 | before | 0.020218 | 0.000592 |
| functions-main-1000-0 | after | 0.021169 | 0.001254 |
| functions-main-1000-1 | before | 0.020265 | 0.000540 |
| functions-main-1000-1 | after | 0.020777 | 0.001518 |
| functions-args-0-0 | before | 0.013085 | 0.000525 |
| functions-args-0-0 | after | 0.013190 | 0.000194 |
| functions-args-0-1 | before | 0.013473 | 0.001291 |
| functions-args-0-1 | after | 0.013956 | 0.000706 |
| functions-args-1000-0 | before | 0.026354 | 0.000201 |
| functions-args-1000-0 | after | 0.027343 | 0.000431 |
| functions-args-1000-1 | before | 0.026399 | 0.000573 |
| functions-args-1000-1 | after | 0.027400 | 0.001702 |
| functions-modules-0-0 | before | 0.013624 | 0.000707 |
| functions-modules-0-0 | after | 0.013186 | 0.000181 |
| functions-modules-0-1 | before | 0.013152 | 0.000466 |
| functions-modules-0-1 | after | 0.013244 | 0.000161 |
| functions-modules-1000-0 | before | 0.021155 | 0.001132 |
| functions-modules-1000-0 | after | 0.021354 | 0.001185 |
| functions-modules-1000-1 | before | 0.021850 | 0.000731 |
| functions-modules-1000-1 | after | 0.023256 | 0.001228 |
| existing-fib | before | 0.014487 | 0.000817 |
| existing-fib | after | 0.014029 | 0.001469 |
| existing-loop | before | 0.013794 | 0.001495 |
| existing-loop | after | 0.013849 | 0.000150 |
| existing-string | before | 0.013783 | 0.000944 |
| existing-string | after | 0.013773 | 0.000143 |
| higher-0-0 | before | 0.013136 | 0.001736 |
| higher-0-0 | after | 0.013160 | 0.000487 |
| higher-1-0 | before | 0.014042 | 0.001239 |
| higher-1-0 | after | 0.014563 | 0.000282 |
| classes-0 | before | 0.017739 | 0.000422 |
| classes-0 | after | 0.017947 | 0.001039 |
| higher-0-300 | before | 0.028080 | 0.000078 |
| higher-0-300 | after | 0.029671 | 0.001096 |
| higher-1-300 | before | 0.031668 | 0.000501 |
| higher-1-300 | after | 0.032492 | 0.001154 |
| classes-300 | before | 0.038886 | 0.000874 |
| classes-300 | after | 0.039366 | 0.000649 |
| depth-0-8 | before | 0.015540 | 0.001265 |
| depth-0-8 | after | 0.015400 | 0.000874 |
| depth-1-8 | before | 0.015455 | 0.000802 |
| depth-1-8 | after | 0.015490 | 0.000413 |
| f1-nofail-call | before | 0.014553 | 0.000583 |
| f1-nofail-call | after | 0.014416 | 0.000258 |
| f1-join-effects | before | 0.014308 | 0.001206 |
| f1-join-effects | after | 0.014419 | 0.000268 |
| control-16.3 | before | 0.013398 | 0.002005 |
| control-16.3 | after | 0.013512 | 0.000624 |
| interval-bind-64 | before | 0.013290 | 0.000676 |
| interval-bind-64 | after | 0.013436 | 0.000146 |
| interval-bind-256 | before | 0.013717 | 0.000903 |
| interval-bind-256 | after | 0.013799 | 0.000141 |
| interval-add-64 | before | 0.013359 | 0.000617 |
| interval-add-64 | after | 0.013626 | 0.000417 |
| interval-add-256 | before | 0.014951 | 0.001350 |
| interval-add-256 | after | 0.015188 | 0.000334 |
| interval-flow-64 | before | 0.014160 | 0.001296 |
| interval-flow-64 | after | 0.014327 | 0.000047 |
| interval-flow-256 | before | 0.017544 | 0.000830 |
| interval-flow-256 | after | 0.017843 | 0.000522 |
| interval-range-0 | before | 0.018788 | 0.000484 |
| interval-range-0 | after | 0.019191 | 0.000794 |
| interval-range-64 | before | 0.023439 | 0.001335 |
| interval-range-64 | after | 0.024144 | 0.001134 |
| interval-range-256 | before | 0.038590 | 0.003033 |
| interval-range-256 | after | 0.037870 | 0.001329 |
| interval-http-0 | before | 0.018885 | 0.000588 |
| interval-http-0 | after | 0.019268 | 0.001733 |
| interval-http-64 | before | 0.021965 | 0.000889 |
| interval-http-64 | after | 0.022868 | 0.001728 |
| interval-http-256 | before | 0.030638 | 0.001625 |
| interval-http-256 | after | 0.031209 | 0.001561 |
| interval-width-Integer8-64 | before | 0.014608 | 0.000857 |
| interval-width-Integer8-64 | after | 0.014316 | 0.000144 |
| interval-width-Integer8-256 | before | 0.018285 | 0.000847 |
| interval-width-Integer8-256 | after | 0.018260 | 0.001195 |
| interval-width-Integer16-64 | before | 0.015188 | 0.001226 |
| interval-width-Integer16-64 | after | 0.015643 | 0.000791 |
| interval-width-Integer16-256 | before | 0.017553 | 0.000964 |
| interval-width-Integer16-256 | after | 0.018391 | 0.000700 |
| interval-width-Integer32-64 | before | 0.014907 | 0.001546 |
| interval-width-Integer32-64 | after | 0.015382 | 0.000553 |
| interval-width-Integer32-256 | before | 0.016825 | 0.000671 |
| interval-width-Integer32-256 | after | 0.017171 | 0.000817 |
| interval-width-Integer64-64 | before | 0.014048 | 0.001567 |
| interval-width-Integer64-64 | after | 0.014257 | 0.000157 |
| interval-width-Integer64-256 | before | 0.016847 | 0.000719 |
| interval-width-Integer64-256 | after | 0.017030 | 0.000259 |
| interval-width-UnsignedInteger16-64 | before | 0.013843 | 0.001099 |
| interval-width-UnsignedInteger16-64 | after | 0.014175 | 0.000149 |
| interval-width-UnsignedInteger16-256 | before | 0.016981 | 0.000851 |
| interval-width-UnsignedInteger16-256 | after | 0.016940 | 0.000533 |
| interval-width-UnsignedInteger32-64 | before | 0.014121 | 0.001161 |
| interval-width-UnsignedInteger32-64 | after | 0.014348 | 0.000638 |
| interval-width-UnsignedInteger32-256 | before | 0.016724 | 0.001102 |
| interval-width-UnsignedInteger32-256 | after | 0.017198 | 0.001241 |
| interval-width-UnsignedInteger64-64 | before | 0.013765 | 0.001085 |
| interval-width-UnsignedInteger64-64 | after | 0.014172 | 0.000239 |
| interval-width-UnsignedInteger64-256 | before | 0.016515 | 0.000962 |
| interval-width-UnsignedInteger64-256 | after | 0.016951 | 0.000072 |
| property-seven-24-20-1000-all-ok | before | 0.036940 | 0.001202 |
| property-seven-24-20-1000-all-ok | after | 0.038825 | 0.000987 |
| property-seven-24-20-1000-always-error | before | 0.035745 | 0.000833 |
| property-seven-24-20-1000-always-error | after | 0.037234 | 0.000798 |
| property-distinct-24-20-1000-all-ok | before | 0.036128 | 0.001134 |
| property-distinct-24-20-1000-all-ok | after | 0.037403 | 0.000484 |
| property-distinct-24-20-1000-always-error | before | 0.036317 | 0.001759 |
| property-distinct-24-20-1000-always-error | after | 0.036940 | 0.000840 |
| property-zero-24-20-1000-all-ok | before | 0.036856 | 0.002412 |
| property-zero-24-20-1000-all-ok | after | 0.038351 | 0.001526 |
| property-zero-24-20-1000-always-error | before | 0.036150 | 0.001461 |
| property-zero-24-20-1000-always-error | after | 0.037786 | 0.001683 |
| property-max-24-20-1000-all-ok | before | 0.037969 | 0.002504 |
| property-max-24-20-1000-all-ok | after | 0.040136 | 0.001651 |
| property-max-24-20-1000-always-error | before | 0.037326 | 0.001553 |
| property-max-24-20-1000-always-error | after | 0.036963 | 0.000964 |
| order-string-candidates | before | 0.035403 | 0.002797 |
| order-string-candidates | after | 0.037688 | 0.001818 |
| order-string-all-ok | before | 0.036146 | 0.001536 |
| order-string-all-ok | after | 0.037072 | 0.000284 |
| order-string-always-error | before | 0.035432 | 0.001006 |
| order-string-always-error | after | 0.036630 | 0.000394 |
| order-map-candidates | before | 0.035607 | 0.001197 |
| order-map-candidates | after | 0.036507 | 0.000375 |
| order-map-all-ok | before | 0.036342 | 0.001297 |
| order-map-all-ok | after | 0.037398 | 0.000755 |
| order-map-always-error | before | 0.036533 | 0.002108 |
| order-map-always-error | after | 0.037311 | 0.000884 |
| order-record-candidates | before | 0.038669 | 0.001936 |
| order-record-candidates | after | 0.038999 | 0.001810 |
| order-record-all-ok | before | 0.039265 | 0.001459 |
| order-record-all-ok | after | 0.043193 | 0.003223 |
| order-record-always-error | before | 0.038714 | 0.002222 |
| order-record-always-error | after | 0.038996 | 0.002337 |
| build-string-builder-8-0 | before | 0.018717 | 0.001038 |
| build-string-builder-8-0 | after | 0.018460 | 0.007874 |
| build-string-builder-all-8-0 | before | 0.017966 | 0.001099 |
| build-string-builder-all-8-0 | after | 0.017860 | 0.000456 |
| build-string-concatenate-8-0 | before | 0.016906 | 0.001182 |
| build-string-concatenate-8-0 | after | 0.017314 | 0.000606 |
| build-string-join-8-0 | before | 0.016416 | 0.000637 |
| build-string-join-8-0 | after | 0.016446 | 0.001486 |
| build-list-builder-8-0 | before | 0.016578 | 0.000517 |
| build-list-builder-8-0 | after | 0.016464 | 0.001490 |
| build-list-builder-all-8-0 | before | 0.016206 | 0.000382 |
| build-list-builder-all-8-0 | after | 0.016381 | 0.000129 |
| build-list-concatenate-8-0 | before | 0.016400 | 0.000571 |
| build-list-concatenate-8-0 | after | 0.016618 | 0.000145 |
| build-list-fold-8-0 | before | 0.016636 | 0.000722 |
| build-list-fold-8-0 | after | 0.016621 | 0.000296 |
| build-bytes-builder-8-0 | before | 0.016229 | 0.000452 |
| build-bytes-builder-8-0 | after | 0.016498 | 0.000129 |
| build-bytes-builder-all-8-0 | before | 0.016788 | 0.000473 |
| build-bytes-builder-all-8-0 | after | 0.017195 | 0.000981 |
| build-bytes-concatenate-8-0 | before | 0.016518 | 0.000512 |
| build-bytes-concatenate-8-0 | after | 0.016828 | 0.000387 |
| patterns-integer-100 | before | 0.014680 | 0.001138 |
| patterns-integer-100 | after | 0.014996 | 0.000210 |
| codegen-let-100 | before | 0.017450 | 0.000578 |
| codegen-let-100 | after | 0.017349 | 0.001981 |
| bridge-shared-8 | before | 0.005109 | 0.000322 |
| bridge-shared-8 | after | 0.004829 | 0.000626 |
| external-tests-normal-1 | before | 0.018183 | 0.000506 |
| external-tests-normal-1 | after | 0.018569 | 0.001007 |
| runtime-fib-short | before | 0.018108 | 0.000494 |
| runtime-fib-short | after | 0.018591 | 0.000993 |
| runtime-loop-short | before | 0.024238 | 0.000476 |
| runtime-loop-short | after | 0.024417 | 0.002101 |
| runtime-list-short | before | 0.029888 | 0.000451 |
| runtime-list-short | after | 0.030164 | 0.000685 |
| runtime-tree-short | before | 0.018572 | 0.000423 |
| runtime-tree-short | after | 0.018812 | 0.001694 |
| runtime-eval-short | before | 0.022084 | 0.000359 |
| runtime-eval-short | after | 0.022725 | 0.001223 |
| runtime-string-short | before | 0.016945 | 0.000471 |
| runtime-string-short | after | 0.017246 | 0.000331 |
| runtime-println-short | before | 0.017556 | 0.000511 |
| runtime-println-short | after | 0.017556 | 0.000327 |
| runtime-lines-short | before | 0.016913 | 0.000635 |
| runtime-lines-short | after | 0.017774 | 0.000624 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.7917e-05 | 1.292e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3e-06 | 2.09e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1208e-05 | 1.334e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6834e-05 | 8.34e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.333e-06 | 9.17e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9959e-05 | 1.334e-06 |
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
    "before": "6124775788579e60530f55fb85570f26ef7fa900",
    "after": "41b4bda37b3cf2a8c3f6a3ef7232955e41d90431"
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
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.002021770800000411 |
| functions-main-1000-1 | 判定不能 | None | 0.002026504199999124 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.0009884170000020731 | 0.0026354083000001086 |
| functions-args-1000-1 | 判定不能 | None | 0.0026399374999996894 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021155082999996465 |
| functions-modules-1000-1 | 判定不能 | None | 0.002184970800000485 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0015915000000035207 | 0.002807995799999219 |
| higher-1-300 | 判定不能 | None | 0.0031668082999999573 |
| classes-300 | 判定不能 | None | 0.003888608299999419 |
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
| interval-range-64 | 判定不能 | None | 0.0023438791999993215 |
| interval-range-256 | 判定不能 | None | 0.00385897080000035 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.0021964749999995093 |
| interval-http-256 | 判定不能 | None | 0.0030638167000006434 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003694016699999736 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.00357454169999869 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003612833299999352 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003631737499999588 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.00368555830000048 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0036150207999995133 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037968917000000602 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003732574999999372 |
| order-string-candidates | 判定不能 | None | 0.0035402500000003556 |
| order-string-all-ok | 判定不能 | None | 0.0036146041999998604 |
| order-string-always-error | 判定不能 | None | 0.0035432499999998868 |
| order-map-candidates | 判定不能 | None | 0.00356067909999922 |
| order-map-all-ok | 判定不能 | None | 0.0036341624999991495 |
| order-map-always-error | 判定不能 | None | 0.0036532790999999065 |
| order-record-candidates | 判定不能 | None | 0.0038668542000010577 |
| order-record-all-ok | 判定不能 | None | 0.00392652499999997 |
| order-record-always-error | 判定不能 | None | 0.0038713833000002754 |
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
| runtime-loop-short | 判定不能 | None | 0.0024238250000010453 |
| runtime-list-short | 判定不能 | None | 0.0029887999999999694 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002208383299999639 |
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
    "verify": 2.128918249999998,
    "cli": 5.268451749000022,
    "warmup": 0.5901055390000209,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.8868177909999986,
    "cli": 11.990983252999968,
    "warmup": 1.3775351650000403,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2595910830000037,
    "cli": 9.256178750000004,
    "warmup": 1.2843762540000085,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3674510839999954,
    "cli": 3.7396114160000025,
    "warmup": 0.37278958300002785,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10211325000000215,
    "cli": 0.2856615419999997,
    "warmup": 0.030052292000007697,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.042677917000006005,
    "cli": 0.3404503329999926,
    "warmup": 0.034875042000010126,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010981749999999124,
    "cli": 0.20976529200000016,
    "warmup": 0.009186583000001747,
    "probe_warmup": 0.00816199999999867,
    "rss": 0,
    "stages": 0.04018579200001682,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04554491700000085,
    "cli": 0.3517415000000028,
    "warmup": 0.036317874999994615,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.19095545900000843
  },
  "runtime": {
    "verify": 0.3513820839999937,
    "cli": 2.9759883330000036,
    "warmup": 0.3331400419999824,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
