#!/bin/bash
# Builds native macOS App bundle using osacompile with explicit 2-Step Folder + File selection flow

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

Convert your REAPER project into Logic Pro in 2 simple steps:
 Step 1: Select your Audio/Media Folder
 Step 2: Select your REAPER (.rpp) File

Click Start to begin:" buttons {"Start 2-Step Selection (Folder + .rpp)", "Open Visual Window", "Cancel"} default button "Start 2-Step Selection (Folder + .rpp)" with title "reaper2logic Converter" with icon path to resource "applet.icns" in bundle (path to me))
        
        if userChoice is "Start 2-Step Selection (Folder + .rpp)" then
            -- STEP 1: Select Audio Folder
            set chosenFolder to (choose folder with prompt "STEP 1 of 2: Select your REAPER Audio Folder (containing your audio files/stems):")
            set posixFolder to POSIX path of chosenFolder
            
            -- STEP 2: Select RPP File
            set chosenFile to (choose file with prompt "STEP 2 of 2: Select your REAPER (.rpp) project file:")
            set posixFile to POSIX path of chosenFile
            
            -- STEP 3: Choose Output Save Location (ONLY AFTER STEP 1 AND 2 ARE DONE)
            set savePrompt to "Save Logic Pro Converted Project Folder to:"
            set defaultName to "Converted_Logic_Project"
            
            set targetFile to (choose file name with prompt savePrompt default name defaultName)
            set posixOutput to POSIX path of targetFile
            
            set cmd to "perl " & quoted form of perlScript & " " & quoted form of posixFile & " " & quoted form of posixFolder & " " & quoted form of posixOutput
            do shell script cmd
            
            display dialog "🎉 Success!

Your REAPER project folder has been converted for Logic Pro:
" & posixOutput & "

Double-click 'Open in Logic Pro.command' inside the output folder, or open Logic Pro and choose File > Import > Final Cut Pro XML... and select 'Session.fcpxml'!" buttons {"OK"} default button "OK" with title "reaper2logic — Conversion Complete" with icon path to resource "applet.icns" in bundle (path to me)
            
        else if userChoice is "Open Visual Window" then
            do shell script "open " & quoted form of webPage
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

echo "SUCCESS: Built native macOS Application Bundle '$APP_NAME' with 2-step selection flow!"
