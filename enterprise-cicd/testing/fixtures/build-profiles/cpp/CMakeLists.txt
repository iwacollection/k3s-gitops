cmake_minimum_required(VERSION 3.20)
project(platform_cpp_build_fixture LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(platform_fixture src/health.cpp)
target_include_directories(platform_fixture PUBLIC include)

add_executable(platform_fixture_app src/main.cpp)
target_link_libraries(platform_fixture_app PRIVATE platform_fixture)

include(CTest)
if(BUILD_TESTING)
  add_executable(platform_fixture_test tests/health_test.cpp)
  target_link_libraries(platform_fixture_test PRIVATE platform_fixture)
  add_test(NAME health COMMAND platform_fixture_test)
endif()

install(TARGETS platform_fixture_app RUNTIME DESTINATION bin)
