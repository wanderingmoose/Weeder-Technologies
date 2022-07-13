'This QBASIC program will test out the RS-232 Digital Input/Output kit.
'Set the WTDIO address to "A". Start the program then hit "C" on the
'keyboard. Type in any one of the valid commands you wish to send to
'the WTDIO then press enter. The WTDIO will respond to the command and
'return any data (if applicable) which will be displayed on the monitor.

'Hit "ESC" to exit the program.


        CLS
        OPEN "COM2:1200,N,8,1" FOR RANDOM AS #1
        ON COM(2) GOSUB RECEIVE
        COM(2) ON
       
        DO
            KEY$ = INKEY$
            IF UCASE$(KEY$) = "C" THEN
                INPUT "Enter Command ", OUT$
                GOSUB TRANSMIT
            END IF
        LOOP UNTIL KEY$ = CHR$(27)
        CLOSE #1
        END

RECEIVE:
        COM(2) OFF                      'disable event trapping
        IF INPUT$(2, #1) = "DA" THEN    'test for WTDIO header character "D"
and address "A"
            LINE INPUT #1, IN$          'get response from WTDIO board
            PRINT IN$                   'print response to screen
        ELSE LINE INPUT #1, DISCARD$    'discard data using different header
        END IF
        COM(2) ON                       'enable event trapping
        RETURN

TRANSMIT:
        COM(2) OFF                      'disable event trapping
        OUT$ = "DA" + OUT$              'append header character "D" and
address "A"
        PRINT #1, OUT$                  'send string to WTDIO
        LINE INPUT #1, DISCARD$         'discard echo
        COM(2) ON                       'enable event trapping
        RETURN
       
        


