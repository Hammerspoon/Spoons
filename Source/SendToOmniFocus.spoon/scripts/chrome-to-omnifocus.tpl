set urlList to {}
set currentTab to 0
tell application "${app}"
  set chromeWindow to the front window
  set t to active tab of chromeWindow
  set tabTitle to (title of t)
  set tabURL to (URL of t)
  tell front document of application "OmniFocus"
    ${quickentry_open}
      make new inbox task with properties {name:("Review: " & tabTitle), note:tabURL as text}
    ${quickentry_close}
  end tell
  display notification "Successfully exported ${item} '" & tabTitle & "' to OmniFocus" with title "Send ${item} to OmniFocus"
end tell
