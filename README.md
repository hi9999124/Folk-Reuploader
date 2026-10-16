<div align="center">

# Folk Reuploader

A modern fork of [Asset-Reuploader](https://github.com/bacfr/Asset-Reuploader) — Roblox asset reupload host with a live terminal, auto Studio link, and a terminal-only mode.

</div>

Folk talks to a Roblox Studio plugin over localhost. Use it when you need copies of assets on an account that can actually publish them (your own games, groups you edit, unpublished inventory you already own).

### What Folk adds

- **Live terminal** — amber dashboard, pulse bars, signed-in account, Studio link status
- **Auto Studio connection** — plugin scans ports, handshakes `/v1/studio/hello`, reconnects if the host restarts
- **Autofill** — place id, creator id, group flag, port, API key, and cookie from files/env/last Studio session
- **Modern HTTP** — `/v1/health`, `/v1/events`, `/v1/reupload`, bound to `127.0.0.1` by default
- **Terminal-only** — `FolkReuploader --cli` with no plugin

### Supported assets

- Animations
- Audio
- Meshes

### Host (plugin + dashboard)

1. Run `FolkReuploader` (or `go run ./cmd/assetreuploader`).
2. Paste `.ROBLOSECURITY` once (saved to `cookie.txt`). Open Cloud API key is saved to `api-key.txt`.
3. Install the plugin (`rojo build plugin`) and open a **published** place in Studio.
4. Folk auto-connects. Hit Reupload on Animation / Sound / Mesh.

Environment autofill: `FOLK_ROBLOSECURITY` / `ROBLOSECURITY`, `FOLK_API_KEY` / `ROBLOX_API_KEY`.

### Terminal only

```text
FolkReuploader --cli
FolkReuploader --cli --type Animation --ids 1,2,3 --place 123 --creator 456
FolkReuploader --cli --type Mesh --ids 9 --place 123 --creator 456 --group --export
```

If you already connected the plugin once, `--place` and `--creator` fill from `config.ini`.

### Headless host

```text
FolkReuploader --no-tui --port 38073
```

### Build

```text
go build -ldflags="-X main.CompatiblePluginVersion=2.0.0" -o FolkReuploader.exe ./cmd/assetreuploader
rojo build plugin --output FolkReuploader2.0.0.rbxm
```

## License

Forked from Asset-Reuploader (kartFr / bacfr), GPL-3.0. Folk Reuploader is a modified version of that work.
