Red [
    File:    %topaz-parse.red
    Title:   "An alternative to PARSE by Gabriele Santilli"
    Author:  "Gabriele Santilli"
    Version: 1.0.0
    License: {
        Copyright 2019 Gabriele Santilli

        Permission is hereby granted, free of charge, to any person obtaining
        a copy of this software and associated documentation files
        (the "Software"), to deal in the Software without restriction, including
        without limitation the rights to use, copy, modify, merge, publish,
        distribute, sublicense, and/or sell copies of the Software, and to
        permit persons to whom the Software is furnished to do so, subject
        to the following conditions:

        The above copyright notice and this permission notice shall be included
        in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
        OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
        THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
        OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
        ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
        OTHER DEALINGS IN THE SOFTWARE.
    }
]

topaz-parse: context [
    topaz-parse: function [
        "Parse BLOCK according to RULES; return last result from RULES if it matches, NONE otherwise"
        block [any-block!]
        rules [block!]
        /trace "Output execution trace for debugging"
    ] [
        state: context [
            pos:        block ; current block position
            rules-pos:  rules ; current rules position
            match?:     no    ; did the rules match?
            collection: none  ; collect results here (eg. KEEP)
            result:     none  ; parsing result (valid if MATCH? is TRUE)
            depth:      0     ; current recursion depth
            trace?:     trace ; output trace?
            any-count:  0     ; count how many times a rule matches (any, some etc.)
        ]
        state: parse* state
        if state/match? [state/result]
    ]

    indent: func [n] [loop n [prin "    "]]

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

    print-trace: func [label state] [
        if state/trace? [
            indent state/depth
            print [
                ">" label
                "pos:" mold-flat state/pos 20
                "rules-pos:" mold-flat state/rules-pos 20
                "match?:" state/match?
                "any-count:" state/any-count
                "collection: " mold-flat state/collection -20
                "result:" mold-flat state/result 20
            ]
        ]
    ]

    parse*: function [state] [
        state/match?: no
        state/result: none
        print-trace 'parse* state
        orig-pos: state/pos
        while [
            all [
                not empty? state/rules-pos
                not strict-equal? '| first state/rules-pos
            ]
        ] [
            state/depth: state/depth + 1
            state: parse-step state
            state/depth: state/depth - 1
            if not state/match? [
                state/pos: orig-pos
                state/rules-pos: any [find/tail state/rules-pos '| tail state/rules-pos]
            ]
        ]
        state
    ]

    parse-step: function [state] [
        print-trace 'parse-step state
        rule: first state/rules-pos
        switch/default type?/word rule [
            word! [
                switch/default rule [
                    collect [
                        state/rules-pos: next state/rules-pos
                        orig-collection: state/collection
                        state/collection: make block! 0
                        state/depth: state/depth + 1
                        state: parse-element state
                        state/depth: state/depth - 1
                        state/result: state/collection
                        state/collection: orig-collection
                        state
                    ]
                    copy [
                        orig-pos: state/pos
                        state/rules-pos: next state/rules-pos
                        state/depth: state/depth + 1
                        state: parse-element state
                        state/depth: state/depth - 1
                        state/result: copy/part orig-pos state/pos
                        state
                    ]
                    keep [
                        state/depth: state/depth + 1
                        state: parse-keep state
                        state/depth: state/depth - 1
                        state
                    ]
                    object [
                        state/rules-pos: next state/rules-pos
                        orig-collection: state/collection
                        state/collection: make map! []
                        state/depth: state/depth + 1
                        state: parse-element state
                        state/depth: state/depth - 1
                        state/result: state/collection
                        state/collection: orig-collection
                        state
                    ]
                    if [
                        state/rules-pos: next state/rules-pos
                        state/depth: state/depth + 1
                        state: parse-element state
                        state/depth: state/depth - 1
                        either :state/result [
                            state/depth: state/depth + 1
                            state: parse-step state
                            state/depth: state/depth - 1
                            state
                        ] [
                            state/match?: no
                            state/result: none
                            state
                        ]
                    ]
                    either [
                        state/rules-pos: next orig-pos: state/rules-pos
                        state/depth: state/depth + 1
                        state: parse-element state
                        state/depth: state/depth - 1
                        unless all [
                            block? true-rule: first state/rules-pos
                            block? false-rule: second state/rules-pos
                        ] [
                            cause-error 'script 'parse-rule [orig-pos]
                        ]
                        result: copy state
                        result/collection: state/collection
                        result/rules-pos: either :state/result [true-rule] [false-rule]
                        state/depth: state/depth + 1
                        result: parse* result
                        state/depth: state/depth - 1
                        state/rules-pos: skip state/rules-pos 2
                        state/pos: result/pos
                        state/match?: result/match?
                        state/result: :result/result
                        state
                    ]
                ] [
                    state/depth: state/depth + 1
                    state: parse-element state
                    state/depth: state/depth - 1
                    state
                ]
            ]
            set-word! [
                state/rules-pos: next state/rules-pos
                state/depth: state/depth + 1
                state: parse-step state
                state/depth: state/depth - 1
                if state/match? [
                    if state/trace? [
                        indent state/depth
                        print ["  set" mold rule "to" mold-flat state/result 30]
                    ]
                    either map? state/collection [
                        put state/collection rule state/result
                        if state/trace? [
                            indent state/depth
                            print ["  in object " mold-flat state/collection -30]
                        ]
                    ] [
                        set rule state/result
                    ]
                ]
                state
            ]
            path! [
                state/depth: state/depth + 1
                state: either rule = 'keep/only [
                    parse-keep/only state
                ] [
                    parse-element state
                ]
                state/depth: state/depth - 1
                state
            ]
        ] [
            state/depth: state/depth + 1
            state: parse-element state
            state/depth: state/depth - 1
            state
        ]
    ]

    parse-keep: function [state /only] [
        state/match?: no
        state/result: none
        print-trace 'parse-keep state
        ; we do this to prevent recursive use of keep
        collection: saved: state/collection
        state/collection: none
        ; special case for AST nodes (since we don't have a node! type)
        if map? collection [
            unless find collection 'children [
                collection/children: make block! 0
            ]
            collection: select collection 'children
        ]
        if not block? collection [
            cause-error 'script 'parse-rule ["KEEP outside of COLLECT"]
        ]
        state/rules-pos: next state/rules-pos
        state/depth: state/depth + 1
        state: parse-step state
        state/depth: state/depth - 1
        if state/match? [
            either only [
                insert/only tail collection :state/result
            ] [
                insert tail collection :state/result
            ]
        ]
        state/collection: saved
        state
    ]

    parse-element: function [state /with rule] [
        print-trace 'parse-element state
        unless with [rule: first state/rules-pos]
        if state/trace? [
            indent state/depth
            print ["  rule:" mold-flat rule 30]
        ]
        switch/default type?/word rule [
            word! [
                switch/default rule [
                    opt [
                        state/rules-pos: next state/rules-pos
                        state/depth: state/depth + 1
                        state: parse-element state
                        state/depth: state/depth - 1
                        state/match?: yes
                        state
                    ]
                    not [
                        state/rules-pos: next state/rules-pos
                        state/depth: state/depth + 1
                        state2: parse-element copy state
                        state/depth: state/depth - 1
                        state/rules-pos: state2/rules-pos
                        state/match?: not state2/match?
                        state
                    ]
                    literal quote [
                        state/rules-pos: next state/rules-pos
                        parse-match state [:state/rules-pos/1 = :state/pos/1]
                    ]
                    any some [
                        state/rules-pos: next state/rules-pos
                        state/depth: state/depth + 1
                        state: parse-any state
                        state/depth: state/depth - 1
                        state/match?: either rule = 'any [yes] [state/any-count > 0]
                        state
                    ]
                    skip * [
                        state/match?: not empty? state/pos
                        state/result: if state/match? [first state/pos]
                        state/pos: next state/pos
                        state/rules-pos: next state/rules-pos
                        state
                    ]
                    end [
                        state/rules-pos: next state/rules-pos
                        state/match?: empty? state/pos
                        state/result: none
                        state
                    ]
                    here [
                        state/rules-pos: next state/rules-pos
                        state/match?: yes
                        state/result: state/pos
                        state
                    ]
                    into [
                        rule: second state/rules-pos
                        if word? :rule [rule: get rule]
                        either datatype? :rule [
                            type: rule
                            ; only block parsing currently supported
                            unless find any-block! type [
                                cause-error 'script 'parse-rule [state/rules-pos]
                            ]
                            rule: third state/rules-pos
                            if word? :rule [rule: get rule]
                            skip-by: 3
                        ] [
                            type: block!
                            skip-by: 2
                        ]
                        if not block? :rule [
                            cause-error 'script 'parse-rule [state/rules-pos]
                        ]
                        state/rules-pos: skip state/rules-pos skip-by
                        either all [not empty? state/pos type = type? block: first state/pos] [
                            result: copy state
                            result/collection: state/collection
                            result/pos: block
                            result/rules-pos: rule
                            result/depth: result/depth + 1
                            result: parse* result
                            if result/match? [state/pos: next state/pos]
                            state/match?: result/match?
                            state/result: :result/result
                        ] [
                            state/match?: no
                            state/result: none
                        ]
                        state
                    ]
                    debug [
                        label: second state/rules-pos
                        state/rules-pos: skip state/rules-pos 2
                        state/match?: yes
                        print [
                            "*** PARSE DEBUG ***" newline
                            "*** label:" label newline
                            "*** pos:" mold-flat state/pos 80 newline
                            "*** rules-pos:" mold-flat state/rules-pos 80 newline
                            "*** collection:" mold-flat state/collection -80 newline
                            "*** result:" mold-flat state/result 80
                        ]
                        if "q" = ask "*** RETURN to continue.... ***" [quit]
                        print ""
                        state
                    ]
                ] [
                    ; don't recurse on word! more than once
                    state/depth: state/depth + 1
                    state: either with [
                        comp: either any-word? :rule [:strict-equal?] [:equal?]
                        parse-match state [comp :rule first state/pos]
                    ] [
                        parse-element/with state get rule
                    ]
                    state/depth: state/depth - 1
                    state
                ]
            ]
            lit-word! [
                parse-match state [strict-equal? first state/pos to word! rule]
            ]
            lit-path! [
                parse-match state [equal? first state/pos to path! rule]
            ]
            path! [
                ; don't recurse on path! more than once
                state/depth: state/depth + 1
                state: either with [
                    comp: either any-word? :rule [:strict-equal?] [:equal?]
                    parse-match state [comp :rule first state/pos]
                ] [
                    parse-element/with state get rule
                ]
                state/depth: state/depth - 1
                state
            ]
            paren! [
                state/rules-pos: next state/rules-pos
                state/match?: yes
                state/result: do rule
                state
            ]
            block! [
                result: copy state
                result/collection: state/collection
                result/rules-pos: rule
                result/depth: result/depth + 1
                result: parse* result
                state/pos: result/pos
                state/rules-pos: next state/rules-pos
                state/match?: result/match?
                state/result: :result/result
                state
            ]
            datatype! [
                parse-match state [rule = type? first state/pos]
            ]
            typeset! [
                parse-match state [find rule type? first state/pos]
            ]
        ] [
            comp: either any-word? :rule [:strict-equal?] [:equal?]
            parse-match state [comp :rule first state/pos]
        ]
    ]

    parse-any: function [state] [
        state/result: none
        state/any-count: 0
        print-trace 'parse-any state
        until [
            state/depth: state/depth + 1
            element: copy state
            element/collection: state/collection
            element: parse-element element
            state/depth: state/depth - 1
            ; don't enter infinite loop if the rule does not advance the input
            if same? state/pos element/pos [break]
            state/pos: element/pos
            either element/match? [
                state/result: element/result
                state/any-count: state/any-count + 1
                false
            ] [true]
        ]
        state/rules-pos: element/rules-pos
        state
    ]

    parse-match: function [state condition] [
        either all [not empty? state/pos do condition] [
            state/result: first state/pos
            state/pos: next state/pos
            state/match?: yes
        ] [
            state/match?: no
            state/result: none
        ]
        state/rules-pos: next state/rules-pos
        state
    ]
]

topaz-parse: :topaz-parse/topaz-parse
