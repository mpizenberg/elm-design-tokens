# Design Tokens Specification v1 (2025.10)

On October 28, 2025, the [W3C Design Tokens Community Group (DTCG)][dtcg] released the first stable version of the **Design Tokens Format Module** (edition 2025.10). This specification provides a production-ready, vendor-neutral JSON format for sharing design decisions across tools and platforms.

[dtcg]: https://www.w3.org/community/design-tokens/

## What Are Design Tokens?

Design tokens are the atomic design decisions of a design system — colors, spacing, typography, shadows, etc. — expressed as data. They serve as a shared language between design and engineering, enabling consistency across platforms (web, iOS, Android, Flutter) from a single source of truth.

## File Format

Design token files are JSON files (RFC 8259) with the following conventions:

- **MIME type**: `application/design-tokens+json` (fallback: `application/json`)
- **File extensions**: `.tokens` or `.tokens.json`
- **Reserved prefix**: All specification-defined properties use the `$` prefix

## Token Structure

Every token is a JSON object with at minimum a `$value` property. Tokens also require a `$type`, either set explicitly or inherited from a parent group.

```json
{
  "brand-color": {
    "$type": "color",
    "$value": {
      "colorSpace": "srgb",
      "components": [0.2, 0.4, 0.8]
    },
    "$description": "Primary brand color"
  }
}
```

### Required Properties

| Property | Description |
|----------|-------------|
| `$value` | The token's value data |
| `$type` | The token type (explicit or inherited from a parent group) |

### Optional Properties

| Property | Description |
|----------|-------------|
| `$description` | Plain text explanation of the token's purpose |
| `$extensions` | Vendor-specific metadata (using reverse domain notation) |
| `$deprecated` | Boolean or string indicating deprecation |

## Token Types

### Simple Types

| Type | Value Format | Example |
|------|-------------|---------|
| `color` | Object with `colorSpace`, `components`, and optional `alpha` | `{"colorSpace": "oklch", "components": [0.65, 0.15, 250]}` |
| `dimension` | Object with `value` (number) and `unit` (`"px"` or `"rem"`) | `{"value": 16, "unit": "px"}` |
| `fontFamily` | String or array of strings | `["Helvetica", "Arial", "sans-serif"]` |
| `fontWeight` | Number (1–1000) or named string (e.g. `"bold"`) | `400` |
| `duration` | Object with `value` and `unit` (`"ms"` or `"s"`) | `{"value": 200, "unit": "ms"}` |
| `cubicBezier` | Array of 4 numbers `[P1x, P1y, P2x, P2y]` | `[0.5, 0, 1, 1]` |
| `number` | JSON number | `1.5` |
| `string` | JSON string | `"solid"` |
| `boolean` | JSON boolean | `true` |

### Composite Types

Composite types combine multiple sub-values into structured objects:

| Type | Sub-values |
|------|------------|
| `shadow` | `color`, `offsetX`, `offsetY`, `blur`, `spread` |
| `border` | `width` (dimension), `style` (string), `color` |
| `strokeStyle` | String value, or object with `dashArray` and `lineCap` |
| `gradient` | `position` (array), `color` (array) |
| `typography` | `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`, and optional `letterSpacing`, `paragraphSpacing` |
| `transition` | `duration`, optional `delay`, `timingFunction` (cubicBezier or string) |

## Groups

Any JSON object without a `$value` property is treated as a **group**. Groups organize tokens hierarchically and can carry their own `$description`, `$type`, `$extensions`, and `$deprecated` properties.

```json
{
  "colors": {
    "$type": "color",
    "primary": {
      "$value": { "colorSpace": "srgb", "components": [0, 0.4, 1] }
    },
    "secondary": {
      "$value": { "colorSpace": "srgb", "components": [1, 0.4, 0] }
    }
  }
}
```

Tokens inside a group inherit the group's `$type`, so neither `primary` nor `secondary` above needs to redeclare it.

### The `$root` Token

A group can contain a special `$root` token, allowing a group and a token to share the same name:

```json
{
  "accent": {
    "$root": { "$type": "color", "$value": { "colorSpace": "srgb", "components": [0, 0.4, 1] } },
    "light": { "$type": "color", "$value": { "colorSpace": "srgb", "components": [0.5, 0.7, 1] } }
  }
}
```

Here `accent` resolves to the `$root` value, while `accent.light` resolves to the variant.

## Modern Color Spaces

The spec supports all **CSS Color Module 4** color spaces including sRGB, Display P3, and OKLCh. Colors are defined with explicit `colorSpace`, `components`, and optional `alpha`:

```json
{
  "$type": "color",
  "$value": {
    "colorSpace": "oklch",
    "components": [0.65, 0.15, 250],
    "alpha": 1
  }
}
```

This enables wide-gamut color workflows matching the capabilities of contemporary design tools and displays.

## Aliases and References

### Curly Brace Syntax (Token References)

Tokens can reference other tokens using `{path.to.token}` syntax:

```json
{
  "colors": {
    "blue": { "$type": "color", "$value": { "colorSpace": "srgb", "components": [0, 0, 1] } }
  },
  "primary": {
    "$type": "color",
    "$value": "{colors.blue}"
  }
}
```

### JSON Pointer Syntax (Property-Level References)

For fine-grained access to individual sub-values, `$ref` with RFC 6901 JSON Pointer notation is supported:

```json
{
  "shade": {
    "$ref": "#/colors/blue/$value/components/0"
  }
}
```

Reference chains are resolved until an explicit value is found. Circular references are invalid.

## Group Extension and Theming (`$extends`)

The `$extends` property enables inheritance between groups, following deep merge semantics. This is the foundation for multi-brand and multi-theme support without file duplication:

```json
{
  "button": {
    "background": { "$type": "color", "$value": { "colorSpace": "srgb", "components": [0.8, 0.8, 0.8] } },
    "radius": { "$type": "dimension", "$value": { "value": 4, "unit": "px" } }
  },
  "button-primary": {
    "$extends": "{button}",
    "background": { "$type": "color", "$value": { "colorSpace": "oklch", "components": [0.5, 0.15, 265] } }
  }
}
```

`button-primary` inherits `radius` from `button` and overrides `background`.

### Token Resolvers

The specification introduces **resolvers** to manage multi-brand, multi-theme complexity. Resolvers establish a clear, consistent order for determining a token's final value across token sets, modifiers, and contexts (light/dark themes, brands, platforms) — all from a single source rather than dozens of separate files.

## Naming Constraints

- Token and group names are **case-sensitive** JSON strings
- Names **cannot** start with `$` or contain `{`, `}`, or `.`
- Tokens are referenced via dot-separated paths: `color.accent.light`

## Ecosystem and Adoption

The specification was developed by 20+ editors and contributors from organizations including Adobe, Amazon, Google, Microsoft, Meta, Figma, Salesforce, Shopify, Sketch, Framer, Penpot, and many others.

Over 10 tools currently support or are implementing the standard:

- **Design tools**: Figma, Sketch, Framer, Penpot
- **Token management**: Tokens Studio, Knapsack, Supernova, zeroheight
- **Build tools**: Style Dictionary (v4+), Terrazzo

## Resources

- [Design Tokens Community Group](https://www.w3.org/community/design-tokens/)
- [Official specification](https://www.designtokens.org/TR/drafts/format/)
- [GitHub repository](https://github.com/design-tokens/community-group)
- [Announcement blog post](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/)
- [Style Dictionary DTCG support](https://styledictionary.com/info/dtcg/)
- [zeroheight article on what's new](https://zeroheight.com/blog/whats-new-in-the-design-tokens-spec/)
