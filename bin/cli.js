#!/usr/bin/env node
// CLI entry for `npx agentic-undo-redo [...]`.
// Thin wrapper that dispatches to install.sh / uninstall.sh, passing through
// any flags (e.g. --project [DIR]).

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const PKG_ROOT = path.join(__dirname, '..');
const PKG = require(path.join(PKG_ROOT, 'package.json'));

const argv = process.argv.slice(2);
const command = argv[0] || 'install';
const rest = argv.slice(1);

const help = `agentic-undo-redo v${PKG.version}

Usage:
  npx agentic-undo-redo                          # install globally (default)
  npx agentic-undo-redo install                  # same
  npx agentic-undo-redo install --project [DIR]  # install into one repo only
  npx agentic-undo-redo uninstall                # remove (--global default)
  npx agentic-undo-redo uninstall --project [DIR]
  npx agentic-undo-redo --version
  npx agentic-undo-redo --help

Pin a specific version:
  npx agentic-undo-redo@0.1.0
  npx github:ak5/agentic-undo-redo#v0.1.0

Source — read before running, it's small: ${PKG.homepage}
`;

if (['--help', '-h', 'help'].includes(command)) {
  process.stdout.write(help); process.exit(0);
}
if (['--version', '-v', 'version'].includes(command)) {
  process.stdout.write(`${PKG.version}\n`); process.exit(0);
}

const scriptMap = { install: 'install.sh', uninstall: 'uninstall.sh' };
const scriptName = scriptMap[command];
if (!scriptName) {
  process.stderr.write(`Unknown command: ${command}\n\n${help}`);
  process.exit(2);
}

const scriptPath = path.join(PKG_ROOT, scriptName);
if (!fs.existsSync(scriptPath)) {
  process.stderr.write(`Internal error: ${scriptName} not found at ${scriptPath}\n`);
  process.exit(3);
}

const result = spawnSync('bash', [scriptPath, ...rest], {
  stdio: 'inherit',
  env: { ...process.env, AGENTIC_UNDO_REDO_VERSION: PKG.version },
});
process.exit(result.status === null ? 1 : result.status);
