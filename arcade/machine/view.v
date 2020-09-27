module machine

import gg
import gx
import sokol.sapp
import sokol.sgl

const (
	view_width_pixels  = 224
	view_height_pixels = 256
	render_channels    = 4
	framebuffer_addr   = 0x2400
)

struct View {
mut:
	framebuffer []byte
	context     &gg.Context = voidptr(0)
}

fn new_view(mut m Machine) View {
	mut v := View{
		framebuffer: []byte{len: view_width_pixels * view_height_pixels * render_channels, init: 0}
		context: gg.new_context({
			bg_color: gx.white
			width: view_width_pixels
			height: view_height_pixels
			use_ortho: true
			create_window: true
			window_title: 'V 8080'
			user_data: m
			frame_fn: frame
			event_fn: on_event
		})
	}
	return v
}

fn frame(mut m Machine) {
	m.view.context.begin()
	// Read the 8080's framebuffer and create an image out of it
	read_framebuffer(mut m)
	mut img := gg.Image{
		width: view_width_pixels
		height: view_height_pixels
		nr_channels: render_channels
		ok: true
		data: m.view.framebuffer.data
	}
	img.init_sokol_image()
	// Draw image
	u0 := f32(0.0)
	v0 := f32(0.0)
	u1 := f32(1.0)
	v1 := f32(1.0)
	x0 := f32(0) * m.view.context.scale
	y0 := f32(0) * m.view.context.scale
	x1 := f32(view_width_pixels) * m.view.context.scale
	y1 := f32(view_height_pixels) * m.view.context.scale
	//
	sgl.load_pipeline(m.view.context.timage_pip)
	sgl.enable_texture()
	sgl.texture(img.simg)
	sgl.begin_quads()
	sgl.c4b(255, 255, 255, 255)
	sgl.v2f_t2f(x0, y0, u0, v0)
	sgl.v2f_t2f(x1, y0, u1, v0)
	sgl.v2f_t2f(x1, y1, u1, v1)
	sgl.v2f_t2f(x0, y1, u0, v1)
	sgl.end()
	sgl.disable_texture()
	m.view.context.end()
	// Free image
	img.simg.free()
}

fn read_framebuffer(mut m Machine) {
	mem_ref := m.cpu.get_mem()
	for i in 0 .. view_width_pixels {
		for j := 0; j < view_height_pixels; j += 8 {
			pix := (*mem_ref)[framebuffer_addr + ((i * (view_height_pixels / 8)) + j / 8)]
			mut offset := (255 - j) * (view_width_pixels * render_channels) + (i * render_channels)
			for p in 0 .. 8 {
				if 0 != (pix & (1 << p)) {
					m.view.framebuffer[offset] = 255
					m.view.framebuffer[offset + 1] = 255
					m.view.framebuffer[offset + 2] = 255
					m.view.framebuffer[offset + 3] = 255
				} else {
					m.view.framebuffer[offset] = 0
					m.view.framebuffer[offset + 1] = 0
					m.view.framebuffer[offset + 2] = 0
					m.view.framebuffer[offset + 3] = 255
				}
				offset -= view_width_pixels
			}
		}
	}
}

// TODO: Platform specific input code, should go in a platform specific place
fn on_event(e &sapp.Event, mut m Machine) {
	if e.typ == .key_down {
		// m.io.input_down()
	} else if e.typ == .key_up {
		// m.io.input_up()
	}
}

// TODO
// fn map_input(key sapp.KeyCode) ?Input {}
