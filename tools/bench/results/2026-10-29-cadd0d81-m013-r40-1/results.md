# 版どうしの性能比較

候補: `cadd0d810d5660e657f81398c33c67674a4df01c`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.016196 | 0.000730 |
| functions-main-0-0 | after | 0.016288 | 0.000115 |
| functions-main-0-1 | before | 0.015892 | 0.000961 |
| functions-main-0-1 | after | 0.016204 | 0.000158 |
| functions-main-64-0 | before | 0.014389 | 0.002343 |
| functions-main-64-0 | after | 0.014585 | 0.000638 |
| functions-main-256-0 | before | 0.015504 | 0.001148 |
| functions-main-256-0 | after | 0.016339 | 0.000355 |
| functions-main-1000-0 | before | 0.020939 | 0.000275 |
| functions-main-1000-0 | after | 0.022320 | 0.002529 |
| functions-main-1000-1 | before | 0.021915 | 0.000725 |
| functions-main-1000-1 | after | 0.023779 | 0.001857 |
| functions-args-0-0 | before | 0.014679 | 0.001562 |
| functions-args-0-0 | after | 0.014757 | 0.002039 |
| functions-args-0-1 | before | 0.016248 | 0.002299 |
| functions-args-0-1 | after | 0.016233 | 0.002776 |
| functions-args-1000-0 | before | 0.029547 | 0.001339 |
| functions-args-1000-0 | after | 0.031305 | 0.001606 |
| functions-args-1000-1 | before | 0.031913 | 0.004238 |
| functions-args-1000-1 | after | 0.033691 | 0.002788 |
| functions-modules-0-0 | before | 0.015304 | 0.000779 |
| functions-modules-0-0 | after | 0.016063 | 0.000289 |
| functions-modules-0-1 | before | 0.015785 | 0.000561 |
| functions-modules-0-1 | after | 0.016553 | 0.000804 |
| functions-modules-1000-0 | before | 0.024392 | 0.000518 |
| functions-modules-1000-0 | after | 0.026371 | 0.004248 |
| functions-modules-1000-1 | before | 0.023810 | 0.000430 |
| functions-modules-1000-1 | after | 0.024468 | 0.001671 |
| existing-fib | before | 0.015832 | 0.000585 |
| existing-fib | after | 0.016205 | 0.000096 |
| existing-loop | before | 0.015634 | 0.000438 |
| existing-loop | after | 0.016185 | 0.000274 |
| existing-string | before | 0.015810 | 0.000660 |
| existing-string | after | 0.015971 | 0.000385 |
| higher-0-0 | before | 0.014868 | 0.001212 |
| higher-0-0 | after | 0.015377 | 0.000434 |
| higher-1-0 | before | 0.015903 | 0.000169 |
| higher-1-0 | after | 0.016345 | 0.000508 |
| classes-0 | before | 0.019938 | 0.000396 |
| classes-0 | after | 0.022447 | 0.001685 |
| higher-0-300 | before | 0.030910 | 0.000722 |
| higher-0-300 | after | 0.032323 | 0.000831 |
| higher-1-300 | before | 0.035719 | 0.002327 |
| higher-1-300 | after | 0.037261 | 0.000702 |
| classes-300 | before | 0.041545 | 0.003548 |
| classes-300 | after | 0.045317 | 0.000803 |
| depth-0-8 | before | 0.016333 | 0.003347 |
| depth-0-8 | after | 0.017130 | 0.000419 |
| depth-1-8 | before | 0.015856 | 0.000751 |
| depth-1-8 | after | 0.016613 | 0.000945 |
| f1-nofail-call | before | 0.014636 | 0.002061 |
| f1-nofail-call | after | 0.014758 | 0.000174 |
| f1-join-effects | before | 0.014655 | 0.002029 |
| f1-join-effects | after | 0.014846 | 0.000437 |
| control-16.3 | before | 0.013315 | 0.001866 |
| control-16.3 | after | 0.013912 | 0.000362 |
| interval-bind-64 | before | 0.013609 | 0.002091 |
| interval-bind-64 | after | 0.014143 | 0.000256 |
| interval-bind-256 | before | 0.014305 | 0.001729 |
| interval-bind-256 | after | 0.014628 | 0.000279 |
| interval-add-64 | before | 0.014643 | 0.001417 |
| interval-add-64 | after | 0.014765 | 0.000085 |
| interval-add-256 | before | 0.015457 | 0.000505 |
| interval-add-256 | after | 0.015980 | 0.000574 |
| interval-flow-64 | before | 0.015213 | 0.001270 |
| interval-flow-64 | after | 0.015046 | 0.000496 |
| interval-flow-256 | before | 0.017760 | 0.001187 |
| interval-flow-256 | after | 0.018796 | 0.001221 |
| interval-range-0 | before | 0.019706 | 0.000556 |
| interval-range-0 | after | 0.022113 | 0.002234 |
| interval-range-64 | before | 0.024703 | 0.001250 |
| interval-range-64 | after | 0.027757 | 0.001233 |
| interval-range-256 | before | 0.038060 | 0.002084 |
| interval-range-256 | after | 0.039923 | 0.000772 |
| interval-http-0 | before | 0.022978 | 0.001808 |
| interval-http-0 | after | 0.026418 | 0.003829 |
| interval-http-64 | before | 0.027246 | 0.000401 |
| interval-http-64 | after | 0.030774 | 0.006073 |
| interval-http-256 | before | 0.035817 | 0.004251 |
| interval-http-256 | after | 0.038153 | 0.002178 |
| interval-width-Integer8-64 | before | 0.015655 | 0.000432 |
| interval-width-Integer8-64 | after | 0.016204 | 0.000363 |
| interval-width-Integer8-256 | before | 0.019245 | 0.000352 |
| interval-width-Integer8-256 | after | 0.020222 | 0.001704 |
| interval-width-Integer16-64 | before | 0.016229 | 0.000259 |
| interval-width-Integer16-64 | after | 0.016813 | 0.000404 |
| interval-width-Integer16-256 | before | 0.018970 | 0.000646 |
| interval-width-Integer16-256 | after | 0.020043 | 0.002666 |
| interval-width-Integer32-64 | before | 0.016135 | 0.000600 |
| interval-width-Integer32-64 | after | 0.016563 | 0.000343 |
| interval-width-Integer32-256 | before | 0.018890 | 0.000579 |
| interval-width-Integer32-256 | after | 0.019264 | 0.001594 |
| interval-width-Integer64-64 | before | 0.016166 | 0.000655 |
| interval-width-Integer64-64 | after | 0.016651 | 0.000214 |
| interval-width-Integer64-256 | before | 0.019317 | 0.000343 |
| interval-width-Integer64-256 | after | 0.019511 | 0.002160 |
| interval-width-UnsignedInteger16-64 | before | 0.016396 | 0.000701 |
| interval-width-UnsignedInteger16-64 | after | 0.016692 | 0.000169 |
| interval-width-UnsignedInteger16-256 | before | 0.018828 | 0.000613 |
| interval-width-UnsignedInteger16-256 | after | 0.020440 | 0.002720 |
| interval-width-UnsignedInteger32-64 | before | 0.015988 | 0.000504 |
| interval-width-UnsignedInteger32-64 | after | 0.016519 | 0.000310 |
| interval-width-UnsignedInteger32-256 | before | 0.018282 | 0.000819 |
| interval-width-UnsignedInteger32-256 | after | 0.019431 | 0.002485 |
| interval-width-UnsignedInteger64-64 | before | 0.014900 | 0.003166 |
| interval-width-UnsignedInteger64-64 | after | 0.015277 | 0.000567 |
| interval-width-UnsignedInteger64-256 | before | 0.017425 | 0.000365 |
| interval-width-UnsignedInteger64-256 | after | 0.017626 | 0.000584 |
| property-seven-24-20-1000-all-ok | before | 0.039588 | 0.004175 |
| property-seven-24-20-1000-all-ok | after | 0.046567 | 0.002985 |
| property-seven-24-20-1000-always-error | before | 0.040004 | 0.004463 |
| property-seven-24-20-1000-always-error | after | 0.044538 | 0.002079 |
| property-distinct-24-20-1000-all-ok | before | 0.037109 | 0.004187 |
| property-distinct-24-20-1000-all-ok | after | 0.041635 | 0.001369 |
| property-distinct-24-20-1000-always-error | before | 0.035887 | 0.001955 |
| property-distinct-24-20-1000-always-error | after | 0.041154 | 0.003052 |
| property-zero-24-20-1000-all-ok | before | 0.041745 | 0.002345 |
| property-zero-24-20-1000-all-ok | after | 0.046325 | 0.000789 |
| property-zero-24-20-1000-always-error | before | 0.039726 | 0.002570 |
| property-zero-24-20-1000-always-error | after | 0.044172 | 0.000203 |
| property-max-24-20-1000-all-ok | before | 0.041400 | 0.002698 |
| property-max-24-20-1000-all-ok | after | 0.045910 | 0.001759 |
| property-max-24-20-1000-always-error | before | 0.040002 | 0.002713 |
| property-max-24-20-1000-always-error | after | 0.044916 | 0.002111 |
| order-string-candidates | before | 0.039942 | 0.001795 |
| order-string-candidates | after | 0.044202 | 0.001041 |
| order-string-all-ok | before | 0.040420 | 0.002764 |
| order-string-all-ok | after | 0.044210 | 0.000349 |
| order-string-always-error | before | 0.041905 | 0.002096 |
| order-string-always-error | after | 0.045265 | 0.001917 |
| order-map-candidates | before | 0.041900 | 0.003453 |
| order-map-candidates | after | 0.046613 | 0.001352 |
| order-map-all-ok | before | 0.041098 | 0.002507 |
| order-map-all-ok | after | 0.045518 | 0.000453 |
| order-map-always-error | before | 0.040113 | 0.002140 |
| order-map-always-error | after | 0.045336 | 0.000356 |
| order-record-candidates | before | 0.041149 | 0.002897 |
| order-record-candidates | after | 0.045746 | 0.000679 |
| order-record-all-ok | before | 0.041835 | 0.002247 |
| order-record-all-ok | after | 0.046624 | 0.000585 |
| order-record-always-error | before | 0.040768 | 0.002158 |
| order-record-always-error | after | 0.045663 | 0.000372 |
| build-string-builder-8-0 | before | 0.018215 | 0.000336 |
| build-string-builder-8-0 | after | 0.018671 | 0.002530 |
| build-string-builder-all-8-0 | before | 0.018249 | 0.000548 |
| build-string-builder-all-8-0 | after | 0.018963 | 0.002430 |
| build-string-concatenate-8-0 | before | 0.018006 | 0.000120 |
| build-string-concatenate-8-0 | after | 0.018676 | 0.000850 |
| build-string-join-8-0 | before | 0.017781 | 0.000830 |
| build-string-join-8-0 | after | 0.018128 | 0.001102 |
| build-list-builder-8-0 | before | 0.018169 | 0.000176 |
| build-list-builder-8-0 | after | 0.018826 | 0.002428 |
| build-list-builder-all-8-0 | before | 0.017898 | 0.000522 |
| build-list-builder-all-8-0 | after | 0.018820 | 0.002618 |
| build-list-concatenate-8-0 | before | 0.018454 | 0.000368 |
| build-list-concatenate-8-0 | after | 0.019392 | 0.002493 |
| build-list-fold-8-0 | before | 0.018376 | 0.000386 |
| build-list-fold-8-0 | after | 0.019428 | 0.001975 |
| build-bytes-builder-8-0 | before | 0.018160 | 0.000540 |
| build-bytes-builder-8-0 | after | 0.018712 | 0.002219 |
| build-bytes-builder-all-8-0 | before | 0.017937 | 0.000477 |
| build-bytes-builder-all-8-0 | after | 0.019189 | 0.002465 |
| build-bytes-concatenate-8-0 | before | 0.018681 | 0.000308 |
| build-bytes-concatenate-8-0 | after | 0.019143 | 0.001916 |
| patterns-integer-100 | before | 0.016786 | 0.000269 |
| patterns-integer-100 | after | 0.016846 | 0.000500 |
| codegen-let-100 | before | 0.020255 | 0.000792 |
| codegen-let-100 | after | 0.021669 | 0.002435 |
| bridge-shared-8 | before | 0.005499 | 0.000302 |
| bridge-shared-8 | after | 0.005463 | 0.000646 |
| external-tests-normal-1 | before | 0.020666 | 0.000335 |
| external-tests-normal-1 | after | 0.021440 | 0.001536 |
| runtime-fib-short | before | 0.020668 | 0.000305 |
| runtime-fib-short | after | 0.021301 | 0.001375 |
| runtime-loop-short | before | 0.026580 | 0.000427 |
| runtime-loop-short | after | 0.026945 | 0.001796 |
| runtime-list-short | before | 0.032922 | 0.000684 |
| runtime-list-short | after | 0.034100 | 0.000839 |
| runtime-tree-short | before | 0.020997 | 0.000233 |
| runtime-tree-short | after | 0.022047 | 0.000813 |
| runtime-eval-short | before | 0.024947 | 0.000289 |
| runtime-eval-short | after | 0.025797 | 0.001859 |
| runtime-string-short | before | 0.018955 | 0.000096 |
| runtime-string-short | after | 0.020045 | 0.002302 |
| runtime-println-short | before | 0.019402 | 0.000140 |
| runtime-println-short | after | 0.020313 | 0.002302 |
| runtime-lines-short | before | 0.018937 | 0.000399 |
| runtime-lines-short | after | 0.021410 | 0.001235 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 2.1291e-05 | 6.375e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.542e-06 | 6.25e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.4916e-05 | 7.292e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6125e-05 | 2.75e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 4.25e-06 | 5.84e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 2.0375e-05 | 4.168e-06 |
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
    "after": "cadd0d810d5660e657f81398c33c67674a4df01c"
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
| functions-main-1000-0 | 判定不能 | None | 0.0020938709000006385 |
| functions-main-1000-1 | 判定不能 | None | 0.0021914750000007646 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0029546957999997403 |
| functions-args-1000-1 | 判定不能 | None | 0.003191325000000234 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002439233299999444 |
| functions-modules-1000-1 | 判定不能 | None | 0.0023810333999989552 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 退行の疑い | 0.0025091250000031096 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0030910250000005138 |
| higher-1-300 | 判定不能 | None | 0.0035719083000003596 |
| classes-300 | 判定不能 | None | 0.004154470800000354 |
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
| interval-range-64 | 退行の疑い | 0.003053750999995941 | 0.002470341599999415 |
| interval-range-256 | 判定不能 | None | 0.003805954199999917 |
| interval-http-0 | 判定不能 | None | 0.002297804200000542 |
| interval-http-64 | 判定不能 | None | 0.002724604200000158 |
| interval-http-256 | 判定不能 | None | 0.0035817082999997753 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003958825000000843 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.004000437499999521 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0037109375000000003 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.005267040999996198 | 0.0035886875000016973 |
| property-zero-24-20-1000-all-ok | 退行の疑い | 0.004579792000015459 | 0.004174491599999897 |
| property-zero-24-20-1000-always-error | 退行の疑い | 0.004446124000025975 | 0.003972633399999381 |
| property-max-24-20-1000-all-ok | 退行の疑い | 0.00451000000001045 | 0.004139983299998562 |
| property-max-24-20-1000-always-error | 退行の疑い | 0.004913291999997682 | 0.004000229199999694 |
| order-string-candidates | 退行の疑い | 0.0042598750000024665 | 0.003994220799998516 |
| order-string-all-ok | 達成 | 0.003789834000031078 | 0.004042016599998988 |
| order-string-always-error | 判定不能 | None | 0.0041905417000009495 |
| order-map-candidates | 判定不能 | None | 0.004190008299997316 |
| order-map-all-ok | 退行の疑い | 0.0044201250000242 | 0.00410977499999774 |
| order-map-always-error | 退行の疑い | 0.005222540999994862 | 0.004011341700001481 |
| order-record-candidates | 退行の疑い | 0.004596750000018801 | 0.0041148999999990115 |
| order-record-all-ok | 退行の疑い | 0.004789665999993531 | 0.004183454200000369 |
| order-record-always-error | 退行の疑い | 0.00489512499999023 | 0.0040768167000010186 |
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
| runtime-fib-short | 判定不能 | None | 0.002066762499998731 |
| runtime-loop-short | 判定不能 | None | 0.0026580416000001605 |
| runtime-list-short | 判定不能 | None | 0.0032922374999998284 |
| runtime-tree-short | 達成 | 0.0010500420000028043 | 0.0020996666999991477 |
| runtime-eval-short | 判定不能 | None | 0.0024946875000011917 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 退行の疑い | 0.0024729170000057366 | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002025520899999833 |
| bridge-shared-8 | 判定不能 | None | 0.002 |
| external-tests-normal-1 | 判定不能 | None | 0.0020665625000020785 |

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
    "verify": 1.838348209000003,
    "cli": 6.0439588320000155,
    "warmup": 0.6687728750000304,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 3.353581332999994,
    "cli": 13.252582162999971,
    "warmup": 1.5072110390000546,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.488328542000005,
    "cli": 10.438839668000043,
    "warmup": 1.447928501000007,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.4195967920000072,
    "cli": 4.066252709999986,
    "warmup": 0.40262170799996966,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.1104375000000033,
    "cli": 0.3257965829999989,
    "warmup": 0.033190832999991926,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04395900000000097,
    "cli": 0.40536808300001326,
    "warmup": 0.038195624999985966,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.012147999999996273,
    "cli": 0.2523636250000152,
    "warmup": 0.00999041599999373,
    "probe_warmup": 0.00950816599998916,
    "rss": 0,
    "stages": 0.04775733400001059,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.061917917000002376,
    "cli": 0.4003998329999945,
    "warmup": 0.04003054199998246,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.21003395600001795
  },
  "runtime": {
    "verify": 0.380440667000002,
    "cli": 3.3513437500000123,
    "warmup": 0.3716312509999682,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

九つの区分の出力の照合はすべて通った。退行の疑いの族は R30.2c・R30.4 の後の比較と同じ（Trait を使う点は設計者が採った費用、`runtime-lines-short` は File が Scope を読む分と TODO-304、`interval-http-*` は既知）。R40.1 は診断の文言と案内の変更で、検査の通る経路の処理は変えていない。全94入力の after/before の中央値の比は 1.048（R30.4 の後は 1.043）。
