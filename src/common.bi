/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: common.bi

    Purpose:

        Define the shared limits and state used by the portable viewer.

    Responsibilities:

        - viewer option storage
        - RFB connection and framebuffer state
        - defensive protocol and allocation limits

    This file intentionally does NOT contain:

        - network input/output
        - RFB message decoding
        - user interface drawing
'/

#ifndef PORTABLE_VNC_COMMON_BI
#define PORTABLE_VNC_COMMON_BI

const VNC_PROGRAM_NAME = "FreeBASIC VNC Viewer"
const VNC_PROGRAM_VERSION = "0.1"

const VNC_DEFAULT_HOST = "127.0.0.1"
const VNC_DEFAULT_PORT = 5900
const VNC_DEFAULT_WINDOW_WIDTH = 1024
const VNC_DEFAULT_WINDOW_HEIGHT = 720

/'
    These limits reject corrupt or hostile length fields before allocating
    memory. A 16,384 by 16,384 framebuffer would already require one GiB at
    the viewer's fixed 32-bit internal pixel depth, so the byte limit is the
    effective guard for unusually large desktops.
'/
const VNC_MAX_FRAMEBUFFER_DIMENSION = 16384
const VNC_MAX_FRAMEBUFFER_BYTES = 536870912u
const VNC_MAX_DESKTOP_NAME_BYTES = 1048576
const VNC_MAX_CLIPBOARD_BYTES = 16777216
const VNC_MAX_RRE_SUBRECTS = 16777216
/'
    Small RFB fields arrive in large groups during Hextile video updates. A
    per-client receive cache prevents every one-byte flag and two-byte
    subrectangle from becoming a separate OPEN TCP GET operation.
'/
const VNC_RECEIVE_BUFFER_BYTES = 65536

type VncOptions
	serverText as string
	host as string
	port as integer
	password as string
	sharedSession as integer
	viewOnly as integer
	scaleToFit as integer
	showToolbar as integer
	preferRaw as integer
end type

type RfbClient
	socketHandle as integer
	connected as integer
	protocolMinor as integer
	serverWidth as integer
	serverHeight as integer
	desktopName as string
	errorMessage as string
	clipboardText as string
	framebuffer as ulong ptr
	framebufferBytes as ulongint
	/' Protected by the framebuffer mutex while threaded decoding is active. '/
	framebufferDirtyValid as integer
	framebufferDirtyLeft as integer
	framebufferDirtyTop as integer
	framebufferDirtyRight as integer
	framebufferDirtyBottom as integer
	requestPending as integer
	fullUpdateNeeded as integer
	updatesReceived as ulong
	bellPending as integer
	viewOnly as integer
	sharedSession as integer
	preferRaw as integer
	threadedSession as integer
	/' Opaque pointer owned by threads.bas while a threaded session is active. '/
	threadState as any ptr
	receiveOffset as integer
	receiveCount as integer
	receiveBuffer( 0 to VNC_RECEIVE_BUFFER_BYTES - 1 ) as ubyte
end type

#endif

/' end of common.bi '/
