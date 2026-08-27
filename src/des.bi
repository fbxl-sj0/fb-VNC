/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: des.bi

    Purpose:

        Declare the classic VNC challenge-response helper.

    Responsibilities:

        - encrypt a 16-byte VNC authentication challenge
        - derive the protocol DES key from an eight-byte password

    This file intentionally does NOT contain:

        - password prompting or storage policy
        - transport input/output
        - any non-VNC authentication method
'/

#ifndef PORTABLE_VNC_DES_BI
#define PORTABLE_VNC_DES_BI

declare sub VncEncryptChallenge( byref password as const string, byval challenge as ubyte ptr )

#endif

/' end of des.bi '/
