# A version of Topaz' `parse` function for Red

This is an implementation of Topaz' `parse` function for Red.

It includes a compiler that can output Red `parse` rules from the `topaz-parse` dialect.

## Instructions

```
$ git clone https://github.com/giesse/red-topaz-parse.git
$ cd red-topaz-parse/
$ red make.red
```

## Major differences compared to `parse`

* First of all, this version is incomplete; here's a list of keywords missing compared to Red's `parse`:

  * `ahead` (no plans to add it)

  * `none` (not entirely sure yet if needed)

  * `break`

  * `fail`

  * `then` (should be removed from Red's `parse` too)

  * `reject`

  * `while` (not sure if needed)

  * `insert` and `remove` (I'd like to stay away from modifying the parsed series)

* Rules return a value in addition to matching the input. This can be used with `keep`, `set-word!` values, and so on. It also makes `set` unnecessary. Examples:

```
>> topaz-parse [1 2 3] [integer!]
== 1
>> topaz-parse [1 2 3] [one: integer! two: integer!]
== 2
>> one
== 1
>> two
== 2
>> topaz-parse [1 2 3] [one: integer! if (one > 0) integer!]
== 2
>> topaz-parse [0 2 3] [one: integer! if (one > 0) integer!]
== none
```

* `set-word!` values are used to extract data rather than the `set` keyword; also `copy` returns the copy rather than setting a word; note that this solves the problem of automatic locals when using `function`

```
>> topaz-parse [foo 1 2 3] ['foo baz: copy some integer!]
== [1 2 3]
>> baz
== [1 2 3]
```

* To set the current position in the input, because of the above change, the `here` keyword has been added.

```
>> topaz-parse [1 2 3] [integer! pos: here]
== [2 3]
>> pos
== [2 3]
```

* `*` is an alias for `skip`

* The parsing succeeds if the rules match, even if they don't consume all the input. To achieve the same behavior as `parse`, just add `end` to your rules appropriately.

* `into` can take an optional type to restrict recursion into only series of that type; eg. `into block! [...]` will only match! blocks, and not parens or strings etc.

* In addition to `collect`, there is a `object` keyword which will collect `set-word!` rules and create a `map!` (closer match to `object!` in Topaz) instead of setting the words directly

```
>> topaz-parse [1 2 3] [object [a: integer! b: * c: quote 3]]
== #(
    a: 1
    b: 2
    c: 3
)
>> a
*** Script Error: a has no value
*** Where: catch
*** Stack:  
```

* The `also` keyword works similarly to the Red `also` function:

```
>> topaz-parse [a b] ['a 'b]
== b
>> topaz-parse [a b] [also 'a 'b]
== a
>> topaz-parse [a c] [also 'a 'b]
== none
```

## Example

```
value: [integer! | word!]
atom: [object [left: value '** op: ('power) right: atom] | value]
item: [object [left: atom ['* op: ('multiply) | '/ op: ('divide)] right: item] | atom]
term: [object [left: item ['+ op: ('add) | '- op: ('subtract)] right: term] | item]
equation: [object [op: ('equal) left: term '= right: term]]

topaz-parse [1 + 3 * x - x ** 2 * 1 / 2 = 2 * y] equation
```

Results in:

```
#(
    op: equal
    left: #(
        left: 1
        op: add
        right: #(
            left: #(
                left: 3
                op: multiply
                right: x
            )
            op: subtract
            right: #(
                left: #(
                    left: x
                    op: power
                    right: 2
                )
                op: multiply
                right: #(
                    left: 1
                    op: divide
                    right: 2
                )
            )
        )
    )
    right: #(
        left: 2
        op: multiply
        right: y
    )
)
```
