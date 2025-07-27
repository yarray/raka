# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Raka is a Domain Specific Language (DSL) built on top of Rake for defining rules and running data processing workflows. It provides improved pattern matching, scopes, language extensions, and conventions to reduce verbosity in data processing tasks.

## Development Commands

### Build and Package
- `rake` - Run default task (tests)
- `rake gem` - Build gem package (via Juwelier)
- `bundle install` - Install dependencies

### Testing

First, `cd test` to enter the test directory.

- `ruby test.rb` - Run all tests
- `ruby test.rb -t <pattern>` - Run specific test files matching pattern
- `ruby test.rb -l <langs>` - Run tests for specific language protocols (e.g., shell,python)
- `LOG_LEVEL=0 ruby test.rb` - Run tests with verbose logging

### Code Quality
- `rubocop` - Run Ruby linter (configured in Gemfile)
- `reek` - Run code smell detector

### Documentation
- `rake rdoc` - Generate RDoc documentation

## Architecture

### Core Components

**Main Entry Point** (`lib/raka.rb`):
- `Raka` class initializes DSL environment
- Creates token creators for output types (csv, pdf, etc.)
- Manages scopes and language protocol loading
- Provides `scope` method for rule scoping

**Token System** (`lib/raka/token.rb`):
- `Token` class represents chained expressions in rules
- `Context` preserves extension and scope information
- Handles pattern matching and template resolution
- Uses method_missing for dynamic token chaining

**Compilation** (`lib/raka/compile.rb`):
- `DSLCompiler` transforms raka rules into Rake tasks
- Resolves automatic variables ($@, $<, $(dep0), etc.)
- Handles dependency resolution and file path mapping
- Manages scope extraction and target parsing

**Protocol System** (`lib/raka/protocol.rb`):
- `LanguageProtocol` enables embedding of foreign languages
- Supports shell, Python, R, and PostgreSQL protocols
- Handles template substitution and script execution
- Located in `lib/raka/lang/*/impl.rb` files

### Rule Structure

Raka rules follow the pattern: `target = [dependencies] | action`

- **Target**: Extension + token chain (e.g., `csv.data.processed`)
- **Dependencies**: Optional array of input files/targets
- **Action**: Protocol-specific code (shell*, py*, r*, psql*)

### Pattern Matching

- File names split on "__" map to token chains in reverse order
- Regex patterns in brackets enable capture groups
- Automatic variables provide context ($@=output, $<=input, etc.)
- Scopes organize rules hierarchically

### Language Protocols

Each protocol in `lib/raka/lang/` implements:
- Template variable substitution
- Script execution environment
- Language-specific conventions

## File Organization

- `lib/raka/` - Core library code
- `test/` - Test files organized by feature (core/, protocol/, scope/, etc.)
- `contrib/demo/` - Example raka files showing usage patterns
- `contrib/vscode/` - VS Code extension for syntax highlighting
- `bin/raka` - Command-line interface

## Testing Framework

Tests use custom `RakaTest` class that:
- Loads .raka files as Rake imports
- Executes default task with test context
- Validates outputs and behavior
- Supports targeted testing by file pattern or language

## Common Development Tasks

When working with raka files, use `.raka` extension and follow the DSL syntax. The `raka` command-line tool automatically detects main files (Rakefile.raka, main.raka, or single .raka file) and provides options for parallel execution (`-j`) and verbose output (`-v`).