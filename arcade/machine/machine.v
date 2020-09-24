module machine

import cpu
import log
import time

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

// TODO (vcomp)
[inline]
fn to_micro(t time.Time) u64 {
	return (t.unix * u64(1000000)) + u64(t.microsecond)
}

const (
	// Refresh rate is 60 Hz, and interrupts happen twice
	// per refresh, so 1/120 = ~8333 microseconds
	interrupt_micro = u64(8333)
)

pub fn (mut m Machine) emulate(mut logger log.Log) ? {
	mut lag_cycles := i64(0)
	mut timestamp := to_micro(time.now())
	mut next_interrupt_time := timestamp + interrupt_micro
	mut next_interrupt_instruction := byte(1)
	for {
		if timestamp >= next_interrupt_time {
			next_interrupt_time += interrupt_micro
			m.cpu.interrupt(next_interrupt_instruction)
			next_interrupt_instruction ^= 3
		}
		for lag_cycles > 0 {
			// TODO (vcomp)
			temp := m.cpu.emulate(logger)?
			lag_cycles -= temp
		}
		now := to_micro(time.now())
		lag_cycles += i64(now - timestamp) * i64(2)
		timestamp = now
	}
}
