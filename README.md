# Chip-8 Emulator

A interpreter for the [chip-8](https://en.wikipedia.org/wiki/CHIP-8) programming language, written in [zig](https://ziglang.org/).

## Installation & Running Locally

**Building:**

You will need:

* A latest copy of the zig compiler, built from master.
* The SDL2 library.

Note: the `build.zig` currently is designed for macOS & homebrew.  If you have
SDL2 installed to a different path, make sure you adjust your include path when
invoking the compiler accordingly.

**Playing a Game**

```shell
zig build run -- games/<game>
```

## Authors

* Michael Helvey <michael.helvey1@gmail.com>

## License

MIT
