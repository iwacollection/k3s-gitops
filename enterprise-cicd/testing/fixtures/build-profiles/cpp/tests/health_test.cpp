#include <cstring>
#include "health.hpp"

int main() {
    return std::strcmp(health(), "cpp-build-profile-ok") == 0 ? 0 : 1;
}
