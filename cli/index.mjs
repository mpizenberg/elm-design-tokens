#!/usr/bin/env node

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname, basename, resolve, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Parse CLI arguments
const args = process.argv.slice(2);
let inputFile = null;
let outputFile = null;
let moduleName = null;
let enumerate = null;
const inputs = {};

for (let i = 0; i < args.length; i++) {
  if ((args[i] === "--output" || args[i] === "-o") && i + 1 < args.length) {
    outputFile = args[++i];
  } else if (
    (args[i] === "--module" || args[i] === "-m") &&
    i + 1 < args.length
  ) {
    moduleName = args[++i];
  } else if (args[i] === "--enumerate" && i + 1 < args.length) {
    enumerate = args[++i];
  } else if (args[i] === "--input" && i + 1 < args.length) {
    const kv = args[++i];
    const eq = kv.indexOf("=");
    if (eq < 1) {
      console.error(`Invalid --input format: "${kv}" (expected key=value)`);
      process.exit(1);
    }
    inputs[kv.slice(0, eq)] = kv.slice(eq + 1);
  } else if (args[i] === "--help" || args[i] === "-h") {
    printUsage();
    process.exit(0);
  } else if (!args[i].startsWith("-")) {
    inputFile = args[i];
  } else {
    console.error(`Unknown option: ${args[i]}`);
    printUsage();
    process.exit(1);
  }
}

if (!inputFile) {
  console.error("Error: No input file specified.");
  printUsage();
  process.exit(1);
}

// Derive module name from output path if not specified
if (!moduleName && outputFile) {
  moduleName = deriveModuleName(outputFile);
}
if (!moduleName) {
  moduleName = "Tokens";
}

// Determine mode based on file extension
const isResolver = inputFile.endsWith(".resolver.json");
let flags;

if (isResolver) {
  flags = processResolver(inputFile, moduleName, inputs, enumerate);
} else {
  flags = processTokenFile(inputFile, moduleName);
}

// Load the compiled Elm worker.
// Elm compiles to an IIFE that assigns to `this.Elm`, which fails in ESM
// (where `this` is undefined). We load the script via vm.runInNewContext
// with a proper global scope.
import { createContext, runInNewContext } from "vm";
const workerSource = readFileSync(resolve(__dirname, "worker.js"), "utf-8");
const context = createContext({
  setTimeout,
  setInterval,
  clearTimeout,
  clearInterval,
});
runInNewContext(workerSource, context);
const { Elm } = context;
const app = Elm.Main.init({ flags });

app.ports.output.subscribe((content) => {
  if (outputFile) {
    mkdirSync(dirname(resolve(outputFile)), { recursive: true });
    writeFileSync(outputFile, content);
    console.error(`Generated ${outputFile}`);
  } else {
    process.stdout.write(content);
  }
  process.exit(0);
});

app.ports.error.subscribe((msg) => {
  console.error(msg);
  process.exit(1);
});

// --- Token file mode (existing) ---

function processTokenFile(filePath, modName) {
  const json = readJsonFile(filePath);
  return { json, moduleName: modName };
}

// --- Resolver mode ---

function processResolver(filePath, modName, inputValues, enumerateModifier) {
  const resolverDir = dirname(resolve(filePath));
  const resolver = readJsonFile(filePath);

  if (resolver.version !== "2025.10") {
    console.error(
      `Unsupported resolver version: ${resolver.version} (expected "2025.10")`
    );
    process.exit(1);
  }

  if (!Array.isArray(resolver.resolutionOrder)) {
    console.error("Resolver must have a resolutionOrder array");
    process.exit(1);
  }

  // Resolve $ref in sets — map set name → sources (array of JSON objects)
  const sets = {};
  for (const [name, set] of Object.entries(resolver.sets || {})) {
    sets[name] = (set.sources || []).map((src) =>
      resolveRef(src, resolverDir, resolver)
    );
  }

  // Resolve $ref in modifiers — map modifier name → { contexts, default }
  const modifiers = {};
  for (const [name, mod] of Object.entries(resolver.modifiers || {})) {
    const contexts = {};
    for (const [ctxName, sources] of Object.entries(mod.contexts || {})) {
      contexts[ctxName] = sources.map((src) =>
        resolveRef(src, resolverDir, resolver)
      );
    }
    modifiers[name] = { contexts, default: mod.default || null };
  }

  // Determine modifier values
  const modifierValues = {};
  for (const [name, mod] of Object.entries(modifiers)) {
    if (name === enumerateModifier) continue;
    const value = inputValues[name] || mod.default;
    if (!value) {
      console.error(
        `No value for modifier "${name}". Use --input ${name}=<value> or set a default.`
      );
      process.exit(1);
    }
    if (!mod.contexts[value]) {
      console.error(
        `Unknown context "${value}" for modifier "${name}". Available: ${Object.keys(mod.contexts).join(", ")}`
      );
      process.exit(1);
    }
    modifierValues[name] = value;
  }

  if (enumerateModifier) {
    // Theme mode: fan out the enumerated modifier
    const mod = modifiers[enumerateModifier];
    if (!mod) {
      console.error(
        `Unknown modifier "${enumerateModifier}". Available: ${Object.keys(modifiers).join(", ")}`
      );
      process.exit(1);
    }

    const variants = Object.keys(mod.contexts).map((ctxName) => {
      const json = buildMergedJson(
        resolver.resolutionOrder,
        sets,
        modifiers,
        { ...modifierValues, [enumerateModifier]: ctxName },
        resolver
      );
      return { name: ctxName, json };
    });

    return { variants, moduleName: modName };
  } else {
    // Single resolution mode
    const json = buildMergedJson(
      resolver.resolutionOrder,
      sets,
      modifiers,
      modifierValues,
      resolver
    );
    return { json, moduleName: modName };
  }
}

function buildMergedJson(resolutionOrder, sets, modifiers, modifierValues) {
  let result = {};
  for (const entry of resolutionOrder) {
    const ref = entry["$ref"];
    if (!ref) continue;

    let sources;
    if (ref.startsWith("#/sets/")) {
      const setName = ref.slice("#/sets/".length);
      sources = sets[setName] || [];
    } else if (ref.startsWith("#/modifiers/")) {
      const modName = ref.slice("#/modifiers/".length);
      const ctxName = modifierValues[modName];
      if (!ctxName || !modifiers[modName]) continue;
      sources = modifiers[modName].contexts[ctxName] || [];
    } else {
      continue;
    }

    for (const src of sources) {
      result = deepMerge(result, src);
    }
  }
  return result;
}

function resolveRef(source, baseDir, resolver) {
  const ref = source["$ref"];
  if (!ref) return source;

  if (ref.startsWith("#/")) {
    // Internal ref — look up in resolver
    const parts = ref.slice(2).split("/");
    let obj = resolver;
    for (const p of parts) {
      obj = obj?.[p];
    }
    return obj || {};
  }

  // External file ref
  return readJsonFile(join(baseDir, ref));
}

function deepMerge(base, override) {
  const result = { ...base };
  for (const [key, val] of Object.entries(override)) {
    if (isPlainObject(result[key]) && isPlainObject(val)) {
      result[key] = deepMerge(result[key], val);
    } else {
      result[key] = val;
    }
  }
  return result;
}

function isPlainObject(val) {
  return val !== null && typeof val === "object" && !Array.isArray(val);
}

// --- Helpers ---

function readJsonFile(filePath) {
  let content;
  try {
    content = readFileSync(filePath, "utf-8");
  } catch (err) {
    console.error(`Error reading ${filePath}: ${err.message}`);
    process.exit(1);
  }
  try {
    return JSON.parse(content);
  } catch (err) {
    console.error(`Error parsing JSON from ${filePath}: ${err.message}`);
    process.exit(1);
  }
}

function deriveModuleName(filePath) {
  // Extract module name from path like "src/Tokens.elm" → "Tokens"
  // or "src/Design/Tokens.elm" → "Design.Tokens"
  const parts = filePath.replace(/\.elm$/, "").split("/");
  // Find "src" directory and take everything after it
  const srcIndex = parts.lastIndexOf("src");
  const relevantParts = srcIndex >= 0 ? parts.slice(srcIndex + 1) : parts;
  return relevantParts
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join(".");
}

function printUsage() {
  console.error(`
Usage: elm-design-tokens [options] <input-file>

Input file: .tokens.json (constants mode) or .resolver.json (theme mode)

Options:
  --output, -o <path>       Output .elm file path (default: stdout)
  --module, -m <name>       Elm module name (default: derived from output path, or "Tokens")
  --input <key=value>       Set modifier value (repeatable)
  --enumerate <modifier>    Fan out modifier as Theme variants
  -h, --help                Show this help message

Examples:
  elm-design-tokens --output src/Tokens.elm tokens.json
  elm-design-tokens tokens.resolver.json --enumerate theme -m Tokens
  elm-design-tokens tokens.resolver.json --input theme=dark -m Tokens
`);
}
