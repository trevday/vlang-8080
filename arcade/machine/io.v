module machine

import audio
import utils

struct IOState {
mut:
	// Special 16 bit shift register
	shift   u16
	offset  byte
	input_1 byte
	input_2 byte
	out_3   byte
	out_5   byte
	player  &audio.Player
}

fn (state IOState) op_in(port byte) ?byte {
	match port {
		1 { return state.input_1 }
		2 { return state.input_2 }
		3 { return byte((state.shift >> (8 - state.offset)) & 0xff) }
		else { return error('port unsupported for in by machine') }
	}
}

fn (mut state IOState) op_out(port, val byte) ? {
	match port {
		2 {
			state.offset = val & 0x7
		}
		3 {
			if val & 0x01 == 0x01 && state.out_3 & 0x01 != 0x01 {
				state.player.play(0, true)?
			}
			if val & 0x01 != 0x01 && state.out_3 & 0x01 == 0x01 {
				// Sound 0 repeats, so need to stop it when it turns off
				state.player.stop(0)?
			}
			if val & 0x02 == 0x02 && state.out_3 & 0x02 != 0x02 {
				state.player.play(1, false)?
			}
			if val & 0x04 == 0x04 && state.out_3 & 0x04 != 0x04 {
				state.player.play(2, false)?
			}
			if val & 0x08 == 0x08 && state.out_3 & 0x08 != 0x08 {
				state.player.play(3, false)?
			}
			state.out_3 = val
		}
		4 {
			a, _ := utils.break_address(state.shift)
			state.shift = utils.create_address(val, a)
		}
		5 {
			if val & 0x01 == 0x01 && state.out_5 & 0x01 != 0x01 {
				state.player.play(4, false)?
			}
			if val & 0x02 == 0x02 && state.out_5 & 0x02 != 0x02 {
				state.player.play(5, false)?
			}
			if val & 0x04 == 0x04 && state.out_5 & 0x04 != 0x04 {
				state.player.play(6, false)?
			}
			if val & 0x08 == 0x08 && state.out_5 & 0x08 != 0x08 {
				state.player.play(7, false)?
			}
			if val & 0x10 == 0x10 && state.out_5 & 0x10 != 0x10 {
				state.player.play(8, false)?
			}
			state.out_5 = val
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

fn (mut state IOState) input_down(i Input) {
	match i {
		.coin { state.input_1 |= 0x01 }
		.tilt { state.input_2 |= 0x04 }
		.player1_start { state.input_1 |= 0x04 }
		.player1_shoot { state.input_1 |= 0x10 }
		.player1_left { state.input_1 |= 0x20 }
		.player1_right { state.input_1 |= 0x40 }
		.player2_start { state.input_1 |= 0x02 }
		.player2_shoot { state.input_2 |= 0x10 }
		.player2_left { state.input_2 |= 0x20 }
		.player2_right { state.input_2 |= 0x40 }
	}
}

fn (mut state IOState) input_up(i Input) {
	match i {
		.coin { state.input_1 &= 0xfe }
		.tilt { state.input_2 &= 0xfb }
		.player1_start { state.input_1 &= 0xfb }
		.player1_shoot { state.input_1 &= 0xef }
		.player1_left { state.input_1 &= 0xdf }
		.player1_right { state.input_1 &= 0xbf }
		.player2_start { state.input_1 &= 0xfd }
		.player2_shoot { state.input_2 &= 0xef }
		.player2_left { state.input_2 &= 0xdf }
		.player2_right { state.input_2 &= 0xbf }
	}
}
