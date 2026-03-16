--- === FileWatcher ===
---
--- File organization spoon that watches directories and moves files based on rules
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FileWatcher.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FileWatcher.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "FileWatcher"
obj.version = "1.0"
obj.author = "Daniel Rodríguez"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- FileWatcher.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new("FileWatcher")

--- FileWatcher.watchers
--- Variable
--- Table containing all active directory watchers. This is managed internally by the Spoon.
obj.watchers = {}

local function expandTilde(path)
	if path:sub(1, 1) == "~" then
		return os.getenv("HOME") .. path:sub(2)
	end
	return path
end

local function ensureTrailingSlash(path)
	if path:sub(-1) ~= "/" then
		return path .. "/"
	end
	return path
end

local function getFilename(path)
	return path:match("([^/]+)$")
end

local function getFileExtension(filename)
	return filename:match("%.([^%.]+)$") or ""
end

local function getBasename(filename)
	local ext = getFileExtension(filename)
	if ext ~= "" then
		return filename:sub(1, #filename - #ext - 1)
	end
	return filename
end

local function directoryExists(path)
	local file = io.open(path, "r")
	if file then
		io.close(file)
		return true
	end
	return false
end

local function createDirectory(path)
	path = expandTilde(path)
	if directoryExists(path) then
		return true
	end
	return os.execute('mkdir -p "' .. path .. '"') == 0
end

--- FileWatcher:init()
--- Method
--- Initialize the spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The FileWatcher object
function obj:init()
	self.watchers = {}
	return self
end

--- FileWatcher:processFile(file, rules)
--- Method
--- Process a single file according to the given rules
---
--- Parameters:
---  * file - Full path to the file
---  * rules - Array of rules to apply
---
--- Returns:
---  * true if file was processed successfully, false otherwise
function obj:processFile(file, rules)
	local filename = getFilename(file)
	if not filename then
		return false
	end

	for _, rule in ipairs(rules) do
		local pattern = rule.pattern
		local destination = expandTilde(rule.destination)
		local action = rule.action or "move"

		if string.match(filename:lower(), pattern:lower()) then
			if action == "move" then
				-- Ensure destination directory exists
				if not createDirectory(destination) then
					self.logger.e(string.format("Failed to create directory %s", destination))
					return false
				end

				destination = ensureTrailingSlash(destination)
				local destPath = destination .. filename

				-- If file already exists at destination, append number
				local counter = 1
				while directoryExists(destPath) do
					local ext = getFileExtension(filename)
					local basename = getBasename(filename)
					destPath =
						string.format("%s%s_%d%s", destination, basename, counter, ext ~= "" and "." .. ext or "")
					counter = counter + 1
				end

				-- Move the file using os.rename
				local success, err = os.rename(file, destPath)
				if success then
					self.logger.i(string.format("Moved %s to %s", filename, destPath))
					-- Show notification
					hs.notify.new({
						title = "File Moved",
						informativeText = string.format("%s → %s", filename, destination:gsub(os.getenv("HOME"), "~")),
						withdrawAfter = 3
					}):send()
				else
					self.logger.e(string.format("Failed to move %s to %s: %s", filename, destPath, err))
				end
				return success
			end
		end
	end
	return false
end

--- FileWatcher:watchDirectory(directory, rules)
--- Method
--- Start watching a directory with the specified rules
---
--- Parameters:
---  * directory - Directory path to watch
---  * rules - Array of rules to apply to matching files
---
--- Returns:
---  * The FileWatcher object
---
--- Notes:
---  * Each rule should be a table with the following keys:
---    * pattern - Lua pattern to match filename (case-insensitive)
---    * destination - Path where matching files should be moved
---    * action - (optional) Action to take, currently only "move" is supported (default: "move")
---  * The directory path can use tilde (~) for the home directory
---  * Files are moved automatically when they appear in the watched directory
---  * If a file with the same name exists at the destination, a number will be appended
function obj:watchDirectory(directory, rules)
	-- Expand the directory path
	directory = expandTilde(directory)
	directory = ensureTrailingSlash(directory)
	self.logger.i("Attempt to watch directory: " .. directory)

	-- Create watcher for the directory
	local watcher = hs.pathwatcher.new(directory, function(files)
		for _, file in ipairs(files) do
			-- Check if it's a file (not a directory) using io.open
			local f = io.open(file, "r")
			if f then
				f:close()
				self:processFile(file, rules)
			end
		end
	end)

	-- Start the watcher
	watcher:start()

	-- Store the watcher
	self.watchers[directory] = {
		watcher = watcher,
		rules = rules,
	}

	self.logger.i(string.format("Started watching %s", directory))
	return self
end

--- FileWatcher:stopWatching(directory)
--- Method
--- Stop watching a directory
---
--- Parameters:
---  * directory - Directory path to stop watching
---
--- Returns:
---  * The FileWatcher object
function obj:stopWatching(directory)
	directory = expandTilde(directory)
	directory = ensureTrailingSlash(directory)

	if self.watchers[directory] then
		self.watchers[directory].watcher:stop()
		self.watchers[directory] = nil
		self.logger.i(string.format("Stopped watching %s", directory))
	end
	return self
end

--- FileWatcher:stopAllWatchers()
--- Method
--- Stop all directory watchers
---
--- Parameters:
---  * None
---
--- Returns:
---  * The FileWatcher object
function obj:stopAllWatchers()
	for directory, _ in pairs(self.watchers) do
		self:stopWatching(directory)
	end
	return self
end

--- FileWatcher:start()
--- Method
--- Starts all configured directory watchers
---
--- Parameters:
---  * None
---
--- Returns:
---  * The FileWatcher object
---
--- Notes:
---  * This method is provided for consistency with other Spoons
---  * Watchers are automatically started when you call :watchDirectory()
---  * This method is useful if you've stopped all watchers and want to restart them
function obj:start()
	-- Watchers are started automatically in watchDirectory
	-- This method is here for API consistency
	return self
end

--- FileWatcher:stop()
--- Method
--- Stops all directory watchers
---
--- Parameters:
---  * None
---
--- Returns:
---  * The FileWatcher object
function obj:stop()
	return self:stopAllWatchers()
end

return obj
