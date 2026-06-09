# 📥 Auto Video Downloader Pro

> A Hammerspoon script that watches your clipboard and automatically downloads videos the moment you copy a link — no terminal, no commands, no friction.

![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)
![Hammerspoon](https://img.shields.io/badge/Hammerspoon-required-orange?style=flat)
![yt-dlp](https://img.shields.io/badge/yt--dlp-required-blue?style=flat)
![License](https://img.shields.io/badge/license-MIT-green?style=flat)

---

## How it works

Copy any supported video URL → get a macOS notification with a 5-second cancel window → download starts automatically in the background. Files land in `~/Downloads/AutoDownloads`.

---

## Features

- **Clipboard-triggered** — detects video URLs the moment you copy them
- **5-second cancel window** — actionable notification lets you abort before it starts
- **MP4 + MP3 modes** — toggle between video and audio-only from the menubar
- **Parallel downloads** — up to 2 concurrent downloads, 4 fragments each
- **Live menubar status** — shows queue depth and active slots (e.g. `⬇︎ 3 [2/2]`)
- **Duplicate prevention** — persists a 500-URL history so nothing gets re-downloaded
- **Watchdog timeout** — kills stalled downloads after 10 minutes automatically
- **Auto cleanup** — removes leftover `.part` and `.ytdl` files daily
- **Click-to-open notifications** — tap the completion alert to open the file or folder

---

## Supported Sites

| Site | URLs matched |
|------|-------------|
| YouTube | `youtube.com`, `youtu.be` |
| Instagram | `instagram.com` |
| Facebook | `facebook.com`, `fb.watch` |
| Twitter / X | `x.com`, `twitter.com` |
| TikTok | `tiktok.com` |
| Vimeo | `vimeo.com` |
| Pinterest | `pinterest.com` |

---

## Requirements

Install all dependencies via [Homebrew](https://brew.sh):

```bash
brew install hammerspoon yt-dlp ffmpeg node
```

---

## Installation

1. Clone or download this repo
2. Copy the script into your Hammerspoon config:

```bash
cat auto_video_downloader.lua >> ~/.hammerspoon/init.lua
```

Or if you prefer a separate file:

```bash
cp auto_video_downloader.lua ~/.hammerspoon/auto_video_downloader.lua
```

Then add this line to your `~/.hammerspoon/init.lua`:

```lua
require("auto_video_downloader")
```

3. Reload Hammerspoon: click the menubar icon → **Reload Config**, or press your reload hotkey.

---

## Usage

| Action | How |
|--------|-----|
| Start/stop monitoring | Click menubar icon → toggle **Monitoring** |
| Switch MP4 ↔ MP3 | Click menubar icon → toggle **Video / Audio** |
| Cancel a pending batch | Click **Cancel** on the detection notification, or via the menubar |
| Start a pending batch immediately | Menubar → **Start Now** |
| Stop all downloads | Menubar → **Stop All Downloads** |
| Open download folder | Menubar → **Open Download Folder** |

---

## Configuration

All tunable options are at the top of the script:

```lua
local COUNTDOWN_SECONDS  = 5     -- seconds before auto-starting a detected batch
local MAX_HISTORY        = 500   -- number of URLs kept in duplicate history
local DOWNLOAD_TIMEOUT   = 600   -- seconds before a stalled download is killed
local MAX_CONCURRENT     = 2     -- maximum parallel downloads
local CONCURRENT_FRAGS   = 4     -- yt-dlp concurrent fragments per download
```

To add more supported sites, append to `ALLOWED_DOMAINS`:

```lua
local ALLOWED_DOMAINS = {
    "youtube.com", "youtu.be",
    "newsite.com",   -- add your domain here
    ...
}
```

---

## Output Format

| Mode | Format | Encoding |
|------|--------|----------|
| Video (default) | `.mp4` | H.264 (libx264), CRF 23, fast preset |
| Audio only | `.mp3` | Best quality (VBR 0) |

Files are saved to `~/Downloads/AutoDownloads/` with sanitized filenames based on the video title.

---

## File Structure

```
~/.hammerspoon/
├── init.lua
├── auto_video_downloader.lua
└── video_history.txt          # auto-created, tracks downloaded URLs

~/Downloads/
└── AutoDownloads/             # auto-created, all downloaded files
```

---

## Troubleshooting

**Nothing happens when I copy a URL**
- Make sure monitoring is enabled (menubar should show ✓ Monitoring)
- Check that the domain is in `ALLOWED_DOMAINS`
- Open the Hammerspoon Console (menubar → Console) and look for errors

**Download fails immediately**
- Run `yt-dlp <url>` manually in Terminal to see the raw error
- Make sure yt-dlp is up to date: `brew upgrade yt-dlp`

**Wrong binary paths**
- The script assumes Homebrew installs to `/opt/homebrew/bin` (Apple Silicon default)
- On Intel Macs, change paths to `/usr/local/bin`

---

## Credits

Built by [@motionkartik](https://github.com/motionkartik) using:
- [Hammerspoon](https://www.hammerspoon.org/) — macOS automation framework
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — video downloader
- [ffmpeg](https://ffmpeg.org/) — media processing

---

## License

MIT — do whatever you want with it.