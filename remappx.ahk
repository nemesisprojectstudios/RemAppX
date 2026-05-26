#SingleInstance, Force
#Persistent
#NoEnv
Process, Priority,, AboveNormal
SetBatchLines, -1

global CmdArr := {}      ; Key -> Command mapping (associative array)
global LabelArr := {}    ; Key -> Generated label name mapping
global KeyArr := {}     ; Key -> Command mapping (associative array)
global Label2Arr := {} 
global GuiVisible := 0
global GuiRows := 0      ; Counter for GUI rows
global GuiRows2 := 0
global ActiveRows := 0
global ActiveRows2 := 0
global MaxRows := 10
global nextLabelId := 0  ; Unique ID for generated labels
global nextLabelId2 := 0 ; Unique ID for generated labels (second array)
global CurrentTab := 1

global configFile := A_ScriptDir "\keybinds.cfg"
global iniFile := A_ScriptDir "\remappxsettings.ini"
global startupLnk := A_Startup "\RemAppX.lnk"

global sizelimit := A_ScreenHeight - 200

global DoStartup := 0
if (FileExist(startupLnk))
    DoStartup := 1

global saving := 0
global loading := 0
global reloading := 0
global processing := 0
global clearing := 0
global rowassigning := 0

global RepeatBtn := 0
global StartupBtn := 0

global DoRepeatOutputs := 0
global RepeatBuffer := 0
global RepeatDelay := 0

global modifierKeys := {"!" : "Alt", "#" : "Win", "^" : "Ctrl", "+" : "Shift"}

global complexKeys := ["Tab", "Enter", "Escape", "Space", "Backspace", "Delete", "Insert", "Home", "End", "PgUp", "PgDn", "Up", "Down", "Left", "Right", "NumpadEnter", "NumpadAdd", "NumpadSub", "NumpadMult", "NumpadDiv"]
global funcKeys := []
Loop, 12 {
    funcKeys.Push("F" . A_Index)
}
global mouseKeys := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]

global validKeys := {}

AddValid(arr) {
    global validKeys
    for _, keyx in arr {
        StringUpper, uKey, keyx
        validKeys[uKey] := 1
    }
}

AddValid(complexKeys)
AddValid(funcKeys)
AddValid(mouseKeys)

Loop, 10 {
    varName := "KeyEdit" . A_Index
    %varName% := ""
    varName := "CmdEdit" . A_Index
    %varName% := ""
    varName := "DelRow" . A_Index
    %varName% := ""
    varName := "InEdit" . A_Index
    %varName% := ""
    varName := "OutEdit" . A_Index
    %varName% := ""
}
LoadConfig()
ShowGui()
Return

; Run a command through cmd.exe
CallCmd(cmd) {
    Run, %ComSpec% /c %cmd%,, Hide
    return
}

; Wrapper that reads from global array and executes
ExecuteBoundKey(boundKey) {
    global CmdArr
    cmd := CmdArr[boundKey]
    if (cmd != "" && cmd != 0)
        CallCmd(cmd)
    return
}

ExecuteBoundKey2(boundKey) {
    global KeyArr
    out := KeyArr[boundKey]
    if (out = "" || out = 0)
        return
    
    ; Convert normalized format (!F4) to Send syntax (!{F4})
    ; Find where modifiers end and base key begins
    pos := RegExMatch(out, "[\w]")
    if (pos > 1) {
        modifiers := SubStr(out, 1, pos - 1)
        baseKey := SubStr(out, pos)
        Send, %modifiers%{%baseKey%}
        if (DoRepeatOutputs) {
            if (RepeatBuffer != 0)
                sleep, %RepeatBuffer%
            while GetKeyState(boundKey, "p")
            {
                Send, %modifiers%{%baseKey%}
                if (RepeatDelay != 0)
                    Sleep, %RepeatDelay%
            }
        }

    } else {
        Send, {%out%}
        if (DoRepeatOutputs) {
            if (RepeatBuffer != 0)
                sleep, %RepeatBuffer%
            while GetKeyState(boundKey, "p")
            {
                Send, {%out%}
                if (RepeatDelay != 0)
                    Sleep, %RepeatDelay%
            }
        }
    }
    return
}

; Register a hotkey with its associated command
RegHotkey(key, command) {
    global CmdArr, LabelArr, nextLabelId
    
    ; Normalize key format (remove $ if present, we'll add it)
    cleanKey := RegExReplace(key, "^\$", "")
    
    ; Store command in array
    CmdArr[cleanKey] := command
    
    ; Generate unique label name
    nextLabelId++
    labelName := "__HK_" . nextLabelId
    LabelArr[cleanKey] := labelName
    
    ; Create dynamic label that calls ExecuteBoundKey with this specific key
    ; We use a timer-based approach to avoid label limitation
    ; Actually, better: use a single label and track which hotkey fired
    
    ; Register with $ prefix (intercept, don't pass through)
    
    Hotkey, $%cleanKey%, DynamicKeyHandler, On
    
    return labelName
}

RegHotkey2(inkey, outkey) {
    global KeyArr, Label2Arr, nextLabelId2
    
    ; Normalize key format (remove $ if present, we'll add it)
    cleanKey := RegExReplace(inkey, "^\$", "")
    
    ; Store command in array
    KeyArr[cleanKey] := outkey
    
    ; Generate unique label name
    nextLabelId2++
    labelName := "__HK_" . nextLabelId2
    Label2Arr[cleanKey] := labelName
    
    ; Create dynamic label that calls ExecuteBoundKey with this specific key
    ; We use a timer-based approach to avoid label limitation
    ; Actually, better: use a single label and track which hotkey fired
    
    ; Register with $ prefix (intercept, don't pass through)
    
    Hotkey, $%cleanKey%, DynamicKeyHandler2, On
    
    return labelName
}

; Single handler that determines which key was pressed
DynamicKeyHandler:
    keyName := A_ThisHotkey
    ; Remove $ prefix for lookup
    cleanKey := RegExReplace(keyName, "^\$", "")
    ExecuteBoundKey(cleanKey)
return

DynamicKeyHandler2:
    keyName := A_ThisHotkey
    ; Remove $ prefix for lookup
    cleanKey := RegExReplace(keyName, "^\$", "")
    ExecuteBoundKey2(cleanKey)
return

; Save all keybinds to file (format: keybind;cmd)
SaveConfig(file := "") {
    global CmdArr, KeyArr, configFile, saving
    saving := 1
    if (file = "")
        file := configFile
    
    ; Clear existing
    if (FileExist(file))
        FileDelete, %file%
    FileAppend,, %file%
    sleep, 1
    ; Write each binding
    for key, cmd in CmdArr {
        ; Escape semicolons in command to avoid parsing issues
        safeCmd := StrReplace(cmd, ";", "{SEMICOLON}")
        line := key . ";" . safeCmd
        FileAppend, %line%`n, %file%
    }
    FileAppend, -------------`n, %file%
    for inb, outb in KeyArr {
        ; Escape semicolons in command to avoid parsing issues
        safeCmd := StrReplace(outb, ";", "{SEMICOLON}")
        line := inb . ";" . safeCmd
        FileAppend, %line%`n, %file%
    }

    IniWrite, %DoRepeatOutputs%, %iniFile%, SETTINGS, DoRepeatOutputs
    IniWrite, %RepeatBuffer%, %iniFile%, SETTINGS, RepeatBuffer
    IniWrite, %RepeatDelay%, %iniFile%, SETTINGS, RepeatDelay
    
    TrayTip, RemAppX, % "Configuration saved to " file, 2
    saving := 0
    return
}

ExportConfig:
    FileSelectFile, saveFile, S24, %A_ScriptDir%\save.cfg, Save settings - %A_ScriptName%, Config Files (*.cfg)
    if (saveFile = "")
        return
    SaveConfig(saveFile)
    ;TrayTip, RemAppX, % "Settings saved to " saveFile, 2
return

ImportConfig:
    FileSelectFile, importFile, 3, %A_ScriptDir%\, Select a .cfg file to import, Config Files (*.cfg)
    if (importFile = "")
        return
    LoadConfig(importFile)
    ShowGui()
return

; Load keybinds from file
LoadConfig(file := "") {
    global CmdArr, KeyArr, configFile, loading
    loading := 1
    if (file = "")
        file := configFile
    
    if (!FileExist(file))
        return 0
    
    ; Clear existing hotkeys first
    for key, cmd in CmdArr {
        Try
            Hotkey, $%key%, Off
    }
    for inb, outb in KeyArr {
        Try
            Hotkey, $%inb%, Off
    }
    CmdArr := {}
    KeyArr := {}
    
    ; Parse file
    hitSeparator := 0
    Loop, Read, %file%
    {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue  ; skip empty/comment lines
        if (SubStr(line, 1, 1) = "-")
        {
            hitSeparator := 1 ; we hit the separator between commands and rebinds
            continue
        }
        ; Split on first semicolon
        pos := InStr(line, ";")
        if (!pos)
            continue
        
        key := Trim(SubStr(line, 1, pos - 1))
        cmd := Trim(SubStr(line, pos + 1))
        
        ; Unescape semicolons
        cmd := StrReplace(cmd, "{SEMICOLON}", ";")
        
        ; Register
        if (!hitSeparator)
            RegHotkey(key, cmd)
        else 
            RegHotkey2(key, cmd)
    }
    if (FileExist(iniFile))
    {
        IniRead, DoRepeatOutputs, %iniFile%, SETTINGS, DoRepeatOutputs, %DoRepeatOutputs%
        IniRead, RepeatBuffer, %iniFile%, SETTINGS, RepeatBuffer, %RepeatBuffer%
        IniRead, RepeatDelay, %iniFile%, SETTINGS, RepeatDelay, %RepeatDelay%
    }
    TrayTip, RemAppX, % "Configuration loaded from " file, 2
    loading := 0
    return 1
}


; Normalize various key formats to AHK hotkey syntax
NormalizeKey(key) {
    global processing

    if (key  = "" || key = false)
        return ""
    key := Trim(key) ; remove leading/trailing whitespace
    StringUpper, key, key

    ; Remove whitespace from the input
    key := RegExReplace(key, "\s", "")
    
    ; Replace common modifiers with AHK syntax - easy to debug and store
    key := StrReplace(key, "WIN+", "#")
    key := StrReplace(key, "CTRL+", "^")
    key := StrReplace(key, "ALT+", "!")
    key := StrReplace(key, "SHIFT+", "+")
    
    ; handle regular text style (win + q)
    key := StrReplace(key, "WIN", "#")
    key := StrReplace(key, "CTRL", "^")
    key := StrReplace(key, "ALT", "!")
    key := StrReplace(key, "SHIFT", "+")
    
    pos := RegExMatch(key, "[\w]")
    if (pos = 0)  ; No word chars found = only modifiers
        return ""

    modifiers := SubStr(key, 1, pos - 1)
    baseKey := SubStr(key, pos)

    ; Base key longer than 1 char - check for complex keys
    if (StrLen(baseKey) != 1) {
        StringUpper, uBase, baseKey
        if (!validKeys.HasKey(uBase))
            return ""
    }

    ; Check for duplicate modifiers
    seen := ""
    Loop, % StrLen(modifiers)
    {
        mod := SubStr(modifiers, A_Index, 1)
        if (InStr(seen, mod))
            return ""  ; Duplicate found
        seen .= mod
    }
    
    ; Validate base key is single character
    if (!RegExMatch(baseKey, "^[\w]+$"))
        return ""

    ; validate format
    if (!RegExMatch(key, "^[\^!+#]*[\w]+$"))
        return ""
    
    return key
}

; Build and show the main configuration GUI
ShowGui() {
    global GuiRows, ActiveRows
    
    Try
        Gui, Main:Destroy
    Catch
        Gui, Destroy
        
    Gui, Main:New, -Resize -Caption +Border +OwnDialogs
    Gui, Main:Default
    Gui, Color, 1E1E1E, 2D2D2D, 1E1E1E
    Gui +LastFound
    WinSet, Transparent, 230
    Gui, Font, s10, Segoe UI Bold
    
    ; Buttons
    off := 15
    Gui, Add, Button, x10 y10 w100 h30 gAddRowBtn, % "+ Add Binding"
    Gui, Add, Button, x+%off% yp w100 h30 gClearBtn, % "Clear Bindings"
    Gui, Add, Button, x+%off% yp w100 h30 gReloadBindings, % "Apply"
    Gui, Add, Button, x+50 yp w55 h30 gSaveBtn, % "Save"
    Gui, Add, Button, x+%off% yp w55 h30 gLoadBtn, % "Load"
    Gui, Add, Button, x+30 yp w55 h30 gImportConfig, % "Import"
    Gui, Add, Button, x+%off% yp w55 h30 gExportConfig, % "Export"
    Gui, Add, Button, x+30 yp w55 h30 gSafeExit, % "Exit"
    
    ; Header
    Gui, Font, s10, Segoe UI Bold
    
    Gui, Add, Text
    Gui, Add, Tab3, x10 yp+10 w744 h420 CWhite AltSubmit vCurrentTab gTabCh, Command mapper|Key remapper|Settings|Usage guide
    ; Build from existing bindings
    Gui, Tab, 1
    Gui, Add, Text, x20 y+10 w500 h25 cWhite, % "Keybind"
    Gui, Add, Text, x250 yp w400 h25 cWhite, % "Command"
    GuiRows := 0
    ActiveRows := 0
    GuiRows2 := 0
    ActiveRows2 := 0
    for key, cmd in CmdArr {
        AddGuiRow(key, cmd)
    }
    Gui, Tab, 2
    Gui, Font, s10, Segoe UI Bold
    Gui, Add, Text, x20 y+10 w500 h25 cWhite, % "Keybind"
    Gui, Add, Text, x250 yp w400 h25 cWhite, % "Output"
    Gui, Font, s10, Segoe UI
    for keyin, keyout in KeyArr {
        AddRebindRow(keyin, keyout)
    }
    Gui, Tab, 3
    Gui, Font, s10, Segoe UI Bold
    Gui, Add, Text, x20 y+10 cWhite, % "RemAppX Settings"
    
    Gui, Font, s10, Segoe UI
    Gui, Margin, 15, 15
    Gui, Add, Text, x20 y+10 cWhite Section, % "Repeat outputs while held (remaps only)"
    Gui, Add, Text, cWhite, % "Repeat buffer (ms)"
    Gui, Add, Text, cWhite, % "Repeat delay (ms)"
    Gui, Add, Text, cWhite, % "Run at startup (requires admin)"
    ;Gui, Add, Text, cWhite, % "etc"

    Gui, Font, s10, Segoe UI Bold
    Gui, Margin, 10,10
    Gui, Add, Button, xs+260 ys-4 w55 h30 vRepeatBtn gToggleRepeat, % (DoRepeatOutputs ? "Disable" : "Enable")
    Gui, Add, Edit, vRepeatBuffer w55 h30 cWhite, %RepeatBuffer%
    Gui, Add, UpDown, range0-1000, %RepeatBuffer%
    Gui, Add, Edit, vRepeatDelay w55 h30 cWhite, %RepeatDelay%
    Gui, Add, UpDown, range0-500, %RepeatDelay%
    Gui, Add, Button, w55 h30 vStartupBtn gToggleStartup, % (DoStartup ? "Disable" : "Enable")

    Gui, Tab, 4
    Gui, Font, s10, Segoe UI Bold
    Gui, Add, Text, x20 y+10 cWhite, % "RemAppX Usage tutorial"
    Gui, Font, s10, Segoe UI
    Gui, Margin, 5, 5
    Gui, Add, Text, cWhite, % "With the command mapper, you can map valid terminal commands to keybinds. Some examples:"
    Gui, Add, Text, cWhite, % "start chrome.exe | taskmgr | shutdown /f"
    Gui, Add, Text, cWhite, % "With the input remapper, you can remap your keyboard keys or map simpler macros to them.`nEvery input field accepts the following syntax:"
    Gui, Add, Text, cWhite, % "AHK syntax: #^!G | Text syntax: WIN+CTRL+ALT+G or WIN CTRL ALT G"
    Gui, Add, Text, cWhite, % "It is also possible to add simple macros with AHK syntax:`n!Tab 2 (holds Alt, presses Tab twice, releases Alt)"
    Gui, Add, Text, cWhite, % "Non-single character keys (esc, tab) are to be referred with their full names (ESCAPE, TAB)`nMouse keys are to be referred as LButton, RButton, Mbutton, XButton1 and XButton2"
    Gui, Add, Text, cWhite, % "`nPress F1 to hide/show this GUI. (You can rebind this actually c:)"

    Gui, Font, s10, Segoe UI Bold
    Gui, Margin, 10,10
    ;Gui, Add, Button, xs+260 ys-4 w55 h30 vAllowMacroBtn gToggleAllowMacro, % (DoAllowMacro ? "Disable" : "Enable")


    Gui, Show, w764 h485, RemAppX - Key remapper utility
    GuiVisible := 1
    return
}

TabCh:
    Gui, Main:Submit, NoHide
return
    

HideGui:
GuiClose:
GuiEscape:
    GuiVisible := 0
    Gui, Main:Submit, NoHide
    Gui, Main:Destroy
    Tooltip, % "Switching to running in the background..."
    SetTimer, __HideTT, -1000
return

SafeExit:
    MsgBox, 308, Confirm, Are you sure you want to exit? All unsaved changes will be lost.
    IfMsgBox, No
        return
    ExitApp
return

ToggleRepeat:
    Gui, Main:Submit, NoHide
    DoRepeatOutputs := !DoRepeatOutputs
    GuiControl,, RepeatBtn, % (DoRepeatOutputs ? "Disable" : "Enable")
return

ToggleStartup:
    Gui, Main:Submit, NoHide
    DoStartup := !DoStartup
    if (!A_IsAdmin)
    {
        MsgBox, 16, Insufficient permissions, % "This setting requires the program to have administrator privileges.`nPlease launch the program again as administrator."
        DoStartup := 0
        GuiControl,, StartupBtn, % (DoStartup ? "Disable" : "Enable")
        return
    }
    if (FileExist(startupLnk) && DoStartup = 0) {
        FileDelete, %startupLnk%
    } else if (!FileExist(startupLnk) && DoStartup = 1) {
        FileCreateShortcut, %A_ScriptFullPath%, %startupLnk%, %A_ScriptDir%,, RemAppX startup entry
        if ErrorLevel {
            MsgBox, 16, Startup shortcut error, Unable to create a shortcut.`nPlease launch the program again as administrator.
            return
        }
    } else {
        DoStartup := (FileExist(startupLnk) ? 1 : 0)
    }
    GuiControl,, StartupBtn, % (DoStartup ? "Disable" : "Enable")
return
    

; Add a row to the GUI (used for existing and new bindings)
; At script top - create variables on demand
EnsureGlobalVar(name) {
    global
    if (%name% = "" && %name% != 0)  ; Check if undefined
        %name% := ""  ; Initialize
    return
}

; Modified AddGuiRow
AddGuiRow(key := "", cmd := "") {
    global GuiRows, ActiveRows, processing

    Gui, Tab, 1 ; assign to correct tab

    ; Check if we can recycle a hidden row
    if (ActiveRows < GuiRows) {
        ; Find first hidden row and recycle it
        Loop, %GuiRows%
        {
            row := A_Index
            GuiControlGet, isVisible, Visible, KeyEdit%row%
            if (isVisible = 0) {  ; Hidden row found
                ActiveRows++
                yPos := 32 + ((ActiveRows - 1) * 35)

                EnsureGlobalVar("KeyEdit" . row)
                EnsureGlobalVar("CmdEdit" . row)
                EnsureGlobalVar("DelRow" . row)
                
                ; Move to new position, clear, show, and populate
                GuiControl, Move, KeyEdit%row%, y%yPos%
                GuiControl, Move, CmdEdit%row%, y%yPos%
                GuiControl, Move, DelRow%row%, y%yPos%
                
                GuiControl,, KeyEdit%row%, %key%
                GuiControl,, CmdEdit%row%, %cmd%
                
                GuiControl, Show, KeyEdit%row%
                GuiControl, Show, CmdEdit%row%
                GuiControl, Show, DelRow%row%

                processing := 0
                return row
            }
        }
    }
    
    ; No hidden rows to recycle - create new
    GuiRows++
    row := GuiRows
    ActiveRows++

    EnsureGlobalVar("KeyEdit" . row)
    EnsureGlobalVar("CmdEdit" . row)
    EnsureGlobalVar("DelRow" . row)
    
    yPos := 115 + ((ActiveRows - 1) * 35)
    Gui, Font, s10, Segoe UI
    Gui, Add, Edit, x20 y%yPos% w220 h25 vKeyEdit%row% cWhite, %key%
    Gui, Add, Edit, x250 y%yPos% w450 h25 vCmdEdit%row% cWhite, %cmd%
    Gui, Font, s12, Segoe UI Bold
    Gui, Add, Button, x+10 yp w30 h25 gDelRow%row% vDelRow%row%, % "X"
    Gui, Font, s10, Segoe UI 
    
    processing := 0
    return row
}

AddRebindRow(inkey  := "", outkey := "")
{
    global GuiRows2, ActiveRows2, processing

    Gui, Tab, 2 ; assign to correct tab

    ; Check if we can recycle a hidden row
    if (ActiveRows2 < GuiRows2) {
        ; Find first hidden row and recycle it
        Loop, %GuiRows2%
        {
            row := A_Index
            GuiControlGet, isVisible, Visible, InEdit%row%
            if (isVisible = 0) {  ; Hidden row found
                ActiveRows2++
                yPos := 32 + ((ActiveRows2 - 1) * 35)

                EnsureGlobalVar("InEdit" . row)
                EnsureGlobalVar("OutEdit" . row)
                EnsureGlobalVar("DelRow2" . row)
                
                ; Move to new position, clear, show, and populate
                GuiControl, Move, InEdit%row%, y%yPos%
                GuiControl, Move, OutEdit%row%, y%yPos%
                GuiControl, Move, DelRow2%row%, y%yPos%
                
                GuiControl,, InEdit%row%, %inkey%
                GuiControl,, OutEdit%row%, %outkey%
                
                GuiControl, Show, InEdit%row%
                GuiControl, Show, OutEdit%row%
                GuiControl, Show, DelRow2%row%
                
                processing := 0
                return row
            }
        }
    }
    
    ; No hidden rows to recycle - create new
    GuiRows2++
    row := GuiRows2
    ActiveRows2++

    EnsureGlobalVar("InEdit" . row)
    EnsureGlobalVar("OutEdit" . row)
    EnsureGlobalVar("DelRow2" . row)
    
    yPos := 115 + ((ActiveRows2 - 1) * 35)
    Gui, Font, s10, Segoe UI
    Gui, Add, Edit, x20 y%yPos% w220 h25 vInEdit%row% cWhite, %inkey%
    Gui, Add, Edit, x250 y%yPos% w450 h25 vOutEdit%row% cWhite, %outkey%
    Gui, Font, s12, Segoe UI Bold
    Gui, Add, Button, x+10 yp w30 h25 gDelRow2%row% vDelRow2%row%, % "X"
    Gui, Font, s10, Segoe UI 
    
    processing := 0
    return row
}

; Add new empty row
AddRowBtn:
    global ActiveRows, MaxRows, processing
    if (processing)
        return
    processing := 1
    if ((CurrentTab = 1 && ActiveRows >= MaxRows) || (CurrentTab = 2 && ActiveRows2 >= MaxRows)) {
        MsgBox, 48, Limit reached, Maximum of %MaxRows% bindings allowed.
        return
    }
    if (CurrentTab = 1)
        AddGuiRow()
    else if (CurrentTab = 2)
        AddRebindRow()
return

; Save current GUI state to file
SaveBtn:
    Gui, Main:Submit, NoHide
    if (saving)
        return
    saving := 1
    
    ; Clear array and rebuild from GUI fields
    CmdArr := {}
    KeyArr := {}
    
    savedCount := 0
    Gui, Tab, 1
    Loop, %GuiRows%
    {
        row := A_Index
        GuiControlGet, key,, KeyEdit%row%
        GuiControlGet, cmd,, CmdEdit%row%
        
        key := Trim(key)
        cmd := Trim(cmd)
        
        if (key != "" && cmd != "") {
            ; Normalize key format
            n := NormalizeKey(key)
            if (n = "") {
                MsgBox, 48, Invalid Key, "%key%" is not a valid key format. Please correct it.
                return
            } else {
            CmdArr[n] := cmd
            savedCount++
            }
        }
    }
    Gui, Tab, 2
    Loop, %GuiRows2%
    {
        row := A_Index
        GuiControlGet, inkey,, InEdit%row%
        GuiControlGet, outkey,, OutEdit%row%
        
        inkey := Trim(inkey)
        outkey := Trim(outkey)
        
        if (inkey != "" && outkey != "") {
            ; Normalize key format
            n := NormalizeKey(inkey)
            if (n = "") {
                MsgBox, 48, Invalid Key, "%inkey%" is not a valid key format. Please correct it.
                return
            } else {
            KeyArr[n] := outkey
            savedCount++
            }
        }
    }
    
    SaveConfig()
    TrayTip, RemAppX, % "Saved " savedCount " bindings", 2
return

; Load from file
LoadBtn:
    global loading
    if (loading)
        Return
    loading := 1
    LoadConfig()
    ShowGui()  ; Refresh to show loaded
return

; Clear all bindings
ClearBtn:
    global GuiRows, GuiRows2, ActiveRows, ActiveRows2, CmdArr, KeyArr, clearing
    if (clearing)
        return
    clearing := 1
    MsgBox, 308, Confirm, Remove all keybinds?
    IfMsgBox, No
        return
    ; Unregister all hotkeys
    for key, cmd in CmdArr {
        Try 
            Hotkey, $%key%, Off
    }
    for iinb, ooutb in KeyArr {
        Try 
            Hotkey, $%iinb%, Off
    }

    ActiveRows := 0
    ActiveRows2 := 0
    CmdArr := {}
    KeyArr := {}

    Gui, Tab, 1
    Loop, %GuiRows%
    {
        GuiControl, Hide, KeyEdit%A_Index%
        GuiControl, Hide, CmdEdit%A_Index%
        GuiControl, Hide, DelRow%A_Index%
        GuiControl,, KeyEdit%A_Index%, 
        GuiControl,, CmdEdit%A_Index%,
    }
    Gui, Tab, 2
    Loop, %GuiRows2%
    {
        GuiControl, Hide, InEdit%A_Index%
        GuiControl, Hide, OutEdit%A_Index%
        GuiControl, Hide, DelRow2%A_Index%
        GuiControl,, InEdit%A_Index%, 
        GuiControl,, OutEdit%A_Index%,
    }
    clearing := 0
return

; Apply changes without saving to file
ReloadBindings:
    if (reloading)
        return
    reloading := 1
    
    ; CAPTURE ALL GUI DATA ACROSS ALL TABS AT ONCE
    Gui, Main:Submit, NoHide
    
    ; Unregister existing
    for key, cmd in CmdArr {
        Try
            Hotkey, $%key%, Off
    }
    for inb, outb in keyArr {
        Try
            Hotkey, $%inb%, Off
    }
    CmdArr := {}
    KeyArr := {}

    appliedCount := 0
    
    ; Rebuild from submitted variables (works for all tabs)
    Loop, %GuiRows%
    {
        row := A_Index
        
        ; Read from variables directly instead of GuiControlGet
        key := Trim(KeyEdit%row%)
        cmd := Trim(CmdEdit%row%)
        
        if (key = "" && cmd = "")
            continue
            
        if (key != "" && cmd != "") {
            n := NormalizeKey(key)
            if (n = "") {
                MsgBox, 48, Invalid Key, % key " is not a valid key format. This entry will be skipped."
                continue
            } else {
                CmdArr[n] := cmd
                RegHotkey(n, cmd)
                appliedCount++
            }
        } else if (key != "" && cmd = "") {
            MsgBox, 48, Missing Command, Key "%key%" has no command. This entry will be skipped.
        } else if (key = "" && cmd != "") {
            MsgBox, 48, Missing Key, Command "%cmd%" has no key. This entry will be skipped."
        }
    }
    
    Loop, %GuiRows2%
    {
        row := A_Index
        
        ; Read from variables directly
        inkey := Trim(InEdit%row%)
        outkey := Trim(OutEdit%row%)
        
        if (inkey = "" && outkey = "")
            continue
            
        if (inkey != "" && outkey != "") {
            n := NormalizeKey(inkey)
            if (n = "") {
                MsgBox, 48, Invalid Key, % inkey " is not a valid key format. This entry will be skipped."
                continue
            } else {
                KeyArr[n] := outkey
                RegHotkey2(n, outkey)
                appliedCount++
            }
        } else if (inkey != "" && outkey = "") {
            MsgBox, 48, Missing Command, Key "%inkey%" has no command. This entry will be skipped."
        } else if (inkey = "" && outkey != "") {
            MsgBox, 48, Missing Key, Command "%outkey%" has no key. This entry will be skipped."
        }
    }
    
    TrayTip, RemAppX, % "Applied " appliedCount " bindings", 2
    reloading := 0
return

; Delete row handlers (dynamically generated)
DelRow1:
DelRow2:
DelRow3:
DelRow4:
DelRow5:
DelRow6:
DelRow7:
DelRow8:
DelRow9:
DelRow10:
    global rowassigning
    if (rowassigning)
        return
    rowassigning := 1
    row := SubStr(A_ThisLabel, 7)
    HandleDelRow(row)
return

HandleDelRow(row) {
    global ActiveRows, CmdArr

    Gui, Tab, 1
    
    ; Hide this row
    GuiControl, Hide, KeyEdit%row%
    GuiControl, Hide, CmdEdit%row%
    GuiControl, Hide, DelRow%row%
    
    ; Clear contents
    GuiControl,, KeyEdit%row%, 
    GuiControl,, CmdEdit%row%,
    
    ActiveRows--
    
    ; Reposition remaining visible rows to fill gaps
    RepositionVisibleRows()

    return
}

DelRow21:
DelRow22:
DelRow23:
DelRow24:
DelRow25:
DelRow26:
DelRow27:
DelRow28:
DelRow29:
DelRow210:
    if (rowassigning)
        return
    rowassigning := 1
    row := SubStr(A_ThisLabel, 8)
    HandleDelRow2(row)
return

HandleDelRow2(row) {
    global ActiveRows2, KeyArr

    Gui, Tab, 2
    
    ; Hide this row
    GuiControl, Hide, InEdit%row%
    GuiControl, Hide, OutEdit%row%
    GuiControl, Hide, DelRow2%row%
    
    ; Clear contents
    GuiControl,, InEdit%row%, 
    GuiControl,, OutEdit%row%,
    
    ActiveRows2--
    
    ; Reposition remaining visible rows to fill gaps
    RepositionVisibleRows2()

    return
}

RepositionVisibleRows() {
    global GuiRows, rowassigning
    visibleIndex := 0
    Gui, Tab, 1

    Loop, %GuiRows%
    {
        row := A_Index
        GuiControlGet, isVisible, Visible, KeyEdit%row%
        if (isVisible = 0)
            continue
            
        visibleIndex++
        yPos := 32 + ((visibleIndex - 1) * 35)  ; CHANGED: 80 -> 125 to match AddGuiRow
        
        GuiControl, Move, KeyEdit%row%, y%yPos%
        GuiControl, Move, CmdEdit%row%, y%yPos%
        GuiControl, Move, DelRow%row%, y%yPos%
    }
    rowassigning := 0
    return
}

RepositionVisibleRows2() {
    global GuiRows2
    visibleIndex := 0
    Gui, Tab, 2

    Loop, %GuiRows2%
    {
        row := A_Index
        GuiControlGet, isVisible, Visible, InEdit%row%
        if (isVisible = 0)
            continue
            
        visibleIndex++
        yPos := 32 + ((visibleIndex - 1) * 35)  ; CHANGED: 80 -> 125 to match AddGuiRow
        
        GuiControl, Move, InEdit%row%, y%yPos%
        GuiControl, Move, OutEdit%row%, y%yPos%
        GuiControl, Move, DelRow2%row%, y%yPos%
    }
    rowassigning := 0
    return
}

__HideTT: ; func to hide tooltips
    ToolTip
return

F1::
    IfWinExist, % "RemAppX - Key remapper utility"
    {
        if (GuiVisible) {
            Gosub, HideGui
            GuiVisible := 0
        } else {
            WinActivate, % "RemAppX - Key remapper utility"
            GuiVisible := 1
        }
    } 
    else 
    {
        ShowGui()
    }
return