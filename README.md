# vlang-8080
Intel 8080 emulator written in [V](https://vlang.io/). The emulator passes all Intel 8080 test suites I could find online. Additionally, it includes two hardware emulation modules:
- The `test` module emulates CP/M calls required for running test suites
- The `arcade` module mimics the hardware setup of Space Invaders

## Building
Install the [V compiler](https://vlang.io/), then navigate to this repository's root directory and run:
`v 8080.v`

## Running
Command line arguments are as follows:
```
8080 Emulator v0.0.1
-----------------------------------------------
Usage: 8080 Emulator [options] [ARGS]

Description:
Emulates program execution for a program designed to run on the Intel 8080 CPU. ARGS should be "help" or one or more paths comprising a single Intel 8080 program.

The arguments should be at least 1 in number.

Options:
  --log <string>                Log level, options are: fatal, error, warn, info, debug
  --disassemble <string>        Boots in disassembly mode, which will output human readable instructions at the given filepath, from the given binary, instead of running it.
  --addr <int>                  Start address of the loaded 8080 program in memory; must be >= 0 and < 65535
  --hardware <string>           Type of hardware to run with the 8080, leave empty for the default arcade hardware, use "test" for testing hardware
  --sound-files-dir <string>    Sound file path directory when running arcade hardware, should contain nine .wav files named 0-8
```

Example command to run a fictional test suite `8080CPUTEST.COM` which expects to load into memory starting at memory address 0x100: `8080 --hardware=test --addr=0x100 8080CPUTEST.COM`

## Resources
- http://www.emulator101.com
- https://www.pcjs.org/machines/pcx80/
- https://www.pastraiser.com/cpu/i8080/i8080_opcodes.html
