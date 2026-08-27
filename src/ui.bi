/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: ui.bi

    Purpose:

        Declare the gfxlib viewer shell and server-address parser.

    Responsibilities:

        - run the resizable viewer window
        - present TightVNC-style connection and session controls
        - translate portable gfxlib events into RFB input

    This file intentionally does NOT contain:

        - RFB packet decoding
        - TCP transport code
        - platform-native widgets or APIs
'/

#ifndef PORTABLE_VNC_UI_BI
#define PORTABLE_VNC_UI_BI

#include once "common.bi"

declare function UiParseServer( byref serverText as const string, byref host as string, byref port as integer, byref errorText as string ) as integer
declare function UiRun( byref options as VncOptions, byval connectImmediately as integer ) as integer

#endif

/' end of ui.bi '/
