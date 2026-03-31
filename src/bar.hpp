#pragma once

#include <string>

#include "foo.hpp"

class Bar {
public:
    Bar(const std::string& name);

private:
    Foo foo;
};
