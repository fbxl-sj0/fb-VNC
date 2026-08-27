/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: threads.bi

    Purpose:

        Declare the optional threaded RFB session pipeline.

    Responsibilities:

        - define bounded byte-pipe and worker lifecycle state
        - expose communication and decoder worker control
        - synchronize framebuffer ownership with the gfxlib render thread
        - provide transport hooks used by the RFB layer

    This file intentionally does NOT contain:

        - RFB packet parsing
        - OPEN TCP operations
        - gfxlib drawing or event handling
'/

#ifndef PORTABLE_VNC_THREADS_BI
#define PORTABLE_VNC_THREADS_BI

#include once "common.bi"

/'
    FreeBASIC defines __FB_MT__ when the thread-safe runtime was selected with
    -mt. DOS supplies deliberate no-thread stubs, while the JavaScript target
    cannot run a blocking producer/consumer pipeline. Both use the serial path.
'/
#if __FB_MT__
	#ifndef __FB_DOS__
		#ifndef __FB_JS__
			#define VNC_THREAD_SUPPORT 1
		#endif
	#endif
#endif

#ifndef VNC_THREAD_SUPPORT
	#define VNC_THREAD_SUPPORT 0
#endif

/'
    Eight MiB holds one complete 1920 by 1080 32-bit frame without wrapping.
    The outgoing pipe is smaller because input messages are normally tiny;
    large clipboard writes already block safely until the worker makes room.
'/
const VNC_INCOMING_PIPE_BYTES = 8388608
const VNC_OUTGOING_PIPE_BYTES = 1048576

type VncThreadState
	client as RfbClient ptr
	communicationsThread as any ptr
	decoderThread as any ptr
	stateMutex as any ptr
	startCondition as any ptr
	incomingMutex as any ptr
	incomingCanRead as any ptr
	incomingCanWrite as any ptr
	outgoingMutex as any ptr
	outgoingWriterMutex as any ptr
	outgoingCanWrite as any ptr
	framebufferMutex as any ptr
	incomingData as ubyte ptr
	incomingHead as integer
	incomingTail as integer
	incomingCount as integer
	outgoingData as ubyte ptr
	outgoingHead as integer
	outgoingTail as integer
	outgoingCount as integer
	workersReleased as integer
	stopRequested as integer
	failed as integer
	active as integer
	generation as ulong
	errorMessage as string
end type

declare sub VncThreadsInitialise( byref state as VncThreadState )
declare function VncThreadsStart( byref state as VncThreadState, byref client as RfbClient, byref fallbackReason as string ) as integer
declare sub VncThreadsStop( byref state as VncThreadState )
declare function VncThreadsActive( byref state as VncThreadState ) as integer
declare function VncThreadsPoll( byref state as VncThreadState, byref generation as ulong, byref errorText as string ) as integer

declare function VncThreadRead( byval statePointer as any ptr, byval buffer as ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
declare function VncThreadReadAvailable( byval statePointer as any ptr, byval buffer as ubyte ptr, byval maximumBytes as integer, byref bytesRead as integer, byref errorText as string ) as integer
declare function VncThreadWrite( byval statePointer as any ptr, byval buffer as const ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer

declare sub VncFramebufferLock( byref client as RfbClient )
declare sub VncFramebufferUnlock( byref client as RfbClient )

#endif

/' end of threads.bi '/
