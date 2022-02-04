
# syntax.ebnf

## 


### rule

![rule](./syntax/rule.svg)

References: [target](#target), [dependencies](#dependencies), [protocol](#protocol), [post_target](#post_target)

### target

![target](./syntax/target.svg)

Used by: [rule](#rule)
References: [ext](#ext), [ltoken](#ltoken)

### dependency

![dependency](./syntax/dependency.svg)

Used by: [dependencies](#dependencies)
References: [rexpr](#rexpr), [template](#template)

### post_target

![post_target](./syntax/post_target.svg)

Used by: [rule](#rule)
References: [rexpr](#rexpr), [template](#template)

### dependencies

![dependencies](./syntax/dependencies.svg)

Used by: [rule](#rule)
References: [dependency](#dependency)

### rexpr

![rexpr](./syntax/rexpr.svg)

Used by: [dependency](#dependency), [post_target](#post_target)
References: [ext](#ext), [rtoken](#rtoken)

### ltoken

![ltoken](./syntax/ltoken.svg)

Used by: [target](#target)
References: [word](#word), [pattern](#pattern)

### rtoken

![rtoken](./syntax/rtoken.svg)

Used by: [rexpr](#rexpr)
References: [word](#word), [template](#template)

### word

![word](./syntax/word.svg)

Used by: [ltoken](#ltoken), [rtoken](#rtoken)
References: [letter](#letter), [digit](#digit)

### protocol

![protocol](./syntax/protocol.svg)

Used by: [rule](#rule)
References: [template](#template), [BLOCK](#BLOCK)

