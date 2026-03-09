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
- **Code generation uses [elm-codegen][elm-codegen].**
  Rather than writing our own Elm AST → source pipeline,
  we use `mdgriffith/elm-codegen`, which provides a type-safe Elm API for
  generating Elm code with automatic import management and type inference.

[elm-codegen]: https://github.com/mdgriffith/elm-codegen

## Architecture Overview

The project is split into two components:

```
                      ┌─────────────────────────┐
                      │   .tokens.json files     │
                      │   (DTCG 2025.10 format)  │
                      └────────────┬──────────────┘
                                   │
                      ┌────────────▼──────────────┐
                      │      CLI / Codegen         │
                      │  (Node + elm-codegen)       │
                      │                            │
                      │  1. Parse DTCG JSON        │
                      │  2. Resolve aliases/$extends│
                      │  3. Generate Elm modules   │
                      └────────────┬──────────────┘
                                   │
                      ┌────────────▼──────────────┐
                      │   Generated Elm Modules    │
                      │                            │
                      │  - Theme type              │
                      │  - Token constants          │
                      │  - Accessor functions       │
                      └────────────┬──────────────┘
                                   │ imports
                      ┌────────────▼──────────────┐
                      │   elm-design-tokens        │
                      │   (published Elm package)  │
                      │                            │
                      │  - Core types (Color, etc.)│
                      │  - Conversion helpers       │
                      │  - JSON decoders            │
                      └───────────────────────────┘
```

### Component 1: Elm Package (`elm-design-tokens`)

A published Elm package providing core types and utilities.
This is useful on its own (for runtime parsing)
and is imported by the generated code.

#### Module Structure

```
DesignTokens
├── Color          -- Color type, color space support (sRGB, Display P3, OKLCh)
├── Dimension      -- Dimension type (px, rem)
├── FontFamily     -- Font family (single or stack)
├── FontWeight     -- Font weight (numeric or named)
├── Duration       -- Duration type (ms, s)
├── CubicBezier    -- Cubic bézier curves for easing
├── Typography     -- Composite: font family + size + weight + line height + ...
├── Shadow         -- Composite: color + offsets + blur + spread
├── Border         -- Composite: width + style + color
├── StrokeStyle    -- Stroke style (simple string or dash pattern)
├── Gradient       -- Gradient stops (position + color pairs)
├── Transition     -- Composite: duration + delay + timing function
└── Decode         -- JSON decoders for all types (DTCG format)
```

Each module exposes:

- **The type itself** — e.g., `Color`, `Dimension`
- **Constructors / helpers** — e.g., `Color.srgb 0.2 0.4 0.8`, `Dimension.px 16`
- **Conversion functions** — e.g., `Color.toCssString`, `Dimension.toCssString`

#### Design Principles for Types

- **Types are concrete, not opaque** — record aliases and union types that users
  can pattern match on. Design tokens are data; there's no invariant to protect.
- **Minimal dependencies** — the core package depends only on `elm/core` and `elm/json`.
- **Ecosystem bridges are separate** — `toCssString` covers the common case.
  Dedicated conversion packages (e.g., `elm-design-tokens-css`,
  `elm-design-tokens-ui`) can be added later if needed.

### Component 2: CLI Code Generator

A Node CLI tool powered by [elm-codegen][elm-codegen].
It reads `.tokens.json` files and produces Elm modules.

#### How elm-codegen Works

[elm-codegen][elm-codegen] is both an Elm package and a CLI.
You write your code generator as an Elm program using the `Elm.*` API:

```elm
-- codegen/Generate.elm
Elm.declaration "primaryColor"
    (Elm.apply
        (Elm.value
            { importFrom = [ "DesignTokens", "Color" ]
            , name = "srgb"
            , annotation = Nothing
            }
        )
        [ Elm.float 0.2, Elm.float 0.4, Elm.float 0.8 ]
    )
```

elm-codegen then runs this program and writes the resulting `.elm` files.
Imports and type annotations are computed automatically.

#### Generation Pipeline

```
.tokens.json
    │
    ▼
Parse JSON (Elm JSON decoder)
    │
    ▼
Build token tree (groups, tokens, aliases)
    │
    ▼
Resolve aliases and $extends (topological sort, cycle detection)
    │
    ▼
Flatten to resolved token list: List (Path, ResolvedToken)
    │
    ▼
Generate Elm declarations via elm-codegen API
    │
    ▼
Output .elm files
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

The generator produces:

```elm
module Tokens exposing (..)

import DesignTokens.Color as Color exposing (Color)
import DesignTokens.Dimension as Dimension exposing (Dimension)

colorsPrimary : Color
colorsPrimary =
    Color.srgb 0.2 0.4 0.8

colorsSecondary : Color
colorsSecondary =
    colorsPrimary

spacingSmall : Dimension
spacingSmall =
    Dimension.px 8

spacingMedium : Dimension
spacingMedium =
    Dimension.px 16
```

#### Theming Support

When a token file uses `$extends` or the CLI detects multiple token sets
(e.g., `light.tokens.json` and `dark.tokens.json` sharing the same structure),
the generator produces a `Theme` record:

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
# Generate Elm modules from token files
npx elm-design-tokens --output src/Tokens.elm tokens/
```

### Use in Elm

```elm
import Tokens exposing (Theme, light, dark)
import DesignTokens.Color as Color

view : Theme -> Html msg
view theme =
    div [ style "color" (Color.toCssString theme.colorsPrimary) ]
        [ text "Themed content" ]
```

### Integrate in Build

Add to your build script or npm scripts:

```json
{
  "scripts": {
    "codegen": "elm-design-tokens --output src/Tokens.elm tokens/",
    "build": "npm run codegen && elm make src/Main.elm"
  }
}
```

## Roadmap

1. **Phase 1 — Core types package**: Implement all DTCG token types as Elm modules
   with constructors, `toCssString` helpers, and JSON decoders.
2. **Phase 2 — DTCG parser + resolver**: Parse `.tokens.json` into a token tree,
   resolve aliases, `$extends`, and group inheritance.
3. **Phase 3 — Code generator**: elm-codegen based CLI that reads DTCG files
   and emits typed Elm modules (constants and/or `Theme` records).
4. **Phase 4 — Ecosystem bridges**: Optional packages for `elm-css` and `elm-ui`
   integration.
