# 版どうしの性能比較

候補: `bf01d0caa366be726b572aef2f01c0519891cbca`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013339 | 0.000170 |
| functions-main-0-0 | after | 0.013705 | 0.000521 |
| functions-main-0-1 | before | 0.013480 | 0.000214 |
| functions-main-0-1 | after | 0.013572 | 0.000129 |
| functions-main-64-0 | before | 0.013698 | 0.000627 |
| functions-main-64-0 | after | 0.013882 | 0.000260 |
| functions-main-256-0 | before | 0.014685 | 0.000657 |
| functions-main-256-0 | after | 0.015299 | 0.000609 |
| functions-main-1000-0 | before | 0.020149 | 0.000292 |
| functions-main-1000-0 | after | 0.020611 | 0.000153 |
| functions-main-1000-1 | before | 0.020396 | 0.000443 |
| functions-main-1000-1 | after | 0.021077 | 0.001500 |
| functions-args-0-0 | before | 0.013083 | 0.000234 |
| functions-args-0-0 | after | 0.013211 | 0.000085 |
| functions-args-0-1 | before | 0.013098 | 0.000576 |
| functions-args-0-1 | after | 0.013162 | 0.000092 |
| functions-args-1000-0 | before | 0.026303 | 0.000311 |
| functions-args-1000-0 | after | 0.027581 | 0.000596 |
| functions-args-1000-1 | before | 0.026567 | 0.001233 |
| functions-args-1000-1 | after | 0.027235 | 0.000432 |
| functions-modules-0-0 | before | 0.013064 | 0.000363 |
| functions-modules-0-0 | after | 0.013242 | 0.000079 |
| functions-modules-0-1 | before | 0.013063 | 0.000377 |
| functions-modules-0-1 | after | 0.013336 | 0.000492 |
| functions-modules-1000-0 | before | 0.020713 | 0.000206 |
| functions-modules-1000-0 | after | 0.021439 | 0.000665 |
| functions-modules-1000-1 | before | 0.020734 | 0.000244 |
| functions-modules-1000-1 | after | 0.021066 | 0.000392 |
| existing-fib | before | 0.013734 | 0.000717 |
| existing-fib | after | 0.013923 | 0.000166 |
| existing-loop | before | 0.013703 | 0.000387 |
| existing-loop | after | 0.013794 | 0.000222 |
| existing-string | before | 0.013525 | 0.000787 |
| existing-string | after | 0.013803 | 0.000167 |
| higher-0-0 | before | 0.013561 | 0.000860 |
| higher-0-0 | after | 0.013461 | 0.000644 |
| higher-1-0 | before | 0.014103 | 0.000287 |
| higher-1-0 | after | 0.014316 | 0.000208 |
| classes-0 | before | 0.017574 | 0.000273 |
| classes-0 | after | 0.018036 | 0.000315 |
| higher-0-300 | before | 0.028618 | 0.000875 |
| higher-0-300 | after | 0.029259 | 0.000884 |
| higher-1-300 | before | 0.030893 | 0.001084 |
| higher-1-300 | after | 0.031999 | 0.000397 |
| classes-300 | before | 0.036982 | 0.000376 |
| classes-300 | after | 0.038785 | 0.000461 |
| depth-0-8 | before | 0.014519 | 0.000375 |
| depth-0-8 | after | 0.014739 | 0.000107 |
| depth-1-8 | before | 0.014813 | 0.000314 |
| depth-1-8 | after | 0.015102 | 0.000104 |
| f1-nofail-call | before | 0.014137 | 0.000241 |
| f1-nofail-call | after | 0.014784 | 0.000377 |
| f1-join-effects | before | 0.013971 | 0.000512 |
| f1-join-effects | after | 0.014274 | 0.000599 |
| control-16.3 | before | 0.013097 | 0.000595 |
| control-16.3 | after | 0.013135 | 0.000108 |
| interval-bind-64 | before | 0.013223 | 0.000260 |
| interval-bind-64 | after | 0.013565 | 0.000406 |
| interval-bind-256 | before | 0.013705 | 0.000896 |
| interval-bind-256 | after | 0.014019 | 0.000260 |
| interval-add-64 | before | 0.013417 | 0.000230 |
| interval-add-64 | after | 0.013620 | 0.000060 |
| interval-add-256 | before | 0.015161 | 0.000682 |
| interval-add-256 | after | 0.015248 | 0.000293 |
| interval-flow-64 | before | 0.013774 | 0.000864 |
| interval-flow-64 | after | 0.014315 | 0.000268 |
| interval-flow-256 | before | 0.016705 | 0.000461 |
| interval-flow-256 | after | 0.017338 | 0.000286 |
| interval-range-0 | before | 0.018377 | 0.000683 |
| interval-range-0 | after | 0.018825 | 0.000294 |
| interval-range-64 | before | 0.023198 | 0.000663 |
| interval-range-64 | after | 0.024420 | 0.000409 |
| interval-range-256 | before | 0.035741 | 0.000422 |
| interval-range-256 | after | 0.036948 | 0.000375 |
| interval-http-0 | before | 0.018986 | 0.000329 |
| interval-http-0 | after | 0.019588 | 0.000572 |
| interval-http-64 | before | 0.022233 | 0.002691 |
| interval-http-64 | after | 0.022924 | 0.000362 |
| interval-http-256 | before | 0.029930 | 0.000313 |
| interval-http-256 | after | 0.030603 | 0.000735 |
| interval-width-Integer8-64 | before | 0.014055 | 0.000223 |
| interval-width-Integer8-64 | after | 0.014200 | 0.000354 |
| interval-width-Integer8-256 | before | 0.016681 | 0.000532 |
| interval-width-Integer8-256 | after | 0.016984 | 0.000174 |
| interval-width-Integer16-64 | before | 0.013960 | 0.000804 |
| interval-width-Integer16-64 | after | 0.013945 | 0.000323 |
| interval-width-Integer16-256 | before | 0.016573 | 0.000420 |
| interval-width-Integer16-256 | after | 0.016932 | 0.000082 |
| interval-width-Integer32-64 | before | 0.014099 | 0.000546 |
| interval-width-Integer32-64 | after | 0.014487 | 0.000379 |
| interval-width-Integer32-256 | before | 0.016766 | 0.000234 |
| interval-width-Integer32-256 | after | 0.017115 | 0.000388 |
| interval-width-Integer64-64 | before | 0.013927 | 0.000256 |
| interval-width-Integer64-64 | after | 0.014152 | 0.000204 |
| interval-width-Integer64-256 | before | 0.016859 | 0.000228 |
| interval-width-Integer64-256 | after | 0.017014 | 0.000570 |
| interval-width-UnsignedInteger16-64 | before | 0.013831 | 0.000728 |
| interval-width-UnsignedInteger16-64 | after | 0.014206 | 0.000517 |
| interval-width-UnsignedInteger16-256 | before | 0.017057 | 0.000453 |
| interval-width-UnsignedInteger16-256 | after | 0.017429 | 0.000672 |
| interval-width-UnsignedInteger32-64 | before | 0.013800 | 0.000213 |
| interval-width-UnsignedInteger32-64 | after | 0.014063 | 0.000119 |
| interval-width-UnsignedInteger32-256 | before | 0.016641 | 0.000214 |
| interval-width-UnsignedInteger32-256 | after | 0.016885 | 0.000778 |
| interval-width-UnsignedInteger64-64 | before | 0.014113 | 0.000795 |
| interval-width-UnsignedInteger64-64 | after | 0.014158 | 0.000173 |
| interval-width-UnsignedInteger64-256 | before | 0.016518 | 0.000445 |
| interval-width-UnsignedInteger64-256 | after | 0.017235 | 0.000398 |
| property-seven-24-20-1000-all-ok | before | 0.036809 | 0.000562 |
| property-seven-24-20-1000-all-ok | after | 0.038059 | 0.001163 |
| property-seven-24-20-1000-always-error | before | 0.035026 | 0.000542 |
| property-seven-24-20-1000-always-error | after | 0.036652 | 0.000598 |
| property-distinct-24-20-1000-all-ok | before | 0.035750 | 0.000204 |
| property-distinct-24-20-1000-all-ok | after | 0.036805 | 0.000322 |
| property-distinct-24-20-1000-always-error | before | 0.035364 | 0.000343 |
| property-distinct-24-20-1000-always-error | after | 0.036817 | 0.000659 |
| property-zero-24-20-1000-all-ok | before | 0.036202 | 0.000371 |
| property-zero-24-20-1000-all-ok | after | 0.037429 | 0.000432 |
| property-zero-24-20-1000-always-error | before | 0.035213 | 0.000396 |
| property-zero-24-20-1000-always-error | after | 0.036676 | 0.000167 |
| property-max-24-20-1000-all-ok | before | 0.037304 | 0.000763 |
| property-max-24-20-1000-all-ok | after | 0.038116 | 0.000950 |
| property-max-24-20-1000-always-error | before | 0.035357 | 0.000642 |
| property-max-24-20-1000-always-error | after | 0.036460 | 0.000531 |
| order-string-candidates | before | 0.035056 | 0.000340 |
| order-string-candidates | after | 0.036299 | 0.000337 |
| order-string-all-ok | before | 0.035600 | 0.000374 |
| order-string-all-ok | after | 0.037032 | 0.000405 |
| order-string-always-error | before | 0.035558 | 0.001222 |
| order-string-always-error | after | 0.036122 | 0.000504 |
| order-map-candidates | before | 0.035438 | 0.000619 |
| order-map-candidates | after | 0.036459 | 0.000567 |
| order-map-all-ok | before | 0.035733 | 0.000213 |
| order-map-all-ok | after | 0.036528 | 0.000707 |
| order-map-always-error | before | 0.035503 | 0.000924 |
| order-map-always-error | after | 0.036510 | 0.000521 |
| order-record-candidates | before | 0.036166 | 0.000861 |
| order-record-candidates | after | 0.037082 | 0.000597 |
| order-record-all-ok | before | 0.036268 | 0.000660 |
| order-record-all-ok | after | 0.037198 | 0.000478 |
| order-record-always-error | before | 0.036208 | 0.000225 |
| order-record-always-error | after | 0.036909 | 0.000572 |
| build-string-builder-8-0 | before | 0.015959 | 0.000407 |
| build-string-builder-8-0 | after | 0.016208 | 0.001756 |
| build-string-builder-all-8-0 | before | 0.015794 | 0.001047 |
| build-string-builder-all-8-0 | after | 0.015838 | 0.000221 |
| build-string-concatenate-8-0 | before | 0.015610 | 0.000239 |
| build-string-concatenate-8-0 | after | 0.015947 | 0.001944 |
| build-string-join-8-0 | before | 0.015538 | 0.000734 |
| build-string-join-8-0 | after | 0.015883 | 0.000749 |
| build-list-builder-8-0 | before | 0.015904 | 0.000209 |
| build-list-builder-8-0 | after | 0.016514 | 0.001002 |
| build-list-builder-all-8-0 | before | 0.015800 | 0.000561 |
| build-list-builder-all-8-0 | after | 0.016144 | 0.000189 |
| build-list-concatenate-8-0 | before | 0.015921 | 0.000556 |
| build-list-concatenate-8-0 | after | 0.016289 | 0.000143 |
| build-list-fold-8-0 | before | 0.015951 | 0.000234 |
| build-list-fold-8-0 | after | 0.016016 | 0.000164 |
| build-bytes-builder-8-0 | before | 0.016104 | 0.000618 |
| build-bytes-builder-8-0 | after | 0.016139 | 0.000247 |
| build-bytes-builder-all-8-0 | before | 0.015991 | 0.000555 |
| build-bytes-builder-all-8-0 | after | 0.016374 | 0.000329 |
| build-bytes-concatenate-8-0 | before | 0.016608 | 0.000421 |
| build-bytes-concatenate-8-0 | after | 0.016647 | 0.000517 |
| patterns-integer-100 | before | 0.014333 | 0.000246 |
| patterns-integer-100 | after | 0.014761 | 0.000836 |
| codegen-let-100 | before | 0.016731 | 0.000155 |
| codegen-let-100 | after | 0.017196 | 0.000125 |
| bridge-shared-8 | before | 0.004572 | 0.000357 |
| external-tests-normal-1 | before | 0.017955 | 0.000395 |
| external-tests-normal-1 | after | 0.018062 | 0.000873 |
| runtime-fib-short | before | 0.017921 | 0.000172 |
| runtime-fib-short | after | 0.018249 | 0.001147 |
| runtime-loop-short | before | 0.023596 | 0.001254 |
| runtime-loop-short | after | 0.024462 | 0.000427 |
| runtime-list-short | before | 0.029630 | 0.000899 |
| runtime-list-short | after | 0.029882 | 0.000169 |
| runtime-tree-short | before | 0.018342 | 0.000788 |
| runtime-tree-short | after | 0.018818 | 0.000303 |
| runtime-eval-short | before | 0.022047 | 0.000844 |
| runtime-eval-short | after | 0.022400 | 0.000191 |
| runtime-string-short | before | 0.016692 | 0.000314 |
| runtime-string-short | after | 0.017087 | 0.000708 |
| runtime-println-short | before | 0.017035 | 0.000375 |
| runtime-println-short | after | 0.017642 | 0.000215 |
| runtime-lines-short | before | 0.016740 | 0.000148 |
| runtime-lines-short | after | 0.017207 | 0.000619 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.7e-05 | 1.25e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.792e-06 | 8.4e-08 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.9875e-05 | 1.791e-06 |
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
    "after": "bf01d0caa366be726b572aef2f01c0519891cbca"
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
    "after": "public API helper build failed (1); see <repo>/target/bench/builds/bf01d0caa366be726b572aef2f01c0519891cbca-default/build.log"
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
| functions-main-1000-0 | 達成 | 0.0004620009999882768 | 0.0020148541000011735 |
| functions-main-1000-1 | 判定不能 | None | 0.002039579199998798 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.0012779999999992242 | 0.002630312499999832 |
| functions-args-1000-1 | 判定不能 | None | 0.0026566917000010906 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002071283400000823 |
| functions-modules-1000-1 | 判定不能 | None | 0.0020734290999996573 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028617957999998115 |
| higher-1-300 | 判定不能 | None | 0.003089333300000874 |
| classes-300 | 達成 | 0.0018035420000046543 | 0.003698162499999569 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 達成 | 0.0006477079999882562 | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 判定不能 | None | 0.002 |
| interval-range-64 | 達成 | 0.0012220010000021375 | 0.002319829099999993 |
| interval-range-256 | 達成 | 0.0012070420000185322 | 0.0035741082999990684 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.0022232709000007847 |
| interval-http-256 | 判定不能 | None | 0.0029930458999999133 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003680866700000252 |
| property-seven-24-20-1000-always-error | 達成 | 0.001626333999979579 | 0.0035026166000008633 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.0010552500000073906 | 0.0035750124999992753 |
| property-distinct-24-20-1000-always-error | 達成 | 0.0014526670000094555 | 0.003536437500000034 |
| property-zero-24-20-1000-all-ok | 達成 | 0.0012270420000106697 | 0.003620166599999664 |
| property-zero-24-20-1000-always-error | 達成 | 0.0014631259999902113 | 0.003521270800000309 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037303875000006315 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0035356957999994167 |
| order-string-candidates | 達成 | 0.001242332999993323 | 0.003505629200000726 |
| order-string-all-ok | 達成 | 0.0014317079999983662 | 0.003560041699999772 |
| order-string-always-error | 判定不能 | None | 0.003555795799999828 |
| order-map-candidates | 判定不能 | None | 0.003543804199999556 |
| order-map-all-ok | 判定不能 | None | 0.0035732625000008513 |
| order-map-always-error | 判定不能 | None | 0.003550254199998904 |
| order-record-candidates | 判定不能 | None | 0.0036165874999994686 |
| order-record-all-ok | 判定不能 | None | 0.0036267917000003536 |
| order-record-always-error | 判定不能 | None | 0.0036207625000002964 |
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
| runtime-loop-short | 判定不能 | None | 0.002359587499999805 |
| runtime-list-short | 判定不能 | None | 0.002962991699999407 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022046791999997596 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 達成 | 0.0006067910000098209 | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 達成 | 0.0004646250000064356 | 0.002 |
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
    "verify": 0.9043400000000048,
    "cli": 5.183879997999981,
    "warmup": 0.5814133319999684,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.1072996670000066,
    "cli": 11.713399418000051,
    "warmup": 1.3501214589999364,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2596240829999914,
    "cli": 8.950789499999999,
    "warmup": 1.24739158499996,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3625010840000016,
    "cli": 3.520021626000016,
    "warmup": 0.3542342120000086,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.08755050000000608,
    "cli": 0.276902249999992,
    "warmup": 0.02866479100001129,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03620004200000437,
    "cli": 0.3277637500000026,
    "warmup": 0.03500116699999012,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.005194541999998137,
    "cli": 0.09796158300000002,
    "warmup": 0.004656416000003105,
    "probe_warmup": 0.004144124999996279,
    "rss": 0,
    "stages": 0.020355666999989808,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04170162499998753,
    "cli": 0.3388575839999959,
    "warmup": 0.03571716600001196,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17903329199998552
  },
  "runtime": {
    "verify": 0.33454358400000217,
    "cli": 2.9292158340000043,
    "warmup": 0.3350885409999904,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
