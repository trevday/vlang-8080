module cpu

import utils

struct InstructionAttributes {
	debug   fn (state &State) string
	execute fn (mut state State) ?ExecutionResult
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
				debug: fn (state &State) string {
					return 'NOP'
				}
				execute: fn (mut state State) ?ExecutionResult {
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x01 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'LXI    B,#$${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'STAX   B'
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
				debug: fn (state &State) string {
					return 'INX    B'
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
				debug: fn (state &State) string {
					return 'INR    B'
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
				debug: fn (state &State) string {
					return 'DCR    B'
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
				debug: fn (state &State) string {
					return 'MVI    B,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RLC'
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
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'DAD    B'
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
				debug: fn (state &State) string {
					return 'LDAX   B'
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
				debug: fn (state &State) string {
					return 'DCX    B'
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
				debug: fn (state &State) string {
					return 'INR    C'
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
				debug: fn (state &State) string {
					return 'DCR    C'
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
				debug: fn (state &State) string {
					return 'MVI    C,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RRC'
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
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'LXI    D,#$${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'STAX   D'
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
				debug: fn (state &State) string {
					return 'INX    D'
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
				debug: fn (state &State) string {
					return 'INR    D'
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
				debug: fn (state &State) string {
					return 'DCR    D'
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
				debug: fn (state &State) string {
					return 'MVI    D,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RAL'
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
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'DAD    D'
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
				debug: fn (state &State) string {
					return 'LDAX   D'
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
				debug: fn (state &State) string {
					return 'DCX    D'
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
				debug: fn (state &State) string {
					return 'INR    E'
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
				debug: fn (state &State) string {
					return 'DCR    E'
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
				debug: fn (state &State) string {
					return 'MVI    E,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RAR'
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
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'LXI    H,#$${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'SHLD   $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'INX    H'
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
				debug: fn (state &State) string {
					return 'INR    H'
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
				debug: fn (state &State) string {
					return 'DCR    H'
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
				debug: fn (state &State) string {
					return 'MVI    H,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'DAA'
				}
				execute: fn (mut state State) ?ExecutionResult {
					orig_a, orig_cy := state.a, state.flags.cy
					if (orig_a & 0xf) > 9 || state.flags.ac {
						res := u16(state.a) + u16(6)
						state.flags.cy = orig_cy || (res > 0xff)
						state.flags.ac = true
						state.a = byte(res & 0xff)
					} else {
						state.flags.ac = false
					}
					if orig_a > 0x99 || orig_cy {
						state.a = state.a + 0x60
						state.flags.cy = true
					} else {
						state.flags.cy = false
					}
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x28 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'DAD    H'
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
				debug: fn (state &State) string {
					return 'LHLD   $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'DCX    H'
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
				debug: fn (state &State) string {
					return 'INR    L'
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
				debug: fn (state &State) string {
					return 'DCR    L'
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
				debug: fn (state &State) string {
					return 'MVI    L,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CMA'
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
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'LXI    SP,#$${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'STA    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'INX    SP'
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
				debug: fn (state &State) string {
					return 'INR    M'
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
				debug: fn (state &State) string {
					return 'DCR    M'
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
				debug: fn (state &State) string {
					return 'MVI    M,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'STC'
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
				debug: fn (state &State) string {
					return 'NOP'
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
				debug: fn (state &State) string {
					return 'DAD    SP'
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
				debug: fn (state &State) string {
					return 'LDA    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'DCX    SP'
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
				debug: fn (state &State) string {
					return 'INR    A'
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
				debug: fn (state &State) string {
					return 'DCR    A'
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
				debug: fn (state &State) string {
					return 'MVI    A,#$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CMC'
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
				debug: fn (state &State) string {
					return 'MOV    B,B'
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
				debug: fn (state &State) string {
					return 'MOV    B,C'
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
				debug: fn (state &State) string {
					return 'MOV    B,D'
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
				debug: fn (state &State) string {
					return 'MOV    B,E'
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
				debug: fn (state &State) string {
					return 'MOV    B,H'
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
				debug: fn (state &State) string {
					return 'MOV    B,L'
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
				debug: fn (state &State) string {
					return 'MOV    B,M'
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
				debug: fn (state &State) string {
					return 'MOV    B,A'
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
				debug: fn (state &State) string {
					return 'MOV    C,B'
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
				debug: fn (state &State) string {
					return 'MOV    C,C'
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
				debug: fn (state &State) string {
					return 'MOV    C,D'
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
				debug: fn (state &State) string {
					return 'MOV    C,E'
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
				debug: fn (state &State) string {
					return 'MOV    C,H'
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
				debug: fn (state &State) string {
					return 'MOV    C,L'
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
				debug: fn (state &State) string {
					return 'MOV    C,M'
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
				debug: fn (state &State) string {
					return 'MOV    C,A'
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
				debug: fn (state &State) string {
					return 'MOV    D,B'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.d = state.a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 5
					}
				}
			} }
		0x51 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'MOV    D,C'
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
				debug: fn (state &State) string {
					return 'MOV    D,D'
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
				debug: fn (state &State) string {
					return 'MOV    D.E'
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
				debug: fn (state &State) string {
					return 'MOV    D,H'
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
				debug: fn (state &State) string {
					return 'MOV    D,L'
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
				debug: fn (state &State) string {
					return 'MOV    D,M'
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
				debug: fn (state &State) string {
					return 'MOV    D,A'
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
				debug: fn (state &State) string {
					return 'MOV    E,B'
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
				debug: fn (state &State) string {
					return 'MOV    E,C'
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
				debug: fn (state &State) string {
					return 'MOV    E,D'
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
				debug: fn (state &State) string {
					return 'MOV    E,E'
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
				debug: fn (state &State) string {
					return 'MOV    E,H'
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
				debug: fn (state &State) string {
					return 'MOV    E,L'
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
				debug: fn (state &State) string {
					return 'MOV    E,M'
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
				debug: fn (state &State) string {
					return 'MOV    E,A'
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
				debug: fn (state &State) string {
					return 'MOV    H,B'
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
				debug: fn (state &State) string {
					return 'MOV    H,C'
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
				debug: fn (state &State) string {
					return 'MOV    H,D'
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
				debug: fn (state &State) string {
					return 'MOV    H.E'
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
				debug: fn (state &State) string {
					return 'MOV    H,H'
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
				debug: fn (state &State) string {
					return 'MOV    H,L'
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
				debug: fn (state &State) string {
					return 'MOV    H,M'
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
				debug: fn (state &State) string {
					return 'MOV    H,A'
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
				debug: fn (state &State) string {
					return 'MOV    L,B'
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
				debug: fn (state &State) string {
					return 'MOV    L,C'
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
				debug: fn (state &State) string {
					return 'MOV    L,D'
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
				debug: fn (state &State) string {
					return 'MOV    L,E'
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
				debug: fn (state &State) string {
					return 'MOV    L,H'
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
				debug: fn (state &State) string {
					return 'MOV    L,L'
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
				debug: fn (state &State) string {
					return 'MOV    L,M'
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
				debug: fn (state &State) string {
					return 'MOV    L,A'
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
				debug: fn (state &State) string {
					return 'MOV    M,B'
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
				debug: fn (state &State) string {
					return 'MOV    M,C'
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
				debug: fn (state &State) string {
					return 'MOV    M,D'
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
				debug: fn (state &State) string {
					return 'MOV    M.E'
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
				debug: fn (state &State) string {
					return 'MOV    M,H'
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
				debug: fn (state &State) string {
					return 'MOV    M,L'
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
				debug: fn (state &State) string {
					return 'HLT'
				}
				execute: fn (mut state State) ?ExecutionResult {
					return error('unimplemented')
				}
			} }
		0x77 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'MOV    M,A'
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
				debug: fn (state &State) string {
					return 'MOV    A,B'
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
				debug: fn (state &State) string {
					return 'MOV    A,C'
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
				debug: fn (state &State) string {
					return 'MOV    A,D'
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
				debug: fn (state &State) string {
					return 'MOV    A,E'
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
				debug: fn (state &State) string {
					return 'MOV    A,H'
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
				debug: fn (state &State) string {
					return 'MOV    A,L'
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
				debug: fn (state &State) string {
					return 'MOV    A,M'
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
				debug: fn (state &State) string {
					return 'MOV    A,A'
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
				debug: fn (state &State) string {
					return 'ADD    B'
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
				debug: fn (state &State) string {
					return 'ADD    C'
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
				debug: fn (state &State) string {
					return 'ADD    D'
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
				debug: fn (state &State) string {
					return 'ADD    E'
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
				debug: fn (state &State) string {
					return 'ADD    H'
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
				debug: fn (state &State) string {
					return 'ADD    L'
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
				debug: fn (state &State) string {
					return 'ADD    M'
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
				debug: fn (state &State) string {
					return 'ADD    A'
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
				debug: fn (state &State) string {
					return 'ADC    B'
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
				debug: fn (state &State) string {
					return 'ADC    C'
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
				debug: fn (state &State) string {
					return 'ADC    D'
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
				debug: fn (state &State) string {
					return 'ADC    E'
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
				debug: fn (state &State) string {
					return 'ADC    H'
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
				debug: fn (state &State) string {
					return 'ADC    L'
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
				debug: fn (state &State) string {
					return 'ADC    M'
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
				debug: fn (state &State) string {
					return 'ADC    A'
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
				debug: fn (state &State) string {
					return 'SUB    B'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x91 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    C'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x92 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    D'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x93 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    E'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x94 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    H'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x95 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    L'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x96 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    M'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -(state.mem[utils.create_address(state.h,
						state.l)]))
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0x97 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SUB    A'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0x98 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'SBB    B'
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
				debug: fn (state &State) string {
					return 'SBB    C'
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
				debug: fn (state &State) string {
					return 'SBB    D'
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
				debug: fn (state &State) string {
					return 'SBB    E'
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
				debug: fn (state &State) string {
					return 'SBB    H'
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
				debug: fn (state &State) string {
					return 'SBB    L'
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
				debug: fn (state &State) string {
					return 'SBB    M'
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
				debug: fn (state &State) string {
					return 'SBB    A'
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
				debug: fn (state &State) string {
					return 'ANA    B'
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
				debug: fn (state &State) string {
					return 'ANA    C'
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
				debug: fn (state &State) string {
					return 'ANA    D'
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
				debug: fn (state &State) string {
					return 'ANA    E'
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
				debug: fn (state &State) string {
					return 'ANA    H'
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
				debug: fn (state &State) string {
					return 'ANA    L'
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
				debug: fn (state &State) string {
					return 'ANA    M'
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
				debug: fn (state &State) string {
					return 'ANA    A'
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
				debug: fn (state &State) string {
					return 'XRA    B'
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
				debug: fn (state &State) string {
					return 'XRA    C'
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
				debug: fn (state &State) string {
					return 'XRA    D'
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
				debug: fn (state &State) string {
					return 'XRA    E'
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
				debug: fn (state &State) string {
					return 'XRA    H'
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
				debug: fn (state &State) string {
					return 'XRA    L'
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
				debug: fn (state &State) string {
					return 'XRA    M'
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
				debug: fn (state &State) string {
					return 'XRA    A'
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
				debug: fn (state &State) string {
					return 'ORA    B'
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
				debug: fn (state &State) string {
					return 'ORA    C'
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
				debug: fn (state &State) string {
					return 'ORA    D'
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
				debug: fn (state &State) string {
					return 'ORA    E'
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
				debug: fn (state &State) string {
					return 'ORA    H'
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
				debug: fn (state &State) string {
					return 'ORA    L'
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
				debug: fn (state &State) string {
					return 'ORA    M'
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
				debug: fn (state &State) string {
					return 'ORA    A'
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
				debug: fn (state &State) string {
					return 'CMP    B'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.b)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xb9 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    C'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.c)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xba { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    D'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.d)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbb { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    E'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.e)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbc { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    H'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.h)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbd { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    L'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.l)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xbe { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    M'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -(state.mem[utils.create_address(state.h,
						state.l)]))
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 7
					}
				}
			} }
		0xbf { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CMP    A'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition(state.a, -state.a)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 4
					}
				}
			} }
		0xc0 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'RNZ'
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
				debug: fn (state &State) string {
					return 'POP    B'
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
				debug: fn (state &State) string {
					return 'JNZ    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'JMP    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CNZ    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'PUSH   B'
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
				debug: fn (state &State) string {
					return 'ADI    #$${state.mem[state.pc+1]:02x}'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, state.mem[state.pc + 1])
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xc7 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'RST    0'
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
				debug: fn (state &State) string {
					return 'RZ'
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
				debug: fn (state &State) string {
					return 'RET'
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
				debug: fn (state &State) string {
					return 'JZ     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'JMP    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CZ     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CALL   $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'ACI    #$${state.mem[state.pc+1]:02x}'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, u16(state.mem[state.pc + 1]) + u16(utils.bool_byte(state.flags.cy)))
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xcf { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'RST    1'
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
				debug: fn (state &State) string {
					return 'RNC'
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
				debug: fn (state &State) string {
					return 'POP    D'
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
				debug: fn (state &State) string {
					return 'JNC    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'OUT    #$${state.mem[state.pc+1]:02x}'
				}
				execute: op_out_execute
			} }
		0xd4 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CNC    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'PUSH   D'
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
				debug: fn (state &State) string {
					return 'SUI    #$${state.mem[state.pc+1]:02x}'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -(state.mem[state.pc + 1]))
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xd7 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'RST    2'
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
				debug: fn (state &State) string {
					return 'RC'
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
				debug: fn (state &State) string {
					return 'RET'
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
				debug: fn (state &State) string {
					return 'JC     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'IN     #$${state.mem[state.pc+1]:02x}'
				}
				execute: op_in_execute
			} }
		0xdc { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'CC     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CALL   $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'SBI    #$${state.mem[state.pc+1]:02x}'
				}
				execute: fn (mut state State) ?ExecutionResult {
					state.execute_addition_and_store(state.a, -(u16(state.mem[state.pc + 1])) -
						u16(utils.bool_byte(state.flags.cy)))
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xdf { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'RST    3'
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
				debug: fn (state &State) string {
					return 'RPO'
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
				debug: fn (state &State) string {
					return 'POP    H'
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
				debug: fn (state &State) string {
					return 'JPO    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'XTHL'
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
				debug: fn (state &State) string {
					return 'CPO    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'PUSH   H'
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
				debug: fn (state &State) string {
					return 'ANI    #$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RST    4'
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
				debug: fn (state &State) string {
					return 'RPE'
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
				debug: fn (state &State) string {
					return 'PCHL'
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
				debug: fn (state &State) string {
					return 'JPE    $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'XCHG'
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
				debug: fn (state &State) string {
					return 'CPE     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CALL   $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'XRI    #$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RST    5'
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
				debug: fn (state &State) string {
					return 'RP'
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
				debug: fn (state &State) string {
					return 'POP    PSW'
				}
				execute: fn (mut state State) ?ExecutionResult {
					psw, a := state.pop()
					state.flags.z = ((psw & 0x01) == 0x01)
					state.flags.s = ((psw & 0x02) == 0x02)
					state.flags.p = ((psw & 0x04) == 0x04)
					state.flags.cy = ((psw & 0x08) == 0x08)
					state.flags.ac = ((psw & 0x10) == 0x10)
					state.a = a
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 10
					}
				}
			} }
		0xf2 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'JP     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'DI'
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
				debug: fn (state &State) string {
					return 'CP     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'PUSH   PSW'
				}
				execute: fn (mut state State) ?ExecutionResult {
					psw := (utils.bool_byte(state.flags.z) |
						(utils.bool_byte(state.flags.s) << 1) |
						(utils.bool_byte(state.flags.p) << 2) |
						(utils.bool_byte(state.flags.cy) << 3) |
						(utils.bool_byte(state.flags.ac) << 4))
					state.push(state.a, psw)
					return ExecutionResult{
						bytes_used: 1
						cycles_used: 11
					}
				}
			} }
		0xf6 { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'ORI    #$${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'RST    6'
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
				debug: fn (state &State) string {
					return 'RM'
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
				debug: fn (state &State) string {
					return 'SPHL'
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
				debug: fn (state &State) string {
					return 'JM     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'EI'
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
				debug: fn (state &State) string {
					return 'CM     $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CALL   $${state.mem[state.pc+2]:02x}${state.mem[state.pc+1]:02x}'
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
				debug: fn (state &State) string {
					return 'CPI    #$${state.mem[state.pc+1]:02x}'
				}
				execute: fn (mut state State) ?ExecutionResult {
					// Throw away the result, we do not store it
					// TODO (vcomp): Interesting V compiler bug, when using the negation
					// operator with the result of the array access it applies the operators
					// in an incorrect ordering.
					_ = state.execute_addition(state.a, -(state.mem[state.pc + 1]))
					return ExecutionResult{
						bytes_used: 2
						cycles_used: 7
					}
				}
			} }
		0xff { return InstructionAttributes{
				debug: fn (state &State) string {
					return 'RST    7'
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
