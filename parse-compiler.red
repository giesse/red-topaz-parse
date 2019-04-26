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
; do %parse-compiler-debug.red

compile-parse-rules: context [
    unless exists? %compiled-rules.red [
        do make error! "%compiled-rules.red missing. Please do %make.red first."
    ]
    compiled-rules: do load %compiled-rules.red

    ; only one target available right now
    parse-target: do %targets/parse.red

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
        ; compile sub-rules, preserve word values, handle rule-functions
        foreach-node ast [
            (loop n child)    -> [preserve-word n]
            (get type)        -> [preserve-word type]
            (match-type type) -> [preserve-word type]
            (into child)      -> [if type [preserve-word type]]
            (rule word)       -> [
                unless find result word [
                    compile-rules* result word get word
                ]
            ]
            (rule-function word ...) -> [
                unless find result word [
                    unless result/_functions [
                        result/_functions: make map! []
                    ]
                    value: get word
                    put result/_functions word value
                    set value/context value/parsed-spec
                    compile-rules* result word value/body
                ]
            ]
        ]
        ; convert the AST to a Red PARSE block
        put result name tree-to-block ast parse-target/rules
    ]

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

    compile-rules: function [
        "Compile TOPAZ-PARSE rules into PARSE rules"
        rules [block! word!]
        /with ctx [object!] "Copy words into the generated context (eg. functions called from within rule parens)"
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
        if with [
            with: collect [
                foreach word words-of ctx [
                    unless find parsed-rules word [
                        put parsed-rules keep word false
                    ]
                ]
            ]
        ]
        result: parse-target/compile parsed-rules name
        if with [
            foreach word with [
                put result word select ctx word
            ]
        ]
        result
    ]
]

compile-parse-rules: :compile-parse-rules/compile-rules

rule: context [
    func-spec: [
        opt string!
        collect [
            any [
                refinement! (do make error! "Sorry, refinements not supported in parse functions")
                |
                keep object [
                    word: word!
                    name: ('rule-function-argument)
                    opt [type: block! (collection/type: make typeset! collection/type)]
                    opt string!
                ]
            ]
        ]
    ]
    func-spec: compile-parse-rules 'func-spec

    extract-set-words*: [
        any [
            keep set-word!
            |
            into any-block! extract-set-words*
            |
            skip
        ]
    ]
    extract-set-words: [collect [extract-set-words* end]]
    extract-set-words: compile-parse-rules 'extract-set-words

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
        words: collect [
            foreach arg result/parsed-spec [
                keep to set-word! arg/word
            ]
        ]
        append words extract-set-words/_parse body
        result/context: construct words
        result/body: bind body result/context
        result/stack: make block! 0
        result
    ]
]

rule: :rule/rule
