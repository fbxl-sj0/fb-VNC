/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: ui.bas

    Purpose:

        Provide the complete portable viewer interface with gfxlib.

    Responsibilities:

        - connection dialog and in-session toolbar
        - resizable and full-screen window behavior
        - scale-to-fit and one-to-one framebuffer presentation
        - portable keyboard, pointer, clipboard, and scroll-bar interaction
        - connection information and options overlays

    This file intentionally does NOT contain:

        - operating-system window, clipboard, or input APIs
        - RFB wire parsing
        - framebuffer encoding decoders
'/

#define OMAGUI_PORTABLE_ONLY
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI-main/omaGUI.bi"
#Ifdef __FB_GFXLIB3__
#include once "fbgfx3.bi"
#include once "builtin.bi"
#EndIf
#include once "ui.bi"
#include once "rfb.bi"
#include once "scaler.bi"
#include once "threads.bi"

using fb

const UI_MODE_CONNECTION = 0
const UI_MODE_SESSION = 1

const UI_OVERLAY_NONE = 0
const UI_OVERLAY_OPTIONS = 1
const UI_OVERLAY_INFO = 2
const UI_OVERLAY_CLIPBOARD = 3

const UI_TOOLBAR_HEIGHT = 42
const UI_STATUS_HEIGHT = 24
const UI_SCROLLBAR_SIZE = 14
/' A faster producer should replace pending video frames, not present above 60 Hz. '/
const UI_THREADED_FRAME_INTERVAL_SECONDS = 1.0 / 60.0

type UiLayout
	contentTop as integer
	contentBottom as integer
	viewLeft as integer
	viewTop as integer
	viewWidth as integer
	viewHeight as integer
	destinationX as integer
	destinationY as integer
	destinationWidth as integer
	destinationHeight as integer
	showScrollbars as integer
end type

type UiClientSnapshot
	desktopName as string
	serverWidth as integer
	serverHeight as integer
	protocolMinor as integer
	updatesReceived as ulong
	threadedSession as integer
	bellPending as integer
	preferRaw as integer
end type

type UiState
	windowWidth as integer
	windowHeight as integer
	running as integer
	mode as integer
	activeField as integer
	overlay as integer
	needsRedraw as integer
	fullScreen as integer
	fullScreenHotkeyActive as integer
	controlHeld as integer
	altHeld as integer
	leftShiftHeld as integer
	rightShiftHeld as integer
	savedWindowWidth as integer
	savedWindowHeight as integer
	scrollX as integer
	scrollY as integer
	pointerMask as integer
	pointerX as integer
	pointerY as integer
	lastWheelZ as integer
	clipboardDraft as string
	statusText as string
	threadFallbackReason as string
	lastUpdateCount as ulong
	lastThreadGeneration as ulong
	threadFramePending as integer
	lastThreadFrameTime as double
	threadState as VncThreadState ptr
	frameImage as any ptr
	frameImagePixels as uByte ptr
	frameImageWidth as integer
	frameImageHeight as integer
	frameImagePitch as integer
#Ifdef __FB_GFXLIB3__
	frameSurface as any ptr
	frameSurfaceWidth as integer
	frameSurfaceHeight as integer
	frameSurfaceReady as integer
	frameUploadPixels as ubyte ptr
	frameUploadCapacity as ulongint
	scaleFilter as integer
#EndIf
end type

private function UiElapsedSeconds( byval startedAt as double ) as double
	dim as double elapsed = timer - startedAt

	/' TIMER wraps at midnight on every supported FreeBASIC target. '/
	if( elapsed < 0.0 ) then elapsed += 86400.0
	return elapsed
end function

private function IsAllDigits( byref value as const string ) as integer
	if( len( value ) = 0 ) then return 0

	for index as integer = 1 to len( value )
		if( mid( value, index, 1 ) < "0" orelse mid( value, index, 1 ) > "9" ) then
			return 0
		end if
	next index

	return -1
end function

private function CountCharacter( byref value as const string, byref character as const string ) as integer
	dim as integer count = 0

	for index as integer = 1 to len( value )
		if( mid( value, index, 1 ) = character ) then count += 1
	next index

	return count
end function

private function SafeDisplayText( byref value as const string ) as string
	dim as string result
	dim as integer characterValue

	result = space( len( value ) )
	for index as integer = 1 to len( value )
		characterValue = asc( mid( value, index, 1 ) )
		if( characterValue >= 32 andalso characterValue <= 126 ) then
			mid( result, index, 1 ) = chr( characterValue )
		else
			mid( result, index, 1 ) = "."
		end if
	next index

	return result
end function

private function FitTextToWidth( byref value as const string, byval pixelWidth as integer ) as string
	dim as integer characterCount

	if( pixelWidth <= 0 ) then return ""
	characterCount = pixelWidth \ 8
	if( characterCount <= 0 ) then return ""
	return left( value, characterCount )
end function

function UiParseServer( byref serverText as const string, byref host as string, byref port as integer, byref errorText as string ) as integer
	dim as string value = trim( serverText )
	dim as integer delimiterPosition
	dim as string hostPart
	dim as string numberText
	dim as integer displayNumber
	dim as integer closingBracket
	dim as string suffix

	host = ""
	port = VNC_DEFAULT_PORT
	errorText = ""

	if( len( value ) = 0 ) then
		errorText = "Enter a VNC server name or address."
		return 0
	end if

	if( left( value, 1 ) = "[" ) then
		/' Brackets keep an IPv6 address separate from the VNC suffix. '/
		closingBracket = instr( value, "]" )
		if( closingBracket < 3 ) then
			errorText = "The bracketed server address is malformed."
			return 0
		end if
		host = mid( value, 2, closingBracket - 2 )
		suffix = mid( value, closingBracket + 1 )
		if( len( suffix ) > 0 ) then
			if( left( suffix, 2 ) = "::" ) then
				numberText = mid( suffix, 3 )
				if( IsAllDigits( numberText ) = 0 ) then
					errorText = "The TCP port after '::' is not a number."
					return 0
				end if
				port = valint( numberText )
			elseif( left( suffix, 1 ) = ":" ) then
				numberText = mid( suffix, 2 )
				if( IsAllDigits( numberText ) = 0 ) then
					errorText = "The VNC display number is not a number."
					return 0
				end if
				displayNumber = valint( numberText )
				if( displayNumber < 0 orelse displayNumber > 59635 ) then
					errorText = "The VNC display number is outside the valid range."
					return 0
				end if
				port = 5900 + displayNumber
			else
				errorText = "Unexpected text follows the bracketed server address."
				return 0
			end if
		end if
	else
		/'
		    TightVNC's host::port form selects a literal TCP port. A bare
		    IPv6 address also contains "::", so only accept this form when
		    the text before the final separator is an ordinary host name.
		'/
		delimiterPosition = instrrev( value, "::" )
		hostPart = ""
		if( delimiterPosition > 1 ) then hostPart = left( value, delimiterPosition - 1 )
		if( delimiterPosition > 1 andalso instr( hostPart, ":" ) = 0 ) then
			host = hostPart
			numberText = mid( value, delimiterPosition + 2 )
			if( IsAllDigits( numberText ) = 0 ) then
				errorText = "The TCP port after '::' is not a number."
				return 0
			end if
			port = valint( numberText )
		elseif( CountCharacter( value, ":" ) > 1 ) then
			/' An unbracketed multi-colon value is a bare IPv6 host. '/
			host = value
		else
			/' A single colon follows the traditional host:display convention. '/
			delimiterPosition = instrrev( value, ":" )
			if( delimiterPosition > 0 ) then
				host = left( value, delimiterPosition - 1 )
				numberText = mid( value, delimiterPosition + 1 )
				if( IsAllDigits( numberText ) = 0 ) then
					errorText = "The VNC display number is not a number."
					return 0
				end if
				displayNumber = valint( numberText )
				/' Display 59635 maps to the largest valid TCP port, 65535. '/
				if( displayNumber < 0 orelse displayNumber > 59635 ) then
					errorText = "The VNC display number is outside the valid range."
					return 0
				end if
				port = 5900 + displayNumber
			else
				host = value
			end if
		end if
	end if

	if( len( host ) = 0 ) then host = VNC_DEFAULT_HOST
	if( instr( host, "," ) > 0 orelse instr( host, "=" ) > 0 ) then
		errorText = "The host contains a character reserved by OPEN TCP."
		return 0
	end if

	if( port < 1 orelse port > 65535 ) then
		errorText = "The TCP port must be between 1 and 65535."
		return 0
	end if

	return -1
end function

private sub DrawPanel( byval x as integer, byval y as integer, byval panelWidth as integer, byval panelHeight as integer, byref title as const string )
	dim as Widget panelWidget
	dim as SubWindowData panelData

	panelWidget.ax = x
	panelWidget.ay = y
	panelWidget.w = panelWidth
	panelWidget.h = panelHeight
	panelWidget.data = @panelData
	panelData.title = title
	panelData.closable = 0
	subwindow_Render( @panelWidget )
end sub

private sub DrawLabel( byval x as integer, byval y as integer, byref labelText as const string, byval textColor as ulong )
	dim as Widget labelWidget
	dim as LabelData labelData

	labelWidget.ax = x
	labelWidget.ay = y
	labelWidget.data = @labelData
	labelData.text = labelText
	labelData.clr = textColor
	label_Render( @labelWidget )
end sub

private sub DrawTextField( byval x as integer, byval y as integer, byval fieldWidth as integer, byref value as const string, byval active as integer )
	dim as Widget fieldWidget
	dim as TextBoxData fieldData
	dim as string visibleText

	if( fieldWidth < 8 ) then fieldWidth = 8
	visibleText = FitTextToWidth( SafeDisplayText( value ), fieldWidth - 12 )

	fieldWidget.ax = x
	fieldWidget.ay = y
	fieldWidget.w = fieldWidth
	fieldWidget.h = 26
	fieldWidget.has_focus = active
	fieldWidget.data = @fieldData
	fieldData.text = visibleText
	fieldData.active = active
	fieldData.cursor_pos = len( visibleText )
	fieldData.sel_start = fieldData.cursor_pos
	fieldData.sel_end = fieldData.cursor_pos
	fieldData.selection_anchor = fieldData.cursor_pos
	fieldData.scrollbar_mode = TEXTBOX_SCROLLBAR_NONE
	fieldData.total_visual_lines = 1
	textbox_Render( @fieldWidget )
end sub

private sub DrawCheckBox( byval x as integer, byval y as integer, byref labelText as const string, byval checked as integer )
	dim as Widget checkWidget
	dim as CheckBoxData checkData

	checkWidget.ax = x
	checkWidget.ay = y
	checkWidget.w = 12
	checkWidget.h = 12
	checkWidget.data = @checkData
	checkData.label = labelText
	checkData.checked = checked
	checkbox_Render( @checkWidget )
end sub

private sub DrawButton( byval x as integer, byval y as integer, byval buttonWidth as integer, byval buttonHeight as integer, byref labelText as const string, byval primary as integer = 0 )
	dim as Widget buttonWidget
	dim as ButtonData buttonData

	buttonWidget.ax = x
	buttonWidget.ay = y
	buttonWidget.w = buttonWidth
	buttonWidget.h = buttonHeight
	buttonWidget.data = @buttonData
	buttonData.text = labelText
	if( primary ) then buttonData.state = 2
	button_Render( @buttonWidget )
end sub

private sub DrawConnectionDialog( byref state as UiState, byref options as VncOptions )
	dim as integer panelWidth = 520
	dim as integer panelHeight = 400
	dim as integer x
	dim as integer y
	dim as string passwordMask

	if( panelWidth > state.windowWidth - 30 ) then panelWidth = state.windowWidth - 30
	if( panelWidth < 330 ) then panelWidth = 330
	x = ( state.windowWidth - panelWidth ) \ 2
	y = ( state.windowHeight - panelHeight ) \ 2
	if( y < 10 ) then y = 10

	backend_Clear rgb( 55, 65, 75 )
	DrawPanel( x, y, panelWidth, panelHeight, "New TightVNC-style connection" )
	DrawLabel( x + 24, y + 55, "VNC server", rgb( 25, 25, 25 ) )
	DrawTextField( x + 24, y + 72, panelWidth - 48, options.serverText, state.activeField = 0 )
	DrawLabel( x + 24, y + 108, "Password (classic VNC authentication)", rgb( 25, 25, 25 ) )
	passwordMask = string( len( options.password ), asc( "*" ) )
	DrawTextField( x + 24, y + 125, panelWidth - 48, passwordMask, state.activeField = 1 )

	DrawCheckBox( x + 24, y + 171, "Share the session with other viewers", options.sharedSession )
	DrawCheckBox( x + 24, y + 199, "View only", options.viewOnly )
	DrawCheckBox( x + 24, y + 227, "Scale remote desktop to fit the window", options.scaleToFit )
	DrawCheckBox( x + 24, y + 255, "Show the session toolbar", options.showToolbar )
	DrawCheckBox( x + 24, y + 283, "Prefer Raw encoding (automatic for localhost)", options.preferRaw )

	if( len( state.statusText ) > 0 ) then
		DrawLabel( x + 24, y + 320, FitTextToWidth( SafeDisplayText( state.statusText ), panelWidth - 48 ), rgb( 160, 35, 35 ) )
	else
		DrawLabel( x + 24, y + 320, "Use host:display or host::port. Press Tab to change fields.", rgb( 80, 80, 80 ) )
	end if

	DrawButton( x + panelWidth - 220, y + 357, 92, 28, "Connect", -1 )
	DrawButton( x + panelWidth - 116, y + 357, 92, 28, "Exit" )
end sub

private sub CalculateLayout( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byref layout as UiLayout )
	dim as integer maximumScroll

	if( state.fullScreen ) then
		layout.contentTop = 0
		layout.contentBottom = state.windowHeight - 1
	elseif( options.showToolbar ) then
		layout.contentTop = UI_TOOLBAR_HEIGHT
		layout.contentBottom = state.windowHeight - UI_STATUS_HEIGHT - 1
	else
		layout.contentTop = 0
		layout.contentBottom = state.windowHeight - UI_STATUS_HEIGHT - 1
	end if
	layout.viewLeft = 0
	layout.viewTop = layout.contentTop
	layout.viewWidth = state.windowWidth
	layout.viewHeight = layout.contentBottom - layout.contentTop + 1
	layout.showScrollbars = 0

	if( layout.viewWidth < 1 ) then layout.viewWidth = 1
	if( layout.viewHeight < 1 ) then layout.viewHeight = 1

	if( options.scaleToFit ) then
		if( ScalerFitDimensions( _
			client.serverWidth, client.serverHeight, _
			layout.viewWidth, layout.viewHeight, _
			layout.destinationWidth, layout.destinationHeight _
		) = 0 ) then
			layout.destinationWidth = 1
			layout.destinationHeight = 1
		end if
		layout.destinationX = ( layout.viewWidth - layout.destinationWidth ) \ 2
		layout.destinationY = layout.contentTop + ( layout.viewHeight - layout.destinationHeight ) \ 2
		state.scrollX = 0
		state.scrollY = 0
	else
		layout.destinationWidth = client.serverWidth
		layout.destinationHeight = client.serverHeight

		if( client.serverWidth > layout.viewWidth orelse client.serverHeight > layout.viewHeight ) then
			layout.showScrollbars = -1
			layout.viewWidth -= UI_SCROLLBAR_SIZE
			layout.viewHeight -= UI_SCROLLBAR_SIZE
			if( layout.viewWidth < 1 ) then layout.viewWidth = 1
			if( layout.viewHeight < 1 ) then layout.viewHeight = 1
		end if

		maximumScroll = client.serverWidth - layout.viewWidth
		if( maximumScroll < 0 ) then maximumScroll = 0
		if( state.scrollX > maximumScroll ) then state.scrollX = maximumScroll
		if( state.scrollX < 0 ) then state.scrollX = 0
		maximumScroll = client.serverHeight - layout.viewHeight
		if( maximumScroll < 0 ) then maximumScroll = 0
		if( state.scrollY > maximumScroll ) then state.scrollY = maximumScroll
		if( state.scrollY < 0 ) then state.scrollY = 0

		if( client.serverWidth < layout.viewWidth ) then
			layout.destinationX = ( layout.viewWidth - client.serverWidth ) \ 2
		else
			layout.destinationX = -state.scrollX
		end if
		if( client.serverHeight < layout.viewHeight ) then
			layout.destinationY = layout.contentTop + ( layout.viewHeight - client.serverHeight ) \ 2
		else
			layout.destinationY = layout.contentTop - state.scrollY
		end if
	end if
end sub

private sub ReleaseFrameImage( byref state as UiState )
	if( state.frameImage <> 0 ) then imageDestroy state.frameImage
	state.frameImage = 0
	state.frameImagePixels = 0
	state.frameImageWidth = 0
	state.frameImageHeight = 0
	state.frameImagePitch = 0
end sub

#Ifdef __FB_GFXLIB3__
private sub ReleaseFrameSurface( byref state as UiState )
	if( state.frameSurface <> 0 ) then Gfx3SurfaceDestroy state.frameSurface
	state.frameSurface = 0
	state.frameSurfaceWidth = 0
	state.frameSurfaceHeight = 0
	state.frameSurfaceReady = 0
end sub

private sub ReleaseFrameUploadBuffer( byref state as UiState )
	if( state.frameUploadPixels <> 0 ) then deallocate state.frameUploadPixels
	state.frameUploadPixels = 0
	state.frameUploadCapacity = 0
end sub

private function EnsureFrameUploadBuffer( byref state as UiState, byval requiredBytes as ulongint ) as integer
	dim as ubyte ptr newPixels

	if( requiredBytes < 1 ) then return 0
	if( state.frameUploadPixels <> 0 andalso state.frameUploadCapacity >= requiredBytes ) then return -1

	newPixels = cptr( ubyte ptr, reallocate( state.frameUploadPixels, requiredBytes ) )
	if( newPixels = 0 ) then return 0

	state.frameUploadPixels = newPixels
	state.frameUploadCapacity = requiredBytes
	return -1
end function

private function EnsureFrameSurface( byref state as UiState, byval surfaceWidth as integer, byval surfaceHeight as integer, byref created as integer ) as integer
	dim as any ptr newSurface

	created = 0
	if( surfaceWidth < 1 orelse surfaceHeight < 1 ) then return 0
	if( state.frameSurface <> 0 andalso _
		state.frameSurfaceWidth = surfaceWidth andalso state.frameSurfaceHeight = surfaceHeight ) then return -1

	/'
	    Opaque surfaces belong to one gfxlib3 screen mode. Release the previous
	    allocation before a DesktopSize replacement so a large old desktop does
	    not make an otherwise valid new allocation fail for lack of GPU memory.
	'/
	ReleaseFrameSurface state
	newSurface = Gfx3SurfaceCreate( _
		surfaceWidth, surfaceHeight, 32, _
		GFX3_SURFACE_SAMPLED or GFX3_SURFACE_TRANSFER_DESTINATION, _
		rgb( 0, 0, 0 ) _
	)
	if( newSurface = 0 ) then return 0

	state.frameSurface = newSurface
	state.frameSurfaceWidth = surfaceWidth
	state.frameSurfaceHeight = surfaceHeight
	created = -1
	return -1
end function

private function RenderFramebufferGfx3( byref state as UiState, byref client as RfbClient, byref layout as UiLayout ) as integer
	dim as integer surfaceCreated
	dim as integer uploadLeft
	dim as integer uploadTop
	dim as integer uploadRight
	dim as integer uploadBottom
	dim as integer uploadWidth
	dim as integer uploadHeight
	dim as integer sourcePitch
	dim as integer packedPitch
	dim as integer uploadRow
	dim as ulongint packedBytes
	dim as const ulong ptr sourcePixels
	dim as integer uploadNeeded

	if( EnsureFrameSurface( state, client.serverWidth, client.serverHeight, surfaceCreated ) = 0 ) then return 0

	if( surfaceCreated ) then
		uploadLeft = 0
		uploadTop = 0
		uploadRight = client.serverWidth - 1
		uploadBottom = client.serverHeight - 1
		uploadNeeded = -1
	elseif( client.framebufferDirtyValid ) then
		uploadLeft = client.framebufferDirtyLeft
		uploadTop = client.framebufferDirtyTop
		uploadRight = client.framebufferDirtyRight
		uploadBottom = client.framebufferDirtyBottom
		uploadNeeded = -1
	end if

	if( uploadNeeded ) then
		if( uploadLeft < 0 orelse uploadRight < uploadLeft orelse uploadRight >= client.serverWidth orelse _
			uploadTop < 0 orelse uploadBottom < uploadTop orelse uploadBottom >= client.serverHeight ) then
			ReleaseFrameSurface state
			return 0
		end if

		/'
		    gfxlib3 currently copies sourcePitch * height bytes into its queued
		    command. Pack narrow dirty rectangles so a small update does not copy and
		    transfer complete framebuffer rows. Packing adds one CPU copy, so use the
		    direct full-row path once the dirty width reaches half the framebuffer;
		    that path moves no more total memory and needs no staging allocation.
		'/
		uploadWidth = uploadRight - uploadLeft + 1
		uploadHeight = uploadBottom - uploadTop + 1
		if( uploadWidth < ( client.serverWidth + 1 ) \ 2 ) then
			packedPitch = uploadWidth * sizeof( ulong )
			packedBytes = culngint( packedPitch ) * culngint( uploadHeight )
			if( EnsureFrameUploadBuffer( state, packedBytes ) ) then
				for uploadRow = 0 to uploadHeight - 1
					__builtin_memcpy( _
						state.frameUploadPixels + culngint( uploadRow ) * packedPitch, _
						client.framebuffer + _
							culngint( uploadTop + uploadRow ) * client.serverWidth + uploadLeft, _
						packedPitch _
					)
				next uploadRow
				sourcePitch = packedPitch
				sourcePixels = cptr( const ulong ptr, state.frameUploadPixels )
			else
				/' Allocation failure keeps the correct direct-row fallback available. '/
				uploadLeft = 0
				uploadWidth = client.serverWidth
				sourcePitch = client.serverWidth * sizeof( ulong )
				sourcePixels = client.framebuffer + culngint( uploadTop ) * client.serverWidth
			end if
		else
			uploadLeft = 0
			uploadWidth = client.serverWidth
			sourcePitch = client.serverWidth * sizeof( ulong )
			sourcePixels = client.framebuffer + culngint( uploadTop ) * client.serverWidth
		end if
		if( Gfx3SurfaceUpload( _
			state.frameSurface, uploadLeft, uploadTop, uploadWidth, uploadHeight, _
			sourcePitch, sourcePixels _
		) <> 0 ) then
			ReleaseFrameSurface state
			return 0
		end if
		client.framebufferDirtyValid = 0
	end if

	return -1
end function

private sub BlitFramebufferGfx3( byref state as UiState, byref layout as UiLayout )
	dim as integer blitResult

	if( state.frameSurfaceReady = 0 orelse state.frameSurface = 0 ) then exit sub

	/'
	    Keep the remote transform after the ordinary window chrome so it is the
	    final bulk operation in the viewport. omaGUI's gfxlib3 alpha backend uses
	    queued point batches, so later overlay text can blend without a page
	    readback. The viewport clip also protects one-to-one scrollbars from a
	    destination rectangle which extends beyond the visible remote area.
	'/
	backend_SetClip layout.viewLeft, layout.viewTop, layout.viewWidth, layout.viewHeight
	blitResult = Gfx3SurfaceBlitScaled( _
		0, state.frameSurface, _
		0, 0, state.frameSurfaceWidth, state.frameSurfaceHeight, _
		layout.destinationX, layout.destinationY, _
		layout.destinationWidth, layout.destinationHeight, _
		GFX3_PUT_PSET, 255, state.scaleFilter _
	)
	backend_ResetClip()
	state.frameSurfaceReady = 0

	if( blitResult <> 0 ) then ReleaseFrameSurface state
end sub
#EndIf

private function EnsureFrameImage( byref state as UiState, byval imageWidth as integer, byval imageHeight as integer ) as integer
	dim as any ptr newImage
	dim as any ptr newPixels
	dim as integer actualWidth
	dim as integer actualHeight
	dim as integer bytesPerPixel
	dim as integer imagePitch
	dim as integer imageBytes

	if( imageWidth < 1 orelse imageHeight < 1 ) then return 0
	if( culngint( imageWidth ) * 4u > culngint( &h7FFFFFFF ) ) then return 0
	if( culngint( imageWidth ) * culngint( imageHeight ) * 4u > culngint( &h7FFFFFFF ) ) then return 0

	if( state.frameImage <> 0 andalso _
		state.frameImageWidth = imageWidth andalso state.frameImageHeight = imageHeight andalso _
		state.frameImagePixels <> 0 andalso state.frameImagePitch >= imageWidth * 4 ) then return -1

	newImage = imageCreate( imageWidth, imageHeight, rgb( 0, 0, 0 ), 32 )
	if( newImage = 0 ) then return 0

	if( imageInfo( newImage, actualWidth, actualHeight, bytesPerPixel, imagePitch, newPixels, imageBytes ) <> 0 orelse _
		actualWidth <> imageWidth orelse actualHeight <> imageHeight orelse _
		bytesPerPixel <> 4 orelse imagePitch < imageWidth * 4 orelse imageBytes < 0 orelse newPixels = 0 orelse _
		culngint( imagePitch ) * culngint( imageHeight ) > culngint( imageBytes ) ) then
		imageDestroy newImage
		return 0
	end if

	/'
	    Only the main gfx thread owns this image. Reuse is important with gfxlib3:
	    it retains a same-sized texture for PUT and uploads new pixels into that
	    allocation. Reallocating the image every frame would defeat that cache.
	'/
	ReleaseFrameImage state
	state.frameImage = newImage
	state.frameImagePixels = cptr( uByte ptr, newPixels )
	state.frameImageWidth = actualWidth
	state.frameImageHeight = actualHeight
	state.frameImagePitch = imagePitch
	return -1
end function

private sub RenderFramebufferDirect( byref state as UiState, byref client as RfbClient, byref layout as UiLayout, _
	byval firstX as integer, byval firstY as integer, byval lastX as integer, byval lastY as integer )
	dim as integer screenPitch
	dim as uByte ptr screenBytes

	/'
	    The direct path is a portability fallback for a target that cannot create
	    a 32-bit gfx image. It is correct, but gfxlib3 must upload the complete
	    work page after ScreenPtr has exposed it for writing.
	'/
	screenControl GET_SCREEN_PITCH, screenPitch
	screenBytes = cptr( uByte ptr, screenPtr )
	if( screenBytes = 0 orelse screenPitch < 0 orelse _
		culngint( screenPitch ) < culngint( state.windowWidth ) * 4u ) then exit sub

	screenLock
	ScalerBlitNearest32( _
		client.framebuffer, client.serverWidth, client.serverHeight, _
		screenBytes, state.windowWidth, state.windowHeight, screenPitch, _
		layout.destinationX, layout.destinationY, _
		layout.destinationWidth, layout.destinationHeight, _
		firstX, firstY, lastX, lastY _
	)
	screenUnlock
end sub

private sub RenderFramebuffer( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byref layout as UiLayout )
	dim as integer firstX
	dim as integer lastX
	dim as integer firstY
	dim as integer lastY
	dim as integer visibleWidth
	dim as integer visibleHeight

	backend_Rect 0, layout.contentTop, state.windowWidth, layout.contentBottom - layout.contentTop + 1, rgb( 22, 22, 22 ), -1
#Ifdef __FB_GFXLIB3__
	state.frameSurfaceReady = 0
#EndIf

	firstX = layout.destinationX
	if( firstX < layout.viewLeft ) then firstX = layout.viewLeft
	lastX = layout.destinationX + layout.destinationWidth - 1
	if( lastX >= layout.viewLeft + layout.viewWidth ) then lastX = layout.viewLeft + layout.viewWidth - 1
	firstY = layout.destinationY
	if( firstY < layout.viewTop ) then firstY = layout.viewTop
	lastY = layout.destinationY + layout.destinationHeight - 1
	if( lastY >= layout.viewTop + layout.viewHeight ) then lastY = layout.viewTop + layout.viewHeight - 1

	if( firstX <= lastX andalso firstY <= lastY ) then
#Ifdef __FB_GFXLIB3__
		if( RenderFramebufferGfx3( state, client, layout ) ) then
			state.frameSurfaceReady = -1
			exit sub
		end if
#EndIf
		visibleWidth = lastX - firstX + 1
		visibleHeight = lastY - firstY + 1

		if( EnsureFrameImage( state, visibleWidth, visibleHeight ) ) then
			/'
			    The staging image contains only the visible remote rectangle. This
			    matters when a one-to-one desktop is larger than the window: PUT does
			    not upload pixels hidden beyond the scrollable viewport.
			'/
			if( ScalerBlitNearest32( _
				client.framebuffer, client.serverWidth, client.serverHeight, _
				state.frameImagePixels, visibleWidth, visibleHeight, state.frameImagePitch, _
				layout.destinationX - firstX, layout.destinationY - firstY, _
				layout.destinationWidth, layout.destinationHeight, _
				0, 0, visibleWidth - 1, visibleHeight - 1 _
			) ) then
				put ( firstX, firstY ), state.frameImage, pset
			end if
		else
			RenderFramebufferDirect state, client, layout, firstX, firstY, lastX, lastY
		end if
	end if
end sub

private function ToolbarButtonWidth( byref labelText as const string ) as integer
	return len( labelText ) * 8 + 18
end function

private sub DrawToolbarItem( byref leftPosition as integer, byref labelText as const string, byval highlighted as integer = 0 )
	dim as integer buttonWidth = ToolbarButtonWidth( labelText )
	DrawButton( leftPosition, 7, buttonWidth, 27, labelText, highlighted )
	leftPosition += buttonWidth + 5
end sub

private sub DrawToolbar( byref state as UiState, byref options as VncOptions )
	dim as integer leftPosition = 6
	dim as string scaleLabel
	dim as string viewLabel

	backend_Rect 0, 0, state.windowWidth, UI_TOOLBAR_HEIGHT, current_theme.bg_face, -1
	backend_Line 0, UI_TOOLBAR_HEIGHT - 2, state.windowWidth - 1, UI_TOOLBAR_HEIGHT - 2, current_theme.bg_dark

	if( options.scaleToFit ) then scaleLabel = "Fit" else scaleLabel = "1:1"
	if( options.viewOnly ) then viewLabel = "View" else viewLabel = "Control"

	DrawToolbarItem( leftPosition, "New" )
	DrawToolbarItem( leftPosition, "Options" )
	DrawToolbarItem( leftPosition, "Refresh" )
	DrawToolbarItem( leftPosition, "Ctrl-Esc" )
	DrawToolbarItem( leftPosition, "Ctrl-Alt-Del" )
	DrawToolbarItem( leftPosition, "Full screen", state.fullScreen )
	DrawToolbarItem( leftPosition, scaleLabel, options.scaleToFit )
	DrawToolbarItem( leftPosition, viewLabel, options.viewOnly )
	DrawToolbarItem( leftPosition, "Clipboard" )
	DrawToolbarItem( leftPosition, "Info" )
end sub

private sub DrawScrollbars( _
	byref state as UiState, byref layout as UiLayout, _
	byval serverWidth as integer, byval serverHeight as integer _
)
	dim as integer maximumScroll
	dim as Widget horizontalWidget
	dim as Widget verticalWidget
	dim as ScrollBarData horizontalData
	dim as ScrollBarData verticalData

	if( layout.showScrollbars = 0 ) then exit sub

	maximumScroll = serverWidth - layout.viewWidth
	if( maximumScroll < 0 ) then maximumScroll = 0
	horizontalWidget.ax = 0
	horizontalWidget.ay = layout.contentTop + layout.viewHeight
	horizontalWidget.w = layout.viewWidth
	horizontalWidget.h = UI_SCROLLBAR_SIZE
	horizontalWidget.enabled = -1
	horizontalWidget.data = @horizontalData
	horizontalData.max_val = maximumScroll
	horizontalData.page_size = layout.viewWidth
	horizontalData.value = state.scrollX
	horizontalData.vertical = 0
	scrollbar_Render( @horizontalWidget )

	maximumScroll = serverHeight - layout.viewHeight
	if( maximumScroll < 0 ) then maximumScroll = 0
	verticalWidget.ax = layout.viewWidth
	verticalWidget.ay = layout.contentTop
	verticalWidget.w = UI_SCROLLBAR_SIZE
	verticalWidget.h = layout.viewHeight
	verticalWidget.enabled = -1
	verticalWidget.data = @verticalData
	verticalData.max_val = maximumScroll
	verticalData.page_size = layout.viewHeight
	verticalData.value = state.scrollY
	verticalData.vertical = -1
	scrollbar_Render( @verticalWidget )

	backend_Rect layout.viewWidth, layout.contentTop + layout.viewHeight, UI_SCROLLBAR_SIZE, UI_SCROLLBAR_SIZE, current_theme.bg_face, -1
end sub

private sub DrawStatusBar( byref state as UiState, byref options as VncOptions, byref snapshot as UiClientSnapshot )
	dim as integer topPosition = state.windowHeight - UI_STATUS_HEIGHT
	dim as string status

	backend_Rect 0, topPosition, state.windowWidth, UI_STATUS_HEIGHT, current_theme.bg_face, -1
	backend_Line 0, topPosition, state.windowWidth - 1, topPosition, current_theme.bg_dark
	status = SafeDisplayText( snapshot.desktopName ) & "  " & str( snapshot.serverWidth ) & "x" & str( snapshot.serverHeight ) & _
		"  RFB 3." & str( snapshot.protocolMinor ) & "  updates " & str( snapshot.updatesReceived )
	if( options.viewOnly ) then status &= "  VIEW ONLY"
	if( snapshot.threadedSession ) then status &= "  THREADED" else status &= "  SERIAL"
	if( snapshot.bellPending ) then status &= "  BELL"
	DrawLabel( 7, topPosition + 8, FitTextToWidth( status, state.windowWidth - 14 ), rgb( 35, 35, 35 ) )
end sub

private sub DrawOptionsOverlay( byref state as UiState, byref options as VncOptions )
	dim as integer panelWidth = 390
	dim as integer panelHeight
#Ifdef __FB_GFXLIB3__
	panelHeight = 270
#Else
	panelHeight = 225
#EndIf
	dim as integer x = ( state.windowWidth - panelWidth ) \ 2
	dim as integer y = ( state.windowHeight - panelHeight ) \ 2

	DrawPanel( x, y, panelWidth, panelHeight, "Connection options" )
	DrawCheckBox( x + 28, y + 58, "View only", options.viewOnly )
	DrawCheckBox( x + 28, y + 90, "Scale desktop to fit", options.scaleToFit )
	DrawCheckBox( x + 28, y + 122, "Show session toolbar (F8 restores it)", options.showToolbar )
#Ifdef __FB_GFXLIB3__
	DrawLabel( x + 28, y + 154, "Scaling filter", rgb( 25, 25, 25 ) )
	DrawCheckBox( x + 28, y + 176, "Nearest (crisp)", state.scaleFilter = GFX3_FILTER_NEAREST )
	DrawCheckBox( x + 200, y + 176, "Linear (smooth)", state.scaleFilter = GFX3_FILTER_LINEAR )
	DrawButton( x + panelWidth - 110, y + 224, 82, 28, "Close" )
#Else
	DrawButton( x + panelWidth - 110, y + 174, 82, 28, "Close" )
#EndIf
end sub

private sub DrawInfoOverlay( byref state as UiState, byref snapshot as UiClientSnapshot )
	dim as integer panelWidth = 450
	dim as integer panelHeight = 245
	dim as integer x = ( state.windowWidth - panelWidth ) \ 2
	dim as integer y = ( state.windowHeight - panelHeight ) \ 2

	DrawPanel( x, y, panelWidth, panelHeight, "Connection information" )
	DrawLabel( x + 28, y + 58, "Desktop: " & SafeDisplayText( snapshot.desktopName ), rgb( 25, 25, 25 ) )
	DrawLabel( x + 28, y + 82, "Framebuffer: " & str( snapshot.serverWidth ) & " x " & str( snapshot.serverHeight ), rgb( 25, 25, 25 ) )
	DrawLabel( x + 28, y + 106, "Protocol: RFB 3." & str( snapshot.protocolMinor ), rgb( 25, 25, 25 ) )
	if( snapshot.preferRaw ) then
		DrawLabel( x + 28, y + 130, "Encoding preference: Raw, CopyRect, Hextile", rgb( 25, 25, 25 ) )
	else
		DrawLabel( x + 28, y + 130, "Encoding preference: Hextile, CopyRect, RRE", rgb( 25, 25, 25 ) )
	end if
	DrawLabel( x + 28, y + 154, "Transport: standard FreeBASIC OPEN TCP", rgb( 25, 25, 25 ) )
	if( snapshot.threadedSession ) then
		DrawLabel( x + 28, y + 178, "Execution: render + decoder + communications threads", rgb( 25, 25, 25 ) )
	elseif( len( state.threadFallbackReason ) > 0 ) then
		DrawLabel( x + 28, y + 178, FitTextToWidth( state.threadFallbackReason, panelWidth - 56 ), rgb( 25, 25, 25 ) )
	else
		DrawLabel( x + 28, y + 178, "Execution: portable serial fallback", rgb( 25, 25, 25 ) )
	end if
	DrawButton( x + panelWidth - 110, y + 210, 82, 28, "Close" )
end sub

private sub DrawClipboardOverlay( byref state as UiState )
	dim as integer panelWidth = 520
	dim as integer panelHeight = 245
	dim as integer x
	dim as integer y

	if( panelWidth > state.windowWidth - 20 ) then panelWidth = state.windowWidth - 20
	if( panelWidth < 200 ) then panelWidth = 200
	x = ( state.windowWidth - panelWidth ) \ 2
	y = ( state.windowHeight - panelHeight ) \ 2
	DrawPanel( x, y, panelWidth, panelHeight, "VNC clipboard" )
	DrawLabel( x + 24, y + 55, "Portable clipboard text (single line)", rgb( 25, 25, 25 ) )
	DrawTextField( x + 24, y + 74, panelWidth - 48, state.clipboardDraft, -1 )
	DrawLabel( x + 24, y + 116, "This field avoids platform clipboard APIs. Edit it, then Send.", rgb( 70, 70, 70 ) )
	DrawButton( x + panelWidth - 220, y + 188, 92, 28, "Send", -1 )
	DrawButton( x + panelWidth - 116, y + 188, 92, 28, "Cancel" )
end sub

private sub DrawSession( byref state as UiState, byref options as VncOptions, byref client as RfbClient )
	dim as UiLayout layout
	dim as UiClientSnapshot snapshot

	/'
	    Keep the framebuffer mutex around pixel access and the metadata snapshot
	    only. omaGUI chrome can then render while the decoder starts the next RFB
	    update instead of extending the critical section for unrelated drawing.
	'/
	VncFramebufferLock client
	CalculateLayout( state, options, client, layout )
	RenderFramebuffer( state, options, client, layout )
	snapshot.desktopName = client.desktopName
	snapshot.serverWidth = client.serverWidth
	snapshot.serverHeight = client.serverHeight
	snapshot.protocolMinor = client.protocolMinor
	snapshot.updatesReceived = client.updatesReceived
	snapshot.threadedSession = client.threadedSession
	snapshot.bellPending = client.bellPending
	snapshot.preferRaw = client.preferRaw
	VncFramebufferUnlock client

	DrawScrollbars( state, layout, snapshot.serverWidth, snapshot.serverHeight )
	if( state.fullScreen = 0 ) then
		if( options.showToolbar ) then DrawToolbar( state, options )
		DrawStatusBar( state, options, snapshot )
	end if

#Ifdef __FB_GFXLIB3__
	BlitFramebufferGfx3 state, layout
#EndIf

	select case state.overlay
	case UI_OVERLAY_OPTIONS
		DrawOptionsOverlay( state, options )
	case UI_OVERLAY_INFO
		DrawInfoOverlay( state, snapshot )
	case UI_OVERLAY_CLIPBOARD
		DrawClipboardOverlay( state )
	end select
end sub

private function HitRectangle( byval mouseX as integer, byval mouseY as integer, byval x as integer, byval y as integer, byval rectWidth as integer, byval rectHeight as integer ) as integer
	return ( mouseX >= x andalso mouseX <= x + rectWidth andalso mouseY >= y andalso mouseY <= y + rectHeight )
end function

private sub ReadCurrentPointer( byref state as UiState )
	dim as integer wheelPosition
	dim as integer buttonMask
	dim as integer mouseX
	dim as integer mouseY

	/'
	    EVENT is a union. Button and wheel events contain only their button or
	    wheel member, so their x and y members are not valid coordinates.
	    GetMouse is the portable gfxlib source for the position at those events.
	'/
	if( getmouse( mouseX, mouseY, wheelPosition, buttonMask ) = 0 ) then
		state.pointerX = mouseX
		state.pointerY = mouseY
	end if
end sub

private function ToolbarActionAt( byval mouseX as integer, byval mouseY as integer, byref options as VncOptions ) as integer
	dim as integer leftPosition = 6
	dim as integer actionIndex
	dim as string labels( 0 to 9 ) = { "New", "Options", "Refresh", "Ctrl-Esc", "Ctrl-Alt-Del", "Full screen", "", "", "Clipboard", "Info" }

	if( mouseY < 7 orelse mouseY > 34 ) then return 0
	if( options.scaleToFit ) then labels( 6 ) = "Fit" else labels( 6 ) = "1:1"
	if( options.viewOnly ) then labels( 7 ) = "View" else labels( 7 ) = "Control"

	for actionIndex = 0 to 9
		if( mouseX >= leftPosition andalso mouseX <= leftPosition + ToolbarButtonWidth( labels( actionIndex ) ) ) then
			return actionIndex + 1
		end if
		leftPosition += ToolbarButtonWidth( labels( actionIndex ) ) + 5
	next actionIndex

	return 0
end function

private function ControlKeySymFromEvent( byref eventData as event ) as ulong
	/'
	    gfxlib reports Ctrl+A through Ctrl+Z as ASCII control values 1 through
	    26. RFB needs the printable key's X11 keysym while the separate Control
	    key event remains held. The scancode fallback covers backends which omit
	    ASCII on a modified key release.
	'/
	select case eventData.ascii
	case 1 to 26: return culng( asc( "a" ) + eventData.ascii - 1 )
	case 27: return culng( asc( "[" ) )
	case 28: return culng( asc( "\" ) )
	case 29: return culng( asc( "]" ) )
	case 30: return culng( asc( "^" ) )
	case 31: return culng( asc( "_" ) )
	end select

	select case eventData.scancode
	case SC_A: return asc( "a" )
	case SC_B: return asc( "b" )
	case SC_C: return asc( "c" )
	case SC_D: return asc( "d" )
	case SC_E: return asc( "e" )
	case SC_F: return asc( "f" )
	case SC_G: return asc( "g" )
	case SC_H: return asc( "h" )
	case SC_I: return asc( "i" )
	case SC_J: return asc( "j" )
	case SC_K: return asc( "k" )
	case SC_L: return asc( "l" )
	case SC_M: return asc( "m" )
	case SC_N: return asc( "n" )
	case SC_O: return asc( "o" )
	case SC_P: return asc( "p" )
	case SC_Q: return asc( "q" )
	case SC_R: return asc( "r" )
	case SC_S: return asc( "s" )
	case SC_T: return asc( "t" )
	case SC_U: return asc( "u" )
	case SC_V: return asc( "v" )
	case SC_W: return asc( "w" )
	case SC_X: return asc( "x" )
	case SC_Y: return asc( "y" )
	case SC_Z: return asc( "z" )
	case SC_SPACE: return asc( " " )
	case SC_LEFTBRACKET: return asc( "[" )
	case SC_RIGHTBRACKET: return asc( "]" )
	case SC_BACKSLASH: return asc( "\" )
	end select

	return 0
end function

private function KeySymFromEvent( byref eventData as event, byval controlHeld as integer ) as ulong
	if( eventData.ascii >= 32 andalso eventData.ascii <= 255 ) then
		return culng( eventData.ascii )
	end if

	select case eventData.scancode
	case SC_BACKSPACE: return &hFF08u
	case SC_TAB: return &hFF09u
	case SC_ENTER: return &hFF0Du
	case SC_ESCAPE: return &hFF1Bu
	case SC_INSERT: return &hFF63u
	case SC_DELETE: return &hFFFFu
	case SC_HOME: return &hFF50u
	case SC_END: return &hFF57u
	case SC_PAGEUP: return &hFF55u
	case SC_PAGEDOWN: return &hFF56u
	case SC_LEFT: return &hFF51u
	case SC_UP: return &hFF52u
	case SC_RIGHT: return &hFF53u
	case SC_DOWN: return &hFF54u
	case SC_LSHIFT: return &hFFE1u
	case SC_RSHIFT: return &hFFE2u
	case SC_CONTROL: return &hFFE3u
	case SC_CAPSLOCK: return &hFFE5u
	case SC_ALT: return &hFFE9u
	case SC_ALTGR: return &hFFEAu
	case SC_F1 to SC_F10: return &hFFBEu + ( eventData.scancode - SC_F1 )
	case SC_F11: return &hFFC8u
	case SC_F12: return &hFFC9u
	end select

	if( controlHeld ) then
		dim as ulong controlKeySym = ControlKeySymFromEvent( eventData )
		if( controlKeySym <> 0 ) then return controlKeySym
	end if

	select case eventData.ascii
	case 8: return &hFF08u
	case 9: return &hFF09u
	case 13: return &hFF0Du
	case 27: return &hFF1Bu
	end select

	return 0
end function

private sub ReleaseViewerModifiers( byref client as RfbClient )
	RfbSendKey( client, &hFFE1u, 0 )
	RfbSendKey( client, &hFFE2u, 0 )
	RfbSendKey( client, &hFFE3u, 0 )
	RfbSendKey( client, &hFFE9u, 0 )
	RfbSendKey( client, &hFFEAu, 0 )
end sub

private sub ClearViewerModifierState( byref state as UiState )
	state.controlHeld = 0
	state.altHeld = 0
	state.leftShiftHeld = 0
	state.rightShiftHeld = 0
end sub

private sub UpdateViewerModifierState( byref state as UiState, byref eventData as event )
	dim as integer isHeld

	if( eventData.type <> EVENT_KEY_PRESS andalso _
		eventData.type <> EVENT_KEY_REPEAT andalso _
		eventData.type <> EVENT_KEY_RELEASE ) then exit sub

	isHeld = ( eventData.type <> EVENT_KEY_RELEASE )

	select case eventData.scancode
	case SC_CONTROL: state.controlHeld = isHeld
	case SC_ALT: state.altHeld = isHeld
	case SC_LSHIFT: state.leftShiftHeld = isHeld
	case SC_RSHIFT: state.rightShiftHeld = isHeld
	end select
end sub

private function FullScreenChordIsHeld( byref state as UiState ) as integer
	return state.controlHeld andalso state.altHeld andalso _
		( state.leftShiftHeld orelse state.rightShiftHeld )
end function

private sub ToggleFullScreen( byref state as UiState )
	dim as integer desktopWidth
	dim as integer desktopHeight

#Ifdef __FB_GFXLIB3__
	/' SCREENRES destroys mode-owned opaque surfaces, so release ours first. '/
	ReleaseFrameSurface state
#EndIf

	if( state.fullScreen = 0 ) then
		state.savedWindowWidth = state.windowWidth
		state.savedWindowHeight = state.windowHeight
		screencontrol GET_DESKTOP_SIZE, desktopWidth, desktopHeight
		if( backend_SetWindowMode( desktopWidth, desktopHeight, BACKEND_WINDOW_FULLSCREEN ) ) then
			state.fullScreen = -1
			state.overlay = UI_OVERLAY_NONE
			state.windowWidth = desktopWidth
			state.windowHeight = desktopHeight
		end if
	else
		if( backend_SetWindowMode( state.savedWindowWidth, state.savedWindowHeight, BACKEND_WINDOW_RESIZABLE ) ) then
			state.fullScreen = 0
			state.windowWidth = state.savedWindowWidth
			state.windowHeight = state.savedWindowHeight
		end if
	end if

	windowtitle VNC_PROGRAM_NAME
	state.needsRedraw = -1
end sub

private sub BeginConnection( byref state as UiState, byref options as VncOptions, byref client as RfbClient )
	dim as string parseError
	dim as string fallbackReason

	if( state.threadState <> 0 ) then VncThreadsStop *state.threadState
	ReleaseFrameImage state
#Ifdef __FB_GFXLIB3__
	ReleaseFrameSurface state
#EndIf

	if( UiParseServer( options.serverText, options.host, options.port, parseError ) = 0 ) then
		state.statusText = parseError
		state.needsRedraw = -1
		exit sub
	end if

	state.statusText = "Connecting to " & options.host & "..."
	DrawConnectionDialog( state, options )
	backend_Flip()

	if( RfbConnect( client, options ) ) then
		state.threadFallbackReason = ""
		if( state.threadState <> 0 ) then
			if( VncThreadsStart( *state.threadState, client, fallbackReason ) = 0 ) then
				state.threadFallbackReason = fallbackReason
			end if
		end if
		state.mode = UI_MODE_SESSION
		state.statusText = ""
		state.scrollX = 0
		state.scrollY = 0
		state.lastThreadGeneration = 0
		state.threadFramePending = 0
		state.lastThreadFrameTime = 0.0
		state.overlay = UI_OVERLAY_NONE
		windowtitle client.desktopName & " - " & VNC_PROGRAM_NAME
	else
		state.statusText = client.errorMessage
		state.mode = UI_MODE_CONNECTION
	end if

	state.needsRedraw = -1
end sub

private sub HandleConnectionKey( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byref eventData as event )
	dim as string ptr fieldValue

	if( state.activeField = 0 ) then
		fieldValue = @options.serverText
	else
		fieldValue = @options.password
	end if

	select case eventData.scancode
	case SC_TAB
		state.activeField = 1 - state.activeField
	case SC_BACKSPACE
		if( len( *fieldValue ) > 0 ) then *fieldValue = left( *fieldValue, len( *fieldValue ) - 1 )
	case SC_ENTER
		BeginConnection( state, options, client )
	case SC_ESCAPE
		state.running = 0
	case else
		if( eventData.ascii >= 32 andalso eventData.ascii <= 126 ) then
			if( state.activeField = 0 andalso len( *fieldValue ) < 255 ) then
				*fieldValue &= chr( eventData.ascii )
			elseif( state.activeField = 1 andalso len( *fieldValue ) < 64 ) then
				*fieldValue &= chr( eventData.ascii )
			end if
		end if
	end select

	state.needsRedraw = -1
end sub

private sub HandleConnectionClick( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byval mouseX as integer, byval mouseY as integer )
	dim as integer panelWidth = 520
	dim as integer panelHeight = 400
	dim as integer x
	dim as integer y

	if( panelWidth > state.windowWidth - 30 ) then panelWidth = state.windowWidth - 30
	if( panelWidth < 330 ) then panelWidth = 330
	x = ( state.windowWidth - panelWidth ) \ 2
	y = ( state.windowHeight - panelHeight ) \ 2
	if( y < 10 ) then y = 10

	if( HitRectangle( mouseX, mouseY, x + 24, y + 72, panelWidth - 48, 25 ) ) then
		state.activeField = 0
	elseif( HitRectangle( mouseX, mouseY, x + 24, y + 125, panelWidth - 48, 25 ) ) then
		state.activeField = 1
	elseif( HitRectangle( mouseX, mouseY, x + 24, y + 168, panelWidth - 48, 20 ) ) then
		options.sharedSession = not options.sharedSession
	elseif( HitRectangle( mouseX, mouseY, x + 24, y + 196, panelWidth - 48, 20 ) ) then
		options.viewOnly = not options.viewOnly
	elseif( HitRectangle( mouseX, mouseY, x + 24, y + 224, panelWidth - 48, 20 ) ) then
		options.scaleToFit = not options.scaleToFit
	elseif( HitRectangle( mouseX, mouseY, x + 24, y + 252, panelWidth - 48, 20 ) ) then
		options.showToolbar = not options.showToolbar
	elseif( HitRectangle( mouseX, mouseY, x + 24, y + 280, panelWidth - 48, 20 ) ) then
		options.preferRaw = not options.preferRaw
	elseif( HitRectangle( mouseX, mouseY, x + panelWidth - 220, y + 357, 92, 28 ) ) then
		BeginConnection( state, options, client )
	elseif( HitRectangle( mouseX, mouseY, x + panelWidth - 116, y + 357, 92, 28 ) ) then
		state.running = 0
	end if

	state.needsRedraw = -1
end sub

private sub HandleOverlayKey( byref state as UiState, byref client as RfbClient, byref eventData as event )
	if( state.overlay = UI_OVERLAY_CLIPBOARD ) then
		select case eventData.scancode
		case SC_BACKSPACE
			if( len( state.clipboardDraft ) > 0 ) then state.clipboardDraft = left( state.clipboardDraft, len( state.clipboardDraft ) - 1 )
		case SC_ENTER
			RfbSendClipboard( client, state.clipboardDraft )
			state.overlay = UI_OVERLAY_NONE
		case SC_ESCAPE
			state.overlay = UI_OVERLAY_NONE
		case else
			if( eventData.ascii >= 32 andalso eventData.ascii <= 126 andalso len( state.clipboardDraft ) < VNC_MAX_CLIPBOARD_BYTES ) then
				state.clipboardDraft &= chr( eventData.ascii )
			end if
		end select
	elseif( eventData.scancode = SC_ESCAPE orelse eventData.scancode = SC_ENTER ) then
		state.overlay = UI_OVERLAY_NONE
	end if

	state.needsRedraw = -1
end sub

private sub HandleOverlayClick( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byval mouseX as integer, byval mouseY as integer )
	dim as integer panelWidth
	dim as integer panelHeight
	dim as integer x
	dim as integer y

	select case state.overlay
	case UI_OVERLAY_OPTIONS
		panelWidth = 390
#Ifdef __FB_GFXLIB3__
		panelHeight = 270
#Else
		panelHeight = 225
#EndIf
		x = ( state.windowWidth - panelWidth ) \ 2
		y = ( state.windowHeight - panelHeight ) \ 2
		if( HitRectangle( mouseX, mouseY, x + 28, y + 53, panelWidth - 56, 24 ) ) then
			options.viewOnly = not options.viewOnly
			client.viewOnly = options.viewOnly
		elseif( HitRectangle( mouseX, mouseY, x + 28, y + 85, panelWidth - 56, 24 ) ) then
			options.scaleToFit = not options.scaleToFit
		elseif( HitRectangle( mouseX, mouseY, x + 28, y + 117, panelWidth - 56, 24 ) ) then
			options.showToolbar = not options.showToolbar
			state.overlay = UI_OVERLAY_NONE
#Ifdef __FB_GFXLIB3__
		elseif( HitRectangle( mouseX, mouseY, x + 28, y + 170, 150, 24 ) ) then
			state.scaleFilter = GFX3_FILTER_NEAREST
		elseif( HitRectangle( mouseX, mouseY, x + 200, y + 170, 160, 24 ) ) then
			state.scaleFilter = GFX3_FILTER_LINEAR
		elseif( HitRectangle( mouseX, mouseY, x + panelWidth - 110, y + 224, 82, 28 ) ) then
			state.overlay = UI_OVERLAY_NONE
#Else
		elseif( HitRectangle( mouseX, mouseY, x + panelWidth - 110, y + 174, 82, 28 ) ) then
			state.overlay = UI_OVERLAY_NONE
#EndIf
		end if

	case UI_OVERLAY_INFO
		panelWidth = 450
		panelHeight = 245
		x = ( state.windowWidth - panelWidth ) \ 2
		y = ( state.windowHeight - panelHeight ) \ 2
		if( HitRectangle( mouseX, mouseY, x + panelWidth - 110, y + 210, 82, 28 ) ) then state.overlay = UI_OVERLAY_NONE

	case UI_OVERLAY_CLIPBOARD
		panelWidth = 520
		panelHeight = 245
		if( panelWidth > state.windowWidth - 20 ) then panelWidth = state.windowWidth - 20
		x = ( state.windowWidth - panelWidth ) \ 2
		y = ( state.windowHeight - panelHeight ) \ 2
		if( HitRectangle( mouseX, mouseY, x + panelWidth - 220, y + 188, 92, 28 ) ) then
			RfbSendClipboard( client, state.clipboardDraft )
			state.overlay = UI_OVERLAY_NONE
		elseif( HitRectangle( mouseX, mouseY, x + panelWidth - 116, y + 188, 92, 28 ) ) then
			state.overlay = UI_OVERLAY_NONE
		end if
	end select

	state.needsRedraw = -1
end sub

private sub HandleToolbarAction( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byval actionIndex as integer )
	select case actionIndex
	case 1
		if( state.threadState <> 0 ) then VncThreadsStop *state.threadState
		RfbDisconnect( client )
		ReleaseFrameImage state
#Ifdef __FB_GFXLIB3__
		ReleaseFrameSurface state
#EndIf
		state.mode = UI_MODE_CONNECTION
		state.statusText = ""
		state.overlay = UI_OVERLAY_NONE
		windowtitle VNC_PROGRAM_NAME
	case 2
		state.overlay = UI_OVERLAY_OPTIONS
	case 3
		VncFramebufferLock client
		RfbRequestUpdate( client, 0 )
		VncFramebufferUnlock client
	case 4
		RfbSendCtrlEscape( client )
	case 5
		RfbSendCtrlAltDelete( client )
	case 6
		ToggleFullScreen( state )
	case 7
		options.scaleToFit = not options.scaleToFit
	case 8
		options.viewOnly = not options.viewOnly
		client.viewOnly = options.viewOnly
	case 9
		VncFramebufferLock client
		state.clipboardDraft = client.clipboardText
		VncFramebufferUnlock client
		state.overlay = UI_OVERLAY_CLIPBOARD
	case 10
		state.overlay = UI_OVERLAY_INFO
	end select

	state.needsRedraw = -1
end sub

private sub HandleScrollbarClick( byref state as UiState, byref client as RfbClient, byref layout as UiLayout, byval mouseX as integer, byval mouseY as integer )
	dim as integer maximumScroll

	if( layout.showScrollbars = 0 ) then exit sub

	if( mouseY >= layout.contentTop + layout.viewHeight andalso mouseY < layout.contentBottom ) then
		maximumScroll = client.serverWidth - layout.viewWidth
		if( maximumScroll > 0 andalso layout.viewWidth > 1 ) then
			state.scrollX = mouseX * maximumScroll \ ( layout.viewWidth - 1 )
		end if
	elseif( mouseX >= layout.viewWidth andalso mouseY >= layout.contentTop ) then
		maximumScroll = client.serverHeight - layout.viewHeight
		if( maximumScroll > 0 andalso layout.viewHeight > 1 ) then
			state.scrollY = ( mouseY - layout.contentTop ) * maximumScroll \ ( layout.viewHeight - 1 )
		end if
	end if
end sub

private function MapPointerToRemote( byref layout as UiLayout, byref client as RfbClient, byval mouseX as integer, byval mouseY as integer, byref remoteX as integer, byref remoteY as integer ) as integer
	if( mouseX < layout.viewLeft orelse mouseX >= layout.viewLeft + layout.viewWidth orelse _
		mouseY < layout.viewTop orelse mouseY >= layout.viewTop + layout.viewHeight ) then return 0
	if( mouseX < layout.destinationX orelse mouseX >= layout.destinationX + layout.destinationWidth orelse _
		mouseY < layout.destinationY orelse mouseY >= layout.destinationY + layout.destinationHeight ) then return 0

	remoteX = ( mouseX - layout.destinationX ) * client.serverWidth \ layout.destinationWidth
	remoteY = ( mouseY - layout.destinationY ) * client.serverHeight \ layout.destinationHeight
	return -1
end function

private sub HandleSessionEvent( byref state as UiState, byref options as VncOptions, byref client as RfbClient, byref eventData as event )
	dim as UiLayout layout
	dim as integer actionIndex
	dim as integer remoteX
	dim as integer remoteY
	dim as ulong keysym
	dim as integer wheelMask

	/'
	    gfxlib may recreate the screen while changing display modes. Keeping the
	    viewer shortcut state from gfxlib events makes the chord independent of
	    the keyboard snapshot associated with either the old or new screen.
	'/
	UpdateViewerModifierState state, eventData

	if( eventData.type = EVENT_MOUSE_MOVE ) then
		state.pointerX = eventData.x
		state.pointerY = eventData.y
	elseif( eventData.type = EVENT_MOUSE_BUTTON_PRESS orelse _
		eventData.type = EVENT_MOUSE_BUTTON_RELEASE orelse _
		eventData.type = EVENT_MOUSE_WHEEL ) then
		ReadCurrentPointer( state )
	end if

	/'
	    Ctrl-Alt-Shift-F belongs to the viewer rather than the remote desktop.
	    Modifier presses may already have crossed the wire before F identifies
	    the chord, so release them remotely to avoid leaving a modifier stuck.
	'/
	if( ( eventData.type = EVENT_KEY_PRESS orelse _
		eventData.type = EVENT_KEY_REPEAT orelse _
		eventData.type = EVENT_KEY_RELEASE ) andalso eventData.scancode = SC_F ) then
		if( eventData.type = EVENT_KEY_PRESS andalso FullScreenChordIsHeld( state ) ) then
			state.fullScreenHotkeyActive = -1
			ReleaseViewerModifiers client
			ToggleFullScreen state
			ClearViewerModifierState state
			exit sub
		elseif( eventData.type = EVENT_KEY_REPEAT andalso state.fullScreenHotkeyActive ) then
			exit sub
		elseif( eventData.type = EVENT_KEY_RELEASE andalso state.fullScreenHotkeyActive ) then
			state.fullScreenHotkeyActive = 0
			exit sub
		elseif( eventData.type = EVENT_KEY_PRESS ) then
			/' A focus or mode switch may have consumed the prior F release. '/
			state.fullScreenHotkeyActive = 0
		end if
	end if

	if( state.overlay <> UI_OVERLAY_NONE ) then
		if( eventData.type = EVENT_KEY_PRESS ) then
			HandleOverlayKey( state, client, eventData )
		elseif( eventData.type = EVENT_MOUSE_BUTTON_PRESS andalso eventData.button = BUTTON_LEFT ) then
			HandleOverlayClick( state, options, client, state.pointerX, state.pointerY )
		end if
		exit sub
	end if

	CalculateLayout( state, options, client, layout )

	select case eventData.type
	case EVENT_KEY_PRESS
		if( eventData.scancode = SC_F8 ) then
			options.showToolbar = not options.showToolbar
			state.needsRedraw = -1
		else
			keysym = KeySymFromEvent( eventData, state.controlHeld )
			if( keysym <> 0 ) then RfbSendKey( client, keysym, -1 )
		end if
	case EVENT_KEY_REPEAT
		keysym = KeySymFromEvent( eventData, state.controlHeld )
		if( keysym <> 0 ) then RfbSendKey( client, keysym, -1 )
	case EVENT_KEY_RELEASE
		if( eventData.scancode <> SC_F8 ) then
			keysym = KeySymFromEvent( eventData, state.controlHeld )
			if( keysym <> 0 ) then RfbSendKey( client, keysym, 0 )
		end if
	case EVENT_WINDOW_LOST_FOCUS
		state.fullScreenHotkeyActive = 0
		ClearViewerModifierState state
		ReleaseViewerModifiers( client )
	case EVENT_MOUSE_MOVE
		if( MapPointerToRemote( layout, client, eventData.x, eventData.y, remoteX, remoteY ) ) then
			RfbSendPointer( client, remoteX, remoteY, state.pointerMask )
		end if
	case EVENT_MOUSE_BUTTON_PRESS
		if( eventData.button = BUTTON_LEFT andalso state.fullScreen = 0 andalso options.showToolbar andalso state.pointerY < UI_TOOLBAR_HEIGHT ) then
			actionIndex = ToolbarActionAt( state.pointerX, state.pointerY, options )
			if( actionIndex > 0 ) then HandleToolbarAction( state, options, client, actionIndex )
		elseif( eventData.button = BUTTON_LEFT andalso layout.showScrollbars andalso _
			( state.pointerX >= layout.viewWidth orelse state.pointerY >= layout.contentTop + layout.viewHeight ) ) then
			HandleScrollbarClick( state, client, layout, state.pointerX, state.pointerY )
			state.needsRedraw = -1
		elseif( MapPointerToRemote( layout, client, state.pointerX, state.pointerY, remoteX, remoteY ) ) then
			if( eventData.button = BUTTON_LEFT ) then state.pointerMask or= 1
			if( eventData.button = BUTTON_MIDDLE ) then state.pointerMask or= 2
			if( eventData.button = BUTTON_RIGHT ) then state.pointerMask or= 4
			RfbSendPointer( client, remoteX, remoteY, state.pointerMask )
		end if
	case EVENT_MOUSE_BUTTON_RELEASE
		if( eventData.button = BUTTON_LEFT ) then state.pointerMask and= not 1
		if( eventData.button = BUTTON_MIDDLE ) then state.pointerMask and= not 2
		if( eventData.button = BUTTON_RIGHT ) then state.pointerMask and= not 4
		if( MapPointerToRemote( layout, client, state.pointerX, state.pointerY, remoteX, remoteY ) ) then
			RfbSendPointer( client, remoteX, remoteY, state.pointerMask )
		end if
	case EVENT_MOUSE_WHEEL
		if( MapPointerToRemote( layout, client, state.pointerX, state.pointerY, remoteX, remoteY ) ) then
			if( eventData.z > state.lastWheelZ ) then wheelMask = 8 else wheelMask = 16
			state.lastWheelZ = eventData.z
			RfbSendPointer( client, remoteX, remoteY, state.pointerMask or wheelMask )
			RfbSendPointer( client, remoteX, remoteY, state.pointerMask )
		end if
	end select
end sub

function UiRun( byref options as VncOptions, byval connectImmediately as integer ) as integer
	dim as UiState state
	dim as RfbClient client
	dim as VncThreadState threadState
	dim as event eventData
	dim as string threadError
	dim as ulong threadGeneration
	dim as double frameStartedAt

	state.windowWidth = VNC_DEFAULT_WINDOW_WIDTH
	state.windowHeight = VNC_DEFAULT_WINDOW_HEIGHT
	state.running = -1
	state.mode = UI_MODE_CONNECTION
	state.activeField = 0
	state.overlay = UI_OVERLAY_NONE
	state.needsRedraw = -1
	state.fullScreen = 0
	state.fullScreenHotkeyActive = 0
	ClearViewerModifierState state
	state.scrollX = 0
	state.scrollY = 0
	state.pointerMask = 0
	state.pointerX = 0
	state.pointerY = 0
	state.lastWheelZ = 0
	state.statusText = ""
	state.threadFallbackReason = ""
	state.lastUpdateCount = 0
	state.lastThreadGeneration = 0
	state.threadFramePending = 0
	state.lastThreadFrameTime = 0.0
	state.threadState = @threadState
	state.frameImage = 0
	state.frameImagePixels = 0
	state.frameImageWidth = 0
	state.frameImageHeight = 0
	state.frameImagePitch = 0
#Ifdef __FB_GFXLIB3__
	state.frameSurface = 0
	state.frameSurfaceWidth = 0
	state.frameSurfaceHeight = 0
	state.frameSurfaceReady = 0
	state.frameUploadPixels = 0
	state.frameUploadCapacity = 0
	state.scaleFilter = GFX3_FILTER_NEAREST
#EndIf

	RfbInitialise( client )
	VncThreadsInitialise( threadState )
	backend_Init( state.windowWidth, state.windowHeight, 0, BACKEND_WINDOW_RESIZABLE, BACKEND_COLOR_DEPTH_TRUE_COLOR )
	if( screenptr = 0 ) then
		print "Unable to create the gfxlib3 viewer window."
		return 1
	end if
	windowtitle VNC_PROGRAM_NAME

	if( connectImmediately ) then BeginConnection( state, options, client )

	while( state.running )
		while( screenevent( @eventData ) <> 0 )
			select case eventData.type
			case EVENT_WINDOW_CLOSE
				state.running = 0
			case EVENT_WINDOW_RESIZE
				state.windowWidth = eventData.width
				state.windowHeight = eventData.height
				if( state.windowWidth < 1 ) then state.windowWidth = 1
				if( state.windowHeight < 1 ) then state.windowHeight = 1
				state.needsRedraw = -1
			case else
				if( state.mode = UI_MODE_CONNECTION ) then
					if( eventData.type = EVENT_KEY_PRESS ) then
						HandleConnectionKey( state, options, client, eventData )
					elseif( eventData.type = EVENT_MOUSE_BUTTON_PRESS andalso eventData.button = BUTTON_LEFT ) then
						ReadCurrentPointer( state )
						HandleConnectionClick( state, options, client, state.pointerX, state.pointerY )
					end if
				else
					HandleSessionEvent( state, options, client, eventData )
				end if
			end select
		wend

		if( state.mode = UI_MODE_SESSION andalso client.connected ) then
			if( VncThreadsActive( threadState ) ) then
				if( VncThreadsPoll( threadState, threadGeneration, threadError ) ) then
					state.statusText = threadError
					VncThreadsStop threadState
					RfbDisconnect( client )
					state.mode = UI_MODE_CONNECTION
					windowtitle VNC_PROGRAM_NAME
				else
					if( threadGeneration <> state.lastThreadGeneration ) then
						state.lastThreadGeneration = threadGeneration
						state.threadFramePending = -1
					end if
				end if
			else
				/' Limit each serial pass so a busy server cannot starve window events. '/
				for messageIndex as integer = 1 to 8
					if( RfbHasMessage( client ) = 0 ) then exit for
					if( RfbProcessOneMessage( client ) = 0 ) then
						state.statusText = client.errorMessage
						RfbDisconnect( client )
						state.mode = UI_MODE_CONNECTION
						windowtitle VNC_PROGRAM_NAME
						exit for
					end if
					state.needsRedraw = -1
				next messageIndex

				if( client.updatesReceived <> state.lastUpdateCount ) then
					state.lastUpdateCount = client.updatesReceived
					state.needsRedraw = -1
				end if
			end if
		end if

		/'
		    A decoder can complete hundreds of small updates per second. The main
		    thread keeps only the newest completed framebuffer until the next useful
		    presentation time. Window and input events still set needsRedraw directly
		    and therefore remain immediate.
		'/
		if( state.threadFramePending andalso state.needsRedraw = 0 ) then
			if( UiElapsedSeconds( state.lastThreadFrameTime ) >= UI_THREADED_FRAME_INTERVAL_SECONDS ) then
				state.needsRedraw = -1
			end if
		end if

		if( state.needsRedraw ) then
			frameStartedAt = timer
			if( state.mode = UI_MODE_CONNECTION ) then
				DrawConnectionDialog( state, options )
			else
				DrawSession( state, options, client )
			end if
			backend_Flip()
			state.threadFramePending = 0
			if( state.mode = UI_MODE_SESSION ) then
				state.lastThreadFrameTime = frameStartedAt
			end if
			state.needsRedraw = 0
		end if

		sleep 2, 1
	wend

	VncThreadsStop threadState
	RfbDisconnect( client )
#Ifdef __FB_GFXLIB3__
	ReleaseFrameSurface state
	ReleaseFrameUploadBuffer state
#EndIf
	ReleaseFrameImage state
	backend_Exit()
	screen 0
	return 0
end function

/' end of ui.bas '/
