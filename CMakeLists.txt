cmake_minimum_required(VERSION 3.6.0)

project(asteroid-terminal
    VERSION 1.0.0
    DESCRIPTION "Terminal emulator for AsteroidOS"
    LANGUAGES CXX)

# -----------------------------
# 设置应用信息
# -----------------------------
set(APP_NAME asteroid-terminal)
set(APP_ICON terminal)

# -----------------------------
# 添加源文件目录
# -----------------------------
add_subdirectory(src)

# -----------------------------
# 手动生成 desktop 文件
# -----------------------------
# 使用 configure_file 替代 generate_desktop
# 在模板中可以使用 @APP_NAME@ 和 @APP_ICON@ 变量
configure_file(
    ${CMAKE_SOURCE_DIR}/asteroid-terminal.desktop.template
    ${CMAKE_BINARY_DIR}/${APP_NAME}.desktop
    @ONLY
)
