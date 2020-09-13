module core

fn bool_byte(b bool) byte {
	if b {
		return 1
	} else {
		return 0
	}
}

fn create_address(a, b byte) u16 {
	return (a << 8) | b
}

fn parity(x int) bool {
	mut temp := x ^ (x >> 1)
	temp = temp ^ (temp >> 2)
	temp = temp ^ (temp >> 4)
	temp = temp ^ (temp >> 8)
	temp = temp ^ (temp >> 16)
	return ((temp & 1) == 1)
}
