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
    unless exists? %compiled-rules.red [
        do make error! "%compiled-rules.red missing. Please do %make.red first."
    ]
    compiled-rules: do load %compiled-rules.red

    compile-rules*: function [result name rules] [
        unless ast: compiled-rules/_parse rules [
            cause-error 'script 'invalid-arg [rules]
        ]
        put result name ast
        ; optimize the AST
        transform-tree ast [
            (sequence)           -> (none)
            (sequence child)     -> child
            (alternatives child) -> child
        ]
        ; convert the AST to a Red PARSE block
        put result name tree-to-block ast [
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
            (loop n child)      -> [(preserve-word n) n [child]]
            (get type)          -> [[
                'set '_result type
                '|
                'set '_result 'word! 'if
                either (
                    either word? type [
                        preserve-word type
                        typeset? get type
                    ] [typeset? type]
                ) [
                    (paren [find (type) type? get/any _result])
                ] [
                    (paren [(type) = type? get/any _result])
                ]
            ]]
            (rule word)         -> [
                (
                    unless find result word [
                        compile-rules* result word get word
                    ]
                    []
                )
                literal (_push-state)
                word
                literal (_pop-state)
                '|
                literal (_pop-state)
                'fail
            ]
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
                (preserve-word type)
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
                if (value? 'type) [
                    (preserve-word type)
                    'ahead type
                ]
                'into [child]
            ]
        ]
    ]

    paren: func [block] [reduce [to paren! compose/only/deep block]]
    preserve-word: func [word] bind [
        if all [
            word? word
            ; would be nice to have system/catalog/datatypes :)
            not find [
                datatype! unset! none! logic! block! paren! string! file! url! char! integer! float! word!
                set-word! lit-word! get-word! refinement! issue! native! action! op! function! path! lit-path!
                set-path! get-path! routine! bitset! point! object! typeset! error! vector! hash! pair! percent!
                tuple! map! binary! time! tag! email! handle! date!
            ] word
        ] [put result word get word]
        []
    ] :compile-rules*

    nargs: 0
    handle-word: function [word-node] bind [
        nargs: 0
        word: first word-node/children
        value: get word
        word-node/name: case [
            block? :value [
                ;append more-rules word
                ;append/only more-rules value
                'rule
            ]
            all [map? :value value/name = 'rule-function] [
                unless find result word [
                    unless result/_functions [
                        result/_functions: make map! []
                    ]
                    put result/_functions word value
                    append more-rules word
                    append/only more-rules value/body
                ]
                nargs: length? value/parsed-spec
                'rule-function
            ]
            'else [
                'match-value
            ]
        ]
    ] :compile-rules*

    runtime: [
        _coll: collection: _result: none
        _stack: []

        _push-state: does [
            append _stack collection
        ]
        _pop-state: does [
            collection: take/last _stack
        ]

        _reset: does [
            collection: _result: none
            clear _stack
        ]
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
        result: append copy runtime body-of parsed-rules
        append result compose/deep [
            _parse: func [input] [
                _reset
                if parse input [(name) to end] [:_result]
            ]
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
            (get type)          -> ['get type]
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
            (get type)          -> [.indent "Get word if it refers to " (mold type) #"^/"]
            (into child)        -> [
                .indent (
                    either value? 'type [reduce ["Into " mold type]] ["Into (default)"]
                ) #"^/" child
            ]
        ] copy ""
    ]
]

rule: context [
    func-spec: [
        opt string!
        collect [
            any [
                refinement! (do make error! "Sorry, refinements not supported in parse functions")
                |
                keep object [
                    name: word!
                    opt [type: block! (collection/type: make typeset! collection/type)]
                    opt string!
                ]
            ]
        ]
    ]
    func-spec: parse-compiler/compile-rules 'func-spec

    extract-set-words*: [
        any [
            keep set-word!
            |
            into extract-set-words*
            |
            skip
        ]
    ]
    extract-set-words: [collect [extract-set-words* end]]
    extract-set-words: parse-compiler/compile-rules 'extract-set-words

    rule: function [
        "Define a TOPAZ-PARSE rule that can take arguments and has local words"
        spec [block!] "Arguments specification"
        body [block!] "TOPAZ-PARSE rule"
    ] [
        result: make map! []
        result/name: 'rule-function
        result/spec: spec
        unless result/parsed-spec: func-spec/_parse spec [
            cause-error 'script 'invalid-arg [spec]
        ]
        result/words: make block! 0
        foreach arg result/parsed-spec [
            append result/words to set-word! arg/name
        ]
        append result/words extract-set-words/_parse body
        result/context: construct result/words
        ; make sure they are in the correct order to use SET etc. (handles duplicates in original words block)
        result/words: words-of result/context
        result/body: bind body result/context
        foreach arg result/parsed-spec [
            arg/name: bind arg/name result/context
        ]
        result
    ]
]

rule: :rule/rule
