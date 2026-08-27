/'
    Project: Portable FreeBASIC VNC Viewer
    --------------------------------------

    File: des.bas

    Purpose:

        Implement the DES operation required by classic VNC authentication.

    Responsibilities:

        - reverse password bits as required by the VNC protocol
        - construct the sixteen DES round keys
        - encrypt the server's two eight-byte challenge blocks

    This file intentionally does NOT contain:

        - general-purpose cryptographic APIs
        - random number generation
        - network or user interface code

    Classic VNC authentication is retained for interoperability. It is not a
    secure transport: the password is limited to eight bytes and the session
    is not encrypted. Use the viewer through a trusted network or tunnel.
'/

#include once "des.bi"

private dim shared as integer DES_IP( 0 to 63 ) = { _
	58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4, _
	62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8, _
	57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3, _
	61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7 }

private dim shared as integer DES_FINAL_PERMUTATION( 0 to 63 ) = { _
	40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31, _
	38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29, _
	36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27, _
	34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25 }

private dim shared as integer DES_EXPANSION( 0 to 47 ) = { _
	32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, _
	8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17, _
	16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25, _
	24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1 }

private dim shared as integer DES_P( 0 to 31 ) = { _
	16, 7, 20, 21, 29, 12, 28, 17, _
	1, 15, 23, 26, 5, 18, 31, 10, _
	2, 8, 24, 14, 32, 27, 3, 9, _
	19, 13, 30, 6, 22, 11, 4, 25 }

private dim shared as integer DES_PC1( 0 to 55 ) = { _
	57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18, _
	10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36, _
	63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22, _
	14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4 }

private dim shared as integer DES_PC2( 0 to 47 ) = { _
	14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, _
	23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2, _
	41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48, _
	44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32 }

private dim shared as integer DES_SHIFTS( 0 to 15 ) = { _
	1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1 }

/' Each S-box occupies four rows of sixteen values in protocol bit order. '/
private dim shared as integer DES_SBOX( 0 to 511 ) = { _
	14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7, _
	0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8, _
	4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0, _
	15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13, _
	15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10, _
	3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5, _
	0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15, _
	13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9, _
	10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8, _
	13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1, _
	13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7, _
	1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12, _
	7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15, _
	13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9, _
	10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4, _
	3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14, _
	2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9, _
	14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6, _
	4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14, _
	11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3, _
	12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11, _
	10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8, _
	9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6, _
	4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13, _
	4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1, _
	13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6, _
	1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2, _
	6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12, _
	13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7, _
	1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2, _
	7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8, _
	2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11 }

private function ReverseByteBits( byval value as ubyte ) as ubyte
	dim as ubyte reversed = 0
	dim as integer bitIndex

	for bitIndex = 0 to 7
		reversed = cubyte( reversed shl 1 )
		if( ( value and ( 1 shl bitIndex ) ) <> 0 ) then
			reversed or= 1
		end if
	next bitIndex

	return reversed
end function

private sub BytesToBits( byval source as const ubyte ptr, byval bits as ubyte ptr )
	dim as integer byteIndex
	dim as integer bitIndex

	for byteIndex = 0 to 7
		for bitIndex = 0 to 7
			if( ( source[byteIndex] and ( 1 shl ( 7 - bitIndex ) ) ) <> 0 ) then
				bits[byteIndex * 8 + bitIndex] = 1
			else
				bits[byteIndex * 8 + bitIndex] = 0
			end if
		next bitIndex
	next byteIndex
end sub

private sub BitsToBytes( byval bits as const ubyte ptr, byval destination as ubyte ptr )
	dim as integer byteIndex
	dim as integer bitIndex
	dim as ubyte value

	for byteIndex = 0 to 7
		value = 0
		for bitIndex = 0 to 7
			value = cubyte( value shl 1 )
			value or= bits[byteIndex * 8 + bitIndex]
		next bitIndex
		destination[byteIndex] = value
	next byteIndex
end sub

private sub BuildRoundKeys( byval key as const ubyte ptr, byval roundKeys as ubyte ptr )
	dim as ubyte keyBits( 0 to 63 )
	dim as ubyte halves( 0 to 55 )
	dim as ubyte temporary( 0 to 27 )
	dim as integer roundIndex
	dim as integer bitIndex
	dim as integer shiftIndex

	BytesToBits( key, @keyBits( 0 ) )

	for bitIndex = 0 to 55
		halves( bitIndex ) = keyBits( DES_PC1( bitIndex ) - 1 )
	next bitIndex

	for roundIndex = 0 to 15
		for shiftIndex = 1 to DES_SHIFTS( roundIndex )
			for bitIndex = 0 to 27
				temporary( bitIndex ) = halves( bitIndex )
			next bitIndex
			for bitIndex = 0 to 26
				halves( bitIndex ) = temporary( bitIndex + 1 )
			next bitIndex
			halves( 27 ) = temporary( 0 )

			for bitIndex = 0 to 27
				temporary( bitIndex ) = halves( 28 + bitIndex )
			next bitIndex
			for bitIndex = 0 to 26
				halves( 28 + bitIndex ) = temporary( bitIndex + 1 )
			next bitIndex
			halves( 55 ) = temporary( 0 )
		next shiftIndex

		for bitIndex = 0 to 47
			roundKeys[roundIndex * 48 + bitIndex] = halves( DES_PC2( bitIndex ) - 1 )
		next bitIndex
	next roundIndex
end sub

private sub EncryptDesBlock( byval block as ubyte ptr, byval roundKeys as const ubyte ptr )
	dim as ubyte inputBits( 0 to 63 )
	dim as ubyte permuted( 0 to 63 )
	dim as ubyte leftHalf( 0 to 31 )
	dim as ubyte rightHalf( 0 to 31 )
	dim as ubyte expanded( 0 to 47 )
	dim as ubyte substituted( 0 to 31 )
	dim as ubyte nextRight( 0 to 31 )
	dim as ubyte preoutput( 0 to 63 )
	dim as ubyte outputBits( 0 to 63 )
	dim as integer roundIndex
	dim as integer bitIndex
	dim as integer boxIndex
	dim as integer rowIndex
	dim as integer columnIndex
	dim as integer boxValue

	BytesToBits( block, @inputBits( 0 ) )

	for bitIndex = 0 to 63
		permuted( bitIndex ) = inputBits( DES_IP( bitIndex ) - 1 )
	next bitIndex

	for bitIndex = 0 to 31
		leftHalf( bitIndex ) = permuted( bitIndex )
		rightHalf( bitIndex ) = permuted( 32 + bitIndex )
	next bitIndex

	for roundIndex = 0 to 15
		for bitIndex = 0 to 47
			expanded( bitIndex ) = rightHalf( DES_EXPANSION( bitIndex ) - 1 ) xor _
				roundKeys[roundIndex * 48 + bitIndex]
		next bitIndex

		for boxIndex = 0 to 7
			rowIndex = expanded( boxIndex * 6 ) * 2 + expanded( boxIndex * 6 + 5 )
			columnIndex = expanded( boxIndex * 6 + 1 ) * 8 + _
				expanded( boxIndex * 6 + 2 ) * 4 + _
				expanded( boxIndex * 6 + 3 ) * 2 + _
				expanded( boxIndex * 6 + 4 )
			boxValue = DES_SBOX( boxIndex * 64 + rowIndex * 16 + columnIndex )

			for bitIndex = 0 to 3
				if( ( boxValue and ( 1 shl ( 3 - bitIndex ) ) ) <> 0 ) then
					substituted( boxIndex * 4 + bitIndex ) = 1
				else
					substituted( boxIndex * 4 + bitIndex ) = 0
				end if
			next bitIndex
		next boxIndex

		for bitIndex = 0 to 31
			nextRight( bitIndex ) = leftHalf( bitIndex ) xor substituted( DES_P( bitIndex ) - 1 )
		next bitIndex

		for bitIndex = 0 to 31
			leftHalf( bitIndex ) = rightHalf( bitIndex )
			rightHalf( bitIndex ) = nextRight( bitIndex )
		next bitIndex
	next roundIndex

	for bitIndex = 0 to 31
		preoutput( bitIndex ) = rightHalf( bitIndex )
		preoutput( 32 + bitIndex ) = leftHalf( bitIndex )
	next bitIndex

	for bitIndex = 0 to 63
		outputBits( bitIndex ) = preoutput( DES_FINAL_PERMUTATION( bitIndex ) - 1 )
	next bitIndex

	BitsToBytes( @outputBits( 0 ), block )
end sub

sub VncEncryptChallenge( byref password as const string, byval challenge as ubyte ptr )
	dim as ubyte key( 0 to 7 )
	dim as ubyte roundKeys( 0 to 767 )
	dim as integer byteIndex

	if( challenge = 0 ) then
		exit sub
	end if

	for byteIndex = 0 to 7
		if( byteIndex < len( password ) ) then
			key( byteIndex ) = ReverseByteBits( asc( mid( password, byteIndex + 1, 1 ) ) and 255 )
		else
			key( byteIndex ) = 0
		end if
	next byteIndex

	BuildRoundKeys( @key( 0 ), @roundKeys( 0 ) )
	EncryptDesBlock( challenge, @roundKeys( 0 ) )
	EncryptDesBlock( challenge + 8, @roundKeys( 0 ) )
end sub

/' end of des.bas '/
