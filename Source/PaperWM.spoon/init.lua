--- === PaperWM ===
---
--- A scrolling window manager. Inspired by PaperWM Gnome extension.
---
--- # Usage
---
--- `PaperWM:start()` will begin automatically tiling new and existing windows.
--- `PaperWM:stop()` will release control over windows.
--- `PaperWM::bindHotkeys()` will move / resize windows using keyboard shortcuts.
---
--- Here is an example Hammerspoon config:
---
--- ```
--- PaperWM = hs.loadSpoon("PaperWM")
--- PaperWM:bindHotkeys({
---     -- switch to a new focused window in tiled grid
---     focus_left  = {{"ctrl", "alt", "cmd"}, "left"},
---     focus_right = {{"ctrl", "alt", "cmd"}, "right"},
---     focus_up    = {{"ctrl", "alt", "cmd"}, "up"},
---     focus_down  = {{"ctrl", "alt", "cmd"}, "down"},
---
---     -- move windows around in tiled grid
---     swap_left  = {{"ctrl", "alt", "cmd", "shift"}, "left"},
---     swap_right = {{"ctrl", "alt", "cmd", "shift"}, "right"},
---     swap_up    = {{"ctrl", "alt", "cmd", "shift"}, "up"},
---     swap_down  = {{"ctrl", "alt", "cmd", "shift"}, "down"},
---
---     -- position and resize focused window
---     center_window = {{"ctrl", "alt", "cmd"}, "c"},
---     full_width    = {{"ctrl", "alt", "cmd"}, "f"},
---     cycle_width   = {{"ctrl", "alt", "cmd"}, "r"},
---     cycle_height  = {{"ctrl", "alt", "cmd", "shift"}, "r"},
---
---     -- move focused window into / out of a column
---     slurp_in = {{"ctrl", "alt", "cmd"}, "i"},
---     barf_out = {{"ctrl", "alt", "cmd"}, "o"},
---
---     -- switch to a new Mission Control space
---     switch_space_1 = {{"ctrl", "alt", "cmd"}, "1"},
---     switch_space_2 = {{"ctrl", "alt", "cmd"}, "2"},
---     switch_space_3 = {{"ctrl", "alt", "cmd"}, "3"},
---     switch_space_4 = {{"ctrl", "alt", "cmd"}, "4"},
---     switch_space_5 = {{"ctrl", "alt", "cmd"}, "5"},
---     switch_space_6 = {{"ctrl", "alt", "cmd"}, "6"},
---     switch_space_7 = {{"ctrl", "alt", "cmd"}, "7"},
---     switch_space_8 = {{"ctrl", "alt", "cmd"}, "8"},
---     switch_space_9 = {{"ctrl", "alt", "cmd"}, "9"},
---
---     -- move focused window to a new space and tile
---     move_window_1 = {{"ctrl", "alt", "cmd", "shift"}, "1"},
---     move_window_2 = {{"ctrl", "alt", "cmd", "shift"}, "2"},
---     move_window_3 = {{"ctrl", "alt", "cmd", "shift"}, "3"},
---     move_window_4 = {{"ctrl", "alt", "cmd", "shift"}, "4"},
---     move_window_5 = {{"ctrl", "alt", "cmd", "shift"}, "5"},
---     move_window_6 = {{"ctrl", "alt", "cmd", "shift"}, "6"},
---     move_window_7 = {{"ctrl", "alt", "cmd", "shift"}, "7"},
---     move_window_8 = {{"ctrl", "alt", "cmd", "shift"}, "8"},
---     move_window_9 = {{"ctrl", "alt", "cmd", "shift"}, "9"}
--- })
--- PaperWM:start()
--- ```
---
--- Use `PaperWM:bindHotkeys(PaperWM.default_hotkeys)` for defaults.
---
--- Set `PaperWM.window_gap` to the number of pixels to space between windows and
--- the top and bottom screen edges.
---
--- Overwrite `PaperWM.window_filter` to ignore specific applications. For example:
---
--- ```
--- PaperWM.window_filter = PaperWM.window_filter:setAppFilter("Finder", false)
--- PaperWM:start() -- restart for new window filter to take effect
--- ```
---
--- # Limitations
---
--- Under System Preferences -> Mission Control, unselect "Automatically
--- rearrange Spaces based on most recent use" and select "Displays have separate
--- Spaces".
---
--- MacOS does not allow a window to be moved fully off-screen. Windows that would--
--- be tiled off-screen are placed in a margin on the left and right edge of the
--- screen. They are still visible and clickable.
---
--- It's difficult to detect when a window is dragged from one space or screen to
--- another. Use the move_window_N commands to move windows between spaces and
--- screens.
---
--- Arrange screens vertically to prevent windows from bleeding into other screens.
---
---
--- Download: [https://github.com/mogenson/PaperWM.spoon](https://github.com/mogenson/PaperWM.spoon)
local WindowFilter <const> = hs.window.filter
local Window <const> = hs.window
local Spaces <const> = hs.spaces
local Screen <const> = hs.screen
local DoAfter <const> = hs.timer.doAfter
local Rect <const> = hs.geometry.rect
local Watcher <const> = hs.uielement.watcher

local PaperWM = {}
PaperWM.__index = PaperWM

-- Metadata
PaperWM.name = "PaperWM"
PaperWM.version = "0.4"
PaperWM.author = "Michael Mogenson"
PaperWM.homepage = "https://github.com/mogenson/PaperWM.spoon"
PaperWM.license = "MIT - https://opensource.org/licenses/MIT"

--- PaperWM.default_hotkeys
--- Variable
--- Default hotkeys for moving / resizing windows
PaperWM.default_hotkeys = {
    stop_events = { { "ctrl", "alt", "cmd", "shift" }, "q" },
    focus_left = { { "ctrl", "alt", "cmd" }, "left" },
    focus_right = { { "ctrl", "alt", "cmd" }, "right" },
    focus_up = { { "ctrl", "alt", "cmd" }, "up" },
    focus_down = { { "ctrl", "alt", "cmd" }, "down" },
    swap_left = { { "ctrl", "alt", "cmd", "shift" }, "left" },
    swap_right = { { "ctrl", "alt", "cmd", "shift" }, "right" },
    swap_up = { { "ctrl", "alt", "cmd", "shift" }, "up" },
    swap_down = { { "ctrl", "alt", "cmd", "shift" }, "down" },
    center_window = { { "ctrl", "alt", "cmd" }, "c" },
    full_width = { { "ctrl", "alt", "cmd" }, "f" },
    cycle_width = { { "ctrl", "alt", "cmd" }, "r" },
    cycle_height = { { "ctrl", "alt", "cmd", "shift" }, "r" },
    slurp_in = { { "ctrl", "alt", "cmd" }, "i" },
    barf_out = { { "ctrl", "alt", "cmd" }, "o" },
    switch_space_1 = { { "ctrl", "alt", "cmd" }, "1" },
    switch_space_2 = { { "ctrl", "alt", "cmd" }, "2" },
    switch_space_3 = { { "ctrl", "alt", "cmd" }, "3" },
    switch_space_4 = { { "ctrl", "alt", "cmd" }, "4" },
    switch_space_5 = { { "ctrl", "alt", "cmd" }, "5" },
    switch_space_6 = { { "ctrl", "alt", "cmd" }, "6" },
    switch_space_7 = { { "ctrl", "alt", "cmd" }, "7" },
    switch_space_8 = { { "ctrl", "alt", "cmd" }, "8" },
    switch_space_9 = { { "ctrl", "alt", "cmd" }, "9" },
    move_window_1 = { { "ctrl", "alt", "cmd", "shift" }, "1" },
    move_window_2 = { { "ctrl", "alt", "cmd", "shift" }, "2" },
    move_window_3 = { { "ctrl", "alt", "cmd", "shift" }, "3" },
    move_window_4 = { { "ctrl", "alt", "cmd", "shift" }, "4" },
    move_window_5 = { { "ctrl", "alt", "cmd", "shift" }, "5" },
    move_window_6 = { { "ctrl", "alt", "cmd", "shift" }, "6" },
    move_window_7 = { { "ctrl", "alt", "cmd", "shift" }, "7" },
    move_window_8 = { { "ctrl", "alt", "cmd", "shift" }, "8" },
    move_window_9 = { { "ctrl", "alt", "cmd", "shift" }, "9" }
}

--- PaperWM.window_filter
--- Variable
--- Windows captured by this filter are automatically tiled and managed
PaperWM.window_filter = WindowFilter.new():setOverrideFilter({
    visible = true,
    fullscreen = false,
    hasTitlebar = true,
    allowRoles = "AXStandardWindow"
})

--- PaperWM.window_gap
--- Variable
--- Number of pixels between tiled windows
PaperWM.window_gap = 8

--- PaperWM.logger
--- Variable
--- Logger object. Can be accessed to set default log level.
PaperWM.logger = hs.logger.new(PaperWM.name)

-- constants
local Direction <const> = {
    LEFT = -1,
    RIGHT = 1,
    UP = -2,
    DOWN = 2,
    WIDTH = 3,
    HEIGHT = 4
}

-- array of windows sorted from left to right
local window_list = {} -- 3D array of tiles in order of [space][x][y]
local index_table = {} -- dictionary of {space, x, y} with window id for keys
local ui_watchers = {} -- dictionary of uielement watchers with window id for keys

-- current focused window
local focused_window = nil

local function getSpace(index)
    local layout = Spaces.allSpaces()
    for _, screen in ipairs(Screen.allScreens()) do
        local screen_uuid = screen:getUUID()
        local num_spaces = #layout[screen_uuid]
        if num_spaces >= index then return layout[screen_uuid][index] end
        index = index - num_spaces
    end
end

local function getFirstVisibleWindow(columns, screen)
    local x = screen:frame().x
    for _, windows in ipairs(columns or {}) do
        local window = windows[1] -- take first window in column
        if window:frame().x >= x then return window end
    end
end

local function getColumn(space, col) return (window_list[space] or {})[col] end

local function getWindow(space, col, row)
    return (getColumn(space, col) or {})[row]
end

local function getCanvas(screen)
    local screen_frame = screen:frame()
    return Rect(screen_frame.x + PaperWM.window_gap,
        screen_frame.y + PaperWM.window_gap,
        screen_frame.w - (2 * PaperWM.window_gap),
        screen_frame.h - (2 * PaperWM.window_gap))
end

local function updateIndexTable(space, column)
    local columns = window_list[space] or {}
    for col = column, #columns do
        for row, window in ipairs(getColumn(space, col)) do
            index_table[window:id()] = { space = space, col = col, row = row }
        end
    end
end

local pending_window = nil
local function windowEventHandler(window, event, self)
    self.logger.df("%s for %s", event, window)
    local space = nil

    --[[ When a new window is created, We first get a windowVisible event but
    without a Space. Next we receive a windowFocused event for the window, but
    this also sometimes lacks a Space. Our approach is to store the window
    pending a Space in the pending_window variable and set a timer to try to add
    the window again later. Also schedule the windowFocused handler to run later
    after the window was added ]]
    --

    if event == "windowFocused" then
        if pending_window and window == pending_window then
            DoAfter(Window.animationDuration,
                function()
                    windowEventHandler(window, event, self)
                end)
            return
        end
        focused_window = window
        space = Spaces.windowSpaces(window)[1]
    elseif event == "windowVisible" or event == "windowUnfullscreened" then
        space = self:addWindow(window)
        if pending_window and window == pending_window then
            pending_window = nil -- tried to add window for the second time
        elseif not space then
            pending_window = window
            DoAfter(Window.animationDuration,
                function()
                    windowEventHandler(window, event, self)
                end)
            return
        end
    elseif event == "windowNotVisible" then
        self:removeWindow(window)               -- destroyed windows don't have a space
    elseif event == "windowFullscreened" then
        space = self:removeWindow(window, true) -- don't focus new window if fullscreened
    elseif event == "AXWindowMoved" or event == "AXWindowResized" then
        space = Spaces.windowSpaces(window)[1]
    end

    if space then self:tileSpace(space) end
end

--- PaperWM.bindHotkeys(mapping)
--- Method
--- Binds hotkeys for PaperWM
---
--- Parameters:
---  * mapping - A table containing hotkey modifer/key details for the following items:
---   * stop_events - Stop automatic tiling
---   * focus_left - Focus window to left of current window
---   * focus_right - Focus window to right of current window
---   * focus_up - Focus window to up of current window
---   * focus_down - Focus window to down of current window
---   * swap_left - Swap positions of window to the left and current window
---   * swap_right - Swap positions of window to the right and current window
---   * swap_up - Swap positions of window above and current window
---   * swap_down - Swap positions of window below and current window
---   * center_window - Move current window to center of screen
---   * full_width - Resize width of current window to width of screen
---   * cycle_width - Toggle through preset window widths
---   * cycle_height - Toggle through preset window heights
---   * slurp_in - Move current window into column to the left
---   * barf_out - Remove current window from column and place to the right
---   * switch_space_1 - Switch to Mission Control space 1
---   * switch_space_2 - Switch to Mission Control space 2
---   * switch_space_3 - Switch to Mission Control space 3
---   * switch_space_4 - Switch to Mission Control space 4
---   * switch_space_5 - Switch to Mission Control space 5
---   * switch_space_6 - Switch to Mission Control space 6
---   * switch_space_7 - Switch to Mission Control space 7
---   * switch_space_8 - Switch to Mission Control space 8
---   * switch_space_9 - Switch to Mission Control space 9
---   * move_window_1 - Move current window to Mission Control space 1
---   * move_window_2 - Move current window to Mission Control space 2
---   * move_window_3 - Move current window to Mission Control space 3
---   * move_window_4 - Move current window to Mission Control space 4
---   * move_window_5 - Move current window to Mission Control space 5
---   * move_window_6 - Move current window to Mission Control space 6
---   * move_window_7 - Move current window to Mission Control space 7
---   * move_window_8 - Move current window to Mission Control space 8
---   * move_window_9 - Move current window to Mission Control space 9
function PaperWM:bindHotkeys(mapping)
    local partial = hs.fnutils.partial
    local spec = {
        stop_events = partial(self.stop, self),
        focus_left = partial(self.focusWindow, self, Direction.LEFT),
        focus_right = partial(self.focusWindow, self, Direction.RIGHT),
        focus_up = partial(self.focusWindow, self, Direction.UP),
        focus_down = partial(self.focusWindow, self, Direction.DOWN),
        swap_left = partial(self.swapWindows, self, Direction.LEFT),
        swap_right = partial(self.swapWindows, self, Direction.RIGHT),
        swap_up = partial(self.swapWindows, self, Direction.UP),
        swap_down = partial(self.swapWindows, self, Direction.DOWN),
        center_window = partial(self.centerWindow, self),
        full_width = partial(self.setWindowFullWidth, self),
        cycle_width = partial(self.cycleWindowSize, self, Direction.WIDTH),
        cycle_height = partial(self.cycleWindowSize, self, Direction.HEIGHT),
        slurp_in = partial(self.slurpWindow, self),
        barf_out = partial(self.barfWindow, self),
        switch_space_1 = partial(self.switchToSpace, self, 1),
        switch_space_2 = partial(self.switchToSpace, self, 2),
        switch_space_3 = partial(self.switchToSpace, self, 3),
        switch_space_4 = partial(self.switchToSpace, self, 4),
        switch_space_5 = partial(self.switchToSpace, self, 5),
        switch_space_6 = partial(self.switchToSpace, self, 6),
        switch_space_7 = partial(self.switchToSpace, self, 7),
        switch_space_8 = partial(self.switchToSpace, self, 8),
        switch_space_9 = partial(self.switchToSpace, self, 9),
        move_window_1 = partial(self.moveWindowToSpace, self, 1),
        move_window_2 = partial(self.moveWindowToSpace, self, 2),
        move_window_3 = partial(self.moveWindowToSpace, self, 3),
        move_window_4 = partial(self.moveWindowToSpace, self, 4),
        move_window_5 = partial(self.moveWindowToSpace, self, 5),
        move_window_6 = partial(self.moveWindowToSpace, self, 6),
        move_window_7 = partial(self.moveWindowToSpace, self, 7),
        move_window_8 = partial(self.moveWindowToSpace, self, 8),
        move_window_9 = partial(self.moveWindowToSpace, self, 9)
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
end

--- PaperWM:start()
--- Method
--- Start automatic tiling of windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * The PaperWM object
function PaperWM:start()
    -- check for some settings
    if not Spaces.screensHaveSeparateSpaces() then
        self.logger.e(
            "please check 'Displays have separate Spaces' in System Preferences -> Mission Control")
    end

    -- clear state
    window_list = {}
    index_table = {}
    ui_watchers = {}

    -- populate window list, index table, and ui_watchers
    self:refreshWindows()

    -- set initial layout
    for space, _ in pairs(window_list) do self:tileSpace(space) end

    -- listen for window events
    self.window_filter:subscribe({
        WindowFilter.windowFocused, WindowFilter.windowVisible,
        WindowFilter.windowNotVisible, WindowFilter.windowFullscreened,
        WindowFilter.windowUnfullscreened
    }, function(window, _, event) windowEventHandler(window, event, self) end)

    return self
end

--- PaperWM:stop()
--- Method
--- Stop automatic tiling of windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * The PaperWM object
function PaperWM:stop()
    -- stop events
    self.window_filter:unsubscribeAll()
    for _, watcher in pairs(ui_watchers) do watcher:stop() end

    return self
end

--- PaperWM:tileColumn(windows, bounds, h, w, id, h4id)
--- Method
--- Tile a column of windows
---
--- Parameters:
---  * windows - A list of hs.windows.
---  * bounds - An hs.geometry.rect. The area for this column to fill.
---  * h - The height for each window in column.
---  * w - The width for each window in column.
---  * id - A hs.window.id() for a specific window in column.
---  * h4id - The height for a window matching id in column.
---
--- Notes:
---  * The h, w, id, and h4id parameters are optional. The height and width of
---    all windows will be calculated and set to fill column bounds.
---  * If bounds width is not specified, all windows in column will be resized
---    to width of first window.
---
--- Returns:
---  * The width of the column
function PaperWM:tileColumn(windows, bounds, h, w, id, h4id)
    local last_window, frame
    for _, window in ipairs(windows) do
        frame = window:frame()
        w = w or frame.w -- take given width or width of first window
        if bounds.x then -- set either left or right x coord
            frame.x = bounds.x
        elseif bounds.x2 then
            frame.x = bounds.x2 - w
        end
        if h then              -- set height if given
            if id and h4id and window:id() == id then
                frame.h = h4id -- use this height for window with id
            else
                frame.h = h    -- use this height for all other windows
            end
        end
        frame.y = bounds.y
        frame.w = w
        frame.y2 = math.min(frame.y2, bounds.y2) -- don't overflow bottom of bounds
        self:moveWindow(window, frame)
        bounds.y = math.min(frame.y2 + self.window_gap, bounds.y2)
        last_window = window
    end
    -- expand last window height to bottom
    if frame.y2 ~= bounds.y2 then
        frame.y2 = bounds.y2
        self:moveWindow(last_window, frame)
    end
    return w -- return width of column
end

--- PaperWM:tileSpace(space)
--- Method
--- Tile all windows within a space
---
--- Parameters:
---  * space - A hs.spaces space.
function PaperWM:tileSpace(space)
    -- MacOS doesn't allow windows to be moved off screen
    -- stack windows in a visible margin on either side
    local screen_margin <const> = 40

    if not space or Spaces.spaceType(space) ~= "user" then
        self.logger.e("current space invalid")
        return
    end

    -- find screen for space
    local screen = Screen(Spaces.spaceDisplay(space))
    if not screen then
        self.logger.e("no screen for space")
        return
    end

    -- if focused window is in space, tile from that
    focused_window = focused_window or Window.focusedWindow()
    local anchor_window = (focused_window and
            (Spaces.windowSpaces(focused_window)[1] == space)) and
        focused_window or
        getFirstVisibleWindow(window_list[space], screen)

    if not anchor_window then
        self.logger.e("no anchor window in space")
        return
    end

    local anchor_index = index_table[anchor_window:id()]
    if not anchor_index then
        self.logger.e("anchor index not found")
        if self:addWindow(anchor_window) == space then
            self.logger.d("added missing window")
            anchor_index = index_table[anchor_window:id()]
        else
            return -- bail
        end
    end

    -- get some global coordinates
    local screen_frame <const> = screen:frame()
    local left_margin <const> = screen_frame.x + screen_margin
    local right_margin <const> = screen_frame.x2 - screen_margin
    local canvas <const> = getCanvas(screen)

    -- make sure anchor window is on screen
    local anchor_frame = anchor_window:frame()
    anchor_frame.x = math.max(anchor_frame.x, canvas.x)
    anchor_frame.w = math.min(anchor_frame.w, canvas.w)
    anchor_frame.h = math.min(anchor_frame.h, canvas.h)
    if anchor_frame.x2 > canvas.x2 then
        anchor_frame.x = canvas.x2 - anchor_frame.w
    end

    -- adjust anchor window column
    local column = getColumn(space, anchor_index.col)
    if not column then
        self.logger.e("no anchor window column")
        return
    end

    -- TODO: need a minimum window height
    if #column == 1 then
        anchor_frame.y, anchor_frame.h = canvas.y, canvas.h
        self:moveWindow(anchor_window, anchor_frame)
    else
        local n = #column - 1 -- number of other windows in column
        local h =
            math.max(0, canvas.h - anchor_frame.h - (n * self.window_gap)) // n
        local bounds = {
            x = anchor_frame.x,
            x2 = nil,
            y = canvas.y,
            y2 = canvas.y2
        }
        self:tileColumn(column, bounds, h, anchor_frame.w, anchor_window:id(),
            anchor_frame.h)
    end

    -- tile windows from anchor right
    local x = math.min(anchor_frame.x2 + self.window_gap, right_margin)
    for col = anchor_index.col + 1, #(window_list[space] or {}) do
        local bounds = { x = x, x2 = nil, y = canvas.y, y2 = canvas.y2 }
        local column_width = self:tileColumn(getColumn(space, col), bounds)
        x = math.min(x + column_width + self.window_gap, right_margin)
    end

    -- tile windows from anchor left
    local x2 = math.max(anchor_frame.x - self.window_gap, left_margin)
    for col = anchor_index.col - 1, 1, -1 do
        local bounds = { x = nil, x2 = x2, y = canvas.y, y2 = canvas.y2 }
        local column_width = self:tileColumn(getColumn(space, col), bounds)
        x2 = math.max(x2 - column_width - self.window_gap, left_margin)
    end
end

--- PaperWM:refreshWindows()
--- Method
--- Searches for all windows that match window filter.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean, true if the layout needs to be re-tiled, false if no change.
function PaperWM:refreshWindows()
    -- get all windows across spaces
    local all_windows = self.window_filter:getWindows()

    local refresh_needed = false
    for _, window in ipairs(all_windows) do
        local index = index_table[window:id()]
        if not index then
            -- add window
            self:addWindow(window)
            refresh_needed = true
        elseif index.space ~= Spaces.windowSpaces(window)[1] then
            -- move to window list in new space
            self:removeWindow(window)
            self:addWindow(window)
            refresh_needed = true
        end
    end

    return refresh_needed
end

--- PaperWM:addWindow(add_window)
--- Method
--- Adds a window to layout and tiles.
---
--- Parameters:
---  * add_window - An hs.window
---
--- Returns:
---  * The hs.spaces space for added window or nil if window not added.
function PaperWM:addWindow(add_window)
    -- check if window is already in window list
    if index_table[add_window:id()] then return end

    local space = Spaces.windowSpaces(add_window)[1]
    if not space then
        self.logger.e("add window does not have a space")
        return
    end
    if not window_list[space] then window_list[space] = {} end

    -- find where to insert window
    local add_column = 1

    -- when addWindow() is called from a window created event:
    -- focused_window from previous window focused event will not be add_window
    -- hs.window.focusedWindow() will return add_window
    -- new window focused event for add_window has not happened yet
    if focused_window and
        ((index_table[focused_window:id()] or {}).space == space) and
        (focused_window:id() ~= add_window:id()) then
        add_column = index_table[focused_window:id()].col + 1 -- insert to the right
    else
        local x = add_window:frame().center.x
        for col, windows in ipairs(window_list[space]) do
            if x < windows[1]:frame().center.x then
                add_column = col
                break
            end
        end
    end

    -- add window
    table.insert(window_list[space], add_column, { add_window })

    -- update index table
    updateIndexTable(space, add_column)

    -- subscribe to window moved events
    local watcher = add_window:newWatcher(
        function(window, event, _, self)
            windowEventHandler(window, event, self)
        end, self)
    watcher:start({ Watcher.windowMoved, Watcher.windowResized })
    ui_watchers[add_window:id()] = watcher

    return space
end

--- PaperWM:remove_window(remove_window, skip_new_window_focus)
--- Method
--- Remove window from tiling layout
---
--- Parameters:
---  * remove_window - A hs.window to remove from tiling layout
---  * skip_new_window_focus - A boolean. True if a nearby window should not be
---                            focused after current window is removed.
---
--- Returns:
---  * The hs.spaces space for removed window.
function PaperWM:removeWindow(remove_window, skip_new_window_focus)
    -- get index of window
    local remove_index = index_table[remove_window:id()]
    if not remove_index then
        self.logger.e("remove index not found")
        return
    end

    if not skip_new_window_focus then -- find nearby window to focus
        for _, direction in ipairs({
            Direction.DOWN, Direction.UP, Direction.LEFT, Direction.RIGHT
        }) do if self:focusWindow(direction, remove_index) then break end end
    end

    -- remove window
    table.remove(window_list[remove_index.space][remove_index.col],
        remove_index.row)
    if #window_list[remove_index.space][remove_index.col] == 0 then
        table.remove(window_list[remove_index.space], remove_index.col)
    end

    -- remove watcher
    ui_watchers[remove_window:id()] = nil

    -- update index table
    index_table[remove_window:id()] = nil
    updateIndexTable(remove_index.space, remove_index.col)

    -- remove if space is empty
    if #window_list[remove_index.space] == 0 then
        window_list[remove_index.space] = nil
    end

    return remove_index.space -- return space for removed window
end

--- PaperWM:focusWindow(direction, focused_index)
--- Method
--- Change focus to a nearby window
---
--- Parameters:
---  * direction - One of Direction { LEFT, RIGHT, DOWN, UP }
---  * focused_index - The coordinates of the current window in the tiling layout
---
--- Returns:
---  * A boolean. True if a new window was focused. False if no nearby window
---    was found in that direction.
function PaperWM:focusWindow(direction, focused_index)
    if not focused_index then
        -- get current focused window
        focused_window = focused_window or Window.focusedWindow()
        if not focused_window then return false end

        -- get focused window index
        focused_index = index_table[focused_window:id()]
    end

    if not focused_index then
        self.logger.e("focused index not found")
        return false
    end

    -- get new focused window
    local new_focused_window
    if direction == Direction.LEFT or direction == Direction.RIGHT then
        -- walk down column, looking for match in neighbor column
        for row = focused_index.row, 1, -1 do
            new_focused_window = getWindow(focused_index.space,
                focused_index.col + direction, row)
            if new_focused_window then break end
        end
    elseif direction == Direction.UP or direction == Direction.DOWN then
        new_focused_window = getWindow(focused_index.space, focused_index.col,
            focused_index.row + (direction // 2))
    end

    if not new_focused_window then
        self.logger.d("new focused window not found")
        return false
    end

    -- focus new window, windowFocused event will be emited immediately
    new_focused_window:focus()
    return true
end

--- PaperWM:swapWindows(direction)
--- Method
--- Swaps window postions between current window and window in specified direction.
---
--- Parameters:
---  * direction - One of Direction { LEFT, RIGHT, DOWN, UP }
function PaperWM:swapWindows(direction)
    -- use focused window as source window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then return end

    -- get focused window index
    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    if direction == Direction.LEFT or direction == Direction.RIGHT then
        -- get target windows
        local target_index = { col = focused_index.col + direction }
        local target_column = window_list[focused_index.space][target_index.col]
        if not target_column then
            self.logger.d("target column not found")
            return
        end

        -- swap place in window list
        local focused_column =
            window_list[focused_index.space][focused_index.col]
        window_list[focused_index.space][target_index.col] = focused_column
        window_list[focused_index.space][focused_index.col] = target_column

        -- update index table
        for row, window in ipairs(target_column) do
            index_table[window:id()] = {
                space = focused_index.space,
                col = focused_index.col,
                row = row
            }
        end
        for row, window in ipairs(focused_column) do
            index_table[window:id()] = {
                space = focused_index.space,
                col = target_index.col,
                row = row
            }
        end

        -- swap frames
        local focused_frame = focused_window:frame()
        local target_frame = target_column[1]:frame()
        if direction == Direction.LEFT then
            focused_frame.x = target_frame.x
            target_frame.x = focused_frame.x2 + self.window_gap
        else -- Direction.RIGHT
            target_frame.x = focused_frame.x
            focused_frame.x = target_frame.x2 + self.window_gap
        end
        for _, window in ipairs(target_column) do
            local frame = window:frame()
            frame.x = target_frame.x
            self:moveWindow(window, frame)
        end
        for _, window in ipairs(focused_column) do
            local frame = window:frame()
            frame.x = focused_frame.x
            self:moveWindow(window, frame)
        end
    elseif direction == Direction.UP or direction == Direction.DOWN then
        -- get target window
        local target_index = {
            space = focused_index.space,
            col = focused_index.col,
            row = focused_index.row + (direction // 2)
        }
        local target_window = getWindow(target_index.space, target_index.col,
            target_index.row)
        if not target_window then
            self.logger.d("target window not found")
            return
        end

        -- swap places in window list
        window_list[target_index.space][target_index.col][target_index.row] =
            focused_window
        window_list[focused_index.space][focused_index.col][focused_index.row] =
            target_window

        -- update index table
        index_table[target_window:id()] = focused_index
        index_table[focused_window:id()] = target_index

        -- swap frames
        local focused_frame = focused_window:frame()
        local target_frame = target_window:frame()
        if direction == Direction.UP then
            focused_frame.y = target_frame.y
            target_frame.y = focused_frame.y2 + self.window_gap
        else -- Direction.DOWN
            target_frame.y = focused_frame.y
            focused_frame.y = target_frame.y2 + self.window_gap
        end
        self:moveWindow(focused_window, focused_frame)
        self:moveWindow(target_window, target_frame)
    end

    -- update layout
    self:tileSpace(focused_index.space)
end

--- PaperWM:centerWindow()
--- Method
--- Moves current window to center of screen, without resizing.
---
--- Parameters:
---  * None
function PaperWM:centerWindow()
    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then return end

    -- get global coordinates
    local focused_frame = focused_window:frame()
    local screen_frame = focused_window:screen():frame()

    -- center window
    focused_frame.x = screen_frame.x + (screen_frame.w // 2) -
        (focused_frame.w // 2)
    self:moveWindow(focused_window, focused_frame)

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    self:tileSpace(space)
end

--- PaperWM:setWindowFullWidth()
--- Method
--- Resizes current window's width to width of screen, without adjusting height.
---
--- Parameters:
---  * None
function PaperWM:setWindowFullWidth()
    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then return end

    -- fullscreen window width
    local canvas = getCanvas(focused_window:screen())
    local focused_frame = focused_window:frame()
    focused_frame.x, focused_frame.w = canvas.x, canvas.w
    self:moveWindow(focused_window, focused_frame)

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    self:tileSpace(space)
end

--- PaperWM:cycleWindowSize(direction)
--- Method
--- Resizes current window by cycling through width or height ratios.
---
--- Parameters:
---  * direction - One of Direction { WIDTH, HEIGHT }
function PaperWM:cycleWindowSize(direction)
    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then return end

    local function findNewSize(area_size, frame_size)
        -- calculate pixel widths from ratios
        local sizes <const> = { 0.38195, 0.5, 0.61804 }
        for index, size in ipairs(sizes) do
            sizes[index] = size * area_size
        end

        -- find new size
        local new_size = sizes[1]
        for _, size in ipairs(sizes) do
            if size > frame_size + 10 then
                new_size = size
                break
            end
        end

        return new_size
    end

    local canvas = getCanvas(focused_window:screen())
    local focused_frame = focused_window:frame()

    if direction == Direction.WIDTH then
        local new_width = findNewSize(canvas.w, focused_frame.w)
        focused_frame.x = focused_frame.x + ((focused_frame.w - new_width) // 2)
        focused_frame.w = new_width
    elseif direction == Direction.HEIGHT then
        local new_height = findNewSize(canvas.h, focused_frame.h)
        focused_frame.y = math.max(canvas.y, focused_frame.y +
            ((focused_frame.h - new_height) // 2))
        focused_frame.h = new_height
        focused_frame.y = focused_frame.y -
            math.max(0, focused_frame.y2 - canvas.y2)
    end

    -- apply new size
    self:moveWindow(focused_window, focused_frame)

    -- update layout
    local space = Spaces.windowSpaces(focused_window)[1]
    self:tileSpace(space)
end

--- PaperWM:slurpWindow()
--- Method
--- Moves current window into column of windows to the left
---
--- Parameters:
---  * None
function PaperWM:slurpWindow()
    -- TODO paperwm behavior:
    -- add top window from column to the right to bottom of current column
    -- if no colum to the right and current window is only window in current column,
    -- add current window to bottom of column to the left

    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then return end

    -- get window index
    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    -- get column to left
    local column = window_list[focused_index.space][focused_index.col - 1]
    if not column then
        self.logger.d("column not found")
        return
    end

    -- remove window
    table.remove(window_list[focused_index.space][focused_index.col],
        focused_index.row)
    if #window_list[focused_index.space][focused_index.col] == 0 then
        table.remove(window_list[focused_index.space], focused_index.col)
    end

    -- append to end of column
    table.insert(column, focused_window)

    -- update index table
    local num_windows = #column
    index_table[focused_window:id()] = {
        space = focused_index.space,
        col = focused_index.col - 1,
        row = num_windows
    }
    updateIndexTable(focused_index.space, focused_index.col)

    -- adjust window frames
    local canvas = getCanvas(focused_window:screen())
    local bounds = {
        x = column[1]:frame().x,
        x2 = nil,
        y = canvas.y,
        y2 = canvas.y2
    }
    local h = math.max(0, canvas.h - ((num_windows - 1) * self.window_gap)) //
        num_windows
    self:tileColumn(column, bounds, h)

    -- update layout
    self:tileSpace(focused_index.space)
end

--- PaperWM:barfWindow()
--- Method
--- Removes current window from column and places it to the right
---
--- Parameters:
---  * None
function PaperWM:barfWindow()
    -- TODO paperwm behavior:
    -- remove bottom window of current column
    -- place window into a new column to the right--

    -- get current focused window
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then return end

    -- get window index
    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    -- get column
    local column = window_list[focused_index.space][focused_index.col]
    if #column == 1 then
        self.logger.d("only window in column")
        return
    end

    -- remove window and insert in new column
    table.remove(column, focused_index.row)
    table.insert(window_list[focused_index.space], focused_index.col + 1,
        { focused_window })

    -- update index table
    updateIndexTable(focused_index.space, focused_index.col)

    -- adjust window frames
    local num_windows = #column
    local canvas = getCanvas(focused_window:screen())
    local focused_frame = focused_window:frame()
    local bounds = { x = focused_frame.x, x2 = nil, y = canvas.y, y2 = canvas.y2 }
    local h = math.max(0, canvas.h - ((num_windows - 1) * self.window_gap)) //
        num_windows
    focused_frame.y = canvas.y
    focused_frame.x = focused_frame.x2 + self.window_gap
    focused_frame.h = canvas.h
    self:moveWindow(focused_window, focused_frame)
    self:tileColumn(column, bounds, h)

    -- update layout
    self:tileSpace(focused_index.space)
end

--- PaperWM:switchToSpace(index)
--- Method
--- Switch to a Mission Control space
---
--- Parameters:
---  * index - The space number
function PaperWM:switchToSpace(index)
    local space = getSpace(index)
    if not space then
        self.logger.d("space not found")
        return
    end

    Spaces.gotoSpace(space)
end

--- PaperWM:moveWindowToSpace(index)
--- Method
--- Moves the current window to a new Mission Control space
---
--- Parameters:
---  * index - The space number
function PaperWM:moveWindowToSpace(index)
    focused_window = focused_window or Window.focusedWindow()
    if not focused_window then
        self.logger.d("focused window not found")
        return
    end

    local focused_index = index_table[focused_window:id()]
    if not focused_index then
        self.logger.e("focused index not found")
        return
    end

    local new_space = getSpace(index)
    if not new_space then
        self.logger.d("space not found")
        return
    end

    if Spaces.spaceType(new_space) ~= "user" then
        self.logger.d("space is invalid")
        return
    end

    local screen = Screen(Spaces.spaceDisplay(new_space))
    if not screen then
        self.logger.d("screen not found")
        return
    end

    -- cache a local copy, removeWindow() will clear global focused_window
    local focused_window = focused_window
    local old_space = self:removeWindow(focused_window)
    if not old_space then
        self.logger.e("can't remove focused window")
        return
    end

    Spaces.moveWindowToSpace(focused_window, new_space)
    self:addWindow(focused_window)
    self:tileSpace(old_space)
    self:tileSpace(new_space)
    Spaces.gotoSpace(new_space)
end

--- PaperWM::moveWindow(window, frame)
--- Method
--- Resizes a window without triggering a windowMoved event
---
--- Parameters:
---  * window - An hs.window
---  * frame - An hs.geometry.rect for the windows new frame size.
function PaperWM:moveWindow(window, frame)
    -- greater than 0.017 hs.window animation step time
    local padding <const> = 0.02

    local watcher = ui_watchers[window:id()]
    if not watcher then
        self.logger.e("window does not have ui watcher")
        return
    end

    if frame == window:frame() then
        self.logger.v("no change in window frame")
        return
    end

    watcher:stop()
    window:setFrame(frame)
    DoAfter(Window.animationDuration + padding, function()
        watcher:start({ Watcher.windowMoved, Watcher.windowResized })
    end)
end

return PaperWM
