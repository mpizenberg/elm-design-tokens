# elm-design-tokens

Type-safe [DTCG design tokens][dtcg-spec] for Elm.

An Elm package providing rich types for all 15 DTCG token types,
plus a CLI that generates typed Elm modules from `.tokens.json` and
`.resolver.json` files -- so renamed or removed tokens become compiler errors,
not runtime bugs.

[dtcg-spec]: https://www.designtokens.org/TR/drafts/format/

## Quick start

> REMARK: this is a WIP, the package is not published yet!

```bash
# Install the CLI
npm install --save-dev elm-design-tokens

# Add the Elm package
elm install mpizenberg/elm-design-tokens
```

Given a `tokens.json` file:

```json
{
  "colors": {
    "$type": "color",
    "primary": {
      "$value": { "colorSpace": "srgb", "components": [0.2, 0.4, 0.8] }
    },
    "secondary": { "$value": "{colors.primary}" }
  },
  "spacing": {
    "$type": "dimension",
    "small": { "$value": { "value": 8, "unit": "px" } },
    "medium": { "$value": { "value": 16, "unit": "px" } }
  }
}
```

Generate a typed Elm module:

```bash
npx elm-design-tokens tokens.json -o src/Tokens.elm -m Tokens
```

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

Use it in your app:

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

## Features

- **All 15 DTCG types** -- color (14 color spaces), dimension, fontFamily,
  fontWeight, duration, cubicBezier, number, string, boolean, shadow, border,
  strokeStyle, gradient, typography, transition
- **Alias preservation** -- alias tokens reference each other in generated code
  instead of duplicating values
- **`$type` inheritance** -- group-level `$type` propagates to child tokens
- **`$extends` deep merge** -- groups can extend other groups, inheriting their
  tokens with override semantics
- **Theming via DTCG Resolver Module** -- `.resolver.json` files for multi-file
  token sets with automatic `Theme` record generation
- **elm-format compatible** -- generated code passes `elm-format` out of the box
- **Compile-time safety** -- if a token is renamed or removed, your code won't compile

## Theming

For applications with multiple themes (light/dark, multi-brand), use the
[DTCG Resolver Module][resolver-spec] format.

[resolver-spec]: https://www.designtokens.org/tr/drafts/resolver/

### Set up token files

Split your tokens into shared and theme-specific files:

**`base.tokens.json`** -- shared across all themes:
```json
{
  "spacing": {
    "$type": "dimension",
    "small": { "$value": { "value": 8, "unit": "px" } },
    "medium": { "$value": { "value": 16, "unit": "px" } }
  }
}
```

**`light.tokens.json`**:
```json
{
  "colors": {
    "$type": "color",
    "background": { "$value": { "colorSpace": "srgb", "components": [1, 1, 1] } },
    "primary": { "$value": { "colorSpace": "srgb", "components": [0.2, 0.4, 0.8] } }
  }
}
```

**`dark.tokens.json`**:
```json
{
  "colors": {
    "$type": "color",
    "background": { "$value": { "colorSpace": "srgb", "components": [0.1, 0.1, 0.1] } },
    "primary": { "$value": { "colorSpace": "srgb", "components": [0.2, 0.4, 0.8] } }
  }
}
```

### Create a resolver file

**`tokens.resolver.json`**:
```json
{
  "version": "2025.10",
  "sets": {
    "foundation": { "sources": [{ "$ref": "base.tokens.json" }] }
  },
  "modifiers": {
    "theme": {
      "contexts": {
        "light": [{ "$ref": "light.tokens.json" }],
        "dark": [{ "$ref": "dark.tokens.json" }]
      },
      "default": "light"
    }
  },
  "resolutionOrder": [
    { "$ref": "#/sets/foundation" },
    { "$ref": "#/modifiers/theme" }
  ]
}
```

### Generate a themed module

```bash
npx elm-design-tokens tokens.resolver.json --enumerate theme -o src/Tokens.elm -m Tokens
```

The CLI automatically splits tokens: those identical across all themes become
top-level constants, while those that differ go into a `Theme` record:

```elm
module Tokens exposing (Theme, colorsPrimary, dark, light, spacingMedium, spacingSmall)

import DesignTokens.Color as Color exposing (Color)
import DesignTokens.Dimension as Dimension exposing (Dimension)

type alias Theme =
    { colorsBackground : Color }

light : Theme
light =
    { colorsBackground = Color.srgb 1 1 1 }

dark : Theme
dark =
    { colorsBackground = Color.srgb 0.1 0.1 0.1 }

colorsPrimary : Color
colorsPrimary =
    Color.srgb 0.2 0.4 0.8

spacingMedium : Dimension
spacingMedium =
    Dimension.px 16

spacingSmall : Dimension
spacingSmall =
    Dimension.px 8
```

`colorsPrimary` is the same in both themes, so it becomes a constant.
`colorsBackground` differs, so it's a `Theme` field.

Thread the theme through your app:

```elm
view : Theme -> Model -> Html Msg
view theme model =
    div
        [ style "background" (Color.toCssString theme.colorsBackground)
        , style "padding" (Dimension.toCssString spacingMedium)
        ]
        [ text "Hello" ]
```

You can also resolve a single theme without generating a `Theme` type:

```bash
npx elm-design-tokens tokens.resolver.json --input theme=dark -m Tokens
```

This produces flat constants, same as the normal `.tokens.json` mode.

## CLI reference

```
Usage: elm-design-tokens [options] <input-file>

Input file: .tokens.json or .resolver.json
```

| Option | Description |
|--------|-------------|
| `--output, -o <path>` | Output `.elm` file path (default: stdout) |
| `--module, -m <name>` | Elm module name (default: derived from output path, or `Tokens`) |
| `--input <key=value>` | Set modifier value (repeatable) |
| `--enumerate <modifier>` | Fan out modifier as Theme variants |
| `-h, --help` | Show help |

## Elm package API

The Elm package can also be used directly for runtime token parsing.

### Core types

Each module follows the same pattern:

```elm
import DesignTokens.Color as Color exposing (Color)

-- Construct
myColor : Color
myColor = Color.srgb 0.2 0.4 0.8

-- With alpha
myTransparent : Color
myTransparent = Color.srgb 0.2 0.4 0.8 |> Color.withAlpha 0.5

-- To CSS
Color.toCssString myColor       -- "color(srgb 0.2 0.4 0.8)"

-- JSON round-trip
Color.decoder : Decoder Color
Color.encode : Color -> Value
```

Available type modules:

| Module | Type | Constructors |
|--------|------|--------------|
| `DesignTokens.Color` | `Color` | `srgb`, `displayP3`, `oklch`, ... (14 color spaces) |
| `DesignTokens.Dimension` | `Dimension` | `px`, `rem` |
| `DesignTokens.FontFamily` | `FontFamily` | `single`, `stack` |
| `DesignTokens.FontWeight` | `FontWeight` | `Thin` .. `ExtraBlack`, `Numeric` |
| `DesignTokens.Duration` | `Duration` | `ms`, `s` |
| `DesignTokens.CubicBezier` | `CubicBezier` | Record: `{ p1x, p1y, p2x, p2y }` |
| `DesignTokens.Shadow` | `Shadow` | Record: color + offsets + blur + spread |
| `DesignTokens.Border` | `Border` | Record: color + width + style |
| `DesignTokens.StrokeStyle` | `StrokeStyle` | `StringStyle`, `DetailedStyle` |
| `DesignTokens.Gradient` | `Gradient` | List of `{ color, position }` stops |
| `DesignTokens.Typography` | `Typography` | Record: font family + size + weight + ... |
| `DesignTokens.Transition` | `Transition` | Record: duration + delay + timing |

### Parser modules

For runtime DTCG JSON parsing:

```elm
import DesignTokens.TokenTree as TokenTree
import DesignTokens.TokenTree.Resolve as Resolve

-- Parse raw JSON → unresolved tree → resolved tokens
case TokenTree.fromJson jsonValue of
    Err parseErrors -> ...
    Ok tree ->
        case Resolve.resolve tree of
            Err resolveErrors -> ...
            Ok resolvedTokens -> ...
```

## Build integration

Add code generation to your npm scripts:

```json
{
  "scripts": {
    "codegen": "elm-design-tokens tokens.json -o src/Tokens.elm -m Tokens",
    "build": "npm run codegen && elm make src/Main.elm"
  }
}
```

## Spec compliance

> REMARK: Spec compliance is claimed by Claude.
> I have not double-checked it, and will only use what I need, when I need it.

This package implements:

- [DTCG Format Module 2025.10][dtcg-spec] -- token types, `$type` inheritance,
  alias resolution (`{path.to.token}`), `$extends` deep merge, `$description`,
  `$deprecated`, `$extensions`
- [DTCG Resolver Module 2025.10][resolver-spec] -- `.resolver.json` with sets,
  modifiers, resolution order, and `$ref` resolution

## License

BSD-3-Clause
