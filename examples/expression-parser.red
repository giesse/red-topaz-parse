Red [
    File:    %expression-parser.red
    Title:   "Arithmetic expression parser"
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

; This is mostly just an example of TOPAZ-PARSE
; Compare to http://www.rebol.org/ml-display-thread.r?m=rmlXJHS

; Examples:
; >> parse-expression [b ** 2 - 4 * a * c]
; == [subtract power b 2 multiply 4 multiply a c]
; >> parse-expression [1 / k !]
; == [divide 1 factorial k]
; >> parse-expression [a * - b]
; == [multiply a negate b]
; >> parse-expression [e ** (i / h * (p * x - E * t))]
; == [power e divide i multiply h subtract multiply p x multiply E t]

do %../topaz-parse.red

factorial: function [n [integer!]] [
    if n < 2 [return 1]
    res: 1
    repeat i n - 1 [res: i + 1 * res]
]

expression: [
    object [left: term op: ['+ | '-] right: expression]
    |
    term
]
term: [
    object [left: pow op: ['* | '/] right: term]
    |
    pow
]
pow: [
    object [left: unary op: '** right: unary]
    |
    unary
]
unary: [
    object [op: '- argument: fact]
    |
    fact
]
fact: [
    object [argument: primary op: '!]
    |
    primary
]
primary: [
    into paren! expression | number! | word!
]

parse-expression: function [expr [block!]] [
    if tree: topaz-parse expr expression [
        tree-to-code tree
    ]
]

tree-to-code: function [tree [map! number! word!]] [
    output: make block! 0
    emit-node output tree
    output
]
emit-node: function [output node [map! number! word!]] [
    either map? node [
        either node/argument [
            append output select [
                - negate
                ! factorial
            ] node/op
            emit-node output node/argument
        ] [
            append output select [
                + add
                - subtract
                * multiply
                / divide
                ** power
            ] node/op
            emit-node output node/left
            emit-node output node/right
        ]
    ] [
        append output node
    ]
]
