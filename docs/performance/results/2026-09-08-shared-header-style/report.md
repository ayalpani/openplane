# Shared Recent/Canvas header styling

Overview previously used fixed 17pt semibold title, 28pt icon and extra 8pt icon-bottom gap. Now shares CanvasMath.previewHeaderFont (12pt medium/bold), previewHeaderLayout/title lift and titleVisibility, zoom-dependent icon sizing and drawAppIcon badge rendering. Common stack title remains centered with icon, prefix only for multiple windows, tail truncation preserved. Between-group gap already used CanvasMath.itemGap like Recent; intentional within-app overlap retained.

Grouped navigation/restore regression PASS. Synthetic rendering visually inspected. Signed Release build/signature PASS; installed AX launch confirms Overview active. No user preview images inspected. No unrelated user preferences changed.

P17/P15 full low/high zoom and input coverage, core smoke, matched baseline comparisons **NOT RUN: scheduled overnight** for identity.json source/build. Same safe fixture and method, first/warm conditions. Idle/action/additional CPU and latency **NOT RUN**; calibrated observer/fixture **BLOCKED**, [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No performance gain claimed.
