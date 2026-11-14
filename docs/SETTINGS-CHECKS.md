# Settings checks — 2.1.0

Changes are read through Zeron's real read-only settings API. The test host changes that settings state and renders the real plugin components. Zeron's upstream settings-store test separately checks defaults, writes, and reload persistence.

| Setting | Checked behavior |
| --- | --- |
| Enable NSFW | Turning it off clears all non-safe results immediately; no unsafe image remains rendered. |
| Safe / Suggestive / Borderline / Explicit | Each rating selects the right request and result set. No request is sent with no effective rating. |
| Hide NSFW previews | Protected image nodes are absent until Reveal. Re-enabling Hide removes unrevealed previews. |
| Blur NSFW thumbnails | The gallery switches between the blurred and plain image branches without a reload. |
| Included tags / Artist | Values appear URL-encoded in the actual request string. |
| Excluded tags | Matching returned images are removed locally. No unsupported API parameter is sent. |
| Images per request | Limit is clamped to 1–100. A one-image slideshow requests another batch on its timer. |
| Avoid duplicate images | Repeated records are skipped when enabled and accepted when disabled. |
| Gallery / Single Image | Both the page and native panel use the setting. Selection and batch survive mode changes; no extra API call. |
| Auto-refresh / interval | A new request occurs at the configured interval; disabling stops it. |
| Auto-load more | Enabling it at the end of the grid starts loading, without requiring another scroll. |
| Show metadata | Metadata mounts and unmounts immediately in the panel. |
| Preserve aspect ratio | The native renderer's bitmap geometry changes between Contain and Cover. Letterbox space has no plugin background fill. |
| Download format | Original / PNG / JPEG reach the exporter. Export logic has separate mocked-browser tests; the real Windows Save dialog and conversion remain unverified. |
| Start slideshow automatically / interval | Changed defaults update live controls. Play/Pause and timing controls are saved separately with `zeron.store`. |

Thirteen native UI tests pass. A separate Rust host test uses actual WebP bytes and the native image decoder. It checks repeated playback, fit geometry, retaining the last image during a stalled request, timeout recovery, and hidden-view pause.

The test host has no process-running API. No Python or external process dependency was added. The packaged Windows app was not available in this environment.
