// Only used on a freshly copied bundled-plugin tree, before app customization.
async function codexNixPrepareBundledCopy({
  fs, path, pluginRoot, pluginName, computerUseAudioEnabled,
}) {
  const uid = process.getuid();
  const root = path.resolve(pluginRoot);

  async function inspectOwned(target) {
    const stat = await fs.lstat(target);
    if (stat.isSymbolicLink() || stat.uid !== uid) {
      throw new Error("Refusing to change an unowned or symlinked bundled copy");
    }
    return stat;
  }

  async function prepareDirectories(target) {
    const stat = await inspectOwned(target);
    if (!stat.isDirectory()) {
      if (!stat.isFile()) throw new Error("Unexpected bundled-copy file type");
      return;
    }
    // Preserve execute, group/other, and special bits; never chmod source assets.
    if (!(stat.mode & 0o200)) await fs.chmod(target, (stat.mode & 0o7777) | 0o200);
    for (const entry of await fs.readdir(target)) {
      await prepareDirectories(path.join(target, entry));
    }
  }

  await prepareDirectories(root);
  const writableFiles = [];
  if (pluginName === "visualize" ||
      (pluginName === "computer-use" && computerUseAudioEnabled)) {
    writableFiles.push(".codex-plugin/plugin.json");
  }
  if (pluginName === "computer-use" && computerUseAudioEnabled) {
    writableFiles.push("skills/computer-use/SKILL.md");
  }
  for (const relative of writableFiles) {
    const target = path.join(root, relative);
    const stat = await inspectOwned(target);
    if (!stat.isFile() || (stat.mode & 0o111)) {
      throw new Error("Refusing to make an executable or non-file manifest writable");
    }
    if (!(stat.mode & 0o200)) await fs.chmod(target, (stat.mode & 0o7777) | 0o200);
  }
}

// The executor overwrites this cache on every start, then rewrites .mcp.json.
// Limit permission changes to user-owned cache directories and that one file.
async function codexNixCopyExecutorPlugin({ fs, path, sourceRoot, pluginRoot }) {
  const uid = process.getuid();
  if (!path.isAbsolute(sourceRoot) || !path.isAbsolute(pluginRoot)) {
    throw new Error("Executor plugin paths must be absolute");
  }
  const source = path.resolve(sourceRoot);
  const root = path.resolve(pluginRoot);
  const within = (base, target) => {
    const relative = path.relative(base, target);
    return relative === "" || (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." && !path.isAbsolute(relative));
  };
  if (root === path.parse(root).root || within(source, root) || within(root, source)) {
    throw new Error("Refusing overlapping or unbounded executor plugin paths");
  }

  // Reject symlinked destination ancestors as well as entries inside the cache.
  // Do not chmod ancestors outside the selected plugin root.
  async function inspectAncestors() {
    const chain = [];
    for (let current = root; ; current = path.dirname(current)) {
      chain.unshift(current);
      if (path.dirname(current) === current) break;
    }
    for (const target of chain) {
      let info;
      try { info = await fs.lstat(target); }
      catch (error) { if (error.code === "ENOENT") return; throw error; }
      if (info.isSymbolicLink() || !info.isDirectory()) {
        throw new Error("Refusing a symlinked or non-directory executor cache path");
      }
    }
  }

  async function inspectTree(target, owned, allowMissing = false) {
    let info;
    try { info = await fs.lstat(target); }
    catch (error) { if (allowMissing && error.code === "ENOENT") return []; throw error; }
    if (info.isSymbolicLink() || (owned && info.uid !== uid)) {
      throw new Error("Refusing an unowned or symlinked executor plugin tree");
    }
    if (!info.isDirectory() && !info.isFile()) {
      throw new Error("Unexpected executor plugin file type");
    }
    const result = [{ target, info }];
    if (info.isDirectory()) {
      for (const name of await fs.readdir(target)) {
        const child = path.join(target, name);
        if (!within(owned ? root : source, child)) {
          throw new Error("Executor plugin path escaped its root");
        }
        result.push(...await inspectTree(child, owned));
      }
    }
    return result;
  }

  async function addOwnerWrite({ target, info }) {
    if (info.mode & 0o200) return;
    // O_NOFOLLOW plus descriptor-based chmod prevents a swapped final symlink
    // from redirecting the permission change to an outside file.
    const handle = await fs.open(target, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
    try {
      const current = await handle.stat();
      if (current.uid !== uid || current.dev !== info.dev || current.ino !== info.ino ||
          current.mode !== info.mode) {
        throw new Error("Executor plugin changed during permission preparation");
      }
      await handle.chmod((current.mode & 0o7777) | 0o200);
    } finally { await handle.close(); }
  }

  await inspectAncestors();
  if (await fs.realpath(source) !== source) {
    throw new Error("Refusing a symlinked executor source path");
  }
  const sourceEntries = await inspectTree(source, false);
  if (!sourceEntries[0].info.isDirectory()) throw new Error("Executor source is not a directory");
  const sourceManifest = sourceEntries.find(({ target }) => target === path.join(source, ".mcp.json"));
  if (!sourceManifest || !sourceManifest.info.isFile() || (sourceManifest.info.mode & 0o111)) {
    throw new Error("Executor source manifest must be a non-executable regular file");
  }
  const before = await inspectTree(root, true, true);
  if (before.length && !before[0].info.isDirectory()) {
    throw new Error("Executor cache is not a directory");
  }
  for (const entry of before) if (entry.info.isDirectory()) await addOwnerWrite(entry);
  await fs.cp(sourceRoot, pluginRoot, { recursive: true });
  await inspectAncestors();
  const after = await inspectTree(root, true);
  const manifest = after.find(({ target }) => target === path.join(root, ".mcp.json"));
  if (!manifest || !manifest.info.isFile() || manifest.info.nlink !== 1 ||
      (manifest.info.mode & 0o111)) {
    throw new Error("Executor cache manifest must be a non-executable, singly linked regular file");
  }
  for (const entry of after) if (entry.info.isDirectory()) await addOwnerWrite(entry);
  await addOwnerWrite(manifest);
}

codexNixPrepareBundledCopy.copyExecutorPlugin = codexNixCopyExecutorPlugin;

module.exports = codexNixPrepareBundledCopy;
