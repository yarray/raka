/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

import * as vscode from 'vscode';

const stemDoc =
`The stem of the output.

**Example:**

The stem of out/count__num__raw.csv is count__num__raw`;

const capturesDoc =
`Captures when using pattern matching.

Use token name to refer to the whole capture, use token{i} to refer to sub-captures.

**Example:**

For csv.name["(\S+)_(\d+)"].stat with an output "out/stat__exp_12.csv":

- *rask.captures.name* is "exp_12"
- *rask.captures.name0* is "exp"
- and *rask.captures.name1* is "12"`

export function activate(context: vscode.ExtensionContext) {
    const provider = vscode.languages.registerCompletionItemProvider(
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
                        ['name', 'string', 'The output file, alias to output'],
                        ['output', 'string', 'The output file'],
                        ['stem', 'string', stemDoc + '\nalias to output_stem'],
                        ['output_stem', 'string', stemDoc],
                        ['output_dir', 'string', 'The directory of the output file'],
                        ['input', 'string', 'The input file, inferred from the chaining target.\n\n**Example:**\n\nthe input of out/count__num__raw.csv may be out/num__raw.csv'],
                        ['input_stem', 'string', 'The stem of the input\n\n**Example:**\n\nthe stem of out/num__raw.csv is num__raw'],
                        ['deps', '[string]', 'The dependencies of task\n\nDependencies are declared at the right hand of the raka rule, not including the input'],
                        ['captures', 'object', capturesDoc],
                        ['func', 'string', 'Last token of the chaining target\n\n**Example:**\n\nthe func of out/count__num__raw.csv is "count"'],
                        ['output_scope', 'string', '#'],
                        ['ext', 'string', '#'],
                    ];
                }
                return methods.length > 0
                    ? methods.map((m) => {
                          let item = new vscode.CompletionItem(
                              m[0],
                              vscode.CompletionItemKind.Method
                          );
						  item.detail = m[1]
						  item.documentation = new vscode.MarkdownString(m[2]);
						  return item;
                      })
                    : undefined;
            },
        },
        '.' // triggered whenever a '.' is being typed
    );

    context.subscriptions.push(provider);
}
