# Nekos Anime Images — Zeron v3

Version **2.2.0**. A floating image viewer, slideshow, and gallery for Zeron's desktop plugin system, checked against **v0.3.4**.

**No Python, Pillow, Tkinter, npm packages, external programs, or new runtime dependencies.** The plugin uses Luau, Zeron's SDK, zgx image rendering, and Zeron's existing web view for image export. It does not request permission to run commands.

## Install or update on Windows, macOS, or Linux

Use the Zeron desktop app for your operating system. If you need to install it, get it from [Zeron Releases](https://github.com/zeronsh/zeron/releases). Open the `.dmg` on macOS, run the setup `.exe` on Windows, or extract the Linux archive and run its `install.sh`.

1. Download the [v2.2.0 source ZIP](https://github.com/Master0fFate/nekos-zeron-plugin/archive/refs/tags/v2.2.0.zip) and extract it.
2. In Zeron, go to **Settings → Plugins** and open the plugins folder.
3. Disable the old plugin if it is installed. Copy the extracted folder into the plugins folder and name it `nekos-api-anime-images`. Replace the old folder in full. Keep `zeron-plugin.json` and `init.luau` at the top level of the plugin folder.
4. If Zeron requires a signature, follow the steps below. Then enable **Nekos Anime Images** and review its permissions. Select **Nekos Anime Images** in the sidebar, then select **Open PiP**.

### Sign the plugin if required

Keep Zeron open. After you copy the plugin folder, run the command for your operating system.

**Windows (Command Prompt)**

```bat
start "" /wait "%LOCALAPPDATA%\Programs\Zeron\zeron.exe" plugin sign nekos-api-anime-images
```

**macOS (Terminal)**

```sh
/Applications/Zeron.app/Contents/MacOS/zeron plugin sign nekos-api-anime-images
```

If you installed `Zeron.app` in a different folder, adjust the path.

**Linux (terminal)**

```sh
zeron plugin sign nekos-api-anime-images
```

If `zeron` is outside your `PATH`, use the full path to the executable installed by the desktop installer.

For a signed package that you can use in the **Install…** dialog, see `zeron plugin export --help`.

## Showcase

https://github.com/user-attachments/assets/60b6c285-b92c-43f2-b02c-90398676735f

This 24-second demo shows the previous sidebar layout and uses the plugin's native UI components, Nekos API images, and an original instrumental.

## Picture-in-picture

- Select **Open PiP** from the **Nekos Anime Images** page or gallery. You can also select **View → Open Nekos Picture-in-Picture**. The player starts in the lower-right corner of the Zeron window and stays open when you switch chats.
- Drag the title to move the player. Drag the resize handle in the controls to change its size. Select **Close PiP** to close it. You can continue to use Zeron around the player.
- The compact controls let you refresh, move between images, start or pause the slideshow, and open settings. The gallery and PiP share the current selection. PiP shows one image at a time.
- Turn **Slideshow** on to play images in order and repeat. Set **Change image every** to 1–3600 seconds. The timer starts when the image loads. A request that stalls for 15 seconds is skipped during playback. The last permitted image stays visible as the next one loads. Playback pauses when all image views are hidden.
- **View → Nekos Image Controls** and **View → Open Nekos Anime Images** still open the controls or gallery in a chat's panel. Use **Ctrl+Shift+G** on Windows and Linux or **Cmd+Shift+G** on macOS to open the gallery from a chat.

## Gallery and settings

Open **Gallery** for a responsive image grid or Single Image mode. Use **Refresh**, **Next Image**, **Load More**, **Download**, **Copy URL**, and **Open Original**. Artist, tags, rating, and source appear when supplied by the API.

**Filters & settings** opens Zeron's native plugin Settings page. Changes take effect at once. It provides content toggles, included and excluded tags, an optional artist, request size (1–100), duplicate avoidance, Gallery/Single mode, auto-refresh and interval, auto-load more, metadata, aspect ratio, download format, and slideshow defaults.

- **Enable NSFW** defaults to OFF. **Safe images** defaults to ON. All other ratings default to OFF. Turning the master switch off blocks `suggestive`, `borderline`, and `explicit`, even if their individual toggles remain selected. With no effective ratings selected, the plugin sends no request.
- **Hide NSFW previews** and **Blur NSFW thumbnails** default to ON. Hide takes priority: protected images are not sent to the renderer until **Reveal image** is selected in Zeron. If Hide is off and Blur is on, protected previews are blurred.
- A rating change clears old results and revealed states before loading a new batch. This also works while the PiP player is closed.
- **Nekos API ratings may be inaccurate.** A small tag block list skips some records that appear incorrectly marked Safe. It cannot detect all bad ratings.
- Auto-refresh runs while the view is mounted and Zeron is visible. Auto-load more applies to the gallery grid. The shared batch holds at most 300 results. Duplicate history is bounded to 1,000 image records.
- The saved setting IDs `floating_autoplay` and `floating_interval` are retained for upgrades. They control the PiP slideshow defaults.

## Image formats and downloads

Zgx renders WebP directly. It also renders other formats supported by Zeron's image decoder. There is no PNG-only assumption or conversion for display.

**Original** preserves the downloaded bytes. **PNG** or **JPEG** also preserves bytes when the source already has that format. Otherwise, Zeron's existing web view performs canvas conversion, then the native Save dialog chooses the destination. JPEG uses white behind transparent pixels. Conversion of animation saves a still frame.

The exporter has no external scripts. It accepts only the listed Nekos image hosts, rejects redirects, uses a 15-second fetch timeout, limits downloads to 40 MiB, and limits conversion to 40 megapixels. The plugin checks that the selected image is still permitted before it starts the download and again after the Save dialog. Changing the selected image during a save cancels that save.

Export depends on the web view already supported by the Zeron build and the image host's cross-origin policy. If export cannot run, the plugin reports the error and offers **Open Original**. It does not install or launch another program.

## API

Requests use `GET https://api.nekosapi.com/v4/images/random` with URL-encoded `limit`, `rating`, and optional `tags` and `artist`. The checked v4 reference does not document `without_tags`; excluded tags are filtered locally. A batch can therefore contain fewer images than requested.

The plugin handles invalid responses, empty results, network errors, a 15-second timeout, and HTTP 429 with `Retry-After`. NSFW tests use synthetic metadata, not explicit image fixtures.

[Zeron plugin guide](https://github.com/zeronsh/zeron/blob/v0.3.4/apps/zgx/docs/plugins.md) · [Nekos API docs](https://nekosapi.com/docs) · [Checked v4 reference](https://git.moan.dev/nekos-api/nekos-api/src/commit/2c4ee129e1436f37e49a5dfdf957cca8e0f6b62b/README.md)

## Changed source files

| Files | Purpose |
| --- | --- |
| `zeron-plugin.json`, `init.luau` | Page and tab registration, commands, permissions, settings |
| `slideshow.luau`, `image_pip.luau`, `image_surface.luau` | Shared playback, floating player, bounded image loading |
| `player_panel.luau`, `workspace.luau` | Native Settings controls and view tabs |
| `api.luau`, `gallery_state.luau`, `gallery.luau` | Filters, requests, metadata, gallery, and selected-batch transfer |
| `download.luau`, `export_page.luau` | Built-in web view export and native Save dialog |
| `tests/`, `docs/screenshots/native-panel.png`, `README.md` | Tests, preview, and setup |

Removed: `python.luau`, `floating.luau`, `floating_worker.luau`, `download_worker.luau`, and the Python tests. `zeron.luau` remains the unmodified upstream SDK; generic SDK command helpers are not called or granted. No Zeron host files were changed.

## Validation

The 2.2.0 checks cover Luau compilation, API filters and requests, export logic, and PiP geometry. The desktop UI suite includes a test for closing PiP and using the workspace while it is open.

The following results are from 2.1.0:

- Luau compilation and zgx lint: **0 errors, 0 warnings** in plugin source.
- API rating gates, tags, limits, query encoding, metadata, empty/invalid payloads, and cooldown parsing.
- Thirteen native UI regression tests cover the toolbar, live settings, all ratings, visibility, saved controls, batch size one, image timeout, API timeout, empty results, and rate limits. See `docs/SETTINGS-CHECKS.md` for the setting-by-setting report.
- Real WebP bytes loaded through a zgx host fetcher and native decoder. Playback looped through cached images and paused while hidden. A real WebP remained visible when the next request was held pending; the timeout recovered playback. Changing aspect ratio changed the native image geometry from Contain to Cover.
- Real plugin sandbox: entry loading, sidebar controls, page/session panel contexts, tab commands. The sandbox had no program-run capability.
- Upstream manifest validation and settings-store tests: defaults, immediate changes, and reload persistence.
- Export logic with a fake browser: original WebP bytes, no needless conversion, PNG/JPEG conversion flow, two-step download commit, HTTP errors, host and size restrictions. Canvas and browser download services were mocked in this test.

Not verified: the packaged Zeron app on Windows/macOS, the platform Save dialog, and real canvas output through the platform web view. The environment blocked the browser test process. The full Zeron build also remains blocked by an external ONNX Runtime download. These limits do not affect the passed Luau and native panel tests. The standalone UI harness emits existing upstream theme-token warnings; its metadata-only image fixtures are tested separately with the real decoder harness.

Development checks, from the plugin folder:

```sh
luau-compile --null *.luau tests/*.luau
zgx lint .
luau tests/api.test.luau
luau tests/pip.test.luau
node tests/export.test.cjs
bash tests/run-ui.sh /path/to/zeron/apps/zgx/ui /path/to/zgx
```

These are development tools only. Users need only Zeron. The screenshot below shows the 2.1.0 layout in the native zgx showcase with reviewed SFW images fetched from Nekos API. It is not a capture of the packaged Zeron app; Zeron supplies the surrounding sidebar, tab header, and divider.


![Native image panel and controls](docs/screenshots/native-panel.png)
