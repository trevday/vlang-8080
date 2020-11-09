module cpu

import utils

struct InstructionAttributes {
	debug   fn (source []byte, idx int) DebugResult
	execute fn (mut state State) ?ExecutionResult
}

struct DebugResult {
	instr_bytes  u16
	instr_string string
}

struct ExecutionResult {
	// Use u16 max as a sentinel for unset return values,
	// since 0 is a valid bytes_used
	bytes_used  u16 = utils.u16_max
	cycles_used u32
}

// TODO (vcomp): Compiler issues with using interface functions within
// an anonymous function, so put them here
fn op_in_execute(mut state State) ?ExecutionResult {
	state.a = state.machine.op_in(state.mem[state.pc + 1])?
	return ExecutionResult{
		bytes_used: 2
		cycles_used: 10
	}
}

fn op_out_execute(mut state State) ?ExecutionResult {
	state.machine.op_out(state.mem[state.pc + 1], state.a)?
	return ExecutionResult{
		bytes_used: 2
		cycles_used: 10
	}
}

fn get_attributes(instruction byte) ?InstructionAttributes {
	match instruction {
		0x00 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x01 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'LXI    B,#$${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.mem[state.pc + 2]
					state.c = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 10
					}
				}
			} }
		0x02 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'STAX   B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.b, state.c)] = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x03 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INX    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut bc := utils.create_address(state.b, state.c)
					bc++
					state.b, state.c = utils.break_address(bc)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x04 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.inr(state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x05 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.dcr(state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x06 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    B,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x07 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RLC'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					temp := state.a
					state.a = ((temp & 128) >> 7) | (temp << 1)
					// Set carryover if the bit that wraps around
					// is 1
					state.flags.cy = ((temp & 128) == 128)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x08 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x09 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DAD    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.dad(state.b, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0x0a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'LDAX   B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.mem[utils.create_address(state.b, state.c)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x0b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCX    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut bc := utils.create_address(state.b, state.c)
					bc--
					state.b, state.c = utils.break_address(bc)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x0c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.inr(state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x0d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.dcr(state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x0e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    C,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x0f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RRC'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					temp := state.a
					state.a = ((temp & 1) << 7) | (temp >> 1)
					// Set carryover if the bit that wraps around
					// is 1
					state.flags.cy = ((temp & 1) == 1)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x10 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x11 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'LXI    D,#$${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.mem[state.pc + 2]
					state.e = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 10
					}
				}
			} }
		0x12 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'STAX   D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.d, state.e)] = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x13 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INX    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut de := utils.create_address(state.d, state.e)
					de++
					state.d, state.e = utils.break_address(de)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x14 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.inr(state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x15 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.dcr(state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x16 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    D,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x17 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RAL'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					temp := state.a
					state.a = (utils.bool_byte(state.flags.cy) | (temp << 1))
					// We use the carryover flag as the wrapping bit here,
					// but still set carryover based on whether there would
					// have been a wrapping bit of 1
					state.flags.cy = ((temp & 128) == 128)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x18 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x19 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DAD    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.dad(state.d, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0x1a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'LDAX   D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.mem[utils.create_address(state.d, state.e)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x1b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCX    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut de := utils.create_address(state.d, state.e)
					de--
					state.d, state.e = utils.break_address(de)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x1c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.inr(state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x1d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.dcr(state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x1e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    E,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x1f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RAR'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					temp := state.a
					state.a = (utils.bool_byte(state.flags.cy) << 7) | (temp >> 1)
					// We use the carryover flag as the wrapping bit here,
					// but still set carryover based on whether there would
					// have been a wrapping bit of 1
					state.flags.cy = ((temp & 1) == 1)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x20 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x21 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'LXI    H,#$${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.mem[state.pc + 2]
					state.l = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 10
					}
				}
			} }
		0x22 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'SHLD   $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					addr := utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					state.mem[addr] = state.l
					state.mem[addr + 1] = state.h
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 16
					}
				}
			} }
		0x23 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INX    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut hl := utils.create_address(state.h, state.l)
					hl++
					state.h, state.l = utils.break_address(hl)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x24 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.inr(state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x25 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.dcr(state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x26 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    H,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x27 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DAA'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut orig_cy := state.flags.cy
					mut diff := byte(0x0)
					if (state.a & 0xf) > 0x9 || state.flags.ac {
						diff += 0x06
					}
					if state.a > 0x99 || orig_cy {
						diff += 0x60
						orig_cy = true
					}
					state.execute_addition_and_store(state.a, diff)
					state.flags.cy = orig_cy
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x28 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x29 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DAD    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.dad(state.h, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0x2a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'LHLD   $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					addr := utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					state.l = state.mem[addr]
					state.h = state.mem[addr + 1]
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 16
					}
				}
			} }
		0x2b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCX    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					mut hl := utils.create_address(state.h, state.l)
					hl--
					state.h, state.l = utils.break_address(hl)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x2c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.inr(state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x2d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.dcr(state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x2e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    L,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x2f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMA'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = ~state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x30 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x31 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'LXI    SP,#$${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sp = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 10
					}
				}
			} }
		0x32 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'STA    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					addr := utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					state.mem[addr] = state.a
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 13
					}
				}
			} }
		0x33 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INX    SP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sp++
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x34 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					hl := utils.create_address(state.h, state.l)
					state.mem[hl] = state.inr(state.mem[hl])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0x35 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					hl := utils.create_address(state.h, state.l)
					state.mem[hl] = state.dcr(state.mem[hl])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0x36 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    M,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					addr := utils.create_address(state.h, state.l)
					state.mem[addr] = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 10
					}
				}
			} }
		0x37 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'STC'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.flags.cy = true
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x38 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'NOP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// NOP
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x39 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DAD    SP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					sp1, sp2 := utils.break_address(state.sp)
					state.dad(sp1, sp2)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0x3a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'LDA    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					addr := utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					state.a = state.mem[addr]
					return ExecutionResult{
						bytes_used: 3
						cycles_used: 13
					}
				}
			} }
		0x3b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCX    SP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sp--
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x3c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'INR    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.inr(state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x3d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DCR    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.dcr(state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x3e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'MVI    A,#$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.mem[state.pc + 1]
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0x3f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMC'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.flags.cy = !state.flags.cy
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x40 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x41 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x42 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x43 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x44 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x45 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x46 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x47 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    B,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.b = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x48 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x49 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x4a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x4b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x4c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x4d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x4e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x4f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    C,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x50 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x51 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x52 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x53 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D.E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x54 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x55 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x56 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x57 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    D,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x58 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x59 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x5a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x5b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x5c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x5d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x5e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x5f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    E,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x60 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x61 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x62 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x63 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H.E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x64 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x65 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x66 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x67 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    H,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.h = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x68 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x69 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x6a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x6b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x6c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x6d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x6e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x6f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    L,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x70 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.h, state.l)] = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x71 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.h, state.l)] = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x72 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.h, state.l)] = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x73 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M.E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.h, state.l)] = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x74 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.h, state.l)] = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x75 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.mem[utils.create_address(state.h, state.l)] = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x76 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'HLT'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					return error('unimplemented')
				}
			} }
		0x77 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    M,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					addr := utils.create_address(state.h, state.l)
					state.mem[addr] = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x78 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.b
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x79 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.c
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x7a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.d
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x7b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.e
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x7c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.h
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x7d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x7e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.mem[utils.create_address(state.h, state.l)]
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x7f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'MOV    A,A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.a = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x80 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x81 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x82 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x83 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x84 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x85 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x86 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					offset := utils.create_address(state.h, state.l)
					state.execute_addition_and_store(state.a, state.mem[offset])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x87 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADD    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x88 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x89 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x8a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x8b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x8c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x8d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x8e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.mem[utils.create_address(state.h, state.l)])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x8f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ADC    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x90 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x91 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x92 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x93 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x94 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x95 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x96 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.mem[utils.create_address(state.h,
						state.l)])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x97 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SUB    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x98 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x99 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x9a { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x9b { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x9c { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x9d { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x9e { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.mem[utils.create_address(state.h, state.l)])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x9f { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SBB    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa0 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa1 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa2 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa3 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa4 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa5 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa6 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.mem[utils.create_address(state.h, state.l)])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0xa7 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ANA    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa8 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xa9 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xaa { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xab { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xac { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xad { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xae { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.mem[utils.create_address(state.h, state.l)])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0xaf { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XRA    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb0 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb1 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb2 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb3 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb4 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb5 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb6 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.mem[utils.create_address(state.h, state.l)])
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0xb7 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'ORA    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb8 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.b, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb9 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    C'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.c, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xba { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.d, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbb { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    E'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.e, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbc { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.h, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbd { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    L'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.l, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbe { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    M'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~(state.mem[utils.create_address(state.h,
						state.l)]), true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0xbf { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'CMP    A'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~state.a, true)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xc0 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RNZ'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					// If Not Zero, execute a RET
					if !state.flags.z {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xc1 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'POP    B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.c, state.b = state.pop()
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0xc2 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JNZ    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.z {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xc3 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JMP    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 10
					}
				}
			} }
		0xc4 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CNZ    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.z {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						// Skip following address if we did not jump
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xc5 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'PUSH   B'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.push(state.b, state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 11
					}
				}
			} }
		0xc6 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'ADI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xc7 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    0'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xc8 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RZ'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.z {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xc9 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RET'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ret()
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 10
					}
				}
			} }
		0xca { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JZ     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.z {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xcb { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JMP    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 10
					}
				}
			} }
		0xcc { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CZ     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.z {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xcd { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CALL   $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
						state.mem[state.pc + 1]))
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 17
					}
				}
			} }
		0xce { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'ACI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.adc(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xcf { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    1'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0008)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xd0 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RNC'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.cy {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xd1 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'POP    D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.e, state.d = state.pop()
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0xd2 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JNC    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.cy {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xd3 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'OUT    #$${source[idx+1]:02x}'
					}
				}
				execute: op_out_execute
			} }
		0xd4 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CNC    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.cy {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						// Skip following address if we did not jump
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xd5 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'PUSH   D'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.push(state.d, state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 11
					}
				}
			} }
		0xd6 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'SUI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_subtraction_and_store(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xd7 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    2'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0010)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xd8 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RC'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.cy {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xd9 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RET'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ret()
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 10
					}
				}
			} }
		0xda { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JC     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.cy {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xdb { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'IN     #$${source[idx+1]:02x}'
					}
				}
				execute: op_in_execute
			} }
		0xdc { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CC     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.cy {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xdd { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CALL   $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
						state.mem[state.pc + 1]))
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 17
					}
				}
			} }
		0xde { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'SBI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sbb(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xdf { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    3'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0018)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xe0 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RPO'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.p {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xe1 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'POP    H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.l, state.h = state.pop()
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0xe2 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JPO    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.p {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xe3 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XTHL'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					h, l := state.h, state.l
					state.h, state.l = state.mem[state.sp + 1], state.mem[state.sp]
					state.mem[state.sp + 1], state.mem[state.sp] = h, l
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 18
					}
				}
			} }
		0xe4 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CPO    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.p {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						// Skip following address if we did not jump
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xe5 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'PUSH   H'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.push(state.h, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 11
					}
				}
			} }
		0xe6 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'ANI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.and(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xe7 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    4'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0020)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xe8 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RPE'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.p {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xe9 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'PCHL'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.pc = utils.create_address(state.h, state.l)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 5
					}
				}
			} }
		0xea { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JPE    $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.p {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xeb { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'XCHG'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					temp1, temp2 := state.h, state.l
					state.h, state.l = state.d, state.e
					state.d, state.e = temp1, temp2
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0xec { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CPE     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.p {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xed { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CALL   $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
						state.mem[state.pc + 1]))
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 17
					}
				}
			} }
		0xee { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'XRI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.xra(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xef { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    5'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0028)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xf0 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RP'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.s {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xf1 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'POP    PSW'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					psw, a := state.pop()
					state.flags.cy = ((psw & 0x01) == 0x01)
					state.flags.p = ((psw & 0x04) == 0x04)
					state.flags.ac = ((psw & 0x10) == 0x10)
					state.flags.z = ((psw & 0x40) == 0x40)
					state.flags.s = ((psw & 0x80) == 0x80)
					state.a = a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0xf2 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JP     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.s {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xf3 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'DI'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.interrupt_enabled = false
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xf4 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CP     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if !state.flags.s {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						// Skip following address if we did not jump
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xf5 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'PUSH   PSW'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					psw := (utils.bool_byte(state.flags.cy) |
						(1 << 1) | (utils.bool_byte(state.flags.p) << 2) |
						(utils.bool_byte(state.flags.ac) << 4) |
						(utils.bool_byte(state.flags.z) << 6) |
						(utils.bool_byte(state.flags.s) << 7))
					state.push(state.a, psw)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 11
					}
				}
			} }
		0xf6 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'ORI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.ora(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xf7 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    6'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0030)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		0xf8 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RM'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.s {
						state.ret()
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 11
						}
					} else {
						return ExecutionResult{
							bytes_used: 1
							cycles_used: 5
						}
					}
				}
			} }
		0xf9 { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'SPHL'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.sp = utils.create_address(state.h, state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0xfa { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'JM     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.s {
						state.pc = utils.create_address(state.mem[state.pc + 2], state.mem[state.pc +
							1])
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 10
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 10
						}
					}
				}
			} }
		0xfb { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'EI'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.interrupt_enabled = true
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xfc { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CM     $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					if state.flags.s {
						state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
							state.mem[state.pc + 1]))
						return ExecutionResult{
							bytes_used: 0
							cycles_used: 17
						}
					} else {
						return ExecutionResult{
							bytes_used: 3
							cycles_used: 11
						}
					}
				}
			} }
		0xfd { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 3
						instr_string: 'CALL   $${source[idx+2]:02x}${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 3, utils.create_address(state.mem[state.pc + 2],
						state.mem[state.pc + 1]))
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 17
					}
				}
			} }
		0xfe { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 2
						instr_string: 'CPI    #$${source[idx+1]:02x}'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, ~(state.mem[state.pc + 1]), true)
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xff { return InstructionAttributes{
				debug: fn (source []byte, idx int) DebugResult {
					return DebugResult{
						instr_bytes: 1
						instr_string: 'RST    7'
					}
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.call(state.pc + 1, 0x0038)
					return ExecutionResult{
						bytes_used: 0
						cycles_used: 11
					}
				}
			} }
		else { return error('unknown opcode: $instruction') }
	}
}
