/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: main.bas

    Purpose:

        Parse portable command-line options and start the gfxlib viewer.

    Responsibilities:

        - establish viewer defaults
        - accept optional startup connection settings
        - print command-line help and validation errors

    This file intentionally does NOT contain:

        - RFB protocol logic
        - TCP input/output
        - user interface drawing
'/

#include once "common.bi"
#include once "ui.bi"

private sub PrintUsage()
	print VNC_PROGRAM_NAME & " " & VNC_PROGRAM_VERSION
	print
	print "Usage: fbvnc [server] [options]"
	print
	print "Server forms:"
	print "  host:display       Traditional VNC display number, for example host:1"
	print "  host::port         Literal TCP port, for example host::5901"
	print
	print "Options:"
	print "  --server VALUE     Pre-fill and immediately connect to VALUE"
	print "  --password VALUE   Classic VNC password (visible to process-list tools)"
	print "  --view-only        Do not send keyboard, pointer, or clipboard input"
	print "  --exclusive        Ask the server to disconnect other viewers"
	print "  --no-scale         Start at one remote pixel per local pixel"
	print "  --raw              Prefer Raw encoding on a fast network"
	print "  --hide-toolbar     Hide the toolbar; F8 restores it"
	print "  --connect          Connect immediately using the current defaults"
	print "  --help              Show this help"
end sub

dim as VncOptions options
dim as integer connectImmediately = 0
dim as integer argumentIndex = 1
dim as string argument
dim as string followingArgument

options.serverText = VNC_DEFAULT_HOST
options.host = VNC_DEFAULT_HOST
options.port = VNC_DEFAULT_PORT
options.password = ""
options.sharedSession = -1
options.viewOnly = 0
options.scaleToFit = -1
options.showToolbar = -1
options.preferRaw = 0

while( len( command( argumentIndex ) ) > 0 )
	argument = command( argumentIndex )

	select case lcase( argument )
	case "--help", "-h", "/?"
		PrintUsage()
		end 0

	case "--server"
		followingArgument = command( argumentIndex + 1 )
		if( len( followingArgument ) = 0 ) then
			print "--server requires a value."
			end 2
		end if
		options.serverText = followingArgument
		connectImmediately = -1
		argumentIndex += 1

	case "--password"
		followingArgument = command( argumentIndex + 1 )
		if( len( followingArgument ) = 0 ) then
			print "--password requires a value."
			end 2
		end if
		options.password = followingArgument
		argumentIndex += 1

	case "--view-only"
		options.viewOnly = -1

	case "--exclusive"
		options.sharedSession = 0

	case "--no-scale"
		options.scaleToFit = 0

	case "--raw"
		options.preferRaw = -1

	case "--hide-toolbar"
		options.showToolbar = 0

	case "--connect"
		connectImmediately = -1

	case else
		if( left( argument, 1 ) = "-" ) then
			print "Unknown option: " & argument
			print "Use --help for usage."
			end 2
		end if
		options.serverText = argument
		connectImmediately = -1
	end select

	argumentIndex += 1
wend

end UiRun( options, connectImmediately )

/' end of main.bas '/
