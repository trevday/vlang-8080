module core

import log

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
	// TODO: Unused so far
	ac bool
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
	interrupt_enabled byte
}

pub fn new(program &[]byte) State {
	mut state := State{
		mem: []byte{len: 0xffff, init: 0}
	}
	// Copy program to $0x0000
	for i, b in program {
		state.mem[i] = b
	}
	return state
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

fn (mut state State) execute_addition(a, b byte) {
	answer := u16(a) + u16(b)
	// Only use the bottom 8 bits of the answer, carryover
	// is handled by flags (cy)
	truncated := byte(answer & 0xff)
	state.flags.z = (truncated == 0)
	// Set Sign (s) flag is MSB is set
	state.flags.s = ((answer & 0x80) != 0)
	state.flags.cy = (answer > 0xff)
	state.flags.p = parity(truncated)
	state.a = truncated
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

// TODO: Better separation of logging for debug and functionality;
// Split out debug logging into the disassembly function? Be able to
// run disassembler as an independent program, without emulation.
// Clean up this giant if statement.
pub fn (mut state State) emulate(mut logger log.Log) ? {
	// Cache the pc before incrementing it
	pc := state.pc
	state.pc++
	logger.debug('Executing ${state.mem[pc]:02x}')
	match state.mem[pc] {
		0x00 {
			logger.debug('NOP')
			// NOP
		}
		0x01 {
			logger.debug('LXI    B,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x02 {
			logger.debug('STAX   B')
			return error('unimplemented')
		}
		0x03 {
			logger.debug('INX    B')
			return error('unimplemented')
		}
		0x04 {
			logger.debug('INR    B')
			return error('unimplemented')
		}
		0x05 {
			logger.debug('DCR    B')
			return error('unimplemented')
		}
		0x06 {
			logger.debug('MVI    B,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x07 {
			logger.debug('RLC')
			return error('unimplemented')
		}
		0x08 {
			logger.debug('NOP')
			// NOP
		}
		0x09 {
			logger.debug('DAD    B')
			return error('unimplemented')
		}
		0x0a {
			logger.debug('LDAX   B')
			return error('unimplemented')
		}
		0x0b {
			logger.debug('DCX    B')
			return error('unimplemented')
		}
		0x0c {
			logger.debug('INR    C')
			return error('unimplemented')
		}
		0x0d {
			logger.debug('DCR    C')
			return error('unimplemented')
		}
		0x0e {
			logger.debug('MVI    C,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x0f {
			logger.debug('RRC')
			temp := state.a
			state.a = ((temp & 1) << 7) | (temp >> 1)
			// Set carryover if the bit that wraps around
			// is 1
			state.flags.cy = ((temp & 1) == 1)
		}
		0x10 {
			logger.debug('NOP')
			// NOP
		}
		0x11 {
			logger.debug('LXI    D,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x12 {
			logger.debug('STAX   D')
			return error('unimplemented')
		}
		0x13 {
			logger.debug('INX    D')
			return error('unimplemented')
		}
		0x14 {
			logger.debug('INR    D')
			return error('unimplemented')
		}
		0x15 {
			logger.debug('DCR    D')
			return error('unimplemented')
		}
		0x16 {
			logger.debug('MVI    D,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x17 {
			logger.debug('RAL')
			return error('unimplemented')
		}
		0x18 {
			logger.debug('NOP')
			// NOP
		}
		0x19 {
			logger.debug('DAD    D')
			return error('unimplemented')
		}
		0x1a {
			logger.debug('LDAX   D')
			return error('unimplemented')
		}
		0x1b {
			logger.debug('DCX    D')
			return error('unimplemented')
		}
		0x1c {
			logger.debug('INR    E')
			return error('unimplemented')
		}
		0x1d {
			logger.debug('DCR    E')
			return error('unimplemented')
		}
		0x1e {
			logger.debug('MVI    E,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x1f {
			logger.debug('RAR')
			temp := state.a
			state.a = (bool_byte(state.flags.cy) << 7) | (temp >> 1)
			// We use the carryover flag as the wrapping bit here,
			// but still set carryover based on whether there would
			// have been a wrapping bit of 1
			state.flags.cy = ((temp & 1) == 1)
		}
		0x20 {
			logger.debug('NOP')
			// NOP
		}
		0x21 {
			logger.debug('LXI    H,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x22 {
			logger.debug('SHLD   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x23 {
			logger.debug('INX    H')
			return error('unimplemented')
		}
		0x24 {
			logger.debug('INR    H')
			return error('unimplemented')
		}
		0x25 {
			logger.debug('DCR    H')
			return error('unimplemented')
		}
		0x26 {
			logger.debug('MVI    H,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x27 {
			logger.debug('DAA')
			return error('unimplemented')
		}
		0x28 {
			logger.debug('NOP')
			// NOP
		}
		0x29 {
			logger.debug('DAD    H')
			return error('unimplemented')
		}
		0x2a {
			logger.debug('LHLD   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x2b {
			logger.debug('DCX    H')
			return error('unimplemented')
		}
		0x2c {
			logger.debug('INR    L')
			return error('unimplemented')
		}
		0x2d {
			logger.debug('DCR    L')
			return error('unimplemented')
		}
		0x2e {
			logger.debug('MVI    L,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x2f {
			logger.debug('CMA')
			state.a = ~state.a
		}
		0x30 {
			logger.debug('NOP')
			// NOP
		}
		0x31 {
			logger.debug('LXI    SP,#$${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.sp = create_address(state.mem[pc + 2], state.mem[pc + 1])
			state.pc += 2
		}
		0x32 {
			logger.debug('STA    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x33 {
			logger.debug('INX    SP')
			return error('unimplemented')
		}
		0x34 {
			logger.debug('INR    M')
			return error('unimplemented')
		}
		0x35 {
			logger.debug('DCR    M')
			return error('unimplemented')
		}
		0x36 {
			logger.debug('MVI    M,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x37 {
			logger.debug('STC')
			return error('unimplemented')
		}
		0x38 {
			logger.debug('NOP')
			// NOP
		}
		0x39 {
			logger.debug('DAD    SP')
			return error('unimplemented')
		}
		0x3a {
			logger.debug('LDA    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0x3b {
			logger.debug('DCX    SP')
			return error('unimplemented')
		}
		0x3c {
			logger.debug('INR    A')
			return error('unimplemented')
		}
		0x3d {
			logger.debug('DCR    A')
			return error('unimplemented')
		}
		0x3e {
			logger.debug('MVI    A,#$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0x3f {
			logger.debug('CMC')
			return error('unimplemented')
		}
		0x40 {
			logger.debug('MOV    B,B')
			return error('unimplemented')
		}
		0x41 {
			logger.debug('MOV    B,C')
			return error('unimplemented')
		}
		0x42 {
			logger.debug('MOV    B,D')
			return error('unimplemented')
		}
		0x43 {
			logger.debug('MOV    B,E')
			return error('unimplemented')
		}
		0x44 {
			logger.debug('MOV    B,H')
			return error('unimplemented')
		}
		0x45 {
			logger.debug('MOV    B,L')
			return error('unimplemented')
		}
		0x46 {
			logger.debug('MOV    B,M')
			return error('unimplemented')
		}
		0x47 {
			logger.debug('MOV    B,A')
			return error('unimplemented')
		}
		0x48 {
			logger.debug('MOV    C,B')
			return error('unimplemented')
		}
		0x49 {
			logger.debug('MOV    C,C')
			return error('unimplemented')
		}
		0x4a {
			logger.debug('MOV    C,D')
			return error('unimplemented')
		}
		0x4b {
			logger.debug('MOV    C,E')
			return error('unimplemented')
		}
		0x4c {
			logger.debug('MOV    C,H')
			return error('unimplemented')
		}
		0x4d {
			logger.debug('MOV    C,L')
			return error('unimplemented')
		}
		0x4e {
			logger.debug('MOV    C,M')
			return error('unimplemented')
		}
		0x4f {
			logger.debug('MOV    C,A')
			return error('unimplemented')
		}
		0x50 {
			logger.debug('MOV    D,B')
			return error('unimplemented')
		}
		0x51 {
			logger.debug('MOV    D,C')
			return error('unimplemented')
		}
		0x52 {
			logger.debug('MOV    D,D')
			return error('unimplemented')
		}
		0x53 {
			logger.debug('MOV    D.E')
			return error('unimplemented')
		}
		0x54 {
			logger.debug('MOV    D,H')
			return error('unimplemented')
		}
		0x55 {
			logger.debug('MOV    D,L')
			return error('unimplemented')
		}
		0x56 {
			logger.debug('MOV    D,M')
			return error('unimplemented')
		}
		0x57 {
			logger.debug('MOV    D,A')
			return error('unimplemented')
		}
		0x58 {
			logger.debug('MOV    E,B')
			return error('unimplemented')
		}
		0x59 {
			logger.debug('MOV    E,C')
			return error('unimplemented')
		}
		0x5a {
			logger.debug('MOV    E,D')
			return error('unimplemented')
		}
		0x5b {
			logger.debug('MOV    E,E')
			return error('unimplemented')
		}
		0x5c {
			logger.debug('MOV    E,H')
			return error('unimplemented')
		}
		0x5d {
			logger.debug('MOV    E,L')
			return error('unimplemented')
		}
		0x5e {
			logger.debug('MOV    E,M')
			return error('unimplemented')
		}
		0x5f {
			logger.debug('MOV    E,A')
			return error('unimplemented')
		}
		0x60 {
			logger.debug('MOV    H,B')
			return error('unimplemented')
		}
		0x61 {
			logger.debug('MOV    H,C')
			return error('unimplemented')
		}
		0x62 {
			logger.debug('MOV    H,D')
			return error('unimplemented')
		}
		0x63 {
			logger.debug('MOV    H.E')
			return error('unimplemented')
		}
		0x64 {
			logger.debug('MOV    H,H')
			return error('unimplemented')
		}
		0x65 {
			logger.debug('MOV    H,L')
			return error('unimplemented')
		}
		0x66 {
			logger.debug('MOV    H,M')
			return error('unimplemented')
		}
		0x67 {
			logger.debug('MOV    H,A')
			return error('unimplemented')
		}
		0x68 {
			logger.debug('MOV    L,B')
			return error('unimplemented')
		}
		0x69 {
			logger.debug('MOV    L,C')
			return error('unimplemented')
		}
		0x6a {
			logger.debug('MOV    L,D')
			return error('unimplemented')
		}
		0x6b {
			logger.debug('MOV    L,E')
			return error('unimplemented')
		}
		0x6c {
			logger.debug('MOV    L,H')
			return error('unimplemented')
		}
		0x6d {
			logger.debug('MOV    L,L')
			return error('unimplemented')
		}
		0x6e {
			logger.debug('MOV    L,M')
			return error('unimplemented')
		}
		0x6f {
			logger.debug('MOV    L,A')
			return error('unimplemented')
		}
		0x70 {
			logger.debug('MOV    M,B')
			return error('unimplemented')
		}
		0x71 {
			logger.debug('MOV    M,C')
			return error('unimplemented')
		}
		0x72 {
			logger.debug('MOV    M,D')
			return error('unimplemented')
		}
		0x73 {
			logger.debug('MOV    M.E')
			return error('unimplemented')
		}
		0x74 {
			logger.debug('MOV    M,H')
			return error('unimplemented')
		}
		0x75 {
			logger.debug('MOV    M,L')
			return error('unimplemented')
		}
		0x76 {
			logger.debug('HLT')
			return error('unimplemented')
		}
		0x77 {
			logger.debug('MOV    M,A')
			return error('unimplemented')
		}
		0x78 {
			logger.debug('MOV    A,B')
			return error('unimplemented')
		}
		0x79 {
			logger.debug('MOV    A,C')
			return error('unimplemented')
		}
		0x7a {
			logger.debug('MOV    A,D')
			return error('unimplemented')
		}
		0x7b {
			logger.debug('MOV    A,E')
			return error('unimplemented')
		}
		0x7c {
			logger.debug('MOV    A,H')
			return error('unimplemented')
		}
		0x7d {
			logger.debug('MOV    A,L')
			return error('unimplemented')
		}
		0x7e {
			logger.debug('MOV    A,M')
			return error('unimplemented')
		}
		0x7f {
			logger.debug('MOV    A,A')
			return error('unimplemented')
		}
		0x80 {
			logger.debug('ADD    B')
			state.execute_addition(state.a, state.b)
		}
		0x81 {
			logger.debug('ADD    C')
			state.execute_addition(state.a, state.c)
		}
		0x82 {
			logger.debug('ADD    D')
			state.execute_addition(state.a, state.d)
		}
		0x83 {
			logger.debug('ADD    E')
			state.execute_addition(state.a, state.e)
		}
		0x84 {
			logger.debug('ADD    H')
			state.execute_addition(state.a, state.h)
		}
		0x85 {
			logger.debug('ADD    L')
			state.execute_addition(state.a, state.l)
		}
		0x86 {
			logger.debug('ADD    M')
			offset := create_address(state.h, state.l)
			state.execute_addition(state.a, state.mem[offset])
		}
		0x87 {
			logger.debug('ADD    A')
			state.execute_addition(state.a, state.a)
		}
		0x88 {
			logger.debug('ADC    B')
			return error('unimplemented')
		}
		0x89 {
			logger.debug('ADC    C')
			return error('unimplemented')
		}
		0x8a {
			logger.debug('ADC    D')
			return error('unimplemented')
		}
		0x8b {
			logger.debug('ADC    E')
			return error('unimplemented')
		}
		0x8c {
			logger.debug('ADC    H')
			return error('unimplemented')
		}
		0x8d {
			logger.debug('ADC    L')
			return error('unimplemented')
		}
		0x8e {
			logger.debug('ADC    M')
			return error('unimplemented')
		}
		0x8f {
			logger.debug('ADC    A')
			return error('unimplemented')
		}
		0x90 {
			logger.debug('SUB    B')
			return error('unimplemented')
		}
		0x91 {
			logger.debug('SUB    C')
			return error('unimplemented')
		}
		0x92 {
			logger.debug('SUB    D')
			return error('unimplemented')
		}
		0x93 {
			logger.debug('SUB    E')
			return error('unimplemented')
		}
		0x94 {
			logger.debug('SUB    H')
			return error('unimplemented')
		}
		0x95 {
			logger.debug('SUB    L')
			return error('unimplemented')
		}
		0x96 {
			logger.debug('SUB    M')
			return error('unimplemented')
		}
		0x97 {
			logger.debug('SUB    A')
			return error('unimplemented')
		}
		0x98 {
			logger.debug('SBB    B')
			return error('unimplemented')
		}
		0x99 {
			logger.debug('SBB    C')
			return error('unimplemented')
		}
		0x9a {
			logger.debug('SBB    D')
			return error('unimplemented')
		}
		0x9b {
			logger.debug('SBB    E')
			return error('unimplemented')
		}
		0x9c {
			logger.debug('SBB    H')
			return error('unimplemented')
		}
		0x9d {
			logger.debug('SBB    L')
			return error('unimplemented')
		}
		0x9e {
			logger.debug('SBB    M')
			return error('unimplemented')
		}
		0x9f {
			logger.debug('SBB    A')
			return error('unimplemented')
		}
		0xa0 {
			logger.debug('ANA    B')
			return error('unimplemented')
		}
		0xa1 {
			logger.debug('ANA    C')
			return error('unimplemented')
		}
		0xa2 {
			logger.debug('ANA    D')
			return error('unimplemented')
		}
		0xa3 {
			logger.debug('ANA    E')
			return error('unimplemented')
		}
		0xa4 {
			logger.debug('ANA    H')
			return error('unimplemented')
		}
		0xa5 {
			logger.debug('ANA    L')
			return error('unimplemented')
		}
		0xa6 {
			logger.debug('ANA    M')
			return error('unimplemented')
		}
		0xa7 {
			logger.debug('ANA    A')
			return error('unimplemented')
		}
		0xa8 {
			logger.debug('XRA    B')
			return error('unimplemented')
		}
		0xa9 {
			logger.debug('XRA    C')
			return error('unimplemented')
		}
		0xaa {
			logger.debug('XRA    D')
			return error('unimplemented')
		}
		0xab {
			logger.debug('XRA    E')
			return error('unimplemented')
		}
		0xac {
			logger.debug('XRA    H')
			return error('unimplemented')
		}
		0xad {
			logger.debug('XRA    L')
			return error('unimplemented')
		}
		0xae {
			logger.debug('XRA    M')
			return error('unimplemented')
		}
		0xaf {
			logger.debug('XRA    A')
			return error('unimplemented')
		}
		0xb0 {
			logger.debug('ORA    B')
			return error('unimplemented')
		}
		0xb1 {
			logger.debug('ORA    C')
			return error('unimplemented')
		}
		0xb2 {
			logger.debug('ORA    D')
			return error('unimplemented')
		}
		0xb3 {
			logger.debug('ORA    E')
			return error('unimplemented')
		}
		0xb4 {
			logger.debug('ORA    H')
			return error('unimplemented')
		}
		0xb5 {
			logger.debug('ORA    L')
			return error('unimplemented')
		}
		0xb6 {
			logger.debug('ORA    M')
			return error('unimplemented')
		}
		0xb7 {
			logger.debug('ORA    A')
			return error('unimplemented')
		}
		0xb8 {
			logger.debug('CMP    B')
			return error('unimplemented')
		}
		0xb9 {
			logger.debug('CMP    C')
			return error('unimplemented')
		}
		0xba {
			logger.debug('CMP    D')
			return error('unimplemented')
		}
		0xbb {
			logger.debug('CMP    E')
			return error('unimplemented')
		}
		0xbc {
			logger.debug('CMP    H')
			return error('unimplemented')
		}
		0xbd {
			logger.debug('CMP    L')
			return error('unimplemented')
		}
		0xbe {
			logger.debug('CMP    M')
			return error('unimplemented')
		}
		0xbf {
			logger.debug('CMP    A')
			return error('unimplemented')
		}
		0xc0 {
			logger.debug('RNZ')
			return error('unimplemented')
		}
		0xc1 {
			logger.debug('POP    B')
			c, b := state.pop()
			state.b = b
			state.c = c
		}
		0xc2 {
			logger.debug('JNZ    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			if !state.flags.z {
				state.pc = create_address(state.mem[pc + 2], state.mem[pc + 1])
			} else {
				// Skip following address if we did not jump
				state.pc += 2
			}
		}
		0xc3 {
			logger.debug('JMP    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			state.pc = create_address(state.mem[pc + 2], state.mem[pc + 1])
			// TODO: is it bad that pc still gets incremented at end after jmp?
		}
		0xc4 {
			logger.debug('CNZ    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xc5 {
			logger.debug('PUSH   B')
			state.push(state.b, state.c)
		}
		0xc6 {
			logger.debug('ADI    #$${state.mem[pc+1]:02x}')
			state.execute_addition(state.a, state.mem[pc + 1])
			state.pc++
		}
		0xc7 {
			logger.debug('RST    0')
			return error('unimplemented')
		}
		0xc8 {
			logger.debug('RZ')
			return error('unimplemented')
		}
		0xc9 {
			logger.debug('RET')
			right, left := state.pop()
			state.pc = create_address(left, right)
		}
		0xca {
			logger.debug('JZ     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xcb {
			logger.debug('JMP    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xcc {
			logger.debug('CZ     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xcd {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			return_addr := pc + 2
			// left half
			state.push(byte((return_addr >> 8) & 0xff), byte((return_addr & 0xff))) // right half
			// Jump after storing return address on stack
			state.pc = create_address(state.mem[pc + 2], state.mem[pc + 1])
		}
		0xce {
			logger.debug('ACI    #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xcf {
			logger.debug('RST    1')
			return error('unimplemented')
		}
		0xd0 {
			logger.debug('RNC')
			return error('unimplemented')
		}
		0xd1 {
			logger.debug('POP    D')
			return error('unimplemented')
		}
		0xd2 {
			logger.debug('JNC    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xd3 {
			logger.debug('OUT    #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xd4 {
			logger.debug('CNC    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xd5 {
			logger.debug('PUSH   D')
			return error('unimplemented')
		}
		0xd6 {
			logger.debug('SUI    #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xd7 {
			logger.debug('RST    2')
			return error('unimplemented')
		}
		0xd8 {
			logger.debug('RC')
			return error('unimplemented')
		}
		0xd9 {
			logger.debug('RET')
			return error('unimplemented')
		}
		0xda {
			logger.debug('JC     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xdb {
			logger.debug('IN     #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xdc {
			logger.debug('CC     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xdd {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xde {
			logger.debug('SBI    #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xdf {
			logger.debug('RST    3')
			return error('unimplemented')
		}
		0xe0 {
			logger.debug('RPO')
			return error('unimplemented')
		}
		0xe1 {
			logger.debug('POP    H')
			return error('unimplemented')
		}
		0xe2 {
			logger.debug('JPO    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xe3 {
			logger.debug('XTHL')
			return error('unimplemented')
		}
		0xe4 {
			logger.debug('CPO    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xe5 {
			logger.debug('PUSH   H')
			return error('unimplemented')
		}
		0xe6 {
			logger.debug('ANI    #$${state.mem[pc+1]:02x}')
			// AND Immediate
			answer := state.a & state.mem[pc + 1]
			// TODO: Reduce code duplication with addition
			state.flags.z = (answer == 0)
			state.flags.s = ((answer & 0x80) != 0)
			state.flags.p = parity(answer)
			state.flags.cy = false // Clear the carryover flag
			state.a = answer
			state.pc++ // Advance one for immediate byte
		}
		0xe7 {
			logger.debug('RST    4')
			return error('unimplemented')
		}
		0xe8 {
			logger.debug('RPE')
			return error('unimplemented')
		}
		0xe9 {
			logger.debug('PCHL')
			return error('unimplemented')
		}
		0xea {
			logger.debug('JPE    $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xeb {
			logger.debug('XCHG')
			return error('unimplemented')
		}
		0xec {
			logger.debug('CPE     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xed {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xee {
			logger.debug('XRI    #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xef {
			logger.debug('RST    5')
			return error('unimplemented')
		}
		0xf0 {
			logger.debug('RP')
			return error('unimplemented')
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
		}
		0xf2 {
			logger.debug('JP     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xf3 {
			logger.debug('DI')
			return error('unimplemented')
		}
		0xf4 {
			logger.debug('CP     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xf5 {
			logger.debug('PUSH   PSW')
			psw := (bool_byte(state.flags.z) |
				(bool_byte(state.flags.s) << 1) | (bool_byte(state.flags.p) << 2) |
				(bool_byte(state.flags.cy) << 3) |
				(bool_byte(state.flags.ac) << 4))
			state.push(state.a, psw)
		}
		0xf6 {
			logger.debug('ORI    #$${state.mem[pc+1]:02x}')
			// num_bytes = 2
			return error('unimplemented')
		}
		0xf7 {
			logger.debug('RST    6')
			return error('unimplemented')
		}
		0xf8 {
			logger.debug('RM')
			return error('unimplemented')
		}
		0xf9 {
			logger.debug('SPHL')
			return error('unimplemented')
		}
		0xfa {
			logger.debug('JM     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xfb {
			logger.debug('EI')
			return error('unimplemented')
		}
		0xfc {
			logger.debug('CM     $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xfd {
			logger.debug('CALL   $${state.mem[pc+2]:02x}${state.mem[pc+1]:02x}')
			// num_bytes = 3
			return error('unimplemented')
		}
		0xfe {
			logger.debug('CPI    #$${state.mem[pc+1]:02x}')
			answer := state.a - state.mem[pc + 1]
			// TODO: reduce code duplication with addition
			state.flags.z = (answer == 0)
			state.flags.s = ((answer & 0x80) != 0)
			state.flags.p = parity(answer)
			// Wraparound (carryover) if the first element is less than
			// the second
			state.flags.cy = (state.a < state.mem[pc + 1])
			// Add 1 to PC for immediate byte
			state.pc++
		}
		0xff {
			logger.debug('RST    7')
			return error('unimplemented')
		}
		else {
			return error('unknown opcode: ${state.mem[pc]}')
		}
	}
	// NOTE: The use of '.str()' here seems to be a bug with the V compiler;
	// It can't figure out to use the pointer variant of the State struct
	// when calling the string function automatically while interpolating,
	// so a manual usage fixes that for now.
	logger.debug('8080 State:\n$state.str()')
	return none
}
