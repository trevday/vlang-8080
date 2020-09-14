import flag
import log
import os
import core

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('8080 Emulator')
	fp.version('v0.0.1')
	fp.description('Emulates program execution for a program designed to run on the Intel 8080 CPU.')
	fp.limit_free_args_to_exactly(1)
	fp.skip_executable()
	log_level_str := fp.string('log', 0, 'fatal', 'Log level, options are: fatal, error, warn, info, debug')
	// TODO: I would prefer to use the match as an expression
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
			eprintln('Invalid log level $log_level_str')
			println(fp.usage())
			return
		}
	}
	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}
	if additional_args[0] == 'help' {
		println(fp.usage())
		return
	}
	source_bytes := os.read_bytes(additional_args[0]) or {
		eprintln('File ${additional_args[0]} could not be read: $err')
		return
	}
	mut logger := log.Log{}
	logger.set_level(log_level_parsed)
	mut state := core.new(source_bytes)
	for {
		state.emulate(logger) or {
			logger.error(err)
			break
		}
	}
}
