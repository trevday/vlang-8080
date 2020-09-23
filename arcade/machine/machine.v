module machine

import cpu
import log

pub struct Machine {
mut:
	cpu cpu.State
	io  IOState
}

pub fn new(program &[]byte) Machine {
	mut io := IOState{}
	mut cpu := cpu.new(program, 0x0000, io)
	return Machine{
		cpu: cpu
		io: io
	}
}

pub fn (mut m Machine) emulate(mut logger log.Log) ? {
	for {
		m.cpu.emulate(logger)?
	}
}
