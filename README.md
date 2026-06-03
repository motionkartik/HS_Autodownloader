# ⬇︎ Auto Video Downloader

A [Hammerspoon](https://www.hammerspoon.org/) script that watches your clipboard and automatically downloads videos from social platforms using `yt-dlp`.

Copy a link. That's it.

---

## How it works

1. Copy any video URL from a supported platform
2. A 5-second countdown starts — giving you time to cancel
3. The video downloads to `~/Downloads/AutoDownloads` in MP4 format
4. A menubar icon (`⬇︎`) shows the current queue count

---

## Supported platforms

YouTube · Instagram · Facebook · X (Twitter) · TikTok · Vimeo · Pinterest

---

## Requirements

- [Hammerspoon](https://www.hammerspoon.org/)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — `brew install yt-dlp`
- [ffmpeg](https://ffmpeg.org/) — `brew install ffmpeg`
- [Node.js](https://nodejs.org/) — `brew install node`

---

## Install

```bash
# Install dependencies
brew install yt-dlp ffmpeg node

# Copy script to Hammerspoon config
cp init.lua ~/.hammerspoon/init.lua

# Reload Hammerspoon config
# Hammerspoon menu → Reload Config
```

> If you already have an `init.lua`, append or merge the contents instead.

---

## Menubar controls

| Option | Description |
|---|---|
| **Start Now** | Skip the countdown and download immediately |
| **Cancel Pending Batch** | Dismiss the current detected URLs |
| **Pause / Resume Monitoring** | Temporarily stop watching the clipboard |
| **Show Queue** | See how many downloads are waiting |
| **Clear Queue** | Remove all pending downloads |
| **Clear History** | Re-enable downloading of previously downloaded URLs |
| **Open Download Folder** | Opens `~/Downloads/AutoDownloads` in Finder |

---

## Configuration

Edit the top of `init.lua` to customize:

```lua
local DOWNLOAD_DIR      = os.getenv("HOME") .. "/Downloads/AutoDownloads"
local COUNTDOWN_SECONDS = 5
local YTDLP             = "/opt/homebrew/bin/yt-dlp"
local NODE              = "/opt/homebrew/bin/node"
```

---

## Notes

- Already-downloaded URLs are remembered across sessions and won't be re-queued
- Partial/incomplete download files (`.part`, `.ytdl`) older than 24 hours are cleaned up on startup
- Downloads are queued and processed one at a time
- Check the Hammerspoon Console (`⌘ + Shift + C` in Hammerspoon) if a download fails
