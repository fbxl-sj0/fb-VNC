/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: threads.bas

    Purpose:

        Run communications and RFB decoding concurrently when threads exist.

    Responsibilities:

        - transfer OPEN TCP bytes through bounded incoming and outgoing pipes
        - run the RFB decoder independently from communications
        - stop and join workers without abandoning shared memory
        - fall back cleanly when the target or runtime cannot create threads

    This file intentionally does NOT contain:

        - protocol message layouts or encoding decoders
        - graphics rendering or window event processing
        - platform-native thread or socket APIs
'/

#include once "threads.bi"
#include once "network.bi"
#include once "rfb.bi"
#include once "builtin.bi"

#if VNC_THREAD_SUPPORT

/'
    Incoming framebuffer traffic dominates a busy VNC session. A 1 MiB GET
    amortizes OPEN TCP readiness and runtime bookkeeping without requiring a
    second staging buffer. Outgoing input and clipboard messages remain capped
    at 64 KiB per PUT so they cannot monopolize the communications worker.
'/
const VNC_INCOMING_CHUNK_BYTES = 1048576
const VNC_OUTGOING_CHUNK_BYTES = 65536

/' ------------------------------------------------------------------------- '/
/' Shared-state helpers                                                      '/
/' ------------------------------------------------------------------------- '/

private function ThreadStopWasRequested( byval state as VncThreadState ptr ) as integer
	dim as integer requested

	mutexlock state->stateMutex
	requested = state->stopRequested
	mutexunlock state->stateMutex
	return requested
end function

private sub WakeAllWorkers( byval state as VncThreadState ptr )
	mutexlock state->stateMutex
	condbroadcast state->startCondition
	mutexunlock state->stateMutex

	mutexlock state->incomingMutex
	condbroadcast state->incomingCanRead
	condbroadcast state->incomingCanWrite
	mutexunlock state->incomingMutex

	mutexlock state->outgoingMutex
	condbroadcast state->outgoingCanWrite
	mutexunlock state->outgoingMutex
end sub

private sub RequestWorkerStop( byval state as VncThreadState ptr )
	mutexlock state->stateMutex
	state->stopRequested = -1
	state->workersReleased = -1
	condbroadcast state->startCondition
	mutexunlock state->stateMutex

	mutexlock state->incomingMutex
	condbroadcast state->incomingCanRead
	condbroadcast state->incomingCanWrite
	mutexunlock state->incomingMutex

	mutexlock state->outgoingMutex
	condbroadcast state->outgoingCanWrite
	mutexunlock state->outgoingMutex
end sub

private sub ReportWorkerFailure( byval state as VncThreadState ptr, byref message as const string )
	mutexlock state->stateMutex
	if( state->stopRequested = 0 ) then
		state->failed = -1
		state->errorMessage = message
	end if
	state->stopRequested = -1
	state->workersReleased = -1
	condbroadcast state->startCondition
	mutexunlock state->stateMutex

	WakeAllWorkers state
end sub

private function WaitForWorkerRelease( byval state as VncThreadState ptr ) as integer
	mutexlock state->stateMutex
	while( state->workersReleased = 0 andalso state->stopRequested = 0 )
		condwait state->startCondition, state->stateMutex
	wend
	dim as integer mayRun = ( state->stopRequested = 0 )
	mutexunlock state->stateMutex
	return mayRun
end function

/' ------------------------------------------------------------------------- '/
/' Bounded byte pipes                                                        '/
/' ------------------------------------------------------------------------- '/

private sub CopyBytes( byval destination as ubyte ptr, byval source as const ubyte ptr, byval byteCount as integer )
	/'
	    __builtin_memcpy is a FreeBASIC compiler intrinsic, not a platform API.
	    It lets each supported compiler target select its efficient native block
	    copy without defeating the viewer's -exx pointer validation elsewhere.
	'/
	if( destination = 0 orelse source = 0 orelse byteCount < 1 ) then exit sub
	__builtin_memcpy destination, source, byteCount
end sub

private function PopOutgoing( byval state as VncThreadState ptr, byval destination as ubyte ptr, byval maximumBytes as integer ) as integer
	dim as integer copyCount

	mutexlock state->outgoingMutex
	if( state->outgoingCount = 0 ) then
		mutexunlock state->outgoingMutex
		return 0
	end if

	copyCount = VNC_OUTGOING_PIPE_BYTES - state->outgoingHead
	if( copyCount > state->outgoingCount ) then copyCount = state->outgoingCount
	if( copyCount > maximumBytes ) then copyCount = maximumBytes
	CopyBytes destination, state->outgoingData + state->outgoingHead, copyCount
	state->outgoingHead = ( state->outgoingHead + copyCount ) mod VNC_OUTGOING_PIPE_BYTES
	state->outgoingCount -= copyCount
	condsignal state->outgoingCanWrite
	mutexunlock state->outgoingMutex
	return copyCount
end function

function VncThreadRead( byval statePointer as any ptr, byval buffer as ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
	dim as VncThreadState ptr state = cptr( VncThreadState ptr, statePointer )
	dim as ulongint totalRead = 0
	dim as integer copyCount

	errorText = ""
	if( state = 0 orelse buffer = 0 ) then
		errorText = "An invalid threaded RFB read was requested."
		return 0
	end if
	if( byteCount = 0 ) then return -1

	while( totalRead < byteCount )
		mutexlock state->incomingMutex
		while( state->incomingCount = 0 andalso ThreadStopWasRequested( state ) = 0 )
			condwait state->incomingCanRead, state->incomingMutex
		wend

		if( state->incomingCount = 0 andalso ThreadStopWasRequested( state ) ) then
			mutexunlock state->incomingMutex
			errorText = "The threaded RFB transport stopped."
			return 0
		end if

		copyCount = VNC_INCOMING_PIPE_BYTES - state->incomingHead
		if( copyCount > state->incomingCount ) then copyCount = state->incomingCount
		if( culngint( copyCount ) > byteCount - totalRead ) then copyCount = cint( byteCount - totalRead )
		CopyBytes buffer + totalRead, state->incomingData + state->incomingHead, copyCount
		state->incomingHead = ( state->incomingHead + copyCount ) mod VNC_INCOMING_PIPE_BYTES
		state->incomingCount -= copyCount
		totalRead += culngint( copyCount )
		condsignal state->incomingCanWrite
		mutexunlock state->incomingMutex
	wend

	return -1
end function

function VncThreadReadAvailable( byval statePointer as any ptr, byval buffer as ubyte ptr, byval maximumBytes as integer, byref bytesRead as integer, byref errorText as string ) as integer
	dim as VncThreadState ptr state = cptr( VncThreadState ptr, statePointer )
	dim as integer copyCount
	dim as integer remainingCapacity

	bytesRead = 0
	errorText = ""
	if( state = 0 orelse buffer = 0 orelse maximumBytes < 1 ) then
		errorText = "An invalid threaded buffered read was requested."
		return 0
	end if

	mutexlock state->incomingMutex
	while( state->incomingCount = 0 andalso ThreadStopWasRequested( state ) = 0 )
		condwait state->incomingCanRead, state->incomingMutex
	wend

	if( state->incomingCount = 0 andalso ThreadStopWasRequested( state ) ) then
		mutexunlock state->incomingMutex
		errorText = "The threaded RFB transport stopped."
		return 0
	end if

	while( state->incomingCount > 0 andalso bytesRead < maximumBytes )
		remainingCapacity = maximumBytes - bytesRead
		copyCount = VNC_INCOMING_PIPE_BYTES - state->incomingHead
		if( copyCount > state->incomingCount ) then copyCount = state->incomingCount
		if( copyCount > remainingCapacity ) then copyCount = remainingCapacity
		CopyBytes buffer + bytesRead, state->incomingData + state->incomingHead, copyCount
		state->incomingHead = ( state->incomingHead + copyCount ) mod VNC_INCOMING_PIPE_BYTES
		state->incomingCount -= copyCount
		bytesRead += copyCount
	wend

	condsignal state->incomingCanWrite
	mutexunlock state->incomingMutex
	return -1
end function

function VncThreadWrite( byval statePointer as any ptr, byval buffer as const ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
	dim as VncThreadState ptr state = cptr( VncThreadState ptr, statePointer )
	dim as ulongint totalWritten = 0
	dim as integer copyCount
	dim as integer freeBytes

	errorText = ""
	if( state = 0 orelse buffer = 0 ) then
		errorText = "An invalid threaded RFB write was requested."
		return 0
	end if
	if( byteCount = 0 ) then return -1

	/' Only one complete RFB message may enter the byte pipe at a time. '/
	mutexlock state->outgoingWriterMutex
	while( totalWritten < byteCount )
		mutexlock state->outgoingMutex
		while( state->outgoingCount = VNC_OUTGOING_PIPE_BYTES andalso ThreadStopWasRequested( state ) = 0 )
			condwait state->outgoingCanWrite, state->outgoingMutex
		wend

		if( ThreadStopWasRequested( state ) ) then
			mutexunlock state->outgoingMutex
			mutexunlock state->outgoingWriterMutex
			errorText = "The threaded RFB transport stopped."
			return 0
		end if

		freeBytes = VNC_OUTGOING_PIPE_BYTES - state->outgoingCount
		copyCount = VNC_OUTGOING_PIPE_BYTES - state->outgoingTail
		if( copyCount > freeBytes ) then copyCount = freeBytes
		if( culngint( copyCount ) > byteCount - totalWritten ) then copyCount = cint( byteCount - totalWritten )
		CopyBytes state->outgoingData + state->outgoingTail, buffer + totalWritten, copyCount
		state->outgoingTail = ( state->outgoingTail + copyCount ) mod VNC_OUTGOING_PIPE_BYTES
		state->outgoingCount += copyCount
		totalWritten += culngint( copyCount )
		mutexunlock state->outgoingMutex
	wend
	mutexunlock state->outgoingWriterMutex

	return -1
end function

/' ------------------------------------------------------------------------- '/
/' Worker procedures                                                         '/
/' ------------------------------------------------------------------------- '/

private sub CommunicationsWorker( byval parameter as any ptr )
	dim as VncThreadState ptr state = cptr( VncThreadState ptr, parameter )
	dim as ubyte outgoingBytes( 0 to VNC_OUTGOING_CHUNK_BYTES - 1 )
	dim as integer outgoingCount
	dim as integer incomingMaximum
	dim as integer incomingCount
	dim as integer incomingTail
	dim as string errorText
	dim as integer readResult

	if( state = 0 ) then exit sub
	if( WaitForWorkerRelease( state ) = 0 ) then exit sub

	while( ThreadStopWasRequested( state ) = 0 )
		outgoingCount = PopOutgoing( state, @outgoingBytes( 0 ), VNC_OUTGOING_CHUNK_BYTES )
		if( outgoingCount > 0 ) then
			if( NetWriteExact( state->client->socketHandle, @outgoingBytes( 0 ), outgoingCount, errorText ) = 0 ) then
				ReportWorkerFailure state, errorText
				exit while
			end if
		end if

		/'
		    There is only one incoming producer, so the tail cannot move while
		    this worker performs the non-blocking GET. The decoder can only free
		    more of the reserved span. Releasing the pipe mutex here prevents a
		    runtime socket check from delaying a ready decoder.
		'/
		mutexlock state->incomingMutex
		while( state->incomingCount = VNC_INCOMING_PIPE_BYTES andalso ThreadStopWasRequested( state ) = 0 )
			condwait state->incomingCanWrite, state->incomingMutex
		wend
		if( ThreadStopWasRequested( state ) ) then
			mutexunlock state->incomingMutex
			exit while
		end if

		incomingTail = state->incomingTail
		incomingMaximum = VNC_INCOMING_PIPE_BYTES - incomingTail
		if( incomingMaximum > VNC_INCOMING_PIPE_BYTES - state->incomingCount ) then
			incomingMaximum = VNC_INCOMING_PIPE_BYTES - state->incomingCount
		end if
		if( incomingMaximum > VNC_INCOMING_CHUNK_BYTES ) then incomingMaximum = VNC_INCOMING_CHUNK_BYTES
		mutexunlock state->incomingMutex

		/' NetReadSomeNow performs the one required EOC and EOF check. '/
		readResult = NetReadSomeNow( _
			state->client->socketHandle, state->incomingData + incomingTail, _
			incomingMaximum, incomingCount, errorText _
		)
		if( readResult = 0 ) then
			ReportWorkerFailure state, errorText
			exit while
		end if

		if( incomingCount > 0 ) then
			mutexlock state->incomingMutex
			if( state->incomingTail <> incomingTail orelse _
				incomingCount > incomingMaximum orelse _
				incomingCount > VNC_INCOMING_PIPE_BYTES - state->incomingCount ) then
				mutexunlock state->incomingMutex
				ReportWorkerFailure state, "The threaded incoming pipe lost producer ownership."
				exit while
			end if
			state->incomingTail = ( incomingTail + incomingCount ) mod VNC_INCOMING_PIPE_BYTES
			state->incomingCount += incomingCount
			condsignal state->incomingCanRead
			mutexunlock state->incomingMutex
		elseif( outgoingCount = 0 ) then
			/' Two milliseconds retains interactive input latency while reducing idle polling. '/
			sleep 2, 1
		end if
	wend
end sub

private sub DecoderWorker( byval parameter as any ptr )
	dim as VncThreadState ptr state = cptr( VncThreadState ptr, parameter )
	dim as string errorText
	dim as integer continueRunning

	if( state = 0 ) then exit sub
	if( WaitForWorkerRelease( state ) = 0 ) then exit sub

	do
		if( RfbProcessOneMessage( *state->client ) = 0 ) then
			if( ThreadStopWasRequested( state ) = 0 ) then
				errorText = state->client->errorMessage
				if( len( errorText ) = 0 ) then errorText = "The RFB decoder stopped unexpectedly."
				ReportWorkerFailure state, errorText
			end if
			exit do
		end if

		mutexlock state->stateMutex
		state->generation += 1
		continueRunning = ( state->stopRequested = 0 )
		mutexunlock state->stateMutex
	loop while( continueRunning )
end sub

/' ------------------------------------------------------------------------- '/
/' Lifecycle                                                                 '/
/' ------------------------------------------------------------------------- '/

private sub DestroyThreadResources( byref state as VncThreadState )
	if( state.startCondition <> 0 ) then conddestroy state.startCondition
	if( state.incomingCanRead <> 0 ) then conddestroy state.incomingCanRead
	if( state.incomingCanWrite <> 0 ) then conddestroy state.incomingCanWrite
	if( state.outgoingCanWrite <> 0 ) then conddestroy state.outgoingCanWrite
	if( state.stateMutex <> 0 ) then mutexdestroy state.stateMutex
	if( state.incomingMutex <> 0 ) then mutexdestroy state.incomingMutex
	if( state.outgoingMutex <> 0 ) then mutexdestroy state.outgoingMutex
	if( state.outgoingWriterMutex <> 0 ) then mutexdestroy state.outgoingWriterMutex
	if( state.framebufferMutex <> 0 ) then mutexdestroy state.framebufferMutex
	if( state.incomingData <> 0 ) then deallocate state.incomingData
	if( state.outgoingData <> 0 ) then deallocate state.outgoingData

	state.startCondition = 0
	state.incomingCanRead = 0
	state.incomingCanWrite = 0
	state.outgoingCanWrite = 0
	state.stateMutex = 0
	state.incomingMutex = 0
	state.outgoingMutex = 0
	state.outgoingWriterMutex = 0
	state.framebufferMutex = 0
	state.incomingData = 0
	state.outgoingData = 0
end sub

sub VncThreadsInitialise( byref state as VncThreadState )
	state.client = 0
	state.communicationsThread = 0
	state.decoderThread = 0
	state.stateMutex = 0
	state.startCondition = 0
	state.incomingMutex = 0
	state.incomingCanRead = 0
	state.incomingCanWrite = 0
	state.outgoingMutex = 0
	state.outgoingWriterMutex = 0
	state.outgoingCanWrite = 0
	state.framebufferMutex = 0
	state.incomingData = 0
	state.incomingHead = 0
	state.incomingTail = 0
	state.incomingCount = 0
	state.outgoingData = 0
	state.outgoingHead = 0
	state.outgoingTail = 0
	state.outgoingCount = 0
	state.workersReleased = 0
	state.stopRequested = 0
	state.failed = 0
	state.active = 0
	state.generation = 0
	state.errorMessage = ""
end sub

function VncThreadsStart( byref state as VncThreadState, byref client as RfbClient, byref fallbackReason as string ) as integer
	fallbackReason = ""
	if( state.active ) then return -1

	VncThreadsInitialise state
	state.client = @client
	state.incomingData = allocate( VNC_INCOMING_PIPE_BYTES )
	state.outgoingData = allocate( VNC_OUTGOING_PIPE_BYTES )
	state.stateMutex = mutexcreate()
	state.startCondition = condcreate()
	state.incomingMutex = mutexcreate()
	state.incomingCanRead = condcreate()
	state.incomingCanWrite = condcreate()
	state.outgoingMutex = mutexcreate()
	state.outgoingWriterMutex = mutexcreate()
	state.outgoingCanWrite = condcreate()
	state.framebufferMutex = mutexcreate()

	if( state.incomingData = 0 orelse state.outgoingData = 0 orelse _
		state.stateMutex = 0 orelse state.startCondition = 0 orelse _
		state.incomingMutex = 0 orelse state.incomingCanRead = 0 orelse state.incomingCanWrite = 0 orelse _
		state.outgoingMutex = 0 orelse state.outgoingWriterMutex = 0 orelse _
		state.outgoingCanWrite = 0 orelse _
		state.framebufferMutex = 0 ) then
		fallbackReason = "Thread synchronization could not be allocated."
		DestroyThreadResources state
		return 0
	end if

	client.threadState = @state
	state.decoderThread = threadcreate( @DecoderWorker, @state )
	if( state.decoderThread <> 0 ) then
		state.communicationsThread = threadcreate( @CommunicationsWorker, @state )
	end if

	if( state.decoderThread = 0 orelse state.communicationsThread = 0 ) then
		fallbackReason = "The runtime could not create both VNC worker threads."
		RequestWorkerStop @state
		if( state.communicationsThread <> 0 ) then threadwait state.communicationsThread
		if( state.decoderThread <> 0 ) then threadwait state.decoderThread
		client.threadState = 0
		DestroyThreadResources state
		VncThreadsInitialise state
		return 0
	end if

	/' Preserve any bytes read past the serial handshake before releasing workers. '/
	if( client.receiveCount > 0 ) then
		CopyBytes( _
			state.incomingData, @client.receiveBuffer( 0 ) + client.receiveOffset, _
			client.receiveCount _
		)
		state.incomingTail = client.receiveCount
		state.incomingCount = client.receiveCount
		client.receiveOffset = 0
		client.receiveCount = 0
	end if

	state.active = -1
	client.threadedSession = -1
	mutexlock state.stateMutex
	state.workersReleased = -1
	condbroadcast state.startCondition
	mutexunlock state.stateMutex
	return -1
end function

sub VncThreadsStop( byref state as VncThreadState )
	if( state.active = 0 ) then exit sub

	RequestWorkerStop @state
	if( state.communicationsThread <> 0 ) then threadwait state.communicationsThread
	if( state.decoderThread <> 0 ) then threadwait state.decoderThread

	if( state.client <> 0 ) then
		state.client->threadState = 0
		state.client->threadedSession = 0
	end if
	state.active = 0
	DestroyThreadResources state
	VncThreadsInitialise state
end sub

function VncThreadsActive( byref state as VncThreadState ) as integer
	return state.active
end function

function VncThreadsPoll( byref state as VncThreadState, byref generation as ulong, byref errorText as string ) as integer
	dim as integer didFail

	errorText = ""
	generation = 0
	if( state.active = 0 ) then return 0
	mutexlock state.stateMutex
	didFail = state.failed
	generation = state.generation
	if( didFail ) then errorText = state.errorMessage
	mutexunlock state.stateMutex
	return didFail
end function

sub VncFramebufferLock( byref client as RfbClient )
	if( client.threadState <> 0 ) then
		mutexlock cptr( VncThreadState ptr, client.threadState )->framebufferMutex
	end if
end sub

sub VncFramebufferUnlock( byref client as RfbClient )
	if( client.threadState <> 0 ) then
		mutexunlock cptr( VncThreadState ptr, client.threadState )->framebufferMutex
	end if
end sub

#else

/' ------------------------------------------------------------------------- '/
/' Serial fallback                                                           '/
/' ------------------------------------------------------------------------- '/

sub VncThreadsInitialise( byref state as VncThreadState )
	state.client = 0
	state.active = 0
	state.errorMessage = ""
end sub

function VncThreadsStart( byref state as VncThreadState, byref client as RfbClient, byref fallbackReason as string ) as integer
	state.client = @client
	state.active = 0
	client.threadState = 0
	client.threadedSession = 0
	fallbackReason = "This FreeBASIC target uses the serial session pipeline."
	return 0
end function

sub VncThreadsStop( byref state as VncThreadState )
	if( state.client <> 0 ) then
		state.client->threadState = 0
		state.client->threadedSession = 0
	end if
	state.active = 0
end sub

function VncThreadsActive( byref state as VncThreadState ) as integer
	return 0
end function

function VncThreadsPoll( byref state as VncThreadState, byref generation as ulong, byref errorText as string ) as integer
	errorText = ""
	generation = 0
	return 0
end function

function VncThreadRead( byval statePointer as any ptr, byval buffer as ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
	errorText = "The threaded transport is unavailable on this target."
	return 0
end function

function VncThreadReadAvailable( byval statePointer as any ptr, byval buffer as ubyte ptr, byval maximumBytes as integer, byref bytesRead as integer, byref errorText as string ) as integer
	bytesRead = 0
	errorText = "The threaded transport is unavailable on this target."
	return 0
end function

function VncThreadWrite( byval statePointer as any ptr, byval buffer as const ubyte ptr, byval byteCount as ulongint, byref errorText as string ) as integer
	errorText = "The threaded transport is unavailable on this target."
	return 0
end function

sub VncFramebufferLock( byref client as RfbClient )
end sub

sub VncFramebufferUnlock( byref client as RfbClient )
end sub

#endif

/' end of threads.bas '/
