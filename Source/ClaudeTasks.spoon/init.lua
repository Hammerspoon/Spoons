-- ClaudeTasks.spoon
-- Hammerspoon Spoon for Claude Code Task viewer
-- Toggle floating task viewer with opt+. hotkey

local obj = {}

-- Spoon Metadata
obj.name = "ClaudeTasks"
obj.version = "1.1.0"
obj.author = "jongwony <lastone9182@gmail.com>"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/jongwony/ClaudeTasks.spoon"
obj.spoonPath = hs.spoons.scriptPath()

-- ============================================================================
-- Configuration
-- ============================================================================

obj.config = {
    -- UI
    width = 420,
    height = 580,
    margin = 20,
    refreshDebounce = 0.2,
    debugMode = false,

    -- Session
    taskListId = os.getenv("CLAUDE_CODE_TASK_LIST_ID"),

    -- External Tools (nil = auto-discover)
    claudePath = nil,
    terminalApp = nil,
    shell = nil,
}

-- ============================================================================
-- Helper Functions for Discovery
-- ============================================================================

local function discoverClaudePath()
    if obj.config.claudePath then return obj.config.claudePath end
    -- GUI apps have limited PATH, so search common install locations directly
    local candidates = {
        os.getenv("HOME") .. "/.local/bin/claude",
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
    }
    for _, path in ipairs(candidates) do
        if hs.fs.attributes(path) then return path end
    end
    return nil
end

local function discoverTerminalApp()
    if obj.config.terminalApp then return obj.config.terminalApp end
    local candidates = {
        "/Applications/Ghostty.app/Contents/MacOS/ghostty",
        "/Applications/iTerm.app/Contents/MacOS/iTerm2",
        "/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"
    }
    for _, path in ipairs(candidates) do
        if hs.fs.attributes(path) then return path end
    end
    return nil
end

local function getShell()
    return obj.config.shell or os.getenv("SHELL") or "/bin/zsh"
end

-- ============================================================================
-- Persistent State Management
-- ============================================================================

obj.state = {
    currentTaskListId = nil,
    configPath = nil  -- Set in init()
}

-- ============================================================================
-- Internal State
-- ============================================================================

local webview = nil
local pathWatcher = nil
local refreshTimer = nil
local isVisible = false
local usercontent = nil  -- JS-Lua bridge
local cwdCache = {}  -- sessionId -> cwd path cache

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function log(message)
    if obj.config.debugMode then
        print("[ClaudeTasks] " .. message)
    end
end

local function getTasksDir()
    return os.getenv("HOME") .. "/.claude/tasks"
end

-- JSON parsing (simple implementation for task files)
local function parseJSON(str)
    -- Use hs.json
    local success, result = pcall(hs.json.decode, str)
    if success then
        return result
    end
    return nil
end

-- List all items in a directory
local function listDir(path)
    local items = {}
    local handle = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    if handle then
        for line in handle:lines() do
            table.insert(items, line)
        end
        handle:close()
    end
    return items
end

-- Check if a file exists
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Read file contents
local function readFile(path)
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content
    end
    return nil
end

-- ============================================================================
-- State Management Functions
-- ============================================================================

local function loadState()
    local f = io.open(obj.state.configPath, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local data = parseJSON(content)
        if data then
            obj.state.currentTaskListId = data.currentTaskListId
            obj.config.taskListId = data.currentTaskListId
            log("State loaded: " .. (data.currentTaskListId or "nil"))
        end
    end
end

local function saveState()
    local data = hs.json.encode({
        currentTaskListId = obj.state.currentTaskListId
    })
    local f = io.open(obj.state.configPath, "w")
    if f then
        f:write(data)
        f:close()
        log("State saved: " .. (obj.state.currentTaskListId or "nil"))
    end
end

local function listSessionDirs()
    local tasksDir = getTasksDir()
    if not fileExists(tasksDir) then
        return {}
    end

    local allDirs = listDir(tasksDir)
    local nonEmptySessions = {}

    for _, sessionId in ipairs(allDirs) do
        local sessionDir = tasksDir .. "/" .. sessionId
        local files = listDir(sessionDir)
        -- Include if there's at least one .json file
        for _, filename in ipairs(files) do
            if filename:match("%.json$") then
                table.insert(nonEmptySessions, sessionId)
                break
            end
        end
    end

    return nonEmptySessions
end

-- ============================================================================
-- CWD Extraction Functions
-- ============================================================================

local function decodeCwdPath(encodedDir)
    -- Encoding: / → -, /. → --
    local path = encodedDir:gsub("%-%-", "\001")  -- -- → temp marker
    path = path:gsub("^%-", "/")                   -- leading - → /
    path = path:gsub("%-", "/")                    -- remaining - → /
    path = path:gsub("\001", "/.")                 -- temp marker → /.
    return path
end

local function getCwdFromSessionId(sessionId)
    if cwdCache[sessionId] then return cwdCache[sessionId] end

    local projectsDir = os.getenv("HOME") .. "/.claude/projects"
    if not fileExists(projectsDir) then return nil end

    for _, encodedDir in ipairs(listDir(projectsDir)) do
        local sessionFile = projectsDir .. "/" .. encodedDir .. "/" .. sessionId .. ".jsonl"
        if fileExists(sessionFile) then
            local cwd = decodeCwdPath(encodedDir)
            cwdCache[sessionId] = cwd
            return cwd
        end
    end
    return nil
end

-- ============================================================================
-- Task Loading
-- ============================================================================

local function loadAllTasks()
    local tasks = {}
    local tasksDir = getTasksDir()

    if not fileExists(tasksDir) then
        log("Tasks directory does not exist: " .. tasksDir)
        return tasks
    end

    -- Load only specified session if taskListId is set
    local sessions = {}
    if obj.config.taskListId then
        sessions = {obj.config.taskListId}
    else
        sessions = listDir(tasksDir)
    end

    for _, sessionId in ipairs(sessions) do
        local sessionDir = tasksDir .. "/" .. sessionId
        local files = listDir(sessionDir)

        for _, filename in ipairs(files) do
            if filename:match("%.json$") then
                local filepath = sessionDir .. "/" .. filename
                local content = readFile(filepath)

                if content then
                    local task = parseJSON(content)
                    if task then
                        task._sessionId = sessionId
                        task._filepath = filepath
                        task._cwd = getCwdFromSessionId(sessionId)
                        table.insert(tasks, task)
                    end
                end
            end
        end
    end

    -- Sort by ID (numeric first, then string)
    table.sort(tasks, function(a, b)
        local aNum = tonumber(a.id)
        local bNum = tonumber(b.id)
        if aNum and bNum then
            return aNum < bNum
        end
        return tostring(a.id) < tostring(b.id)
    end)

    log("Loaded " .. #tasks .. " tasks")
    return tasks
end

-- ============================================================================
-- HTML Rendering
-- ============================================================================

local function escapeHtml(str)
    if not str then return "" end
    return str:gsub("&", "&amp;")
              :gsub("<", "&lt;")
              :gsub(">", "&gt;")
              :gsub('"', "&quot;")
              :gsub("'", "&#39;")
end

local function getStatusColor(status)
    if status == "completed" then
        return "#22c55e"  -- green
    elseif status == "in_progress" then
        return "#f59e0b"  -- amber
    else
        return "#6b7280"  -- gray (pending)
    end
end

local function getStatusIcon(status)
    if status == "completed" then
        return "✓"
    elseif status == "in_progress" then
        return "◐"
    else
        return "○"
    end
end

local function generateHTML(tasks)
    local pendingTasks = {}
    local inProgressTasks = {}
    local completedTasks = {}

    for _, task in ipairs(tasks) do
        if task.status == "completed" then
            table.insert(completedTasks, task)
        elseif task.status == "in_progress" then
            table.insert(inProgressTasks, task)
        else
            table.insert(pendingTasks, task)
        end
    end

    -- Generate session datalist options
    local sessions = listSessionDirs()
    local sessionOptions = ''
    for _, sessionId in ipairs(sessions) do
        sessionOptions = sessionOptions .. string.format(
            '                    <option value="%s"></option>\n',
            escapeHtml(sessionId)
        )
    end
    local currentSessionValue = obj.state.currentTaskListId or ''

    local html = [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
            font-size: 13px;
            line-height: 1.4;
            background: rgba(30, 30, 30, 0.95);
            color: #e5e5e5;
            padding: 16px;
            overflow-y: auto;
            -webkit-font-smoothing: antialiased;
        }
        .header {
            margin-bottom: 12px;
            padding-bottom: 12px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        .header-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        .title {
            font-size: 15px;
            font-weight: 600;
            color: #fff;
        }
        .header-actions {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .launch-btn {
            background: #22c55e;
            color: #fff;
            border: none;
            width: 32px;
            height: 32px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
        }
        .launch-btn:hover {
            background: #16a34a;
        }
        .launch-btn:disabled {
            background: #4b5563;
            cursor: not-allowed;
        }
        .count {
            font-size: 12px;
            color: #888;
        }
        .session-input {
            background: rgba(255, 255, 255, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            color: #e5e5e5;
            padding: 6px 10px;
            border-radius: 4px;
            font-size: 12px;
            width: 100%;
        }
        .session-input:focus {
            outline: none;
            border-color: #3b82f6;
        }
        .session-input::placeholder {
            color: #666;
        }
        /* TaskCreate form */
        .create-form {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 8px;
            padding: 12px;
            margin-bottom: 16px;
        }
        .create-form.collapsed .form-fields {
            display: none;
        }
        .form-toggle {
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
            user-select: none;
        }
        .form-toggle-label {
            font-size: 12px;
            font-weight: 500;
            color: #888;
        }
        .form-toggle-icon {
            color: #888;
            transition: transform 0.2s;
        }
        .create-form:not(.collapsed) .form-toggle-icon {
            transform: rotate(180deg);
        }
        .form-fields {
            margin-top: 10px;
        }
        .form-group {
            margin-bottom: 10px;
        }
        .form-label {
            display: block;
            font-size: 11px;
            color: #888;
            margin-bottom: 4px;
        }
        .form-input {
            width: 100%;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
            color: #e5e5e5;
            padding: 8px 10px;
            border-radius: 4px;
            font-size: 13px;
        }
        .form-input:focus {
            outline: none;
            border-color: #3b82f6;
        }
        .form-textarea {
            min-height: 60px;
            resize: vertical;
        }
        .form-actions {
            display: flex;
            justify-content: flex-end;
            gap: 8px;
        }
        .btn {
            padding: 6px 14px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 500;
            cursor: pointer;
            border: none;
        }
        .btn-primary {
            background: #3b82f6;
            color: #fff;
        }
        .btn-primary:hover {
            background: #2563eb;
        }
        .btn-primary:disabled {
            background: #4b5563;
            cursor: not-allowed;
        }
        .spinner {
            display: inline-block;
            width: 12px;
            height: 12px;
            border: 2px solid rgba(255, 255, 255, 0.3);
            border-top-color: #fff;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin-right: 6px;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .section {
            margin-bottom: 16px;
        }
        .section-header {
            font-size: 11px;
            font-weight: 600;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }
        .task {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 8px;
            padding: 10px 12px;
            margin-bottom: 6px;
            display: flex;
            align-items: flex-start;
            gap: 10px;
        }
        .task:hover {
            background: rgba(255, 255, 255, 0.08);
        }
        .task-icon {
            font-size: 14px;
            margin-top: 1px;
            flex-shrink: 0;
        }
        .task-content {
            flex: 1;
            min-width: 0;
            position: relative;
            padding-right: 36px;
        }
        .task-subject {
            font-weight: 500;
            color: #fff;
            word-wrap: break-word;
        }
        .task-meta {
            font-size: 11px;
            color: #666;
            margin-top: 4px;
        }
        .task-blocked {
            font-size: 11px;
            color: #ef4444;
            margin-top: 4px;
        }
        .empty {
            color: #555;
            font-style: italic;
            padding: 20px;
            text-align: center;
        }
        .status-pending { color: #6b7280; }
        .status-in_progress { color: #f59e0b; }
        .status-completed { color: #22c55e; }
        .session-badge {
            font-size: 10px;
            background: rgba(255, 255, 255, 0.1);
            padding: 2px 6px;
            border-radius: 4px;
            color: #888;
            cursor: pointer;
        }
        .session-badge:hover {
            background: rgba(255, 255, 255, 0.15);
        }
        .cwd-path {
            font-size: 10px;
            color: #555;
            margin-top: 2px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            max-width: 280px;
        }
        .task-launch-btn {
            position: absolute;
            right: 0;
            bottom: 0;
            background: #22c55e;
            border: none;
            color: #fff;
            width: 28px;
            height: 28px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .task-launch-btn:hover {
            background: #16a34a;
        }
    </style>
    <script>
        let isCreating = false;
        let formCollapsed = true;

        function toggleForm() {
            formCollapsed = !formCollapsed;
            const form = document.querySelector('.create-form');
            form.classList.toggle('collapsed', formCollapsed);
            if (!formCollapsed) {
                document.getElementById('taskSubject').focus();
            }
        }

        function setSession(value) {
            window.webkit.messageHandlers.taskBridge.postMessage({
                action: 'setSession',
                value: value.trim()
            });
        }

        function onSessionInputChange(input) {
            // Change session on Enter key or blur
            setSession(input.value);
        }

        function createTask() {
            if (isCreating) return;

            const subject = document.getElementById('taskSubject').value.trim();

            if (!subject) {
                document.getElementById('taskSubject').focus();
                return;
            }

            isCreating = true;
            const btn = document.getElementById('createBtn');
            btn.disabled = true;
            btn.innerHTML = '<span class="spinner"></span>Creating...';

            window.webkit.messageHandlers.taskBridge.postMessage({
                action: 'createTask',
                subject: subject
            });
        }

        function resetForm() {
            isCreating = false;
            const btn = document.getElementById('createBtn');
            btn.disabled = false;
            btn.innerHTML = 'Create';
            document.getElementById('taskSubject').value = '';
        }

        function launchClaude() {
            window.webkit.messageHandlers.taskBridge.postMessage({
                action: 'launchClaude'
            });
        }

        function showQuickUpdateDialog() {
            window.webkit.messageHandlers.taskBridge.postMessage({
                action: 'showQuickUpdateDialog'
            });
        }

        function copySessionId(e, fullId) {
            e.stopPropagation();
            navigator.clipboard.writeText(fullId).then(function() {
                var badge = e.target;
                var orig = badge.textContent;
                badge.textContent = 'Copied!';
                setTimeout(function() { badge.textContent = orig; }, 1000);
            });
        }

        function launchClaudeWithCwd(sessionId, cwd) {
            window.webkit.messageHandlers.taskBridge.postMessage({
                action: 'launchClaudeWithCwd',
                sessionId: sessionId,
                cwd: cwd
            });
        }

        // Keyboard shortcuts
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
                createTask();
            }
            if (e.key === 'e' && e.metaKey) {
                e.preventDefault();
                var btn = document.getElementById('quickUpdateBtn');
                if (btn && !btn.disabled) {
                    showQuickUpdateDialog();
                } else {
                    document.getElementById('sessionInput').focus();
                }
            }
            if (e.key === 'Escape') {
                if (!formCollapsed) toggleForm();
            }
        });
    </script>
</head>
<body>
    <div class="header">
        <div class="header-row">
            <span class="title">Claude Tasks</span>
            <div class="header-actions">
                <button id="quickUpdateBtn" class="launch-btn quick-update-btn" onclick="showQuickUpdateDialog()" title="Quick Task ⌘E"]] .. (currentSessionValue == '' and ' disabled' or '') .. [[>⚡</button>
                <button id="launchBtn" class="launch-btn" onclick="launchClaude()" title="Launch Claude session"]] .. (currentSessionValue == '' and ' disabled' or '') .. [[>▶</button>
                <span class="count">]] .. #tasks .. [[ tasks</span>
            </div>
        </div>
        <input type="text" class="session-input" id="sessionInput" list="sessionList"
               value="]] .. escapeHtml(currentSessionValue) .. [["
               placeholder="Enter or select session..."
               onchange="onSessionInputChange(this)"
               onkeydown="if(event.key==='Enter'){onSessionInputChange(this);event.preventDefault();}">
        <datalist id="sessionList">
            ]] .. sessionOptions .. [[
        </datalist>
    </div>
]]

    -- In Progress section
    if #inProgressTasks > 0 then
        html = html .. [[
    <div class="section">
        <div class="section-header">In Progress (]] .. #inProgressTasks .. [[)</div>
]]
        for _, task in ipairs(inProgressTasks) do
            local blocked = ""
            if task.blockedBy and #task.blockedBy > 0 then
                blocked = '<div class="task-blocked">Blocked by: ' .. table.concat(task.blockedBy, ", ") .. '</div>'
            end
            local launchBtn = task._cwd and '<button class="task-launch-btn" onclick="launchClaudeWithCwd(\'' .. escapeHtml(task._sessionId) .. '\', \'' .. escapeHtml(task._cwd) .. '\')" title="Launch in ' .. escapeHtml(task._cwd) .. '">▶</button>' or ''
            html = html .. [[
        <div class="task">
            <span class="task-icon status-in_progress">]] .. getStatusIcon("in_progress") .. [[</span>
            <div class="task-content">
                <div class="task-subject">]] .. escapeHtml(task.subject) .. [[</div>
                <div class="task-meta">
                    <span class="session-badge" onclick="copySessionId(event, ']] .. escapeHtml(task._sessionId) .. [[')" title="Click to copy: ]] .. escapeHtml(task._sessionId) .. [[">]] .. escapeHtml(task._sessionId:sub(1, 8)) .. [[...</span>
                    #]] .. escapeHtml(tostring(task.id)) .. [[
                </div>
                ]] .. (task._cwd and '<div class="cwd-path" title="' .. escapeHtml(task._cwd) .. '">' .. escapeHtml(task._cwd) .. '</div>' or '') .. [[
                ]] .. blocked .. launchBtn .. [[
            </div>
        </div>
]]
        end
        html = html .. "    </div>\n"
    end

    -- Pending section
    if #pendingTasks > 0 then
        html = html .. [[
    <div class="section">
        <div class="section-header">Pending (]] .. #pendingTasks .. [[)</div>
]]
        for _, task in ipairs(pendingTasks) do
            local blocked = ""
            if task.blockedBy and #task.blockedBy > 0 then
                blocked = '<div class="task-blocked">Blocked by: ' .. table.concat(task.blockedBy, ", ") .. '</div>'
            end
            local launchBtn = task._cwd and '<button class="task-launch-btn" onclick="launchClaudeWithCwd(\'' .. escapeHtml(task._sessionId) .. '\', \'' .. escapeHtml(task._cwd) .. '\')" title="Launch in ' .. escapeHtml(task._cwd) .. '">▶</button>' or ''
            html = html .. [[
        <div class="task">
            <span class="task-icon status-pending">]] .. getStatusIcon("pending") .. [[</span>
            <div class="task-content">
                <div class="task-subject">]] .. escapeHtml(task.subject) .. [[</div>
                <div class="task-meta">
                    <span class="session-badge" onclick="copySessionId(event, ']] .. escapeHtml(task._sessionId) .. [[')" title="Click to copy: ]] .. escapeHtml(task._sessionId) .. [[">]] .. escapeHtml(task._sessionId:sub(1, 8)) .. [[...</span>
                    #]] .. escapeHtml(tostring(task.id)) .. [[
                </div>
                ]] .. (task._cwd and '<div class="cwd-path" title="' .. escapeHtml(task._cwd) .. '">' .. escapeHtml(task._cwd) .. '</div>' or '') .. [[
                ]] .. blocked .. launchBtn .. [[
            </div>
        </div>
]]
        end
        html = html .. "    </div>\n"
    end

    -- Completed section (show max 5)
    if #completedTasks > 0 then
        local displayCount = math.min(5, #completedTasks)
        html = html .. [[
    <div class="section">
        <div class="section-header">Completed (]] .. #completedTasks .. [[)</div>
]]
        for i = 1, displayCount do
            local task = completedTasks[i]
            local launchBtn = task._cwd and '<button class="task-launch-btn" onclick="launchClaudeWithCwd(\'' .. escapeHtml(task._sessionId) .. '\', \'' .. escapeHtml(task._cwd) .. '\')" title="Launch in ' .. escapeHtml(task._cwd) .. '">▶</button>' or ''
            html = html .. [[
        <div class="task" style="opacity: 0.6;">
            <span class="task-icon status-completed">]] .. getStatusIcon("completed") .. [[</span>
            <div class="task-content">
                <div class="task-subject">]] .. escapeHtml(task.subject) .. [[</div>
                <div class="task-meta">
                    <span class="session-badge" onclick="copySessionId(event, ']] .. escapeHtml(task._sessionId) .. [[')" title="Click to copy: ]] .. escapeHtml(task._sessionId) .. [[">]] .. escapeHtml(task._sessionId:sub(1, 8)) .. [[...</span>
                    #]] .. escapeHtml(tostring(task.id)) .. [[
                </div>
                ]] .. (task._cwd and '<div class="cwd-path" title="' .. escapeHtml(task._cwd) .. '">' .. escapeHtml(task._cwd) .. '</div>' or '') .. launchBtn .. [[
            </div>
        </div>
]]
        end
        if #completedTasks > displayCount then
            html = html .. [[
        <div class="task-meta" style="text-align: center; padding: 8px; color: #555;">
            + ]] .. (#completedTasks - displayCount) .. [[ more completed
        </div>
]]
        end
        html = html .. "    </div>\n"
    end

    -- When no tasks exist
    if #tasks == 0 then
        html = html .. [[
    <div class="empty">
        No tasks found.<br>
        Use TaskCreate in Claude Code to add tasks.
    </div>
]]
    end

    html = html .. [[
</body>
</html>
]]
    return html
end

-- ============================================================================
-- WebView Management
-- ============================================================================

local function createUserContent()
    if usercontent then
        return usercontent
    end

    usercontent = hs.webview.usercontent.new("taskBridge")
    usercontent:setCallback(function(msg)
        log("Bridge message: " .. hs.json.encode(msg.body))

        if msg.body.action == "setSession" then
            obj:setTaskListId(msg.body.value)
        elseif msg.body.action == "createTask" then
            obj:createTask(msg.body.subject)
        elseif msg.body.action == "launchClaude" then
            obj:launchClaudeWithTaskList()
        elseif msg.body.action == "launchClaudeWithCwd" then
            obj:launchClaudeWithCwd(msg.body.sessionId, msg.body.cwd)
        elseif msg.body.action == "showQuickUpdateDialog" then
            local button, text = hs.dialog.textPrompt("Quick Task", "Enter prompt (e.g., 'TaskCreate: Fix bug' or 'TaskUpdate: #3 done'):", "", "OK", "Cancel")
            if button == "OK" and text and text ~= "" then
                obj:quickTaskUpdate(text)
            end
        end
    end)

    log("UserContent bridge created")
    return usercontent
end

local function createWebView()
    if webview then
        return webview
    end

    -- Create JS-Lua bridge
    createUserContent()

    -- Get screen size
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()

    -- Position at bottom-right
    local rect = hs.geometry.rect(
        frame.x + frame.w - obj.config.width - obj.config.margin,
        frame.y + frame.h - obj.config.height - obj.config.margin,
        obj.config.width,
        obj.config.height
    )

    webview = hs.webview.new(rect, {}, usercontent)
    webview:windowStyle({"titled", "closable", "utility", "HUD"})
    webview:level(hs.drawing.windowLevels.floating)
    webview:allowTextEntry(true)  -- Allow form input
    webview:allowGestures(false)
    webview:shadow(true)
    webview:alpha(0.98)
    webview:windowTitle("Claude Tasks")

    -- Update state when window closes
    webview:deleteOnClose(false)

    log("WebView created with usercontent bridge")
    return webview
end

local function refreshWebView()
    if not webview then return end

    local tasks = loadAllTasks()
    local html = generateHTML(tasks)
    webview:html(html)
    log("WebView refreshed with " .. #tasks .. " tasks")
end

-- ============================================================================
-- File Watching
-- ============================================================================

local function startPathWatcher()
    if pathWatcher then return end

    local tasksDir = getTasksDir()

    -- Wait for directory creation if it doesn't exist
    if not fileExists(tasksDir) then
        log("Tasks directory does not exist, will watch parent")
        -- Watch .claude directory
        local parentDir = os.getenv("HOME") .. "/.claude"
        pathWatcher = hs.pathwatcher.new(parentDir, function(paths)
            -- Restart when tasks directory is created
            if fileExists(tasksDir) then
                obj:stop()
                obj:start()
            end
        end)
        pathWatcher:start()
        return
    end

    -- Watch all session directories
    local sessions = listDir(tasksDir)
    local watchPaths = {tasksDir}

    for _, sessionId in ipairs(sessions) do
        table.insert(watchPaths, tasksDir .. "/" .. sessionId)
    end

    pathWatcher = hs.pathwatcher.new(tasksDir, function(paths)
        log("File change detected: " .. table.concat(paths, ", "))

        -- Debounce: only process the last change in rapid succession
        if refreshTimer then
            refreshTimer:stop()
        end

        refreshTimer = hs.timer.doAfter(obj.config.refreshDebounce, function()
            refreshWebView()
            refreshTimer = nil
        end)
    end)

    pathWatcher:start()
    log("PathWatcher started on: " .. tasksDir)
end

local function stopPathWatcher()
    if pathWatcher then
        pathWatcher:stop()
        pathWatcher = nil
        log("PathWatcher stopped")
    end
    if refreshTimer then
        refreshTimer:stop()
        refreshTimer = nil
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Initialize the Spoon
function obj:init()
    obj.state.configPath = obj.spoonPath .. "/state.json"
    log("ClaudeTasks Spoon initialized")
    return self
end

--- Show the task viewer
function obj:show()
    if not webview then
        createWebView()
    end
    refreshWebView()
    webview:show()
    webview:bringToFront()
    isVisible = true
    startPathWatcher()

    -- Focus session input after DOM ready
    hs.timer.doAfter(0.1, function()
        if webview then
            webview:evaluateJavaScript("document.getElementById('sessionInput').focus(); document.getElementById('sessionInput').select();")
        end
    end)

    log("Task viewer shown")
    return self
end

--- Hide the task viewer
function obj:hide()
    if webview then
        webview:hide()
        isVisible = false
        log("Task viewer hidden")
    end
    return self
end

--- Toggle show/hide
function obj:toggle()
    if isVisible then
        obj:hide()
    else
        obj:show()
    end
    return self
end

--- Manual refresh
function obj:refresh()
    refreshWebView()
    return self
end

--- Set session ID
function obj:setTaskListId(id)
    local sessionId = (id ~= "" and id) or nil
    obj.state.currentTaskListId = sessionId
    obj.config.taskListId = sessionId
    saveState()
    log("Session changed to: " .. (sessionId or "none"))

    -- Restart file watcher for new session
    stopPathWatcher()
    startPathWatcher()

    -- Refresh UI
    obj:refresh()
    return self
end

--- Create task (using Claude CLI)
function obj:createTask(subject)
    local claudePath = discoverClaudePath()
    if not claudePath then
        hs.alert.show("Claude CLI not found", 2)
        return nil
    end

    local prompt = string.format("TaskCreate(%s)", subject)

    log("Creating task: " .. prompt)

    local env = {}
    if obj.state.currentTaskListId and obj.state.currentTaskListId ~= "" then
        env.CLAUDE_CODE_TASK_LIST_ID = obj.state.currentTaskListId
    end

    local task = hs.task.new(claudePath, function(exitCode, stdout, stderr)
        if exitCode == 0 then
            hs.alert.show("Task created", 1)
            log("Task created successfully. stdout: " .. (stdout or ""))
        else
            hs.alert.show("Task creation failed", 2)
            log("Task creation failed. exitCode: " .. exitCode .. ", stderr: " .. (stderr or ""))
        end

        -- Reset UI form (JS call)
        if webview then
            webview:evaluateJavaScript("resetForm()")
        end

        -- Refresh
        obj:refresh()
    end, {
        "-p",
        "--model", "haiku",
        prompt
    })

    if next(env) then
        task:setEnvironment(env)
    end

    -- Run from ~/.claude
    task:setWorkingDirectory(os.getenv("HOME") .. "/.claude")
    task:start()
    return task
end

--- Quick TaskUpdate (fast task update with haiku model)
function obj:quickTaskUpdate(prompt)
    local taskListId = obj.state.currentTaskListId
    if not taskListId or taskListId == "" then
        hs.alert.show("Select a session first", 2)
        return
    end

    local claudePath = discoverClaudePath()
    if not claudePath then
        hs.alert.show("Claude CLI not found", 2)
        return
    end

    -- Set required environment variables
    local env = {
        PATH = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        HOME = os.getenv("HOME"),
        USER = os.getenv("USER"),
        SHELL = getShell(),
        TERM = "xterm-256color",
        CLAUDE_CODE_ENABLE_TASKS = "true",
        CLAUDE_CODE_TASK_LIST_ID = taskListId
    }

    local systemPrompt = "This is a lightweight Todo Task management command. Use TaskCreate or TaskUpdate tools immediately based on the user's input. Do not ask for clarification - execute the tool directly."

    log("QuickTaskUpdate: " .. prompt .. " (taskListId: " .. taskListId .. ")")

    local task = hs.task.new(claudePath, function(exitCode, stdout, stderr)
        if exitCode == 0 then
            local result = (stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if result == "" then result = "Done" end
            -- Truncate long results
            if #result > 200 then
                result = result:sub(1, 200) .. "..."
            end
            hs.alert.show(result, 3)
            log("QuickTaskUpdate completed. stdout: " .. (stdout or ""))
        else
            local errMsg = (stderr or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if errMsg == "" then errMsg = "TaskUpdate failed" end
            hs.alert.show("❌ " .. errMsg:sub(1, 100), 3)
            log("QuickTaskUpdate failed. exitCode: " .. exitCode .. ", stderr: " .. (stderr or ""))
        end
        obj:refresh()
    end, {
        "--model", "haiku",
        "-p",
        "--no-session-persistence",
        "--disable-slash-commands",
        "--strict-mcp-config",
        "--dangerously-skip-permissions",
        "--setting-sources", "",
        "--system-prompt", systemPrompt,
        "--verbose",
        "--",
        prompt
    })

    task:setEnvironment(env)
    task:setWorkingDirectory(os.getenv("HOME") .. "/.claude")
    task:start()
    hs.alert.show("Running Quick Task...", 1)
end

--- Launch Claude Code session
function obj:launchClaudeWithTaskList()
    local taskListId = obj.state.currentTaskListId
    if not taskListId or taskListId == "" then
        hs.alert.show("Select a session first", 2)
        return
    end

    local terminalPath = discoverTerminalApp()
    if not terminalPath then
        hs.alert.show("No terminal app found", 2)
        return
    end

    local claudeDir = os.getenv("HOME") .. "/.claude"
    local shell = getShell()
    local shellCmd = string.format("cd %s && CLAUDE_CODE_TASK_LIST_ID=%s claude", claudeDir, taskListId)

    log("Launching Claude: " .. shellCmd)

    local task = hs.task.new(terminalPath, function(exitCode, stdout, stderr)
        if exitCode ~= 0 then
            log("Terminal launch error: " .. (stderr or "unknown"))
        end
    end, {
        "-e", shell, "-c", shellCmd
    })

    task:start()
    hs.alert.show("Launching Claude...", 1)
end

--- Launch Claude Code session in specific working directory
function obj:launchClaudeWithCwd(sessionId, cwd)
    if not sessionId or sessionId == "" then
        hs.alert.show("No session ID", 2)
        return
    end
    if not cwd or cwd == "" then
        hs.alert.show("No working directory", 2)
        return
    end

    local terminalPath = discoverTerminalApp()
    if not terminalPath then
        hs.alert.show("No terminal app found", 2)
        return
    end

    local shell = getShell()
    local shellCmd = string.format("cd '%s' && CLAUDE_CODE_TASK_LIST_ID=%s claude -r %s", cwd, sessionId, sessionId)

    log("Launching Claude with cwd: " .. shellCmd)

    local task = hs.task.new(terminalPath, function(exitCode, stdout, stderr)
        if exitCode ~= 0 then
            log("Terminal launch error: " .. (stderr or "unknown"))
        end
    end, {
        "-e", shell, "-c", shellCmd
    })

    task:start()
    hs.alert.show("Launching Claude in " .. cwd:match("[^/]+$") .. "...", 1)
end

--- Start module (begin file watching)
function obj:start()
    loadState()  -- Load saved state
    startPathWatcher()
    log("Claude Tasks module started")
    return self
end

--- Stop module
function obj:stop()
    stopPathWatcher()
    if webview then
        webview:delete()
        webview = nil
    end
    if usercontent then
        usercontent = nil
    end
    isVisible = false
    cwdCache = {}
    log("Claude Tasks module stopped")
    return self
end

--- Update configuration
function obj:configure(options)
    if options then
        for k, v in pairs(options) do
            obj.config[k] = v
        end
    end
    return self
end

--- Return current state
function obj:status()
    local tasks = loadAllTasks()
    local pending = 0
    local inProgress = 0
    local completed = 0

    for _, task in ipairs(tasks) do
        if task.status == "completed" then
            completed = completed + 1
        elseif task.status == "in_progress" then
            inProgress = inProgress + 1
        else
            pending = pending + 1
        end
    end

    return {
        visible = isVisible,
        taskCount = #tasks,
        pending = pending,
        inProgress = inProgress,
        completed = completed,
        taskListId = obj.config.taskListId,
        currentTaskListId = obj.state.currentTaskListId,
        watcherActive = pathWatcher ~= nil,
    }
end

-- ============================================================================
-- Hotkey Binding
-- ============================================================================

obj.defaultHotkeys = {
    toggle = {{"alt"}, "."},
    status = {{"cmd", "alt"}, "T"}
}

function obj:bindHotkeys(mapping)
    local def = {
        toggle = function() obj:toggle() end,
        status = function()
            local status = obj:status()
            local msg = string.format(
                "Tasks: %d total\n⏳ %d pending\n🔄 %d in progress\n✓ %d completed",
                status.taskCount, status.pending, status.inProgress, status.completed
            )
            hs.alert.show(msg, 3)
        end
    }
    hs.spoons.bindHotkeysToSpec(def, mapping)
    return self
end

return obj
