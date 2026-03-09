#!/usr/bin/env node

import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname, basename, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Parse CLI arguments
const args = process.argv.slice(2);
let inputFile = null;
let outputFile = null;
let moduleName = null;

for (let i = 0; i < args.length; i++) {
  if ((args[i] === "--output" || args[i] === "-o") && i + 1 < args.length) {
    outputFile = args[++i];
  } else if (
    (args[i] === "--module" || args[i] === "-m") &&
    i + 1 < args.length
  ) {
    moduleName = args[++i];
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

// Read input file
let jsonContent;
try {
  jsonContent = readFileSync(inputFile, "utf-8");
} catch (err) {
  console.error(`Error reading ${inputFile}: ${err.message}`);
  process.exit(1);
}

let json;
try {
  json = JSON.parse(jsonContent);
} catch (err) {
  console.error(`Error parsing JSON from ${inputFile}: ${err.message}`);
  process.exit(1);
}

// Load the compiled Elm worker.
// Elm compiles to an IIFE that assigns to `this.Elm`, which fails in ESM
// (where `this` is undefined). We load the script via vm.runInNewContext
// with a proper global scope.
import { readFileSync as readFile } from "fs";
import { createContext, runInNewContext } from "vm";
const workerSource = readFile(resolve(__dirname, "worker.js"), "utf-8");
const context = createContext({ setTimeout, setInterval, clearTimeout, clearInterval });
runInNewContext(workerSource, context);
const { Elm } = context;
const app = Elm.Main.init({
  flags: { json, moduleName },
});

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

Options:
  --output, -o <path>   Output .elm file path (default: stdout)
  --module, -m <name>   Elm module name (default: derived from output path, or "Tokens")
  -h, --help            Show this help message

Example:
  elm-design-tokens --output src/Tokens.elm tokens.json
`);
}
