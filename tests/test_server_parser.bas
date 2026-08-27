/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: test_server_parser.bas

    Purpose:

        Verify TightVNC-compatible server address parsing.

    Responsibilities:

        - check host, display-number, and literal-port forms
        - reject malformed or out-of-range values

    This file intentionally does NOT contain:

        - network connections
        - graphics window creation
        - protocol handshaking
'/

#include once "ui.bi"

private sub CheckAddress( byref inputText as const string, byref expectedHost as const string, byval expectedPort as integer, byval expectedResult as integer, byref failures as integer )
	dim as string host
	dim as integer port
	dim as string errorText
	dim as integer actualResult

	actualResult = UiParseServer( inputText, host, port, errorText )
	if( ( actualResult <> 0 ) <> ( expectedResult <> 0 ) ) then
		print "Unexpected parser result for '" & inputText & "': " & errorText
		failures += 1
	elseif( actualResult andalso ( host <> expectedHost orelse port <> expectedPort ) ) then
		print "Unexpected address for '" & inputText & "': " & host & ":" & port
		failures += 1
	end if
end sub

dim as integer failures = 0

CheckAddress( "example.test", "example.test", 5900, -1, failures )
CheckAddress( "example.test:2", "example.test", 5902, -1, failures )
CheckAddress( "example.test::5999", "example.test", 5999, -1, failures )
CheckAddress( ":1", "127.0.0.1", 5901, -1, failures )
CheckAddress( "::1", "::1", 5900, -1, failures )
CheckAddress( "[::1]:2", "::1", 5902, -1, failures )
CheckAddress( "[::1]::5999", "::1", 5999, -1, failures )
CheckAddress( "example.test:59635", "example.test", 65535, -1, failures )
CheckAddress( "example.test:no", "", 0, 0, failures )
CheckAddress( "example.test:59636", "", 0, 0, failures )
CheckAddress( "example.test::70000", "", 0, 0, failures )
CheckAddress( "bad,host", "", 0, 0, failures )

if( failures = 0 ) then print "Server parser test passed."
end failures

/' end of test_server_parser.bas '/
