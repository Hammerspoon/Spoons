(*
Veritrope.com
Outlook 2011 to Omnifocus
VERSION 1.11
May 31, 2014

// SCRIPT INFORMATION AND UPDATE PAGE
http://veritrope.com/code/outlook-2011-to-omnifocus

// REQUIREMENTS
THIS SCRIPT REQUIRES OS X 10.9+ AND OUTLOOK 2011 SP1 OR GREATER!
More details on the script information page.

// CHANGELOG
1.11  ADDED SWITCH TO DISABLE ATTACHMENTS, CHANGE FROM APPLICATION NAME TO BUNDLE ID TO AVOID VIRTUAL MACHINE CONFLICTS WITH OUTLOOK
1.10  FIX FOR OMNIFOCUS 2.0, GROWL/NOTIFICATION CENTER SWITCH, STARTING TO INTEGRATE NOTIFICATION CENTER
1.01  ADDED ORGANIZER INFO FOR MEETINGS
1.00  FINAL (UPDATED GROWL CODE)
1.00  BETA 1 - ASSORTED BUG FIXES
0.99  REVISED GROWL CODE
0.98  INITIAL RELEASE

// RECOMMENDED INSTALLATION INSTRUCTIONS:
1.) Save this script to ~/Documents/Microsoft User Data/Outlook Script Menu Items (Or Its Equivalent in Localized Language);
(You can navigate quickly to this folder by selecting:
 Outlook's Script Menu => About This Menu... => Open Folder)

2.) Give it a filename that enables a keyboard shortcut to be used.

Example:
Saving the script with the name "Send to OmniFocus\mO.scpt" lets you press Cmd-O to send items to Evernote!

3.) Enjoy!

// TERMS OF USE:
This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View, California, 94041, USA.

*)

(*
======================================
// USER SWITCHES (YOU CAN CHANGE THESE!)
======================================
*)

--SET THIS TO "ON" IF YOU PREFER GROWL NOTIFICATIONS
--TO OSX'S NOTIFICATION CENTER (DEFAULT IS "OFF")
property growlSwitch : "OFF"

--SET THIS TO "OFF" IF YOU PREFER TO DISABLE
--ATTACHMENT PROCESSING (DEFAULT IS "ON")
property attachSwitch : "ON"


(*
======================================
// OTHER PROPERTIES (USE CAUTION WHEN CHANGING)
======================================
*)
property successCount : 0
property growl_Running : "false"
property myTitle : "Item"
property theAttachments : ""
property thisMessage : ""
property itemNum : "0"
property attNum : "0"
property errNum : "0"
property errorText : ""
property the_class : ""
property list_Props : {}
property SaveLoc : ""
property NewTask : {}

(*
======================================
// MAIN PROGRAM
======================================
*)

on run argv

	--LET'S GO!
	try
		--CHECK FOR GROWL SWITCH
		if growlSwitch is "ON" then my startGrowl()

		--SET UP ACTIVITIES
		set selectedItems to {}

		set selectedItems to my item_Check()

		--MESSAGES SELECTED?
		if selectedItems is not missing value then
			--GET FILE COUNT
			my item_Count(selectedItems, the_class)

			--ANNOUNCE THE EXPORT OF ITEMS
			my process_Items(itemNum, attNum, the_class)

			--PROCESS ITEMS FOR EXPORT
			my item_Process(selectedItems, argv)

			--DELETE TEMP FOLDER IF IT EXISTS
			set success to my trashfolder(SaveLoc)

			--NO ITEMS SELECTED
		else
			set successCount to -1
		end if


		--GROWL RESULTS
		if growlSwitch is "ON" then
			my growl_Growler(successCount, itemNum)
		else
			my notification_Center(successCount, itemNum)
		end if

		-- ERROR HANDLING
	on error errText number errNum
		tell application "System Events"
			set isGrlRunning to (count of (every process whose bundle identifier is "com.Growl.GrowlHelperApp")) > 0
		end tell

		ignoring application responses
			if isGrlRunning then
				if errNum is -128 then
					set part_1 to "tell application \"Growl\"
                "
					set part_2 to "notify with name \"Failure Notification\" title \"User Cancelled\" description \"User Cancelled\" application name \"Outlook to OmniFocus\"
                    end tell"
				else
					-- GROWL FAILURE FOR ERROR
					set part_2 to "notify with name \"Failure Notification\" title \"Import Failure\" description \"Failed to export due to the following error: \" & return & errText application name \"Outlook to OmniFocus\"
            end tell"
				end if

				-- NON-GROWL ERROR MSG. FOR ERROR
				display dialog "Item Failed to Import: " & errNum & return & errText with icon 0
			end if
		end ignoring
	end try

end run

(*
======================================
// PREPARATORY SUBROUTINES
======================================
*)

--APP DETECT
on appIsRunning(appName)
	tell application "System Events" to (name of processes) contains appName
end appIsRunning

--SET UP ACTIVITIES
on item_Check()
	tell application id "com.microsoft.Outlook"
		try -- GET MESSAGES
			set selectedItems to selection
			set raw_Class to (class of selectedItems)
			if raw_Class is list then
				set classList to {}
				repeat with selectedItem in selectedItems
					copy class of selectedItem to end of classList
				end repeat
				if classList contains task then
					set the_class to "Task"
				else
					set raw_Class to (class of item 1 of selectedItems)
				end if
			end if
			if raw_Class is calendar event then set the_class to "Calendar"
			if raw_Class is note then set the_class to "Note"
			if raw_Class is task then set the_class to "Task"
			if raw_Class is contact then set the_class to "Contact"
			if raw_Class is incoming message then set the_class to "Message"
			if raw_Class is text then set the_class to "Text"
		end try
		return selectedItems
	end tell
end item_Check

--GET COUNT OF ITEMS AND ATTACHMENTS
on item_Count(selectedItems, the_class)
	tell application id "com.microsoft.Outlook"
		if the_class is not "Text" then
			set itemNum to [count of selectedItems]
			set attNum to 0
			try
				repeat with selectedMessage in selectedItems
					set attNum to attNum + (count of attachment of selectedMessage)
				end repeat
			end try
		else
			set itemNum to 1
		end if
	end tell
end item_Count

(*
======================================
// PROCESS OUTLOOK ITEMS SUBROUTINE
======================================
*)

on item_Process(selectedItems, argv)
	tell application id "com.microsoft.Outlook"

		--TEXT ITEM CLIP
		if (class of selectedItems) is text then
			set OFTitle to selectedItems
			set theContent to "Text Clipping from Outlook"

			--CREATE IN OMNIFOCUS
			tell front document of application "OmniFocus"
				if argv is {"nodialog"} then
					set NewTask to make new inbox task with properties {name:OFTitle, note:theContent}
				else
					tell quick entry
						set NewTask to make new inbox task with properties {name:OFTitle, note:theContent}
						open
					end tell
				end if

			end tell

			--ITEM HAS FINISHED -- COUNT IT AS A SUCCESS!
			set successCount to 1
		else
			--FULL ITEM EXPORT
			repeat with selectedItem in selectedItems
				set theProps to (properties of selectedItem)
				try
					set theAttachments to attachments of selectedItem
					set raw_Attendees to attendees of selectedItem
				end try

				--SET UP SOME VALUES
				set theCompletionDate to missing value
				set theStartDate to missing value
				set theDueDate to missing value
				set theFlag to false

				-- GET OUTLOOK ITEM INFORMATION
				set the_vCard to {}

				--WHAT KIND OF ITEM IS IT?
				if the_class is "Calendar" then

					(* // CALENDAR ITEM *)

					--PREPARE THE TEMPLATE
					--LEFT SIDE (FORM FIELDS)
					set l_1 to "Event:  "
					set l_2 to "Start Time:  "
					set l_3 to "End Time:  "
					set l_4 to "Location:  "
					set l_5 to "Notes  :"

					--RIGHT SIDE (DATA FIELDS)
					set r_1 to (subject of theProps)
					set r_2 to (start time of theProps)
					set r_3 to (end time of theProps)
					set the_Location to (location of theProps)
					if the_Location is missing value then set the_Location to "None"
					set r_4 to the_Location

					--THE NOTES
					set the_notes to ""
					set item_Created to (current date)
					try
						set the_notes to (plain text content of theProps)
					end try
					if the_notes is missing value then set the_notes to ""

					--ADD ATTENDEE INFO IF IT'S A MEETING
					if (count of raw_Attendees) > 0 then
						set the_Organizer to "<strong>Organized By: </strong><br/>" & (organizer of selectedItem) & "<br/><br/>"
						set the_Attendees to "Invited Attendees: " & return
						repeat with raw_Attendee in raw_Attendees

							--GET ATTENDEE DATA
							set raw_EmailAttendee to (email address of raw_Attendee)
							set attend_Name to (name of raw_EmailAttendee) as text
							set raw_Status to (status of raw_Attendee)

							--COERCE STATUS TO TEXT
							if raw_Status contains not responded then
								set attend_Status to "Not Responded"
							else if raw_Status contains accepted then
								set attend_Status to "Accepted"
							else if raw_Status contains declined then
								set attend_Status to "Declined"
							else if raw_Status contains tentatively accepted then
								set attend_Status to "Tentatively Accepted"
							end if

							--COMPILE THE ATTENDEE DATA
							set attend_String to attend_Name & " (" & attend_Status & ")" & return
							set the_Attendees to the_Attendees & attend_String
						end repeat
						set the_notes to (the_Organizer & the_Attendees & the_notes)
						set raw_Attendees to ""
					end if

					--ASSEMBLE THE TEMPLATE
					set theContent to l_1 & r_1 & return & l_2 & r_2 & return & l_3 & r_3 & return & l_4 & r_4 & return & return & return & return & the_notes & return & return

					--EXPORT VCARD DATA
					try
						set vcard_data to (icalendar data of theProps)
						set vcard_extension to ".ics"
						set the_vCard to my write_File(r_1, vcard_data, vcard_extension)
					end try

					set OFTitle to r_1

					(* // NOTE ITEM *)
				else if the_class is "note" then

					--PREPARE THE TEMPLATE
					--LEFT SIDE (FORM FIELDS)
					set l_1 to "Note:  "
					set l_2 to "Creation Date:  "
					set l_3 to "Category:  "
					set l_4 to ""
					set l_5 to "Notes:  "

					--RIGHT SIDE (DATA FIELDS)
					set r_1 to name of theProps
					set item_Created to creation date of theProps
					set r_2 to (item_Created as text)

					--GET CATEGORY INFO
					set the_Cats to (category of theProps)
					set list_Cats to {}
					set count_Cat to (count of the_Cats)
					repeat with the_Cat in the_Cats
						set cat_Name to (name of the_Cat as text)
						copy cat_Name to the end of list_Cats
						if count_Cat > 1 then
							copy ", " to the end of list_Cats
							set count_Cat to (count_Cat - 1)
						else
							set count_Cat to (count_Cat - 1)
						end if
					end repeat

					set r_3 to list_Cats
					set r_4 to ""

					set item_Created to creation date of theProps

					--THE NOTES
					try
						set the_notes to plain text content of theProps
					end try
					if the_notes is missing value then set the_notes to ""

					--ASSEMBLE THE TEMPLATE
					set theContent to l_1 & r_1 & return & l_2 & r_2 & return & l_3 & r_3 & return & l_4 & r_4 & return & return & return & return & the_notes & return & return

					--EXPORT VCARD DATA
					set vcard_data to (icalendar data of theProps)
					set vcard_extension to ".ics"
					set the_vCard to my write_File(r_1, vcard_data, vcard_extension)

					set theHTML to true
					set OFTitle to r_1

					(* // CONTACT ITEM *)
				else if the_class is "contact" then

					--PREPARE THE TEMPLATE
					--LEFT SIDE (FORM FIELDS)
					set l_1 to "Name:  "
					set l_2 to "Email:  "
					set l_3 to "Phone Numbers:" & return
					set l_4 to "Addresses:" & return
					set l_5 to "Notes:"

					--GET EMAIL INFO
					try
						set list_Addresses to {}
						set email_Items to (email addresses of theProps)
						repeat with email_Item in email_Items
							set the_Type to (type of email_Item as text)
							set addr_Item to (address of email_Item) & " (" & my TITLECASE(the_Type) & ")" & return as text
							copy addr_Item to the end of list_Addresses
						end repeat
					end try

					--GET PHONE INFO AND ENCODE TELEPHONE LINK
					try
						set list_Phone to {}
						if business phone number of theProps is not missing value then
							set b_Number to (business phone number of theProps)
							set b_String to "-Work:  " & b_Number & return
							copy b_String to end of list_Phone
						end if
						if home phone number of theProps is not missing value then
							set h_Number to (home phone number of theProps)
							set h_String to "-Home:  " & h_Number & return
							copy h_String to end of list_Phone
						end if
						if mobile number of theProps is not missing value then
							set m_Number to (mobile number of theProps)
							set m_String to "-Mobile:  " & m_Number & return
							copy m_String to end of list_Phone
						end if
					end try

					--GET ADDRESS INFO
					try
						set list_Addr to {}

						(*BUSINESS *)
						if business street address of theProps is not missing value then
							set b_Str to (business street address of theProps)
							set b_gStr to my encodedURL(b_Str)
							if (business city of theProps) is not missing value then
								set b_Cit to (business city of theProps)
								set b_gCit to my encodedURL(b_Cit)
							else
								set b_Cit to ""
								set b_gCit to ""
							end if
							if (business state of theProps) is not missing value then
								set b_Sta to (business state of theProps)
								set b_gSta to my encodedURL(b_Sta)
							else
								set b_Sta to ""
								set b_gSta to ""
							end if
							if (business zip of theProps) is not missing value then
								set b_Zip to (business zip of theProps)
								set b_gZip to my encodedURL(b_Zip)
							else
								set b_Zip to ""
								set b_gZip to ""
							end if
							if (business country of theProps) is not missing value then
								set b_Cou to (business country of theProps)
								set b_gCou to my encodedURL(b_Cou)
							else
								set b_Cou to ""
								set b_gCou to ""
							end if
							set b_Addr to b_Str & return & b_Cit & ", " & b_Sta & "  " & b_Zip & return & b_Cou

							--GOOGLE MAPS LOCATION IN URL
							set b_gString to b_gStr & "," & b_gCit & "," & b_gSta & "," & b_gZip & "," & b_gCou
							set b_GMAP to "http://maps.google.com/maps?q=" & b_gString
							set b_String to "-Work: " & return & b_Addr & return & "(Link to Google Map:  " & b_GMAP & ")" & return
							copy b_String to end of list_Addr
						end if

						(*HOME *)
						if home street address of theProps is not missing value then
							set h_Str to (home street address of theProps)
							set h_gStr to my encodedURL(h_Str)
							if (home city of theProps) is not missing value then
								set h_Cit to (home city of theProps)
								set h_gCit to my encodedURL(h_Cit)
							else
								set h_Cit to ""
								set h_gCit to ""
							end if
							if (home state of theProps) is not missing value then
								set h_Sta to (home state of theProps)
								set h_gSta to my encodedURL(h_Sta)
							else
								set h_Sta to ""
								set h_gSta to ""
							end if
							if (home zip of theProps) is not missing value then
								set h_Zip to (home zip of theProps)
								set h_gZip to my encodedURL(h_Zip)
							else
								set h_Zip to ""
								set h_gZip to ""
							end if
							if (home country of theProps) is not missing value then
								set h_Cou to (home country of theProps)
								set h_gCou to my encodedURL(h_Cou)
							else
								set h_Cou to ""
								set h_gCou to ""
							end if
							set h_Addr to h_Str & return & h_Cit & ", " & h_Sta & "  " & h_Zip & return & h_Cou

							--GOOGLE MAPS LOCATION IN URL
							set h_gString to h_gStr & "," & h_gCit & "," & h_gSta & "," & h_gZip & "," & h_gCou
							set h_GMAP to "http://maps.google.com/maps?q=" & h_gString
							set h_String to "-Home:  " & return & h_Addr & return & "(Link to Google Map:  " & h_GMAP & ")" & return
							copy h_String to end of list_Addr
						end if
					end try

					--RIGHT SIDE (DATA FIELDS)
					set r_1 to (display name of theProps)
					set r_2 to (list_Addresses as string)
					set r_3 to (list_Phone as text)
					set r_4 to (list_Addr as text)

					--EXPORT VCARD DATA
					set vcard_data to (vcard data of theProps)
					set vcard_extension to ".vcf"
					set item_Created to (current date)

					--THE NOTES
					try
						set the_notes to plain text note of theProps
					end try
					if the_notes is missing value then set the_notes to ""

					--ASSEMBLE THE TEMPLATE
					set theContent to l_1 & r_1 & return & l_2 & r_2 & return & l_3 & r_3 & return & l_4 & r_4 & return & return & return & return & the_notes & return & return
					set the_vCard to my write_File(r_1, vcard_data, vcard_extension)

					set OFTitle to r_1

					(* // TASK ITEM *)
				else if the_class is "Task" then

					--PREPARE THE TEMPLATE
					--LEFT SIDE (FORM FIELDS)
					set l_1 to "Note:  "
					set l_2 to "Priority:  "
					set l_3 to "Due Date:  "
					set l_4 to "Status:  "
					set l_5 to "Notes:  "

					--RIGHT SIDE (DATA FIELDS)
					set propClass to (class of theProps) as text
					if propClass is "incoming message" then
						set r_1 to (subject of theProps)
					else
						set r_1 to (name of theProps)
					end if
					set the_Priority to (priority of theProps)
					if the_Priority is priority normal then set r_2 to "Normal"
					if the_Priority is priority high then set r_2 to "High"
					if the_Priority is priority low then set r_2 to "Low"

					set theDueDate to (due date of theProps)
					set r_3 to theDueDate
					set theCompletionDate to (completed date of theProps)
					set theStartDate to (start date of theProps)
					set item_Created to (current date)

					--TODO?
					try
						set todo_Flag to (todo flag of theProps) as text
						set r_4 to my TITLECASE(todo_Flag)
					end try

					--THE NOTES
					try
						set the_notes to plain text content of theProps
					end try
					if the_notes is missing value then set the_notes to ""

					--ASSEMBLE THE TEMPLATE
					set theContent to l_1 & r_1 & return & l_2 & r_2 & return & l_3 & r_3 & return & l_4 & r_4 & return & return & return & return & the_notes & return & return


					--EXPORT VCARD DATA
					if propClass is not "incoming message" then
						set vcard_extension to ".ics"
						set vcard_data to (icalendar data of theProps)
						set the_vCard to my write_File(r_1, vcard_data, vcard_extension)
					end if

					set OFTitle to r_1

					(* // MESSAGE ITEM *)
				else

					--GET EMAIL INFO
					set the_Sender to (sender of theProps)
					set s_Name to (address of the_Sender)
					set s_Address to (address of the_Sender)

					--REPLACE WITH NAME, IF AVAILABLE
					try
						set s_Name to (name of the_Sender)
					end try


					--GET CATEGORY INFO
					set the_Cats to (category of theProps)
					set list_Cats to {}
					set count_Cat to (count of the_Cats)
					repeat with the_Cat in the_Cats
						set cat_Name to (name of the_Cat as text)
						copy cat_Name to the end of list_Cats
						if count_Cat > 1 then
							copy ", " to the end of list_Cats
							set count_Cat to (count_Cat - 1)
						else
							set count_Cat to (count_Cat - 1)
						end if
					end repeat

					--RIGHT SIDE (DATA FIELDS)
					set m_Sub to (subject of theProps)
					if m_Sub is missing value then
						set r_2 to "<No Subject>"
					else
						set r_2 to {subject of theProps}
					end if
					set r_3 to (time sent of theProps)
					set r_4 to list_Cats

					set theID to id of theProps as string
					set item_Created to r_3
					set OFTitle to r_2

					set theDueDate to (due date of theProps)
					set theCompletionDate to (completed date of theProps)
					set theStartDate to (start date of theProps)

					set oFlag to (todo flag of theProps) as text
					if oFlag is "not completed" then
						set theFlag to true
					end if

					--PROCESS EMAIL CONTENT
					set m_Content to plain text content of theProps
					set theContent to return & return & "Name: " & s_Name & return & "Subject: " & r_2 & return & "Sent: " & r_3 & return & "Category: " & r_4 & return & return & return & return & m_Content & return & return
				end if

				--CREATE IN OMNIFOCUS
				tell front document of application "OmniFocus"
					if argv is {"nodialog"} then

						set NewTask to make new inbox task with properties {name:OFTitle, note:theContent, flagged:theFlag, due date:theDueDate, completion date:theCompletionDate, defer date:theStartDate}
					else
						tell quick entry
							set NewTask to make new inbox task with properties {name:OFTitle, note:theContent, flagged:theFlag, due date:theDueDate, completion date:theCompletionDate, defer date:theStartDate}
							open
						end tell
					end if
				end tell

				--ATTACH VCARD (IF PRESENT)
				if the_vCard is not {} then my vCard_Attach(the_vCard, theProps, NewTask)

				--IF ATTACHMENTS PRESENT, RUN ATTACHMENT SUBROUTINE
				my message_Attach(theAttachments, theProps, NewTask, selectedItem)

				--ITEM HAS FINISHED! COUNT IT AS A SUCCESS AND RESET ATTACHMENTS!
				set successCount to successCount + 1
				set theAttachments to {}
			end repeat
		end if
	end tell
end item_Process

(*
======================================
// UTILITY SUBROUTINES
======================================
*)

--URL ENCODE
on encodedURL(the_Word)
	set scpt to "php -r 'echo urlencode(\"" & the_Word & "\");'"
	return do shell script scpt
end encodedURL

--TITLECASE
on TITLECASE(txt)
	return do shell script "python -c \"import sys; print unicode(sys.argv[1], 'utf8').title().encode('utf8')\" " & quoted form of txt
end TITLECASE

--SORT SUBROUTINE
on simple_sort(my_list)
	set the index_list to {}
	set the sorted_list to {}
	repeat (the number of items in my_list) times
		set the low_item to ""
		repeat with i from 1 to (number of items in my_list)
			if i is not in the index_list then
				set this_item to item i of my_list as text
				if the low_item is "" then
					set the low_item to this_item
					set the low_item_index to i
				else if this_item comes before the low_item then
					set the low_item to this_item
					set the low_item_index to i
				end if
			end if
		end repeat
		set the end of sorted_list to the low_item
		set the end of the index_list to the low_item_index
	end repeat
	return the sorted_list
end simple_sort

--REPLACE
on replaceString(theString, theOriginalString, theNewString)
	set theNum to 0
	set {od, AppleScript's text item delimiters} to {AppleScript's text item delimiters, theOriginalString}
	set theStringParts to text items of theString
	if (count of theStringParts) is greater than 1 then
		set theString to text item 1 of theStringParts as string
		repeat with eachPart in items 2 thru -1 of theStringParts
			set theString to theString & theNewString & eachPart as string
			set theNum to theNum + 1
		end repeat
	end if
	set AppleScript's text item delimiters to od
	return theString
end replaceString


(*
======================================
// ATTACHMENT SUBROUTINES
=======================================
*)

--CLEAN TITLE FOR FILENAME
on clean_Title(rawFileName)
	set previousDelimiter to AppleScript's text item delimiters
	set potentialName to rawFileName
	set legalName to {}
	set illegalCharacters to {".", ",", "/", ":", "[", "]"}
	repeat with thisCharacter in the characters of potentialName
		set thisCharacter to thisCharacter as text
		if thisCharacter is not in illegalCharacters then
			set the end of legalName to thisCharacter
		else
			set the end of legalName to "_"
		end if
	end repeat
	return legalName
end clean_Title

--WRITE THE FILE
on write_File(r_1, vcard_data, vcard_extension)
	set ExportFolder to ((path to desktop folder) & "Temp Export From Outlook:") as string
	set SaveLoc to my f_exists(ExportFolder)
	set fileName to (my clean_Title(r_1) & vcard_extension)
	set theFileName to (ExportFolder & fileName)
	try
		open for access file theFileName with write permission
		write vcard_data to file theFileName as string
		close access file theFileName
		return theFileName

	on error errorMessage
		log errorMessage
		try
			close access file theFileName
		end try
	end try
end write_File

--FOLDER EXISTS
on f_exists(ExportFolder)
	try
		--		set myPath to (path to home folder)
		get ExportFolder as alias
		set SaveLoc to ExportFolder
	on error
		do shell script "/bin/mkdir -p '" & (POSIX path of ExportFolder) & "'"
		-- tell application "Finder" to make new folder with properties {name:"Temp Export From Outlook"}
	end try
end f_exists

--VCARD PROCESSING
on vCard_Attach(the_vCard, theProps, NewTask)
	tell application "OmniFocus"
		tell the note of NewTask
			make new file attachment with properties {file name:POSIX file the_vCard, embedded:true}
		end tell
	end tell
end vCard_Attach

--ATTACHMENT PROCESSING
on message_Attach(theAttachments, theProps, NewTask, theMsg)
	if attachSwitch is "ON" then
		tell application id "com.microsoft.Outlook"
			--MAKE SURE TEXT ITEM DELIMITERS ARE DEFAULT
			set AppleScript's text item delimiters to ""

			--TEMP FILES PROCESSED ON THE DESKTOP
			set ExportFolder to ((current identity folder) & "Temp Export From Outlook:") as string
			set SaveLoc to my f_exists(ExportFolder)

			--Attach original message
			set subj to subject of theMsg
			set textPath to ExportFolder & (my clean_Title(subj) & ".eml") as string
			save theMsg in (textPath)
			tell application "OmniFocus"
				tell the note of NewTask
					make new file attachment with properties {file name:file textPath, embedded:true}
				end tell
			end tell
			--set trash_Folder to path to trash folder from user domain
			--do shell script "mv " & quoted form of POSIX path of theFileName & space & quoted form of POSIX path of trash_Folder


			if theAttachments is not {} then
				--PROCESS THE ATTCHMENTS
				set attCount to 0
				repeat with theAttachment in theAttachments
					set theFileName to (ExportFolder & theAttachment's name)
					try
						save theAttachment in theFileName
					end try
					tell application "OmniFocus"
						tell the note of NewTask
							make new file attachment with properties {file name:file theFileName, embedded:true}
						end tell
					end tell

					--SILENT DELETE OF TEMP FILE
					--set trash_Folder to path to trash folder from user domain
					--do shell script "mv " & quoted form of POSIX path of theFileName & space & quoted form of POSIX path of trash_Folder
				end repeat
			end if
		end tell
	end if
end message_Attach

--SILENT DELETE OF TEMP FOLDER (THANKS MARTIN MICHEL!)
on trashfolder(SaveLoc)
	try
		set trashfolderpath to ((path to trash) as Unicode text)
		set srcfolderinfo to info for (SaveLoc as alias)
		set srcfoldername to name of srcfolderinfo
		set SaveLoc to (SaveLoc as alias)
		set SaveLoc to (quoted form of POSIX path of SaveLoc)
		set counter to 0
		repeat
			if counter is equal to 0 then
				set destfolderpath to trashfolderpath & srcfoldername & ":"
			else
				set destfolderpath to trashfolderpath & srcfoldername & " " & counter & ":"
			end if
			try
				set destfolderalias to destfolderpath as alias
			on error
				exit repeat
			end try
			set counter to counter + 1
		end repeat
		set destfolderpath to quoted form of POSIX path of destfolderpath
		set command to "ditto " & SaveLoc & space & destfolderpath
		do shell script command
		-- this won't be executed if the ditto command errors
		set command to "rm -r " & SaveLoc
		do shell script command
		return true
	on error
		return false
	end try
end trashfolder

(*
======================================
// GROWL SUBROUTINES
======================================
*)
on startGrowl()
	try
		tell application "System Events"
			set isGrlRunning to (count of (every process whose bundle identifier is "com.Growl.GrowlHelperApp")) > 0
		end tell
		ignoring application responses
			if isGrlRunning then
				set osaSc to "tell application \"Growl\"
set the allNotificationsList to {\"Import To OmniFocus\", \"Success Notification\", \"Failure Notification\"}
set the enabledNotificationsList to {\"Import To OmniFocus\", \"Success Notification\", \"Failure Notification\"}
register as application \"Outlook to OmniFocus\" all notifications allNotificationsList default notifications enabledNotificationsList icon of application \"OmniFocus\"
notify with name \"Import To OmniFocus\" title \"Import To OmniFocus Started\" description \"Processing Items from Outlook\" application name \"Outlook to OmniFocus\"
end tell"
				set shSc to "osascript -e " & quoted form of osaSc & "  &>  /dev/null &"
				ignoring application responses
					do shell script shSc
				end ignoring
			end if
		end ignoring
	end try
end startGrowl


--ANNOUNCE THE COUNT OF TOTAL ITEMS TO EXPORT
on process_Items(itemNum, attNum, the_class)
	try
		if growlSwitch is "ON" then
			tell application "System Events"
				set isGrlRunning to (count of (every process whose bundle identifier is "com.Growl.GrowlHelperApp")) > 0
			end tell

			set app_Path to (path to application id "com.microsoft.Outlook")

			ignoring application responses
				if isGrlRunning then
					set attPlural to "s"
					set the_class to the_class as text
					if the_class is "List" then set the_class to "Outlook"
					if the_class is "Incoming Message" then
						set growl_Icon to (path to resource "Mail.icns" in bundle app_Path)
					else if the_class is "Contact" then
						set growl_Icon to (path to resource "vCrd.icns" in bundle app_Path)
					else
						set growl_Icon to (path to resource "lcs.icns" in bundle app_Path)
					end if
					set growl_Icon to (POSIX path of growl_Icon) as text

					if attNum = 0 then
						set attNum to "No"
					else if attNum is 1 then
						set attPlural to ""
					end if

					tell application "Finder"
						if the_class is not "Text" then
							set Plural_Test to (itemNum) as number
							if Plural_Test is greater than 1 then

								set osaSc to "tell application \"Growl\"
notify with name \"Import To OmniFocus\" title \"Import To OmniFocus Started\" description \"Now Importing " & itemNum & " " & the_class & " Items with " & attNum & " Attachment" & attPlural & ".\" application name \"Outlook to OmniFocus\" identifier \"OmniFocus\" image from location \"" & growl_Icon & "\"
                            end tell"
								set shSc to "osascript -e " & quoted form of osaSc & "  &>  /dev/null &"
								my growlThis(shSc)
							else
								set osaSc to "tell application \"Growl\"
notify with name \"Import To OmniFocus\" title \"Import To OmniFocus Started\" description \"Now Importing " & itemNum & " " & the_class & " Items with " & attNum & " Attachment" & attPlural & ".\" application name \"Outlook to OmniFocus\" identifier \"OmniFocus\" image from location \"" & growl_Icon & "\"
                            end tell"
								set shSc to "osascript -e " & quoted form of osaSc & "  &>  /dev/null &"
								my growlThis(shSc)
							end if
						end if
					end tell --FINDER
				end if
			end ignoring
		end if

	end try
end process_Items

on growlThis(shSc)
	ignoring application responses
		do shell script shSc
	end ignoring
end growlThis

--GROWL RESULTS
on growl_Growler(successCount, itemNum)
	try
		tell application "System Events"
			set isGrlRunning to (count of (every process whose bundle identifier is "com.Growl.GrowlHelperApp")) > 0
		end tell

		ignoring application responses
			if isGrlRunning then
				set part_1 to "tell application \"Growl\"
"
				set Plural_Test to (successCount) as number
				if Plural_Test is -1 then
					set part_2 to "notify with name \"Failure Notification\" title \"Import Failure\" description \"No Items Selected In Outlook!\" application name \"Outlook to OmniFocus\"
                    end tell"
				else if Plural_Test is 0 then
					set part_2 to "notify with name \"Failure Notification\" title \"Import Failure\" description \"No Items Exported From Outlook!\" application name \"Outlook to OmniFocus\"
                    end tell"
				else if Plural_Test is equal to 1 then
					set part_2 to "notify with name \"Success Notification\" title \"Import Success\" description \"Successfully Exported " & itemNum & " Item to OmniFocus\" application name \"Outlook to OmniFocus\"
                    end tell"
				else if Plural_Test is greater than 1 then
					set part_2 to "notify with name \"Success Notification\" title \"Import Success\" description \"Successfully Exported " & itemNum & " Items to OmniFocus\" application name \"Outlook to OmniFocus\"
                    end tell"
				end if
				set itemNum to "0"
				set combined_parts to part_1 & part_2
				set shSc to "osascript -e " & quoted form of combined_parts & "  &>  /dev/null &"
				my growlThis(shSc)
			end if

		end ignoring
	end try
end growl_Growler

--NOTIFICATION CENTER
on notification_Center(successCount, itemNum)
	set Plural_Test to (successCount) as number

	if Plural_Test is -1 then
		display notification "No Items Selected In Outlook!" with title "Outlook to OmniFocus" subtitle "Veritrope.com"

	else if Plural_Test is 0 then
		display notification "No Items Exported From Outlook!" with title "Outlook to OmniFocus" subtitle "Veritrope.com"

	else if Plural_Test is equal to 1 then
		display notification "Successfully Exported " & itemNum & " Item to OmniFocus" with title "Outlook to OmniFocus" subtitle "Veritrope.com"

	else if Plural_Test is greater than 1 then
		display notification "Successfully Exported " & itemNum & " Items to OmniFocus" with title "Outlook to OmniFocus" subtitle "Veritrope.com"
	end if

	set itemNum to "0"
	delay 1
end notification_Center

