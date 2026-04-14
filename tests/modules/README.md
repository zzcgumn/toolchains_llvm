# C++ Modules Example

This directory contains a minimal example of C++20 named modules built with
Bazel's experimental C++ module support and `toolchains_llvm`.

## Files

- `hello.cppm` — A C++20 module interface unit exporting the `hello` namespace.
- `main.cc` — A binary that imports the `hello` module and calls it.
- `BUILD.bazel` — Build targets using `module_interfaces` (requires `rules_cc ≥ 0.2`).

## Building

C++ module support requires three opt-ins:

1. **A toolchain with `enable_cpp_modules = True`** — declared as
   `llvm_toolchain_cpp_modules` in `MODULE.bazel`.
2. **`--experimental_cpp_modules`** — Bazel's experimental flag that enables
   module-aware compilation and dependency scanning.
3. **`--features=cpp_modules`** — Activates the `cpp_modules` toolchain feature
   in `rules_cc`, which wires up the module dependency scanner tool path.

A named config combining all three is defined in `.bazelrc`:

```
build:cpp_modules --extra_toolchains=@llvm_toolchain_cpp_modules//:all
build:cpp_modules --experimental_cpp_modules
build:cpp_modules --features=cpp_modules
build:cpp_modules --features=-layering_check
build:cpp_modules --features=-use_module_maps
```

> `layering_check` and `use_module_maps` are disabled because they generate a
> synthetic `crosstool` module for system headers that conflicts with C++20
> named modules.

Run the example from the `tests/` directory:

```sh
bazelisk run --config=cpp_modules //modules:main
# Hello from a C++ module!
```

To build all targets in this package:

```sh
bazelisk build --config=cpp_modules //modules:all
```

## Requirements

- Bazel 9 or later (earlier versions lack the deps-scanner calling convention
  required by `--experimental_cpp_modules`).
- LLVM 14 or later (`clang-scan-deps` with P1689 format support). The
  `llvm_toolchain_cpp_modules` toolchain in `MODULE.bazel` selects LLVM ≥ 17
  by default, consistent with the rest of the test suite.
