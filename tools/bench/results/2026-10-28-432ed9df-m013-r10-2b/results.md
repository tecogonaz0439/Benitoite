# 版どうしの性能比較

候補: `432ed9df61ea101b3395fbae835e9a83af19039d`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.014056 | 0.000268 |
| functions-main-0-0 | after | 0.014359 | 0.000532 |
| functions-main-0-1 | before | 0.013857 | 0.001416 |
| functions-main-0-1 | after | 0.013753 | 0.000329 |
| functions-main-64-0 | before | 0.013749 | 0.001370 |
| functions-main-64-0 | after | 0.013879 | 0.000352 |
| functions-main-256-0 | before | 0.015796 | 0.000814 |
| functions-main-256-0 | after | 0.015636 | 0.001104 |
| functions-main-1000-0 | before | 0.020867 | 0.000676 |
| functions-main-1000-0 | after | 0.021566 | 0.002041 |
| functions-main-1000-1 | before | 0.020506 | 0.000526 |
| functions-main-1000-1 | after | 0.020737 | 0.001863 |
| functions-args-0-0 | before | 0.013146 | 0.000677 |
| functions-args-0-0 | after | 0.013356 | 0.000179 |
| functions-args-0-1 | before | 0.013507 | 0.000820 |
| functions-args-0-1 | after | 0.013281 | 0.000168 |
| functions-args-1000-0 | before | 0.027280 | 0.000399 |
| functions-args-1000-0 | after | 0.027601 | 0.001557 |
| functions-args-1000-1 | before | 0.026697 | 0.000366 |
| functions-args-1000-1 | after | 0.027402 | 0.001493 |
| functions-modules-0-0 | before | 0.013765 | 0.000655 |
| functions-modules-0-0 | after | 0.013512 | 0.000212 |
| functions-modules-0-1 | before | 0.013308 | 0.000984 |
| functions-modules-0-1 | after | 0.013295 | 0.000177 |
| functions-modules-1000-0 | before | 0.020858 | 0.000661 |
| functions-modules-1000-0 | after | 0.020989 | 0.001965 |
| functions-modules-1000-1 | before | 0.020922 | 0.000344 |
| functions-modules-1000-1 | after | 0.021210 | 0.001061 |
| existing-fib | before | 0.013889 | 0.001006 |
| existing-fib | after | 0.014052 | 0.000226 |
| existing-loop | before | 0.013756 | 0.001591 |
| existing-loop | after | 0.013671 | 0.000384 |
| existing-string | before | 0.013987 | 0.000567 |
| existing-string | after | 0.013904 | 0.000110 |
| higher-0-0 | before | 0.013176 | 0.000599 |
| higher-0-0 | after | 0.013625 | 0.000291 |
| higher-1-0 | before | 0.014216 | 0.001335 |
| higher-1-0 | after | 0.014417 | 0.000762 |
| classes-0 | before | 0.017945 | 0.000912 |
| classes-0 | after | 0.019174 | 0.000637 |
| higher-0-300 | before | 0.028209 | 0.000587 |
| higher-0-300 | after | 0.029225 | 0.001077 |
| higher-1-300 | before | 0.031016 | 0.000391 |
| higher-1-300 | after | 0.031705 | 0.000902 |
| classes-300 | before | 0.037025 | 0.001210 |
| classes-300 | after | 0.038558 | 0.000388 |
| depth-0-8 | before | 0.014527 | 0.001257 |
| depth-0-8 | after | 0.014568 | 0.000339 |
| depth-1-8 | before | 0.014735 | 0.000954 |
| depth-1-8 | after | 0.014990 | 0.000257 |
| f1-nofail-call | before | 0.014054 | 0.000658 |
| f1-nofail-call | after | 0.014283 | 0.000125 |
| f1-join-effects | before | 0.014059 | 0.001221 |
| f1-join-effects | after | 0.013976 | 0.000212 |
| control-16.3 | before | 0.013110 | 0.000322 |
| control-16.3 | after | 0.013280 | 0.000276 |
| interval-bind-64 | before | 0.013264 | 0.001214 |
| interval-bind-64 | after | 0.013268 | 0.000208 |
| interval-bind-256 | before | 0.013853 | 0.000862 |
| interval-bind-256 | after | 0.013963 | 0.000371 |
| interval-add-64 | before | 0.013164 | 0.001202 |
| interval-add-64 | after | 0.013264 | 0.000207 |
| interval-add-256 | before | 0.015222 | 0.001420 |
| interval-add-256 | after | 0.015357 | 0.000263 |
| interval-flow-64 | before | 0.014378 | 0.000968 |
| interval-flow-64 | after | 0.014308 | 0.000497 |
| interval-flow-256 | before | 0.017470 | 0.000934 |
| interval-flow-256 | after | 0.017525 | 0.000571 |
| interval-range-0 | before | 0.018835 | 0.000546 |
| interval-range-0 | after | 0.018648 | 0.000994 |
| interval-range-64 | before | 0.022979 | 0.000475 |
| interval-range-64 | after | 0.023675 | 0.001422 |
| interval-range-256 | before | 0.035901 | 0.001213 |
| interval-range-256 | after | 0.036933 | 0.000564 |
| interval-http-0 | before | 0.018950 | 0.000623 |
| interval-http-0 | after | 0.019376 | 0.001276 |
| interval-http-64 | before | 0.022059 | 0.000256 |
| interval-http-64 | after | 0.022859 | 0.002907 |
| interval-http-256 | before | 0.030108 | 0.001159 |
| interval-http-256 | after | 0.031372 | 0.000636 |
| interval-width-Integer8-64 | before | 0.014440 | 0.000875 |
| interval-width-Integer8-64 | after | 0.014121 | 0.000055 |
| interval-width-Integer8-256 | before | 0.016873 | 0.000603 |
| interval-width-Integer8-256 | after | 0.016958 | 0.000171 |
| interval-width-Integer16-64 | before | 0.016206 | 0.001882 |
| interval-width-Integer16-64 | after | 0.015286 | 0.001291 |
| interval-width-Integer16-256 | before | 0.017450 | 0.000828 |
| interval-width-Integer16-256 | after | 0.017462 | 0.000583 |
| interval-width-Integer32-64 | before | 0.014702 | 0.001061 |
| interval-width-Integer32-64 | after | 0.014502 | 0.000281 |
| interval-width-Integer32-256 | before | 0.018403 | 0.001425 |
| interval-width-Integer32-256 | after | 0.018018 | 0.002871 |
| interval-width-Integer64-64 | before | 0.014979 | 0.001363 |
| interval-width-Integer64-64 | after | 0.014685 | 0.000282 |
| interval-width-Integer64-256 | before | 0.018161 | 0.000824 |
| interval-width-Integer64-256 | after | 0.018049 | 0.002086 |
| interval-width-UnsignedInteger16-64 | before | 0.014680 | 0.000865 |
| interval-width-UnsignedInteger16-64 | after | 0.014621 | 0.000641 |
| interval-width-UnsignedInteger16-256 | before | 0.017886 | 0.000797 |
| interval-width-UnsignedInteger16-256 | after | 0.018200 | 0.000859 |
| interval-width-UnsignedInteger32-64 | before | 0.014009 | 0.001124 |
| interval-width-UnsignedInteger32-64 | after | 0.014140 | 0.000267 |
| interval-width-UnsignedInteger32-256 | before | 0.017274 | 0.000376 |
| interval-width-UnsignedInteger32-256 | after | 0.017072 | 0.000511 |
| interval-width-UnsignedInteger64-64 | before | 0.014610 | 0.001289 |
| interval-width-UnsignedInteger64-64 | after | 0.014561 | 0.000244 |
| interval-width-UnsignedInteger64-256 | before | 0.017214 | 0.000435 |
| interval-width-UnsignedInteger64-256 | after | 0.017558 | 0.001288 |
| property-seven-24-20-1000-all-ok | before | 0.037672 | 0.003492 |
| property-seven-24-20-1000-all-ok | after | 0.038510 | 0.000540 |
| property-seven-24-20-1000-always-error | before | 0.036469 | 0.001411 |
| property-seven-24-20-1000-always-error | after | 0.037343 | 0.000772 |
| property-distinct-24-20-1000-all-ok | before | 0.037472 | 0.001401 |
| property-distinct-24-20-1000-all-ok | after | 0.037147 | 0.000600 |
| property-distinct-24-20-1000-always-error | before | 0.036065 | 0.001821 |
| property-distinct-24-20-1000-always-error | after | 0.036535 | 0.001594 |
| property-zero-24-20-1000-all-ok | before | 0.038834 | 0.002699 |
| property-zero-24-20-1000-all-ok | after | 0.039464 | 0.001131 |
| property-zero-24-20-1000-always-error | before | 0.036155 | 0.001009 |
| property-zero-24-20-1000-always-error | after | 0.036825 | 0.000486 |
| property-max-24-20-1000-all-ok | before | 0.038831 | 0.001098 |
| property-max-24-20-1000-all-ok | after | 0.038618 | 0.000953 |
| property-max-24-20-1000-always-error | before | 0.036009 | 0.001092 |
| property-max-24-20-1000-always-error | after | 0.036960 | 0.000529 |
| order-string-candidates | before | 0.035786 | 0.002071 |
| order-string-candidates | after | 0.036038 | 0.000334 |
| order-string-all-ok | before | 0.036085 | 0.001538 |
| order-string-all-ok | after | 0.036821 | 0.000336 |
| order-string-always-error | before | 0.034949 | 0.001236 |
| order-string-always-error | after | 0.036449 | 0.000507 |
| order-map-candidates | before | 0.035581 | 0.001323 |
| order-map-candidates | after | 0.036451 | 0.000398 |
| order-map-all-ok | before | 0.036027 | 0.001350 |
| order-map-all-ok | after | 0.036534 | 0.000546 |
| order-map-always-error | before | 0.036821 | 0.002137 |
| order-map-always-error | after | 0.037465 | 0.001238 |
| order-record-candidates | before | 0.036496 | 0.003208 |
| order-record-candidates | after | 0.037404 | 0.000198 |
| order-record-all-ok | before | 0.036900 | 0.001818 |
| order-record-all-ok | after | 0.037728 | 0.000496 |
| order-record-always-error | before | 0.036873 | 0.002788 |
| order-record-always-error | after | 0.037758 | 0.000254 |
| build-string-builder-8-0 | before | 0.016100 | 0.000728 |
| build-string-builder-8-0 | after | 0.016229 | 0.000282 |
| build-string-builder-all-8-0 | before | 0.016132 | 0.000741 |
| build-string-builder-all-8-0 | after | 0.016556 | 0.000510 |
| build-string-concatenate-8-0 | before | 0.016207 | 0.001083 |
| build-string-concatenate-8-0 | after | 0.016487 | 0.000492 |
| build-string-join-8-0 | before | 0.016091 | 0.000646 |
| build-string-join-8-0 | after | 0.015931 | 0.000243 |
| build-list-builder-8-0 | before | 0.016876 | 0.000342 |
| build-list-builder-8-0 | after | 0.017607 | 0.000741 |
| build-list-builder-all-8-0 | before | 0.016493 | 0.000405 |
| build-list-builder-all-8-0 | after | 0.016339 | 0.000327 |
| build-list-concatenate-8-0 | before | 0.016302 | 0.000465 |
| build-list-concatenate-8-0 | after | 0.016621 | 0.000297 |
| build-list-fold-8-0 | before | 0.016728 | 0.000513 |
| build-list-fold-8-0 | after | 0.016678 | 0.000292 |
| build-bytes-builder-8-0 | before | 0.016133 | 0.000392 |
| build-bytes-builder-8-0 | after | 0.016271 | 0.000386 |
| build-bytes-builder-all-8-0 | before | 0.016732 | 0.000338 |
| build-bytes-builder-all-8-0 | after | 0.016646 | 0.000179 |
| build-bytes-concatenate-8-0 | before | 0.016591 | 0.000579 |
| build-bytes-concatenate-8-0 | after | 0.016527 | 0.001385 |
| patterns-integer-100 | before | 0.016655 | 0.000427 |
| patterns-integer-100 | after | 0.016800 | 0.000535 |
| codegen-let-100 | before | 0.018769 | 0.000914 |
| codegen-let-100 | after | 0.019040 | 0.002585 |
| bridge-shared-8 | before | 0.005662 | 0.001149 |
| external-tests-normal-1 | before | 0.019247 | 0.000815 |
| external-tests-normal-1 | after | 0.019922 | 0.002583 |
| runtime-fib-short | before | 0.018639 | 0.000558 |
| runtime-fib-short | after | 0.018742 | 0.000871 |
| runtime-loop-short | before | 0.023951 | 0.000449 |
| runtime-loop-short | after | 0.024694 | 0.001279 |
| runtime-list-short | before | 0.029632 | 0.000716 |
| runtime-list-short | after | 0.030081 | 0.000764 |
| runtime-tree-short | before | 0.018687 | 0.000264 |
| runtime-tree-short | after | 0.018968 | 0.001368 |
| runtime-eval-short | before | 0.021804 | 0.000482 |
| runtime-eval-short | after | 0.022476 | 0.001731 |
| runtime-string-short | before | 0.016818 | 0.000779 |
| runtime-string-short | after | 0.016964 | 0.000116 |
| runtime-println-short | before | 0.017147 | 0.000623 |
| runtime-println-short | after | 0.017384 | 0.000364 |
| runtime-lines-short | before | 0.018069 | 0.001299 |
| runtime-lines-short | after | 0.017580 | 0.002333 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 2.1834e-05 | 2.249e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.667e-06 | 8.4e-08 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.5501e-05 | 2.165e-06 |
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
    "after": "432ed9df61ea101b3395fbae835e9a83af19039d"
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
    "after": "public API helper build failed (1); see <repo>/target/bench/builds/432ed9df61ea101b3395fbae835e9a83af19039d-default/build.log"
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
| functions-main-1000-0 | 判定不能 | None | 0.002086679199999253 |
| functions-main-1000-1 | 判定不能 | None | 0.002050625000001105 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0027280250000004005 |
| functions-args-1000-1 | 判定不能 | None | 0.0026697458000001007 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0020858333000006724 |
| functions-modules-1000-1 | 判定不能 | None | 0.0020922292000008723 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028208583000008504 |
| higher-1-300 | 判定不能 | None | 0.0031016125000007835 |
| classes-300 | 判定不能 | None | 0.0037024584000008077 |
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
| interval-range-64 | 判定不能 | None | 0.002297891599999957 |
| interval-range-256 | 判定不能 | None | 0.0035900791999992523 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.0022059124999998406 |
| interval-http-256 | 判定不能 | None | 0.0030108416999993894 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0037672249999999964 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003646916700000702 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0037471791999990956 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0036065249999992946 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0038833541999991894 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003615491700000462 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003883075000000247 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003600854100000106 |
| order-string-candidates | 判定不能 | None | 0.0035786041999998023 |
| order-string-all-ok | 判定不能 | None | 0.003608450000000119 |
| order-string-always-error | 判定不能 | None | 0.003494912499999714 |
| order-map-candidates | 判定不能 | None | 0.003558108300001095 |
| order-map-all-ok | 判定不能 | None | 0.003602725000000362 |
| order-map-always-error | 判定不能 | None | 0.003682062499999006 |
| order-record-candidates | 判定不能 | None | 0.0036495750000000273 |
| order-record-all-ok | 判定不能 | None | 0.0036900083000006136 |
| order-record-always-error | 判定不能 | None | 0.003687312499999962 |
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
| runtime-loop-short | 判定不能 | None | 0.0023951250000010305 |
| runtime-list-short | 判定不能 | None | 0.0029632458999998335 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002180433300000573 |
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
    "verify": 0.9261547500000091,
    "cli": 5.277734334999991,
    "warmup": 0.5900293279999715,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.1581933750000104,
    "cli": 11.97837025100003,
    "warmup": 1.377822252000044,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2817038329999946,
    "cli": 9.150836916000031,
    "warmup": 1.2634569150000203,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.37132804099999817,
    "cli": 3.6143335829999614,
    "warmup": 0.364145668000063,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.0870503749999898,
    "cli": 0.3244556249999988,
    "warmup": 0.034075708000003146,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.041674333000003116,
    "cli": 0.3724224169999957,
    "warmup": 0.03883937400000548,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.006371292000011408,
    "cli": 0.11977495899999724,
    "warmup": 0.0053935840000036706,
    "probe_warmup": 0.007669500000005769,
    "rss": 0,
    "stages": 0.03012637500000892,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.046101958999997805,
    "cli": 0.37141216700000257,
    "warmup": 0.040285625999985086,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.20127441699997917
  },
  "runtime": {
    "verify": 0.3407295829999981,
    "cli": 2.9754468330000208,
    "warmup": 0.33136024700002054,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
