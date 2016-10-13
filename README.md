**Raka** is a **DSL** for Data processing based on Rake

## Why Raka

Data processing tasks can involve plenty of steps, each with its dependencies. Make is the classical tool to handle the situation and I used it to manage hundreds of data processing tasks in the past. However, since it is not dedicated to data processing, Make had several shortcomings which soon became headaches when the number of tasks rose. Rake is better on some aspect but is not perfectly useful for this situation. Fortunately, a rake script is in ruby so we can easily create syntax sugar and more on top of that. Briefly, Raka offers some advantages that Make or Rake does not have:

1. Extensible and context aware protocol architecture
2. Advanced pattern matching to maximize code reuse.
3. Other programming languages can be easily embedded
4. Auto dependency and naming by conventions when data is derived from a single source
5. Support scopes for multiple parallel research
6. Terse syntax

... and many more. See the next sections for more hints about why Raka can be useful for you.

## Concepts

The basic shape of rules is:

<!-- TODO -->

In Raka, these definitions are implemented with the following ruby syntax:

1. `expression` is separated by dot, like `ext.token.token.token`
2. `dependencies` and `postjobs` are just arrays
3. `name` can be anything that does not conflict with important staffs, while `_` means anything, or not binding to variables if with patterns
4. `pattern` is a regex str (note it CANNOT be a Regex itself), default to anything
4. `template` is a string to be resolved (See Variable resolving below)
5. `ext` default to csv and pdf, but is configurable in DSL.
6. `string` is anything can be to_s-ed


## Rule, pattern matching, and variable resolving

A `expression` corresponds to an actual file, the naming convention is 

``` 
ext.token1.token2...tokenN (target) -> tokenN__...__token2__token1.output_type 
```

When a token has pattern or template it has be resolved first. See the "Pattern matching and Variable resolving" section.

Examples:

```
csv.data.rules = [txt.spec] | <protocol> | []

table.objects[].geom = [csv._('%{objects}'), 'srs.csv'] | <protocol> | [idx._('%{objects}')]
```

##

## Basic API

### DSL API

These APIs are bounded to an instance of DSL, you can create the object at the top:

``` ruby
dsl = DSL.new(<env>, <options>)
```

The argument `<env>` should be the *self* of a running Rakefile. In most case you can directly write:

``` ruby
dsl = DSL.new(self, <options>)
```

The argument `options` currently support `output_types` and `input_types`. For each `output_types`, you will get an extra function to bootstrap a rule. For example, with


``` ruby
dsl = DSL.new(self, { output_types: [:csv, :pdf] })
```

you can write these rules like:

``` ruby
csv.data = ...
pdf.graph = ...
```

which will generate data.csv and graph.pdf

The `input_types` involves the strategy to find dependencies, which will be explained in detail later.

### protocol API

Currently Raka support 4 protocols: shell, psql, r and psqlf.

``` ruby
shell(base_dir='./')* code::templ_str { |task| ... }
psql(options={})* code::templ_str { |task| ... }
r(src:str, libs=[])* code::templ_str { |task| ... }

# options = { script_name: , script_file: , params: }
psqlf(options={})
```

## Functionalities and examples

## Rakefile Template

## Write your own protocols

## Compare to other tools

Raka borrows some ideas from Drake but not much (currently mainly the name "protocol"). Briefly we have different visions and maybe different suitable senarios.

## TODO

Rake is in fact an (imperfect) implementation of a more general concept model. The concepts should be clarified somewhere and linked back
