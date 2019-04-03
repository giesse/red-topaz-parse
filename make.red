Red [
    File:    %make.red
    Title:   "Generate the topaz-parse.red file"
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

unless exists? %parse-compiler.red [
    print "Downloading pre-built version of parse-compiler.red for bootstrap..."
    write %parse-compiler.red read https://github.com/giesse/red-topaz-parse/releases/download/bootstrap.1/parse-compiler.red
]

do %parse-compiler.red
do %parse-parse.red

template: load %parse-compiler-template.red

print "Building new parse-compiler.red..."
compiled-rules: parse-compiler/compile-rules in parse-parse 'alternatives
change find/tail select template 'context [compiled-rules:] compiled-rules
write %parse-compiler.red mold/only template

print "All done!"