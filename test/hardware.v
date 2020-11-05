module test

import log
import cpu
import utils

pub struct Hardware {
mut:
	cpu  &cpu.State
	done bool
}

pub fn new_hardware(program &[]byte, start_addr u16) ?&Hardware {
	mut h := &Hardware{
		done: false
	}
	// Write in our specialized instructions for what to do during a test
	h.cpu = cpu.new(program, start_addr, h)
	h.cpu.edit_mem(0x0000, 0xd3)?
	h.cpu.edit_mem(0x0001, 0x00)?
	h.cpu.edit_mem(0x0005, 0xd3)?
	h.cpu.edit_mem(0x0006, 0x01)?
	h.cpu.edit_mem(0x0007, 0xc9)?
	return h
}

pub fn (mut h Hardware) run(mut logger log.Log) ? {
	for !h.done {
		h.cpu.step(logger)?
	}
	println('Test run has completed')
}

fn (mut h Hardware) op_in(port byte) ?byte {
	return 0
}

fn (mut h Hardware) op_out(port, val byte) ? {
	match port {
		0 {
			h.done = true
		}
		1 {
			if h.cpu.c == 2 {
				print('${h.cpu.e:c}')
			} else if h.cpu.c == 9 {
				mut output := ''
				mut addr := utils.create_address(h.cpu.d, h.cpu.e)
				for h.cpu.mem[addr] != `$` {
					output += '${h.cpu.mem[addr]:c}'
					addr++
				}
				println(output)
			}
		}
		else {}
	}
}
