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
            name: 'if keep element keep top-level
            |
            name: 'either keep element keep into block! alternatives keep into block! alternatives
            |
            keep set-word! name: ('set) keep top-level
        ]
        |
        element
    ]
    element: [
        object [
            name: ['opt | 'any | 'some | 'not] keep element
            |
            ['literal | 'quote] name: ('literal) keep *
            |
            ['skip | '*] name: ('skip)
            |
            name: ['end | 'here]
            |
            name: 'into type: opt [datatype! | typeset! | word!] keep top-level
            |
            name: 'debug keep string!
            |
            keep word! name: ('word)
            |
            keep/only paren! name: ('paren)
            |
            keep [datatype! | typeset!] name: ('match-type)
        ]
        |
        into block! alternatives
        |
        object [name: ('match-value) keep/only *]
    ]
]
