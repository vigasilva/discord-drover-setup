cmake_minimum_required(VERSION 3.16)
project(discord_drover_linux VERSION 0.1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_executable(discord-drover src/launcher.c)
target_compile_options(discord-drover PRIVATE -Wall -Wextra)

add_library(discord-drover-preload SHARED src/udp_preload.c)
target_compile_options(discord-drover-preload PRIVATE -Wall -Wextra)
target_link_libraries(discord-drover-preload PRIVATE dl pthread)
set_target_properties(discord-drover-preload PROPERTIES OUTPUT_NAME discord-drover-preload)

install(TARGETS discord-drover RUNTIME DESTINATION bin)
install(TARGETS discord-drover-preload LIBRARY DESTINATION lib/discord-drover)
install(FILES config/drover.ini.example DESTINATION share/doc/discord-drover)
install(FILES config/drover.ini.default DESTINATION share/discord-drover)
