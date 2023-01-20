/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

import * as vscode from 'vscode';

const outputDoc = 'The output file';
const inputDoc = `The input file, inferred from the chaining target.

**Example:**

the input of out/count__num__raw.csv may be out/num__raw.csv
`;

const inputStemDoc = `The stem of the input

**Example:**

the stem of out/num__raw.csv is num__raw`;

const outputStemDoc = `The stem of the output.

**Example:**

The stem of out/count__num__raw.csv is count__num__raw`;

const capturesDoc = `Captures when using pattern matching.

Use token name to refer to the whole capture, use token{i} to refer to sub-captures.

**Example:**

For csv.name["(\S+)_(\d+)"].stat with an output "out/stat__exp_12.csv":

- *rask.captures.name* is "exp_12"
- *rask.captures.name0* is "exp"
- and *rask.captures.name1* is "12"`;

const depsDoc = `The dependencies of task

Dependencies are declared at the right hand of the raka rule, not including the input`;

const funcDoc = `Last token of the chaining target

**Example:**

the func of out/count__num__raw.csv is "count"`;

const scopeDoc = `Task scope, i.e. the common directory of output and dependencies

**Example:**

- Given a rule "csv.test = [csv.raw] ..." with output "out/2021/test.csv", the scope is out/2021
- Given a rule "csv('group0').test = [csv.raw] ..." with output "out/2021/group0/test.csv", the scope is out/2021
`;

const targetScopeDoc = `Target scope, i.e. the directory specified in target

**Example:**

Given a rule "csv('2021/group0').test = [csv.raw] ...", the target scope is 2021/group0
`;

const ruleScopesDoc = `Scopes as defined at rule level, i.e. by dsl.scopes

**Example:**

Given a rule:
\`\`\`ruby
dsl.scope :group0, :group1  do
	dsl.scope :sub0, :sub1 do
		csv.test = ...
	end
end
\`\`\`
and output "out/group0/sub1/test.csv", the rule scopes are [:sub1, :group0]
`;

const extDoc = 'Extension of the output file';

export function activate(context: vscode.ExtensionContext) {
    const embedLangProvider = vscode.languages.registerCompletionItemProvider(
        'ruby',
        {
            provideCompletionItems(
                document: vscode.TextDocument,
                position: vscode.Position
            ) {
                const linePrefix = document
                    .lineAt(position)
                    .text.slice(0, position.character);
                if (linePrefix.endsWith('<<~') || linePrefix.endsWith('<<-')) {
                    return ['SHELL', 'PYTHON', 'SQL'].map((m) => {
                        const item = new vscode.CompletionItem(
                            m,
                            vscode.CompletionItemKind.Variable
                        );
                        item.insertText = new vscode.SnippetString(m + '\n  $1\n' + m);
                        item.documentation = `Embed ${m} Language`
                        return item;
                    });
                }
            },
        },
        '-', '~'
    );
    const raskProvider = vscode.languages.registerCompletionItemProvider(
        'ruby',
        {
            provideCompletionItems(
                document: vscode.TextDocument,
                position: vscode.Position
            ) {
                // get all text until the `position` and check if it reads `console.`
                // and if so then complete if `log`, `warn`, and `error`
                const linePrefix = document
                    .lineAt(position)
                    .text.slice(0, position.character);

                let methods: [string, string, string][] = [];
                if (linePrefix.endsWith('rask.')) {
                    methods = [
                        ['name', 'string', outputDoc + '\nalias to output'],
                        ['output', 'string', outputDoc],
                        [
                            'stem',
                            'string',
                            outputStemDoc + '\nalias to output_stem',
                        ],
                        ['output_stem', 'string', outputStemDoc],
                        ['input', 'string', inputDoc],
                        ['input_stem', 'string', inputStemDoc],
                        ['deps', '[string]', depsDoc],
                        ['captures', 'object', capturesDoc],
                        ['func', 'string', funcDoc],
                        ['scope', 'string', scopeDoc],
                        ['target_scope', 'string', targetScopeDoc],
                        ['rule_scopes', '[string]', ruleScopesDoc],
                        ['ext', 'string', extDoc],
                    ];
                }
                return methods.length > 0
                    ? methods.map((m) => {
                          let item = new vscode.CompletionItem(
                              m[0],
                              vscode.CompletionItemKind.Method
                          );
                          item.detail = m[1];
                          item.documentation = new vscode.MarkdownString(m[2]);
                          return item;
                      })
                    : undefined;
            },
        },
        '.' // triggered whenever a '.' is being typed
    );

    const autoVarProvider = vscode.languages.registerCompletionItemProvider(
        'ruby',
        {
            provideCompletionItems(
                document: vscode.TextDocument,
                position: vscode.Position
            ) {
                if (
                    document.lineAt(position.line).text[
                        position.character - 1
                    ] !== '$'
                ) {
                    return;
                }
                const vars = [
                    ['@', '$@: the output file'],
                    [
                        '^',
                        '$^: the dependencies, concated by ",", not including input',
                    ],
                    ['<', '$@: the input file'],
                ];
                const parenVars = [
                    ['output', outputDoc],
                    ['input', inputDoc],
                    ['output_stem', outputStemDoc],
                    ['input_stem', inputStemDoc],
                    [
                        'deps',
                        'The dependencies, concated by ",", not including input',
                    ],
                    ['dep0', 'The i-th dependency, not including input'],
                    [
                        'scope',
                        'The scope of the task, i.e. the common directory for both output and dependencies',
                    ],
                    ['target_scope', targetScopeDoc],
                    [
                        'target_scope0',
                        'The i-th capture of the scope pattern specified by the rule target',
                    ],
                    [
                        'rule_scope0',
                        'The i-th rule scope, specify by nested dsl.scopes\n\n' +
                            ruleScopesDoc,
                    ],
                ];
                return vars
                    .map((v) => {
                        let item = new vscode.CompletionItem(
                            v[0],
                            vscode.CompletionItemKind.Variable
                        );
                        item.documentation = new vscode.MarkdownString(v[1]);
                        return item;
                    })
                    .concat(
                        parenVars.map((v) => {
                            let item = new vscode.CompletionItem(
                                v[0],
                                vscode.CompletionItemKind.Variable
                            );
                            item.insertText = `(${v[0]})`;
                            item.documentation = new vscode.MarkdownString(
                                v[1]
                            );
                            return item;
                        })
                    );
            },
        },
        '$'
    );
    context.subscriptions.push(raskProvider);
    context.subscriptions.push(autoVarProvider);
    context.subscriptions.push(embedLangProvider);
}
