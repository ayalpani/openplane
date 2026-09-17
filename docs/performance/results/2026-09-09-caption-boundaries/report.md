# First/last caption investigation

Added regression for visible first/middle/last stack title, including effective ancestor opacity. PASS in existing native grouped Overview test; reported missing title NOT REPRODUCED. No product rendering code changed or app rebuilt/installed for this investigation.

Found two same-bundle OpenPlane processes. Current /Applications app PID 29889 started Sep 9, binary SHA 389a90b7a5fad0a06e2120ff7f3291977634ed9e97ba0bbd3814563f8e669d93. Obsolete repo DerivedData Debug PID 71486 started Sep 7; binary timestamp Sep 2; both com.yalpani.openplane.poc. Terminated only obsolete debug process; subsequent process listing confirms installed app alone remains. Whether duplicate caused title symptom UNCONFIRMED. No screenshots viewed.

Performance comparison NOT APPLICABLE: no production-code change. Live title confirmation awaits clarification of first/last stack windows versus first/last app and user verification after removal of competing instance. Existing P04/P20 nightly checks remain scheduled, not passed. Test source remains in working tree.
