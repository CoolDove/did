package main    

import win32 "core:sys/windows"

import "core:runtime"

import "core:strings"
import "core:slice"
import "core:c"
import "core:log"
import "core:mem"

import sdl "vendor:sdl2"

import "dude"

nid : win32.NOTIFYICONDATAW
menu : win32.HMENU

CWM_SYSTRAY :: win32.WM_USER+6

systray_init :: proc() {
    // Get the window handle
    wm_info : sdl.SysWMinfo// SDL_SysWMinfo;
    wnd := dude.game.window.window
    sdl.GetVersion(&wm_info.version)
    sdl.GetWindowWMInfo(wnd, &wm_info)
    
    hwnd := wm_info.info.win.window
    hinstance := wm_info.info.win.hinstance

    // Set up the taskbar icon
    nid.cbSize = size_of(win32.NOTIFYICONDATAW)
    nid.hWnd = transmute(win32.HWND)hwnd
    nid.uFlags = win32.NIF_ICON | win32.NIF_TIP | win32.NIF_MESSAGE | win32.NIF_INFO
    nid.uCallbackMessage = CWM_SYSTRAY
    nid.uID = 1  // Unique ID for the icon
    
    iconw := win32.utf8_to_utf16("APP_ICON")
    nid.hIcon = win32.LoadIconW(transmute(win32.HANDLE)hinstance, raw_data(iconw))

    tipw := win32.utf8_to_utf16("Hello, Dove. 你好，鸽子。")
    mem.copy(raw_data(nid.szTip[:]), raw_data(tipw), len(tipw) * size_of(u16))

    // Add the icon to the taskbar
    win32.Shell_NotifyIconW(win32.NIM_ADD, &nid)

    menu :win32.HMENU = win32.CreatePopupMenu();
    option1 := win32.utf8_to_utf16("选项 1")
    option2 := win32.utf8_to_utf16("option 2")
    win32.AppendMenuW(menu, win32.MF_STRING, 1, raw_data(option1));
    win32.AppendMenuW(menu, win32.MF_STRING, 2, raw_data(option2));
    
    dude.wnd_handler = systray_handler
}

systray_release :: proc() {
    win32.Shell_NotifyIconW(win32.NIM_DELETE, &nid);
}

systray_handler :: proc(wnd:^dude.Window, event:sdl.Event) {
    if event.type == .SYSWMEVENT {
        msg := event.syswm.msg.msg.win
        wm_info : sdl.SysWMinfo// SDL_SysWMinfo;
        wnd := dude.game.window.window
        sdl.GetVersion(&wm_info.version)
        sdl.GetWindowWMInfo(wnd, &wm_info)
        
        hwnd := cast(win32.HWND)wm_info.info.win.window
        hinstance := wm_info.info.win.hinstance
        if msg.msg == CWM_SYSTRAY {
            if msg.lParam == win32.WM_RBUTTONUP {
                win32.SendMessageW(hwnd, win32.WM_CLOSE, 0, 0)
            } else if msg.lParam == win32.WM_LBUTTONUP {
                visible := (transmute(u32)win32.GetWindowLongW(hwnd, win32.GWL_STYLE) & win32.WS_VISIBLE) != 0
                win32.ShowWindow(hwnd, win32.SW_HIDE if visible else win32.SW_SHOW)
            }
        }
    }
}