cmake_minimum_required(VERSION 3.21)
project(glassnative LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick WaylandClient)
find_package(Qt6 REQUIRED COMPONENTS QuickPrivate WaylandClientPrivate)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)

# Passed by default.nix: wlr-screencopy-unstable-v1.xml from wlr-protocols.
if(NOT WLR_SCREENCOPY_XML)
	message(FATAL_ERROR "WLR_SCREENCOPY_XML is not set")
endif()

set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)
set(GLASS_MODULE_DIR ${QT_QML_OUTPUT_DIRECTORY}/Glass/Native)

qt_add_qml_module(glassnative
	URI Glass.Native
	VERSION 1.0
	SOURCES
		glasscapture.cpp
		glasscapture.hpp
)

qt6_generate_wayland_protocol_client_sources(glassnative FILES ${WLR_SCREENCOPY_XML})

# C is enabled above on purpose: the generated protocol interface tables are a .c file.

target_link_libraries(glassnative PRIVATE
	Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
	Qt6::WaylandClient Qt6::WaylandClientPrivate Qt6::GuiPrivate
	PkgConfig::WAYLAND_CLIENT
)

# Backing library and plugin side by side, found through $ORIGIN, so the module directory
# can be copied as it is.
set_target_properties(glassnative glassnativeplugin PROPERTIES
	LIBRARY_OUTPUT_DIRECTORY ${GLASS_MODULE_DIR}
	BUILD_RPATH "\$ORIGIN"
	INSTALL_RPATH "\$ORIGIN"
	BUILD_WITH_INSTALL_RPATH ON
)
