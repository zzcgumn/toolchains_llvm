module;

export module hello;

export namespace hello {

auto greeting() -> const char* {
    return "Hello from a C++ module!";
}

}  // namespace hello
