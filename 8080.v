import flag
import log
import os
import audio
import cpu
import arcade
import test

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
	// All flag definitions
	log_level_str := fp.string('log', 0, 'fatal', 'Log level, options are: fatal, error, warn, info, debug')
	disassemble_path := fp.string('disassemble', 0, '', 'Boots in disassembly mode, which will output human readable instructions at the given filepath, from the given binary, instead of running it.')
	start_addr := fp.int('addr', 0, 0, 'Start address of the loaded 8080 program in memory; must be >= 0 and < 65535')
	hardware_type := fp.string('hardware', 0, '', 'Type of hardware to run with the 8080, leave empty for the default arcade hardware, use "test" for testing hardware')
	sound_files_dir_path := fp.string('sound-files-dir', 0, '', 'Sound file path directory when running arcade hardware, should contain nine .wav files named 0-8')
	// Finalize
	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	// Help
	if additional_args[0] == 'help' {
		println(fp.usage())
		return
	}
	// TODO (vcomp): I would prefer to use the match as an expression
	// and assign direct to a variable, but the V compiler
	// does not support an error and return, or even a panic,
	// in the else case when assigning to a value.
	//
	// Log level flag
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
	mut logger := log.Log{}
	logger.set_level(log_level_parsed)
	// Read in source program
	mut source_bytes := []byte{}
	for additional_arg in additional_args {
		arg_bytes := os.read_bytes(additional_arg) or {
			eprintln('File $additional_arg could not be read: $err')
			return
		}
		source_bytes << arg_bytes
	}
	// Disassembly flag
	if disassemble_path != '' {
		if os.exists(disassemble_path) {
			eprintln('please provide a file path that does not exist for disassembly output, $disassemble_path already exists')
			return
		}
		disassembled := cpu.disassemble(source_bytes) or {
			eprintln(err)
			return
		}
		os.write_file(disassemble_path, disassembled) or {
			eprintln(err)
			return
		}
		println('Successfully disassembled and output to $disassemble_path')
		return
	}
	// Start address for program flag
	if start_addr < 0 || start_addr > cpu.max_memory - 1 {
		eprintln('Invalid start address: $start_addr')
		println(fp.usage())
		return
	}
	// Hardware type flag
	if hardware_type == 'test' {
		// If test, just run test hardware and early out
		if source_bytes.len < 7 {
			eprintln('Test hardware requires a source program of at least 7 bytes')
			return
		}
		mut test_hardware := test.new_hardware(source_bytes, u16(start_addr)) or {
			eprintln(err)
			return
		}
		test_hardware.run(logger) or {
			eprintln(err)
		}
		return
	}
	// Sound files
	mut audio_player := audio.new_player()
	mut audio_enabled := false
	if sound_files_dir_path != '' {
		if os.exists(sound_files_dir_path) && os.is_dir(sound_files_dir_path) {
			audio_enabled = true
		} else {
			eprintln('Given sound files directory $sound_files_dir_path is not valid')
			return
		}
	}
	if audio_enabled {
		for i in 0 .. num_audio_files {
			audio_player.load('$sound_files_dir_path/${i}.wav') or {
				eprintln(err)
				return
			}
		}
	}
	mut hardware := arcade.new_hardware(source_bytes, u16(start_addr), audio_player, audio_enabled)
	hardware.run(logger) or {
		eprintln(err)
		return
	}
}
