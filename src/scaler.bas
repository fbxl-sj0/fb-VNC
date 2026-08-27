/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: scaler.bas

    Purpose:

        Scale the internal 32-bit VNC framebuffer into a display buffer.

    Responsibilities:

        - preserve aspect ratio when fitting a desktop into a viewport
        - render clipped nearest-neighbour pixels at any scale
        - avoid division in the inner pixel loop by building one x-coordinate map
        - use a direct copy path for one-to-one presentation

    This file intentionally does NOT contain:

        - knowledge of gfxlib pages or windows
        - framebuffer allocation ownership
        - interpolation or colour conversion
'/

#include once "scaler.bi"
#include once "builtin.bi"

function ScalerFitDimensions( _
	byval sourceWidth as integer, byval sourceHeight as integer, _
	byval availableWidth as integer, byval availableHeight as integer, _
	byref fittedWidth as integer, byref fittedHeight as integer _
) as integer
	dim as ulongint sourceAspectProduct
	dim as ulongint availableAspectProduct

	fittedWidth = 0
	fittedHeight = 0

	if( sourceWidth < 1 orelse sourceHeight < 1 orelse _
		availableWidth < 1 orelse availableHeight < 1 ) then return 0

	/'
	    Comparing cross-products avoids floating-point rounding. Whichever
	    viewport edge constrains the image is copied exactly, and the other
	    dimension is rounded down so it can never extend beyond the viewport.
	'/
	sourceAspectProduct = culngint( sourceWidth ) * culngint( availableHeight )
	availableAspectProduct = culngint( sourceHeight ) * culngint( availableWidth )

	if( sourceAspectProduct > availableAspectProduct ) then
		fittedWidth = availableWidth
		fittedHeight = cint( culngint( sourceHeight ) * culngint( availableWidth ) \ culngint( sourceWidth ) )
	else
		fittedHeight = availableHeight
		fittedWidth = cint( culngint( sourceWidth ) * culngint( availableHeight ) \ culngint( sourceHeight ) )
	end if

	if( fittedWidth < 1 ) then fittedWidth = 1
	if( fittedHeight < 1 ) then fittedHeight = 1
	if( fittedWidth > availableWidth ) then fittedWidth = availableWidth
	if( fittedHeight > availableHeight ) then fittedHeight = availableHeight

	return -1
end function

private function ScalerCopyOneToOne32( _
	byval sourcePixels as const ulong ptr, byval sourceWidth as integer, _
	byval destinationBytes as ubyte ptr, byval destinationPitchBytes as integer, _
	byval scaledX as integer, byval scaledY as integer, _
	byval clipLeft as integer, byval clipTop as integer, _
	byval clipRight as integer, byval clipBottom as integer _
) as integer
	dim as integer sourceX = clipLeft - scaledX
	dim as integer sourceY
	dim as integer visibleWidth = clipRight - clipLeft + 1
	dim as ulong ptr destinationRow
	dim as const ulong ptr sourceRow

	for destinationY as integer = clipTop to clipBottom
		sourceY = destinationY - scaledY
		destinationRow = cptr( ulong ptr, destinationBytes + culngint( destinationY ) * destinationPitchBytes )
		sourceRow = sourcePixels + culngint( sourceY ) * sourceWidth + sourceX

		/' The compiler intrinsic selects the target's efficient contiguous row copy. '/
		__builtin_memcpy destinationRow + clipLeft, sourceRow, visibleWidth * sizeof( ulong )
	next destinationY

	return -1
end function

function ScalerBlitNearest32( _
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
	dim as integer visibleWidth
	dim as ulongint mapBytes
	dim as integer ptr sourceXMap
	dim as integer sourceX
	dim as integer sourceY
	dim as ulong ptr destinationRow
	dim as const ulong ptr sourceRow

	if( sourcePixels = 0 orelse destinationBytes = 0 ) then return 0
	if( sourceWidth < 1 orelse sourceHeight < 1 orelse _
		destinationWidth < 1 orelse destinationHeight < 1 orelse _
		scaledWidth < 1 orelse scaledHeight < 1 ) then return 0
	if( culngint( destinationWidth ) * 4u > culngint( &h7FFFFFFF ) ) then return 0
	if( destinationPitchBytes < destinationWidth * 4 ) then return 0
	if( clipLeft < 0 orelse clipTop < 0 orelse _
		clipRight >= destinationWidth orelse clipBottom >= destinationHeight orelse _
		clipLeft > clipRight orelse clipTop > clipBottom ) then return 0

	/' The caller clips against the scaled rectangle before entering here. '/
	if( clipLeft < scaledX orelse clipTop < scaledY orelse _
		clipRight >= scaledX + scaledWidth orelse _
		clipBottom >= scaledY + scaledHeight ) then return 0

	if( scaledWidth = sourceWidth andalso scaledHeight = sourceHeight ) then
		return ScalerCopyOneToOne32( _
			sourcePixels, sourceWidth, destinationBytes, destinationPitchBytes, _
			scaledX, scaledY, clipLeft, clipTop, clipRight, clipBottom _
		)
	end if

	visibleWidth = clipRight - clipLeft + 1
	mapBytes = culngint( visibleWidth ) * sizeof( integer )
	if( mapBytes > culngint( &h7FFFFFFF ) ) then return 0
	sourceXMap = allocate( mapBytes )
	if( sourceXMap = 0 ) then return 0

	/'
	    Horizontal source coordinates are constant for every row. Building this
	    map once removes an integer division from the hottest per-pixel loop.
	'/
	for mapIndex as integer = 0 to visibleWidth - 1
		sourceX = cint( _
			culngint( clipLeft + mapIndex - scaledX ) * culngint( sourceWidth ) \ _
			culngint( scaledWidth ) _
		)
		if( sourceX >= sourceWidth ) then sourceX = sourceWidth - 1
		sourceXMap[mapIndex] = sourceX
	next mapIndex

	for destinationY as integer = clipTop to clipBottom
		sourceY = cint( _
			culngint( destinationY - scaledY ) * culngint( sourceHeight ) \ _
			culngint( scaledHeight ) _
		)
		if( sourceY >= sourceHeight ) then sourceY = sourceHeight - 1
		destinationRow = cptr( ulong ptr, destinationBytes + culngint( destinationY ) * destinationPitchBytes )
		sourceRow = sourcePixels + culngint( sourceY ) * sourceWidth

		for mapIndex as integer = 0 to visibleWidth - 1
			destinationRow[clipLeft + mapIndex] = sourceRow[sourceXMap[mapIndex]]
		next mapIndex
	next destinationY

	deallocate sourceXMap
	return -1
end function

/' end of scaler.bas '/
