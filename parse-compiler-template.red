Red [
    File:    %parse-compiler.red
    Title:   "Compile TOPAZ-PARSE rules into PARSE rules"
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

do %ast-tools.red

parse-compiler: context [
    compiled-rules: []

    compile-rules*: function [result name rules] [
        parse rules compiled-rules/alternatives
        put result name compiled-rules/_state/result
        handle-word: function [old-node new-node] [
            word: first old-node/children
            value: get word
            case [
                block? :value [
                    new-node/name: 'rule
                    new-node/children: old-node/children
                    unless find result word [
                        compile-rules* result word value
                    ]
                ]
                any [datatype? :value typeset? :value] [
                    new-node/name: 'match-type
                    new-node/children: reduce [value]
                ]
                'else [
                    new-node/name: 'match-value
                    new-node/children: old-node/children
                ]
            ]
        ]
        transform-tree select result name [
            (sequence)           -> (none)
            (sequence child)     -> child
            (alternatives child) -> child
            (word .)             -> handle-word
        ]
    ]

    runtime: [
        _state: context [
            collection: none
            result:     none
        ]
        _stack: []
        _push-state: does [
            append _stack _state
            _state: copy _state
        ]
        _pop-state: does [
            _state: take/last _stack
        ]
        _value: _word: none
    ]

    compile-rules: function [
        "Compile TOPAZ-PARSE rules into PARSE rules"
        rules [block! word!]
    ] [
        parsed-rules: make map! []
        name: 'rules
        if word? rules [
            name: rules
            unless block? rules: get name [
                cause-error 'script 'invalid-arg [:rules]
            ]
        ]
        compile-rules* parsed-rules name rules
        result: copy runtime
        paren: func [block] [reduce [to paren! compose/only/deep block]]
        foreach [name ast] body-of parsed-rules [
            append result name
            compiled-rule: copy [(_state/collection: _state/result: none)]
            tree-to-block/into ast [
                (alternatives ...)  -> [either (empty? .stack) [... separated by |] [[... separated by |]]]
                (sequence ...)      -> [either (.parent = 'alternatives) [...] [[...]]]
                (end)               -> ['end literal (_state/result: none)]
                (skip)              -> [([set _value skip (_state/result: :_value)])]
                (paren code)        -> [(paren [_state/result: (code)])]
                (opt child)         -> ['opt [child]]
                (any child)         -> ['any [child]]
                (some child)        -> ['some [child]]
                (not child)         -> ['not [child]]
                (rule word)         -> [
                    literal (_push-state) 
                    word
                    literal (
                        _value: :_state/result
                        _pop-state
                        _state/result: :_value
                    )
                    '|
                    literal (_pop-state)
                    'fail
                ]
                (match-value value) -> [
                    ; Red parse wants [some/path] rather than ['some/path] to match a literal path
                    ; also there's a bug with lit-words, you need [ahead word! 'some-word] to work around it
                    (
                        rule: switch/default type?/word :value [
                            lit-path! [reduce [to path! value]]
                            lit-word! [compose/deep [[ahead word! (value)]]]
                        ] [
                            reduce [:value]
                        ]
                        []
                    )
                    either (.parent = 'not) [
                        (rule)
                    ] [
                        'set '_value (rule) literal (_state/result: :_value)
                    ]
                ]
                (match-type type)   -> [
                    either (.parent = 'not) [
                        type
                    ] [
                        'set '_value type literal (_state/result: :_value)
                    ]
                ]
                (object child)      -> [
                    literal (
                        _push-state
                        _state/collection: make map! []
                    )
                    [child]
                    literal (
                        _value: _state/collection
                        _pop-state
                        _state/result: _value
                    )
                    '|
                    literal (_pop-state)
                    'fail
                ]
                (set word child)    -> [
                    [child]
                    (paren [_word: (to lit-word! word)])
                    literal (
                        either map? _state/collection [
                            put _state/collection _word :_state/result
                        ] [
                            set _word :_state/result
                        ]
                    )
                ]
                (collect child)     -> [
                    literal (
                        _push-state
                        _state/collection: make block! 0
                    )
                    [child]
                    literal (
                        _value: _state/collection
                        _pop-state
                        _state/result: _value
                    )
                    '|
                    literal (_pop-state)
                    'fail
                ]
                (keep child)        -> [
                    [child]
                    literal (
                        _value: either map? _state/collection [
                            unless find _state/collection 'children [
                                _state/collection/children: make block! 0
                            ]
                            _state/collection/children
                        ] [
                            _state/collection
                        ]
                        unless block? :_value [
                            cause-error 'script 'parse-rule ["KEEP outside of COLLECT or OBJECT"]
                        ]
                    )
                    either only? [
                        literal (append/only _value :_state/result)
                    ] [
                        literal (append _value :_state/result)
                    ]
                ]
                (into child)        -> [
                    either (value? 'type) [
                        'ahead type
                    ] []
                    'into [child]
                ]
            ] compiled-rule
            append compiled-rule [| (_state/result: none)]
            append/only result compiled-rule
        ]
        context result
    ]

    decompile-ast: function [ast [map!]] [
        tree-to-block ast [
            (alternatives ...)  -> [either (empty? .stack) [... separated by |] [[... separated by |]]]
            (sequence ...)      -> [either (.parent = 'alternatives) [...] [[...]]]
            (object child)      -> ['object child]
            (set word child)    -> [(to set-word! word) child]
            (end)               -> ['end]
            (skip)              -> ['skip]
            (paren code)        -> [code]
            (collect child)     -> ['collect child]
            (keep child)        -> [(either only? [[keep/only]] ['keep]) child]
            (opt child)         -> ['opt child]
            (any child)         -> ['any child]
            (some child)        -> ['some child]
            (not child)         -> ['not child]
            (rule word)         -> [word]
            (match-value value) -> [value]
            (match-type type)   -> [type]
            (into child)        -> ['into (either value? 'type [type] [[]]) child]
        ]
    ]

    print-ast: function [ast [map!]] [
        mold-flat: func [value] [
            value: mold/flat/part value 30
            if 30 = length? value [
                change skip tail value -3 "..."
            ]
            value
        ]
        print tree-to-block/into ast [
            (alternatives ...)  -> [.indent "[^/" ... separated by [.indent "    |^/"] .indent "]^/"]
            (sequence ...)      -> [... without indenting]
            (object child)      -> [.indent "Object^/" child]
            (set word child)    -> [.indent "Set " (mold word) #"^/" child]
            (end)               -> [.indent "End^/"]
            (skip)              -> [.indent "Skip^/"]
            (paren code)        -> [.indent "Do " (mold-flat code) #"^/"]
            (collect child)     -> [.indent "Collect^/" child]
            (keep child)        -> [.indent (either only? ["Keep (only)"] ["Keep"]) #"^/" child]
            (opt child)         -> [.indent "Opt^/" child]
            (any child)         -> [.indent "Any^/" child]
            (some child)        -> [.indent "Some^/" child]
            (not child)         -> [.indent "Not^/" child]
            (rule word)         -> [.indent "Sub-rule " (mold word) #"^/"]
            (match-value value) -> [.indent "Match value " (mold-flat value) #"^/"]
            (match-type type)   -> [.indent "Match type " (mold-flat type) #"^/"]
            (into child)        -> [
                .indent (
                    either value? 'type [reduce ["Into " mold type]] ["Into (default)"]
                ) #"^/" child
            ]
        ] copy ""
    ]
]
