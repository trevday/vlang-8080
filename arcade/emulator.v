import flag
import log
import os
import audio
import machine

const (
	num_audio_files = 9
)

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('8080 Emulator')
	fp.version('v0.0.1')
	fp.description('Emulates program execution for a program designed to run on the Intel 8080 CPU.')
	fp.limit_free_args_to_at_least(1)
	fp.skip_executable()
	log_level_str := fp.string('log', 0, 'fatal', 'Log level, options are: fatal, error, warn, info, debug')
	// TODO (vcomp): I would prefer to use the match as an expression
	// and assign direct to a variable, but the V compiler
	// does not support an error and return, or even a panic,
	// in the else case when assigning to a value.
	mut log_level_parsed := log.Level.fatal
	match log_level_str {
		'fatal' {
			log_level_parsed = log.Level.fatal
		}
		'error' {
			log_level_parsed = log.Level.error
		}
		'warn' {
			log_level_parsed = log.Level.warn
		}
		'info' {
			log_level_parsed = log.Level.info
		}
		'debug' {
			log_level_parsed = log.Level.debug
		}
		else {
			eprintln('Invalid log level: $log_level_str')
			println(fp.usage())
			return
		}
	}
	// TODO: Keep?
	// start_addr := fp.int('addr', 0, 0, 'Start address of the loaded 8080 program in memory; must be >= 0 and < 65535')
	// if start_addr < 0 || start_addr > cpu.max_memory - 1 {
	// eprintln('Invalid start address: $start_addr')
	// println(fp.usage())
	// return
	// }
	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	if additional_args[0] == 'help' {
		println(fp.usage())
		return
	}
	mut source_bytes := []byte{}
	for additional_arg in additional_args {
		arg_bytes := os.read_bytes(additional_arg) or {
			eprintln('File $additional_arg could not be read: $err')
			return
		}
		source_bytes << arg_bytes
	}
	mut logger := log.Log{}
	logger.set_level(log_level_parsed)
	audio_source_dir := os.dir(additional_args[0])
	mut audio_player := audio.new_player()
	for i in 0 .. num_audio_files {
		audio_player.load('$audio_source_dir/${i}.wav') or {
			logger.error(err)
			return
		}
	}
	mut machine := machine.new(source_bytes, audio_player)
	machine.emulate(logger) or {
		logger.error(err)
		return
	}
}
