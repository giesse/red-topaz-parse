Red []

results-file?: func [file] [
    %.results = suffix? file
]

mold-flat: func [value size] [
    either size < 0 [
        value: mold/flat value
        if greater? length? value absolute size [
            value: skip tail value size
            change value "..."
        ]
    ] [
        value: mold/flat/part value size
        if size = length? value [
            change skip tail value -3 "..."
        ]
    ]
    value
]

review-test-results: function [file] [
    results: load/all file
    print "Summary of failed tests:"
    repeat i length? results [
        result: pick results i
        if result/status = 'Failure [
            print [i ")" mold-flat result/test 80]
        ]
    ]
    to-review: copy [Unknown]
    print ""
    if find ["y" "yes"] ask "Review failed tests? " [
        append to-review 'Failure
    ]
    foreach result results [
        if find to-review result/status [
            print ["^/Test:" mold-flat result/test 80]
            print ["Status:" result/status]
            if result/note [print result/note]
            switch/default result/type [
                error! [
                    print "Causes error:"
                    print result/result
                ]
            ] [
                print ["Result: (" result/type ")" mold-flat result/result 80]
            ]
            forever [
                switch/default ask "Pass/Fail/Unknown/PRint/Quit? " [
                    "p" "pass" [
                        result/status: 'Pass
                        break
                    ]
                    "f" "fail" [
                        result/status: 'Failure
                        break
                    ]
                    "" [
                        break
                    ]
                    "u" "unknown" [
                        result/status: 'Unknown
                        break
                    ]
                    "pr" "print" [
                        print "Test:"
                        probe result/test
                        print "^/Result:"
                        probe result/result
                        print ""
                    ]
                    "q" "quit" [quit]
                ] [
                    print
{Type "p" or "pass" etc. to mark the test as passed;
"pr" or "print" to print the whole test and results; etc.
Just hitting RETURN will leave the test status as it is.}
                ]
            ]
        ]
    ]
    write file mold/only/all results
]

foreach file read %tests/ [
    if results-file? file [
        print ["^/^/*** File:" file]
        review-test-results rejoin [%tests/ file]
        print "***^/"
    ]
]
