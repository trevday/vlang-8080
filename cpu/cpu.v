module cpu

import log
import utils

pub const (
	max_memory = 0x10000
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
	// TODO: I think the ac flag is sort of broken after
	// subtraction operations, but it works well enough
	// for my goals at the moment
	ac bool
}

pub interface Machine {
	op_in(port byte) ?byte
	op_out(port, val byte) ?
}

pub struct State {
pub mut:
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

pub fn new(program &[]byte, start_addr u16, machine &Machine) &State {
	mut state := &State{
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

pub fn (mut state State) edit_mem(addr u16, val byte) ? {
	if addr > state.mem.len - 1 {
		return error('out of bounds editing cpu memory at ${addr:04x}')
	}
	state.mem[addr] = val
}

fn (state &State) str() string {
	return 'a: 0x${state.a:02x} b: 0x${state.b:02x} c: 0x${state.c:02x} d: 0x${state.d:02x} ' +
		'e: 0x${state.e:02x} h: 0x${state.h:02x} l: 0x${state.l:02x} ' + 'sp: 0x${state.sp:04x} pc: 0x${state.pc:04x} ' +
		'z: $state.flags.z s: $state.flags.s p: $state.flags.p cy: $state.flags.cy ac: $state.flags.ac'
}

// NOTE: cy and ac are not set here because different instructions
// affect the carryover in different ways, but nearly all
// affect the other flags in the same way.
fn (mut state State) set_flags(x byte) {
	state.flags.z = (x == 0)
	// Set Sign (s) flag if MSB is set
	state.flags.s = ((x & 0x80) != 0)
	state.flags.p = utils.parity(x)
}

fn (mut state State) execute_addition(x1, x2 byte, cy bool) byte {
	answer := u16(x1) + u16(x2) + u16(utils.bool_byte(cy))
	// Only use the bottom 8 bits of the answer, carryover
	// is handled by flags (cy)
	truncated := byte(answer & 0xff)
	state.set_flags(truncated)
	state.flags.cy = (answer > 0xff)
	state.flags.ac = ((x1 & 0xf) + (x2 & 0xf) + utils.bool_byte(cy) > 0xf)
	return truncated
}

fn (mut state State) execute_subtraction(x1, x2 byte, cy bool) byte {
	res := state.execute_addition(x1, ~x2, !cy)
	state.flags.cy = !state.flags.cy
	return res
}

fn (mut state State) execute_addition_and_store(x1, x2 byte) {
	state.a = state.execute_addition(x1, x2, false)
}

fn (mut state State) execute_subtraction_and_store(x1, x2 byte) {
	// True because if carry is not taken into account it is always
	// inverted during subtraction
	state.a = state.execute_subtraction(x1, x2, false)
}

fn (mut state State) inr(x1 byte) byte {
	res := x1 + 1
	state.set_flags(res)
	state.flags.ac = (res & 0xf) == 0x0
	return res
}

fn (mut state State) dcr(x1 byte) byte {
	res := x1 - 1
	state.set_flags(res)
	state.flags.ac = (res & 0xf) != 0xf
	return res
}

fn (mut state State) adc(x1, x2 byte) {
	state.a = state.execute_addition(x1, x2, state.flags.cy)
}

fn (mut state State) sbb(x1, x2 byte) {
	state.a = state.execute_subtraction(x1, x2, state.flags.cy)
}

fn (mut state State) cmp(x1, x2 byte) {
	state.execute_addition(x1, ~x2, true)
	state.flags.cy = x1 < x2
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
	state.mem[u16(state.sp + 1)] = x1
	state.mem[state.sp] = x2
}

// Pops x2 and then x1 off the stack
fn (mut state State) pop() (byte, byte) {
	state.sp += 2
	return state.mem[u16(state.sp - 2)], state.mem[u16(state.sp - 1)]
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

pub fn (mut state State) step(mut logger log.Log) ?u32 {
	instruction_attrs := get_attributes(state.mem[state.pc])?
	// TODO (vcomp): The use of '.str()' here seems to be a bug with the V compiler;
	// It can't figure out to use the pointer variant of the State struct
	// when calling the string function automatically while interpolating,
	// so a manual usage fixes that for now.
	$if debug {
		debug_out := instruction_attrs.debug(state.mem, state.pc)
		logger.debug('0x${state.pc:04x} 0x${state.mem[state.pc]:02x} $debug_out.instr_string $state.str()')
	}
	exec_result := instruction_attrs.execute(state)?
	if exec_result.bytes_used == utils.u16_max {
		return error('bytes used not set for instruction ${state.mem[state.pc]:02x}')
	}
	if exec_result.cycles_used == 0 {
		return error('got 0 cycles for instruction ${state.mem[state.pc]:02x}')
	}
	state.pc += exec_result.bytes_used
	return exec_result.cycles_used
}

pub fn disassemble(source_bytes []byte) ?string {
	mut output := ''
	mut i := 0
	for i < source_bytes.len {
		instruction_attrs := get_attributes(source_bytes[i])?
		debug_out := instruction_attrs.debug(source_bytes, i)
		output += '${i:04x} $debug_out.instr_string\n'
		if debug_out.instr_bytes == 0 {
			return error('instruction debug bytes not set for ${source_bytes[i]:02x}')
		}
		i += debug_out.instr_bytes
	}
	return output
}
