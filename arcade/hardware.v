module arcade

import audio
import cpu
import log
import sync
import time
import utils

pub struct Hardware {
mut:
	cpu  &cpu.State
	io   &IO
	view View
	mtx  &sync.Mutex
}

pub fn new_hardware(program &[]byte, start_addr u16, audio_player &audio.Player, audio_enabled bool) Hardware {
	mut io := &IO{
		audio_player: audio_player
		audio_enabled: audio_enabled
	}
	mut hardware := Hardware{
		cpu: cpu.new(program, start_addr, io)
		io: io
		mtx: &sync.Mutex{}
	}
	hardware.view = new_view(mut hardware)
	return hardware
}

const (
	// Refresh rate is 60 Hz, and interrupts happen twice
	// per refresh, so 1/120 = ~8333 microseconds
	interrupt_micro        = u64(8333)
	// 2 MHz, so 2 instructions per microsecond
	instructions_per_micro = i64(2)
)

pub fn (mut hardware Hardware) run(mut logger log.Log) ? {
	go hardware.run_cpu(logger)
	hardware.view.context.run()
}

fn (mut hardware Hardware) run_cpu(mut logger log.Log) {
	mut lag_cycles := i64(0)
	mut timestamp := utils.to_micro(time.now())
	mut next_interrupt_time := timestamp + interrupt_micro
	mut next_interrupt_instruction := byte(1)
	for {
		hardware.mtx.m_lock()
		if timestamp >= next_interrupt_time {
			next_interrupt_time += interrupt_micro
			hardware.cpu.interrupt(next_interrupt_instruction)
			next_interrupt_instruction ^= 3
		}
		for lag_cycles > 0 {
			// TODO (vcomp): I would prefer not to have to panic
			// here but I had a lot of difficulty getting errors to
			// pass between threads via channels, they are not quite
			// robust enough yet to support that.
			temp := hardware.cpu.step(logger) or {
				panic(err)
			}
			lag_cycles -= temp
		}
		hardware.mtx.unlock()
		now := utils.to_micro(time.now())
		lag_cycles += i64(now - timestamp) * instructions_per_micro
		timestamp = now
	}
}
