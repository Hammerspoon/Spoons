--- === Leanpub ===
---
--- Spoon to track and notify about Leanpub builds.
---
--- Download:
--- https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Leanpub.spoon.zip

local obj={}
obj.__index = obj

-- Metadata
obj.name     = "Leanpub"
obj.version  = "0.3"
obj.author   = "Diego Zamboni <diego@zzamboni.org>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license  = "MIT - https://opensource.org/licenses/MIT"

--- Leanpub.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the
--- default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Leanpub')

--- Leanpub.watch_books
--- Variable
--- List of books to watch (by default an empty list). Each element of
--- the list must be a table containing the following keys:
---  * slug - the web page "slug" of the book to watch. The slug of a
---    book can be set under the "Book Web Page / Web Page URL" menu
---    section in Leanpub.
---  * icon - optional icon to show in the notifications for the book,
---    as an hs.image object. If not specified, and if
---    `fetch_leanpub_covers` is `true`, then the icon is generated
---    automatically from the book cover.
---  * syncs_to_dropbox - optional boolean to indicate whether the
---    book is configured in Leanpub to sync to Dropbox (you can find
---    this option in your books "Writing mode" screen, as "Send
---    output to Dropbox". If true, the "Book generation complete"
---    notification will include a "Show" button to open the book's
---    directory in Dropbox. If you have multiple books and all of
---    them are synced to Dropbox, you can set the main
---    `Leanpub.books_sync_to_dropbox` variable instead of setting it
---    for each book. Default value: `false`
obj.watch_books = {}

--- Leanpub.books_sync_to_dropbox
--- Variable
--- Boolean that specifies whether all your books are being synced to
--- Dropbox. If true, the "Book generation complete" notification will
--- include a "Show" button to open the book's directory in
--- Dropbox. Setting this is equivalent to setting the
--- `syncs_to_dropbox` attribute for each book in
--- `watch_books`. Default value: `false`.
obj.books_sync_to_dropbox = false

--- Leanpub.api_key
--- Variable
--- String containing the key to use for Leanpub API requests. Get it
--- from your Leanpub account under the "Author / Your API Key" menu
--- section. No default.
obj.api_key = ""

--- Leanpub.check_interval
--- Variable
--- Integer containing the interval (in seconds) at which the book
--- status is checked. Default 5.
obj.check_interval = 5

--- Leanpub.fetch_leanpub_covers
--- Variable
--- Boolean indicating whether we should try to fetch book covers from
--- Leanpub. Default value: `true`.
obj.fetch_leanpub_covers = true

--- Leanpub.persistent_notification
--- Variable
--- Table specifying the Leanpub status for which notifications should
--- not disappear automatically. The indices correspond to the values
--- of the `status` field returned by the Leanpub API. Possible values
--- are `working` and `complete`. Default `{ complete = true }` to
--- keep the "Book generation complete" messages.
obj.persistent_notification = { complete = true, failure = true }

--- Leanpub.dropbox_path
--- Variable
--- String containing the base Dropbox path to which the books are
--- synced, if the corresponding parameters are set. If unset, the
--- path is determined automatically by reading the
--- ~/.dropbox/info.json file and choosing the path corresponding to
--- the profile specified in `Leanpub.dropbox_profile`. If for some
--- reason your synced files are somewhere else, you can store in this
--- variable the final path to use. Most users should be fine with the
--- defaults.
obj.dropbox_path = nil

--- Leanpub.dropbox_type
--- Variable
--- String containing the name of the Dropbox account type to use for
--- determining the base path of the Dropbox directory. Valid values
--- are "personal" and "business". See
--- https://help.dropbox.com/installs-integrations/desktop/locate-dropbox-folder
--- for the details. Default value: "personal".
obj.dropbox_type = "personal"

-- Internal function to get the Dropbox base path to use and store it
-- in obj.dropbox_path. In further calls the existing value is
-- returned.
function obj._dropboxPath()
  -- If the path is already specified, leave it alone
  if not obj.dropbox_path then
    -- Read the Dropbox info file
    local dropbox_data = hs.json.read(os.getenv("HOME").."/.dropbox/info.json")
    if dropbox_data then
      obj.dropbox_path = dropbox_data[obj.dropbox_type].path
    else
      obj.logger.e("Could not determine the Dropbox path, error reading ~/.dropbox/info.json")
    end
  end
  return obj.dropbox_path
end

--- Leanpub:getBookStatus(slug, callback)
--- Method
--- Asynchronously get the status of a book given its slug.
---
--- Parameters:
---  * slug - URL "slug" of the book to check. The slug of a book is
---    the part of the URL for your book after https://leanpub.com/.
---  * callback - function to which the book status will be passed
---    when the data is received. This function will be passed a
---    single argument, a table containing the fields returned by the
---    Leanpub API. If the book is not being built at the moment, an
---    empty table is passed. If an error occurs, the value passed
---    will be `nil`. Samples of the return values can be found at
---    https://leanpub.com/help/api#getting-the-job-status
---
--- Returns:
---  * No return value
function obj:getBookStatus(slug, callback)
  local url = string.format("https://leanpub.com/%s/job_status?api_key=%s",
                            slug, self.api_key)
  self.logger.df("Fetching status for book '%s'", slug)
  hs.http.asyncGet(url, {},
                   function(s, b, h)
                     self:_getBookStatusCallback(slug,s,b,h,callback)
                   end)
end

function obj:_getBookStatusCallback(slug,status,body,headers,callback)
  if status == 200 then
    self.logger.df("  Status of book '%s': %s", slug, body)
    callback(hs.json.decode(body))
  else
    -- status==0 means no network (which might be common if you use a
    -- laptop), so we don't produce an error in that case. Otherwise
    -- we print an error and call the callback with nil
    if status ~= 0 then
      self.logger.ef("  Error: %s %s %s", status, body, hs.inspect(headers))
      callback(nil)
    end
  end
end

obj.last_status = {}

--- Leanpub:displayBookStatus(book)
--- Method
--- Display a notification with the current build status of a book.
--- Only produce a notification if the current status is different
--- than the last known one (from the last time `displayBookStatus`
--- was run for the same book).
---
--- Parameters:
---  * book - table containing the information of the book to
---    check. The table must contain the following fields:
---    * slug - URL "slug" of the book to check. The slug is the part
---      of the book URL after https://leanpub.com/.
---    * icon - optional icon to show in the notifications for the
---      book, as an `hs.image` object. If this field is not specified
---      but `fetch_leanpub_covers` is true (the default value), this
---      method attempts to fetch the book cover from Leanpub. If the
---      cover can be retrieved, it gets stored in the icon field so
---      it doesn't get fetched every time. You can disable cover
---      fetching for individual books by setting this field
---      explicitly to `false`
---
--- Returns:
---  * A Lua table containing the status (may be empty), nil if an
---    error occurred
function obj:displayBookStatus(book)
  -- Fetches and stores the cover if needed
  self:fetchBookCover(book)
  -- Gets and displays the book status if needed
  self:getBookStatus(book.slug,
                     function(status)
                       self:_displayBookStatusCallback(book, status)
                     end)
end

-- This internal function gets called as a callback when the book
-- status information is retrieved by Leanpub:displayBookStatus(), and
-- actually does the job of displaying a notification if needed.
function obj:_displayBookStatusCallback(book, status)
  if status then
    local step = status.message or status.msg
    if step and step ~= self.last_status[book.slug] then
      -- Create base notification, with just the text
      local n = hs.notify.new(
        -- The notification callback function reveals the files in
        -- Dropbox when the "Show" button is pressed in the final
        -- notification.
        function (n) self:_bookCompleteCallback(book, status) end,
        -- The base information in the notification
        {
          title = status.name or book.slug,
          subTitle = string.format("Step %d of %d",status.num or 0,status.total or 0),
          informativeText = step
        }
      )
      -- If we have an icon, put it in the notification
      if book.icon then
        n:setIdImage(book.icon)
      end
      -- If message should be persistent, set timeout to 0
      if self.persistent_notification[status.status or status.response] then
        n:withdrawAfter(0)
      end
      -- If the message corresponds to the end of the build process
      -- (i.e. its status is "complete), enable the action buttons to
      -- reveal the synced files in Dropbox, if configured to do so.
      if status.status == "complete" then
        if self.books_sync_to_dropbox or book.syncs_to_dropbox then
          n:hasActionButton(true)
        end
      end
      -- Finally! Generate the notification.
      n:send()
    end
    self.last_status[book.slug] = step
  end
end

-- This internal function gets called when the user clicks the "Show"
-- button or the notification itself in the final notification of the
-- book process. If the general Leanpub.books_sync_to_dropbox or the
-- book's individual syncs_to_dropbox attributes are true, the
-- corresponding Dropbox folder is revealed in the finder. Leanpub
-- stores the files in the following folders:
--  ~/Dropbox/<book-slug>-output/preview - preview/subset files
--  ~/Dropbox/<book-slug>-output/published - published files
-- The corresponding folder is opened depending on the build type.
function obj:_bookCompleteCallback(book, status)
  self.logger.df("_bookCompleteCallback.\nbook = %s\nstatus = %s",
                 hs.inspect(book), hs.inspect(status))
  if status.status == "complete" then
    if self.books_sync_to_dropbox or book.syncs_to_dropbox then
      local subdir = ""
      if string.find(status.job_type, "preview") then
        subdir = "/preview"
      elseif string.find(status.job_type, "publish") or string.find(status.job_type, "EmailPossibleReaders") then
        subdir = "/published"
      end
      local path = self._dropboxPath().."/"..book.slug.."-output"..subdir
      self.logger.df("  opening %s", path)
      if not hs.open(path) then
        self.logger.ef("Error opening %s", path)
      end
    end
  end
end

--- Leanpub:fetchBookCover(book)
--- Method
--- Fetch the cover of a book.
---
--- Parameters:
---  * book - table containing the book information. The icon gets
---    stored in its `icon` field when it can be fetched.
---
--- Returns:
---  * No return value
---
--- Side effects:
---  * Stores the icon in the book data structure
function obj:fetchBookCover(book)
  -- If no icon is given, fetch it from Leanpub. Explicitly check
  -- against nil to allow disabling the icon by specifying its
  -- value as `false`
  if book.icon == nil and self.fetch_leanpub_covers then
    local url = string.format("https://leanpub.com/%s.json?api_key=%s",
                              book.slug, self.api_key)
    self.logger.df("Fetching info for book '%s'", book.slug)
    hs.http.asyncGet(url, {},
                     function(s,b,h)
                       self:_fetchBookCoverCallback(book,s,b,h)
                     end)
  end
end

function obj:_fetchBookCoverCallback(book, status, body, headers)
  if status == 200 then
    local info = hs.json.decode(body)
    book.icon = hs.image.imageFromURL(info.title_page_url or "")
    if book.icon == nil then
      self.logger.df("No cover available from Leanpub for book '%s'", book.slug)
      book.icon = false
    else
      self.logger.df("Storing cover for book '%s'", book.slug)
    end
  end
end

--- Leanpub:displayAllBookStatus()
--- Method
--- Check and display (if needed) the status of all the books in `watch_books`
---
--- Parameters:
---  * None
function obj:displayAllBookStatus()
  for i,book in ipairs(self.watch_books) do
    self:displayBookStatus(book)
  end
end

obj.timer = nil

--- Leanpub:start()
--- Method
--- Start periodic check for book status, checking every
--- check_interval seconds.
---
--- Parameters:
---  * None
function obj:start()
  self.timer = hs.timer.new(self.check_interval,
                            function()
                              self:displayAllBookStatus()
                            end):start()
end

--- Leanpub:stop()
--- Method
--- Stops periodic check for book status, if enabled.
--- check_interval seconds.
---
--- Parameters:
---  * None
function obj:stop()
  if self.timer ~= nil then
    self.timer:stop()
    self.timer = nil
  end
end

return obj
