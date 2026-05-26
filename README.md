# RemAppX
Nemesis Open-Source Redistributable project #3. 
A simple keyboard remapper tool that allows mapping terminal commands to keybinds
## Why terminal commands?
We wanted to reproduce the Linux feature in many desktop environments (such as KDE plasma, or Hyprland which actually isn't a DE but a WM) where users can add terminal commands to their keybinds and bring it to Windows. 
For example (Hyprland.conf extract - hyprlang): 
```
$Mainmod Shift, F, exec, alacritty -e fastfetch
```
## Details
RemAppX is designed to be fast, lightweight and easy to use. The app includes a guide which is also readable below
## Requirements
- **Script version:** AutoHotKey v1.1.37.02 or newer.
- **Raw compiled executable:** Any up-to-date Windows 10 version or Windows 11.
- **MPRESS compressed compiled executable:** Any Windows version able to run MPRESS compressed executables.
## Guide
### Buttons:
- **Add Binding:** Adds a new bind option (empty bind options are removed anytime the GUI reloads itself.
- **Clear Bindings:** Deletes every bind option from both tabs.
- **Apply:** Caches all currently added bind options and activates them.
- **Save:** Saves all currently added bind options and all settings to files (keybinds.cfg for configs and remappxsettings.ini for settings).
- **Load:** Loads the keybinds and settings files and applies their contents. Use when you accidently remove your binds or change something inside the files instead of through the UI.
- **Export/Import:** Opens a dialog to export your keybinds or import someone else's.
- **Exit:** Shows a confirmation message and then exits the process.
### Command Mapper Tab
- **Keybind column:** Type in the keybind string here (see Keybind Syntax below).
- **Command column:** Type in any valid terminal command (see Examples).
- **X (Delete Bind):** Deletes the bind option and its contents.
### Key Remapper Tab
- **Keybind column:** Type in the keybind string here (see Keybind Syntax below).
- **Output column:** Type in the keybind string here (see Key Output Syntax below).
- **X (Delete Bind):** Deletes the bind option and its contents.
### Settings Tab
- **Repeat outputs while held:** if enabled, loops sending the output of an input key while that input key is being held (Remaps only).
- **Repeat buffer:** time to wait between a recognized input and the beginning of the repeat loop.
- **Repeat delay:** time to wait between two repetitions during the repeat loop.
- **Run at startup:** inserts a shortcut to the executable/script 's current path in the `shell:startup` folder.
### Usage Guide Tab
- has a shorter version of this guide inside
## Keybind Syntax
Both keybind columns accept the following syntax:
- AHK v1 syntax: `#^!B`
  - `#` corresponds to the Windows key
  - `+` to Shift
  - `!` to Alt
  - and `^` to Control
- Text syntax 1: `Win+Ctrl+Alt+B`
  - Each modifier key has it's own shortened name: `Win, Ctrl, Alt, Shift`
  - Each modifier key has a `+` symbol right after their shortened names
- Text syntax 2: `Win Ctrl Alt B`
  - Each modifier key has it's own shortened name: `Win, Ctrl, Alt, Shift`
  - Each modifier key has whitespace right after their shortened names or they follow the same order as their shortened names were listed in

- Additionally, the parser is able to recognize keys such as `Tab` or `Escape` as valid keys. This applies for modifier keys as well, where the rightmost text-syntax modifier key  will be recognized as the input key and all other modifiers will stay as modifiers
- Mouse keys are recognized as `Lbutton, Rbutton` (Left/Right click), `Mbutton` (Middle click / scrollwheel click), `Xbutton1` (Backward) and `XButton2` (Forward) following AHKv1 syntax
## Key Output Syntax
Key outputs follow the same syntax as input keybinds, with an extra addition:
The parser first extracts the modifier keys and puts them ahead of the rest of the string passed, so any extra additions with the `Send` function in AHK v1.1.37.02 also work. 
```
for example: Win+Ctrl+B -> #^B -> #^{B}
or: Alt Tab 3 -> !Tab 3 -> !{Tab 3}
```
Some examples are:
- typing `keyname x` after the modifiers where keyname is a valid output key and x is a positive integer, that keybind will be sent as `modifier down, press keybind x times, modifier up`
- typing `keyname Raw` after the modifiers will send the output key as a raw output (see AHKv1 docs)
- and so on with every feature AHKv1 supports in this version

## Examples:
Command maps:
```
#Escape -> taskmgr
#Q -> start cmd.exe
#Z -> start firefox.exe
```
Remaps:
```
#C -> !F4
#1 -> !Tab
#2 -> !Tab 2
```
