Red [
    File:    %parse-compiler-debug.red
    Title:   "Debug helpers for PARSE-COMPILER"
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
