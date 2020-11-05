module arcade

import gg
import gx
import sokol.sapp
import sokol.sgl

const (
	view_width_pixels  = 224
	view_height_pixels = 256
	image_channels     = 4
	framebuffer_addr   = 0x2400
	pixel_on           = byte(255)
	pixel_off          = byte(0)
)

struct View {
mut:
	framebuffer []byte
	context     &gg.Context = voidptr(0)
	width       int = view_width_pixels
	height      int = view_height_pixels
}

fn new_view(mut hardware Hardware) View {
	mut v := View{
		framebuffer: []byte{len: view_width_pixels * view_height_pixels * image_channels, init: 0}
		context: gg.new_context({
			bg_color: gx.white
			width: view_width_pixels
			height: view_height_pixels
			use_ortho: true
			create_window: true
			resizable: true
			window_title: 'V 8080'
			user_data: hardware
			frame_fn: frame
			event_fn: on_event
		})
	}
	return v
}

fn frame(mut hardware Hardware) {
	hardware.view.context.begin()
	// Read the 8080's framebuffer and create an image out of it
	read_framebuffer(mut hardware)
	mut img := gg.Image{
		width: view_width_pixels
		height: view_height_pixels
		nr_channels: image_channels
		ok: true
		data: hardware.view.framebuffer.data
	}
	img.init_sokol_image()
	// Draw image
	u0 := f32(0.0)
	v0 := f32(0.0)
	u1 := f32(1.0)
	v1 := f32(1.0)
	x0 := f32(0)
	y0 := f32(0)
	x1 := hardware.view.width * hardware.view.context.scale
	y1 := hardware.view.height * hardware.view.context.scale
	//
	sgl.load_pipeline(hardware.view.context.timage_pip)
	sgl.enable_texture()
	sgl.texture(img.simg)
	sgl.begin_quads()
	sgl.c4b(pixel_on, pixel_on, pixel_on, pixel_on)
	sgl.v2f_t2f(x0, y0, u0, v0)
	sgl.v2f_t2f(x1, y0, u1, v0)
	sgl.v2f_t2f(x1, y1, u1, v1)
	sgl.v2f_t2f(x0, y1, u0, v1)
	sgl.end()
	sgl.disable_texture()
	hardware.view.context.end()
	// Free image
	img.simg.free()
}

// Convert 1-bit image to 4-byte, and rotate
// by 90 degrees clockwise
fn read_framebuffer(mut hardware Hardware) {
	hardware.mtx.m_lock()
	mem_ref := hardware.cpu.get_mem()
	for y in 0 .. view_width_pixels {
		for x in 0 .. view_height_pixels {
			bit_idx := (y * view_height_pixels) + x
			mem_idx := bit_idx / 8
			data := (*mem_ref)[mem_idx + framebuffer_addr]
			pixel := data & (1 << (bit_idx - (mem_idx * 8)))
			out_offset := (((view_height_pixels - 1 - x) * view_width_pixels) + y) * image_channels
			if pixel == 0 {
				hardware.view.framebuffer[out_offset] = pixel_off
				hardware.view.framebuffer[out_offset + 1] = pixel_off
				hardware.view.framebuffer[out_offset + 2] = pixel_off
				hardware.view.framebuffer[out_offset + 3] = pixel_on
			} else {
				hardware.view.framebuffer[out_offset] = pixel_on
				hardware.view.framebuffer[out_offset + 1] = pixel_on
				hardware.view.framebuffer[out_offset + 2] = pixel_on
				hardware.view.framebuffer[out_offset + 3] = pixel_on
			}
		}
	}
	hardware.mtx.unlock()
}

fn (mut v View) resize() {
	mut s := sapp.dpi_scale()
	if s == 0.0 {
		s = 1.0
	}
	v.width = int(sapp.width() / s)
	v.height = int(sapp.height() / s)
}

// TODO: Platform specific input code, should go in a platform specific place
fn on_event(e &sapp.Event, mut hardware Hardware) {
	match e.typ {
		.key_down {
			if k := map_input(e.key_code) {
				hardware.mtx.m_lock()
				hardware.io.input_down(k)
				hardware.mtx.unlock()
			}
		}
		.key_up {
			if k := map_input(e.key_code) {
				hardware.mtx.m_lock()
				hardware.io.input_up(k)
				hardware.mtx.unlock()
			}
		}
		.resized, .restored, .resumed {
			hardware.view.resize()
		}
		else {
			// No-op
		}
	}
}

fn map_input(key sapp.KeyCode) ?Input {
	match key {
		.space { return .coin }
		.backspace { return .tilt }
		.q { return .player1_start }
		.w { return .player1_shoot }
		.a { return .player1_left }
		.d { return .player1_right }
		.p { return .player2_start }
		.up { return .player2_shoot }
		.left { return .player2_left }
		.right { return .player2_right }
		else { return none }
	}
}
