# http://www.tkdocs.com/tutorial/windows.html

rexec {
  tk::toplevel .window
  wm title .window "New title"
  wm geometry .window 300x200-5+40
  wm resizable .window 0 0
}

set filename [tk_getOpenFile]
set filename [tk_getSaveFile]
set dirname [tk_chooseDirectory]
tk_chooseColor -initialcolor #ff0000

set filename [rexec_wait { tk_getOpenFile }]

tk_messageBox -message "Have a good day"

tk_messageBox -type "yesno" \
  -message "Are you sure you want to do this?" \
  -icon question -title "Last Chance"
    
tk_messageBox -type "okcancel" \
  -message "Are you sure you want to do this?" \
  -icon question -title "Last Chance"
    
tk_messageBox -type "yesnocancel" \
  -message "Save before closing?" \
  -icon question -title "Last Chance"

tk_messageBox -type "retrycancel" \
  -message "Failed to save!" \
  -icon error -title "Last Chance"
