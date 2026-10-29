# 版どうしの性能比較

候補: `1b0d9096cb8661b367edfffc0f3596fbcf9ca734`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013569 | 0.000196 |
| functions-main-0-0 | after | 0.014039 | 0.000325 |
| functions-main-0-1 | before | 0.013145 | 0.000281 |
| functions-main-0-1 | after | 0.013782 | 0.000193 |
| functions-main-64-0 | before | 0.013413 | 0.000163 |
| functions-main-64-0 | after | 0.013893 | 0.000173 |
| functions-main-256-0 | before | 0.015454 | 0.000649 |
| functions-main-256-0 | after | 0.016358 | 0.000562 |
| functions-main-1000-0 | before | 0.020576 | 0.000848 |
| functions-main-1000-0 | after | 0.021600 | 0.000937 |
| functions-main-1000-1 | before | 0.020743 | 0.000885 |
| functions-main-1000-1 | after | 0.021916 | 0.000763 |
| functions-args-0-0 | before | 0.013137 | 0.000114 |
| functions-args-0-0 | after | 0.013776 | 0.000272 |
| functions-args-0-1 | before | 0.013668 | 0.000733 |
| functions-args-0-1 | after | 0.014080 | 0.000455 |
| functions-args-1000-0 | before | 0.027153 | 0.000630 |
| functions-args-1000-0 | after | 0.028679 | 0.000643 |
| functions-args-1000-1 | before | 0.026739 | 0.000716 |
| functions-args-1000-1 | after | 0.028082 | 0.000529 |
| functions-modules-0-0 | before | 0.013006 | 0.000331 |
| functions-modules-0-0 | after | 0.013665 | 0.000358 |
| functions-modules-0-1 | before | 0.013220 | 0.000118 |
| functions-modules-0-1 | after | 0.013580 | 0.000425 |
| functions-modules-1000-0 | before | 0.021220 | 0.000993 |
| functions-modules-1000-0 | after | 0.022190 | 0.000151 |
| functions-modules-1000-1 | before | 0.021022 | 0.000547 |
| functions-modules-1000-1 | after | 0.021812 | 0.000316 |
| existing-fib | before | 0.014115 | 0.000657 |
| existing-fib | after | 0.014278 | 0.001167 |
| existing-loop | before | 0.013981 | 0.000358 |
| existing-loop | after | 0.014213 | 0.000359 |
| existing-string | before | 0.013878 | 0.000344 |
| existing-string | after | 0.014232 | 0.000302 |
| higher-0-0 | before | 0.013484 | 0.000811 |
| higher-0-0 | after | 0.013871 | 0.000239 |
| higher-1-0 | before | 0.014338 | 0.000863 |
| higher-1-0 | after | 0.014805 | 0.000212 |
| classes-0 | before | 0.017838 | 0.001261 |
| classes-0 | after | 0.019841 | 0.000228 |
| higher-0-300 | before | 0.028505 | 0.000769 |
| higher-0-300 | after | 0.029550 | 0.000585 |
| higher-1-300 | before | 0.031422 | 0.000654 |
| higher-1-300 | after | 0.032985 | 0.001892 |
| classes-300 | before | 0.038247 | 0.001110 |
| classes-300 | after | 0.040643 | 0.000329 |
| depth-0-8 | before | 0.014930 | 0.000248 |
| depth-0-8 | after | 0.015384 | 0.000443 |
| depth-1-8 | before | 0.014725 | 0.000207 |
| depth-1-8 | after | 0.015575 | 0.000215 |
| f1-nofail-call | before | 0.014993 | 0.000475 |
| f1-nofail-call | after | 0.014892 | 0.000116 |
| f1-join-effects | before | 0.014265 | 0.000136 |
| f1-join-effects | after | 0.014506 | 0.000265 |
| control-16.3 | before | 0.013273 | 0.000461 |
| control-16.3 | after | 0.013804 | 0.000613 |
| interval-bind-64 | before | 0.013398 | 0.000661 |
| interval-bind-64 | after | 0.013866 | 0.000254 |
| interval-bind-256 | before | 0.013862 | 0.001987 |
| interval-bind-256 | after | 0.014280 | 0.000152 |
| interval-add-64 | before | 0.013174 | 0.001016 |
| interval-add-64 | after | 0.013698 | 0.000249 |
| interval-add-256 | before | 0.014898 | 0.001187 |
| interval-add-256 | after | 0.015403 | 0.000215 |
| interval-flow-64 | before | 0.014568 | 0.000173 |
| interval-flow-64 | after | 0.014979 | 0.000723 |
| interval-flow-256 | before | 0.017532 | 0.000693 |
| interval-flow-256 | after | 0.017570 | 0.000635 |
| interval-range-0 | before | 0.018536 | 0.000460 |
| interval-range-0 | after | 0.020745 | 0.000615 |
| interval-range-64 | before | 0.022917 | 0.000245 |
| interval-range-64 | after | 0.025616 | 0.000396 |
| interval-range-256 | before | 0.036429 | 0.001059 |
| interval-range-256 | after | 0.038385 | 0.000725 |
| interval-http-0 | before | 0.018914 | 0.000135 |
| interval-http-0 | after | 0.021532 | 0.000850 |
| interval-http-64 | before | 0.022006 | 0.000289 |
| interval-http-64 | after | 0.024526 | 0.000739 |
| interval-http-256 | before | 0.029739 | 0.000114 |
| interval-http-256 | after | 0.032624 | 0.000325 |
| interval-width-Integer8-64 | before | 0.013736 | 0.000134 |
| interval-width-Integer8-64 | after | 0.014304 | 0.000171 |
| interval-width-Integer8-256 | before | 0.016549 | 0.000210 |
| interval-width-Integer8-256 | after | 0.017157 | 0.000263 |
| interval-width-Integer16-64 | before | 0.013769 | 0.000357 |
| interval-width-Integer16-64 | after | 0.014776 | 0.000398 |
| interval-width-Integer16-256 | before | 0.016609 | 0.000202 |
| interval-width-Integer16-256 | after | 0.017217 | 0.000174 |
| interval-width-Integer32-64 | before | 0.013868 | 0.000480 |
| interval-width-Integer32-64 | after | 0.014320 | 0.000279 |
| interval-width-Integer32-256 | before | 0.016702 | 0.000340 |
| interval-width-Integer32-256 | after | 0.017197 | 0.000573 |
| interval-width-Integer64-64 | before | 0.013649 | 0.000197 |
| interval-width-Integer64-64 | after | 0.014110 | 0.000728 |
| interval-width-Integer64-256 | before | 0.016862 | 0.000358 |
| interval-width-Integer64-256 | after | 0.017305 | 0.000229 |
| interval-width-UnsignedInteger16-64 | before | 0.013920 | 0.000471 |
| interval-width-UnsignedInteger16-64 | after | 0.014316 | 0.000186 |
| interval-width-UnsignedInteger16-256 | before | 0.016526 | 0.000401 |
| interval-width-UnsignedInteger16-256 | after | 0.017504 | 0.000644 |
| interval-width-UnsignedInteger32-64 | before | 0.014330 | 0.000690 |
| interval-width-UnsignedInteger32-64 | after | 0.014316 | 0.000487 |
| interval-width-UnsignedInteger32-256 | before | 0.016449 | 0.000283 |
| interval-width-UnsignedInteger32-256 | after | 0.016831 | 0.000389 |
| interval-width-UnsignedInteger64-64 | before | 0.013932 | 0.000867 |
| interval-width-UnsignedInteger64-64 | after | 0.014169 | 0.000649 |
| interval-width-UnsignedInteger64-256 | before | 0.016251 | 0.000308 |
| interval-width-UnsignedInteger64-256 | after | 0.016691 | 0.000590 |
| property-seven-24-20-1000-all-ok | before | 0.036355 | 0.000370 |
| property-seven-24-20-1000-all-ok | after | 0.040650 | 0.000383 |
| property-seven-24-20-1000-always-error | before | 0.035260 | 0.000439 |
| property-seven-24-20-1000-always-error | after | 0.038955 | 0.000178 |
| property-distinct-24-20-1000-all-ok | before | 0.035675 | 0.001361 |
| property-distinct-24-20-1000-all-ok | after | 0.039495 | 0.000284 |
| property-distinct-24-20-1000-always-error | before | 0.035297 | 0.000514 |
| property-distinct-24-20-1000-always-error | after | 0.038914 | 0.000547 |
| property-zero-24-20-1000-all-ok | before | 0.036451 | 0.000437 |
| property-zero-24-20-1000-all-ok | after | 0.040507 | 0.001675 |
| property-zero-24-20-1000-always-error | before | 0.035180 | 0.000634 |
| property-zero-24-20-1000-always-error | after | 0.039052 | 0.000267 |
| property-max-24-20-1000-all-ok | before | 0.036817 | 0.000836 |
| property-max-24-20-1000-all-ok | after | 0.040550 | 0.001094 |
| property-max-24-20-1000-always-error | before | 0.034993 | 0.000508 |
| property-max-24-20-1000-always-error | after | 0.039329 | 0.000294 |
| order-string-candidates | before | 0.034774 | 0.000794 |
| order-string-candidates | after | 0.038699 | 0.000230 |
| order-string-all-ok | before | 0.035411 | 0.000845 |
| order-string-all-ok | after | 0.039195 | 0.000432 |
| order-string-always-error | before | 0.035388 | 0.001679 |
| order-string-always-error | after | 0.038870 | 0.000853 |
| order-map-candidates | before | 0.035212 | 0.000913 |
| order-map-candidates | after | 0.039119 | 0.000470 |
| order-map-all-ok | before | 0.035446 | 0.000427 |
| order-map-all-ok | after | 0.039664 | 0.000506 |
| order-map-always-error | before | 0.035298 | 0.001425 |
| order-map-always-error | after | 0.039099 | 0.000380 |
| order-record-candidates | before | 0.036363 | 0.000706 |
| order-record-candidates | after | 0.039228 | 0.000892 |
| order-record-all-ok | before | 0.035643 | 0.000396 |
| order-record-all-ok | after | 0.039547 | 0.000290 |
| order-record-always-error | before | 0.035457 | 0.001291 |
| order-record-always-error | after | 0.039336 | 0.000751 |
| build-string-builder-8-0 | before | 0.015679 | 0.000569 |
| build-string-builder-8-0 | after | 0.016066 | 0.000469 |
| build-string-builder-all-8-0 | before | 0.015719 | 0.000319 |
| build-string-builder-all-8-0 | after | 0.016267 | 0.000260 |
| build-string-concatenate-8-0 | before | 0.015638 | 0.000401 |
| build-string-concatenate-8-0 | after | 0.016083 | 0.000372 |
| build-string-join-8-0 | before | 0.015608 | 0.000375 |
| build-string-join-8-0 | after | 0.015993 | 0.000232 |
| build-list-builder-8-0 | before | 0.016075 | 0.000263 |
| build-list-builder-8-0 | after | 0.016407 | 0.000207 |
| build-list-builder-all-8-0 | before | 0.015934 | 0.000505 |
| build-list-builder-all-8-0 | after | 0.016193 | 0.000175 |
| build-list-concatenate-8-0 | before | 0.016258 | 0.000927 |
| build-list-concatenate-8-0 | after | 0.016425 | 0.000254 |
| build-list-fold-8-0 | before | 0.015925 | 0.000675 |
| build-list-fold-8-0 | after | 0.016472 | 0.001286 |
| build-bytes-builder-8-0 | before | 0.015663 | 0.000167 |
| build-bytes-builder-8-0 | after | 0.016345 | 0.000156 |
| build-bytes-builder-all-8-0 | before | 0.015840 | 0.000266 |
| build-bytes-builder-all-8-0 | after | 0.016598 | 0.001712 |
| build-bytes-concatenate-8-0 | before | 0.016198 | 0.001194 |
| build-bytes-concatenate-8-0 | after | 0.017392 | 0.000745 |
| patterns-integer-100 | before | 0.014317 | 0.000172 |
| patterns-integer-100 | after | 0.014769 | 0.001271 |
| codegen-let-100 | before | 0.016719 | 0.000346 |
| codegen-let-100 | after | 0.017276 | 0.000612 |
| bridge-shared-8 | before | 0.004442 | 0.000423 |
| bridge-shared-8 | after | 0.004372 | 0.000278 |
| external-tests-normal-1 | before | 0.017655 | 0.000249 |
| external-tests-normal-1 | after | 0.018324 | 0.001795 |
| runtime-fib-short | before | 0.017939 | 0.000251 |
| runtime-fib-short | after | 0.018108 | 0.000261 |
| runtime-loop-short | before | 0.023401 | 0.000171 |
| runtime-loop-short | after | 0.023823 | 0.000646 |
| runtime-list-short | before | 0.028806 | 0.001049 |
| runtime-list-short | after | 0.029695 | 0.000359 |
| runtime-tree-short | before | 0.018068 | 0.000313 |
| runtime-tree-short | after | 0.018610 | 0.000192 |
| runtime-eval-short | before | 0.021876 | 0.000253 |
| runtime-eval-short | after | 0.022440 | 0.000692 |
| runtime-string-short | before | 0.016546 | 0.000794 |
| runtime-string-short | after | 0.017040 | 0.000348 |
| runtime-println-short | before | 0.016914 | 0.000310 |
| runtime-println-short | after | 0.017501 | 0.000322 |
| runtime-lines-short | before | 0.016482 | 0.000832 |
| runtime-lines-short | after | 0.018473 | 0.000067 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.9e-05 | 1.958e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.333e-06 | 3.74e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.2667e-05 | 2.291e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.3375e-05 | 9.17e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.084e-06 | 3.34e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.6459e-05 | 1.251e-06 |
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
    "after": "1b0d9096cb8661b367edfffc0f3596fbcf9ca734"
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
| functions-main-0-1 | 達成 | 0.0006360840000070311 | 0.002 |
| functions-main-64-0 | 達成 | 0.0004800829999993539 | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.002057600000000548 |
| functions-main-1000-1 | 判定不能 | None | 0.0020743082999999276 |
| functions-args-0-0 | 達成 | 0.0006389160000139782 | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.0015257920000095737 | 0.0027153082999987533 |
| functions-args-1000-1 | 達成 | 0.0013429589999987002 | 0.002673912500000597 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021219750000000203 |
| functions-modules-1000-1 | 判定不能 | None | 0.002102191699999878 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 退行の疑い | 0.002003208999994399 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028504834000003146 |
| higher-1-300 | 判定不能 | None | 0.003142237500000533 |
| classes-300 | 達成 | 0.002395749999990926 | 0.0038247167000008634 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 達成 | 0.0008495410000080028 | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 退行の疑い | 0.002208916000000727 | 0.002 |
| interval-range-64 | 退行の疑い | 0.0026989170000035756 | 0.0022916875000007055 |
| interval-range-256 | 達成 | 0.0019550420000058466 | 0.003642945800000064 |
| interval-http-0 | 退行の疑い | 0.002617416000006756 | 0.002 |
| interval-http-64 | 退行の疑い | 0.0025208339999949203 | 0.002200554099999863 |
| interval-http-256 | 達成 | 0.00288558399998351 | 0.0029738625000007347 |
| interval-width-Integer8-64 | 達成 | 0.0005676260000058164 | 0.002 |
| interval-width-Integer8-256 | 達成 | 0.000608791999994196 | 0.002 |
| interval-width-Integer16-64 | 達成 | 0.00100641699999926 | 0.002 |
| interval-width-Integer16-256 | 達成 | 0.0006081670000099848 | 0.002 |
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
| property-seven-24-20-1000-all-ok | 退行の疑い | 0.004294666000006941 | 0.0036355208999992784 |
| property-seven-24-20-1000-always-error | 退行の疑い | 0.0036953750000066066 | 0.0035260042000004434 |
| property-distinct-24-20-1000-all-ok | 退行の疑い | 0.0038207090000099697 | 0.0035674665999991364 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.003616499999992584 | 0.0035297333000002596 |
| property-zero-24-20-1000-all-ok | 退行の疑い | 0.0040564999999901374 | 0.0036450999999999567 |
| property-zero-24-20-1000-always-error | 退行の疑い | 0.003872375000000261 | 0.0035179749999997515 |
| property-max-24-20-1000-all-ok | 退行の疑い | 0.0037329590000041435 | 0.003681683299998895 |
| property-max-24-20-1000-always-error | 退行の疑い | 0.004335833000013167 | 0.0034993416999995475 |
| order-string-candidates | 退行の疑い | 0.0039246670000210315 | 0.003477445799998691 |
| order-string-all-ok | 退行の疑い | 0.0037835420000078557 | 0.003541095799999994 |
| order-string-always-error | 達成 | 0.0034817910000128904 | 0.0035387958999990587 |
| order-map-candidates | 退行の疑い | 0.003906916999994792 | 0.003521237500000041 |
| order-map-all-ok | 退行の疑い | 0.004217875999998455 | 0.003544604100000015 |
| order-map-always-error | 退行の疑い | 0.0038007500000105665 | 0.003529833300000007 |
| order-record-candidates | 達成 | 0.002865042000010476 | 0.0036363416999989798 |
| order-record-all-ok | 退行の疑い | 0.003904040999998415 | 0.003564254200000505 |
| order-record-always-error | 退行の疑い | 0.003878332999988743 | 0.0035457292000003805 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 達成 | 0.0006822089999900527 | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0023400708999986365 |
| runtime-list-short | 判定不能 | None | 0.0028805792 |
| runtime-tree-short | 達成 | 0.0005412499999977172 | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002187649999999053 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 達成 | 0.0019911239999998998 | 0.002 |
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
    "verify": 1.7212896669999935,
    "cli": 5.358145831000002,
    "warmup": 0.5939012939999486,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.966945958000011,
    "cli": 11.902702540999968,
    "warmup": 1.381296129000063,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3145181250000064,
    "cli": 9.15816916899999,
    "warmup": 1.280524168000042,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.4410020419999938,
    "cli": 3.544354373999994,
    "warmup": 0.3543586679999464,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09922420799999543,
    "cli": 0.2779336669999992,
    "warmup": 0.029526416999999583,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.035801125000006095,
    "cli": 0.33004179200000294,
    "warmup": 0.03416950099999383,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009750959000001558,
    "cli": 0.19847941599999785,
    "warmup": 0.00919454099999939,
    "probe_warmup": 0.007697249000003126,
    "rss": 0,
    "stages": 0.044676584000001185,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04239933399999529,
    "cli": 0.34001849999999934,
    "warmup": 0.035332374999995864,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1782572900000048
  },
  "runtime": {
    "verify": 0.3433640419999904,
    "cli": 2.905637749999997,
    "warmup": 0.32776654399999927,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-30）

九つの区分の出力の照合はすべて通った。V10.1a〜V10.2b の変更は、同梱の Skill の文・英語の文書・設計書・テストの入力・改造の記録だけで、検査と実行の経路は変えていない。退行の疑いの20点の族は前回（R40.3 の後）と同じである（`property-*`・`order-*` は Trait を使う点で設計者が採った費用、`interval-range-*`・`interval-http-*` は既知の族）。`classes-0` は R30.2c・R30.4・R40.1・R40.2 の後の short でも退行の疑いに入った既知の点で、幅は 2 ms の閾値とほぼ同じである。全94入力の after/before の中央値の比は 1.037（前回 1.040）。これをリリースの準備の前の最後の short とし、新しい退行の族はない。
