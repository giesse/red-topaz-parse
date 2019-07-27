Red [
    File:    %parse-parse.red
    Title:   "TOPAZ-PARSE rules for the TOPAZ-PARSE dialect"
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

parse-parse: context [
    datatype|typeset: make typeset! [datatype! typeset!]
    nargs: 0
    handle-map: function [node [map!]] [
        rule-func: node/children/1
        if word? rule-func [rule-func: get rule-func]
        switch/default rule-func/name [
            rule-function [
                node/name: 'rule-function
                node/nargs: length? rule-func/parsed-spec
            ]
            ; this happens when parsing the body of a rule function
            rule-function-argument [
                node/name: 'rule-function-argument
                node/mode: either rule-func/type = make typeset! [integer!] ['loop] ['match-value]
            ]
        ] [
            node/name: 'match-value
        ]
    ]

    alternatives: [
        object [name: ('alternatives) keep sequence any ['| keep sequence] end]
    ]
    sequence: [
        object [name: ('sequence) any [not '| keep top-level]]
    ]
    top-level: [
        object [
            name: ['collect | 'copy | 'object] keep element
            |
            [name: 'keep only?: (false) | 'keep/only name: ('keep) only?: (true)] keep top-level
            |
            name: 'if keep/only paren!
            |
            keep set-word! name: ('set) keep top-level
            |
            name: 'also keep top-level keep top-level
        ]
        |
        element
    ]
    element: [
        into block! alternatives
        |
        object [
            name: ['opt | 'any | 'some | 'not | 'to | 'thru] keep element
            |
            keep get integer! name: ('loop) keep element
            |
            ['literal | 'quote] name: ('literal) keep *
            |
            ['skip | '*] name: ('skip)
            |
            name: ['end | 'here]
            |
            name: 'into type: opt get datatype|typeset keep top-level
            |
            ;name: 'debug keep string!
            ;|
            name: 'get keep get datatype|typeset
            |
            keep get datatype|typeset name: ('match-type)
            |
            keep get block! name: ('rule)
            |
            keep get map! (handle-map collection) [
                if (collection/name = 'rule-function)
                (nargs: collection/nargs) nargs [keep/only *]
                |
                if (collection/name = 'rule-function-argument) [
                    if (collection/mode = 'loop) keep element
                    |
                    if (collection/mode = 'match-value)
                ]
                |
                if (collection/name = 'match-value)
            ]
            |
            keep/only paren! name: ('paren)
            |
            ; does not really belong here, but will do for now
            keep get any-function! name: ('filter) keep top-level
        ]
        |
        object [name: ('match-value) keep/only *]
    ]
]
