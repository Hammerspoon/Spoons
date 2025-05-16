--- === RandomBackground ===
---
--- Use Unsplash API to set a random background image for your desktop
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RandomBackground.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RandomBackground.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "RandomBackground"
obj.version = "1.0"
obj.author = "Rodrigo Medina <rodrigo.medina.neri@gmail.com>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local UPDATE_INTERVAL_SECONDS = 3 * 60 * 60 -- Interval to update background image. i.e. 3 hours
local UNSPLASH_API_URL = "https://api.unsplash.com/photos/random/?orientation=landscape&client_id=" -- Partial URL, passkey is missing

local logger = hs.logger.new(obj.name, "debug")

--- RandomBackground.curl_download_callback(exitCode, stdOut, stdErr) -> nil
--- Function
--- Callback for when the curl command finishes downloading the image.
---
--- This function is used internally by the RandomBackground Spoon.
--- It's intended to be used as a callback function for the 'hs.task' that downloads an image using the curl command.
---
--- Parameters:
---  * exitCode - A number containing the exit code of the task.
---  * stdOut - A string containing the standard output of the task.
---  * stdErr - A string containing the standard error of the task.
---
--- Returns:
---  * None.
---
--- Notes:
---  * If the task finishes successfully (exitCode == 0), this function sets the downloaded image as the desktop background on the main screen and logs a success message.
---  * If the task does not finish successfully, this function logs an error message along with the standard output and standard error of the task.
function obj.curl_download_callback(exitCode, stdOut, stdErr)
	if exitCode == 0 then
		obj.task = nil
		hs.screen.mainScreen():desktopImageURL("file://" .. obj.localpath)
		logger.d("New background set successfully")
	else
		logger.d("Error downloading image from parsed JSON API response")
		logger.d(stdOut, stdErr)
	end
end

--- RandomBackground.get_download_link(response_body)
--- Function
--- Extracts and returns the download link from a response body.
---
--- This function is used internally by the RandomBackground Spoon.
--- It's intended to be used to parse the response body from an Unsplash API call and extract the image download link.
---
--- Parameters:
---  * response_body - A string containing the response body, expected to be in JSON format.
---
--- Returns:
---  * If successful, a string containing the download link.
---  * If unsuccessful (due to the response body not being valid JSON or not containing a `links.download` field), it returns `nil`.
---
--- Notes:
---  * This function uses the protected call (`pcall`) function in Lua to handle potential errors when decoding the JSON response body.
---  * If the decoding fails (due to invalid JSON, for example), it will return `nil`.
function obj.get_download_link(response_body)
	local ok, decoded_data = pcall(hs.json.decode, response_body)
	if ok and decoded_data and decoded_data.links and decoded_data.links.download then
		return decoded_data.links.download
	else
		return nil
	end
end

--- RandomBackground.download_img_request(image_url)
--- Function
--- Downloads an image from a given URL and stores it in the system's Trash folder.
---
--- This function is intended to be used internally by the RandomBackground Spoon.
--- It is called by the `set_new_background` function once a suitable image URL has been fetched from the Unsplash API.
--- Prior to the download, it cancels any previous download task.
--- It then sets the download path to the system's Trash folder and initiates the download task using `hs.task.new`.
---
--- Parameters:
---  * image_url - A string containing the URL of the image to be downloaded.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function will log information about its progress, including the URL of the image being downloaded.
---  * The downloaded image file is saved with a hashed name to prevent naming conflicts.
---  * The image is saved in the Trash folder as it is intended to be a temp file used only for setting the wallpaper.
function obj.download_img_request(image_url)
	-- cancel any pending request
	if obj.task then
		obj.task:terminate()
		obj.task = nil
	end

	logger.d("Downloading image: " .. image_url)

	local temp_img_name = hs.hash.SHA1(hs.timer.absoluteTime())

	-- set as download path the Trash folder, as we only want to set the wallpaper once
	obj.localpath = os.getenv("HOME") .. "/.Trash/" .. temp_img_name .. "_background.jpg"
	obj.task = hs.task.new("/usr/bin/curl", obj.curl_download_callback, { "-L", image_url, "-o", obj.localpath })
	obj.task:start()
end

--- RandomBackground.set_new_background()
--- Function
--- Sets a new background for the system using a randomly fetched image from Unsplash.
---
--- This function is intended to be used internally by the RandomBackground Spoon.
--- It is triggered by a timer started in the `start()` method.
--- It sends an asynchronous GET request to the Unsplash API to fetch a random landscape image.
--- If the request is successful, it proceeds to download and set the image as the background.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This function will log information about its progress, including whether the API request and image parsing were successful,
---  and the remaining rate limit for the Unsplash API.
function obj.set_new_background()
	logger.d("Setting new background...")

	hs.http.asyncGet(obj.unsplash_api_url, {}, function(stat, body, header)
		logger.d("Received response from unsplash")
		logger.d("Remaining Rate Limit: ", header["X-Ratelimit-Remaining"])

		if stat ~= 200 then
			logger.d("Unsplash API get random image failed")
			return false
		end

		logger.d("Successful response status. Processing download link")

		local download_link = obj.get_download_link(body)
		if download_link == nil then
			logger.d("Unsplash API response JSON parsing failed")
			return false
		end

		logger.d("Successful download link parsing.")

		return pcall(obj.download_img_request, download_link)
	end)
end

--- RandomBackground:start()
--- Method
---
--- This method starts the RandomBackground spoon. It sets the URL for the Unsplash API with the provided API key.
--- and initiates the timer to change the desktop background.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `false` if the Unsplash API key is not provided or is an empty string. In this case, the method also logs an error message and stops the execution of the spoon.
---  * No explicit return (i.e., `nil`) in case of successful operation.
---
--- Notes:
---  * The Unsplash API key must be provided for this method to start the spoon successfully.
---  * If the key is not provided, the method will not start the spoon and will return `false`.
---  * If there's no existing timer, it creates a new one that triggers the `set_new_background` method every `UPDATE_INTERVAL_SECONDS` seconds.
---  * The first trigger happens after a 5-second delay.
---  * If a timer already exists, it simply restarts it.
---
--- Example usage:
--- spoon.RandomBackground:start()
function obj:start()
	if obj.unsplash_api_key == nil or obj.unsplash_api_key == "" then
		print("There's no Unsplash API key or it is empty.")
		return false
	end

	logger.d("Received API Key: ", obj.unsplash_api_key)

	obj.unsplash_api_url = UNSPLASH_API_URL .. obj.unsplash_api_key

	logger.d("Started the RandomBackground spoon")
	if obj.timer == nil then
		obj.timer = hs.timer.doEvery(UPDATE_INTERVAL_SECONDS, obj.set_new_background)
		obj.timer:setNextTrigger(5)
	else
		obj.timer:start()
	end
end

--- RandomBackground:stop()
--- Method
--- Stops the RandomBackground Spoon.
---
--- This function is used to stop the functionality of the RandomBackground Spoon.
--- If a timer has been started by the Spoon, it is stopped when this method is called.
---
--- Example usage:
--- spoon.RandomBackground:stop()
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This method stops the RandomBackground Spoon and any associated timers.
function obj:stop()
	logger.d("Stopped the RandomBackground spoon")
	if obj.timer ~= nil then
		obj.timer:stop()
	end
end

--- RandomBackground:init()
--- Method
--- Initializes the RandomBackground Spoon.
---
--- This function is called automatically by Hammerspoon during the creation of the Spoon object.
--- The initialization involves preparing resources that would be needed by the Spoon for later use.
--- Note: It is not recommended to start timers, watchers, or map hotkeys in this method.
---
--- The init method does not start the functionality of the RandomBackground spoon,
--- as the necessary API key from the config table is not accessible until the setup is completed (i.e., the start method is called).
---
--- Example usage:
--- spoon.RandomBackground:init()
---
--- Returns:
---  * None
---
--- Notes:
---  * The Hammerspoon user has the option to override the automatic calling of this method.
---  * For more details, see: https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#how-do-i-create-a-spoon
function obj:init()
	logger.d("Init the RandomBackground spoon")
end

return obj
