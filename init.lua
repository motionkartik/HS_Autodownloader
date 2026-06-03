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

local function notify(title, text)
    hs.notify.new({
        title = title,
        informativeText = text
    }):send()
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
        title = "Open Download Folder",
        fn = function()
            hs.execute('open "' .. DOWNLOAD_DIR .. '"')
        end
    })

    table.insert(menu, {
        title = "Show Queue",
        fn = function()

            if #queue == 0 then
                notify("Queue", "Queue is empty")
                return
            end

            notify("Queue", #queue .. " item(s) waiting")
        end
    })

    table.insert(menu, {
        title = "Clear Queue",
        fn = function()
            queue = {}
            updateMenu()
        end
    })

    table.insert(menu, {
        title = "Clear History",
        fn = function()

            history = {}

            local file = io.open(HISTORY_FILE, "w")

            if file then
                file:close()
            end

            notify("History", "History cleared")
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

    isDownloading = true

    updateMenu()

    notify("Download Started", url)

    local command = string.format([[
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

    hs.task.new(
        "/bin/bash",
        function(exitCode, stdout, stderr)

            print("================================")
            print("URL:", url)
            print("Exit:", exitCode)

            if stdout and stdout ~= "" then
                print(stdout)
            end

            if stderr and stderr ~= "" then
                print(stderr)
            end

            print("================================")

            isDownloading = false

            if exitCode == 0 then
                saveHistory(url)

                local title =
                    stdout:match("%[download%] Destination: ([^\n]+)")
                    or "Video"

                notify(
                    "Download Complete",
                    title
                )
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

    notify(
        "Videos Detected",
        #urls .. " download(s) starting in " .. COUNTDOWN_SECONDS .. " seconds"
    )

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