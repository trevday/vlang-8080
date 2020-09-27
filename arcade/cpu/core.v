module cpu

import log
import utils

pub const (
	max_memory = 0xffff
)

struct Flags {
mut:
	// Is Zero
	z  bool
	// Sign
	s  bool
	// Parity
	p  bool
	// Carryover
	cy bool
	// Auxiliary Carry
	ac bool
}

pub interface Machine {
	op_in(port byte) ?byte
	op_out(port byte) ?
}

pub struct State {
mut:
	// Registers
	a                 byte
	b                 byte
	c                 byte
	d                 byte
	e                 byte
	h                 byte
	l                 byte
	// Stack Pointer
	sp                u16
	// Program Counter
	pc                u16
	// Working Memory
	mem               []byte
	// Flags for Conditions
	flags             Flags
	interrupt_enabled bool
	// Machine
	machine           &Machine
}

pub fn new(program &[]byte, start_addr u16, machine &Machine) State {
	mut state := State{
		machine: machine
		mem: []byte{len: max_memory, init: 0}
	}
	// Copy program to start_addr
	for i, b in program {
		state.mem[i + start_addr] = b
	}
	state.pc = start_addr
	return state
}

pub fn (mut state State) interrupt(rst byte) ? {
	if state.interrupt_enabled {
		if rst > 7 {
			return error('invalid interrupt rst')
		}
		state.interrupt_enabled = false
		state.call(state.pc, rst * 8)
	}
	return none
}

pub fn (state &State) get_mem() &[]byte {
	return &state.mem
}

fn (state &State) str() string {
	return 'Registers:\n' +
		'a: ${state.a:02x}, b: ${state.b:02x}, c: ${state.c:02x}, d: ${state.d:02x}, ' +
		'e: ${state.e:02x}, h: ${state.h:02x}, l: ${state.l:02x}' +
		'\nStack Pointer: ${state.sp:04x}\nProgram Counter: ${state.pc:04x}' +
		'\nFlags:\nz: $state.flags.z, s: $state.flags.s, p: $state.flags.p, cy: $state.flags.cy, ac: $state.flags.ac'
}

enum Instructions {
	nop_0 = 0x00 // TODO: fill in and make the disassembler use
}

// NOTE: cy is not set here because different instructions
// affect the carryover in different ways, but nearly all
// affect the other flags in the same way.
fn (mut state State) set_flags(x byte) {
	state.flags.z = (x == 0)
	// Set Sign (s) flag if MSB is set
	state.flags.s = ((x & 0x80) != 0)
	state.flags.p = utils.parity(x)
}

fn (mut state State) execute_addition(x1, x2 u16) byte {
	answer := x1 + x2
	// Only use the bottom 8 bits of the answer, carryover
	// is handled by flags (cy)
	truncated := byte(answer & 0xff)
	state.set_flags(truncated)
	state.flags.cy = (answer > 0xff)
	state.flags.ac = ((x1 & 0xf) + (x2 & 0xf) > 0xf)
	return truncated
}

fn (mut state State) execute_addition_and_store(x1, x2 u16) {
	state.a = state.execute_addition(x1, x2)
}

fn (mut state State) inr(x1 byte) byte {
	res := x1 + 1
	state.set_flags(res)
	state.flags.ac = ((x1 & 0xf) + 0x1 > 0xf)
	return res
}

fn (mut state State) dcr(x1 byte) byte {
	res := x1 - 1
	state.set_flags(res)
	state.flags.ac = ((x1 & 0xf) + 0x1 > 0xf)
	return res
}

fn (mut state State) adc(x1, x2 byte) {
	new_x2 := u16(x2) + u16(utils.bool_byte(state.flags.cy))
	// TODO: Identify if there is an error when calculating auxiliary carry
	// for ADC. What should it be measuring, the result of adding all 3 or
	// the result of adding the original 2?
	state.execute_addition_and_store(u16(x1), new_x2)
}

fn (mut state State) sbb(x1, x2 byte) {
	new_x2 := u16(-x2) - u16(utils.bool_byte(state.flags.cy))
	// TODO: Same as ADC, determine if there is an issue with AC flag.
	state.execute_addition_and_store(u16(x1), new_x2)
}

fn (mut state State) set_logic_flags(x byte) {
	state.set_flags(x)
	state.flags.cy = false
	state.flags.ac = false
}

fn (mut state State) and(x1, x2 byte) {
	state.a = x1 & x2
	state.set_logic_flags(state.a)
}

fn (mut state State) xra(x1, x2 byte) {
	state.a = x1 ^ x2
	state.set_logic_flags(state.a)
}

fn (mut state State) ora(x1, x2 byte) {
	state.a = x1 | x2
	state.set_logic_flags(state.a)
}

// Pushes x1 and then x2 on to the stack
fn (mut state State) push(x1, x2 byte) {
	state.sp -= 2
	state.mem[state.sp + 1] = x1
	state.mem[state.sp] = x2
}

// Pops x2 and then x1 off the stack
fn (mut state State) pop() (byte, byte) {
	state.sp += 2
	return state.mem[state.sp - 2], state.mem[state.sp - 1]
}

fn (mut state State) call(ret_addr, jmp_addr u16) {
	left, right := utils.break_address(ret_addr)
	state.push(left, right)
	// Jump after storing return address on stack
	state.pc = jmp_addr
}

fn (mut state State) ret() {
	right, left := state.pop()
	state.pc = utils.create_address(left, right)
}

fn (mut state State) dad(a, b byte) {
	hl := u32(utils.create_address(state.h, state.l))
	ab := u32(utils.create_address(a, b))
	answer := hl + ab
	state.flags.cy = (answer > 0xffff)
	h, l := utils.break_address(u16(answer & 0xffff))
	state.h = h
	state.l = l
}

// TODO: Better separation of logging for debug and functionality;
// Split out debug logging into the disassembly function? Be able to
// run disassembler as an independent program, without emulation.
// Clean up this giant if statement.
pub fn (mut state State) emulate(mut logger log.Log) ?u32 {
	// Cache the pc before incrementing it
	mut cycles_used := u32(0)
	pc := state.pc
	state.pc++
	logger.debug('Executing ${state.mem[pc]:02x}')
	match state.mem[pc] {
		0x00 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x01 {
			logger.debug('LXI    B,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.b = state.mem[pc + 2]
			state.c = state.mem[pc + 1]
			state.pc += 2
			cycles_used = 10
		}
		0x02 {
			logger.debug('STAX   B')
			state.mem[utils.create_address(state.b, state.c)] = state.a
			cycles_used = 7
		}
		0x03 {
			logger.debug('INX    B')
			mut bc := utils.create_address(state.b, state.c)
			bc++
			state.b, state.c = utils.break_address(bc)
			cycles_used = 5
		}
		0x04 {
			logger.debug('INR    B')
			state.b = state.inr(state.b)
			cycles_used = 5
		}
		0x05 {
			logger.debug('DCR    B')
			state.b = state.dcr(state.b)
			cycles_used = 5
		}
		0x06 {
			logger.debug('MVI    B,#$${state.mem[pc+1]:02x}')
			state.b = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x07 {
			logger.debug('RLC')
			temp := state.a
			state.a = ((temp & 128) >> 7) | (temp << 1)
			// Set carryover if the bit that wraps around
			// is 1
			state.flags.cy = ((temp & 128) == 128)
			cycles_used = 4
		}
		0x08 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x09 {
			logger.debug('DAD    B')
			state.dad(state.b, state.c)
			cycles_used = 10
		}
		0x0a {
			logger.debug('LDAX   B')
			state.a = state.mem[utils.create_address(state.b, state.c)]
			cycles_used = 7
		}
		0x0b {
			logger.debug('DCX    B')
			mut bc := utils.create_address(state.b, state.c)
			bc--
			state.b, state.c = utils.break_address(bc)
			cycles_used = 5
		}
		0x0c {
			logger.debug('INR    C')
			state.c = state.inr(state.c)
			cycles_used = 5
		}
		0x0d {
			logger.debug('DCR    C')
			state.c = state.dcr(state.c)
			cycles_used = 5
		}
		0x0e {
			logger.debug('MVI    C,#$${state.mem[pc+1]:02x}')
			state.c = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x0f {
			logger.debug('RRC')
			temp := state.a
			state.a = ((temp & 1) << 7) | (temp >> 1)
			// Set carryover if the bit that wraps around
			// is 1
			state.flags.cy = ((temp & 1) == 1)
			cycles_used = 4
		}
		0x10 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x11 {
			logger.debug('LXI    D,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.d = state.mem[pc + 2]
			state.e = state.mem[pc + 1]
			state.pc += 2
			cycles_used = 10
		}
		0x12 {
			logger.debug('STAX   D')
			state.mem[utils.create_address(state.d, state.e)] = state.a
			cycles_used = 7
		}
		0x13 {
			logger.debug('INX    D')
			mut de := utils.create_address(state.d, state.e)
			de++
			state.d, state.e = utils.break_address(de)
			cycles_used = 5
		}
		0x14 {
			logger.debug('INR    D')
			state.d = state.inr(state.d)
			cycles_used = 5
		}
		0x15 {
			logger.debug('DCR    D')
			state.d = state.dcr(state.d)
			cycles_used = 5
		}
		0x16 {
			logger.debug('MVI    D,#$${state.mem[pc+1]:02x}')
			state.d = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x17 {
			logger.debug('RAL')
			temp := state.a
			state.a = (utils.bool_byte(state.flags.cy) | (temp << 1))
			// We use the carryover flag as the wrapping bit here,
			// but still set carryover based on whether there would
			// have been a wrapping bit of 1
			state.flags.cy = ((temp & 128) == 128)
			cycles_used = 4
		}
		0x18 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x19 {
			logger.debug('DAD    D')
			state.dad(state.d, state.e)
			cycles_used = 10
		}
		0x1a {
			logger.debug('LDAX   D')
			state.a = state.mem[utils.create_address(state.d, state.e)]
			cycles_used = 7
		}
		0x1b {
			logger.debug('DCX    D')
			mut de := utils.create_address(state.d, state.e)
			de--
			state.d, state.e = utils.break_address(de)
			cycles_used = 5
		}
		0x1c {
			logger.debug('INR    E')
			state.e = state.inr(state.e)
			cycles_used = 5
		}
		0x1d {
			logger.debug('DCR    E')
			state.e = state.dcr(state.e)
			cycles_used = 5
		}
		0x1e {
			logger.debug('MVI    E,#$${state.mem[pc+1]:02x}')
			state.e = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x1f {
			logger.debug('RAR')
			temp := state.a
			state.a = (utils.bool_byte(state.flags.cy) << 7) | (temp >> 1)
			// We use the carryover flag as the wrapping bit here,
			// but still set carryover based on whether there would
			// have been a wrapping bit of 1
			state.flags.cy = ((temp & 1) == 1)
			cycles_used = 4
		}
		0x20 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x21 {
			logger.debug('LXI    H,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.h = state.mem[pc + 2]
			state.l = state.mem[pc + 1]
			state.pc += 2
			cycles_used = 10
		}
		0x22 {
			logger.debug('SHLD   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.mem[addr] = state.l
			state.mem[addr + 1] = state.h
			state.pc += 2
		}
		0x23 {
			logger.debug('INX    H')
			mut hl := utils.create_address(state.h, state.l)
			hl++
			state.h, state.l = utils.break_address(hl)
			cycles_used = 5
		}
		0x24 {
			logger.debug('INR    H')
			state.h = state.inr(state.h)
			cycles_used = 5
		}
		0x25 {
			logger.debug('DCR    H')
			state.h = state.dcr(state.h)
			cycles_used = 5
		}
		0x26 {
			logger.debug('MVI    H,#$${state.mem[pc+1]:02x}')
			state.h = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x27 {
			logger.debug('DAA')
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
			cycles_used = 4
		}
		0x28 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x29 {
			logger.debug('DAD    H')
			state.dad(state.h, state.l)
			cycles_used = 10
		}
		0x2a {
			logger.debug('LHLD   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.l = state.mem[addr]
			state.h = state.mem[addr + 1]
			state.pc += 2
		}
		0x2b {
			logger.debug('DCX    H')
			mut hl := utils.create_address(state.h, state.l)
			hl--
			state.h, state.l = utils.break_address(hl)
			cycles_used = 5
		}
		0x2c {
			logger.debug('INR    L')
			state.l = state.inr(state.l)
			cycles_used = 5
		}
		0x2d {
			logger.debug('DCR    L')
			state.l = state.dcr(state.l)
			cycles_used = 5
		}
		0x2e {
			logger.debug('MVI    L,#$${state.mem[pc+1]:02x}')
			state.l = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x2f {
			logger.debug('CMA')
			state.a = ~state.a
			cycles_used = 4
		}
		0x30 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x31 {
			logger.debug('LXI    SP,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.sp = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.pc += 2
			cycles_used = 10
		}
		0x32 {
			logger.debug('STA    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.mem[addr] = state.a
			state.pc += 2
			cycles_used = 13
		}
		0x33 {
			logger.debug('INX    SP')
			state.sp++
			cycles_used = 5
		}
		0x34 {
			logger.debug('INR    M')
			hl := utils.create_address(state.h, state.l)
			state.mem[hl] = state.inr(state.mem[hl])
			cycles_used = 10
		}
		0x35 {
			logger.debug('DCR    M')
			hl := utils.create_address(state.h, state.l)
			state.mem[hl] = state.dcr(state.mem[hl])
			cycles_used = 10
		}
		0x36 {
			logger.debug('MVI    M,#$${state.mem[pc+1]:02x}')
			addr := utils.create_address(state.h, state.l)
			state.mem[addr] = state.mem[pc + 1]
			state.pc++
			cycles_used = 10
		}
		0x37 {
			logger.debug('STC')
			state.flags.cy = true
			cycles_used = 4
		}
		0x38 {
			logger.debug('NOP')
			// NOP
			cycles_used = 4
		}
		0x39 {
			logger.debug('DAD    SP')
			sp1, sp2 := utils.break_address(state.sp)
			state.dad(sp1, sp2)
			cycles_used = 10
		}
		0x3a {
			logger.debug('LDA    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.a = state.mem[addr]
			state.pc += 2
			cycles_used = 13
		}
		0x3b {
			logger.debug('DCX    SP')
			state.sp--
			cycles_used = 5
		}
		0x3c {
			logger.debug('INR    A')
			state.a = state.inr(state.a)
			cycles_used = 5
		}
		0x3d {
			logger.debug('DCR    A')
			state.a = state.dcr(state.a)
			cycles_used = 5
		}
		0x3e {
			logger.debug('MVI    A,#$${state.mem[pc+1]:02x}')
			state.a = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x3f {
			logger.debug('CMC')
			state.flags.cy = !state.flags.cy
			cycles_used = 4
		}
		0x40 {
			logger.debug('MOV    B,B')
			state.b = state.b
			cycles_used = 5
		}
		0x41 {
			logger.debug('MOV    B,C')
			state.b = state.c
			cycles_used = 5
		}
		0x42 {
			logger.debug('MOV    B,D')
			state.b = state.d
			cycles_used = 5
		}
		0x43 {
			logger.debug('MOV    B,E')
			state.b = state.e
			cycles_used = 5
		}
		0x44 {
			logger.debug('MOV    B,H')
			state.b = state.h
			cycles_used = 5
		}
		0x45 {
			logger.debug('MOV    B,L')
			state.b = state.l
			cycles_used = 5
		}
		0x46 {
			logger.debug('MOV    B,M')
			state.b = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x47 {
			logger.debug('MOV    B,A')
			state.b = state.a
			cycles_used = 5
		}
		0x48 {
			logger.debug('MOV    C,B')
			state.c = state.b
			cycles_used = 5
		}
		0x49 {
			logger.debug('MOV    C,C')
			state.c = state.c
			cycles_used = 5
		}
		0x4a {
			logger.debug('MOV    C,D')
			state.c = state.d
			cycles_used = 5
		}
		0x4b {
			logger.debug('MOV    C,E')
			state.c = state.e
			cycles_used = 5
		}
		0x4c {
			logger.debug('MOV    C,H')
			state.c = state.h
			cycles_used = 5
		}
		0x4d {
			logger.debug('MOV    C,L')
			state.c = state.l
			cycles_used = 5
		}
		0x4e {
			logger.debug('MOV    C,M')
			state.c = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x4f {
			logger.debug('MOV    C,A')
			state.c = state.a
			cycles_used = 5
		}
		0x50 {
			logger.debug('MOV    D,B')
			state.d = state.a
			cycles_used = 5
		}
		0x51 {
			logger.debug('MOV    D,C')
			state.d = state.c
			cycles_used = 5
		}
		0x52 {
			logger.debug('MOV    D,D')
			state.d = state.d
			cycles_used = 5
		}
		0x53 {
			logger.debug('MOV    D.E')
			state.d = state.e
			cycles_used = 5
		}
		0x54 {
			logger.debug('MOV    D,H')
			state.d = state.h
			cycles_used = 5
		}
		0x55 {
			logger.debug('MOV    D,L')
			state.d = state.l
			cycles_used = 5
		}
		0x56 {
			logger.debug('MOV    D,M')
			state.d = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x57 {
			logger.debug('MOV    D,A')
			state.d = state.a
			cycles_used = 5
		}
		0x58 {
			logger.debug('MOV    E,B')
			state.e = state.b
			cycles_used = 5
		}
		0x59 {
			logger.debug('MOV    E,C')
			state.e = state.c
			cycles_used = 5
		}
		0x5a {
			logger.debug('MOV    E,D')
			state.e = state.d
			cycles_used = 5
		}
		0x5b {
			logger.debug('MOV    E,E')
			state.e = state.e
			cycles_used = 5
		}
		0x5c {
			logger.debug('MOV    E,H')
			state.e = state.h
			cycles_used = 5
		}
		0x5d {
			logger.debug('MOV    E,L')
			state.e = state.l
			cycles_used = 5
		}
		0x5e {
			logger.debug('MOV    E,M')
			state.e = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x5f {
			logger.debug('MOV    E,A')
			state.e = state.a
			cycles_used = 5
		}
		0x60 {
			logger.debug('MOV    H,B')
			state.h = state.b
			cycles_used = 5
		}
		0x61 {
			logger.debug('MOV    H,C')
			state.h = state.c
			cycles_used = 5
		}
		0x62 {
			logger.debug('MOV    H,D')
			state.h = state.d
			cycles_used = 5
		}
		0x63 {
			logger.debug('MOV    H.E')
			state.h = state.e
			cycles_used = 5
		}
		0x64 {
			logger.debug('MOV    H,H')
			state.h = state.h
			cycles_used = 5
		}
		0x65 {
			logger.debug('MOV    H,L')
			state.h = state.l
			cycles_used = 5
		}
		0x66 {
			logger.debug('MOV    H,M')
			state.h = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x67 {
			logger.debug('MOV    H,A')
			state.h = state.a
			cycles_used = 5
		}
		0x68 {
			logger.debug('MOV    L,B')
			state.l = state.b
			cycles_used = 5
		}
		0x69 {
			logger.debug('MOV    L,C')
			state.l = state.c
			cycles_used = 5
		}
		0x6a {
			logger.debug('MOV    L,D')
			state.l = state.d
			cycles_used = 5
		}
		0x6b {
			logger.debug('MOV    L,E')
			state.l = state.e
			cycles_used = 5
		}
		0x6c {
			logger.debug('MOV    L,H')
			state.l = state.h
			cycles_used = 5
		}
		0x6d {
			logger.debug('MOV    L,L')
			state.l = state.l
			cycles_used = 5
		}
		0x6e {
			logger.debug('MOV    L,M')
			state.l = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x6f {
			logger.debug('MOV    L,A')
			state.l = state.a
			cycles_used = 5
		}
		0x70 {
			logger.debug('MOV    M,B')
			state.mem[utils.create_address(state.h, state.l)] = state.b
			cycles_used = 7
		}
		0x71 {
			logger.debug('MOV    M,C')
			state.mem[utils.create_address(state.h, state.l)] = state.c
			cycles_used = 7
		}
		0x72 {
			logger.debug('MOV    M,D')
			state.mem[utils.create_address(state.h, state.l)] = state.d
			cycles_used = 7
		}
		0x73 {
			logger.debug('MOV    M.E')
			state.mem[utils.create_address(state.h, state.l)] = state.e
			cycles_used = 7
		}
		0x74 {
			logger.debug('MOV    M,H')
			state.mem[utils.create_address(state.h, state.l)] = state.h
			cycles_used = 7
		}
		0x75 {
			logger.debug('MOV    M,L')
			state.mem[utils.create_address(state.h, state.l)] = state.l
			cycles_used = 7
		}
		0x76 {
			logger.debug('HLT')
			cycles_used = 7
			return error('unimplemented')
		}
		0x77 {
			logger.debug('MOV    M,A')
			addr := utils.create_address(state.h, state.l)
			cycles_used = 7
			state.mem[addr] = state.a
		}
		0x78 {
			logger.debug('MOV    A,B')
			state.a = state.b
			cycles_used = 5
		}
		0x79 {
			logger.debug('MOV    A,C')
			state.a = state.c
			cycles_used = 5
		}
		0x7a {
			logger.debug('MOV    A,D')
			state.a = state.d
			cycles_used = 5
		}
		0x7b {
			logger.debug('MOV    A,E')
			state.a = state.e
			cycles_used = 5
		}
		0x7c {
			logger.debug('MOV    A,H')
			state.a = state.h
			cycles_used = 5
		}
		0x7d {
			logger.debug('MOV    A,L')
			state.a = state.l
			cycles_used = 5
		}
		0x7e {
			logger.debug('MOV    A,M')
			state.a = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x7f {
			logger.debug('MOV    A,A')
			state.a = state.a
			cycles_used = 5
		}
		0x80 {
			logger.debug('ADD    B')
			state.execute_addition_and_store(state.a, state.b)
			cycles_used = 4
		}
		0x81 {
			logger.debug('ADD    C')
			state.execute_addition_and_store(state.a, state.c)
			cycles_used = 4
		}
		0x82 {
			logger.debug('ADD    D')
			state.execute_addition_and_store(state.a, state.d)
			cycles_used = 4
		}
		0x83 {
			logger.debug('ADD    E')
			state.execute_addition_and_store(state.a, state.e)
			cycles_used = 4
		}
		0x84 {
			logger.debug('ADD    H')
			state.execute_addition_and_store(state.a, state.h)
			cycles_used = 4
		}
		0x85 {
			logger.debug('ADD    L')
			state.execute_addition_and_store(state.a, state.l)
			cycles_used = 4
		}
		0x86 {
			logger.debug('ADD    M')
			offset := utils.create_address(state.h, state.l)
			cycles_used = 7
			state.execute_addition_and_store(state.a, state.mem[offset])
		}
		0x87 {
			logger.debug('ADD    A')
			state.execute_addition_and_store(state.a, state.a)
			cycles_used = 4
		}
		0x88 {
			logger.debug('ADC    B')
			state.adc(state.a, state.b)
			cycles_used = 4
		}
		0x89 {
			logger.debug('ADC    C')
			state.adc(state.a, state.c)
			cycles_used = 4
		}
		0x8a {
			logger.debug('ADC    D')
			state.adc(state.a, state.d)
			cycles_used = 4
		}
		0x8b {
			logger.debug('ADC    E')
			state.adc(state.a, state.e)
			cycles_used = 4
		}
		0x8c {
			logger.debug('ADC    H')
			state.adc(state.a, state.h)
			cycles_used = 4
		}
		0x8d {
			logger.debug('ADC    L')
			state.adc(state.a, state.l)
			cycles_used = 4
		}
		0x8e {
			logger.debug('ADC    M')
			state.adc(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0x8f {
			logger.debug('ADC    A')
			state.adc(state.a, state.a)
			cycles_used = 4
		}
		0x90 {
			logger.debug('SUB    B')
			state.execute_addition_and_store(state.a, -state.b)
			cycles_used = 4
		}
		0x91 {
			logger.debug('SUB    C')
			state.execute_addition_and_store(state.a, -state.c)
			cycles_used = 4
		}
		0x92 {
			logger.debug('SUB    D')
			state.execute_addition_and_store(state.a, -state.d)
			cycles_used = 4
		}
		0x93 {
			logger.debug('SUB    E')
			state.execute_addition_and_store(state.a, -state.e)
			cycles_used = 4
		}
		0x94 {
			logger.debug('SUB    H')
			state.execute_addition_and_store(state.a, -state.h)
			cycles_used = 4
		}
		0x95 {
			logger.debug('SUB    L')
			state.execute_addition_and_store(state.a, -state.l)
			cycles_used = 4
		}
		0x96 {
			logger.debug('SUB    M')
			state.execute_addition_and_store(state.a, -(state.mem[utils.create_address(state.h,
				state.l)]))
			cycles_used = 7
		}
		0x97 {
			logger.debug('SUB    A')
			state.execute_addition_and_store(state.a, -state.a)
			cycles_used = 4
		}
		0x98 {
			logger.debug('SBB    B')
			state.sbb(state.a, state.b)
			cycles_used = 4
		}
		0x99 {
			logger.debug('SBB    C')
			state.sbb(state.a, state.c)
			cycles_used = 4
		}
		0x9a {
			logger.debug('SBB    D')
			state.sbb(state.a, state.d)
			cycles_used = 4
		}
		0x9b {
			logger.debug('SBB    E')
			state.sbb(state.a, state.e)
			cycles_used = 4
		}
		0x9c {
			logger.debug('SBB    H')
			state.sbb(state.a, state.h)
			cycles_used = 4
		}
		0x9d {
			logger.debug('SBB    L')
			state.sbb(state.a, state.l)
			cycles_used = 4
		}
		0x9e {
			logger.debug('SBB    M')
			state.sbb(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0x9f {
			logger.debug('SBB    A')
			state.sbb(state.a, state.a)
			cycles_used = 4
		}
		0xa0 {
			logger.debug('ANA    B')
			state.and(state.a, state.b)
			cycles_used = 4
		}
		0xa1 {
			logger.debug('ANA    C')
			state.and(state.a, state.c)
			cycles_used = 4
		}
		0xa2 {
			logger.debug('ANA    D')
			state.and(state.a, state.d)
			cycles_used = 4
		}
		0xa3 {
			logger.debug('ANA    E')
			state.and(state.a, state.e)
			cycles_used = 4
		}
		0xa4 {
			logger.debug('ANA    H')
			state.and(state.a, state.h)
			cycles_used = 4
		}
		0xa5 {
			logger.debug('ANA    L')
			state.and(state.a, state.l)
			cycles_used = 4
		}
		0xa6 {
			logger.debug('ANA    M')
			state.and(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0xa7 {
			logger.debug('ANA    A')
			state.and(state.a, state.a)
			cycles_used = 4
		}
		0xa8 {
			logger.debug('XRA    B')
			state.xra(state.a, state.b)
			cycles_used = 4
		}
		0xa9 {
			logger.debug('XRA    C')
			state.xra(state.a, state.c)
			cycles_used = 4
		}
		0xaa {
			logger.debug('XRA    D')
			state.xra(state.a, state.d)
			cycles_used = 4
		}
		0xab {
			logger.debug('XRA    E')
			state.xra(state.a, state.e)
			cycles_used = 4
		}
		0xac {
			logger.debug('XRA    H')
			state.xra(state.a, state.h)
			cycles_used = 4
		}
		0xad {
			logger.debug('XRA    L')
			state.xra(state.a, state.l)
			cycles_used = 4
		}
		0xae {
			logger.debug('XRA    M')
			state.xra(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0xaf {
			logger.debug('XRA    A')
			state.xra(state.a, state.a)
			cycles_used = 4
		}
		0xb0 {
			logger.debug('ORA    B')
			state.ora(state.a, state.b)
			cycles_used = 4
		}
		0xb1 {
			logger.debug('ORA    C')
			state.ora(state.a, state.c)
			cycles_used = 4
		}
		0xb2 {
			logger.debug('ORA    D')
			state.ora(state.a, state.d)
			cycles_used = 4
		}
		0xb3 {
			logger.debug('ORA    E')
			state.ora(state.a, state.e)
			cycles_used = 4
		}
		0xb4 {
			logger.debug('ORA    H')
			state.ora(state.a, state.h)
			cycles_used = 4
		}
		0xb5 {
			logger.debug('ORA    L')
			state.ora(state.a, state.l)
			cycles_used = 4
		}
		0xb6 {
			logger.debug('ORA    M')
			state.ora(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0xb7 {
			logger.debug('ORA    A')
			state.ora(state.a, state.a)
			cycles_used = 4
		}
		0xb8 {
			logger.debug('CMP    B')
			state.execute_addition(state.a, -state.b)
			cycles_used = 4
		}
		0xb9 {
			logger.debug('CMP    C')
			state.execute_addition(state.a, -state.c)
			cycles_used = 4
		}
		0xba {
			logger.debug('CMP    D')
			state.execute_addition(state.a, -state.d)
			cycles_used = 4
		}
		0xbb {
			logger.debug('CMP    E')
			state.execute_addition(state.a, -state.e)
			cycles_used = 4
		}
		0xbc {
			logger.debug('CMP    H')
			state.execute_addition(state.a, -state.h)
			cycles_used = 4
		}
		0xbd {
			logger.debug('CMP    L')
			state.execute_addition(state.a, -state.l)
			cycles_used = 4
		}
		0xbe {
			logger.debug('CMP    M')
			state.execute_addition(state.a, -(state.mem[utils.create_address(state.h,
				state.l)]))
			cycles_used = 7
		}
		0xbf {
			logger.debug('CMP    A')
			state.execute_addition(state.a, -state.a)
			cycles_used = 4
		}
		0xc0 {
			logger.debug('RNZ')
			// If Not Zero, execute a RET
			if !state.flags.z {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xc1 {
			logger.debug('POP    B')
			state.c, state.b = state.pop()
			cycles_used = 10
		}
		0xc2 {
			logger.debug('JNZ    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.z {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				// Skip following address if we did not jump
				state.pc += 2
			}
			cycles_used = 10
		}
		0xc3 {
			logger.debug('JMP    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			cycles_used = 10
		}
		0xc4 {
			logger.debug('CNZ    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.z {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xc5 {
			logger.debug('PUSH   B')
			state.push(state.b, state.c)
			cycles_used = 11
		}
		0xc6 {
			logger.debug('ADI    #$${state.mem[pc+1]:02x}')
			state.execute_addition_and_store(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xc7 {
			logger.debug('RST    0')
			state.call(state.pc, 0)
			cycles_used = 11
		}
		0xc8 {
			logger.debug('RZ')
			if state.flags.z {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xc9 {
			logger.debug('RET')
			state.ret()
			cycles_used = 10
		}
		0xca {
			logger.debug('JZ     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.z {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xcb {
			logger.debug('JMP    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			cycles_used = 10
		}
		0xcc {
			logger.debug('CZ     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.z {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xcd {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xce {
			logger.debug('ACI    #$${state.mem[pc+1]:02x}')
			state.execute_addition_and_store(state.a, u16(state.mem[pc + 1]) + u16(utils.bool_byte(state.flags.cy)))
			state.pc++
			cycles_used = 7
		}
		0xcf {
			logger.debug('RST    1')
			state.call(state.pc, 0x0008)
			cycles_used = 11
		}
		0xd0 {
			logger.debug('RNC')
			if !state.flags.cy {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xd1 {
			logger.debug('POP    D')
			state.e, state.d = state.pop()
			cycles_used = 10
		}
		0xd2 {
			logger.debug('JNC    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.cy {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xd3 {
			logger.debug('OUT    #$${state.mem[pc+1]:02x}')
			state.machine.op_out(state.mem[pc + 1])?
			state.pc++
			cycles_used = 10
		}
		0xd4 {
			logger.debug('CNC    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.cy {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xd5 {
			logger.debug('PUSH   D')
			state.push(state.d, state.e)
			cycles_used = 11
		}
		0xd6 {
			logger.debug('SUI    #$${state.mem[pc+1]:02x}')
			state.execute_addition_and_store(state.a, -(state.mem[pc + 1]))
			state.pc++
			cycles_used = 7
		}
		0xd7 {
			logger.debug('RST    2')
			state.call(state.pc, 0x0010)
			cycles_used = 11
		}
		0xd8 {
			logger.debug('RC')
			if state.flags.cy {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xd9 {
			logger.debug('RET')
			state.ret()
			cycles_used = 10
		}
		0xda {
			logger.debug('JC     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.cy {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xdb {
			logger.debug('IN     #$${state.mem[pc+1]:02x}')
			state.a = state.machine.op_in(state.mem[pc + 1])?
			state.pc++
			cycles_used = 10
		}
		0xdc {
			logger.debug('CC     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.cy {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xdd {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xde {
			logger.debug('SBI    #$${state.mem[pc+1]:02x}')
			state.execute_addition_and_store(state.a, -(u16(state.mem[pc + 1])) - u16(utils.bool_byte(state.flags.cy)))
			state.pc++
			cycles_used = 7
		}
		0xdf {
			logger.debug('RST    3')
			state.call(state.pc, 0x0018)
			cycles_used = 11
		}
		0xe0 {
			logger.debug('RPO')
			if !state.flags.p {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xe1 {
			logger.debug('POP    H')
			state.l, state.h = state.pop()
			cycles_used = 10
		}
		0xe2 {
			logger.debug('JPO    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.p {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xe3 {
			logger.debug('XTHL')
			h, l := state.h, state.l
			state.h, state.l = state.mem[state.sp + 1], state.mem[state.sp]
			state.mem[state.sp + 1], state.mem[state.sp] = h, l
			cycles_used = 18
		}
		0xe4 {
			logger.debug('CPO    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.p {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xe5 {
			logger.debug('PUSH   H')
			state.push(state.h, state.l)
			cycles_used = 11
		}
		0xe6 {
			logger.debug('ANI    #$${state.mem[pc+1]:02x}')
			state.and(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xe7 {
			logger.debug('RST    4')
			state.call(state.pc, 0x0020)
			cycles_used = 11
		}
		0xe8 {
			logger.debug('RPE')
			if state.flags.p {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xe9 {
			logger.debug('PCHL')
			state.pc = utils.create_address(state.h, state.l)
			cycles_used = 5
		}
		0xea {
			logger.debug('JPE    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.p {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xeb {
			logger.debug('XCHG')
			temp1, temp2 := state.h, state.l
			state.h, state.l = state.d, state.e
			state.d, state.e = temp1, temp2
			cycles_used = 5
		}
		0xec {
			logger.debug('CPE     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.p {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xed {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xee {
			logger.debug('XRI    #$${state.mem[pc+1]:02x}')
			state.xra(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xef {
			logger.debug('RST    5')
			state.call(state.pc, 0x0028)
			cycles_used = 11
		}
		0xf0 {
			logger.debug('RP')
			if !state.flags.s {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xf1 {
			logger.debug('POP    PSW')
			psw, a := state.pop()
			state.flags.z = ((psw & 0x01) == 0x01)
			state.flags.s = ((psw & 0x02) == 0x02)
			state.flags.p = ((psw & 0x04) == 0x04)
			state.flags.cy = ((psw & 0x08) == 0x05)
			state.flags.ac = ((psw & 0x10) == 0x10)
			state.a = a
			cycles_used = 10
		}
		0xf2 {
			logger.debug('JP     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// TODO: Am I sure I have the definition of "P" right?
			if !state.flags.s {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xf3 {
			logger.debug('DI')
			state.interrupt_enabled = false
			cycles_used = 4
		}
		0xf4 {
			logger.debug('CP     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.s {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xf5 {
			logger.debug('PUSH   PSW')
			psw := (utils.bool_byte(state.flags.z) |
				(utils.bool_byte(state.flags.s) << 1) |
				(utils.bool_byte(state.flags.p) << 2) |
				(utils.bool_byte(state.flags.cy) << 3) |
				(utils.bool_byte(state.flags.ac) << 4))
			state.push(state.a, psw)
			cycles_used = 11
		}
		0xf6 {
			logger.debug('ORI    #$${state.mem[pc+1]:02x}')
			state.ora(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xf7 {
			logger.debug('RST    6')
			state.call(state.pc, 0x0030)
			cycles_used = 11
		}
		0xf8 {
			logger.debug('RM')
			if state.flags.s {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xf9 {
			logger.debug('SPHL')
			state.sp = utils.create_address(state.h, state.l)
			cycles_used = 5
		}
		0xfa {
			logger.debug('JM     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.s {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xfb {
			logger.debug('EI')
			state.interrupt_enabled = true
			cycles_used = 4
		}
		0xfc {
			logger.debug('CM     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if state.flags.s {
				state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xfd {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.call(pc + 2, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xfe {
			logger.debug('CPI    #$${state.mem[pc+1]:02x}')
			// Throw away the result, we do not store it
			// TODO (vcomp): Interesting V compiler bug, when using the negation
			// operator with the result of the array access it applies the operators
			// in an incorrect ordering.
			_ = state.execute_addition(state.a, -(state.mem[pc + 1]))
			state.pc++
			cycles_used = 7
		}
		0xff {
			logger.debug('RST    7')
			state.call(state.pc, 0x0038)
			cycles_used = 11
		}
		else {
			return error('unknown opcode: ${state.mem[pc]}')
		}
	}
	// TODO (vcomp): The use of '.str()' here seems to be a bug with the V compiler;
	// It can't figure out to use the pointer variant of the State struct
	// when calling the string function automatically while interpolating,
	// so a manual usage fixes that for now.
	logger.debug('8080 State:\n$state.str()')
	if cycles_used == 0 {
		return error('got 0 cycles for instruction ${state.mem[pc]:02x}')
	}
	return cycles_used
}
