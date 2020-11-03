module machine

import audio
import cpu
import log
import sync
import time
import utils

pub struct Machine {
mut:
	cpu  cpu.State
	io   &IOState
	view View
	mtx  &sync.Mutex
}

pub fn new(program &[]byte, player &audio.Player) Machine {
	mut io := &IOState{
		player: player
	}
	mut cpu := cpu.new(program, 0x0000, io)
	mut m := Machine{
		cpu: cpu
		io: io
		mtx: &sync.Mutex{}
	}
	m.view = new_view(mut m)
	return m
}

const (
	// Refresh rate is 60 Hz, and interrupts happen twice
	// per refresh, so 1/120 = ~8333 microseconds
	interrupt_micro        = u64(8333)
	// 2 MHz, so 2 instructions per microsecond
	instructions_per_micro = i64(2)
)

pub fn (mut m Machine) emulate(mut logger log.Log) ? {
	go m.run(logger)
	m.view.context.run()
}

pub fn (mut m Machine) run(mut logger log.Log) {
	mut lag_cycles := i64(0)
	mut timestamp := utils.to_micro(time.now())
	mut next_interrupt_time := timestamp + interrupt_micro
	mut next_interrupt_instruction := byte(1)
	for {
		m.mtx.m_lock()
		if timestamp >= next_interrupt_time {
			next_interrupt_time += interrupt_micro
			m.cpu.interrupt(next_interrupt_instruction)
			next_interrupt_instruction ^= 3
		}
		for lag_cycles > 0 {
			// TODO (vcomp): I would prefer not to have to panic
			// here but I had a lot of difficulty getting errors to
			// pass between threads via channels, they are not quite
			// robust enough yet to support that.
			temp := m.cpu.emulate(logger) or {
				panic(err)
			}
			lag_cycles -= temp
		}
		m.mtx.unlock()
		now := utils.to_micro(time.now())
		lag_cycles += i64(now - timestamp) * instructions_per_micro
		timestamp = now
	}
}
