**Raka** is a **DSL**(Domain Specific Language) on top of **Rak**e for defining rules and running d**a**t**a** processing workflows. Raka is specifically designed for data processing with improved pattern matching, scopes, language extensions and lots of conventions to prevent verbosity.

## Installation

Raka is a library based on rake. Though rake is cross platform, raka may not work on Windows since it relies some shell facilities. To use raka, one has to install ruby and rake first. Ruby is available for most \*nix systems including Mac OSX so the only task is to install raka like:

```bash
gem install raka
```

## Quick Start

First create a file named `main.raka` and import & initialize the DSL

```ruby
require 'raka'

dsl = DSL.new(self,
  output_types: [:txt, :table, :pdf, :idx],
  input_types: [:txt, :table]
)
```

Then the code below will define two simple rules:

```ruby
txt.sort.first50 = shell* "cat sort.txt | head -n 50 > $@"
txt.sort = [txt.input] | shell* "cat $< | sort -rn > $@"
```

For testing let's prepare an input file named `input.txt`:

```bash
seq 1000 > input.txt
```

We can then invoke `rake first50.txt`, the script will read data from _input.txt_, sort the numbers descendingly and get the first 50 lines.

The workflow here is as follows:

1. Try to find _first50\_\_sort.txt_: not exists
2. Rule `txt.sort.first50` matched
3. For rule `txt.sort.first50`, find input file _sort.txt_ or _sort.table_. Neither exists
4. Rule `txt.sort` matched
5. Rule `txt.sort` has no input but a depended target `txt.input`
6. Find file _input.txt_ or _input.table_. Use the former
7. Run rule `txt.sort` and create _sort.txt_
8. Run rule `txt.sort.first50` and create _first50\_\_sort.txt_

This illustrates some basic ideas but may not be particularly interesting. Following is a much more sophisticated example from real world research which covers more features.

```ruby
SRC_DIR = File.absolute_path 'src'
USER = 'postgres'
DB = 'osm'
HOST = 'localhost'
PORT = 5432

def idx_this() [idx._('$(output_stem)')] end

dsl.scope :de

idx._ = psqlf(script_name: '$stem_idx.sql')
pdf.buildings.func['(\S+)_graph'] = r(:graph)* %[
  table_input("$(input_stem)") | draw_%{func0} | ggplot_output('$@') ]
table.buildings = [csv.admin] | psqlf(admin: '$<') | idx_this
```

Assume that we have a schema named _de_ in database _osm_, have a input file _admin.csv_, and have _graph.R_ and _buildings.sql_ under _src/_. Now further assume that _graph.R_ contains two functions:

```r
draw_stat_snapshot <- function(d) { ... }
draw_user_trend <- function(d) { ... }
```

...and _buildings.sql_ contains table creation code like:

```sql
DROP TABLE IF EXISTS buildings;
CREATE TABLE buildings AS ( ... );
```

We may also have a _buildings_idx.sql_ to create index for the table.

Then we can run either `rake de/stat_snapshot_graph__buildings.pdf` or `rake de/user_trend_graph__buildings.pdf`, which will do a bunch of things at first run (take the former as example):

1. Target file not found.
2. Rule `pdf.buildings.func['(\S+)_graph']` matched. "stat_snapshot_graph" is bound to `func` and "stat_snapshot" is bound to `func0`.
3. None of the four possible input files: _de/buildings.table_, _de/buildings.txt_, _buildings.table_, _buildings.txt_ can be found. Rule `table.buildings` is matched and the only dependecy file _admin.csv_ is found.
4. The protocol `psqlf` finds the source file _src/buildings.sql_, intepolate the options with automatic variables (`$<` as "admin.csv"), run the sql, and create a placeholder file _de/buildings.table_ afterwards.
5. Run the post-job `idx_this`, according to the rule `idx._` it will find and run _buildings_idx.sql_, then create a placeholder file _de/buildings.idx_.
6. For rule `pdf.buildings.func['(\S+)_graph']`, the R code in `%[]` is interpolated with several automatic variables (`$(input_stem)` as "buildings", `$@` as "de/stat_snapshot_graph\_\_buildings.pdf") and the variables (`func`, `func0`) bound before.
7. Run the R code. The _buildings_ table is piped into the function `draw_snapshot_graph` and then output to `ggplot_output`, which writes the graph to the specified pdf file.

## Why Raka

Data processing tasks can involve plenty of steps, each with its dependencies. Compared to bare Rake or the more classical Make, Raka offers the following advantages:

1. Advanced pattern matching and template resolving to define general rules and maximize code reuse.
2. Extensible and context-aware protocol architecture.
3. Multilingual. Other programming languages can be easily embedded.
4. Auto dependency and naming by conventions.
5. Scopes to ease comparative studies.
6. Terser syntax.

... and more.

Compared to more comlex, GUI-based solutions (perhaps classified as scientific-workflow software) like Kepler, etc., Raka has the following advantages:

1. Lightweight and easy to setup, especially on platforms with ruby preinstalled.
2. Easy to deploy, version-control, backup or share workflows since the workflows are merely text files.
3. Easy to reuse modules or create reusable modules, which are merely plain ruby code snippets (or in other languages with protocols).
4. Expressive so a few lines of code can replace many manual operations.

## Documentation

### Syntax of Rules

It is possible to use Raka with little knowledge of ruby / rake, though minimal understandings are highly recommended. The formal syntax of rule can be defined as follows (W3C EBNF form):

```ebnf
rule ::= target "=" (dependencies "|")* protocol ("|" post_target)*

target ::= ext "." ltoken ("." ltoken)*

dependency ::= rexpr | template

post_target ::= rexpr | template

dependencies ::= "[]" | "[" dependency ("," dependency)* "]"

rexpr ::= ext "." rtoken ("." rtoken)*

ltoken ::= word | word "[" pattern "]"
rtoken ::= word | word "(" template ")"

word ::= ("_" | letter) ( letter | digit | "_" )*

protocol ::= ("shell" | "r" | "psql" | "py" ) ("*" template | BLOCK ) | "run" BLOCK
```

The corresponding railroad diagrams are:

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/rule.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/target.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/dependencies.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/dependency.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/post_target.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/rexpr.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/ltoken.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/rtoken.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/word.svg)

![](https://cdn.rawgit.com/yarray/raka/master/doc/syntax/protocol.svg)

The definition is concise but several details are omitted for simplicity:

1. **BLOCK** and **HASH** is ruby's block and hash object.
2. A **template** is just a ruby string, but with some placeholders (see the next section for details)
3. A **pattern** is just a ruby string which represents regex (see the next section for details)
4. The listed protocols are merely what we offered now. It can be greatly extended.
5. Nearly any concept in the syntax can be replaced by a suitable ruby variable.

### Pattern matching and template resolving

When defined a rule like `lexpr = rexpr`, the left side represents a pattern and the right side contains specifications for extra dependecies, actions and some targets to create thereafter. When raking a target file, the left sides of the rules will be examined one by one until a rule is matched. The matching process based on Regex also support named captures so that some varibales can be bound for use in the right side.

The specifications on the right side of a rule can be incomplete from various aspects, that is, they can contains some templates. The "holes" in the templates will be fulfilled by automatic variables and variables bounded when matching the left side.

#### Pattern matching

To match a given _file_ with a `lexpr`, asides the extension, the substrings of the file name between "\_\_" are mapped to tokens separated by `.`, in reverse order. After that, each substring is matched to the corresponding token or the regex in `[]`. For example, the rule

```ruby
pdf.buildings.indicator['\S+'].top['top_(\d+)']
```

can match "top_50\_\_node_num\_\_buildings.pdf". The logical process is:

1. The extension `pdf` matches.
2. The substrings and the tokens are paired and they all match:
   - `buildings ~ buildings`
   - `'\S+' ~ node_num`
   - `top_(\d+) ~ top_50`
3. Two levels of captures are made. First, 'node_num' is captured as `indicator`, 'top_50' is captured as `top`; Second, '50' is captured as `top0` since `\d+` is wrapped in parenthesis and is the first.

One can write special token `_` or `something[]` if the captured value is useful later, as the syntax sugar of `something['\S+']`.

#### Template resolving

In some places of `rexpr`, templates can be written instead of strings, so that it can represent different values at runtime. There are two types of variables that can be used in templates. The first is automatic variables, which is just like `$@` in Make or `task.name` in Rake. We even preserve some Make conventions for easier migrations. All automatic varibales begin with `$`. The possible automatic variables are:

| symbol         | meaning                | symbol          | meaning                         |
| -------------- | ---------------------- | --------------- | ------------------------------- |
| \$@            | output file            | \$^             | all dependecies (sep by spaces) |
| \$<            | first dependency       | $0, $1, … \$i   | ith depdency                    |
| \$(scope)      | scope for current task | \$(output_stem) | stem of the output file         |
| \$(input_stem) | stem of the input file |                 |                                 |

The other type of variables are those bounded during pattern matching,which can be referred to using `%{var}`. In the example of the [pattern matching](###pattern-matching) section, `%{indicator}` will be replaced by `node_num`, `%{top}` will be replaced by `top_50` and `%{top0}` will be replaced by `50`. In such case, a template as `'calculate top %{top0} of %{indicator} for $@'` will be resolved as `'calculate top 50 of node_num for top_50__node_num__buildings.pdf'`

The replacement of variables happen before any process to the template string. So do not include the symbols for automatic variables or `%{<anything>}` in templates.

Templates can happen in various places. For depdencies and post jobs, tokens with parenthesis can wrap in templates, like `csv._('%{indicator}')`. The symbol of a token with parenthesis is of no use and is generally omitted. It is also possible to write template literal directly, i.e. `'%{indicator}.csv'`. Where templates can be applied in actions depends on the protocols and will be explained later in the [Protocols](###protocols) section

### Scope

### Protocols

Currently Raka support 4 lang: shell, psql, r and psqlf.

```ruby
shell(base_dir='./')* code::templ_str { |task| ... }
psql(options={})* code::templ_str { |task| ... }
r(src:str, libs=[])* code::templ_str { |task| ... }

# options = { script_name: , script_file: , params: }
psqlf(options={})
```

### Initialization and options

These APIs are bounded to an instance of DSL, you can create the object at the top:

```ruby
dsl = DSL.new(<env>, <options>)
```

The argument `<env>` should be the *self* of a running Rakefile. In most case you can directly write:

```ruby
dsl = DSL.new(self, <options>)
```

The argument `options` currently support `output_types` and `input_types`. For each item in `output_types`, you will get an extra function to bootstrap a rule. For example, with

```ruby
dsl = DSL.new(self, { output_types: [:csv, :pdf] })
```

you can write these rules like:

```ruby
csv.data = ...
pdf.graph = ...
```

which will generate data.csv and graph.pdf

The `input_types` involves the strategy to find inputs. For example, raka will try to find both *numbers.csv* and *numbers.table* for a rule like `table.numbers.mean = …` if `input_type = [:csv, :table]`.

## Rakefile Template

## Write your own protocols

## Compare to other tools

Raka borrows some ideas from Drake but not much (currently mainly the name "protocol"). Briefly we have different visions and maybe different suitable senarios.
