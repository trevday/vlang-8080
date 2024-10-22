module utils

import time

const (
	u16_max = u16(65535)
)

pub fn bool_byte(b bool) byte {
	if b {
		return 1
	} else {
		return 0
	}
}

pub fn create_address(a, b byte) u16 {
	return (a << 8) | b
}

pub fn break_address(addr u16) (byte, byte) {
	return byte((addr >> 8) & 0xff), byte(addr & 0xff)
}

pub fn parity(x byte) bool {
	// 0
	mut temp := x
	mut p := (temp & 1)
	// 1
	temp = temp >> 1
	p = p ^ (temp & 1)
	// 2
	temp = temp >> 1
	p = p ^ (temp & 1)
	// 3
	temp = temp >> 1
	p = p ^ (temp & 1)
	// 4
	temp = temp >> 1
	p = p ^ (temp & 1)
	// 5
	temp = temp >> 1
	p = p ^ (temp & 1)
	// 6
	temp = temp >> 1
	p = p ^ (temp & 1)
	// 7
	temp = temp >> 1
	p = p ^ (temp & 1)
	return p == 0
}

// TODO (vcomp)
[inline]
pub fn to_micro(t time.Time) u64 {
	return (t.unix * u64(1000000)) + u64(t.microsecond)
}
