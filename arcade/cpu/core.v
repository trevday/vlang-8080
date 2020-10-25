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
	return 'a: 0x${state.a:02x} b: 0x${state.b:02x} c: 0x${state.c:02x} d: 0x${state.d:02x} ' +
		'e: 0x${state.e:02x} h: 0x${state.h:02x} l: 0x${state.l:02x} ' + 'sp: 0x${state.sp:04x} pc: 0x${state.pc:04x} ' +
		'z: $state.flags.z s: $state.flags.s p: $state.flags.p cy: $state.flags.cy ac: $state.flags.ac'
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
	mut cmd_str := ''
	match state.mem[pc] {
		0x00 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x01 {
			cmd_str = 'LXI    B,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.b = state.mem[pc + 2]
			state.c = state.mem[pc + 1]
			state.pc += 2
			cycles_used = 10
		}
		0x02 {
			cmd_str = 'STAX   B'
			state.mem[utils.create_address(state.b, state.c)] = state.a
			cycles_used = 7
		}
		0x03 {
			cmd_str = 'INX    B'
			mut bc := utils.create_address(state.b, state.c)
			bc++
			state.b, state.c = utils.break_address(bc)
			cycles_used = 5
		}
		0x04 {
			cmd_str = 'INR    B'
			state.b = state.inr(state.b)
			cycles_used = 5
		}
		0x05 {
			cmd_str = 'DCR    B'
			state.b = state.dcr(state.b)
			cycles_used = 5
		}
		0x06 {
			cmd_str = 'MVI    B,#$${state.mem[pc+1]:02x}'
			state.b = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x07 {
			cmd_str = 'RLC'
			temp := state.a
			state.a = ((temp & 128) >> 7) | (temp << 1)
			// Set carryover if the bit that wraps around
			// is 1
			state.flags.cy = ((temp & 128) == 128)
			cycles_used = 4
		}
		0x08 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x09 {
			cmd_str = 'DAD    B'
			state.dad(state.b, state.c)
			cycles_used = 10
		}
		0x0a {
			cmd_str = 'LDAX   B'
			state.a = state.mem[utils.create_address(state.b, state.c)]
			cycles_used = 7
		}
		0x0b {
			cmd_str = 'DCX    B'
			mut bc := utils.create_address(state.b, state.c)
			bc--
			state.b, state.c = utils.break_address(bc)
			cycles_used = 5
		}
		0x0c {
			cmd_str = 'INR    C'
			state.c = state.inr(state.c)
			cycles_used = 5
		}
		0x0d {
			cmd_str = 'DCR    C'
			state.c = state.dcr(state.c)
			cycles_used = 5
		}
		0x0e {
			cmd_str = 'MVI    C,#$${state.mem[pc+1]:02x}'
			state.c = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x0f {
			cmd_str = 'RRC'
			temp := state.a
			state.a = ((temp & 1) << 7) | (temp >> 1)
			// Set carryover if the bit that wraps around
			// is 1
			state.flags.cy = ((temp & 1) == 1)
			cycles_used = 4
		}
		0x10 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x11 {
			cmd_str = 'LXI    D,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.d = state.mem[pc + 2]
			state.e = state.mem[pc + 1]
			state.pc += 2
			cycles_used = 10
		}
		0x12 {
			cmd_str = 'STAX   D'
			state.mem[utils.create_address(state.d, state.e)] = state.a
			cycles_used = 7
		}
		0x13 {
			cmd_str = 'INX    D'
			mut de := utils.create_address(state.d, state.e)
			de++
			state.d, state.e = utils.break_address(de)
			cycles_used = 5
		}
		0x14 {
			cmd_str = 'INR    D'
			state.d = state.inr(state.d)
			cycles_used = 5
		}
		0x15 {
			cmd_str = 'DCR    D'
			state.d = state.dcr(state.d)
			cycles_used = 5
		}
		0x16 {
			cmd_str = 'MVI    D,#$${state.mem[pc+1]:02x}'
			state.d = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x17 {
			cmd_str = 'RAL'
			temp := state.a
			state.a = (utils.bool_byte(state.flags.cy) | (temp << 1))
			// We use the carryover flag as the wrapping bit here,
			// but still set carryover based on whether there would
			// have been a wrapping bit of 1
			state.flags.cy = ((temp & 128) == 128)
			cycles_used = 4
		}
		0x18 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x19 {
			cmd_str = 'DAD    D'
			state.dad(state.d, state.e)
			cycles_used = 10
		}
		0x1a {
			cmd_str = 'LDAX   D'
			state.a = state.mem[utils.create_address(state.d, state.e)]
			cycles_used = 7
		}
		0x1b {
			cmd_str = 'DCX    D'
			mut de := utils.create_address(state.d, state.e)
			de--
			state.d, state.e = utils.break_address(de)
			cycles_used = 5
		}
		0x1c {
			cmd_str = 'INR    E'
			state.e = state.inr(state.e)
			cycles_used = 5
		}
		0x1d {
			cmd_str = 'DCR    E'
			state.e = state.dcr(state.e)
			cycles_used = 5
		}
		0x1e {
			cmd_str = 'MVI    E,#$${state.mem[pc+1]:02x}'
			state.e = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x1f {
			cmd_str = 'RAR'
			temp := state.a
			state.a = (utils.bool_byte(state.flags.cy) << 7) | (temp >> 1)
			// We use the carryover flag as the wrapping bit here,
			// but still set carryover based on whether there would
			// have been a wrapping bit of 1
			state.flags.cy = ((temp & 1) == 1)
			cycles_used = 4
		}
		0x20 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x21 {
			cmd_str = 'LXI    H,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.h = state.mem[pc + 2]
			state.l = state.mem[pc + 1]
			state.pc += 2
			cycles_used = 10
		}
		0x22 {
			cmd_str = 'SHLD   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.mem[addr] = state.l
			state.mem[addr + 1] = state.h
			state.pc += 2
		}
		0x23 {
			cmd_str = 'INX    H'
			mut hl := utils.create_address(state.h, state.l)
			hl++
			state.h, state.l = utils.break_address(hl)
			cycles_used = 5
		}
		0x24 {
			cmd_str = 'INR    H'
			state.h = state.inr(state.h)
			cycles_used = 5
		}
		0x25 {
			cmd_str = 'DCR    H'
			state.h = state.dcr(state.h)
			cycles_used = 5
		}
		0x26 {
			cmd_str = 'MVI    H,#$${state.mem[pc+1]:02x}'
			state.h = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x27 {
			cmd_str = 'DAA'
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
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x29 {
			cmd_str = 'DAD    H'
			state.dad(state.h, state.l)
			cycles_used = 10
		}
		0x2a {
			cmd_str = 'LHLD   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.l = state.mem[addr]
			state.h = state.mem[addr + 1]
			state.pc += 2
		}
		0x2b {
			cmd_str = 'DCX    H'
			mut hl := utils.create_address(state.h, state.l)
			hl--
			state.h, state.l = utils.break_address(hl)
			cycles_used = 5
		}
		0x2c {
			cmd_str = 'INR    L'
			state.l = state.inr(state.l)
			cycles_used = 5
		}
		0x2d {
			cmd_str = 'DCR    L'
			state.l = state.dcr(state.l)
			cycles_used = 5
		}
		0x2e {
			cmd_str = 'MVI    L,#$${state.mem[pc+1]:02x}'
			state.l = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x2f {
			cmd_str = 'CMA'
			state.a = ~state.a
			cycles_used = 4
		}
		0x30 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x31 {
			cmd_str = 'LXI    SP,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.sp = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.pc += 2
			cycles_used = 10
		}
		0x32 {
			cmd_str = 'STA    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.mem[addr] = state.a
			state.pc += 2
			cycles_used = 13
		}
		0x33 {
			cmd_str = 'INX    SP'
			state.sp++
			cycles_used = 5
		}
		0x34 {
			cmd_str = 'INR    M'
			hl := utils.create_address(state.h, state.l)
			state.mem[hl] = state.inr(state.mem[hl])
			cycles_used = 10
		}
		0x35 {
			cmd_str = 'DCR    M'
			hl := utils.create_address(state.h, state.l)
			state.mem[hl] = state.dcr(state.mem[hl])
			cycles_used = 10
		}
		0x36 {
			cmd_str = 'MVI    M,#$${state.mem[pc+1]:02x}'
			addr := utils.create_address(state.h, state.l)
			state.mem[addr] = state.mem[pc + 1]
			state.pc++
			cycles_used = 10
		}
		0x37 {
			cmd_str = 'STC'
			state.flags.cy = true
			cycles_used = 4
		}
		0x38 {
			cmd_str = 'NOP'
			// NOP
			cycles_used = 4
		}
		0x39 {
			cmd_str = 'DAD    SP'
			sp1, sp2 := utils.break_address(state.sp)
			state.dad(sp1, sp2)
			cycles_used = 10
		}
		0x3a {
			cmd_str = 'LDA    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			addr := utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.a = state.mem[addr]
			state.pc += 2
			cycles_used = 13
		}
		0x3b {
			cmd_str = 'DCX    SP'
			state.sp--
			cycles_used = 5
		}
		0x3c {
			cmd_str = 'INR    A'
			state.a = state.inr(state.a)
			cycles_used = 5
		}
		0x3d {
			cmd_str = 'DCR    A'
			state.a = state.dcr(state.a)
			cycles_used = 5
		}
		0x3e {
			cmd_str = 'MVI    A,#$${state.mem[pc+1]:02x}'
			state.a = state.mem[pc + 1]
			state.pc++
			cycles_used = 7
		}
		0x3f {
			cmd_str = 'CMC'
			state.flags.cy = !state.flags.cy
			cycles_used = 4
		}
		0x40 {
			cmd_str = 'MOV    B,B'
			state.b = state.b
			cycles_used = 5
		}
		0x41 {
			cmd_str = 'MOV    B,C'
			state.b = state.c
			cycles_used = 5
		}
		0x42 {
			cmd_str = 'MOV    B,D'
			state.b = state.d
			cycles_used = 5
		}
		0x43 {
			cmd_str = 'MOV    B,E'
			state.b = state.e
			cycles_used = 5
		}
		0x44 {
			cmd_str = 'MOV    B,H'
			state.b = state.h
			cycles_used = 5
		}
		0x45 {
			cmd_str = 'MOV    B,L'
			state.b = state.l
			cycles_used = 5
		}
		0x46 {
			cmd_str = 'MOV    B,M'
			state.b = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x47 {
			cmd_str = 'MOV    B,A'
			state.b = state.a
			cycles_used = 5
		}
		0x48 {
			cmd_str = 'MOV    C,B'
			state.c = state.b
			cycles_used = 5
		}
		0x49 {
			cmd_str = 'MOV    C,C'
			state.c = state.c
			cycles_used = 5
		}
		0x4a {
			cmd_str = 'MOV    C,D'
			state.c = state.d
			cycles_used = 5
		}
		0x4b {
			cmd_str = 'MOV    C,E'
			state.c = state.e
			cycles_used = 5
		}
		0x4c {
			cmd_str = 'MOV    C,H'
			state.c = state.h
			cycles_used = 5
		}
		0x4d {
			cmd_str = 'MOV    C,L'
			state.c = state.l
			cycles_used = 5
		}
		0x4e {
			cmd_str = 'MOV    C,M'
			state.c = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x4f {
			cmd_str = 'MOV    C,A'
			state.c = state.a
			cycles_used = 5
		}
		0x50 {
			cmd_str = 'MOV    D,B'
			state.d = state.a
			cycles_used = 5
		}
		0x51 {
			cmd_str = 'MOV    D,C'
			state.d = state.c
			cycles_used = 5
		}
		0x52 {
			cmd_str = 'MOV    D,D'
			state.d = state.d
			cycles_used = 5
		}
		0x53 {
			cmd_str = 'MOV    D.E'
			state.d = state.e
			cycles_used = 5
		}
		0x54 {
			cmd_str = 'MOV    D,H'
			state.d = state.h
			cycles_used = 5
		}
		0x55 {
			cmd_str = 'MOV    D,L'
			state.d = state.l
			cycles_used = 5
		}
		0x56 {
			cmd_str = 'MOV    D,M'
			state.d = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x57 {
			cmd_str = 'MOV    D,A'
			state.d = state.a
			cycles_used = 5
		}
		0x58 {
			cmd_str = 'MOV    E,B'
			state.e = state.b
			cycles_used = 5
		}
		0x59 {
			cmd_str = 'MOV    E,C'
			state.e = state.c
			cycles_used = 5
		}
		0x5a {
			cmd_str = 'MOV    E,D'
			state.e = state.d
			cycles_used = 5
		}
		0x5b {
			cmd_str = 'MOV    E,E'
			state.e = state.e
			cycles_used = 5
		}
		0x5c {
			cmd_str = 'MOV    E,H'
			state.e = state.h
			cycles_used = 5
		}
		0x5d {
			cmd_str = 'MOV    E,L'
			state.e = state.l
			cycles_used = 5
		}
		0x5e {
			cmd_str = 'MOV    E,M'
			state.e = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x5f {
			cmd_str = 'MOV    E,A'
			state.e = state.a
			cycles_used = 5
		}
		0x60 {
			cmd_str = 'MOV    H,B'
			state.h = state.b
			cycles_used = 5
		}
		0x61 {
			cmd_str = 'MOV    H,C'
			state.h = state.c
			cycles_used = 5
		}
		0x62 {
			cmd_str = 'MOV    H,D'
			state.h = state.d
			cycles_used = 5
		}
		0x63 {
			cmd_str = 'MOV    H.E'
			state.h = state.e
			cycles_used = 5
		}
		0x64 {
			cmd_str = 'MOV    H,H'
			state.h = state.h
			cycles_used = 5
		}
		0x65 {
			cmd_str = 'MOV    H,L'
			state.h = state.l
			cycles_used = 5
		}
		0x66 {
			cmd_str = 'MOV    H,M'
			state.h = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x67 {
			cmd_str = 'MOV    H,A'
			state.h = state.a
			cycles_used = 5
		}
		0x68 {
			cmd_str = 'MOV    L,B'
			state.l = state.b
			cycles_used = 5
		}
		0x69 {
			cmd_str = 'MOV    L,C'
			state.l = state.c
			cycles_used = 5
		}
		0x6a {
			cmd_str = 'MOV    L,D'
			state.l = state.d
			cycles_used = 5
		}
		0x6b {
			cmd_str = 'MOV    L,E'
			state.l = state.e
			cycles_used = 5
		}
		0x6c {
			cmd_str = 'MOV    L,H'
			state.l = state.h
			cycles_used = 5
		}
		0x6d {
			cmd_str = 'MOV    L,L'
			state.l = state.l
			cycles_used = 5
		}
		0x6e {
			cmd_str = 'MOV    L,M'
			state.l = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x6f {
			cmd_str = 'MOV    L,A'
			state.l = state.a
			cycles_used = 5
		}
		0x70 {
			cmd_str = 'MOV    M,B'
			state.mem[utils.create_address(state.h, state.l)] = state.b
			cycles_used = 7
		}
		0x71 {
			cmd_str = 'MOV    M,C'
			state.mem[utils.create_address(state.h, state.l)] = state.c
			cycles_used = 7
		}
		0x72 {
			cmd_str = 'MOV    M,D'
			state.mem[utils.create_address(state.h, state.l)] = state.d
			cycles_used = 7
		}
		0x73 {
			cmd_str = 'MOV    M.E'
			state.mem[utils.create_address(state.h, state.l)] = state.e
			cycles_used = 7
		}
		0x74 {
			cmd_str = 'MOV    M,H'
			state.mem[utils.create_address(state.h, state.l)] = state.h
			cycles_used = 7
		}
		0x75 {
			cmd_str = 'MOV    M,L'
			state.mem[utils.create_address(state.h, state.l)] = state.l
			cycles_used = 7
		}
		0x76 {
			cmd_str = 'HLT'
			cycles_used = 7
			return error('unimplemented')
		}
		0x77 {
			cmd_str = 'MOV    M,A'
			addr := utils.create_address(state.h, state.l)
			cycles_used = 7
			state.mem[addr] = state.a
		}
		0x78 {
			cmd_str = 'MOV    A,B'
			state.a = state.b
			cycles_used = 5
		}
		0x79 {
			cmd_str = 'MOV    A,C'
			state.a = state.c
			cycles_used = 5
		}
		0x7a {
			cmd_str = 'MOV    A,D'
			state.a = state.d
			cycles_used = 5
		}
		0x7b {
			cmd_str = 'MOV    A,E'
			state.a = state.e
			cycles_used = 5
		}
		0x7c {
			cmd_str = 'MOV    A,H'
			state.a = state.h
			cycles_used = 5
		}
		0x7d {
			cmd_str = 'MOV    A,L'
			state.a = state.l
			cycles_used = 5
		}
		0x7e {
			cmd_str = 'MOV    A,M'
			state.a = state.mem[utils.create_address(state.h, state.l)]
			cycles_used = 7
		}
		0x7f {
			cmd_str = 'MOV    A,A'
			state.a = state.a
			cycles_used = 5
		}
		0x80 {
			cmd_str = 'ADD    B'
			state.execute_addition_and_store(state.a, state.b)
			cycles_used = 4
		}
		0x81 {
			cmd_str = 'ADD    C'
			state.execute_addition_and_store(state.a, state.c)
			cycles_used = 4
		}
		0x82 {
			cmd_str = 'ADD    D'
			state.execute_addition_and_store(state.a, state.d)
			cycles_used = 4
		}
		0x83 {
			cmd_str = 'ADD    E'
			state.execute_addition_and_store(state.a, state.e)
			cycles_used = 4
		}
		0x84 {
			cmd_str = 'ADD    H'
			state.execute_addition_and_store(state.a, state.h)
			cycles_used = 4
		}
		0x85 {
			cmd_str = 'ADD    L'
			state.execute_addition_and_store(state.a, state.l)
			cycles_used = 4
		}
		0x86 {
			cmd_str = 'ADD    M'
			offset := utils.create_address(state.h, state.l)
			cycles_used = 7
			state.execute_addition_and_store(state.a, state.mem[offset])
		}
		0x87 {
			cmd_str = 'ADD    A'
			state.execute_addition_and_store(state.a, state.a)
			cycles_used = 4
		}
		0x88 {
			cmd_str = 'ADC    B'
			state.adc(state.a, state.b)
			cycles_used = 4
		}
		0x89 {
			cmd_str = 'ADC    C'
			state.adc(state.a, state.c)
			cycles_used = 4
		}
		0x8a {
			cmd_str = 'ADC    D'
			state.adc(state.a, state.d)
			cycles_used = 4
		}
		0x8b {
			cmd_str = 'ADC    E'
			state.adc(state.a, state.e)
			cycles_used = 4
		}
		0x8c {
			cmd_str = 'ADC    H'
			state.adc(state.a, state.h)
			cycles_used = 4
		}
		0x8d {
			cmd_str = 'ADC    L'
			state.adc(state.a, state.l)
			cycles_used = 4
		}
		0x8e {
			cmd_str = 'ADC    M'
			state.adc(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0x8f {
			cmd_str = 'ADC    A'
			state.adc(state.a, state.a)
			cycles_used = 4
		}
		0x90 {
			cmd_str = 'SUB    B'
			state.execute_addition_and_store(state.a, -state.b)
			cycles_used = 4
		}
		0x91 {
			cmd_str = 'SUB    C'
			state.execute_addition_and_store(state.a, -state.c)
			cycles_used = 4
		}
		0x92 {
			cmd_str = 'SUB    D'
			state.execute_addition_and_store(state.a, -state.d)
			cycles_used = 4
		}
		0x93 {
			cmd_str = 'SUB    E'
			state.execute_addition_and_store(state.a, -state.e)
			cycles_used = 4
		}
		0x94 {
			cmd_str = 'SUB    H'
			state.execute_addition_and_store(state.a, -state.h)
			cycles_used = 4
		}
		0x95 {
			cmd_str = 'SUB    L'
			state.execute_addition_and_store(state.a, -state.l)
			cycles_used = 4
		}
		0x96 {
			cmd_str = 'SUB    M'
			state.execute_addition_and_store(state.a, -(state.mem[utils.create_address(state.h,
				state.l)]))
			cycles_used = 7
		}
		0x97 {
			cmd_str = 'SUB    A'
			state.execute_addition_and_store(state.a, -state.a)
			cycles_used = 4
		}
		0x98 {
			cmd_str = 'SBB    B'
			state.sbb(state.a, state.b)
			cycles_used = 4
		}
		0x99 {
			cmd_str = 'SBB    C'
			state.sbb(state.a, state.c)
			cycles_used = 4
		}
		0x9a {
			cmd_str = 'SBB    D'
			state.sbb(state.a, state.d)
			cycles_used = 4
		}
		0x9b {
			cmd_str = 'SBB    E'
			state.sbb(state.a, state.e)
			cycles_used = 4
		}
		0x9c {
			cmd_str = 'SBB    H'
			state.sbb(state.a, state.h)
			cycles_used = 4
		}
		0x9d {
			cmd_str = 'SBB    L'
			state.sbb(state.a, state.l)
			cycles_used = 4
		}
		0x9e {
			cmd_str = 'SBB    M'
			state.sbb(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0x9f {
			cmd_str = 'SBB    A'
			state.sbb(state.a, state.a)
			cycles_used = 4
		}
		0xa0 {
			cmd_str = 'ANA    B'
			state.and(state.a, state.b)
			cycles_used = 4
		}
		0xa1 {
			cmd_str = 'ANA    C'
			state.and(state.a, state.c)
			cycles_used = 4
		}
		0xa2 {
			cmd_str = 'ANA    D'
			state.and(state.a, state.d)
			cycles_used = 4
		}
		0xa3 {
			cmd_str = 'ANA    E'
			state.and(state.a, state.e)
			cycles_used = 4
		}
		0xa4 {
			cmd_str = 'ANA    H'
			state.and(state.a, state.h)
			cycles_used = 4
		}
		0xa5 {
			cmd_str = 'ANA    L'
			state.and(state.a, state.l)
			cycles_used = 4
		}
		0xa6 {
			cmd_str = 'ANA    M'
			state.and(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0xa7 {
			cmd_str = 'ANA    A'
			state.and(state.a, state.a)
			cycles_used = 4
		}
		0xa8 {
			cmd_str = 'XRA    B'
			state.xra(state.a, state.b)
			cycles_used = 4
		}
		0xa9 {
			cmd_str = 'XRA    C'
			state.xra(state.a, state.c)
			cycles_used = 4
		}
		0xaa {
			cmd_str = 'XRA    D'
			state.xra(state.a, state.d)
			cycles_used = 4
		}
		0xab {
			cmd_str = 'XRA    E'
			state.xra(state.a, state.e)
			cycles_used = 4
		}
		0xac {
			cmd_str = 'XRA    H'
			state.xra(state.a, state.h)
			cycles_used = 4
		}
		0xad {
			cmd_str = 'XRA    L'
			state.xra(state.a, state.l)
			cycles_used = 4
		}
		0xae {
			cmd_str = 'XRA    M'
			state.xra(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0xaf {
			cmd_str = 'XRA    A'
			state.xra(state.a, state.a)
			cycles_used = 4
		}
		0xb0 {
			cmd_str = 'ORA    B'
			state.ora(state.a, state.b)
			cycles_used = 4
		}
		0xb1 {
			cmd_str = 'ORA    C'
			state.ora(state.a, state.c)
			cycles_used = 4
		}
		0xb2 {
			cmd_str = 'ORA    D'
			state.ora(state.a, state.d)
			cycles_used = 4
		}
		0xb3 {
			cmd_str = 'ORA    E'
			state.ora(state.a, state.e)
			cycles_used = 4
		}
		0xb4 {
			cmd_str = 'ORA    H'
			state.ora(state.a, state.h)
			cycles_used = 4
		}
		0xb5 {
			cmd_str = 'ORA    L'
			state.ora(state.a, state.l)
			cycles_used = 4
		}
		0xb6 {
			cmd_str = 'ORA    M'
			state.ora(state.a, state.mem[utils.create_address(state.h, state.l)])
			cycles_used = 7
		}
		0xb7 {
			cmd_str = 'ORA    A'
			state.ora(state.a, state.a)
			cycles_used = 4
		}
		0xb8 {
			cmd_str = 'CMP    B'
			state.execute_addition(state.a, -state.b)
			cycles_used = 4
		}
		0xb9 {
			cmd_str = 'CMP    C'
			state.execute_addition(state.a, -state.c)
			cycles_used = 4
		}
		0xba {
			cmd_str = 'CMP    D'
			state.execute_addition(state.a, -state.d)
			cycles_used = 4
		}
		0xbb {
			cmd_str = 'CMP    E'
			state.execute_addition(state.a, -state.e)
			cycles_used = 4
		}
		0xbc {
			cmd_str = 'CMP    H'
			state.execute_addition(state.a, -state.h)
			cycles_used = 4
		}
		0xbd {
			cmd_str = 'CMP    L'
			state.execute_addition(state.a, -state.l)
			cycles_used = 4
		}
		0xbe {
			cmd_str = 'CMP    M'
			state.execute_addition(state.a, -(state.mem[utils.create_address(state.h,
				state.l)]))
			cycles_used = 7
		}
		0xbf {
			cmd_str = 'CMP    A'
			state.execute_addition(state.a, -state.a)
			cycles_used = 4
		}
		0xc0 {
			cmd_str = 'RNZ'
			// If Not Zero, execute a RET
			if !state.flags.z {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xc1 {
			cmd_str = 'POP    B'
			state.c, state.b = state.pop()
			cycles_used = 10
		}
		0xc2 {
			cmd_str = 'JNZ    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.z {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				// Skip following address if we did not jump
				state.pc += 2
			}
			cycles_used = 10
		}
		0xc3 {
			cmd_str = 'JMP    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			cycles_used = 10
		}
		0xc4 {
			cmd_str = 'CNZ    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.z {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xc5 {
			cmd_str = 'PUSH   B'
			state.push(state.b, state.c)
			cycles_used = 11
		}
		0xc6 {
			cmd_str = 'ADI    #$${state.mem[pc+1]:02x}'
			state.execute_addition_and_store(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xc7 {
			cmd_str = 'RST    0'
			state.call(state.pc, 0)
			cycles_used = 11
		}
		0xc8 {
			cmd_str = 'RZ'
			if state.flags.z {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xc9 {
			cmd_str = 'RET'
			state.ret()
			cycles_used = 10
		}
		0xca {
			cmd_str = 'JZ     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.z {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xcb {
			cmd_str = 'JMP    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			cycles_used = 10
		}
		0xcc {
			cmd_str = 'CZ     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.z {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xcd {
			cmd_str = 'CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xce {
			cmd_str = 'ACI    #$${state.mem[pc+1]:02x}'
			state.execute_addition_and_store(state.a, u16(state.mem[pc + 1]) + u16(utils.bool_byte(state.flags.cy)))
			state.pc++
			cycles_used = 7
		}
		0xcf {
			cmd_str = 'RST    1'
			state.call(state.pc, 0x0008)
			cycles_used = 11
		}
		0xd0 {
			cmd_str = 'RNC'
			if !state.flags.cy {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xd1 {
			cmd_str = 'POP    D'
			state.e, state.d = state.pop()
			cycles_used = 10
		}
		0xd2 {
			cmd_str = 'JNC    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.cy {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xd3 {
			cmd_str = 'OUT    #$${state.mem[pc+1]:02x}'
			state.machine.op_out(state.mem[pc + 1])?
			state.pc++
			cycles_used = 10
		}
		0xd4 {
			cmd_str = 'CNC    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.cy {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xd5 {
			cmd_str = 'PUSH   D'
			state.push(state.d, state.e)
			cycles_used = 11
		}
		0xd6 {
			cmd_str = 'SUI    #$${state.mem[pc+1]:02x}'
			state.execute_addition_and_store(state.a, -(state.mem[pc + 1]))
			state.pc++
			cycles_used = 7
		}
		0xd7 {
			cmd_str = 'RST    2'
			state.call(state.pc, 0x0010)
			cycles_used = 11
		}
		0xd8 {
			cmd_str = 'RC'
			if state.flags.cy {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xd9 {
			cmd_str = 'RET'
			state.ret()
			cycles_used = 10
		}
		0xda {
			cmd_str = 'JC     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.cy {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xdb {
			cmd_str = 'IN     #$${state.mem[pc+1]:02x}'
			state.a = state.machine.op_in(state.mem[pc + 1])?
			state.pc++
			cycles_used = 10
		}
		0xdc {
			cmd_str = 'CC     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.cy {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xdd {
			cmd_str = 'CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xde {
			cmd_str = 'SBI    #$${state.mem[pc+1]:02x}'
			state.execute_addition_and_store(state.a, -(u16(state.mem[pc + 1])) - u16(utils.bool_byte(state.flags.cy)))
			state.pc++
			cycles_used = 7
		}
		0xdf {
			cmd_str = 'RST    3'
			state.call(state.pc, 0x0018)
			cycles_used = 11
		}
		0xe0 {
			cmd_str = 'RPO'
			if !state.flags.p {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xe1 {
			cmd_str = 'POP    H'
			state.l, state.h = state.pop()
			cycles_used = 10
		}
		0xe2 {
			cmd_str = 'JPO    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.p {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xe3 {
			cmd_str = 'XTHL'
			h, l := state.h, state.l
			state.h, state.l = state.mem[state.sp + 1], state.mem[state.sp]
			state.mem[state.sp + 1], state.mem[state.sp] = h, l
			cycles_used = 18
		}
		0xe4 {
			cmd_str = 'CPO    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.p {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xe5 {
			cmd_str = 'PUSH   H'
			state.push(state.h, state.l)
			cycles_used = 11
		}
		0xe6 {
			cmd_str = 'ANI    #$${state.mem[pc+1]:02x}'
			state.and(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xe7 {
			cmd_str = 'RST    4'
			state.call(state.pc, 0x0020)
			cycles_used = 11
		}
		0xe8 {
			cmd_str = 'RPE'
			if state.flags.p {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xe9 {
			cmd_str = 'PCHL'
			state.pc = utils.create_address(state.h, state.l)
			cycles_used = 5
		}
		0xea {
			cmd_str = 'JPE    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.p {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xeb {
			cmd_str = 'XCHG'
			temp1, temp2 := state.h, state.l
			state.h, state.l = state.d, state.e
			state.d, state.e = temp1, temp2
			cycles_used = 5
		}
		0xec {
			cmd_str = 'CPE     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.p {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xed {
			cmd_str = 'CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xee {
			cmd_str = 'XRI    #$${state.mem[pc+1]:02x}'
			state.xra(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xef {
			cmd_str = 'RST    5'
			state.call(state.pc, 0x0028)
			cycles_used = 11
		}
		0xf0 {
			cmd_str = 'RP'
			if !state.flags.s {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xf1 {
			cmd_str = 'POP    PSW'
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
			cmd_str = 'JP     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			// TODO: Am I sure I have the definition of "P" right?
			if !state.flags.s {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xf3 {
			cmd_str = 'DI'
			state.interrupt_enabled = false
			cycles_used = 4
		}
		0xf4 {
			cmd_str = 'CP     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if !state.flags.s {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				// Skip following address if we did not jump
				state.pc += 2
				cycles_used = 11
			}
		}
		0xf5 {
			cmd_str = 'PUSH   PSW'
			psw := (utils.bool_byte(state.flags.z) |
				(utils.bool_byte(state.flags.s) << 1) |
				(utils.bool_byte(state.flags.p) << 2) |
				(utils.bool_byte(state.flags.cy) << 3) |
				(utils.bool_byte(state.flags.ac) << 4))
			state.push(state.a, psw)
			cycles_used = 11
		}
		0xf6 {
			cmd_str = 'ORI    #$${state.mem[pc+1]:02x}'
			state.ora(state.a, state.mem[pc + 1])
			state.pc++
			cycles_used = 7
		}
		0xf7 {
			cmd_str = 'RST    6'
			state.call(state.pc, 0x0030)
			cycles_used = 11
		}
		0xf8 {
			cmd_str = 'RM'
			if state.flags.s {
				state.ret()
				cycles_used = 11
			} else {
				cycles_used = 5
			}
		}
		0xf9 {
			cmd_str = 'SPHL'
			state.sp = utils.create_address(state.h, state.l)
			cycles_used = 5
		}
		0xfa {
			cmd_str = 'JM     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.s {
				state.pc = utils.create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				state.pc += 2
			}
			cycles_used = 10
		}
		0xfb {
			cmd_str = 'EI'
			state.interrupt_enabled = true
			cycles_used = 4
		}
		0xfc {
			cmd_str = 'CM     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			if state.flags.s {
				state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
				cycles_used = 17
			} else {
				state.pc += 2
				cycles_used = 11
			}
		}
		0xfd {
			cmd_str = 'CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}'
			state.call(pc + 3, utils.create_address(state.mem[pc + 2], state.mem[pc + 1]))
			cycles_used = 17
		}
		0xfe {
			cmd_str = 'CPI    #$${state.mem[pc+1]:02x}'
			// Throw away the result, we do not store it
			// TODO (vcomp): Interesting V compiler bug, when using the negation
			// operator with the result of the array access it applies the operators
			// in an incorrect ordering.
			_ = state.execute_addition(state.a, -(state.mem[pc + 1]))
			state.pc++
			cycles_used = 7
		}
		0xff {
			cmd_str = 'RST    7'
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
	logger.debug('0x${pc:04x} 0x${state.mem[pc]:02x} $cmd_str $state.str()')
	if cycles_used == 0 {
		return error('got 0 cycles for instruction ${state.mem[pc]:02x}')
	}
	return cycles_used
}
