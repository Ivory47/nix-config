# Built by system/modules/pane.nix with the same Hyprland package that runs (hyprland.pc comes from it).
CXXFLAGS ?= -O2
PKGS = pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon

libpane.so: main.cpp
	$(CXX) -shared -fPIC --no-gnu-unique -std=c++2b $(CXXFLAGS) main.cpp -o libpane.so `pkg-config --cflags $(PKGS)`

clean:
	rm -f libpane.so
