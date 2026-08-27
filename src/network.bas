/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: network.bas

    Purpose:

        Implement the viewer transport exclusively through FreeBASIC OPEN TCP.

    Responsibilities:

        - open and close TCP file handles
        - distinguish EOF readiness from EOC disconnection
        - complete partial non-blocking binary reads safely
        - encode and decode RFB big-endian integers

    This file intentionally does NOT contain:

        - platform socket headers or native APIs
        - RFB handshaking or rectangle decoding
        - user interface event handling
'/

#include once "network.bi"

private function ElapsedMilliseconds( byval startedAt as double ) as ulong
	dim as double elapsed = timer - startedAt

	/' TIMER wraps at midnight. '/
	if( elapsed < 0.0 ) then
		elapsed += 86400.0
	end if

	return culng( elapsed * 1000.0 )
end function

function NetOpen( byref host as const string, byval port as integer, byref handle as integer, byref errorText as string ) as integer
	dim as string specification

	handle = 0
	errorText = ""

	if( len( host ) = 0 ) then
		errorText = "The server host is empty."
		return 0
	end if

	if( port < 1 orelse port > 65535 ) then
		errorText = "The TCP port must be between 1 and 65535."
		return 0
	end if

	handle = freefile()
	specification = "host=" & host & ",port=" & str( port )

	if( open tcp( specification as #handle ) <> 0 ) then
		errorText = "OPEN TCP failed with FreeBASIC error " & str( err ) & "."
		handle = 0
		return 0
	end if

	return -1
end function

sub NetClose( byref handle as integer )
	if( handle <> 0 ) then
		close #handle
		handle = 0
	end if
end sub

function NetHasData( byval handle as integer ) as integer
	if( handle = 0 ) then
		return 0
	end if

	/' On an OPEN TCP handle EOF means that no received byte is waiting. '/
	return ( eof( handle ) = 0 )
end function

function NetConnectionEnded( byval handle as integer ) as integer
	if( handle = 0 ) then
		return -1
	end if

	/' EOC is reserved for the connection-lost test, not readiness. '/
	return ( eoc( handle ) <> 0 )
end function

function NetReadSomeNow( byval handle as integer, byval buffer as ubyte ptr, byval maximumBytes as integer, byref bytesRead as integer, byref errorText as string ) as integer
	bytesRead = 0
	errorText = ""

	if( handle = 0 orelse buffer = 0 orelse maximumBytes < 1 ) then
		errorText = "An invalid non-blocking TCP read was requested."
		return 0
	end if

	if( NetConnectionEnded( handle ) ) then
		errorText = "The server closed the connection."
		return 0
	end if

	/' EOF means no byte is waiting, so this successful call has no payload. '/
	if( NetHasData( handle ) = 0 ) then return -1

	get #handle, , buffer[0], maximumBytes, bytesRead
	if( err <> 0 ) then
		errorText = "TCP read failed with FreeBASIC error " & str( err ) & "."
		bytesRead = 0
		return 0
	end if

	return -1
end function

function NetReadAvailable( byval handle as integer, byval buffer as ubyte ptr, byval maximumBytes as integer, byval timeoutMilliseconds as integer, byref bytesRead as integer, byref errorText as string ) as integer
	dim as double startedAt = timer

	bytesRead = 0
	errorText = ""

	if( handle = 0 orelse buffer = 0 orelse maximumBytes < 1 ) then
		errorText = "An invalid buffered TCP read was requested."
		return 0
	end if

	do
		if( NetConnectionEnded( handle ) ) then
			errorText = "The server closed the connection."
			return 0
		end if

		if( NetHasData( handle ) ) then
			get #handle, , buffer[0], maximumBytes, bytesRead
			if( err <> 0 ) then
				errorText = "TCP read failed with FreeBASIC error " & str( err ) & "."
				return 0
			end if
			if( bytesRead > 0 ) then return -1
		else
			sleep 1, 1
		end if

		if( timeoutMilliseconds >= 0 ) then
			if( ElapsedMilliseconds( startedAt ) >= culng( timeoutMilliseconds ) ) then
				errorText = "Timed out while waiting for data from the server."
				return 0
			end if
		end if
	loop
end function

function NetReadExact( byval handle as integer, byval buffer as ubyte ptr, byval byteCount as ulongint, byval timeoutMilliseconds as integer, byref errorText as string ) as integer
	dim as ulongint totalRead = 0
	dim as integer bytesRead
	dim as integer requested
	dim as double startedAt = timer

	errorText = ""

	if( handle = 0 orelse buffer = 0 ) then
		errorText = "An invalid TCP read was requested."
		return 0
	end if

	while( totalRead < byteCount )
		if( NetConnectionEnded( handle ) ) then
			errorText = "The server closed the connection."
			return 0
		end if

		if( NetHasData( handle ) ) then
			/' GET's byte-count argument is an Integer on all supported targets. '/
			if( byteCount - totalRead > 1048576 ) then
				requested = 1048576
			else
				requested = cint( byteCount - totalRead )
			end if

			bytesRead = 0
			get #handle, , buffer[totalRead], requested, bytesRead

			if( err <> 0 ) then
				errorText = "TCP read failed with FreeBASIC error " & str( err ) & "."
				return 0
			end if

			if( bytesRead > 0 ) then
				totalRead += culngint( bytesRead )
			end if
		else
			sleep 1, 1
		end if

		if( timeoutMilliseconds >= 0 ) then
			if( ElapsedMilliseconds( startedAt ) >= culng( timeoutMilliseconds ) ) then
				errorText = "Timed out while waiting for data from the server."
				return 0
			end if
		end if
	wend

	return -1
end function

function NetWriteExact( byval handle as integer, byval buffer as const ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
	dim as ulongint totalWritten = 0
	dim as integer requested

	errorText = ""

	if( handle = 0 orelse buffer = 0 ) then
		errorText = "An invalid TCP write was requested."
		return 0
	end if

	/'
	    OPEN TCP's PUT implementation completes each supplied buffer. The loop
	    only divides values that exceed the portable Integer byte-count limit.
	'/
	while( totalWritten < byteCount )
		if( byteCount - totalWritten > 1048576 ) then
			requested = 1048576
		else
			requested = cint( byteCount - totalWritten )
		end if

		put #handle, , buffer[totalWritten], requested

		if( err <> 0 ) then
			errorText = "TCP write failed with FreeBASIC error " & str( err ) & "."
			return 0
		end if

		totalWritten += culngint( requested )
	wend

	return -1
end function

function NetDiscard( byval handle as integer, byval byteCount as ulongint, byval timeoutMilliseconds as integer, byref errorText as string ) as integer
	dim as ubyte scratch( 0 to 4095 )
	dim as ulongint remaining = byteCount
	dim as ulongint chunkSize

	while( remaining > 0 )
		if( remaining > 4096 ) then
			chunkSize = 4096
		else
			chunkSize = remaining
		end if

		if( NetReadExact( handle, @scratch( 0 ), chunkSize, timeoutMilliseconds, errorText ) = 0 ) then
			return 0
		end if

		remaining -= chunkSize
	wend

	return -1
end function

function NetReadString( byval handle as integer, byval byteCount as ulong, byval maximumBytes as ulong, byval timeoutMilliseconds as integer, byref value as string, byref errorText as string ) as integer
	value = ""

	if( byteCount > maximumBytes ) then
		errorText = "The server supplied a string larger than the safety limit."
		return 0
	end if

	if( byteCount = 0 ) then
		return -1
	end if

	value = space( byteCount )
	if( NetReadExact( handle, cptr( ubyte ptr, strptr( value ) ), byteCount, timeoutMilliseconds, errorText ) = 0 ) then
		value = ""
		return 0
	end if

	return -1
end function

function ReadU16BE( byval buffer as const ubyte ptr ) as ushort
	if( buffer = 0 ) then
		return 0
	end if

	return cushort( cushort( buffer[0] ) shl 8 ) or cushort( buffer[1] )
end function

function ReadU32BE( byval buffer as const ubyte ptr ) as ulong
	if( buffer = 0 ) then
		return 0
	end if

	return ( culng( buffer[0] ) shl 24 ) or _
		( culng( buffer[1] ) shl 16 ) or _
		( culng( buffer[2] ) shl 8 ) or _
		culng( buffer[3] )
end function

sub WriteU16BE( byval buffer as ubyte ptr, byval value as ushort )
	if( buffer = 0 ) then
		exit sub
	end if

	buffer[0] = cubyte( ( value shr 8 ) and 255 )
	buffer[1] = cubyte( value and 255 )
end sub

sub WriteU32BE( byval buffer as ubyte ptr, byval value as ulong )
	if( buffer = 0 ) then
		exit sub
	end if

	buffer[0] = cubyte( ( value shr 24 ) and 255 )
	buffer[1] = cubyte( ( value shr 16 ) and 255 )
	buffer[2] = cubyte( ( value shr 8 ) and 255 )
	buffer[3] = cubyte( value and 255 )
end sub

/' end of network.bas '/
