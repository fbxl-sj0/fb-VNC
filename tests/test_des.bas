/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: test_des.bas

    Purpose:

        Verify the built-in classic VNC DES challenge response.

    Responsibilities:

        - exercise VNC password bit reversal
        - compare both encrypted challenge blocks with a known vector

    This file intentionally does NOT contain:

        - network or VNC server integration
        - external cryptographic library calls
        - production viewer logic beyond the public authentication helper
'/

#include once "des.bi"

dim as ubyte challenge( 0 to 15 )
dim as ubyte expected( 0 to 15 ) = { _
	&hB8, &h66, &h92, &h41, &h25, &hC8, &hEE, &hBB, _
	&h9D, &hEB, &hC1, &hDB, &h61, &hC5, &h38, &hE2 }
dim as integer failures = 0

for index as integer = 0 to 15
	challenge( index ) = index
next index

VncEncryptChallenge( "password", @challenge( 0 ) )

for index as integer = 0 to 15
	if( challenge( index ) <> expected( index ) ) then
		print "DES mismatch at byte"; index; ": expected"; hex( expected( index ), 2 ); " got"; hex( challenge( index ), 2 )
		failures += 1
	end if
next index

if( failures = 0 ) then print "VNC DES test passed."
end failures

/' end of test_des.bas '/
