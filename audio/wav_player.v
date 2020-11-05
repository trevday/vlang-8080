// Base file taken from https://github.com/vlang/v/blob/master/examples/sokol/sounds/wav_player.v
module audio

import os
import sokol.audio
import sync

pub struct Player {
mut:
	sounds []Sound
	mtx    &sync.Mutex
}

pub fn new_player() &Player {
	mut p := &Player{
		mtx: &sync.Mutex{}
	}
	p.init()
	return p
}

fn (mut p Player) init() {
	audio.setup({
		num_channels: 2
		stream_userdata_cb: audio_player_callback
		user_data: p
	})
}

fn (mut p Player) shutdown() {
	audio.shutdown()
	p.sounds.clear()
}

pub fn (mut p Player) load(file string) ?int {
	if !os.exists(file) || os.is_dir(file) {
		return error('sound file "$file" does not exist')
	}
	fext := os.file_ext(file).to_lower()
	if fext != '.wav' {
		return error('sound file "$file" is not a .wav file')
	}
	mut sound := Sound{}
	samples := read_wav_file_samples(file)?
	sound.samples << samples
	sound.reset()
	sound.repeats = false
	p.mtx.m_lock()
	p.sounds << sound
	idx := p.sounds.len - 1
	p.mtx.unlock()
	return idx
}

pub fn (mut p Player) play(idx int, repeats bool) ? {
	p.mtx.m_lock()
	if idx < 0 || idx >= p.sounds.len {
		return error('given invalid sound index $idx')
	}
	p.sounds[idx].finished = false
	p.sounds[idx].repeats = repeats
	p.mtx.unlock()
}

pub fn (mut p Player) stop(idx int) ? {
	p.mtx.m_lock()
	if idx < 0 || idx >= p.sounds.len {
		return error('given invalid sound index $idx')
	}
	p.sounds[idx].reset()
	p.mtx.unlock()
}

fn audio_player_callback(mut buffer &f32, num_frames, num_channels int, mut p Player) {
	p.mtx.m_lock()
	ntotal := num_channels * num_frames
	unsafe {
		// Zero out buffer before filling it
		C.memset(buffer, 0, ntotal * int(sizeof(f32)))
	}
	for s in 0 .. p.sounds.len {
		if p.sounds[s].finished {
			continue
		}
		mut nsamples := p.sounds[s].calc_samples(ntotal)
		if nsamples <= 0 {
			p.sounds[s].reset()
			if p.sounds[s].repeats {
				// If it repeats, start it again after reset
				nsamples = p.sounds[s].calc_samples(ntotal)
				p.sounds[s].finished = false
			} else {
				continue
			}
		}
		for i in 0 .. nsamples {
			unsafe {
				buffer[i] = buffer[i] + p.sounds[s].samples[p.sounds[s].pos + i]
			}
		}
		p.sounds[s].pos += nsamples
	}
	p.mtx.unlock()
}

struct Sound {
mut:
	samples  []f32
	pos      int
	finished bool
	repeats  bool
}

fn (s &Sound) calc_samples(max int) int {
	nremaining := s.samples.len - s.pos
	if nremaining < max {
		return nremaining
	} else {
		return max
	}
}

fn (mut s Sound) reset() {
	s.finished = true
	s.pos = 0
}

// The read_wav_file_samples function below is based on the following sources:
// http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html
// http://www.lightlink.com/tjweber/StripWav/WAVE.html
// http://www.lightlink.com/tjweber/StripWav/Canon.html
// https://tools.ietf.org/html/draft-ema-vpim-wav-00
// NB: > The chunks MAY appear in any order except that the Format chunk
// > MUST be placed before the Sound data chunk (but not necessarily
// > contiguous to the Sound data chunk).
struct RIFFHeader {
	riff      [4]byte
	file_size u32
	form_type [4]byte
}

struct RIFFChunkHeader {
	chunk_type [4]byte
	chunk_size u32
	chunk_data voidptr
}

struct RIFFFormat {
	format_tag            u16 // PCM = 1; Values other than 1 indicate some form of compression.
	nchannels             u16 // Nc ; 1 = mono ; 2 = stereo
	sample_rate           u32 // F
	avg_bytes_per_second  u32 // F * M*Nc
	nblock_align          u16 // M*Nc
	bits_per_sample       u16 // 8 * M
	cbsize                u16 // Size of the extension: 22
	valid_bits_per_sample u16 // at most 8*M
	channel_mask          u32 // Speaker position mask
	sub_format            [16]byte // GUID
}

fn read_wav_file_samples(fpath string) ?[]f32 {
	mut res := []f32{}
	// eprintln('> read_wav_file_samples: $fpath -------------------------------------------------')
	mut bytes := os.read_bytes(fpath)?
	mut pbytes := byteptr(bytes.data)
	mut offset := u32(0)
	rh := &RIFFHeader(pbytes)
	// eprintln('rh: $rh')
	if rh.riff[0] != byte(`R`) ||
		rh.riff[1] != byte(`I`) || rh.riff[2] != byte(`F`) || rh.riff[3] != byte(`F`) {
		return error('WAV should start with `RIFF`')
	}
	if rh.form_type[0] != byte(`W`) ||
		rh.form_type[1] != byte(`A`) || rh.form_type[2] != byte(`V`) || rh.form_type[3] != byte(`E`) {
		return error('WAV should have `WAVE` form type')
	}
	if rh.file_size + 8 != bytes.len {
		return error('WAV should have valid lenght')
	}
	offset += sizeof(RIFFHeader)
	mut rf := &RIFFFormat(0)
	for {
		if offset >= bytes.len {
			break
		}
		//
		ch := &RIFFChunkHeader(unsafe {pbytes + offset})
		offset += 8 + ch.chunk_size
		// eprintln('ch: $ch')
		// eprintln('p: $pbytes | offset: $offset | bytes.len: $bytes.len')
		// ////////
		if ch.chunk_type[0] == byte(`L`) &&
			ch.chunk_type[1] == byte(`I`) && ch.chunk_type[2] == byte(`S`) && ch.chunk_type[3] == byte(`T`) {
			continue
		}
		//
		if ch.chunk_type[0] == byte(`i`) &&
			ch.chunk_type[1] == byte(`d`) && ch.chunk_type[2] == byte(`3`) && ch.chunk_type[3] == byte(` `) {
			continue
		}
		//
		if ch.chunk_type[0] == byte(`f`) &&
			ch.chunk_type[1] == byte(`m`) && ch.chunk_type[2] == byte(`t`) && ch.chunk_type[3] == byte(` `) {
			// eprintln('`fmt ` chunk')
			rf = &RIFFFormat(&ch.chunk_data)
			// eprintln('fmt riff format: $rf')
			if rf.format_tag != 1 {
				return error('only PCM encoded WAVs are supported')
			}
			if rf.nchannels < 1 || rf.nchannels > 2 {
				return error('only mono or stereo WAVs are supported')
			}
			if rf.bits_per_sample !in [u16(8), 16] {
				return error('only 8 or 16 bits per sample WAVs are supported')
			}
			continue
		}
		//
		if ch.chunk_type[0] == byte(`d`) &&
			ch.chunk_type[1] == byte(`a`) && ch.chunk_type[2] == byte(`t`) && ch.chunk_type[3] == byte(`a`) {
			if rf == 0 {
				return error('`data` chunk should be after `fmt ` chunk')
			}
			// eprintln('`fmt ` chunk: $rf\n`data` chunk: $ch')
			mut doffset := 0
			mut dp := byteptr(&ch.chunk_data)
			for doffset < ch.chunk_size {
				for c := 0; c < rf.nchannels; c++ {
					mut x := f32(0.0)
					mut step := 0
					ppos := unsafe {dp + doffset}
					if rf.bits_per_sample == 8 {
						d8 := byteptr(ppos)
						x = (f32(*d8) - 128) / 128.0
						step = 1
						doffset++
					}
					if rf.bits_per_sample == 16 {
						d16 := &i16(ppos)
						x = f32(*d16) / 32768.0
						step = 2
					}
					doffset += step
					if doffset < ch.chunk_size {
						res << x
						if rf.nchannels == 1 {
							// Duplicating single channel mono sounds,
							// produces a stereo sound, simplifying further processing:
							res << x
						}
					}
				}
			}
		}
	}
	return res
}
