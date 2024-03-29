package dude

import "core:fmt"
import "core:c"
import "core:log"
import "core:os"
import "core:strings"
import win32 "core:sys/windows"
import sdl  "vendor:sdl2"
import gl   "vendor:OpenGL"


OPENGL_VERSION_MAJOR :: 4
OPENGL_VERSION_MINOR :: 4

Window :: struct {
	// NOTE(Dove): 
	// The GLContext is not correct during `handler`, 
	// so do not use any OpenGL things in `handler`.
	using vtable : ^Window_VTable,

	using state : WindowState,

    imgui_state : ImguiState,

	position, size : Vec2i,

	name     : string,

	window_flags   : sdl.WindowFlags,
	renderer_flags : sdl.RendererFlags,

    window   : ^sdl.Window,
	renderer : ^sdl.Renderer,

	is_opengl_window : bool,
	gl_context : sdl.GLContext,

	_data_type : typeid,
	_data : rawptr, // This is invalid before instantiated.
}

WindowState :: struct {
	fullscreen : WindowFullscreenMode,
}

Window_VTable :: struct {
	handler  : proc(wnd:^Window, event:sdl.Event), 
}

WindowFullscreenMode :: enum {
	Fullscreen, Windowed, FullscreenDesktop,
}

window_get_basic_template :: proc(name: string, size : Vec2i = Vec2i{800, 600}, is_opengl_window : bool = true) -> Window {
	wnd : Window
	wnd.name = name

	wnd.is_opengl_window = is_opengl_window
	if is_opengl_window {
		wnd.window_flags |= { .OPENGL, .ALWAYS_ON_TOP, .POPUP_MENU, .RESIZABLE, .HIDDEN }
	} 
	wnd.position = sdl.WINDOWPOS_UNDEFINED
	wnd.size = size
    return wnd
}

window_instantiate :: proc(using wnd:^Window) -> bool {
	window = sdl.CreateWindow(
	    strings.clone_to_cstring(name, context.temp_allocator),
	    position.x, position.y, size.x, size.y,
	    window_flags)
    sdl.EventState(.SYSWMEVENT, sdl.ENABLE)

	if window == nil {
        fmt.println("failed to instantiate window: ", name)
		return false
	}

	if .FULLSCREEN in wnd.window_flags {
		if sdl.WindowFlag._INTERNAL_FULLSCREEN_DESKTOP in window_flags do fullscreen = .FullscreenDesktop
		else do fullscreen = .Fullscreen
	} else do fullscreen = .Windowed

	if is_opengl_window {
		gl_context = sdl.GL_CreateContext(window)
		assert(gl_context != nil, fmt.tprintf("Failed to create GLContext for window: {}, because: {}.\n", name, sdl.GetError()))

		sdl.GL_MakeCurrent(window, gl_context)
		gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, sdl.gl_set_proc_address)
        sdl.GL_SetSwapInterval(1)

        gl.Enable(gl.MULTISAMPLE)
	} else {
		renderer = sdl.CreateRenderer(window, -1, renderer_flags)
		assert(renderer != nil, fmt.tprintf("Failed to create renderer for window: {}, because: {}.\n", name, sdl.GetError()))
	}
	return true
}

window_destroy :: proc(using wnd:^Window) {
	if window == nil do return

	if _data != nil do free(_data)
	sdl.DestroyWindow(window)
	if renderer != nil do sdl.DestroyRenderer(renderer)
	window = nil
    renderer = nil
}

// FIXME: FullscreenDesktop mode is not correctly working, viewport and resolution broken.
window_toggle_fullscreen :: proc(using wnd:^Window, mode: WindowFullscreenMode) {
	zero :u32= 0
	flags : sdl.WindowFlags = transmute(sdl.WindowFlags)zero
	if mode == .FullscreenDesktop do flags = sdl.WINDOW_FULLSCREEN_DESKTOP
	else if mode == .Fullscreen do flags = sdl.WINDOW_FULLSCREEN
	if sdl.SetWindowFullscreen(window, flags) >= 0 do fullscreen = mode
}
