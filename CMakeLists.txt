cmake_minimum_required(VERSION 3.6.0)

project(asteroid-terminal
    VERSION 1.0.0
    DESCRIPTION "Terminal emulator for AsteroidOS"
    LANGUAGES CXX)

find_package(AsteroidApp REQUIRED)
include(AsteroidApp)

set(APP_NAME asteroid-terminal)
set(APP_ICON terminal)

add_subdirectory(src)

# Generate desktop file
generate_desktop(${CMAKE_SOURCE_DIR}/asteroid-terminal.desktop.template)
