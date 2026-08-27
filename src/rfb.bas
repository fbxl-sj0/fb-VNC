/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: rfb.bas

    Purpose:

        Implement an RFB 3.3, 3.7, and 3.8 client using standard FreeBASIC.

    Responsibilities:

        - protocol and security negotiation
        - classic VNC challenge-response authentication
        - Raw, CopyRect, RRE, CoRRE, and Hextile rectangle decoding
        - desktop resize, clipboard, bell, keyboard, and pointer messages
        - validation of every server-controlled length and rectangle

    This file intentionally does NOT contain:

        - compressed encodings that require zlib or JPEG libraries
        - platform socket or graphics APIs
        - connection-dialog and toolbar behavior
'/

#include once "rfb.bi"
#include once "network.bi"
#include once "des.bi"
#include once "threads.bi"
#include once "builtin.bi"

const RFB_IO_TIMEOUT_MS = 15000

const RFB_SECURITY_NONE = 1
const RFB_SECURITY_VNC_AUTH = 2

const RFB_SERVER_FRAMEBUFFER_UPDATE = 0
const RFB_SERVER_SET_COLOUR_MAP = 1
const RFB_SERVER_BELL = 2
const RFB_SERVER_CUT_TEXT = 3

const RFB_CLIENT_SET_PIXEL_FORMAT = 0
const RFB_CLIENT_SET_ENCODINGS = 2
const RFB_CLIENT_UPDATE_REQUEST = 3
const RFB_CLIENT_KEY_EVENT = 4
const RFB_CLIENT_POINTER_EVENT = 5
const RFB_CLIENT_CUT_TEXT = 6

const RFB_ENCODING_RAW = 0
const RFB_ENCODING_COPYRECT = 1
const RFB_ENCODING_RRE = 2
const RFB_ENCODING_CORRE = 4
const RFB_ENCODING_HEXTILE = 5
const RFB_ENCODING_XCURSOR = &hFFFFFF10u
const RFB_ENCODING_RICH_CURSOR = &hFFFFFF11u
const RFB_ENCODING_POINTER_POSITION = &hFFFFFF18u
const RFB_ENCODING_LAST_RECT = &hFFFFFF20u
const RFB_ENCODING_NEW_FRAMEBUFFER_SIZE = &hFFFFFF21u

const RFB_HEXTILE_RAW = 1
const RFB_HEXTILE_BACKGROUND = 2
const RFB_HEXTILE_FOREGROUND = 4
const RFB_HEXTILE_SUBRECTS = 8
const RFB_HEXTILE_COLOURED = 16

private function RfbFail( byref client as RfbClient, byref message as const string ) as integer
	client.errorMessage = message
	return 0
end function

private function RfbHostIsLoopback( byref hostName as const string ) as integer
	dim as string normalisedHost = lcase( trim( hostName ) )

	/'
	    Raw avoids Hextile's bookkeeping cost when the TCP path does not leave
	    this machine. Brackets are accepted here for completeness even though
	    the connection parser normally removes them from an IPv6 address.
	'/
	if( normalisedHost = "localhost" ) then return -1
	if( normalisedHost = "127.0.0.1" ) then return -1
	if( normalisedHost = "::1" orelse normalisedHost = "[::1]" ) then return -1

	return 0
end function

private function RfbRead( byref client as RfbClient, byval buffer as ubyte ptr, byval byteCount as ulongint ) as integer
	dim as string errorText
	dim as ulongint totalRead = 0
	dim as integer copyCount
	dim as integer receivedBytes
	dim as ubyte ptr receiveBytes = @client.receiveBuffer( 0 )

	if( byteCount = 0 ) then return -1
	if( buffer = 0 ) then return RfbFail( client, "An invalid RFB read was requested." )

	while( totalRead < byteCount )
		if( client.receiveCount > 0 ) then
			if( byteCount - totalRead < culngint( client.receiveCount ) ) then
				copyCount = cint( byteCount - totalRead )
			else
				copyCount = client.receiveCount
			end if

			__builtin_memcpy buffer + totalRead, receiveBytes + client.receiveOffset, copyCount

			client.receiveOffset += copyCount
			client.receiveCount -= copyCount
			totalRead += culngint( copyCount )
		elseif( byteCount - totalRead >= VNC_RECEIVE_BUFFER_BYTES ) then
			if( client.threadState <> 0 ) then
				if( VncThreadRead( _
					client.threadState, buffer + totalRead, byteCount - totalRead, errorText _
				) = 0 ) then return RfbFail( client, errorText )
			else
				if( NetReadExact( _
					client.socketHandle, buffer + totalRead, byteCount - totalRead, _
					RFB_IO_TIMEOUT_MS, errorText _
				) = 0 ) then return RfbFail( client, errorText )
			end if
			totalRead = byteCount
		else
			if( client.threadState <> 0 ) then
				if( VncThreadReadAvailable( _
					client.threadState, @client.receiveBuffer( 0 ), _
					VNC_RECEIVE_BUFFER_BYTES, receivedBytes, errorText _
				) = 0 ) then return RfbFail( client, errorText )
			else
				if( NetReadAvailable( _
					client.socketHandle, @client.receiveBuffer( 0 ), _
					VNC_RECEIVE_BUFFER_BYTES, RFB_IO_TIMEOUT_MS, _
					receivedBytes, errorText _
				) = 0 ) then return RfbFail( client, errorText )
			end if
			client.receiveOffset = 0
			client.receiveCount = receivedBytes
		end if
	wend

	return -1
end function

private function RfbReadString( byref client as RfbClient, byval byteCount as ulong, byval maximumBytes as ulong, byref value as string ) as integer
	value = ""

	if( byteCount > maximumBytes ) then
		return RfbFail( client, "The server supplied a string larger than the safety limit." )
	end if
	if( byteCount = 0 ) then return -1

	value = space( byteCount )
	if( RfbRead( client, cptr( ubyte ptr, strptr( value ) ), byteCount ) = 0 ) then
		value = ""
		return 0
	end if

	return -1
end function

private function RfbDiscard( byref client as RfbClient, byval byteCount as ulongint ) as integer
	dim as ubyte scratch( 0 to 4095 )
	dim as ulongint remaining = byteCount
	dim as ulongint chunkBytes

	while( remaining > 0 )
		if( remaining > sizeof( scratch ) ) then
			chunkBytes = sizeof( scratch )
		else
			chunkBytes = remaining
		end if
		if( RfbRead( client, @scratch( 0 ), chunkBytes ) = 0 ) then return 0
		remaining -= chunkBytes
	wend

	return -1
end function

private function RfbWrite( byref client as RfbClient, byval buffer as const ubyte ptr, byval byteCount as ulongint ) as integer
	dim as string errorText

	if( client.threadState <> 0 ) then
		if( VncThreadWrite( client.threadState, buffer, byteCount, errorText ) = 0 ) then
			return RfbFail( client, errorText )
		end if
	elseif( NetWriteExact( client.socketHandle, buffer, byteCount, errorText ) = 0 ) then
		return RfbFail( client, errorText )
	end if

	return -1
end function

private function RfbReadProtocolString( byref client as RfbClient, byval maximumBytes as ulong, byref value as string ) as integer
	dim as ubyte lengthBytes( 0 to 3 )
	dim as ulong byteCount

	if( RfbRead( client, @lengthBytes( 0 ), 4 ) = 0 ) then
		return 0
	end if

	byteCount = ReadU32BE( @lengthBytes( 0 ) )
	return RfbReadString( client, byteCount, maximumBytes, value )
end function

private sub RfbMarkFramebufferDirty( byref client as RfbClient, byval x as integer, byval y as integer, byval rectWidth as integer, byval rectHeight as integer )
	dim as integer rightPosition
	dim as integer bottomPosition

	if( rectWidth < 1 orelse rectHeight < 1 ) then exit sub
	if( x < 0 orelse y < 0 orelse x > client.serverWidth - rectWidth orelse y > client.serverHeight - rectHeight ) then exit sub

	rightPosition = x + rectWidth - 1
	bottomPosition = y + rectHeight - 1
	if( client.framebufferDirtyValid = 0 ) then
		client.framebufferDirtyLeft = x
		client.framebufferDirtyTop = y
		client.framebufferDirtyRight = rightPosition
		client.framebufferDirtyBottom = bottomPosition
		client.framebufferDirtyValid = -1
		exit sub
	end if

	if( x < client.framebufferDirtyLeft ) then client.framebufferDirtyLeft = x
	if( y < client.framebufferDirtyTop ) then client.framebufferDirtyTop = y
	if( rightPosition > client.framebufferDirtyRight ) then client.framebufferDirtyRight = rightPosition
	if( bottomPosition > client.framebufferDirtyBottom ) then client.framebufferDirtyBottom = bottomPosition
end sub

private function RfbAllocateFramebuffer( byref client as RfbClient, byval framebufferWidth as integer, byval framebufferHeight as integer ) as integer
	dim as ulongint pixelCount
	dim as ulongint byteCount
	dim as ulong ptr newFramebuffer
	dim as ulongint pixelIndex

	if( framebufferWidth < 1 orelse framebufferHeight < 1 ) then
		return RfbFail( client, "The server supplied an empty framebuffer." )
	end if

	if( framebufferWidth > VNC_MAX_FRAMEBUFFER_DIMENSION orelse framebufferHeight > VNC_MAX_FRAMEBUFFER_DIMENSION ) then
		return RfbFail( client, "The server framebuffer dimensions exceed the safety limit." )
	end if

	pixelCount = culngint( framebufferWidth ) * culngint( framebufferHeight )
	byteCount = pixelCount * 4u
	if( byteCount > VNC_MAX_FRAMEBUFFER_BYTES ) then
		return RfbFail( client, "The server framebuffer requires more than the allowed memory limit." )
	end if

	newFramebuffer = cptr( ulong ptr, allocate( byteCount ) )
	if( newFramebuffer = 0 ) then
		return RfbFail( client, "There is not enough memory for the server framebuffer." )
	end if

	for pixelIndex = 0 to pixelCount - 1
		newFramebuffer[pixelIndex] = 0
	next pixelIndex

	if( client.framebuffer <> 0 ) then
		deallocate client.framebuffer
	end if

	client.framebuffer = newFramebuffer
	client.framebufferBytes = byteCount
	client.serverWidth = framebufferWidth
	client.serverHeight = framebufferHeight
	client.fullUpdateNeeded = -1
	RfbMarkFramebufferDirty client, 0, 0, framebufferWidth, framebufferHeight

	return -1
end function

private function RfbRectangleIsValid( byref client as RfbClient, byval x as integer, byval y as integer, byval rectWidth as integer, byval rectHeight as integer ) as integer
	if( x < 0 orelse y < 0 orelse rectWidth < 0 orelse rectHeight < 0 ) then
		return 0
	end if

	if( x > client.serverWidth orelse y > client.serverHeight ) then
		return 0
	end if

	if( rectWidth > client.serverWidth - x orelse rectHeight > client.serverHeight - y ) then
		return 0
	end if

	return -1
end function

private function RfbReadPixel( byref client as RfbClient, byref pixel as ulong ) as integer
	dim as ubyte bytes( 0 to 3 )

	if( RfbRead( client, @bytes( 0 ), 4 ) = 0 ) then
		return 0
	end if

	/'
	    The negotiated format is little-endian BGRX8888. Its native numeric
	    value is the same 0x00RRGGBB colour accepted by 32-bit gfxlib.
	'/
	pixel = culng( bytes( 0 ) ) or _
		( culng( bytes( 1 ) ) shl 8 ) or _
		( culng( bytes( 2 ) ) shl 16 ) or _
		( culng( bytes( 3 ) ) shl 24 )

	return -1
end function

private sub RfbFillRectangle( byref client as RfbClient, byval x as integer, byval y as integer, byval rectWidth as integer, byval rectHeight as integer, byval pixel as ulong )
	dim as integer rowIndex
	dim as integer columnIndex
	dim as ulong ptr destination

	for rowIndex = 0 to rectHeight - 1
		destination = client.framebuffer + culngint( y + rowIndex ) * client.serverWidth + x
		for columnIndex = 0 to rectWidth - 1
			destination[columnIndex] = pixel
		next columnIndex
	next rowIndex
end sub

private function RfbDecodeRawPixels( byref client as RfbClient, byval x as integer, byval y as integer, byval rectWidth as integer, byval rectHeight as integer ) as integer
	dim as ubyte pixelBytes( 0 to 3 )
	dim as integer rowIndex
	dim as integer columnIndex
	dim as ulong ptr destination
	dim as integer bufferIndex
	dim as ubyte ptr receiveBytes = @client.receiveBuffer( 0 )
	dim as ulong endianMarker = 1
	dim as integer littleEndianHost = ( cptr( ubyte ptr, @endianMarker )[0] = 1 )
	dim as integer directPixelCount
	dim as ulong ptr directSource

	for rowIndex = 0 to rectHeight - 1
		destination = client.framebuffer + culngint( y + rowIndex ) * client.serverWidth + x
		columnIndex = 0
		while( columnIndex < rectWidth )
			if( client.receiveCount >= 4 ) then
				bufferIndex = client.receiveOffset

				/'
				    Raw pixels already have the native 0x00RRGGBB value on a
				    little-endian host. Use aligned 32-bit copies whenever the
				    receive-cache boundary permits them, and retain the portable
				    byte assembly path for other hosts or unaligned fragments.
				'/
				if( littleEndianHost andalso _
					( culngint( receiveBytes + bufferIndex ) and 3u ) = 0 ) then
					directPixelCount = client.receiveCount \ 4
					if( directPixelCount > rectWidth - columnIndex ) then
						directPixelCount = rectWidth - columnIndex
					end if
					directSource = cptr( ulong ptr, receiveBytes + bufferIndex )
					__builtin_memcpy( _
						destination + columnIndex, directSource, directPixelCount * sizeof( ulong ) _
					)
					client.receiveOffset += directPixelCount * 4
					client.receiveCount -= directPixelCount * 4
					columnIndex += directPixelCount
				else
					destination[columnIndex] = culng( receiveBytes[bufferIndex] ) or _
						( culng( receiveBytes[bufferIndex + 1] ) shl 8 ) or _
						( culng( receiveBytes[bufferIndex + 2] ) shl 16 ) or _
						( culng( receiveBytes[bufferIndex + 3] ) shl 24 )
					client.receiveOffset += 4
					client.receiveCount -= 4
					columnIndex += 1
				end if
			else
				/' A cache boundary can leave fewer than four bytes available. '/
				if( RfbRead( client, @pixelBytes( 0 ), 4 ) = 0 ) then return 0
				destination[columnIndex] = culng( pixelBytes( 0 ) ) or _
					( culng( pixelBytes( 1 ) ) shl 8 ) or _
					( culng( pixelBytes( 2 ) ) shl 16 ) or _
					( culng( pixelBytes( 3 ) ) shl 24 )
				columnIndex += 1
			end if
		wend
	next rowIndex

	return -1
end function

private function RfbDecodeRaw( byref client as RfbClient, byval x as integer, byval y as integer, byval rectWidth as integer, byval rectHeight as integer ) as integer
	dim as ulongint rectangleByteCount = culngint( rectWidth ) * rectHeight * 4u
	dim as ulong endianMarker = 1
	dim as integer littleEndianHost = ( cptr( ubyte ptr, @endianMarker )[0] = 1 )

	if( rectangleByteCount = 0 ) then return -1
	if( rectangleByteCount > VNC_MAX_FRAMEBUFFER_BYTES ) then
		return RfbFail( client, "The Raw rectangle exceeds the safety limit." )
	end if

	/'
	    A full-width Raw rectangle is contiguous in the framebuffer. On a
	    little-endian host its negotiated wire representation is already the
	    native framebuffer representation, so OPEN TCP can receive most of the
	    rectangle directly into its final storage. Partial-width rectangles
	    retain the row-aware decoder because the framebuffer has a row stride.
	'/
	if( littleEndianHost andalso x = 0 andalso rectWidth = client.serverWidth ) then
		return RfbRead( _
			client, _
			cptr( ubyte ptr, client.framebuffer + culngint( y ) * client.serverWidth ), _
			rectangleByteCount _
		)
	end if

	return RfbDecodeRawPixels( client, x, y, rectWidth, rectHeight )
end function

private function RfbDecodeCopyRect( byref client as RfbClient, byval destinationX as integer, byval destinationY as integer, byval rectWidth as integer, byval rectHeight as integer ) as integer
	dim as ubyte sourceBytes( 0 to 3 )
	dim as integer sourceX
	dim as integer sourceY
	dim as integer startRow
	dim as integer endRow
	dim as integer rowStep
	dim as integer startColumn
	dim as integer endColumn
	dim as integer columnStep
	dim as integer rowIndex
	dim as integer columnIndex
	dim as ulongint sourceOffset
	dim as ulongint destinationOffset

	if( RfbRead( client, @sourceBytes( 0 ), 4 ) = 0 ) then
		return 0
	end if

	sourceX = ReadU16BE( @sourceBytes( 0 ) )
	sourceY = ReadU16BE( @sourceBytes( 2 ) )
	if( RfbRectangleIsValid( client, sourceX, sourceY, rectWidth, rectHeight ) = 0 ) then
		return RfbFail( client, "The server supplied an invalid CopyRect source." )
	end if

	if( destinationY > sourceY ) then
		startRow = rectHeight - 1
		endRow = 0
		rowStep = -1
	else
		startRow = 0
		endRow = rectHeight - 1
		rowStep = 1
	end if

	if( destinationX > sourceX ) then
		startColumn = rectWidth - 1
		endColumn = 0
		columnStep = -1
	else
		startColumn = 0
		endColumn = rectWidth - 1
		columnStep = 1
	end if

	rowIndex = startRow
	do
		columnIndex = startColumn
		do
			sourceOffset = culngint( sourceY + rowIndex ) * client.serverWidth + sourceX + columnIndex
			destinationOffset = culngint( destinationY + rowIndex ) * client.serverWidth + destinationX + columnIndex
			client.framebuffer[destinationOffset] = client.framebuffer[sourceOffset]

			if( columnIndex = endColumn ) then exit do
			columnIndex += columnStep
		loop

		if( rowIndex = endRow ) then exit do
		rowIndex += rowStep
	loop

	return -1
end function

private function RfbDecodeRre( byref client as RfbClient, byval rectangleX as integer, byval rectangleY as integer, byval rectangleWidth as integer, byval rectangleHeight as integer, byval compact as integer ) as integer
	dim as ubyte countBytes( 0 to 3 )
	dim as ubyte geometry( 0 to 7 )
	dim as ulong subrectangleCount
	dim as ulong subrectangleIndex
	dim as ulong backgroundPixel
	dim as ulong foregroundPixel
	dim as integer x
	dim as integer y
	dim as integer subrectWidth
	dim as integer subrectHeight

	if( RfbRead( client, @countBytes( 0 ), 4 ) = 0 ) then
		return 0
	end if

	subrectangleCount = ReadU32BE( @countBytes( 0 ) )
	if( subrectangleCount > VNC_MAX_RRE_SUBRECTS ) then
		return RfbFail( client, "The RRE subrectangle count exceeds the safety limit." )
	end if

	if( RfbReadPixel( client, backgroundPixel ) = 0 ) then
		return 0
	end if
	RfbFillRectangle( client, rectangleX, rectangleY, rectangleWidth, rectangleHeight, backgroundPixel )

	for subrectangleIndex = 1 to subrectangleCount
		if( RfbReadPixel( client, foregroundPixel ) = 0 ) then
			return 0
		end if

		if( compact ) then
			if( RfbRead( client, @geometry( 0 ), 4 ) = 0 ) then return 0
			x = geometry( 0 )
			y = geometry( 1 )
			subrectWidth = geometry( 2 )
			subrectHeight = geometry( 3 )
		else
			if( RfbRead( client, @geometry( 0 ), 8 ) = 0 ) then return 0
			x = ReadU16BE( @geometry( 0 ) )
			y = ReadU16BE( @geometry( 2 ) )
			subrectWidth = ReadU16BE( @geometry( 4 ) )
			subrectHeight = ReadU16BE( @geometry( 6 ) )
		end if

		if( x > rectangleWidth orelse y > rectangleHeight orelse _
			subrectWidth > rectangleWidth - x orelse subrectHeight > rectangleHeight - y ) then
			return RfbFail( client, "The server supplied an invalid RRE subrectangle." )
		end if

		RfbFillRectangle( client, rectangleX + x, rectangleY + y, subrectWidth, subrectHeight, foregroundPixel )
	next subrectangleIndex

	return -1
end function

private function RfbDecodeHextile( byref client as RfbClient, byval rectangleX as integer, byval rectangleY as integer, byval rectangleWidth as integer, byval rectangleHeight as integer ) as integer
	dim as integer tileX
	dim as integer tileY
	dim as integer tileWidth
	dim as integer tileHeight
	dim as ubyte subencoding
	dim as ubyte subrectangleCount
	dim as ubyte geometry( 0 to 1 )
	dim as integer subrectangleIndex
	dim as integer x
	dim as integer y
	dim as integer subrectWidth
	dim as integer subrectHeight
	dim as ulong backgroundPixel = 0
	dim as ulong foregroundPixel = 0
	dim as integer haveBackground = 0
	dim as integer haveForeground = 0

	tileY = 0
	while( tileY < rectangleHeight )
		tileHeight = 16
		if( tileHeight > rectangleHeight - tileY ) then tileHeight = rectangleHeight - tileY

		tileX = 0
		while( tileX < rectangleWidth )
			tileWidth = 16
			if( tileWidth > rectangleWidth - tileX ) then tileWidth = rectangleWidth - tileX

			if( RfbRead( client, @subencoding, 1 ) = 0 ) then return 0
			if( ( subencoding and &hE0 ) <> 0 ) then
				return RfbFail( client, "The server supplied unsupported Hextile flag bits." )
			end if
			if( ( subencoding and RFB_HEXTILE_RAW ) <> 0 ) then
				if( RfbDecodeRawPixels( _
					client, rectangleX + tileX, rectangleY + tileY, _
					tileWidth, tileHeight _
				) = 0 ) then return 0
			else
				if( ( subencoding and RFB_HEXTILE_BACKGROUND ) <> 0 ) then
					if( RfbReadPixel( client, backgroundPixel ) = 0 ) then return 0
					haveBackground = -1
				end if
				if( haveBackground = 0 ) then return RfbFail( client, "The first non-Raw Hextile tile omitted its background colour." )

				RfbFillRectangle( client, rectangleX + tileX, rectangleY + tileY, tileWidth, tileHeight, backgroundPixel )

				if( ( subencoding and RFB_HEXTILE_FOREGROUND ) <> 0 ) then
					if( RfbReadPixel( client, foregroundPixel ) = 0 ) then return 0
					haveForeground = -1
				end if

				if( ( subencoding and RFB_HEXTILE_SUBRECTS ) <> 0 ) then
					if( RfbRead( client, @subrectangleCount, 1 ) = 0 ) then return 0

					for subrectangleIndex = 1 to subrectangleCount
						if( ( subencoding and RFB_HEXTILE_COLOURED ) <> 0 ) then
							if( RfbReadPixel( client, foregroundPixel ) = 0 ) then return 0
							haveForeground = -1
						end if
						if( haveForeground = 0 ) then return RfbFail( client, "A Hextile subrectangle omitted its foreground colour." )

						if( RfbRead( client, @geometry( 0 ), 2 ) = 0 ) then return 0
						x = geometry( 0 ) shr 4
						y = geometry( 0 ) and 15
						subrectWidth = ( geometry( 1 ) shr 4 ) + 1
						subrectHeight = ( geometry( 1 ) and 15 ) + 1

						if( x + subrectWidth > tileWidth orelse y + subrectHeight > tileHeight ) then
							return RfbFail( client, "The server supplied an invalid Hextile subrectangle." )
						end if

						RfbFillRectangle( client, rectangleX + tileX + x, rectangleY + tileY + y, subrectWidth, subrectHeight, foregroundPixel )
					next subrectangleIndex
				end if
			end if

			tileX += 16
		wend
		tileY += 16
	wend

	return -1
end function

private function RfbDiscardCursor( byref client as RfbClient, byval cursorWidth as integer, byval cursorHeight as integer, byval richCursor as integer ) as integer
	dim as ulongint maskBytes
	dim as ulongint pixelBytes
	dim as ulongint totalBytes

	/'
	    TightVNC uses a zero-by-zero cursor rectangle to remove the current
	    cursor shape. It sends no colour fields or bitmap bytes in that case.
	    Consuming the ordinary XCursor colours would eat six bytes from the
	    following rectangle header and desynchronize the RFB stream.
	'/
	if( cursorWidth = 0 orelse cursorHeight = 0 ) then return -1

	maskBytes = culngint( ( cursorWidth + 7 ) \ 8 ) * cursorHeight
	if( richCursor ) then
		pixelBytes = culngint( cursorWidth ) * cursorHeight * 4u
	else
		/' XCursor has two three-byte colours before its bitmap and mask. '/
		pixelBytes = 6u + maskBytes
	end if
	totalBytes = pixelBytes + maskBytes

	if( totalBytes > VNC_MAX_FRAMEBUFFER_BYTES ) then
		return RfbFail( client, "The server cursor exceeds the safety limit." )
	end if

	return RfbDiscard( client, totalBytes )
end function

private function RfbProcessFramebufferUpdateBody( byref client as RfbClient ) as integer
	dim as ubyte updateHeader( 0 to 2 )
	dim as ubyte rectangleHeader( 0 to 11 )
	dim as integer rectangleCount
	dim as integer rectangleIndex
	dim as integer x
	dim as integer y
	dim as integer rectWidth
	dim as integer rectHeight
	dim as ulong encodingType
	dim as integer lastRectangle = 0

	if( RfbRead( client, @updateHeader( 0 ), 3 ) = 0 ) then return 0
	rectangleCount = ReadU16BE( @updateHeader( 1 ) )
	client.requestPending = 0

	for rectangleIndex = 1 to rectangleCount
		if( RfbRead( client, @rectangleHeader( 0 ), 12 ) = 0 ) then return 0
		x = ReadU16BE( @rectangleHeader( 0 ) )
		y = ReadU16BE( @rectangleHeader( 2 ) )
		rectWidth = ReadU16BE( @rectangleHeader( 4 ) )
		rectHeight = ReadU16BE( @rectangleHeader( 6 ) )
		encodingType = ReadU32BE( @rectangleHeader( 8 ) )

		if( encodingType = RFB_ENCODING_LAST_RECT ) then
			lastRectangle = -1
			exit for
		elseif( encodingType = RFB_ENCODING_NEW_FRAMEBUFFER_SIZE ) then
			if( RfbAllocateFramebuffer( client, rectWidth, rectHeight ) = 0 ) then return 0
		elseif( encodingType = RFB_ENCODING_POINTER_POSITION ) then
			/' The local gfxlib pointer remains visible, so no payload is needed. '/
		elseif( encodingType = RFB_ENCODING_XCURSOR ) then
			if( RfbDiscardCursor( client, rectWidth, rectHeight, 0 ) = 0 ) then return 0
		elseif( encodingType = RFB_ENCODING_RICH_CURSOR ) then
			if( RfbDiscardCursor( client, rectWidth, rectHeight, -1 ) = 0 ) then return 0
		else
			if( RfbRectangleIsValid( client, x, y, rectWidth, rectHeight ) = 0 ) then
				return RfbFail( client, "The server supplied a rectangle outside the framebuffer." )
			end if

			select case encodingType
			case RFB_ENCODING_RAW
				if( RfbDecodeRaw( client, x, y, rectWidth, rectHeight ) = 0 ) then return 0
			case RFB_ENCODING_COPYRECT
				if( RfbDecodeCopyRect( client, x, y, rectWidth, rectHeight ) = 0 ) then return 0
			case RFB_ENCODING_RRE
				if( RfbDecodeRre( client, x, y, rectWidth, rectHeight, 0 ) = 0 ) then return 0
			case RFB_ENCODING_CORRE
				if( RfbDecodeRre( client, x, y, rectWidth, rectHeight, -1 ) = 0 ) then return 0
			case RFB_ENCODING_HEXTILE
				if( RfbDecodeHextile( client, x, y, rectWidth, rectHeight ) = 0 ) then return 0
			case else
				return RfbFail( client, "The server selected an unsupported framebuffer encoding " & str( clng( encodingType ) ) & "." )
			end select
			RfbMarkFramebufferDirty client, x, y, rectWidth, rectHeight
		end if
	next rectangleIndex

	client.updatesReceived += 1

	/' LastRect permits an early end even when the header used 65535 rectangles. '/
	if( lastRectangle = 0 orelse rectangleCount > 0 ) then
		if( client.fullUpdateNeeded ) then
			client.fullUpdateNeeded = 0
			if( RfbRequestUpdate( client, 0 ) = 0 ) then return 0
		else
			if( RfbRequestUpdate( client, -1 ) = 0 ) then return 0
		end if
	end if

	return -1
end function

private function RfbProcessFramebufferUpdate( byref client as RfbClient ) as integer
	dim as integer result

	/'
	    The decoder owns framebuffer mutations for one complete server update.
	    The gfxlib thread takes the same mutex while building a hidden page, so
	    neither side can observe a deallocated or partially updated framebuffer.
	'/
	VncFramebufferLock client
	result = RfbProcessFramebufferUpdateBody( client )
	VncFramebufferUnlock client
	return result
end function

private function RfbSendPixelFormat( byref client as RfbClient ) as integer
	dim as ubyte message( 0 to 19 )

	for index as integer = 0 to 19
		message( index ) = 0
	next index

	message( 0 ) = RFB_CLIENT_SET_PIXEL_FORMAT
	message( 4 ) = 32
	message( 5 ) = 24
	message( 6 ) = 0
	message( 7 ) = 1
	WriteU16BE( @message( 8 ), 255 )
	WriteU16BE( @message( 10 ), 255 )
	WriteU16BE( @message( 12 ), 255 )
	message( 14 ) = 16
	message( 15 ) = 8
	message( 16 ) = 0

	return RfbWrite( client, @message( 0 ), 20 )
end function

private function RfbSendEncodings( byref client as RfbClient ) as integer
	dim as ulong encodings( 0 to 9 )
	dim as ubyte message( 0 to 43 )
	dim as integer encodingIndex

	/'
	    Hextile saves bandwidth on ordinary remote links. Raw is substantially
	    cheaper to decode for high-motion images and is preferred on loopback or
	    when the user identifies the network as fast enough for the extra bytes.
	'/
	if( client.preferRaw ) then
		encodings( 0 ) = RFB_ENCODING_RAW
		encodings( 1 ) = RFB_ENCODING_COPYRECT
		encodings( 2 ) = RFB_ENCODING_HEXTILE
		encodings( 3 ) = RFB_ENCODING_RRE
		encodings( 4 ) = RFB_ENCODING_CORRE
	else
		encodings( 0 ) = RFB_ENCODING_HEXTILE
		encodings( 1 ) = RFB_ENCODING_COPYRECT
		encodings( 2 ) = RFB_ENCODING_RRE
		encodings( 3 ) = RFB_ENCODING_CORRE
		encodings( 4 ) = RFB_ENCODING_RAW
	end if
	encodings( 5 ) = RFB_ENCODING_RICH_CURSOR
	encodings( 6 ) = RFB_ENCODING_XCURSOR
	encodings( 7 ) = RFB_ENCODING_POINTER_POSITION
	encodings( 8 ) = RFB_ENCODING_LAST_RECT
	encodings( 9 ) = RFB_ENCODING_NEW_FRAMEBUFFER_SIZE

	for encodingIndex = 0 to 43
		message( encodingIndex ) = 0
	next encodingIndex

	message( 0 ) = RFB_CLIENT_SET_ENCODINGS
	WriteU16BE( @message( 2 ), 10 )
	for encodingIndex = 0 to 9
		WriteU32BE( @message( 4 + encodingIndex * 4 ), encodings( encodingIndex ) )
	next encodingIndex

	return RfbWrite( client, @message( 0 ), 44 )
end function

private function RfbReadSecurityResult( byref client as RfbClient ) as integer
	dim as ubyte resultBytes( 0 to 3 )
	dim as ulong result
	dim as string reason

	if( RfbRead( client, @resultBytes( 0 ), 4 ) = 0 ) then return 0
	result = ReadU32BE( @resultBytes( 0 ) )
	if( result = 0 ) then return -1

	if( client.protocolMinor >= 8 ) then
		if( RfbReadProtocolString( client, VNC_MAX_DESKTOP_NAME_BYTES, reason ) = 0 ) then return 0
		if( len( reason ) > 0 ) then
			return RfbFail( client, "VNC authentication failed: " & reason )
		end if
	end if

	if( result = 2 ) then
		return RfbFail( client, "VNC authentication failed because the server refused further attempts." )
	end if

	return RfbFail( client, "VNC authentication failed. Check the password." )
end function

private function RfbPerformVncAuthentication( byref client as RfbClient, byref password as const string ) as integer
	dim as ubyte challenge( 0 to 15 )

	if( RfbRead( client, @challenge( 0 ), 16 ) = 0 ) then return 0
	VncEncryptChallenge( password, @challenge( 0 ) )
	if( RfbWrite( client, @challenge( 0 ), 16 ) = 0 ) then return 0

	return RfbReadSecurityResult( client )
end function

private function RfbNegotiateSecurity( byref client as RfbClient, byref password as const string ) as integer
	dim as ubyte securityBytes( 0 to 3 )
	dim as ubyte securityTypes( 0 to 255 )
	dim as integer typeCount
	dim as integer typeIndex
	dim as integer selectedType = 0
	dim as ulong securityType
	dim as string reason

	if( client.protocolMinor = 3 ) then
		if( RfbRead( client, @securityBytes( 0 ), 4 ) = 0 ) then return 0
		securityType = ReadU32BE( @securityBytes( 0 ) )

		select case securityType
		case 0
			if( RfbReadProtocolString( client, VNC_MAX_DESKTOP_NAME_BYTES, reason ) = 0 ) then return 0
			return RfbFail( client, "The VNC server refused the connection: " & reason )
		case RFB_SECURITY_NONE
			return -1
		case RFB_SECURITY_VNC_AUTH
			return RfbPerformVncAuthentication( client, password )
		case else
			return RfbFail( client, "The VNC server requires an unsupported security type." )
		end select
	end if

	if( RfbRead( client, @securityTypes( 0 ), 1 ) = 0 ) then return 0
	typeCount = securityTypes( 0 )
	if( typeCount = 0 ) then
		if( RfbReadProtocolString( client, VNC_MAX_DESKTOP_NAME_BYTES, reason ) = 0 ) then return 0
		return RfbFail( client, "The VNC server refused the connection: " & reason )
	end if

	if( RfbRead( client, @securityTypes( 0 ), typeCount ) = 0 ) then return 0
	for typeIndex = 0 to typeCount - 1
		if( securityTypes( typeIndex ) = RFB_SECURITY_VNC_AUTH ) then
			selectedType = RFB_SECURITY_VNC_AUTH
		end if
	next typeIndex

	/' Prefer no authentication only when no VNC password was supplied. '/
	if( len( password ) = 0 ) then
		for typeIndex = 0 to typeCount - 1
			if( securityTypes( typeIndex ) = RFB_SECURITY_NONE ) then
				selectedType = RFB_SECURITY_NONE
			end if
		next typeIndex
	end if

	if( selectedType = 0 ) then
		return RfbFail( client, "The server does not offer None or classic VNC authentication." )
	end if

	securityBytes( 0 ) = cubyte( selectedType )
	if( RfbWrite( client, @securityBytes( 0 ), 1 ) = 0 ) then return 0

	if( selectedType = RFB_SECURITY_VNC_AUTH ) then
		return RfbPerformVncAuthentication( client, password )
	end if

	if( client.protocolMinor >= 8 ) then
		return RfbReadSecurityResult( client )
	end if

	return -1
end function

sub RfbInitialise( byref client as RfbClient )
	client.socketHandle = 0
	client.connected = 0
	client.protocolMinor = 0
	client.serverWidth = 0
	client.serverHeight = 0
	client.desktopName = ""
	client.errorMessage = ""
	client.clipboardText = ""
	client.framebuffer = 0
	client.framebufferBytes = 0
	client.framebufferDirtyValid = 0
	client.framebufferDirtyLeft = 0
	client.framebufferDirtyTop = 0
	client.framebufferDirtyRight = 0
	client.framebufferDirtyBottom = 0
	client.requestPending = 0
	client.fullUpdateNeeded = 0
	client.updatesReceived = 0
	client.bellPending = 0
	client.viewOnly = 0
	client.sharedSession = -1
	client.preferRaw = 0
	client.threadedSession = 0
	client.threadState = 0
	client.receiveOffset = 0
	client.receiveCount = 0
end sub

sub RfbDisconnect( byref client as RfbClient )
	NetClose( client.socketHandle )
	if( client.framebuffer <> 0 ) then
		deallocate client.framebuffer
		client.framebuffer = 0
	end if
	client.framebufferBytes = 0
	client.framebufferDirtyValid = 0
	client.framebufferDirtyLeft = 0
	client.framebufferDirtyTop = 0
	client.framebufferDirtyRight = 0
	client.framebufferDirtyBottom = 0
	client.connected = 0
	client.requestPending = 0
	client.threadedSession = 0
	client.threadState = 0
	client.receiveOffset = 0
	client.receiveCount = 0
end sub

function RfbConnect( byref client as RfbClient, byref options as VncOptions ) as integer
	dim as ubyte versionBytes( 0 to 11 )
	dim as string serverVersion
	dim as string clientVersion
	dim as integer serverMajor
	dim as integer serverMinor
	dim as ubyte initialisationByte
	dim as ubyte serverInitialisation( 0 to 23 )
	dim as ulong nameLength
	dim as string errorText

	RfbDisconnect( client )
	client.errorMessage = ""
	client.desktopName = ""
	client.clipboardText = ""
	client.updatesReceived = 0
	client.viewOnly = options.viewOnly
	client.sharedSession = options.sharedSession
	client.preferRaw = options.preferRaw
	client.threadedSession = 0
	client.threadState = 0
	if( RfbHostIsLoopback( options.host ) ) then client.preferRaw = -1
	client.receiveOffset = 0
	client.receiveCount = 0

	if( NetOpen( options.host, options.port, client.socketHandle, errorText ) = 0 ) then
		return RfbFail( client, errorText )
	end if

	if( RfbRead( client, @versionBytes( 0 ), 12 ) = 0 ) then goto connection_failed
	serverVersion = space( 12 )
	for index as integer = 0 to 11
		mid( serverVersion, index + 1, 1 ) = chr( versionBytes( index ) )
	next index

	if( left( serverVersion, 4 ) <> "RFB " orelse mid( serverVersion, 8, 1 ) <> "." ) then
		RfbFail( client, "The server did not send a valid RFB protocol banner." )
		goto connection_failed
	end if

	serverMajor = valint( mid( serverVersion, 5, 3 ) )
	serverMinor = valint( mid( serverVersion, 9, 3 ) )
	if( serverMajor <> 3 orelse serverMinor < 3 ) then
		RfbFail( client, "The server's RFB protocol version is not supported." )
		goto connection_failed
	end if

	if( serverMinor >= 8 ) then
		client.protocolMinor = 8
	elseif( serverMinor >= 7 ) then
		client.protocolMinor = 7
	else
		client.protocolMinor = 3
	end if

	clientVersion = "RFB 003.00" & str( client.protocolMinor ) & chr( 10 )
	if( RfbWrite( client, cptr( const ubyte ptr, strptr( clientVersion ) ), 12 ) = 0 ) then goto connection_failed
	if( RfbNegotiateSecurity( client, options.password ) = 0 ) then goto connection_failed

	if( options.sharedSession ) then
		initialisationByte = 1
	else
		initialisationByte = 0
	end if
	if( RfbWrite( client, @initialisationByte, 1 ) = 0 ) then goto connection_failed

	if( RfbRead( client, @serverInitialisation( 0 ), 24 ) = 0 ) then goto connection_failed
	if( RfbAllocateFramebuffer( client, ReadU16BE( @serverInitialisation( 0 ) ), ReadU16BE( @serverInitialisation( 2 ) ) ) = 0 ) then goto connection_failed

	nameLength = ReadU32BE( @serverInitialisation( 20 ) )
	if( RfbReadString( client, nameLength, VNC_MAX_DESKTOP_NAME_BYTES, client.desktopName ) = 0 ) then goto connection_failed

	if( RfbSendPixelFormat( client ) = 0 ) then goto connection_failed
	if( RfbSendEncodings( client ) = 0 ) then goto connection_failed
	client.connected = -1
	client.fullUpdateNeeded = 0
	if( RfbRequestUpdate( client, 0 ) = 0 ) then goto connection_failed

	return -1

connection_failed:
	NetClose( client.socketHandle )
	if( client.framebuffer <> 0 ) then
		deallocate client.framebuffer
		client.framebuffer = 0
	end if
	client.framebufferBytes = 0
	client.connected = 0
	client.receiveOffset = 0
	client.receiveCount = 0
	return 0
end function

function RfbHasMessage( byref client as RfbClient ) as integer
	if( client.connected = 0 ) then return 0
	/' A threaded decoder waits on its byte pipe instead of polling here. '/
	if( client.threadState <> 0 ) then return 0
	if( client.receiveCount > 0 ) then return -1
	if( NetConnectionEnded( client.socketHandle ) ) then return -1
	return NetHasData( client.socketHandle )
end function

function RfbProcessOneMessage( byref client as RfbClient ) as integer
	dim as ubyte messageType
	dim as ubyte header( 0 to 6 )
	dim as ulong byteCount
	dim as integer colourCount
	dim as string clipboardText

	if( client.connected = 0 ) then
		return RfbFail( client, "There is no active VNC connection." )
	end if

	if( client.threadState = 0 andalso client.receiveCount = 0 andalso NetConnectionEnded( client.socketHandle ) ) then
		client.connected = 0
		return RfbFail( client, "The server closed the connection." )
	end if

	if( RfbRead( client, @messageType, 1 ) = 0 ) then return 0

	select case messageType
	case RFB_SERVER_FRAMEBUFFER_UPDATE
		return RfbProcessFramebufferUpdate( client )

	case RFB_SERVER_SET_COLOUR_MAP
		if( RfbRead( client, @header( 0 ), 5 ) = 0 ) then return 0
		colourCount = ReadU16BE( @header( 3 ) )
		if( RfbDiscard( client, culngint( colourCount ) * 6u ) = 0 ) then return 0

	case RFB_SERVER_BELL
		VncFramebufferLock client
		client.bellPending = -1
		VncFramebufferUnlock client

	case RFB_SERVER_CUT_TEXT
		if( RfbRead( client, @header( 0 ), 7 ) = 0 ) then return 0
		byteCount = ReadU32BE( @header( 3 ) )
		if( RfbReadString( client, byteCount, VNC_MAX_CLIPBOARD_BYTES, clipboardText ) = 0 ) then return 0
		VncFramebufferLock client
		client.clipboardText = clipboardText
		VncFramebufferUnlock client

	case else
		return RfbFail( client, "The server sent an unsupported message type " & str( messageType ) & "." )
	end select

	return -1
end function

function RfbRequestUpdate( byref client as RfbClient, byval incremental as integer ) as integer
	dim as ubyte message( 0 to 9 )

	if( client.connected = 0 ) then return 0
	if( client.requestPending ) then
		if( incremental = 0 ) then client.fullUpdateNeeded = -1
		return -1
	end if

	message( 0 ) = RFB_CLIENT_UPDATE_REQUEST
	if( incremental ) then
		message( 1 ) = 1
	else
		message( 1 ) = 0
	end if
	WriteU16BE( @message( 2 ), 0 )
	WriteU16BE( @message( 4 ), 0 )
	WriteU16BE( @message( 6 ), cushort( client.serverWidth ) )
	WriteU16BE( @message( 8 ), cushort( client.serverHeight ) )

	if( RfbWrite( client, @message( 0 ), 10 ) = 0 ) then return 0
	client.requestPending = -1
	return -1
end function

function RfbSendPointer( byref client as RfbClient, byval x as integer, byval y as integer, byval buttonMask as integer ) as integer
	dim as ubyte message( 0 to 5 )

	if( client.connected = 0 orelse client.viewOnly ) then return -1
	if( client.serverWidth < 1 orelse client.serverHeight < 1 ) then return -1

	if( x < 0 ) then x = 0
	if( y < 0 ) then y = 0
	if( x >= client.serverWidth ) then x = client.serverWidth - 1
	if( y >= client.serverHeight ) then y = client.serverHeight - 1

	message( 0 ) = RFB_CLIENT_POINTER_EVENT
	message( 1 ) = cubyte( buttonMask and 255 )
	WriteU16BE( @message( 2 ), cushort( x ) )
	WriteU16BE( @message( 4 ), cushort( y ) )

	return RfbWrite( client, @message( 0 ), 6 )
end function

function RfbSendKey( byref client as RfbClient, byval keysym as ulong, byval isDown as integer ) as integer
	dim as ubyte message( 0 to 7 )

	if( client.connected = 0 orelse client.viewOnly ) then return -1

	for index as integer = 0 to 7
		message( index ) = 0
	next index
	message( 0 ) = RFB_CLIENT_KEY_EVENT
	if( isDown ) then message( 1 ) = 1
	WriteU32BE( @message( 4 ), keysym )

	return RfbWrite( client, @message( 0 ), 8 )
end function

function RfbSendClipboard( byref client as RfbClient, byref text as const string ) as integer
	dim as ubyte header( 0 to 7 )
	dim as ubyte ptr message
	dim as ulong byteCount
	dim as integer result

	if( client.connected = 0 orelse client.viewOnly ) then return -1
	if( len( text ) > VNC_MAX_CLIPBOARD_BYTES ) then
		return RfbFail( client, "The clipboard text exceeds the safety limit." )
	end if

	for index as integer = 0 to 7
		header( index ) = 0
	next index
	header( 0 ) = RFB_CLIENT_CUT_TEXT
	byteCount = len( text )
	WriteU32BE( @header( 4 ), byteCount )

	/'
	    The threaded writer must enqueue ClientCutText as one indivisible RFB
	    message. Otherwise a decoder-generated update request could be inserted
	    between its header and text. The serial path keeps its allocation-free
	    two-write behavior.
	'/
	if( client.threadState <> 0 ) then
		message = allocate( culngint( byteCount ) + 8u )
		if( message = 0 ) then return RfbFail( client, "There is not enough memory to send the clipboard text." )
		for index as integer = 0 to 7
			message[index] = header( index )
		next index
		if( byteCount > 0 ) then
			__builtin_memcpy message + 8u, strptr( text ), byteCount
		end if
		result = RfbWrite( client, message, culngint( byteCount ) + 8u )
		deallocate message
		return result
	end if

	if( RfbWrite( client, @header( 0 ), 8 ) = 0 ) then return 0
	if( byteCount > 0 ) then
		if( RfbWrite( client, cptr( const ubyte ptr, strptr( text ) ), byteCount ) = 0 ) then return 0
	end if

	return -1
end function

function RfbSendCtrlAltDelete( byref client as RfbClient ) as integer
	if( RfbSendKey( client, &hFFE3u, -1 ) = 0 ) then return 0
	if( RfbSendKey( client, &hFFE9u, -1 ) = 0 ) then return 0
	if( RfbSendKey( client, &hFFFFu, -1 ) = 0 ) then return 0
	if( RfbSendKey( client, &hFFFFu, 0 ) = 0 ) then return 0
	if( RfbSendKey( client, &hFFE9u, 0 ) = 0 ) then return 0
	return RfbSendKey( client, &hFFE3u, 0 )
end function

function RfbSendCtrlEscape( byref client as RfbClient ) as integer
	if( RfbSendKey( client, &hFFE3u, -1 ) = 0 ) then return 0
	if( RfbSendKey( client, &hFF1Bu, -1 ) = 0 ) then return 0
	if( RfbSendKey( client, &hFF1Bu, 0 ) = 0 ) then return 0
	return RfbSendKey( client, &hFFE3u, 0 )
end function

/' end of rfb.bas '/
