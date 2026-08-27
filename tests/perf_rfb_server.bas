/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: perf_rfb_server.bas

    Purpose:

        Provide a repeatable localhost Raw RFB throughput workload.

    Responsibilities:

        - perform a minimal RFB 3.8 server handshake without authentication
        - consume the viewer's normal setup and framebuffer request messages
        - send a fixed number of complete 1920 by 1080 Raw frames
        - report frame and byte throughput for before-and-after comparisons

    This file intentionally does NOT contain:

        - VNC authentication
        - a graphical desktop or input handling
        - platform socket APIs
'/

#include once "network.bi"

const PERF_SERVER_HOST = "127.0.0.1"
/' A high non-standard port avoids colliding with a configured VNC display. '/
const PERF_SERVER_PORT = 5999
const PERF_FRAME_WIDTH = 1920
const PERF_FRAME_HEIGHT = 1080
const PERF_FRAME_COUNT = 120
const PERF_MAX_FRAME_COUNT = 10000
const PERF_MAX_ENCODING_COUNT = 1024
const PERF_MAX_CLIPBOARD_BYTES = 16777216u
const PERF_MAX_START_DELAY_MILLISECONDS = 60000
const PERF_SERVER_INITIALISATION_BYTES = 24
const PERF_FRAMEBUFFER_UPDATE_BYTES = 16

/' ------------------------------------------------------------------------- '/
/' RFB message helpers                                                       '/
/' ------------------------------------------------------------------------- '/

private function ReadClientBytes( byval handle as integer, byval buffer as ubyte ptr, byval byteCount as ulongint ) as integer
	dim as string errorText

	if( NetReadExact( handle, buffer, byteCount, -1, errorText ) = 0 ) then
		print "Client read failed: "; errorText
		return 0
	end if

	return -1
end function

private function DiscardClientBytes( byval handle as integer, byval byteCount as ulongint ) as integer
	dim as string errorText

	if( NetDiscard( handle, byteCount, -1, errorText ) = 0 ) then
		print "Client message discard failed: "; errorText
		return 0
	end if

	return -1
end function

private function WriteServerBytes( byval handle as integer, byval buffer as const ubyte ptr, byval byteCount as ulongint ) as integer
	dim as string errorText

	if( NetWriteExact( handle, buffer, byteCount, errorText ) = 0 ) then
		print "Server write failed: "; errorText
		return 0
	end if

	return -1
end function

private function WaitForFramebufferRequest( byval handle as integer ) as integer
	dim as ubyte messageType
	dim as ubyte header( 0 to 6 )
	dim as ulong payloadBytes
	dim as ushort encodingCount

	do
		if( ReadClientBytes( handle, @messageType, 1 ) = 0 ) then return 0

		select case messageType
		case 0
			/' SetPixelFormat has nineteen bytes after its message type. '/
			if( DiscardClientBytes( handle, 19 ) = 0 ) then return 0

		case 2
			if( ReadClientBytes( handle, @header( 0 ), 3 ) = 0 ) then return 0
			encodingCount = ReadU16BE( @header( 1 ) )
			if( encodingCount > PERF_MAX_ENCODING_COUNT ) then
				print "The viewer supplied an unreasonable encoding count."
				return 0
			end if
			if( DiscardClientBytes( handle, culngint( encodingCount ) * 4u ) = 0 ) then return 0

		case 3
			/' FramebufferUpdateRequest has nine bytes after its message type. '/
			return DiscardClientBytes( handle, 9 )

		case 4
			if( DiscardClientBytes( handle, 7 ) = 0 ) then return 0

		case 5
			if( DiscardClientBytes( handle, 5 ) = 0 ) then return 0

		case 6
			if( ReadClientBytes( handle, @header( 0 ), 7 ) = 0 ) then return 0
			payloadBytes = ReadU32BE( @header( 3 ) )
			if( payloadBytes > PERF_MAX_CLIPBOARD_BYTES ) then
				print "The viewer supplied an unreasonable clipboard length."
				return 0
			end if
			if( DiscardClientBytes( handle, payloadBytes ) = 0 ) then return 0

		case else
			print "Unsupported client message type:"; messageType
			return 0
		end select
	loop
end function

private function SendServerInitialisation( byval handle as integer ) as integer
	dim as ubyte initialisation( 0 to 23 )
	dim as string desktopName = "FreeBASIC Raw throughput benchmark"

	for index as integer = 0 to ubound( initialisation )
		initialisation( index ) = 0
	next index

	WriteU16BE @initialisation( 0 ), PERF_FRAME_WIDTH
	WriteU16BE @initialisation( 2 ), PERF_FRAME_HEIGHT
	initialisation( 4 ) = 32
	initialisation( 5 ) = 24
	initialisation( 6 ) = 0
	initialisation( 7 ) = 1
	WriteU16BE @initialisation( 8 ), 255
	WriteU16BE @initialisation( 10 ), 255
	WriteU16BE @initialisation( 12 ), 255
	initialisation( 14 ) = 16
	initialisation( 15 ) = 8
	initialisation( 16 ) = 0
	WriteU32BE @initialisation( 20 ), len( desktopName )

	/' Static array SizeOf reports one element in FreeBASIC, so use the RFB wire size. '/
	if( WriteServerBytes( handle, @initialisation( 0 ), PERF_SERVER_INITIALISATION_BYTES ) = 0 ) then return 0
	return WriteServerBytes( handle, cptr( const ubyte ptr, strptr( desktopName ) ), len( desktopName ) )
end function

/' ------------------------------------------------------------------------- '/
/' Benchmark                                                                 '/
/' ------------------------------------------------------------------------- '/

dim as integer serverHandle = freefile()
dim as integer clientHandle
dim as string serverSpecification
dim as string protocolVersion = !"RFB 003.008\n"
dim as ubyte protocolReply( 0 to 11 )
dim as ubyte securityTypes( 0 to 1 ) = { 1, 1 }
dim as ubyte securitySelection
dim as ubyte securityResult( 0 to 3 ) = { 0, 0, 0, 0 }
dim as ubyte sharedFlag
dim as ubyte updateHeader( 0 to 15 )
dim as ulong ptr framePixels
dim as ulongint framePixelCount = culngint( PERF_FRAME_WIDTH ) * PERF_FRAME_HEIGHT
dim as ulongint frameBytes = framePixelCount * 4u
dim as integer benchmarkFrameCount = PERF_FRAME_COUNT
dim as integer startDelayMilliseconds = 0
dim as double startedAt
dim as double elapsed

if( len( command( 1 ) ) > 0 ) then
	benchmarkFrameCount = valint( command( 1 ) )
	if( benchmarkFrameCount < 1 orelse benchmarkFrameCount > PERF_MAX_FRAME_COUNT ) then
		print "Frame count must be between 1 and"; PERF_MAX_FRAME_COUNT; "."
		end 1
	end if
end if

if( len( command( 2 ) ) > 0 ) then
	startDelayMilliseconds = valint( command( 2 ) )
	if( startDelayMilliseconds < 0 orelse startDelayMilliseconds > PERF_MAX_START_DELAY_MILLISECONDS ) then
		print "Start delay must be between 0 and"; PERF_MAX_START_DELAY_MILLISECONDS; " milliseconds."
		end 1
	end if
end if

serverSpecification = "host=" & PERF_SERVER_HOST & ",port=" & PERF_SERVER_PORT & ",backlog=1"
if( open tcp server( serverSpecification as #serverHandle ) <> 0 ) then
	print "OPEN TCP SERVER failed with FreeBASIC error"; err
	end 1
end if

print "Raw RFB benchmark listening on " & PERF_SERVER_HOST & "::" & ltrim( str( PERF_SERVER_PORT ) )
print "Connect fbvnc to 127.0.0.1::5999."
clientHandle = tcp accept( #serverHandle )
if( clientHandle = 0 ) then
	print "TCP ACCEPT failed with FreeBASIC error"; err
	close #serverHandle
	end 1
end if

if( WriteServerBytes( clientHandle, cptr( const ubyte ptr, strptr( protocolVersion ) ), 12 ) = 0 ) then end 1
if( ReadClientBytes( clientHandle, @protocolReply( 0 ), 12 ) = 0 ) then end 1
if( WriteServerBytes( clientHandle, @securityTypes( 0 ), 2 ) = 0 ) then end 1
if( ReadClientBytes( clientHandle, @securitySelection, 1 ) = 0 ) then end 1
if( securitySelection <> 1 ) then
	print "The viewer did not select the None security type."
	end 1
end if
if( WriteServerBytes( clientHandle, @securityResult( 0 ), 4 ) = 0 ) then end 1
if( ReadClientBytes( clientHandle, @sharedFlag, 1 ) = 0 ) then end 1
if( SendServerInitialisation( clientHandle ) = 0 ) then end 1
if( WaitForFramebufferRequest( clientHandle ) = 0 ) then end 1

framePixels = cptr( ulong ptr, allocate( frameBytes ) )
if( framePixels = 0 ) then
	print "Unable to allocate the benchmark framebuffer."
	end 1
end if

/' Knuth's multiplicative hash creates a cheap, deterministic high-detail image. '/
for pixelIndex as ulongint = 0 to framePixelCount - 1
	framePixels[pixelIndex] = ( culng( pixelIndex ) * 2654435761u ) and &h00FFFFFFu
next pixelIndex

for index as integer = 0 to ubound( updateHeader )
	updateHeader( index ) = 0
next index
updateHeader( 0 ) = 0
WriteU16BE @updateHeader( 2 ), 1
WriteU16BE @updateHeader( 4 ), 0
WriteU16BE @updateHeader( 6 ), 0
WriteU16BE @updateHeader( 8 ), PERF_FRAME_WIDTH
WriteU16BE @updateHeader( 10 ), PERF_FRAME_HEIGHT
WriteU32BE @updateHeader( 12 ), 0

if( startDelayMilliseconds > 0 ) then sleep startDelayMilliseconds, 1
startedAt = timer
for frameIndex as integer = 1 to benchmarkFrameCount
	/' Change a visible pixel so every completed frame has distinct contents. '/
	framePixels[( frameIndex - 1 ) mod framePixelCount] xor= &h00FFFFFFu
	if( WriteServerBytes( clientHandle, @updateHeader( 0 ), PERF_FRAMEBUFFER_UPDATE_BYTES ) = 0 ) then end 1
	if( WriteServerBytes( clientHandle, cptr( const ubyte ptr, framePixels ), frameBytes ) = 0 ) then end 1
	if( frameIndex < benchmarkFrameCount ) then
		if( WaitForFramebufferRequest( clientHandle ) = 0 ) then end 1
	end if
next frameIndex
elapsed = timer - startedAt
if( elapsed < 0.0 ) then elapsed += 86400.0
if( elapsed <= 0.0 ) then elapsed = 0.000001

print "Frames sent:"; benchmarkFrameCount
print "Elapsed seconds:"; elapsed
print "Frames/second:"; benchmarkFrameCount / elapsed
print "Payload MiB/second:"; ( cdbl( frameBytes ) * benchmarkFrameCount ) / elapsed / 1048576.0

deallocate framePixels
close #clientHandle
close #serverHandle

/' end of perf_rfb_server.bas '/
