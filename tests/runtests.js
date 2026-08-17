const fs = require('fs');
const path = require('path');
const { LuaFactory } = require('wasmoon');

const addonRoot = process.argv[2];
const testFile = process.argv[3];

(async () => {
  const factory = new LuaFactory();

  // Mount the addon sources into the VM's virtual filesystem so loadfile works.
  for (const rel of ['Core/Squads.lua', 'Core/Transfer.lua']) {
    const content = fs.readFileSync(path.join(addonRoot, rel), 'utf8');
    await factory.mountFile(`addon/${rel}`, content);
  }

  const lua = await factory.createEngine();
  let code = 0;
  try {
    const testSource = fs.readFileSync(testFile, 'utf8');
    const failures = await lua.doString(
      `local ADDON_ROOT = "addon"\n` +
      testSource.replace('local ADDON_ROOT = ...', '')
    );
    code = failures && failures > 0 ? 1 : 0;
  } catch (e) {
    console.error('Lua error:', e.message);
    code = 1;
  }

  // Deliberately not closing the Lua state: wasmoon's teardown trips a libuv
  // assertion on Windows, which would turn a clean run into a spurious crash.
  process.exit(code);
})();
