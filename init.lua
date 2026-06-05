-- ==========================================
-- Auto Video Downloader Pro
-- ==========================================

local DOWNLOAD_DIR = os.getenv("HOME") .. "/Downloads/AutoDownloads"
local HISTORY_FILE = os.getenv("HOME") .. "/Library/Application Support/Hammerspoon/video_history.txt"

local YTDLP = "/opt/homebrew/bin/yt-dlp"
local NODE = "/opt/homebrew/bin/node"

local COUNTDOWN_SECONDS = 5

local ALLOWED_DOMAINS = {
    "youtube.com",
    "youtu.be",
    "instagram.com",
    "facebook.com",
    "fb.watch",
    "x.com",
    "twitter.com",
    "tiktok.com",
    "vimeo.com",
    "pinterest.com"
}

os.execute('mkdir -p "' .. DOWNLOAD_DIR .. '"')
os.execute('mkdir -p "' .. os.getenv("HOME") .. '/Library/Application Support/Hammerspoon"')

local menubar = hs.menubar.new()

local queue = {}
local history = {}
local pendingBatch = nil
local pendingTimer = nil
local isDownloading = false
local monitoringPaused = false
local audioOnlyMode = false
local currentTask = nil

local function notify(title, text)
    hs.notify.new({
        title = title,
        informativeText = text
    }):send()
end

local function notifyDetected(urls)
    hs.notify.new(
        function(n)
            if n:activationType() == hs.notify.activationTypes.actionButtonClicked then
                if pendingTimer then
                    pendingTimer:stop()
                    pendingTimer = nil
                end
                pendingBatch = nil
                updateMenu()
            end
        end,
        {
            title = "Videos Detected",
            informativeText = #urls .. " download(s) starting in " .. COUNTDOWN_SECONDS .. " seconds" .. (audioOnlyMode and " [MP3]" or ""),
            actionButtonTitle = "Cancel",
            hasActionButton = true,
            alwaysPresent = true,
        }
    ):send()
end

local function notifyComplete(filePath, downloadAudioOnly)
    local name = filePath:match("([^/]+)$") or (downloadAudioOnly and "Audio (MP3)" or "Video")
    hs.notify.new(
        function(n)
            local t = n:activationType()
            if t == hs.notify.activationTypes.actionButtonClicked then
                hs.execute('open "' .. DOWNLOAD_DIR .. '"')
            elseif t == hs.notify.activationTypes.contentsClicked
                or t == hs.notify.activationTypes.additionalActionClicked then
                if filePath then
                    hs.execute('open "' .. filePath .. '"')
                end
            end
        end,
        {
            title = "Download Complete",
            informativeText = name,
            actionButtonTitle = "Open Folder",
            otherButtonTitle = "Open",
            hasActionButton = true,
            alwaysPresent = true,
        }
    ):send()
end

local function loadHistory()
    local file = io.open(HISTORY_FILE, "r")

    if not file then
        return
    end

    for line in file:lines() do
        history[line] = true
    end

    file:close()
end

local function saveHistory(url)
    local file = io.open(HISTORY_FILE, "a")

    if file then
        file:write(url .. "\n")
        file:close()
    end

    history[url] = true
end

local function cleanupTempFiles()
    os.execute('find "' .. DOWNLOAD_DIR .. '" \\( -name "*.part" -o -name "*.ytdl" \\) -mtime +1 -delete')
end

local function updateMenu()

    local count = #queue

    if pendingBatch then
        count = count + #pendingBatch
    end

    if isDownloading then
        count = count + 1
    end

    menubar:setTitle("⬇︎ " .. count)

    local menu = {}

    if pendingBatch then
        table.insert(menu, {
            title = "Pending Batch (" .. #pendingBatch .. ")"
        })

        table.insert(menu, {
            title = "Start Now",
            fn = function()

                if pendingTimer then
                    pendingTimer:stop()
                    pendingTimer = nil
                end

                for _, url in ipairs(pendingBatch) do
                    table.insert(queue, url)
                end

                pendingBatch = nil

                updateMenu()
            end
        })

        table.insert(menu, {
            title = "Cancel Pending Batch",
            fn = function()

                if pendingTimer then
                    pendingTimer:stop()
                    pendingTimer = nil
                end

                pendingBatch = nil

                updateMenu()
            end
        })

        table.insert(menu, { title = "-" })
    end

    table.insert(menu, {
        title = monitoringPaused and "Resume Monitoring" or "Pause Monitoring",
        fn = function()
            monitoringPaused = not monitoringPaused
            updateMenu()
        end
    })

    table.insert(menu, {
        title = audioOnlyMode and "Audio" or "Video",
        fn = function()
            audioOnlyMode = not audioOnlyMode
            updateMenu()
        end
    })

    table.insert(menu, { title = "-" })

    table.insert(menu, {
        title = "Stop Download",
        fn = function()
            if currentTask then
                currentTask:terminate()
                currentTask = nil
            end
            queue = {}
            if pendingTimer then
                pendingTimer:stop()
                pendingTimer = nil
            end
            pendingBatch = nil
            isDownloading = false
            notify("Download Stopped", "Queue cleared")
            updateMenu()
        end
    })

    table.insert(menu, {
        title = "Open Download Folder",
        fn = function()
            hs.execute('open "' .. DOWNLOAD_DIR .. '"')
        end
    })

    menubar:setMenu(menu)

end

local function isAllowed(url)

    local lower = url:lower()

    for _, domain in ipairs(ALLOWED_DOMAINS) do
        if lower:find(domain, 1, true) then
            return true
        end
    end

    return false
end

local function processQueue()

    if isDownloading then
        return
    end

    if #queue == 0 then
        updateMenu()
        return
    end

    local url = table.remove(queue, 1)
    local downloadAudioOnly = audioOnlyMode

    isDownloading = true

    updateMenu()

    notify("Download Started", (downloadAudioOnly and "[MP3] " or "[MP4] ") .. url)

    local command

    if downloadAudioOnly then
        command = string.format([[
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

%s \
--js-runtimes node:%s \
--ffmpeg-location /opt/homebrew/bin \
-f "bestaudio/best" \
--extract-audio \
--audio-format mp3 \
--audio-quality 0 \
--restrict-filenames \
--no-playlist \
-o "%s/%%(title)s.%%(ext)s" \
"%s"
]],
            YTDLP,
            NODE,
            DOWNLOAD_DIR,
            url
        )
    else
        command = string.format([[
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

%s \
--js-runtimes node:%s \
--ffmpeg-location /opt/homebrew/bin \
-f "bestvideo+bestaudio/best" \
--merge-output-format mp4 \
--recode-video mp4 \
--restrict-filenames \
--no-playlist \
-o "%s/%%(title)s.%%(ext)s" \
"%s"
]],
            YTDLP,
            NODE,
            DOWNLOAD_DIR,
            url
        )
    end

    currentTask = hs.task.new(
        "/bin/bash",
        function(exitCode, stdout, stderr)

            print("================================")
            print("URL:", url)
            print("Mode:", downloadAudioOnly and "Audio Only (MP3)" or "Video (MP4)")
            print("Exit:", exitCode)

            if stdout and stdout ~= "" then
                print(stdout)
            end

            if stderr and stderr ~= "" then
                print(stderr)
            end

            print("================================")

            currentTask = nil
            isDownloading = false

            if exitCode == 0 then
                saveHistory(url)

                local filePath =
                    stdout:match("%[ExtractAudio%] Destination: ([^\n]+)")
                    or stdout:match("%[Merger%] Merging formats into \"([^\"]+)\"")
                    or stdout:match("%[download%] Destination: ([^\n]+)")

                if not filePath then
                    filePath = DOWNLOAD_DIR .. "/" .. (downloadAudioOnly and "audio.mp3" or "video.mp4")
                end

                filePath = filePath:gsub("^%s+", ""):gsub("%s+$", "")

                notifyComplete(filePath, downloadAudioOnly)
            else
                notify(
                    "Download Failed",
                    "Check Hammerspoon Console"
                )
            end

            updateMenu()

            processQueue()

        end,
        { "-c", command }
    ):start()
end

loadHistory()
cleanupTempFiles()

local clipboardWatcher = hs.pasteboard.watcher.new(function()

    if monitoringPaused then
        return
    end

    local clipboard = hs.pasteboard.getContents()

    if not clipboard then
        return
    end

    local urls = {}

    local seen = {}

    for url in clipboard:gmatch("https?://[%w%-%._~:/%?#%[%]@!$&%'%(%)%*%+,;=]+") do

        if isAllowed(url)
            and not history[url]
            and not seen[url]
        then
            seen[url] = true
            table.insert(urls, url)
        end

    end

    if #urls == 0 then
        return
    end

    if pendingTimer then
        pendingTimer:stop()
    end

    pendingBatch = urls

    notifyDetected(urls)

    updateMenu()

    pendingTimer = hs.timer.doAfter(
        COUNTDOWN_SECONDS,
        function()

            if not pendingBatch then
                return
            end

            for _, url in ipairs(pendingBatch) do
                table.insert(queue, url)
            end

            pendingBatch = nil
            pendingTimer = nil

            updateMenu()
            processQueue()

        end
    )

end)

clipboardWatcher:start()

updateMenu()

notify(
    "Auto Downloader",
    "Clipboard monitor started"
)