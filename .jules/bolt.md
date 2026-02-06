## 2026-02-06 - Reducing Python Interpreter Overhead
**Learning:** In bash scripts, invoking `python3` multiple times (e.g., once per JSON field) introduces significant latency due to interpreter startup.
**Action:** Consolidate multiple extractions into a single Python call that outputs shell-safe variable assignments (using `shlex.quote`) and consume them with `eval`. This effectively mimics a "structured return" from the subprocess.
