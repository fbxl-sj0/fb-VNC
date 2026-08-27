/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: scaler.bi

    Purpose:

        Declare the portable framebuffer scaling operations.

    Responsibilities:

        - calculate aspect-preserving fit dimensions
        - copy a clipped 32-bit framebuffer with nearest-neighbour scaling
        - validate dimensions and destination pitch before writing pixels

    This file intentionally does NOT contain:

        - gfxlib screen locking or page selection
        - RFB protocol handling
        - user-interface layout policy
'/

#ifndef PORTABLE_VNC_SCALER_BI
#define PORTABLE_VNC_SCALER_BI

declare function ScalerFitDimensions( _
	byval sourceWidth as integer, byval sourceHeight as integer, _
	byval availableWidth as integer, byval availableHeight as integer, _
	byref fittedWidth as integer, byref fittedHeight as integer _
) as integer

declare function ScalerBlitNearest32( _
	byval sourcePixels as const ulong ptr, _
	byval sourceWidth as integer, byval sourceHeight as integer, _
	byval destinationBytes as ubyte ptr, _
	byval destinationWidth as integer, byval destinationHeight as integer, _
	byval destinationPitchBytes as integer, _
	byval scaledX as integer, byval scaledY as integer, _
	byval scaledWidth as integer, byval scaledHeight as integer, _
	byval clipLeft as integer, byval clipTop as integer, _
	byval clipRight as integer, byval clipBottom as integer _
) as integer

#endif

/' end of scaler.bi '/
