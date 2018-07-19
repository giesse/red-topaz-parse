# A version of Topaz' `parse` function for Red

This is a simple direct port of Topaz' `parse` function to Red. It should perhaps be rewritten in Red/System (any takers?),
or, if we keep it as a mezz, it would make sense to rewrite it using Red's `parse` instead.

## Major differences compared to `parse`

* First of all, this version is incomplete and missing lots of stuff like `break`, `to` and `thru`, and so on. Also only block parsing is currently supported. That's hopefully temporary.

* Rules return a value in addition to matching the input. This can be used with `keep`, `set-word!` values, `if` and `either`, and so on. It also makes `set` unnecessary. Examples:

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
