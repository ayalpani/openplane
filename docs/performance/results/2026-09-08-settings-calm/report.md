# Progressive view settings

Replaced the dense editor entry with four borderless navigation rows. Individual detail shows name and existing movement switches. AI form is collapsed until explicitly opened. Root uses the same navigation-row rendering as the list; back/Escape traverse detail → list → general Settings. Current view labels refresh through the existing common update path.

Nine OverviewModeTests PASS. Synthetic list/detail rendered and visually reviewed against the prior settings-views synthetic detail. Native AppKit: no Storybook story; native test rendering is the visual surface. Signed Release build/signature PASS. Installed AX-only navigation, disclosure and Escape check PASS; original Overview/settings visibility restored. No user screenshots inspected.

P13/P20/P21 complete variants, core smoke and paired baseline comparisons **NOT RUN: scheduled overnight**, case/source/build identity in identity.json. Same viewport and first/warm cache fixture required. Idle CPU, action CPU, additional CPU and presented latency **NOT RUN**. Calibrated observer and complete reproducible live fixture **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No measured performance gain claimed.
