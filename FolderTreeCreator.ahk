/*
Folder Tree Creator
Copyright (C) 2025 Special-Niewbie Softwares
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, and distribute copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
Commercial use, sale, or integration of the Software into commercial products
requires explicit written permission from the copyright holder.
Redistributions in any form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

Menu, Tray, NoStandard

; System Tray Menu
Menu, Tray, Add, 👉 >>> Folder Tree Creator Menu <<<, TitleLabel
Menu, Tray, Disable, 👉 >>> Folder Tree Creator Menu <<<
Menu, Tray, Add, , Separator
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, Project Site, OpenProjectSite
Menu, Tray, Add, Donate, OpenDonationSite
Menu, Tray, Add, , Separator
Menu, Tray, Add, Show Version, ShowVersionInfo
Menu, Tray, Add, Exit, ExitApp

Gui, Font, s10, Segoe UI

Gui, Add, Button, x430 y25 w100 h30 gSelectTarget, Target Path

Gui, Add, Text, x20 y10 w200 h30, Select the destination folder:
Gui, Font, s10 cBFBFBF, Segoe UI
Gui, Add, Edit, x20 y30 w400 h20 vSelectedFolder ReadOnly hwndhEditTarget,
GuiControl,, SelectedFolder, No folder selected...

Gui, Font, s10 c000000, Segoe UI
Gui, Add, Text, x20 y70 w300 h30, Folder structure:
Gui, Add, TreeView, x20 y90 w510 h300 vMyTree gTreeEvent

; Load folder icon from shell32.dll
ImageListID := IL_Create(10)
folderIcon := IL_Add(ImageListID, "shell32.dll", 4) ; index 4 = folder
fileIcon := IL_Add(ImageListID, "shell32.dll", 2)  ; index 2 = generic file
TV_SetImageList(ImageListID)
NodeTypeMap := {}

Gui, Font, s10, Segoe UI

; Standard buttons
Gui, Add, Button, x20 y400 w100 h30 vBtnAdd gAddFolder, + Add
Gui, Add, Button, x130 y400 w100 h30 vBtnRemove gRemoveFolder, - Remove
Gui, Add, Button, x440 y440 w90 h30 vBtnStart gStartProcess, Start
Gui, Add, Button, x240 y400 w100 h30 vBtnAddFile gAddFile, + Add File
Gui, Add, Button, x20 y440 w100 h30 vBtnRename gRenameFolder, Rename

; Retrieve button HWNDs after creating them
GuiControlGet, hwndAdd, Hwnd, BtnAdd
GuiControlGet, hwndRemove, Hwnd, BtnRemove
GuiControlGet, hwndStart, Hwnd, BtnStart
GuiControlGet, hwndAddFile, Hwnd, BtnAddFile
GuiControlGet, hwndRename, Hwnd, BtnRename

; Use Windows call to color the buttons
OnMessage(0x135, "WM_CTLCOLORBTN")

; Brush defined in BGR format, I inverted the colors because if I put the color code of Blue I got red and vice versa
hBrushAdd    := CreateSolidBrush(0xFF9933)  ; Blu → BGR: 0xFF3333
hBrushRemove := CreateSolidBrush(0x0000FF)  ; Red → BGR: 0x3333FF
hBrushStart  := CreateSolidBrush(0xCCFF33)  ; Green
; hBrushAddFile := CreateSolidBrush(0xFF66FF)  ; Purple
hBrushRename := CreateSolidBrush(0x00FFFF)  ; Light Orange → BGR: 0x66CCFF

Gui, Show, w550 h480, Folder Tree Creator

Return

; -------------------------------------------------------
SelectTarget:
FileSelectFolder, SelectedFolder, , 3, Select the destination folder
if (SelectedFolder != "")
    GuiControl, , SelectedFolder, %SelectedFolder%
Return

; -------------------------------------------------------
AddFolder:
Gui, Submit, NoHide
selectedID := TV_GetSelection()

if (selectedID) {
    type := NodeTypeMap.HasKey(selectedID) ? NodeTypeMap[selectedID] : InferNodeType(selectedID)
    if (type = "file") {
        MsgBox, You can't add a folder inside a file!
        Return
    }
}

baseName := "New_Folder"
folderName := baseName
counter := 1

parentID := selectedID ? selectedID : 0
childID := TV_GetChild(parentID)
Loop {
    if (!childID)
        break
    TV_GetText(existingName, childID)
    if (existingName = folderName) {
        counter++
        folderName := baseName . counter
        childID := TV_GetChild(parentID)  ; the cycle begins again
        continue
    }
    childID := TV_GetNext(childID)
}

newID := TV_Add(folderName, parentID, "Icon" folderIcon)
NodeTypeMap[newID] := "folder"
if (selectedID)
    TV_Modify(selectedID, "Expand")

GuiControl, Choose, MyTree, %newID%
RenameFolderByID(newID)
GuiControl, Focus, SelectedFolder
GuiControl, Focus, MyTree
Return

; -------------------------------------------------------
RenameFolder:
Gui, Submit, NoHide
selectedID := TV_GetSelection()
if (!selectedID) {
    MsgBox, You must select a folder to rename.
    Return
}
RenameFolderByID(selectedID)
Return

; -------------------------------------------------------
RenameFolderByID(itemID) {
    TV_GetText(oldName, itemID)
    Gui, +OwnDialogs
    InputBox, newName, Rename folder, Enter new name:, , 300, 120, , , , , %oldName%
    if (ErrorLevel)
        Return
    TV_Modify(itemID, "Text", newName)
    GuiControl, Choose, MyTree, %itemID%
}

; -------------------------------------------------------
AddFile:
Gui, Submit, NoHide
selectedID := TV_GetSelection()

if (!selectedID) {
    MsgBox, You must first select a folder in the TreeView.
    Return
}

type := NodeTypeMap.HasKey(selectedID) ? NodeTypeMap[selectedID] : InferNodeType(selectedID)

if (type = "file") {
    MsgBox, You can't add a file inside a file!
    Return
}

baseName := "New_File"
ext := ".txt"
fileName := baseName . ext
counter := 1

; Search for duplicates among the children of the current node
childID := TV_GetChild(selectedID)
Loop {
    if (!childID)
        break
    TV_GetText(existingName, childID)
    if (existingName = fileName) {
        counter++
        fileName := baseName . counter . ext
        childID := TV_GetChild(selectedID)  ; the cycle begins again
        continue
    }
    childID := TV_GetNext(childID)
}

newID := TV_Add(fileName, selectedID, "Icon" fileIcon)
NodeTypeMap[newID] := "file"
TV_Modify(selectedID, "Expand")
GuiControl, Choose, MyTree, %newID%
RenameFolderByID(newID)
GuiControl, Focus, SelectedFolder
GuiControl, Focus, MyTree
Return

; -------------------------------------------------------
RemoveFolder:
Gui, Submit, NoHide
selectedID := TV_GetSelection()
if (selectedID)
    RemoveNodeAndChildren(selectedID)
Return

; -------------------------------------------------------
TreeEvent:
Return

; -------------------------------------------------------
StartProcess:
Gui, Submit, NoHide
if (!SelectedFolder || SelectedFolder = "No folder selected...")
{
    MsgBox, You need to select a destination folder, please click the "Target Path" button.
    Return
}
folderPaths := []
nodeIDs := []
GetTreePaths("", 0, folderPaths, nodeIDs)

for index, path in folderPaths
{
    id := nodeIDs[index]
    type := NodeTypeMap.HasKey(id) ? NodeTypeMap[id] : InferNodeType(id)
    fullPath := SelectedFolder . "\" . path

    if (type = "file") {
        FileAppend,, %fullPath%  ; create empty file
    } else {
        FileCreateDir, %fullPath%
    }
}
MsgBox, Struttura creata con successo in: %SelectedFolder%
Return

; -------------------------------------------------------
; Title
TitleLabel:
return

; Function to show version information
ShowVersionInfo:
{
    version := "1.0.0"

    MsgBox, 64, Version Info,
    (
Folder Tree Creator: %version%
		
Author: Special-Niewbie Softwares
Copyright (C) 2025 Special-Niewbie Softwares
    )
    Return
}

ReloadScript:
    Reload
return

OpenProjectSite:
    Run, https://github.com/Special-Niewbie/FolderTreeCreator
return	

OpenDonationSite:
	Run, https://www.paypal.com/ncp/payment/WYU4A2HTRTVHG
return

GuiClose:
ExitApp

ExitApp:
ExitApp

; -------------------------------------------------------
GetTreePaths(currentPath, parentID, ByRef folderPaths, ByRef nodeIDs) {
    itemID := TV_GetChild(parentID)
    while (itemID) {
        TV_GetText(text, itemID)
        fullPath := (currentPath = "" ? text : currentPath . "\" . text)
        folderPaths.Push(fullPath)
        nodeIDs.Push(itemID)
        GetTreePaths(fullPath, itemID, folderPaths, nodeIDs)
        itemID := TV_GetNext(itemID)
    }
}

; -------------------------------------------------------
; AGGIUNTA: funzione hook per colorare i bordi dei pulsanti
WM_CTLCOLORBTN(wParam, lParam) {
    global hwndAdd, hwndRemove, hwndStart, hwndRename
    global hBrushAdd, hBrushRemove, hBrushStart, hBrushRename
    if (lParam = hwndAdd) {
        Return hBrushAdd
    } else if (lParam = hwndRemove) {
        Return hBrushRemove
    } else if (lParam = hwndStart) {
        Return hBrushStart
    } else if (lParam = hwndAddFile) {
		Return hBrushAddFile
	} else if (lParam = hwndRename) {
        Return hBrushRename
    } 
}

; -------------------------------------------------------
; Windows Function to color the buttons
CreateSolidBrush(color) {
    return DllCall("gdi32.dll\CreateSolidBrush", "UInt", color, "Ptr")
}

; -------------------------------------------------------
RemoveNodeAndChildren(id) {
    global NodeTypeMap
    child := TV_GetChild(id)
    while (child) {
        RemoveNodeAndChildren(child)
        child := TV_GetNext(child)
    }
    NodeTypeMap.Delete(id)
    TV_Delete(id)
}

; -------------------------------------------------------
; Blow it's my Lib for TV_GetImageIndex as doesn't exist
TV_GetImageIndex(ByRef outIndex, id) {
    ; LVM_GETIMAGELIST = 0x1002, TVM_GETITEM = 0x110C
    VarSetCapacity(tvi, 48, 0) ; TVITEM structure (size may vary depending on AHK version)
    NumPut(0x1, tvi, 0, "UInt")       ; mask: TVIF_IMAGE
    NumPut(id, tvi, 4, "Ptr")         ; hItem
    SendMessage, 0x110C, 0, &tvi, , ahk_id %MyTree%  ; TVM_GETITEM
    outIndex := NumGet(tvi, 36, "Int") ; iImage is at offset 36
    return outIndex != ""
}


; -------------------------------------------------------
InferNodeType(id) {
    global fileIcon
    TV_GetText(label, id)
    TV_GetImageIndex(iconIndex, id)
    ; If the icon matches that of the files or if it has a .txt extension or any dot, consider it a file
    if (iconIndex = fileIcon || InStr(label, ".")) {
        NodeTypeMap[id] := "file"
        return "file"
    } else {
        NodeTypeMap[id] := "folder"
        return "folder"
    }
}


