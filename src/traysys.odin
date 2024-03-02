package main    

import win32 "core:sys/windows"

import "core:runtime"

import "core:strings"
import "core:slice"
import "core:c"
import "core:log"
import "core:mem"

import "vendor:sdl2"

import "dude"

nid : win32.NOTIFYICONDATAW
menu : win32.HMENU

systray_init :: proc() {
    // Get the window handle
    wm_info : sdl2.SysWMinfo// SDL_SysWMinfo;
    wnd := dude.game.window.window
    sdl2.GetVersion(&wm_info.version)
    sdl2.GetWindowWMInfo(wnd, &wm_info)
    
    hwnd := wm_info.info.win.window
    hinstance := wm_info.info.win.hinstance

    // Set up the taskbar icon
    nid.cbSize = size_of(win32.NOTIFYICONDATAW)
    nid.hWnd = transmute(win32.HWND)hwnd
    nid.uFlags = win32.NIF_ICON | win32.NIF_TIP | win32.NIF_MESSAGE | win32.NIF_INFO
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
    
}

systray_release :: proc() {
    win32.Shell_NotifyIconW(win32.NIM_DELETE, &nid);
}

native_wnd_msg_handler :: proc "c" (userdata: rawptr, hWnd: rawptr, message: c.uint, wParam: u64, lParam: i64) {
	context = runtime.default_context()
    log.debugf("message")
    switch message {
    case win32.WM_NOTIFY:
        log.debugf("notify")
        // 处理任务栏图标的消息
        switch lParam {
            // case WM_LBUTTONUP:
                // // MessageBox(hWnd, TEXT("任务栏图标被左键点击"), TEXT("提示"), MB_ICONINFORMATION);
                // break;
            case win32.WM_RBUTTONUP: 
                wm_info : sdl2.SysWMinfo// SDL_SysWMinfo;
                wnd := dude.game.window.window
                sdl2.GetVersion(&wm_info.version)
                sdl2.GetWindowWMInfo(wnd, &wm_info)

                hwnd :win32.HWND= auto_cast wm_info.info.win.window
            
                pt : win32.POINT
                win32.GetCursorPos(&pt)

                win32.SetForegroundWindow(hwnd)
                win32.TrackPopupMenu(menu, win32.TPM_RIGHTBUTTON, auto_cast pt.x, auto_cast pt.y, 0, hwnd, nil)
                // win32.PostMessage(hwnd, WM_NULL, 0, 0); // 发送一个空消息，以关闭弹出的菜单
                // win32.DestroyMenu(menu)
                break;
            
        }

    }

    
    
}