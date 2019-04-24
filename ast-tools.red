Red [
    File:    %ast-tools.red
    Title:   "Tools related to Abstract Syntax Trees"
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

paren-to-tree: function [
    "Convert a paren representation to a tree of map! values"
    node [paren!]
] [
    result: make map! []
    result/name: 'name
    result/children: make block! 0
    value: word: none
    node-rule: [
        set word word! (result/name: word)
        any [
            set word set-word! set value skip (
                if paren? :value [value: paren-to-tree value]
                put result word :value
            )
            |
            set value skip (
                if paren? :value [value: paren-to-tree value]
                append/only result/children :value
            )
        ]
    ]
    unless parse node node-rule [
        cause-error 'script 'invalid-arg [node]
    ]
    if empty? result/children [result/children: none]
    result
]

node?: func [value] [
    all [
        any [map? value object? value]
        word? :value/name
    ]
]

append-value: function [result value] [
    case [
        paren? :value [
            ; this is a problem. for now we just convert to block.
            value: to block! value
        ]
        set-word? :value [
            ; similar issue
            value: to word! value
        ]
        node? :value [
            value: tree-to-paren value
        ]
    ]
    append/only result :value
]

tree-to-paren: function [
    "Convert a tree of map! or object! values to a paren representation"
    node [object! map!]
] [
    unless word? :node/name [
        cause-error 'script 'invalid-arg [node]
    ]
    result: make paren! []
    append result node/name
    if find node 'children [
        unless block? :node/children [
            cause-error 'script 'invalid-arg [node]
        ]
        foreach child node/children [
            append-value result :child
        ]
    ]
    foreach word words-of node [
        unless find [name children] word [
            append result to set-word! word
            append-value result select node word
        ]
    ]
    result
]

parse-tree-rules: function [rules production-rule] [
    result: make map! []
    patt: prod: none
    unless parse rules [
        some [
            set patt paren! '-> set prod production-rule (
                patt: paren-to-tree patt
                either find result patt/name [
                    append select result patt/name make object! [
                        pattern: patt
                        production: :prod
                    ]
                ] [
                    put result patt/name reduce [
                        make object! [
                            pattern: patt
                            production: :prod
                        ]
                    ]
                ]
            )
        ]
    ] [
        cause-error 'script 'invalid-arg [rules]
    ]
    result
]

map-node: function [node pattern] [
    node: copy node
    either pattern/children [
        unless pattern/children = [...] [
            unless all [block? node/children not empty? node/children] [
                return none
            ]
            ...?: false
            foreach word pattern/children [
                if word = '... [
                    ...?: true
                    break
                ]
                unless word? word [
                    cause-error 'script 'invalid-arg [word]
                ]
                put node word first node/children
                node/children: next node/children
            ]
            if all [not ...? not tail? node/children] [
                return none
            ]
        ]
    ] [
        if node/children [return none]
    ]
    foreach word words-of pattern [
        unless find [name children] word [
            unless equal? select node word select pattern word [
                return none
            ]
        ]
    ]
    node
]

emit-production: function [output rules node production] [
    value: no-indent: separator: blk: condition: true-block: false-block: none
    next-indent: append copy node/.indent "    "
    next-stack: append copy node/.stack node/name
    first-value?: no
    production-rule: [
        any [
            '... any ['without 'indenting (no-indent: true) | 'separated 'by set separator skip] (
                if block? node/children [
                    first-value?: yes
                    foreach value node/children [
                        unless any [none? :separator first-value?] [
                            either block? :separator [
                                emit-production output rules node separator
                            ] [
                                append/only output :separator
                            ]
                        ]
                        first-value?: no
                        either node? :value [
                            i: either no-indent [node/.indent] [next-indent]
                            tree-to-block* output next-stack i value rules
                        ] [
                            append output :value
                        ]
                    ]
                ]
            )
            |
            'either set condition [word! | paren!] set true-block block! set false-block block! (
                condition: either word? condition [get condition] [do condition]
                blk: either condition [true-block] [false-block]
                emit-production output rules node blk
            )
            |
            'if set condition [word! | paren!] set true-block block! (
                condition: either word? condition [get condition] [do condition]
                if condition [emit-production output rules node true-block]
            )
            |
            'literal set value skip (append/only output :value)
            |
            set value word! (
                value: get value
                either node? :value [
                    tree-to-block* output next-stack next-indent value rules
                ] [
                    append/only output :value
                ]
            )
            |
            set value lit-word! (append output to word! value)
            |
            set value paren! (append output do value)
            |
            set value block! (
                blk: make block! 0
                append/only output blk
                emit-production blk rules node value
            )
            |
            set value skip (
                append/only output :value
            )
        ]
    ]
    unless parse production production-rule [
        cause-error 'script 'invalid-arg [production]
    ]
]

map-to-object: function [map [map!] /with words [block!]] [
    body: body-of map
    words*: clear []
    values: clear []
    foreach [word value] body [
        append words* word
        append/only values :value
    ]
    obj: construct append copy any [words []] words*
    set bind words* obj values
    obj
]

tree-to-block*: function [output stack indent node rules] [
    node-rules: select rules node/name
    either node-rules [
        foreach rule node-rules [
            if mapped: map-node node rule/pattern [
                mapped/.stack: stack
                mapped/.indent: indent
                mapped/.parent: last stack
                mapped: map-to-object/with mapped [.parent:]
                production: bind/copy rule/production mapped
                emit-production output rules mapped production
                break
            ]
        ]
    ] [
        append output tree-to-paren node
    ]
]
    
tree-to-block: function [
    "Generate a block from a tree based on the given rules"
    node [object! map!]
    rules [block!]
    /into output [any-block! any-string!]
] [
    unless word? :node/name [
        cause-error 'script 'invalid-arg [node]
    ]
    rules: parse-tree-rules rules block!
    unless output [output: make block! 0]
    tree-to-block* output [] "" node rules
    output
]

transform-node: function [node rules] [
    modified?: false
    until [
        done?: true
        node-rules: select rules node/name
        old-node: copy node
        clear node
        match?: false
        if node-rules [
            foreach rule node-rules [
                if mapped: map-node old-node rule/pattern [
                    match?: true
                    modified?: true
                    done?: false
                    prod: rule/production
                    if word? prod [
                        prod: either find mapped prod [
                            select mapped prod
                        ] [
                            get prod
                        ]
                    ]
                    if paren? :prod [
                        prod: paren-to-tree prod
                    ]
                    either any-function? :prod [
                        prod old-node node
                    ] [
                        unless node? :prod [
                            cause-error 'script 'invalid-arg [:prod]
                        ]
                        node/name: prod/name
                        if block? prod/children [
                            node/children: make block! 0
                            foreach child prod/children [
                                either word? :child [
                                    either find mapped child [
                                        child: select mapped child
                                        if node? :child [transform-node child rules]
                                        append/only node/children :child
                                    ] [
                                        append/only node/children child
                                    ]
                                ] [
                                    if node? :child [transform-node child rules]
                                    append/only node/children :child
                                ]
                            ]
                        ]
                        foreach word words-of prod [
                            unless find [name children] word [
                                value: select prod word
                                either word? :value [
                                    either find mapped value [
                                        value: select mapped value
                                        if node? :value [transform-node value rules]
                                        put node word :value
                                    ] [
                                        put node word value
                                    ]
                                ] [
                                    if node? :value [transform-node value rules]
                                    put node word :value
                                ]
                            ]
                        ]
                    ]
                    break
                ]
            ]
        ]
        unless match? [
            node/name: old-node/name
            if block? old-node/children [
                node/children: make block! []
                foreach child old-node/children [
                    if node? :child [
                        if transform-node child rules [
                            done?: false
                            modified?: true
                        ]
                    ]
                    append/only node/children :child
                ]
            ]
            foreach word words-of old-node [
                unless find [name children] word [
                    if node? select old-node word [
                        if transform-node select old-node word rules [
                            done?: false
                            modified?: true
                        ]
                    ]
                    put node word select old-node word
                ]
            ]
        ]
        done?
    ]
    modified?
]

transform-tree: function [
    "Apply transformation rules to a tree of map! values"
    node [map!] "Modified"
    rules [block!]
] [
    unless word? :node/name [
        cause-error 'script 'invalid-arg [node]
    ]
    rules: parse-tree-rules rules [paren! | word!]
    transform-node node rules
]
foreach-node*: function [node rules] [
    node-rules: select rules node/name
    if node-rules [
        foreach rule node-rules [
            if mapped: map-node node rule/pattern [
                mapped: map-to-object mapped
                do bind/copy rule/production mapped
            ]
        ]
    ]
    if block? node/children [
        foreach child node/children [
            if node? :child [foreach-node* child rules]
        ]
    ]
    foreach word words-of node [
        unless find [name children] word [
            if node? child: select node word [foreach-node* child rules]
        ]
    ]
]

foreach-node: function [
    "Evaluates a block for each matching node in a tree"
    node [map! object!]
    rules [block!]
] [
    unless word? :node/name [
        cause-error 'script 'invalid-arg [node]
    ]
    rules: parse-tree-rules rules block!
    foreach-node* node rules
]
