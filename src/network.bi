/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: network.bi

    Purpose:

        Declare the OPEN TCP transport and network-byte-order helpers.

    Responsibilities:

        - portable TCP connection management
        - exact binary reads and writes
        - big-endian RFB integer conversion

    This file intentionally does NOT contain:

        - operating-system socket calls
        - RFB protocol decisions
        - graphics or user interface code
'/

#ifndef PORTABLE_VNC_NETWORK_BI
#define PORTABLE_VNC_NETWORK_BI

declare function NetOpen( byref host as const string, byval port as integer, byref handle as integer, byref errorText as string ) as integer
declare sub NetClose( byref handle as integer )
declare function NetHasData( byval handle as integer ) as integer
declare function NetConnectionEnded( byval handle as integer ) as integer
declare function NetReadSomeNow( byval handle as integer, byval buffer as ubyte ptr, byval maximumBytes as integer, byref bytesRead as integer, byref errorText as string ) as integer
declare function NetReadAvailable( byval handle as integer, byval buffer as ubyte ptr, byval maximumBytes as integer, byval timeoutMilliseconds as integer, byref bytesRead as integer, byref errorText as string ) as integer
declare function NetReadExact( byval handle as integer, byval buffer as ubyte ptr, byval byteCount as ulongint, byval timeoutMilliseconds as integer, byref errorText as string ) as integer
declare function NetWriteExact( byval handle as integer, byval buffer as const ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
declare function NetDiscard( byval handle as integer, byval byteCount as ulongint, byval timeoutMilliseconds as integer, byref errorText as string ) as integer
declare function NetReadString( byval handle as integer, byval byteCount as ulong, byval maximumBytes as ulong, byval timeoutMilliseconds as integer, byref value as string, byref errorText as string ) as integer

declare function ReadU16BE( byval buffer as const ubyte ptr ) as ushort
declare function ReadU32BE( byval buffer as const ubyte ptr ) as ulong
declare sub WriteU16BE( byval buffer as ubyte ptr, byval value as ushort )
declare sub WriteU32BE( byval buffer as ubyte ptr, byval value as ulong )

#endif

/' end of network.bi '/
