(*
@author Thanh Pham
@URL www.asianefficiency.com
@lastmod 10 Jun 2012

Imagine you are capturing a lot of notes and you want to later review
them in Omnifocus? Most of the time you will forget transferring the
notes into your Omnifocus inbox. This script will help automate this process.

For every note that you want to review, all you have to do is
tag it with "review" (without quotes) and this script will
automatically make a new task in your Omnifocus inbox for review
that links back to your Evernote note.

By default the format of the task is:

"Review: title of your Evernote note" (without the quotes)

Once the task is created, the script will delete the tag from
the note in Evernote.

REQUIREMENTS:
* Evernote
* Omnifocus

Credit goes to Nick Wild of 360 Degree Media (www.360degreesmedia.com/)
for the original script. All I have done is modified some bits and pieces,
but all credit should go to Nick Wild.

If you want to have this script run automatically on a regular interval,
use the program Lingon. Read this blog post on how to do it:

http://www.asianefficiency.com/technology/transfer-evernote-to-omnifocus/

Have fun with the script. If you like it, please leave a comment
on the post mentioned above.

-Thanh Pham
www.asianefficiency.com
*)

-- You can change the variables below to customize it to your liking.

########### CAN EDIT ###########

-- the name of the task starts by default with "Review: " (without quotes)
-- change this to your liking
property taskPrefix : "Review: "

########### CAN EDIT ###########

on run argv

	set strNoteCreated to (localized string "CREATED_LABEL")
	set strTodosCreatedOne to (localized string "TODOS_CREATED_ONE")
	set strTodosCreatedMany to (localized string "TODOS_CREATED_MANY")

	set theTodoList to {}

	try

		tell application "Evernote"
			(* set currentNote to selection
	set currentNoteName to (title of item 1 of currentNote)
	set currentID to (local id of item 1 of currentNote) *)

			set savedDelimiters to AppleScript's text item delimiters
			set AppleScript's text item delimiters to {"/"}

			-- selected notes
			set foundNotes to selection

			repeat with aNote in foundNotes
				set enTitle to (the title of aNote)
				set enTitle to taskPrefix & enTitle
				set enTags to (the tags of aNote)
				--set enId to (the local id of aNote)
				--set enFile to (the last text item of enId)
				set enLink to note link of aNote
				set end of theTodoList to {theTitle:enTitle, thelink:enLink, theTags:enTags}

				set ennotename to taskPrefix & enTitle
				set AppleScript's text item delimiters to savedDelimiters

				try
					tell front document of application "OmniFocus"
						if argv is {"nodialog"} then
							make new inbox task with properties {name:(enTitle), note:enLink}
						else
							tell quick entry
								make new inbox task with properties {name:(enTitle), note:enLink}
								open
							end tell
						end if
					end tell

				on error errmsg
					display dialog errmsg buttons {"Oops. Did you create the context?"}
				end try

			end repeat
		end tell

	on error errmsg
		display dialog errmsg buttons {"Oops. Couldn't find Evernote! Try changing paths."}
	end try

end run
