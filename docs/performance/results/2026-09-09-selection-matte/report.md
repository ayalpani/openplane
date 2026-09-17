# Opaque background inside selected outline

Shared window card layer adds opaque background-colored matte behind preview, extending to rounded outline. Selected image-to-stroke gap is 8pt; matte hidden on unselected cards and placeholders. Existing stack order and navigation retained.

Nine Overview tests PASS including matte visible/opaque/outside image and hidden on unselected card. Synthetic native scene visually checked; no Storybook for AppKit. Signed Release build/signature PASS; installed AX launch Overview confirmed. No user screenshots inspected. Full installed visual confirmation remains NOT RUN under privacy constraint.

P04/P20 full live variants/core smoke/matched baseline **NOT RUN: scheduled overnight**, source/build in identity.json. Same first/warm fixture. Idle/action/additional CPU and presented latency NOT RUN. Controlled safe fixture/calibrated observer **BLOCKED**, follow-up [PERF-025](../../backlog.md#perf-025--view-overlay-movement-policy-and-prompt-prototype-acceptance). No measured performance gain claimed.
