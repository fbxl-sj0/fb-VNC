/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: test_scaler.bas

    Purpose:

        Verify scaling and clipping for desktops larger than the viewer.

    Responsibilities:

        - check aspect-preserving fit dimensions
        - check downscaling from a larger source framebuffer
        - confirm destination guard pixels are not overwritten

    This file intentionally does NOT contain:

        - a gfxlib window
        - RFB network traffic
        - performance thresholds
'/

#include once "scaler.bi"

dim as integer failures = 0
dim as integer fittedWidth
dim as integer fittedHeight

if( ScalerFitDimensions( 3840, 2160, 800, 534, fittedWidth, fittedHeight ) = 0 orelse _
	fittedWidth <> 800 orelse fittedHeight <> 450 ) then
	print "Unexpected 16:9 fit dimensions:"; fittedWidth; "x"; fittedHeight
	failures += 1
end if

if( ScalerFitDimensions( 1200, 1920, 800, 534, fittedWidth, fittedHeight ) = 0 orelse _
	fittedWidth <> 333 orelse fittedHeight <> 534 ) then
	print "Unexpected portrait fit dimensions:"; fittedWidth; "x"; fittedHeight
	failures += 1
end if

dim as ulong sourcePixels( 0 to 15 )
dim as ulong destinationPixels( 0 to 15 )

for pixelIndex as integer = 0 to 15
	sourcePixels( pixelIndex ) = culng( pixelIndex + 1 )
	destinationPixels( pixelIndex ) = &hDEADBEEFu
next pixelIndex

if( ScalerBlitNearest32( _
	@sourcePixels( 0 ), 4, 4, cptr( ubyte ptr, @destinationPixels( 0 ) ), _
	4, 4, 16, 1, 1, 2, 2, 1, 1, 2, 2 _
) = 0 ) then
	print "The larger-source blit was rejected."
	failures += 1
else
	if( destinationPixels( 5 ) <> sourcePixels( 0 ) orelse _
		destinationPixels( 6 ) <> sourcePixels( 2 ) orelse _
		destinationPixels( 9 ) <> sourcePixels( 8 ) orelse _
		destinationPixels( 10 ) <> sourcePixels( 10 ) ) then
		print "The larger source did not downscale to the expected pixels."
		failures += 1
	end if

	if( destinationPixels( 0 ) <> &hDEADBEEFu orelse _
		destinationPixels( 15 ) <> &hDEADBEEFu ) then
		print "The scaler wrote outside its clipped destination."
		failures += 1
	end if
end if

for pixelIndex as integer = 0 to 15
	destinationPixels( pixelIndex ) = &hDEADBEEFu
next pixelIndex

if( ScalerBlitNearest32( _
	@sourcePixels( 0 ), 4, 4, cptr( ubyte ptr, @destinationPixels( 0 ) ), _
	4, 4, 16, 0, 0, 4, 4, 1, 1, 2, 2 _
) = 0 ) then
	print "The clipped one-to-one blit was rejected."
	failures += 1
else
	if( destinationPixels( 5 ) <> sourcePixels( 5 ) orelse _
		destinationPixels( 6 ) <> sourcePixels( 6 ) orelse _
		destinationPixels( 9 ) <> sourcePixels( 9 ) orelse _
		destinationPixels( 10 ) <> sourcePixels( 10 ) ) then
		print "The one-to-one row copy did not preserve its source pixels."
		failures += 1
	end if

	if( destinationPixels( 0 ) <> &hDEADBEEFu orelse _
		destinationPixels( 15 ) <> &hDEADBEEFu ) then
		print "The one-to-one row copy wrote outside its clipped destination."
		failures += 1
	end if
end if

if( failures = 0 ) then print "Framebuffer scaler test passed."
end failures

/' end of test_scaler.bas '/
