/'
    Project: omaGUI Test Harness
    ---------------------------

    File: test_harness.bi

    Purpose:

        Provide shared assertion and summary helpers for one test process.

    Responsibilities:

        - count passing and failing assertions
        - label test sections
        - return a failing process status when assertions fail

    This file intentionally does NOT contain:

        - production widget behavior
        - graphics or input setup
'/

#ifndef __TEST_HARNESS_BI__
#define __TEST_HARNESS_BI__

/'
    This test-only module owns the counters and section label for one suite
    process. Production code never includes or mutates this state.
'/
Dim Shared As Integer test_total_pass
Dim Shared As Integer test_total_fail
Dim Shared As String current_section

Sub test_Section(ByVal nm As String)
    Print "--- SECTION: " & nm & " ---"
    current_section = nm
End Sub

Sub AssertTrue(ByVal condition As Integer, ByVal msg As String)
    If condition = 0 Then
        Print "  [FAIL] " & msg
        test_total_fail += 1
    Else
        Print "  [PASS] " & msg
        test_total_pass += 1
    End If
End Sub

Sub test_Summary()
    Print ""
    Print "========================================="
    Print "TEST SUMMARY"
    Print "  Passed: " & test_total_pass
    Print "  Failed: " & test_total_fail
    Print "========================================="
    If test_total_fail > 0 Then
        Print "RESULT: FAILURE"
        End 1
    Else
        Print "RESULT: SUCCESS"
    End If
End Sub

#endif

/' end of test_harness.bi '/
