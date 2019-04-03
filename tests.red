Red []

delta-time*: function [code count] [
    start: now/precise
    loop count code
    difference now/precise start
]
delta-time: function [
    "Return the time it takes to evaluate a block"
    code [block! word! function!] "Code to evaluate"
    /accuracy run-time [time! none!] "Longer time gives more accurate results, but takes longer to compute. Default 0:00:00.1"
][
    run-time: any [run-time 0:00:00.1]
    time: 0:00:00
    count: 1
    if word? :code [code: get code]
    cd: either block? :code [code] [[code]]
    while [time < run-time] [
        time: delta-time* cd count
        ; if your computer is really really fast, or now/precise is not accurate enough
        ; (hello Windows users!)
        either time > 0 [
            result: time / count
            ; multiply by 1.5 for faster convergence
            ; (ie. aim for 1.5*run-time)
            count: to integer! run-time * count * 1.5 / time
        ] [
            count: count * 10
        ]
    ]
    result
]

test-file?: func [file] [
    %.tests = suffix? file
]

load-header: function [file] [
    file: load/all file
    unless file/1 = 'Red [cause-error "Not a Red file"]
    file/2: make map! file/2
    next file
]

run-test-file: function [file] [
    print file
    file: clean-path rejoin [%tests/ file]
    summary: copy #(passed: 0 failed: 0 unknown: 0 perf-regressions: 0) 
    error: result: none ; to let FUNCTION catch them as a local
    bare-file: copy/part file skip tail file -6
    results-file: rejoin [bare-file %.results]
    perf-file: rejoin [bare-file %.perf]
    file: load-header file
    if files-to-test: file/1/Tests [
        foreach source-file files-to-test [
            if error? set/any 'error try [do source-file] [
                print [tab "UNABLE TO DO" source-file]
                print form error
                summary/failed: 1
                return summary
            ]
        ]
        print [tab "TESTS:" mold/only/flat files-to-test]
    ]
    results: either exists? results-file [load/all results-file] [copy []]
    perf: either exists? perf-file [load/all perf-file] [copy []]
    until [
        file: next file
        throw-test: copy ""
        current-result: make map! []
        current-result/test: file/1
        if expected-result: results/1 [
            ; work around missing mold/all
            if expected-result/type = 'logic! [
                expected-result/result: switch expected-result/result [
                    true  [true]
                    false [false]
                ]
            ]
        ]
        unless perf-data: perf/1 [
            perf-data: make map! []
            perf-data/test: file/1
            perf-data/samples: copy []
            append perf perf-data
        ]
        if perf-data/test <> current-result/test [
            print [tab "WARNING: Test" index? perf "has changed, can't accurately determine performance regressions"]
        ]
        ; trick to determine if there was a throw: throw-test is unique at this point and
        ; there is no way file/1 would accidentally throw it
        either same? throw-test catch [type: type?/word set/any 'result try file/1 throw-test] [
            ; no throw
            current-result/result: case [
                all [any-string? :result 65535 < length? result] [
                    ; TODO: write the result out to a file so a human can check it
                    checksum result 'SHA1
                ]
                error? :result [
                    form result
                ]
                object? :result [
                    body-of result
                ]
                'else [
                    :result
                ]
            ]
            current-result/type: type
            current-result/status: 'Unknown
            either expected-result [
                expected?: all [current-result/type = expected-result/type current-result/result = expected-result/result]
                case [
                    all [current-result/test <> expected-result/test expected?] [
                        current-result/note: rejoin [
                            "Test changed, but same result as before (was marked as " expected-result/status ")"
                        ]
                        summary/unknown: summary/unknown + 1
                    ]
                    current-result/test <> expected-result/test [
                        current-result/note: "Test changed"
                        summary/unknown: summary/unknown + 1
                    ]
                    all [expected? expected-result/status = 'Pass] [
                        current-result/status: 'Pass
                        summary/passed: summary/passed + 1
                    ]
                    any [
                        all [expected? expected-result/status = 'Failure]
                        all [not expected? expected-result/status = 'Pass]
                    ] [
                        current-result/status: 'Failure
                        summary/failed: summary/failed + 1
                    ]
                    'else [
                        summary/unknown: summary/unknown + 1
                    ]
                ]
                results/1: current-result
            ] [
                summary/unknown: summary/unknown + 1
                append results current-result
            ]
        ] [
            ; there has been a throw
            ; TODO: perhaps check if the same value has been thrown?
            current-result/result: 'throw
            current-result/type: 'throw
            current-result/status: either expected-result [
                results/1: current-result
                either expected-result/type = 'throw [
                    switch expected-result/status [
                        Pass [summary/passed: summary/passed + 1]
                        Failure [summary/failed: summary/failed + 1]
                        Unknown [summary/unknown: summary/unknown + 1]
                    ]
                    expected-result/status
                ] [
                    either expected-result/status = 'Pass [
                        summary/failed: summary/failed + 1
                        'Failure
                    ] [
                        summary/unknown: summary/unknown + 1
                        'Unknown
                    ]
                ]
            ] [
                append results current-result
                'Unknown
            ]
        ]
        time: to float! delta-time [catch [try file/1]]
        if any [empty? perf-data/samples perf-data/fastest > time] [
            perf-data/fastest: time
        ]
        append perf-data/samples time
        speed: time / perf-data/fastest
        if speed > 1.05 [
            print [tab "WARNING: Test" index? perf "ran" round/to speed 0.01 "times slower than fastest sample"]
            summary/perf-regressions: summary/perf-regressions + 1
        ]
        results: next results
        perf: next perf
        tail? next file
    ]
    clear results ; remove extra results
    results: head results
    new-line/all results true
    write results-file mold/only/all results
    clear perf ; remove extra samples
    perf: head perf
    new-line/all perf true
    write perf-file mold/only/all perf
    print [
        tab "PASSED:" summary/passed newline
        tab "FAILED:" summary/failed newline
        tab "UNKNOWN:" summary/unknown newline
        tab "PERF. REGRESSIONS:" summary/perf-regressions
    ]
    summary
]

total-passed: total-failed: total-unknown: total-perf-regressions: 0
foreach file read %tests/ [
    if test-file? file [
        summary: run-test-file file
        total-passed: total-passed + summary/passed
        total-failed: total-failed + summary/failed
        total-unknown: total-unknown + summary/unknown
        total-perf-regressions: total-perf-regressions + summary/perf-regressions
    ]
]
print ["TOTAL PASSED:" total-passed]
print ["TOTAL FAILED:" total-failed]
print ["TOTAL UNKNOWN:" total-unknown]
print ["TOTAL PERF. REGRESSIONS:" total-perf-regressions]
