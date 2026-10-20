# 版どうしの性能比較

候補: `270a717c670d9640d4c08f10bc400afa6e3fcef2`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.011477 | 0.000456 |
| functions-main-0-0 | after | 0.013979 | 0.001042 |
| functions-main-0-1 | before | 0.011207 | 0.000534 |
| functions-main-0-1 | after | 0.013321 | 0.000262 |
| functions-main-1000-0 | before | 0.015786 | 0.000309 |
| functions-main-1000-0 | after | 0.032064 | 0.001438 |
| functions-main-1000-1 | before | 0.016228 | 0.001093 |
| functions-main-1000-1 | after | 0.031508 | 0.001101 |
| functions-args-0-0 | before | 0.011112 | 0.000573 |
| functions-args-0-0 | after | 0.013226 | 0.000305 |
| functions-args-0-1 | before | 0.010732 | 0.000562 |
| functions-args-0-1 | after | 0.013929 | 0.000204 |
| functions-args-1000-0 | before | 0.019860 | 0.000967 |
| functions-args-1000-0 | after | 0.048972 | 0.001268 |
| functions-args-1000-1 | before | 0.020166 | 0.000751 |
| functions-args-1000-1 | after | 0.048580 | 0.001464 |
| functions-modules-0-0 | before | 0.010473 | 0.000530 |
| functions-modules-0-0 | after | 0.014270 | 0.000423 |
| functions-modules-0-1 | before | 0.010941 | 0.000179 |
| functions-modules-0-1 | after | 0.013086 | 0.000161 |
| functions-modules-1000-0 | before | 0.016212 | 0.000431 |
| functions-modules-1000-0 | after | 0.025288 | 0.000989 |
| functions-modules-1000-1 | before | 0.016641 | 0.000803 |
| functions-modules-1000-1 | after | 0.025547 | 0.002001 |
| existing-fib | before | 0.011615 | 0.000742 |
| existing-fib | after | 0.013929 | 0.000231 |
| existing-loop | before | 0.011731 | 0.000437 |
| existing-loop | after | 0.014007 | 0.000376 |
| existing-string | before | 0.011533 | 0.000539 |
| existing-string | after | 0.014069 | 0.000693 |
| higher-0-0 | before | 0.011034 | 0.000660 |
| higher-0-0 | after | 0.014072 | 0.000715 |
| higher-1-0 | before | 0.012024 | 0.000761 |
| higher-1-0 | after | 0.014507 | 0.000922 |
| classes-0 | before | 0.016348 | 0.000685 |
| classes-0 | after | 0.019172 | 0.000742 |
| higher-0-300 | before | 0.019669 | 0.001084 |
| higher-0-300 | after | 0.027498 | 0.000985 |
| higher-1-300 | before | 0.022519 | 0.000515 |
| higher-1-300 | after | 0.030538 | 0.000861 |
| classes-300 | before | 0.030167 | 0.000595 |
| classes-300 | after | 0.039349 | 0.000582 |
| depth-0-8 | before | 0.012147 | 0.000973 |
| depth-0-8 | after | 0.014906 | 0.000605 |
| depth-1-8 | before | 0.012417 | 0.000781 |
| depth-1-8 | after | 0.014972 | 0.000251 |
| f1-nofail-call | before | 0.011433 | 0.000762 |
| f1-nofail-call | after | 0.014742 | 0.000508 |
| f1-join-effects | before | 0.011309 | 0.000674 |
| f1-join-effects | after | 0.014317 | 0.000270 |
| control-16.3 | before | 0.010344 | 0.000699 |
| control-16.3 | after | 0.014075 | 0.000160 |
| property-seven-24-20-1000-all-ok | before | 0.035952 | 0.002934 |
| property-seven-24-20-1000-all-ok | after | 0.040324 | 0.000459 |
| property-seven-24-20-1000-always-error | before | 0.034534 | 0.001602 |
| property-seven-24-20-1000-always-error | after | 0.039569 | 0.000657 |
| property-distinct-24-20-1000-all-ok | before | 0.035056 | 0.001043 |
| property-distinct-24-20-1000-all-ok | after | 0.039492 | 0.000263 |
| property-distinct-24-20-1000-always-error | before | 0.034813 | 0.001835 |
| property-distinct-24-20-1000-always-error | after | 0.039107 | 0.000638 |
| property-zero-24-20-1000-all-ok | before | 0.036060 | 0.001478 |
| property-zero-24-20-1000-all-ok | after | 0.039834 | 0.000672 |
| property-zero-24-20-1000-always-error | before | 0.034526 | 0.000477 |
| property-zero-24-20-1000-always-error | after | 0.038842 | 0.000717 |
| property-max-24-20-1000-all-ok | before | 0.035730 | 0.001705 |
| property-max-24-20-1000-all-ok | after | 0.040394 | 0.000991 |
| property-max-24-20-1000-always-error | before | 0.034527 | 0.001709 |
| property-max-24-20-1000-always-error | after | 0.039585 | 0.000647 |
| order-string-candidates | before | 0.034090 | 0.001612 |
| order-string-candidates | after | 0.038684 | 0.000769 |
| order-string-all-ok | before | 0.034808 | 0.001703 |
| order-string-all-ok | after | 0.039385 | 0.000406 |
| order-string-always-error | before | 0.034607 | 0.000339 |
| order-string-always-error | after | 0.039045 | 0.001654 |
| order-map-candidates | before | 0.034859 | 0.002459 |
| order-map-candidates | after | 0.039404 | 0.000721 |
| order-map-all-ok | before | 0.034943 | 0.000703 |
| order-map-all-ok | after | 0.039725 | 0.001045 |
| order-map-always-error | before | 0.034959 | 0.001140 |
| order-map-always-error | after | 0.039669 | 0.000731 |
| order-record-candidates | before | 0.035271 | 0.001495 |
| order-record-candidates | after | 0.039652 | 0.000451 |
| order-record-all-ok | before | 0.035457 | 0.000895 |
| order-record-all-ok | after | 0.040335 | 0.000950 |
| order-record-always-error | before | 0.035073 | 0.001584 |
| order-record-always-error | after | 0.039849 | 0.000437 |
| build-string-builder-8-0 | before | 0.013219 | 0.000680 |
| build-string-builder-8-0 | after | 0.016619 | 0.000402 |
| build-string-builder-all-8-0 | before | 0.013331 | 0.000775 |
| build-string-builder-all-8-0 | after | 0.016841 | 0.000438 |
| build-string-concatenate-8-0 | before | 0.012604 | 0.001271 |
| build-string-concatenate-8-0 | after | 0.016086 | 0.000349 |
| build-string-join-8-0 | before | 0.013385 | 0.000975 |
| build-string-join-8-0 | after | 0.016539 | 0.000644 |
| build-list-builder-8-0 | before | 0.013671 | 0.001046 |
| build-list-builder-8-0 | after | 0.016339 | 0.000371 |
| build-list-builder-all-8-0 | before | 0.013779 | 0.001430 |
| build-list-builder-all-8-0 | after | 0.016527 | 0.000501 |
| build-list-concatenate-8-0 | before | 0.013804 | 0.000575 |
| build-list-concatenate-8-0 | after | 0.016474 | 0.000767 |
| build-list-fold-8-0 | before | 0.013575 | 0.000679 |
| build-list-fold-8-0 | after | 0.016475 | 0.000573 |
| build-bytes-builder-8-0 | before | 0.014065 | 0.001112 |
| build-bytes-builder-8-0 | after | 0.016169 | 0.000440 |
| build-bytes-builder-all-8-0 | before | 0.013733 | 0.000375 |
| build-bytes-builder-all-8-0 | after | 0.016382 | 0.000809 |
| build-bytes-concatenate-8-0 | before | 0.013551 | 0.000757 |
| build-bytes-concatenate-8-0 | after | 0.016785 | 0.000346 |
| patterns-integer-100 | before | 0.011964 | 0.000607 |
| patterns-integer-100 | after | 0.014834 | 0.000529 |
| codegen-let-100 | before | 0.015562 | 0.000413 |
| codegen-let-100 | after | 0.017762 | 0.000884 |
| bridge-shared-8 | before | 0.004821 | 0.000358 |
| bridge-shared-8 | after | 0.005191 | 0.000310 |
| external-tests-normal-1 | before | 0.015469 | 0.000762 |
| external-tests-normal-1 | after | 0.019016 | 0.001885 |
| runtime-fib-short | before | 0.015295 | 0.000575 |
| runtime-fib-short | after | 0.018287 | 0.000290 |
| runtime-loop-short | before | 0.020239 | 0.000419 |
| runtime-loop-short | after | 0.025138 | 0.001095 |
| runtime-list-short | before | 0.026491 | 0.000433 |
| runtime-list-short | after | 0.030092 | 0.001386 |
| runtime-tree-short | before | 0.015525 | 0.000681 |
| runtime-tree-short | after | 0.020010 | 0.001403 |
| runtime-eval-short | before | 0.018862 | 0.000444 |
| runtime-eval-short | after | 0.022938 | 0.001681 |
| runtime-string-short | before | 0.013703 | 0.000768 |
| runtime-string-short | after | 0.016892 | 0.000254 |
| runtime-println-short | before | 0.014604 | 0.000579 |
| runtime-println-short | after | 0.017530 | 0.001178 |
| runtime-lines-short | before | 0.014240 | 0.000718 |
| runtime-lines-short | after | 0.016953 | 0.000316 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 2.4625e-05 | 2.09e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.4125e-05 | 1.874e-06 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 4.9833e-05 | 1.333e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 511 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5291e-05 | 9.99e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.792e-06 | 3.74e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8083e-05 | 1.373e-06 |
| unique_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | after | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | after | 5 | 7 | 0 |
| runtime_compilations | count | external-tests-normal-1 | after | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | after | 5 | 1 | 0 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "c31e64b03d2810343e1779926bea4ebc958b6164",
    "after": "270a717c670d9640d4c08f10bc400afa6e3fcef2"
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
| functions-main-0-0 | 退行の疑い | 0.0025023749999997236 | 0.002 |
| functions-main-0-1 | 退行の疑い | 0.0021136259999998686 | 0.002 |
| functions-main-1000-0 | 退行の疑い | 0.016278250000000938 | 0.002 |
| functions-main-1000-1 | 退行の疑い | 0.015279873999999971 | 0.002 |
| functions-args-0-0 | 退行の疑い | 0.0021141670000011104 | 0.002 |
| functions-args-0-1 | 退行の疑い | 0.003197458000000708 | 0.002 |
| functions-args-1000-0 | 退行の疑い | 0.02911195799999966 | 0.002 |
| functions-args-1000-1 | 退行の疑い | 0.028414875000000173 | 0.002016550000000006 |
| functions-modules-0-0 | 退行の疑い | 0.003797333999999708 | 0.002 |
| functions-modules-0-1 | 退行の疑い | 0.0021450410000021236 | 0.002 |
| functions-modules-1000-0 | 退行の疑い | 0.009076750000000189 | 0.002 |
| functions-modules-1000-1 | 退行の疑い | 0.008905874999999952 | 0.002 |
| existing-fib | 退行の疑い | 0.0023136659999991593 | 0.002 |
| existing-loop | 退行の疑い | 0.0022757509999991044 | 0.002 |
| existing-string | 退行の疑い | 0.002536707999999166 | 0.002 |
| higher-0-0 | 退行の疑い | 0.0030373329999999754 | 0.002 |
| higher-1-0 | 退行の疑い | 0.0024827499999986458 | 0.002 |
| classes-0 | 退行の疑い | 0.002823957999998683 | 0.002 |
| higher-0-300 | 退行の疑い | 0.007828791999999751 | 0.002 |
| higher-1-300 | 退行の疑い | 0.008019541999999547 | 0.0022518707999999777 |
| classes-300 | 退行の疑い | 0.009181624999998306 | 0.003016737500000133 |
| depth-0-8 | 退行の疑い | 0.0027582490000011006 | 0.002 |
| depth-1-8 | 退行の疑い | 0.0025552920000002644 | 0.002 |
| f1-nofail-call | 退行の疑い | 0.0033089999999997843 | 0.002 |
| f1-join-effects | 退行の疑い | 0.003008541999999892 | 0.002 |
| control-16.3 | 退行の疑い | 0.003731291999999442 | 0.002 |
| property-seven-24-20-1000-all-ok | 退行の疑い | 0.004372249999999411 | 0.003595179200000054 |
| property-seven-24-20-1000-always-error | 退行の疑い | 0.005034917000001471 | 0.003453416699999856 |
| property-distinct-24-20-1000-all-ok | 退行の疑い | 0.004436125999999874 | 0.0035055916000001023 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.00429404199999972 | 0.003481262500000071 |
| property-zero-24-20-1000-all-ok | 退行の疑い | 0.0037733330000015997 | 0.00360601669999987 |
| property-zero-24-20-1000-always-error | 退行の疑い | 0.00431616799999901 | 0.0034526040999999456 |
| property-max-24-20-1000-all-ok | 退行の疑い | 0.004664376000000914 | 0.003573004100000077 |
| property-max-24-20-1000-always-error | 退行の疑い | 0.005057749999998862 | 0.0034527292000003486 |
| order-string-candidates | 退行の疑い | 0.004593791999997876 | 0.0034090416000001514 |
| order-string-all-ok | 退行の疑い | 0.0045770000000011635 | 0.003480833299999731 |
| order-string-always-error | 退行の疑い | 0.00443887500000173 | 0.00346065419999988 |
| order-map-candidates | 退行の疑い | 0.004544957999996768 | 0.00348589170000011 |
| order-map-all-ok | 退行の疑い | 0.004782541000000862 | 0.0034942666999999263 |
| order-map-always-error | 退行の疑い | 0.004710291999998617 | 0.0034958875000000948 |
| order-record-candidates | 退行の疑い | 0.004381375999997772 | 0.0035270583000002634 |
| order-record-all-ok | 退行の疑い | 0.004877458999999362 | 0.0035457208000000406 |
| order-record-always-error | 退行の疑い | 0.004775582999997141 | 0.00350730420000005 |
| build-string-builder-8-0 | 退行の疑い | 0.003399874999999497 | 0.002 |
| build-string-builder-all-8-0 | 退行の疑い | 0.0035101669999981766 | 0.002 |
| build-string-concatenate-8-0 | 退行の疑い | 0.003481875999998607 | 0.002 |
| build-string-join-8-0 | 退行の疑い | 0.0031543749999976 | 0.002 |
| build-list-builder-8-0 | 退行の疑い | 0.0026677080000006015 | 0.002 |
| build-list-builder-all-8-0 | 退行の疑い | 0.0027487089999986836 | 0.002 |
| build-list-concatenate-8-0 | 退行の疑い | 0.0026703739999973664 | 0.002 |
| build-list-fold-8-0 | 退行の疑い | 0.002899666999997663 | 0.002 |
| build-bytes-builder-8-0 | 退行の疑い | 0.00210404199999914 | 0.002 |
| build-bytes-builder-all-8-0 | 退行の疑い | 0.002648999999998125 | 0.002 |
| build-bytes-concatenate-8-0 | 退行の疑い | 0.003233750999996232 | 0.002 |
| runtime-fib-short | 退行の疑い | 0.0029922910000017566 | 0.002 |
| runtime-loop-short | 退行の疑い | 0.004898833999998686 | 0.002023883300000051 |
| runtime-list-short | 退行の疑い | 0.0036018330000011645 | 0.0026490624999997436 |
| runtime-tree-short | 退行の疑い | 0.004484584000000069 | 0.002 |
| runtime-eval-short | 退行の疑い | 0.004076540999999878 | 0.002 |
| runtime-string-short | 退行の疑い | 0.003188874999999314 | 0.002 |
| runtime-println-short | 退行の疑い | 0.002926667000000549 | 0.002 |
| runtime-lines-short | 退行の疑い | 0.002712832999996806 | 0.002 |
| patterns-integer-100 | 退行の疑い | 0.002869792000002036 | 0.002 |
| codegen-let-100 | 退行の疑い | 0.0021998329999988187 | 0.002 |
| bridge-shared-8 | 判定不能 | None | 0.002 |
| external-tests-normal-1 | 退行の疑い | 0.003547498999999732 | 0.002 |

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
    "verify": 1.155811458,
    "cli": 4.5815446269999995,
    "warmup": 0.5423217510000002,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 0.849786208,
    "cli": 3.3205772909999958,
    "warmup": 0.3902430809999995,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2733181669999998,
    "cli": 8.90675016800001,
    "warmup": 1.2745352500000013,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3361045420000002,
    "cli": 3.301019085,
    "warmup": 0.33039679100000185,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.08822854100000033,
    "cli": 0.2596075419999977,
    "warmup": 0.027225874999999178,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03543891699999957,
    "cli": 0.3174890829999981,
    "warmup": 0.03237145900000016,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.01062612499999993,
    "cli": 0.1973504169999991,
    "warmup": 0.009390626000001845,
    "probe_warmup": 0.009382709000000489,
    "rss": 0,
    "stages": 0.03979020899999597,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.03882775000000027,
    "cli": 0.3238520410000021,
    "warmup": 0.033399375999998426,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17190458200001046
  },
  "runtime": {
    "verify": 0.3092165409999996,
    "cli": 2.740841462000006,
    "warmup": 0.30744908400000526,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
