**Raka** is a **DSL**(Domain Specific Language) for D**a**t**a** processing based on top of **Ra**ke. Unlike comman task runners like Make or Rake itself, Raka is specifically designed for data processing with improved pattern matching, multilingual support, scopes, and lots of conventions to prevent verbosity. 

## Why Raka

Data processing tasks can involve plenty of steps, each with its dependencies. Make is the classical tool to handle the situation but it had several shortcomings which soon became headaches when the number of tasks rises. Rake is better here but can still be improved from various aspects. Raka offers the following advantages:

1. Advanced pattern matching to maximize code reuse.
2. Extensible and context-aware protocol architecture
3. Multilingual. Other programming languages can be easily embedded
4. Auto dependency and naming by conventions
5. Support scopes
6. Terser syntax

... and more.

## Installation

Raka is a drop-in library for rake. Though rake is cross platform, raka may not work on Windows since it relies some shell facilities. To use raka, one has to install ruby and rake first. Ruby is available for most *nix systems including Mac OSX so the only task is to install rake like:

``` bash
gem install rake
```

 The next step is to clone this project to local machine, and `require` the `dsl.rb` file in your Rakefile.

## Quick Start

First create a file named `Rakefile` and import & initialize the DSL (assuming this repository is cloned at the same place of the `Rakefile`):

``` ruby
require_relative './raka/dsl'

dsl = DSL.new(self,
  output_types: [:txt, :table, :pdf, :idx],
  input_types: [:txt, :table]
)
```

Then the code below will define two simple rules:

``` ruby
txt.first50.comment = shell* "sed 's#^#//#' first50.txt > $@"
txt.first50 = [txt.input] | shell* "head -n 50 $< > $@"
```

For testing let's prepare an input file named `input.txt`:

``` bash
seq 1000 > input.txt
```

We can then invoke `rake comment__first50.txt`, the script will read data from `input.txt`, get the first 50 lines, and then insert `//` at the beginning of each line.

The workflow here is as follows:

1. Try to find `comment__first50.txt`: not exists
2. Rule `txt.first50.comment` matched
3. For rule `txt.first50.comment`, find input file `first50.txt` or `first50.table`, neither exists
4. Rule `txt.first50` matched
5. Rule `txt.first50` has no input but a depended target `txt.input`
6. Find file `input.txt` or `input.table`, use the former
7. Invoke by rule `txt.first50`
8. Invoke by rule `txt.first50.comment`

This illustrates some basic ideas but may not be particularly interesting. Following is a much more sophisticated example from real world research which covers more features.

``` ruby
SRC_DIR = File.absolute_path 'src'
USER = 'postgres'
DB = 'osm'
HOST = 'localhost'
PORT = 5432

def idx_this() [idx._('$(stem)')] end

dsl.scope :de

idx._ = psqlf(script_name: '$stem_idx.sql')
pdf.buildings.func['(\S+)_graph'] = r(:graph)* %[
  table_input("$(input_stem)") | draw_%{func0} | ggplot_output('$@') ]
table.buildings = [csv.admin] | psqlf(admin: '$<') | idx_this
```

Assume that we have a schema named `de` in database `osm`, have a input file `admin.csv`, and have `graph.R` and `buildings.sql` under `src/`. Now further assume that `graph.R` contains two functions:

``` r
draw_stat_snapshot <- function(d) { ... }
draw_user_trend <- function(d) { ... }
```

...and `buildings.sql` contains table creation code like:

``` sql
DROP TABLE IF EXISTS buildings;
CREATE TABLE buildings AS ( ... );
```

We may also have a `buildings_idx.sql` to create index for the table.

Then we can run either `rake de/stat_snapshot_graph__buildings.pdf` or `rake de/user_trend_graph__buildings.pdf`, which will do a bunch of things at first run (take the former as example):

1. Target file not found. 
2. Rule `pdf.buildings.func['(\S+)_graph']` matched. `stat_snapshot_graph` is bound to `func` and `stat_snapshot` is bound to `func0`.
3. None of the four possible input files: `de/buildings.table`, `de/buildings.txt`,`buildings.table`, `buildings.txt` can be found. Rule `table.buildings` matched and the only dependecy `admin.csv` found.
4. The protocol `psqlf` finds the source file `src/buildings.sql`, intepolate the options with automatic variables (`$<` as `admin.csv`), run the sql, and create a placeholder file `de/buildings.table` afterwards.
5. Run the post-job `idx_this`, according to the rule `idx._` it will find and run `buildings_idx.sql`, then create a placeholder file `buildings.idx`.
6. For rule `pdf.buildings.func['(\S+)_graph']`, the R code in `%[]` is interpolated with several automatic variables (`$(input_stem)` as `buildings`, `$@` as `de/stat_snapshot_graph__buildings.pdf`) and the variables (`func`, `stat_snapshot`) bound before.
7. Run the R code. The `buildings` table is piped into the function `draw_snapshot_graph` and then output to `ggplot_output`, which writes the graph to the specified pdf file.

## Syntax of Rules

It is possible to use Raka with little knowledge of ruby / rake, though minimal understandings are highly recommended. The formal syntax of rule can be defined as follows (EBNF form):

``` ebnf
rule = lexpr "=" {target_list "|"} protocol {"|" target_list};

target = rexpr | template;

target_list = "[]" | "[" target {"," target} "]";

lexpr = ext "." {ltoken "."} ltoken;
rexpr = ext "." rtoken {"." rtoken};

ltoken = word | word "[" pattern "]";
rtoken = word | word "(" template ")";

word = ("_" | letter) { letter | digit | "_" };

protocol = ("shell" | "r" | "psql") ("*" template | BLOCK )
         | "psqlf" | "psqlf" "(" HASH ")";
```

The corresponding railroad diagrams are:

![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/rule.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/target.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/target_list.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/lexpr.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/rexpr.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/ltoken.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/rtoken.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/word.svg)



![](https://cdn.rawgit.com/yarray/raka/master/doc/figures/protocol.svg)



The definition is concise but several details are omitted for simplicity:

1. **BLOCK** and **HASH** is ruby's block and hash object.
2. A **template** is just a ruby string, but with some placeholders (see the next section for details)
3. A **pattern** is just a ruby string which represents regex (see the next section for details)
4. The listed protocols are merely what we offered now. It can be greatly extended.
5. Nearly any concept in the syntax can be replaced by a suitable ruby variable.


## Rule, pattern matching, and variable resolving

### TODO not complete yet

A `expression` corresponds to an actual file, the naming convention is 

``` ruby
ext.token1.token2...tokenN (target) -> tokenN__...__token2__token1.output_type 
```

When a token has pattern or template it has be resolved first. See the "Pattern matching and Variable resolving" section.

Examples:

```ruby
csv.data.rules = [txt.spec] | <protocol> | []

table.objects[].geom = [csv._('%{objects}'), 'srs.csv'] | <protocol> | [idx._('%{objects}')]
```

## Basic API

### Initialization and Options

These APIs are bounded to an instance of DSL, you can create the object at the top:

``` ruby
dsl = DSL.new(<env>, <options>)
```

The argument `<env>` should be the *self* of a running Rakefile. In most case you can directly write:

``` ruby
dsl = DSL.new(self, <options>)
```

The argument `options` currently support `output_types` and `input_types`. For each item in `output_types`, you will get an extra function to bootstrap a rule. For example, with


``` ruby
dsl = DSL.new(self, { output_types: [:csv, :pdf] })
```

you can write these rules like:

``` ruby
csv.data = ...
pdf.graph = ...
```

which will generate data.csv and graph.pdf

The `input_types` involves the strategy to find inputs. For example, raka will try to find both *numbers.csv* and *numbers.table* for a rule like `table.numbers.mean = …` if `input_type = [:csv, :table]`.

### Scope

### Protocols

Currently Raka support 4 protocols: shell, psql, r and psqlf.

``` ruby
shell(base_dir='./')* code::templ_str { |task| ... }
psql(options={})* code::templ_str { |task| ... }
r(src:str, libs=[])* code::templ_str { |task| ... }

# options = { script_name: , script_file: , params: }
psqlf(options={})
```

## Rakefile Template

## Write your own protocols

## Compare to other tools

Raka borrows some ideas from Drake but not much (currently mainly the name "protocol"). Briefly we have different visions and maybe different suitable senarios.
