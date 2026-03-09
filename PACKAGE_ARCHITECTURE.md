# Package Architecture

This document describes the architecture of the `elm-design-tokens` project,
a hybrid Elm package + CLI tool for working with
[DTCG Design Tokens][dtcg-spec] in Elm applications.

[dtcg-spec]: https://www.designtokens.org/TR/drafts/format/

## Goals

- **Type-safe design tokens in Elm** — colors, dimensions, typography, shadows, etc.
  represented as proper Elm types, not stringly-typed dictionaries.
- **DTCG spec compliance** — parse `.tokens.json` files following the 2025.10 specification.
- **Compile-time safety** — generate Elm modules from token files so that
  renamed or removed tokens cause compiler errors, not runtime failures.
- **Runtime theming** — support theme switching (light/dark, multi-brand)
  without sacrificing type safety.
- **Elm ecosystem integration** — provide helpers to convert tokens to
  `elm-css`, `elm-ui`, or plain HTML/CSS values.

## Inspiration: travelm-agency

The architecture is inspired by [travelm-agency][travelm], an Elm i18n solution
that uses the same hybrid approach: a CLI code generator + generated Elm modules.

[travelm]: https://github.com/anmolitor/travelm-agency

Key ideas borrowed from travelm-agency:

| Concept | travelm-agency | elm-design-tokens |
|---|---|---|
| Input files | `.json`, `.properties`, `.ftl` | `.tokens.json` (DTCG format) |
| Switching type | `Language` union type | `Theme` union type |
| State holder | Opaque `I18n` type | `Theme` record with typed fields |
| Typed accessors | `greeting : I18n -> String` | `primaryColor : Theme -> Color` |
| Inline mode | Translations embedded in Elm | Tokens as Elm constants |
| Dynamic mode | Load translations via HTTP | Load token sets at runtime |

Where we diverge from travelm-agency:

- **We publish an Elm types package.**
  Unlike i18n (where output is `String` / `Html msg`), design tokens have rich types
  (`Color`, `Dimension`, `Typography`, `Shadow`, ...) that users need to manipulate,
  convert, and compose. These types live in a standalone Elm package.
- **Code generation uses [elm-syntax-dsl][elm-syntax-dsl].**
  Rather than writing our own Elm AST → source pipeline, we use
  `the-sett/elm-syntax-dsl` (the same library used by travelm-agency),
  which provides a type-safe DSL for constructing Elm syntax trees and a
  pretty printer that outputs elm-format compatible source code.

[elm-syntax-dsl]: https://github.com/the-sett/elm-syntax-dsl

## Architecture Overview

The project is split into two components:

```
                      ┌─────────────────────────┐
                      │   .tokens.json files     │
                      │   (DTCG 2025.10 format)  │
                      └────────────┬──────────────┘
                                   │
                      ┌────────────▼──────────────┐
                      │   elm-design-tokens        │
                      │   (published Elm package)  │
                      │                            │
                      │  1. Core types (Color, ...) │
                      │  2. Parse DTCG JSON        │
                      │  3. Resolve aliases/$type  │
                      └────────────┬──────────────┘
                                   │ used by
                      ┌────────────▼──────────────┐
                      │   CLI (Node + elm-syntax-  │
                      │   dsl, published to npm)   │
                      │                            │
                      │  1. Read .tokens.json      │
                      │  2. Parse + resolve (Elm)  │
                      │  3. Build AST (CodeGen)    │
                      │  4. Pretty-print to source │
                      └────────────┬──────────────┘
                                   │
                      ┌────────────▼──────────────┐
                      │   Generated Elm Modules    │
                      │                            │
                      │  - Token constants          │
                      │  - (Theme records — future) │
                      └───────────────────────────┘
```

### Component 1: Elm Package (`elm-design-tokens`)

A published Elm package providing core types and utilities.
This is useful on its own (for runtime parsing)
and is imported by the generated code.

#### Module Structure

```
DesignTokens
│
│── Core token types (Phase 1)
├── Color          -- Color type, 14 CSS color spaces
├── Dimension      -- Dimension type (px, rem)
├── FontFamily     -- Font family (opaque, non-empty)
├── FontWeight     -- Font weight (numeric or named, 11 variants)
├── Duration       -- Duration type (ms, s)
├── CubicBezier    -- Cubic bézier curves for easing
├── Shadow         -- Composite: color + offsets + blur + spread
├── Border         -- Composite: width + style + color
├── StrokeStyle    -- Stroke style (simple string or dash pattern)
├── Gradient       -- Gradient stops (position + color pairs)
├── Typography     -- Composite: font family + size + weight + line height + ...
├── Transition     -- Composite: duration + delay + timing function
│
│── DTCG file parser (Phase 2)
├── Token          -- TokenValue union (15 variants), ResolvedToken, TokenMeta
├── TokenTree      -- Parse raw DTCG JSON → unresolved tree
├── TokenTree
│   └── Resolve    -- Type inheritance + alias resolution + cycle detection
│
└── Internal
    └── CssFormat  -- Shared float formatting (not exposed)
```

Each core type module exposes:

- **The type itself** — e.g., `Color`, `Dimension`
- **Constructors / helpers** — e.g., `Color.srgb 0.2 0.4 0.8`, `Dimension.px 16`
- **JSON codecs** — `decoder` and `encode` for the DTCG value format
- **CSS output** — `toCssString` for CSS string representation

The parser modules expose:

- **`Token`** — `TokenValue` union wrapping all 15 DTCG types (12 rich types +
  number/string/boolean), with type-dispatching decoder, encoder, and CSS output
- **`TokenTree`** — `fromJson` to parse raw DTCG JSON into an unresolved tree
  of groups and tokens, with alias detection and name validation
- **`TokenTree.Resolve`** — `resolve` to flatten the tree with `$type` inheritance,
  decode literal values, resolve alias chains, and detect circular references.
  Each `ResolvedToken` tracks its alias target (`aliasOf : Maybe Path`) so
  code generation can emit references instead of duplicated values

#### Design Principles

- **Types are concrete, not opaque** — record aliases and union types that users
  can pattern match on. Exception: `FontFamily` is opaque to enforce non-empty.
- **Minimal dependencies** — the package depends only on `elm/core` and `elm/json`.
- **Validation at decode boundary** — decoders enforce constraints (e.g., cubic
  bézier p1x/p2x in [0,1]); users can construct values directly without validation.
- **Error accumulation** — the parser and resolver report all errors at once,
  not fail-fast.
- **Deferred decoding** — literal token values are stored as raw JSON until
  resolution, when the effective `$type` (after group inheritance) is known.
- **Ecosystem bridges are separate** — `toCssString` covers the common case.
  Dedicated conversion packages (e.g., `elm-design-tokens-css`,
  `elm-design-tokens-ui`) can be added later if needed.

### Component 2: CLI Code Generator

A Node CLI tool that reads `.tokens.json` files and produces typed Elm modules.
The generation logic is written in Elm using [elm-syntax-dsl][elm-syntax-dsl]
and compiled to JavaScript via `elm make`. A thin Node.js wrapper handles
file I/O and CLI argument parsing.

#### CLI Module Structure

```
cli/
├── src/
│   ├── Main.elm              -- Platform.worker: flags → port output
│   ├── Generate.elm          -- List ResolvedToken → Elm.CodeGen.File → String
│   └── Generate/
│       ├── Expression.elm    -- TokenValue → Elm.CodeGen.Expression (all 15 types)
│       ├── Naming.elm        -- Token path → camelCase Elm identifier
│       └── Imports.elm       -- Collect required imports from token types
├── tests/
│   └── Generate/
│       ├── ExpressionTest.elm
│       └── NamingTest.elm
├── elm.json                  -- Application project (deps: elm-syntax-dsl + ../src)
└── index.mjs                 -- Node CLI entry point
```

The CLI is packaged in `package.json` with a `"bin"` field, so users invoke it
via `npx elm-design-tokens`. The compiled Elm worker (`worker.js`) is built
with `pnpm build:cli` and auto-built before npm publish via `prepublishOnly`.

#### How elm-syntax-dsl Works

[elm-syntax-dsl][elm-syntax-dsl] provides two modules:

- **`Elm.CodeGen`** — a DSL for constructing Elm AST nodes (expressions,
  declarations, type annotations, imports, modules)
- **`Elm.Pretty`** — a pretty printer that renders the AST to elm-format
  compatible source code

Example from the generator:

```elm
import Elm.CodeGen as CG
import Elm.Pretty

-- Generates: colorsPrimary : Color
--            colorsPrimary = Color.srgb 0.2 0.4 0.8
CG.valDecl Nothing
    (Just (CG.typed "Color" []))
    "colorsPrimary"
    (CG.apply
        [ CG.fqVal [ "Color" ] "srgb"
        , CG.float 0.2
        , CG.float 0.4
        , CG.float 0.8
        ]
    )
```

#### Generation Pipeline

```
.tokens.json
    │
    ▼
TokenTree.fromJson          ── Parse JSON into unresolved tree
    │                           (groups, tokens, alias detection)
    ▼
TokenTree.Resolve.resolve   ── Inherit $type from groups
    │                           Decode literal values
    │                           Resolve alias chains (cycle detection)
    ▼
List ResolvedToken          ── Flat list with typed values + alias tracking
    │
    ▼
Generate.elm                ── Build Elm.CodeGen.File (declarations + imports)
    │                           Alias tokens → reference other constants
    │                           Literal tokens → constructor expressions
    ▼
Elm.Pretty.pretty           ── Render AST to elm-format compatible source
    │
    ▼
Output .elm file
```

#### What Gets Generated

Given a token file like:

```json
{
  "colors": {
    "$type": "color",
    "primary": {
      "$value": { "colorSpace": "srgb", "components": [0.2, 0.4, 0.8] }
    },
    "secondary": {
      "$value": "{colors.primary}"
    }
  },
  "spacing": {
    "$type": "dimension",
    "small": { "$value": { "value": 8, "unit": "px" } },
    "medium": { "$value": { "value": 16, "unit": "px" } }
  }
}
```

Running `npx elm-design-tokens --output src/Tokens.elm --module Tokens tokens.json`
produces:

```elm
module Tokens exposing (colorsPrimary, colorsSecondary, spacingMedium, spacingSmall)

import DesignTokens.Color as Color exposing (Color)
import DesignTokens.Dimension as Dimension exposing (Dimension)


colorsPrimary : Color
colorsPrimary =
    Color.srgb 0.2 0.4 0.8


colorsSecondary : Color
colorsSecondary =
    colorsPrimary


spacingMedium : Dimension
spacingMedium =
    Dimension.px 16


spacingSmall : Dimension
spacingSmall =
    Dimension.px 8
```

Key features of the generated code:

- **Explicit exposing list** — each constant is named in the module header
- **Minimal imports** — only the types actually used are imported
- **Alias preservation** — `colorsSecondary` references `colorsPrimary` directly,
  not a duplicated literal value
- **All 15 DTCG types supported** — color, dimension, fontFamily, fontWeight,
  duration, cubicBezier, number, string, boolean, shadow, border, strokeStyle,
  gradient, typography, transition

#### Theming Support (Phase 3b — planned)

When a token file uses `$extends` or the CLI detects multiple token sets
(e.g., `light.tokens.json` and `dark.tokens.json` sharing the same structure),
the generator will produce a `Theme` record:

```elm
module Tokens exposing (..)

import DesignTokens.Color exposing (Color)
import DesignTokens.Dimension exposing (Dimension)

type alias Theme =
    { colorsPrimary : Color
    , colorsSecondary : Color
    , spacingSmall : Dimension
    , spacingMedium : Dimension
    }

light : Theme
light =
    { colorsPrimary = Color.srgb 0.2 0.4 0.8
    , colorsSecondary = Color.srgb 0.2 0.4 0.8
    , spacingSmall = Dimension.px 8
    , spacingMedium = Dimension.px 16
    }

dark : Theme
dark =
    { colorsPrimary = Color.srgb 0.8 0.8 1.0
    , colorsSecondary = Color.srgb 0.6 0.6 0.9
    , spacingSmall = Dimension.px 8
    , spacingMedium = Dimension.px 16
    }
```

Users then thread `Theme` through their application:

```elm
view : Theme -> Model -> Html Msg
view theme model =
    div
        [ style "color" (Color.toCssString theme.colorsPrimary)
        , style "padding" (Dimension.toCssString theme.spacingMedium)
        ]
        [ text "Hello" ]
```

## User Workflow

### Installation

```bash
# Install the CLI
npm install --save-dev elm-design-tokens

# Add the Elm package
elm install mpizenberg/elm-design-tokens
```

### Generate Code

```bash
# Generate Elm module from a token file
npx elm-design-tokens --output src/Tokens.elm --module Tokens tokens.json

# Or pipe to stdout
npx elm-design-tokens --module Tokens tokens.json
```

CLI options:

| Option | Description |
|--------|-------------|
| `--output, -o <path>` | Output `.elm` file path (default: stdout) |
| `--module, -m <name>` | Elm module name (default: derived from output path, or `Tokens`) |

### Use in Elm

```elm
import Tokens exposing (colorsPrimary, spacingSmall)
import DesignTokens.Color as Color
import DesignTokens.Dimension as Dimension

view : Html msg
view =
    div
        [ style "color" (Color.toCssString colorsPrimary)
        , style "padding" (Dimension.toCssString spacingSmall)
        ]
        [ text "Styled content" ]
```

### Integrate in Build

Add to your build script or npm scripts:

```json
{
  "scripts": {
    "codegen": "elm-design-tokens --output src/Tokens.elm --module Tokens tokens.json",
    "build": "npm run codegen && elm make src/Main.elm"
  }
}
```

## Roadmap

1. **Phase 1 — Core types package** *(done)*: All 12 DTCG token types implemented
   as Elm modules with constructors, JSON codecs, `toCssString` helpers, and tests
   (107 tests). Plus 3 primitive types (number, string, boolean) handled directly.
2. **Phase 2 — DTCG parser + resolver** *(done)*: Parse raw `.tokens.json` into an
   unresolved token tree (`TokenTree.fromJson`), then resolve `$type` inheritance
   and alias references with cycle detection (`TokenTree.Resolve.resolve`).
   Produces `List ResolvedToken` with typed values, paths, and metadata.
   72 additional tests (179 total). `$extends` stored but deferred to Phase 3b.
3. **Phase 3a — Code generator (constants)** *(done)*: CLI tool using
   `the-sett/elm-syntax-dsl` that reads a `.tokens.json` file and generates a
   typed Elm module with top-level constants. Supports all 15 DTCG types,
   preserves alias references, generates elm-format compatible output.
   Packaged in `package.json` with `bin` field for `npx elm-design-tokens`.
   `ResolvedToken` extended with `aliasOf : Maybe Path` for alias tracking.
   27 CLI tests, 3 new package tests (209 total).
4. **Phase 3b — Theming + `$extends`**: Multi-file token sets
   (e.g., `light.tokens.json` + `dark.tokens.json`) generating `Theme` record
   types + variant functions. Resolve `$extends` (group inheritance via deep merge).
5. **Phase 4 — Ecosystem bridges**: Optional packages for `elm-css` and `elm-ui`
   integration.
