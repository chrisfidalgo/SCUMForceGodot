# Web build & Netlify hosting

How the game gets from this repo to a link you can send a playtester.

## The short version

Pushing to `main` saves work; it does **not** change the live site. The site
only updates when you publish:

1. **Publish** = push `main` to the `release` branch:
   `git push origin main:release` (or tell Claude "publish to web").
2. GitHub Actions builds the web version (a few minutes; slower the first time
   while it downloads Godot) and puts the finished files on **`web-build`**.
3. Netlify watches `web-build` and redeploys automatically.

You can also publish from GitHub: **Actions → Web build → Run workflow**.
You never build by hand and never commit build output. The game boots to the
temporary launcher: **Play the run** or **Combat gym**.

## One-time Netlify setup

1. In Netlify: **Add new site → Import an existing project → GitHub** and pick
   `chrisfidalgo/SCUMForceGodot`.
2. **Branch to deploy:** `web-build` (not `main`).
3. **Build command:** leave empty. **Publish directory:** leave empty (or `.`).
4. Deploy. The `web-build` branch only exists after the first GitHub Actions
   run has finished — check the repo's **Actions** tab if it's missing.

No tokens or secrets are needed: Actions publishes using the repo's own
permissions, and Netlify just reads a branch.

## The pieces, if something breaks

| File | What it does |
|---|---|
| `export_presets.cfg` | The "Web" export preset. Single-threaded, so it runs in any modern browser without special server setup. |
| `.github/workflows/web-build.yml` | Runs on a push to `release` (or by hand). Downloads Godot 4.6.3 + the web templates (cached after the first run), exports, publishes to `web-build`. |
| `netlify.toml` | Copied into every build. Sets headers so browsers never mix an old engine file with new game data. |

**Changing the Godot version:** edit `GODOT_VERSION` at the top of the workflow
to match the editor you use. A mismatch fails the export.

**Building locally instead** (e.g. to drag-and-drop onto Netlify): in the editor,
Project → Export → Web → Export Project, into `build/web/`. Or from a terminal:

```
Godot_v4.6.3-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html
```

Opening `index.html` straight from disk does not work — browsers block it. Serve
the folder (Netlify, or the editor's "Run in Browser" button top-right).

## Known limits in the browser

- **F-keys belong to the browser.** F5 reloads the page and F6 jumps to the
  address bar, so the gym's debug tray (F1–F6) is effectively desktop-only.
  Movement, attacks, Enter and the `` ` `` tuning panel all work.
- **Reload the page to get back to the launcher.**
- Click the game once if keys don't respond — the page needs focus.
- Phones and tablets aren't a target: there's no touch input.
