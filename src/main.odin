﻿package main

import "core:time"
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import "core:log"
import "core:strings"
import "core:math/linalg"
import "core:math"

import sdl "vendor:sdl2"

import "dude"
import "dude/dgl"
import "dude/vendor/imgui"
import hla "dude/collections/hollow_array"

pass_main : dude.RenderPass

DemoGame :: struct {
    // mat_grid, mat_grid2 : dude.Material,
    texture_test : dgl.Texture,
    texture_9slice, texture_qq : dgl.Texture,
    player : dude.RObjHandle,

    test_mesh_triangle, mesh_grid, mesh_arrow : dgl.Mesh,

    tm_test : dgl.Mesh,

    robj_message : dude.RObjHandle,
    message_color : dude.Color,

    book : []rune,
    book_ptr : int,

    dialogue_size : f32,
}

@(private="file")
demo_game : DemoGame

main :: proc() {
    // dude.native_wnd_msg_handler = native_wnd_msg_handler
    dude.init("dude game demo", {_package_game, _test})
    dude.dude_main(update, init, release, on_gui)
}

@(private="file")
update :: proc(game: ^dude.Game, delta: f32) {
    using dude, demo_game
    @static time : f32 = 0
    time += delta

    viewport := app.window.size

    pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
    pass_main.camera.viewport = vec_i2f(viewport)

    pass_main.camera.angle = 0.06 * math.sin(time*0.8)
    pass_main.camera.size = 60 + 6 * math.sin(time*1.2)

    camera := &pass_main.camera
    t := hla.hla_get_pointer(player)
    move_speed :f32= 3.0
    if get_key(.A) do t.position.x -= move_speed * delta
    else if get_key(.D) do t.position.x += move_speed * delta
    if get_key(.W) do t.position.y += move_speed * delta
    else if get_key(.S) do t.position.y -= move_speed * delta

    pass_main.camera.position = t.position

    if get_key(.F) {
        _flip_page()
    }

    if get_mouse_button_down(.Left)  {
        if demo_game.dialogue_size == 0 {
            dude.tween(&game.global_tweener, &demo_game.dialogue_size, 1.0, 0.3)->set_easing(dude.ease_outcubic)
        } else if demo_game.dialogue_size == 1 {
            dude.tween(&game.global_tweener, &demo_game.dialogue_size, 0.0, 0.3)->set_easing(dude.ease_outcubic)
        }
    }

    {
        msg := hla.hla_get_pointer(robj_message)
        msg.position.x = -5
    }

    dude.immediate_screen_quad(&pass_main, get_mouse_position()-{8,8}, {16,16}, texture=texture_qq.id)

    to_screen :: proc(pos: dude.Vec2) -> dude.Vec2 {
        return dude.coord_world2screen(&pass_main.camera, pos)
    }

    dude.immediate_screen_quad(&pass_main, to_screen({0,0}), {16,16}, texture=texture_qq.id)
    dude.immediate_screen_quad(&pass_main, to_screen({3,0}), {16,16}, texture=texture_qq.id)
    dude.immediate_screen_quad(&pass_main, to_screen({6,0}), {16,16}, texture=texture_qq.id)

    {// test arrow
        root := dude.coord_world2screen(&pass_main.camera, {0,0})
        forward := dude.get_mouse_position() - root
        left := dude.rotate_vector(forward, 90 * math.RAD_PER_DEG)
        dude.immediate_screen_arrow(&pass_main, 
            root,
            root + forward,
            16.0, {200, 64, 32, 222})
        dude.immediate_screen_arrow(&pass_main, 
            root,
            root + left,
            16.0, {32, 230, 20, 222})
    }

    if demo_game.dialogue_size > 0 {
        dialogue(get_mouse_position(), {256, 128} * demo_game.dialogue_size, demo_game.dialogue_size)
    }
}

dialogue :: proc(anchor, size: dude.Vec2, alpha:f32) {
    padding :dude.Vec2= {64,64}
    size := linalg.max(padding, size)
    t := cast(f32)dude.game.time_total
    t = (math.sin(t * 2) + 1) * 0.5
    t = t * 0.8 + 0.2
    dude.immediate_screen_quad_9slice(&pass_main, anchor+{4-2*t,4-2*t}, size, size-padding, {0.5,0.5}, 
        color={0,0,0,cast(u8)(128*alpha)}, texture=demo_game.texture_9slice.id, order=100)
    dude.immediate_screen_quad_9slice(&pass_main, anchor, size, size-padding, {0.5,0.5}, 
        texture=demo_game.texture_9slice.id, order=101, color={255,255,255, cast(u8)(alpha*255.0)})
}

@(private="file")
init :: proc(game: ^dude.Game) {
    using demo_game
    append(&game.render_pass, &pass_main)

    {// ** Build meshes.
        using dgl
        mb := &dude.rsys.temp_mesh_builder

        mesh_builder_reset(mb, VERTEX_FORMAT_P2U2)
        mesh_builder_add_vertices(mb,
            {v4={-1.0, -1.0, 0,0}},
            {v4={1.0,  -1.0, 1,0}},
            {v4={-1.0, 1.0,  0,1}},
        )
        mesh_builder_add_indices(mb, 0,1,2)
        test_mesh_triangle = mesh_builder_create(mb^)

        mesh_builder_reset(mb, VERTEX_FORMAT_P2U2C4)
        dude.mesher_arrow_p2u2c4(mb, {0,0}, {0,-1}, 0.2, {.9,.3,.2, 1.0})
        mesh_arrow = mesh_builder_create(mb^)

        mesh_builder_reset(mb, VERTEX_FORMAT_P2U2C4)
        dude.mesher_line_grid(mb, 20, 1.0, {0.18,0.14,0.13, 1}, 5, {0.1,0.04,0.09, 1})
        mesh_grid = mesh_builder_create(mb^, true) // Because the mesh is a lines mesh.

        texture_test = texture_load_from_mem(#load("../res/texture/dude.png"))
        texture_9slice = texture_load_from_mem(#load("../res/texture/default_ui_background_9slice.png"))
        texture_qq = texture_load_from_mem(#load("../res/texture/qq.png"))
        texture_set_filter(texture_9slice.id, .Nearest, .Nearest)
    }

    using dude
    utable_general := rsys.shader_default_mesh.utable_general

    // Pass initialization
    render_pass_init(&pass_main, {0,0, app.window.size.x, app.window.size.y})
    pass_main.clear.color = {.2,.2,.2, 1}
    pass_main.clear.mask = {.Color,.Depth,.Stencil}
    blend := &pass_main.blend.(dgl.GlStateBlendSimp)
    blend.enable = true

    // render_pass_add_object(&pass_main, RObjMesh{mesh=rsys.mesh_unit_quad}, &mat_red, position={0.2,0.8})
    // render_pass_add_object(&pass_main, RObjMesh{mesh=rsys.mesh_unit_quad}, position={1.2,1.1})
    // render_pass_add_object(&pass_main, RObjMesh{mesh=test_mesh_triangle, mode=.LineStrip}, position={.2,.2})
    // render_pass_add_object(&pass_main, RObjSprite{{1,1,1,1}, texture_test.id, {0.5,0.5}, {1,1}}, order=101)

    player = render_pass_add_object(&pass_main, 
        RObjSprite{color={1,1,1,1}, texture=texture_test.id, size={4,4}, anchor={0.5,0.5}}, order=100)

    render_pass_add_object(&pass_main, RObjMesh{mesh=mesh_grid, mode=.Lines}, order=-9999, vertex_color_on=true)
    render_pass_add_object(&pass_main, RObjMesh{mesh=mesh_arrow}, vertex_color_on=true)

    tm_test = dude.mesher_text(&rsys.fontstash_context, "诗篇46的秘密\n试试换行", 32)

    robj_message = render_pass_add_object(&pass_main, RObjTextMesh{text_mesh=tm_test, color={.8,.6,0,1}}, scale={0.05,0.05}, order=999)

    if book_data, ok := os.read_entire_file("./res/The Secret of Psalm 46.md"); ok {
        book = utf8.string_to_runes(string(book_data))
        delete(book_data)
    }

    systray_init()
}

@(private="file")
_flip_page :: proc() {
    if demo_game.book_ptr >= len(demo_game.book) do return
    
    dude.render_pass_remove_object(demo_game.robj_message)
    dgl.mesh_delete(&demo_game.tm_test)
    line : []rune
    pick := 20

    for i in 0..<math.min(pick, len(demo_game.book)) {
        if demo_game.book[i] == '\n' {
            line = demo_game.book[:i]
            demo_game.book = demo_game.book[i+1:]
            break
        }
    }
    if len(line) == 0 && demo_game.book_ptr != len(demo_game.book)-1 {
        cut := math.min(pick, len(demo_game.book)-1)
        line = demo_game.book[:cut]
        demo_game.book = demo_game.book[cut+1:]
    }

    using demo_game
    line_str := utf8.runes_to_string(line, context.temp_allocator)
    tm_test = dude.mesher_text(&dude.rsys.fontstash_context, line_str, 32)
    robj_message = dude.render_pass_add_object(&pass_main, dude.RObjTextMesh{text_mesh=tm_test, color={.8,.6,0,1}}, scale={0.05,0.05}, order=999)
}

@(private="file")
release :: proc(game: ^dude.Game) {
    systray_release()

    delete(demo_game.book)
    dgl.mesh_delete(&demo_game.tm_test)

    using dude, demo_game
    dgl.texture_delete(&texture_test.id)
    dgl.texture_delete(&texture_qq.id)
    
	dgl.mesh_delete(&test_mesh_triangle)
	dgl.mesh_delete(&mesh_grid)

    render_pass_release(&pass_main)
}

@(private="file")
on_gui :: proc() {
    using demo_game, imgui
    begin("DemoGame", nil)
    text("Frame time: %f", time.duration_seconds(dude.app.duration_frame))
    p : ^dude.RenderObject = hla.hla_get_pointer(player)
    slider_float2("position", &p.position, -10, 10)
    img := imgui.Texture_ID(uintptr(dude.rsys.fontstash_data.atlas))
    @static scale :f32= 1.0
    text("mouse pos: %f", dude.get_mouse_position())
    text(fmt.tprintf("current atlas size: ({}, {})", dude.rsys.fontstash_context.width, dude.rsys.fontstash_context.height))
    slider_float("atlas scale", &scale, 0.001, 1.0)
    image(img, scale * Vec2{512,512}, border_col={1,1,0,1})
    message := hla.hla_get_pointer(robj_message)
    tm := &message.obj.(dude.RObjTextMesh)
    color_picker4("Text Color", cast(^Vec4)&tm.color)
    end()
}

@(private="file")
_package_game :: proc(args: []string) {
	fmt.printf("command: package game\n")
}
@(private="file")
_test :: proc(args: []string) {
	fmt.printf("command: test\n")
}