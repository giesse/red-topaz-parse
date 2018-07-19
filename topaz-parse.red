Red [
    File:    %topaz-parse.red
    Title:   "An alternative to PARSE by Gabriele Santilli"
    Author:  "Gabriele Santilli"
    Version: 1.0.0
    License: {
        Copyright 2018 Gabriele Santilli

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
        block [block!]
        rules [block!]
    ] [
        state: context [
            pos:        block ; current block position
            rules-pos:  rules ; current rules position
            match?:     no    ; did the rules match?
            collection: none  ; collect results here (eg. KEEP)
            result:     none  ; parsing result (valid if MATCH? is TRUE)
        ]
        state: parse* state
        if state/match? [state/result]
    ]

    parse*: function [state] [
        state/match?: no
        state/result: none
        orig-pos: state/pos
        while [
            all [
                not empty? state/rules-pos
                '| <> first state/rules-pos
            ]
        ] [
            state: parse-step state
            if not state/match? [
                state/pos: orig-pos
                state/rules-pos: any [find/tail state/rules-pos '| tail state/rules-pos]
            ]
        ]
        state
    ]

    parse-step: function [state] [
        rule: first state/rules-pos
        switch/default type?/word rule [
            word! [
                switch/default rule [
                    collect [
                        state/rules-pos: next state/rules-pos
                        state/collection: make block! 0
                        state: parse-element state
                        state/result: state/collection
                        state/collection: none
                        state
                    ]
                    copy [
                        orig-pos: state/pos
                        state/rules-pos: next state/rules-pos
                        state: parse-element state
                        state/result: copy/part orig-pos state/pos
                        state
                    ]
                    keep [
                        parse-keep state
                    ]
                    object [
                        state/rules-pos: next state/rules-pos
                        state/collection: make map! []
                        state: parse-element state
                        state/result: state/collection
                        state/collection: none
                        state
                    ]
                    if [
                        state/rules-pos: next state/rules-pos
                        state: parse-element state
                        either :state/result [
                            parse-step state
                        ] [
                            state/match?: no
                            state/result: none
                            state
                        ]
                    ]
                    either [
                        state/rules-pos: next orig-pos: state/rules-pos
                        state: parse-element state
                        unless all [
                            block? true-rule: first state/rules-pos
                            block? false-rule: second state/rules-pos
                        ] [
                            cause-error 'script 'parse-rule [orig-pos]
                        ]
                        result: copy state
                        result/rules-pos: either :state/result [true-rule] [false-rule]
                        result: parse* result
                        state/rules-pos: skip state/rules-pos 2
                        state/pos: result/pos
                        state/match?: result/match?
                        state/result: :result/result
                        state
                    ]
                ] [
                    parse-element state
                ]
            ]
            set-word! [
                state/rules-pos: next state/rules-pos
                state: parse-step state
                if state/match? [
                    either map? state/collection [
                        put state/collection rule state/result
                    ] [
                        set rule state/result
                    ]
                ]
                state
            ]
            path! [
                either rule = 'keep/only [
                    parse-keep/only state
                ] [
                    parse-element state
                ]
            ]
        ] [
            parse-element state
        ]
    ]

    parse-keep: function [state /only] [
        state/match?: no
        state/result: none
        collection: state/collection
        state/collection: none
        if not block? collection [
            cause-error 'script 'parse-rule ["KEEP outside of COLLECT"]
        ]
        state/rules-pos: next state/rules-pos
        state: parse-step state
        if state/match? [
            either only [
                insert/only tail collection :state/result
            ] [
                insert tail collection :state/result
            ]
        ]
        state/collection: collection
        state
    ]

    parse-element: function [state /with rule] [
        unless with [rule: first state/rules-pos]
        switch/default type?/word rule [
            word! [
                switch/default rule [
                    opt [
                        state/rules-pos: next state/rules-pos
                        state: parse-element state
                        state/match?: yes
                        state
                    ]
                    literal quote [
                        state/rules-pos: next state/rules-pos
                        parse-match state [:state/rules-pos/1 = :state/pos/1]
                    ]
                    any [
                        state/rules-pos: next state/rules-pos
                        parse-any state
                    ]
                    some [
                        state/match?: no
                        state/rules-pos: any-rules: next state/rules-pos
                        state: parse-element state
                        if state/match? [
                            state/rules-pos: any-rules
                            state: parse-any state
                        ]
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
                        if not block? :rule [
                            cause-error 'script 'parse-rule [state/rules-pos]
                        ]
                        state/rules-pos: skip state/rules-pos 2
                        either all [not empty? state/pos block? block: first state/pos] [
                            result: copy state
                            result/pos: block
                            result/rules-pos: rule
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
                ] [
                    ; don't recurse on word! more than once
                    either with [
                        parse-match state [:rule = first state/pos]
                    ] [
                        parse-element/with state get rule
                    ]
                ]
            ]
            paren! [
                state/rules-pos: next state/rules-pos
                state/match?: yes
                state/result: do rule
                state
            ]
            block! [
                result: copy state
                result/rules-pos: rule
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
        ] [
            parse-match state [:rule = first state/pos]
        ]
    ]

    parse-any: function [state] [
        state/result: none
        until [
            element: parse-element copy state
            ; don't enter infinite loop if the rule does not advance the input
            if same? state/pos element/pos [break]
            state/pos: element/pos
            either element/match? [state/result: element/result false] [true]
        ]
        state/rules-pos: element/rules-pos
        state/match?: yes
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
