# Portable FreeBASIC VNC Viewer
# -----------------------------
#
# File: Makefile
#
# Purpose:
#     Build and test the viewer with the standard FreeBASIC toolchain.
#
# This file intentionally does not invoke platform SDKs or external libraries.

FBC ?= fbc
FBCFLAGS ?= -gfx3 -O 2 -exx -w all -i src -i src/omaGUI-main
GFX2FLAGS ?= -O 2 -exx -w all -i src -i src/omaGUI-main
THREADFLAGS ?= -mt

SOURCES = src/main.bas src/network.bas src/des.bas src/threads.bas src/rfb.bas src/scaler.bas src/ui.bas
MODULE_SOURCES = src/network.bas src/des.bas src/threads.bas src/rfb.bas src/scaler.bas src/ui.bas
OMAGUI_SOURCES = $(wildcard src/omaGUI-main/*.bi src/omaGUI-main/src/backend/*.bi src/omaGUI-main/src/backend/*.bas src/omaGUI-main/src/widgets/*.bi src/omaGUI-main/src/widgets/*.bas)

.PHONY: all clean gfx2 serial test perf perf-rfb-server

all: fbvnc

fbvnc: $(SOURCES) src/common.bi src/network.bi src/des.bi src/threads.bi src/rfb.bi src/scaler.bi src/ui.bi $(OMAGUI_SOURCES)
	$(FBC) $(FBCFLAGS) $(THREADFLAGS) $(SOURCES) -x $@

gfx2: fbvnc-gfx2

fbvnc-gfx2: $(SOURCES) src/common.bi src/network.bi src/des.bi src/threads.bi src/rfb.bi src/scaler.bi src/ui.bi $(OMAGUI_SOURCES)
	$(FBC) $(GFX2FLAGS) $(THREADFLAGS) $(SOURCES) -x $@

serial: fbvnc-serial

fbvnc-serial: $(SOURCES) src/common.bi src/network.bi src/des.bi src/threads.bi src/rfb.bi src/scaler.bi src/ui.bi $(OMAGUI_SOURCES)
	$(FBC) $(FBCFLAGS) $(SOURCES) -x $@

tests/test_des: tests/test_des.bas src/des.bas src/des.bi
	$(FBC) $(FBCFLAGS) $(THREADFLAGS) tests/test_des.bas src/des.bas -x $@

tests/test_scaler: tests/test_scaler.bas src/scaler.bas src/scaler.bi
	$(FBC) $(FBCFLAGS) $(THREADFLAGS) tests/test_scaler.bas src/scaler.bas -x $@

tests/perf_scaler: tests/perf_scaler.bas src/scaler.bas src/scaler.bi
	$(FBC) $(FBCFLAGS) $(THREADFLAGS) tests/perf_scaler.bas src/scaler.bas -x $@

tests/perf_rfb_server: tests/perf_rfb_server.bas src/network.bas src/network.bi
	$(FBC) $(FBCFLAGS) $(THREADFLAGS) tests/perf_rfb_server.bas src/network.bas -x $@

tests/test_server_parser: tests/test_server_parser.bas $(MODULE_SOURCES) src/common.bi src/network.bi src/des.bi src/rfb.bi src/ui.bi $(OMAGUI_SOURCES)
	$(FBC) $(FBCFLAGS) $(THREADFLAGS) tests/test_server_parser.bas $(MODULE_SOURCES) -x $@

test: tests/test_des tests/test_scaler tests/test_server_parser
	./tests/test_des
	./tests/test_scaler
	./tests/test_server_parser

perf: tests/perf_scaler
	./tests/perf_scaler

perf-rfb-server: tests/perf_rfb_server
	./tests/perf_rfb_server

clean:
	rm -f fbvnc fbvnc-gfx2 fbvnc-serial tests/test_des tests/test_scaler tests/test_server_parser tests/perf_scaler tests/perf_rfb_server

# end of Makefile
