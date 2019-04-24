Red [
    File:    %parse.red
    Title:   "Red PARSE target for the TOPAZ-PARSE compiler"
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

context [
    paren: func [block] [reduce [to paren! compose/only/deep block]]

    rules: [
        (alternatives ...)  -> [either (empty? .stack) [... separated by |] [[... separated by |]]]
        (sequence ...)      -> [either (.parent = 'alternatives) [...] [[...]]]
        (end)               -> ['end literal (_result: none)]
        (skip)              -> ['set '_result 'skip]
        (paren code)        -> [(paren [_result: (code)])]
        (if code)           -> ['if code]
        (opt child)         -> [[[child] '| literal (_result: none)]]
        (any child)         -> ['any [[child] '| literal (_result: none) 'fail]]
        (some child)        -> ['some [child]]
        (not child)         -> ['not [child]]
        (literal value)     -> ['set '_result 'quote value]
        (none)              -> [(_result: none)]
        (loop n child)      -> [n [child]]
        (get type)          -> [[
            'set '_result type
            '|
            'set '_result 'word! 'if
            either (typeset? either word? type [get type] [type]) [
                (paren [find (type) type? get/any _result])
            ] [
                (paren [(type) = type? get/any _result])
            ]
        ]]
        (rule word)         -> [[
            literal (_push-state)
            word
            literal (_pop-state)
            '|
            literal (_pop-state)
            'fail
        ]]
        (match-value value) -> [
            ; Red parse wants [some/path] rather than ['some/path] to match a literal path
            ; also there's a bug with lit-words, you need [ahead word! 'some-word] to work around it
            (
                rl: switch/default type?/word :value [
                    lit-path! [reduce [to path! value]]
                    lit-word! [compose/deep [[ahead word! (value)]]]
                ] [
                    reduce [:value]
                ]
                []
            )
            either (.parent = 'not) [
                (rl)
            ] [
                'set '_result (rl)
            ]
        ]
        (match-type type)   -> [
            either (.parent = 'not) [
                type
            ] [
                'set '_result type
            ]
        ]
        (object child)      -> [[
            literal (
                _push-state
                collection: make map! []
            )
            [child]
            literal (
                _result: collection
                _pop-state
            )
            '|
            literal (_pop-state)
            'fail
        ]]
        (set word child)    -> [
            [child]
            (paren [
                either map? collection [
                    put collection (to lit-word! word) :_result
                ] [
                    set (to lit-word! word) :_result
                ]
            ])
        ]
        (collect child)     -> [[
            literal (
                _push-state
                collection: make block! 0
            )
            [child]
            literal (
                _result: collection
                _pop-state
            )
            '|
            literal (_pop-state)
            'fail
        ]]
        (keep child)        -> [
            [child]
            literal (
                _coll: either map? collection [
                    unless find collection 'children [
                        collection/children: make block! 0
                    ]
                    collection/children
                ] [
                    collection
                ]
                unless block? :_coll [
                    cause-error 'script 'parse-rule ["KEEP outside of COLLECT or OBJECT"]
                ]
            )
            either only? [
                literal (append/only _coll :_result)
            ] [
                literal (append _coll :_result)
            ]
        ]
        (into child)        -> [
            if (type) ['ahead type]
            'into [child]
        ]
        (filter f child) -> [
            [child]
            (paren [_result: (f) :_result])
        ]
        (rule-function word ...) -> [
            (paren [_rule-func: select _functions (to lit-word! word)])
            literal (append/only _rule-func/stack values-of _rule-func/context)
            (paren [
                set _rule-func/context (children)
                ; problem: arg becomes global??
                foreach _rule-arg _rule-func/parsed-spec [
                    _tmp: select _rule-func/context _rule-arg/word
                    switch type?/word :_tmp [
                        word! [put _rule-func/context _rule-arg/word get _tmp]
                        paren! [put _rule-func/context _rule-arg/word do _tmp]
                    ]
                    if _rule-arg/type [
                        unless find _rule-arg/type type? select _rule-func/context _rule-arg/word [
                            cause-error 'script 'expect-arg [
                                (to lit-word! word)
                                type? select _rule-func/context _rule-arg/word
                                _rule-arg/word
                            ]
                        ]
                    ]
                ]
            ])
            [
                word
                (paren [_rule-func: select _functions (to lit-word! word)])
                literal (set _rule-func/context take/last _rule-func/stack)
                '|
                (paren [_rule-func: select _functions (to lit-word! word)])
                literal (set _rule-func/context take/last _rule-func/stack)
                'fail
            ]
        ]
        ; match-value mode
        (rule-function-argument word) -> [
            either (.parent = 'not) [
                word
            ] [
                'set '_result word
            ]
        ]
        ; loop mode
        (rule-function-argument n child) -> [n [child]]
    ]
]
