import os
import log
import core

fn main() {
	args := os.args[1..]
	if args.len == 0 {
		println('Requires a filepath to emulate')
		return
	}
	source_bytes := os.read_bytes(args[0]) or {
		println('File could not be read: $err')
		return
	}
	mut state := core.new(source_bytes)
	mut logger := log.Log{}
	logger.set_level(log.Level.debug)
	for {
		state.emulate(logger) or {
			logger.error(err)
			break
		}
	}
}
