/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: perf_scaler.bas

    Purpose:

        Measure the viewer's real nearest-neighbour scaling routine.

    Responsibilities:

        - allocate a representative 4K remote framebuffer
        - scale it repeatedly into a 1280 by 720 display buffer
        - report elapsed time, frame time, and pixel throughput

    This file intentionally does NOT contain:

        - pass or fail thresholds that would reject slower platforms
        - gfxlib presentation or page-flip timing
        - network encoding or decoding work
'/

#include once "scaler.bi"

const SOURCE_WIDTH = 3840
const SOURCE_HEIGHT = 2160
const VIEW_WIDTH = 1280
const VIEW_HEIGHT = 720
const FRAME_COUNT = 180

dim as ulongint sourcePixelCount = culngint( SOURCE_WIDTH ) * SOURCE_HEIGHT
dim as ulongint destinationPixelCount = culngint( VIEW_WIDTH ) * VIEW_HEIGHT
dim as ulong ptr sourcePixels = allocate( sourcePixelCount * sizeof( ulong ) )
dim as ulong ptr destinationPixels = allocate( destinationPixelCount * sizeof( ulong ) )
dim as integer fittedWidth
dim as integer fittedHeight

if( sourcePixels = 0 orelse destinationPixels = 0 ) then
	if( sourcePixels <> 0 ) then deallocate sourcePixels
	if( destinationPixels <> 0 ) then deallocate destinationPixels
	print "Unable to allocate the scaling benchmark buffers."
	end 1
end if

for pixelIndex as ulongint = 0 to sourcePixelCount - 1
	sourcePixels[pixelIndex] = culng( pixelIndex xor ( pixelIndex shr 13 ) )
next pixelIndex

if( ScalerFitDimensions( _
	SOURCE_WIDTH, SOURCE_HEIGHT, VIEW_WIDTH, VIEW_HEIGHT, _
	fittedWidth, fittedHeight _
) = 0 ) then
	print "Unable to calculate benchmark fit dimensions."
	deallocate destinationPixels
	deallocate sourcePixels
	end 1
end if

dim as double startedAt = timer

for frameIndex as integer = 1 to FRAME_COUNT
	if( ScalerBlitNearest32( _
		sourcePixels, SOURCE_WIDTH, SOURCE_HEIGHT, _
		cptr( ubyte ptr, destinationPixels ), VIEW_WIDTH, VIEW_HEIGHT, _
		VIEW_WIDTH * 4, 0, 0, fittedWidth, fittedHeight, _
		0, 0, fittedWidth - 1, fittedHeight - 1 _
	) = 0 ) then
		print "The scaling benchmark blit failed."
		deallocate destinationPixels
		deallocate sourcePixels
		end 1
	end if
next frameIndex

dim as double elapsedSeconds = timer - startedAt
if( elapsedSeconds < 0.0 ) then elapsedSeconds += 86400.0
if( elapsedSeconds <= 0.0 ) then elapsedSeconds = 0.000001

dim as double renderedPixels = cdbl( fittedWidth ) * fittedHeight * FRAME_COUNT
dim as ulong checksum = destinationPixels[0] xor _
	destinationPixels[destinationPixelCount \ 2] xor _
	destinationPixels[destinationPixelCount - 1]

print "Scaling benchmark: 3840x2160 to 1280x720"
print "Frames:"; FRAME_COUNT
print "Elapsed seconds:"; elapsedSeconds
print "Milliseconds per frame:"; elapsedSeconds * 1000.0 / FRAME_COUNT
print "Throughput MPixels/s:"; renderedPixels / elapsedSeconds / 1000000.0
print "Checksum: 0x" & hex( checksum, 8 )

deallocate destinationPixels
deallocate sourcePixels
end 0

/' end of perf_scaler.bas '/
