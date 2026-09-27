// Bridge nix-openclaw's immutable npm packages to Openclaw's runtime provenance
// registry. Keep trust scoped to the official packages in the Nix lock metadata.
import { readFileSync, readdirSync } from "node:fs";
import { pathToFileURL } from "node:url";

const [dist, manifestPath] = process.argv.slice(2);
async function exportedFunction(prefix, name) {
  const exportPattern = new RegExp(`\\b${name} as (\\w+)\\b`);
  const files = readdirSync(dist).filter(f => f.startsWith(prefix) && f.endsWith(".mjs") &&
    exportPattern.test(readFileSync(`${dist}/${f}`, "utf8").split("export {").at(-1)));
  if (files.length !== 1) throw new Error(`Expected one Openclaw module for ${prefix}`);
  const path = `${dist}/${files[0]}`;
  const source = readFileSync(path, "utf8");
  const alias = source.split("export {").at(-1).match(exportPattern)?.[1];
  const module = await import(pathToFileURL(path).href);
  const fn = module[alias ?? name];
  if (typeof fn !== "function") throw new Error(`Openclaw no longer exports ${name}`);
  return fn;
}

const withLease = await exportedFunction("plugin-lifecycle-lease-", "withPluginLifecycleLease");
const readRecords = await exportedFunction("installed-plugin-record-match-", "loadInstalledPluginIndexInstallRecordsSync");
const writeRecords = await exportedFunction("installed-plugin-index-records-", "writePersistedInstalledPluginIndexInstallRecordsWithLease");
const config = JSON.parse(readFileSync(process.env.OPENCLAW_CONFIG_PATH, "utf8"));
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

await withLease({}, async lease => {
  const records = readRecords();
  let changed = false;
  for (const { id, ...record } of manifest) {
    const pkg = JSON.parse(readFileSync(`${record.installPath}/package.json`, "utf8"));
    if (pkg.name !== record.resolvedName || pkg.version !== record.version ||
        config.plugins?.entries?.[id]?.enabled !== true) {
      throw new Error(`Nix plugin provenance mismatch: ${id}`);
    }
    if (Object.entries(record).some(([key, value]) => records[id]?.[key] !== value)) {
      records[id] = record;
      changed = true;
    }
  }
  if (changed) {
    await writeRecords(records, { config, lease, filePath: lease.databasePath });
    console.log("Registered Nix-managed Openclaw plugin provenance.");
  }
});
