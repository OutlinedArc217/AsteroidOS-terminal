cmake_minimum_required(VERSION 3.6.0)

project(asteroid-terminal
    VERSION 1.0.0
    DESCRIPTION "Terminal emulator for AsteroidOS"
    LANGUAGES CXX)

# -----------------------------
# 应用信息
# -----------------------------
set(APP_NAME asteroid-terminal)
set(APP_ICON terminal)

# -----------------------------
# 源文件目录
# -----------------------------
add_subdirectory(src)

# -----------------------------
# 生成 .desktop 文件
# -----------------------------
# 把 .desktop.template 中的变量替换
configure_file(
    ${CMAKE_SOURCE_DIR}/asteroid-terminal.desktop.template
    ${CMAKE_BINARY_DIR}/${APP_NAME}.desktop
    @ONLY
)

# -----------------------------
# 安装规则
# -----------------------------
# 可执行文件安装到 /usr/bin
install(TARGETS ${APP_NAME} DESTINATION /usr/bin)

# 安装 .desktop 文件
install(FILES ${CMAKE_BINARY_DIR}/${APP_NAME}.desktop DESTINATION /usr/share/applications)

# 可选：安装图标
# install(FILES icons/terminal.png DESTINATION /usr/share/icons/hicolor/48x48/apps)

# -----------------------------
# CPack 配置，生成 IPK
# -----------------------------
include(CPack)

set(CPACK_PACKAGE_NAME "${APP_NAME}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_GENERATOR "IPK")


# -----------------------------
# 最终生成目标
# -----------------------------
message(STATUS "CMakeLists.txt configured for ${APP_NAME} with IPK packaging")
