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

unless exists? %compiled-rules.red [
    print "Downloading pre-built version of compiled-rules.red for bootstrap..."
    write/binary %compiled-rules.red read/binary https://github.com/giesse/red-topaz-parse/releases/download/bootstrap.2/compiled-rules.red
]

do %parse-compiler.red
do %parse-parse.red

print "Building new compiled-rules.red..."
compiled-rules: compile-parse-rules/with in parse-parse 'alternatives parse-parse
write %compiled-rules.red mold/all compiled-rules

print "All done!"
