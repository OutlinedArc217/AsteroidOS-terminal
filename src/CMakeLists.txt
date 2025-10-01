set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 COMPONENTS Qml Quick REQUIRED)

set(SOURCES
    main.cpp
)

set(RESOURCES
    resources.qrc
)

add_executable(${APP_NAME}
    ${SOURCES}
    ${RESOURCES}
)

target_link_libraries(${APP_NAME}
    PUBLIC
    Qt5::Qml
    Qt5::Quick
    AsteroidApp
)

install(TARGETS ${APP_NAME}
    RUNTIME DESTINATION bin
)