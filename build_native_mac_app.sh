#!/bin/bash
# Builds native macOS App bundle using osacompile with folder selection support

APP_NAME="REAPER to Logic Converter.app"
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

rm -rf "$APP_NAME"

# Create AppleScript source
cat << 'EOF' > /tmp/app_script.applescript
on run
    try
        set appPath to POSIX path of (path to me)
        set perlScript to appPath & "Contents/Resources/daw_converter.pl"
        set webPage to appPath & "Contents/Resources/index.html"
        
        set userChoice to button returned of (display dialog "Welcome to reaper2logic Converter!
Created by Danny Marshall

Select your REAPER Project Folder or File to package into a Logic Pro (.logicx) bundle:

What would you like to select?" buttons {"Select Project Folder", "Select .rpp File", "Open Visual Window"} default button "Select Project Folder" with title "reaper2logic Converter" with icon path to resource "applet.icns" in bundle (path to me))
        
        set posixInput to ""
        
        if userChoice is "Select Project Folder" then
            set chosenFolder to (choose folder with prompt "Select your REAPER Project Folder:")
            set posixInput to POSIX path of chosenFolder
        else if userChoice is "Select .rpp File" then
            set chosenFile to (choose file with prompt "Select your REAPER (.rpp) project file:")
            set posixInput to POSIX path of chosenFile
        else if userChoice is "Open Visual Window" then
            do shell script "open " & quoted form of webPage
            return
        end if
        
        if posixInput is not "" then
            set savePrompt to "Save full Logic Pro Package Bundle (.logicx) to:"
            set defaultName to "MySong.logicx"
            
            set targetFile to (choose file name with prompt savePrompt default name defaultName)
            set posixOutput to POSIX path of targetFile
            
            if posixOutput does not end with ".logicx" then
                set posixOutput to posixOutput & ".logicx"
            end if
            
            set cmd to "perl " & quoted form of perlScript & " " & quoted form of posixInput & " " & quoted form of posixOutput
            do shell script cmd
            
            display dialog "🎉 Success!

Your REAPER project folder has been packaged into a self-contained Logic Pro Bundle:
" & posixOutput & "

Double-click 'Open in Logic Pro.command' inside the bundle or import into Logic Pro!" buttons {"OK"} default button "OK" with title "reaper2logic — Bundle Created" with icon path to resource "applet.icns" in bundle (path to me)
        end if
    on error errMsg number errNum
        if errNum is not -128 then
            display dialog "Notice: " & errMsg buttons {"OK"} default button "OK" with title "reaper2logic"
        end if
    end try
end run
EOF

# Compile into .app bundle using osacompile
osacompile -o "$APP_NAME" /tmp/app_script.applescript

# Bundle Resources inside .app
cp app_icon.icns "$APP_NAME/Contents/Resources/app_icon.icns"
cp app_icon.icns "$APP_NAME/Contents/Resources/applet.icns"
cp daw_converter.pl "$APP_NAME/Contents/Resources/daw_converter.pl"
cp index.html "$APP_NAME/Contents/Resources/index.html"
cp styles.css "$APP_NAME/Contents/Resources/styles.css"
cp app.js "$APP_NAME/Contents/Resources/app.js"
cp app_icon.jpg "$APP_NAME/Contents/Resources/app_icon.jpg"
chmod +x "$APP_NAME/Contents/Resources/daw_converter.pl"

# Remove Assets.car which overrides custom .icns files on macOS 11+
rm -f "$APP_NAME/Contents/Resources/Assets.car"

# Remove CFBundleIconName and set CFBundleIconFile to applet.icns
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP_NAME/Contents/Info.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile applet.icns" "$APP_NAME/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string applet.icns" "$APP_NAME/Contents/Info.plist"

touch "$APP_NAME"
rm -f /tmp/app_script.applescript

echo "SUCCESS: Built native macOS Application Bundle '$APP_NAME' with folder selection support!"
