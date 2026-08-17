// Syntax-checks every Lua file against Lua 5.1, which is what WoW runs.
// Not a substitute for loading the addon, but it catches the class of mistake
// that otherwise only surfaces as a silent failure to load.
//
//   npm install luaparse
//   node check.js .

const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const root = process.argv[2] || '.';

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name === '.git') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith('.lua')) out.push(full);
  }
  return out;
}

let failed = 0;
for (const file of walk(root)) {
  const source = fs.readFileSync(file, 'utf8');
  try {
    luaparse.parse(source, { luaVersion: '5.1' });
    console.log(`OK   ${path.relative(root, file)}`);
  } catch (error) {
    failed++;
    console.log(`FAIL ${path.relative(root, file)}`);
    console.log(`     ${error.message}`);
  }
}

console.log(failed === 0 ? '\nAll files parsed cleanly.' : `\n${failed} file(s) failed.`);
process.exit(failed === 0 ? 0 : 1);
