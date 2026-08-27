/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: rfb.bi

    Purpose:

        Declare the portable Remote Framebuffer client interface.

    Responsibilities:

        - connection and protocol lifecycle
        - framebuffer update processing
        - keyboard, pointer, clipboard, and refresh requests

    This file intentionally does NOT contain:

        - user interface widgets
        - platform-specific key translation
        - operating-system networking
'/

#ifndef PORTABLE_VNC_RFB_BI
#define PORTABLE_VNC_RFB_BI

#include once "common.bi"

declare sub RfbInitialise( byref client as RfbClient )
declare sub RfbDisconnect( byref client as RfbClient )
declare function RfbConnect( byref client as RfbClient, byref options as VncOptions ) as integer
declare function RfbProcessOneMessage( byref client as RfbClient ) as integer
declare function RfbHasMessage( byref client as RfbClient ) as integer
declare function RfbRequestUpdate( byref client as RfbClient, byval incremental as integer ) as integer
declare function RfbSendPointer( byref client as RfbClient, byval x as integer, byval y as integer, byval buttonMask as integer ) as integer
declare function RfbSendKey( byref client as RfbClient, byval keysym as ulong, byval isDown as integer ) as integer
declare function RfbSendClipboard( byref client as RfbClient, byref text as const string ) as integer
declare function RfbSendCtrlAltDelete( byref client as RfbClient ) as integer
declare function RfbSendCtrlEscape( byref client as RfbClient ) as integer

#endif

/' end of rfb.bi '/
