#!/bin/bash
# Builds native macOS App bundle using osacompile with fixed ICNS app icon and native dialog GUI

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

Convert project files between REAPER (.rpp) and Logic Pro (.fcpxml).

Choose an option below:" buttons {"Choose Project File & Convert", "Open Visual Timeline Window", "Cancel"} default button "Choose Project File & Convert" with title "reaper2logic Converter" with icon path to resource "applet.icns" in bundle (path to me))
        
        if userChoice is "Choose Project File & Convert" then
            set chosenFile to (choose file with prompt "Select your REAPER (.rpp) or Logic Pro (.fcpxml) project file:")
            set posixInput to POSIX path of chosenFile
            
            if posixInput ends with ".rpp" then
                set savePrompt to "Save converted Logic Pro project (.fcpxml) as:"
                set defaultName to "Converted_Project.fcpxml"
            else
                set savePrompt to "Save converted REAPER project (.rpp) as:"
                set defaultName to "Converted_Project.rpp"
            end if
            
            set targetFile to (choose file name with prompt savePrompt default name defaultName)
            set posixOutput to POSIX path of targetFile
            
            set cmd to "perl " & quoted form of perlScript & " " & quoted form of posixInput & " " & quoted form of posixOutput
            do shell script cmd
            
            display dialog "🎉 Success!

Converted project file has been saved to:
" & posixOutput buttons {"OK"} default button "OK" with title "reaper2logic — Conversion Complete" with icon path to resource "applet.icns" in bundle (path to me)
            
        else if userChoice is "Open Visual Timeline Window" then
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

touch "$APP_NAME"
rm -f /tmp/app_script.applescript

echo "SUCCESS: Built native macOS Application Bundle '$APP_NAME'"
