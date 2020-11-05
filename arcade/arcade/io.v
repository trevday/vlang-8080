module arcade

import audio
import utils

struct IO {
mut:
	// Special 16 bit shift register
	shift   u16
	offset  byte
	input_1 byte
	input_2 byte
	out_3   byte
	out_5   byte
	audio_player  &audio.Player
}

fn (io IO) op_in(port byte) ?byte {
	match port {
		1 { return io.input_1 }
		2 { return io.input_2 }
		3 { return byte((io.shift >> (8 - io.offset)) & 0xff) }
		else { return error('port unsupported for in by machine') }
	}
}

fn (mut io IO) op_out(port, val byte) ? {
	match port {
		2 {
			io.offset = val & 0x7
		}
		3 {
			if val & 0x01 == 0x01 && io.out_3 & 0x01 != 0x01 {
				io.audio_player.play(0, true)?
			}
			if val & 0x01 != 0x01 && io.out_3 & 0x01 == 0x01 {
				// Sound 0 repeats, so need to stop it when it turns off
				io.audio_player.stop(0)?
			}
			if val & 0x02 == 0x02 && io.out_3 & 0x02 != 0x02 {
				io.audio_player.play(1, false)?
			}
			if val & 0x04 == 0x04 && io.out_3 & 0x04 != 0x04 {
				io.audio_player.play(2, false)?
			}
			if val & 0x08 == 0x08 && io.out_3 & 0x08 != 0x08 {
				io.audio_player.play(3, false)?
			}
			io.out_3 = val
		}
		4 {
			a, _ := utils.break_address(io.shift)
			io.shift = utils.create_address(val, a)
		}
		5 {
			if val & 0x01 == 0x01 && io.out_5 & 0x01 != 0x01 {
				io.audio_player.play(4, false)?
			}
			if val & 0x02 == 0x02 && io.out_5 & 0x02 != 0x02 {
				io.audio_player.play(5, false)?
			}
			if val & 0x04 == 0x04 && io.out_5 & 0x04 != 0x04 {
				io.audio_player.play(6, false)?
			}
			if val & 0x08 == 0x08 && io.out_5 & 0x08 != 0x08 {
				io.audio_player.play(7, false)?
			}
			if val & 0x10 == 0x10 && io.out_5 & 0x10 != 0x10 {
				io.audio_player.play(8, false)?
			}
			io.out_5 = val
		}
		6 {
			// No-op
		}
		else {
			return error('port unsupported for out by machine')
		}
	}
}

pub enum Input {
	coin
	tilt
	player1_start
	player1_shoot
	player1_left
	player1_right
	player2_start
	player2_shoot
	player2_left
	player2_right
}

fn (mut io IO) input_down(i Input) {
	match i {
		.coin { io.input_1 |= 0x01 }
		.tilt { io.input_2 |= 0x04 }
		.player1_start { io.input_1 |= 0x04 }
		.player1_shoot { io.input_1 |= 0x10 }
		.player1_left { io.input_1 |= 0x20 }
		.player1_right { io.input_1 |= 0x40 }
		.player2_start { io.input_1 |= 0x02 }
		.player2_shoot { io.input_2 |= 0x10 }
		.player2_left { io.input_2 |= 0x20 }
		.player2_right { io.input_2 |= 0x40 }
	}
}

fn (mut io IO) input_up(i Input) {
	match i {
		.coin { io.input_1 &= 0xfe }
		.tilt { io.input_2 &= 0xfb }
		.player1_start { io.input_1 &= 0xfb }
		.player1_shoot { io.input_1 &= 0xef }
		.player1_left { io.input_1 &= 0xdf }
		.player1_right { io.input_1 &= 0xbf }
		.player2_start { io.input_1 &= 0xfd }
		.player2_shoot { io.input_2 &= 0xef }
		.player2_left { io.input_2 &= 0xdf }
		.player2_right { io.input_2 &= 0xbf }
	}
}
