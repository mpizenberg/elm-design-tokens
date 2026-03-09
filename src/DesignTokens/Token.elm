module DesignTokens.Token exposing
    ( TokenValue(..), Deprecated(..), TokenMeta, ResolvedToken, Path
    , tokenValueDecoder, encodeTokenValue, tokenValueToCssString, tokenTypeName
    , deprecatedDecoder, encodeDeprecated, emptyMeta
    )

{-| Unified token value type and resolved token record.

This module defines `TokenValue`, a union type that wraps all DTCG token
types, and `ResolvedToken`, the output of parsing and resolving a DTCG file.

@docs TokenValue, Deprecated, TokenMeta, ResolvedToken, Path
@docs tokenValueDecoder, encodeTokenValue, tokenValueToCssString, tokenTypeName
@docs deprecatedDecoder, encodeDeprecated, emptyMeta

-}

import DesignTokens.Border as Border exposing (Border)
import DesignTokens.Color as Color exposing (Color)
import DesignTokens.CubicBezier as CubicBezier exposing (CubicBezier)
import DesignTokens.Dimension as Dimension exposing (Dimension)
import DesignTokens.Duration as Duration exposing (Duration)
import DesignTokens.FontFamily as FontFamily exposing (FontFamily)
import DesignTokens.FontWeight as FontWeight exposing (FontWeight)
import DesignTokens.Gradient as Gradient exposing (Gradient)
import DesignTokens.Shadow as Shadow exposing (Shadow)
import DesignTokens.StrokeStyle as StrokeStyle exposing (StrokeStyle)
import DesignTokens.Transition as Transition exposing (Transition)
import DesignTokens.Typography as Typography exposing (Typography)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A dot-separated token path, represented as a list of segments.
-}
type alias Path =
    List String


{-| A union type wrapping all DTCG token value types.
-}
type TokenValue
    = ColorValue Color
    | DimensionValue Dimension
    | FontFamilyValue FontFamily
    | FontWeightValue FontWeight
    | DurationValue Duration
    | CubicBezierValue CubicBezier
    | NumberValue Float
    | StringValue String
    | BooleanValue Bool
    | ShadowValue Shadow
    | BorderValue Border
    | StrokeStyleValue StrokeStyle
    | GradientValue Gradient
    | TypographyValue Typography
    | TransitionValue Transition


{-| Deprecation status: a boolean flag or a message string.
-}
type Deprecated
    = DeprecatedBool Bool
    | DeprecatedMessage String


{-| Optional metadata attached to a token.
-}
type alias TokenMeta =
    { description : Maybe String
    , extensions : Maybe Decode.Value
    , deprecated : Maybe Deprecated
    }


{-| A fully resolved token with its path, type name, value, and metadata.
-}
type alias ResolvedToken =
    { path : Path
    , typeName : String
    , value : TokenValue
    , aliasOf : Maybe Path
    , meta : TokenMeta
    }


{-| Empty metadata with all fields set to Nothing.
-}
emptyMeta : TokenMeta
emptyMeta =
    { description = Nothing
    , extensions = Nothing
    , deprecated = Nothing
    }


{-| Decode a token value given a DTCG type name string.

Returns a decoder that dispatches to the appropriate type-specific decoder.

-}
tokenValueDecoder : String -> Decoder TokenValue
tokenValueDecoder typeName =
    case typeName of
        "color" ->
            Decode.map ColorValue Color.decoder

        "dimension" ->
            Decode.map DimensionValue Dimension.decoder

        "fontFamily" ->
            Decode.map FontFamilyValue FontFamily.decoder

        "fontWeight" ->
            Decode.map FontWeightValue FontWeight.decoder

        "duration" ->
            Decode.map DurationValue Duration.decoder

        "cubicBezier" ->
            Decode.map CubicBezierValue CubicBezier.decoder

        "number" ->
            Decode.map NumberValue Decode.float

        "string" ->
            Decode.map StringValue Decode.string

        "boolean" ->
            Decode.map BooleanValue Decode.bool

        "shadow" ->
            Decode.map ShadowValue Shadow.decoder

        "border" ->
            Decode.map BorderValue Border.decoder

        "strokeStyle" ->
            Decode.map StrokeStyleValue StrokeStyle.decoder

        "gradient" ->
            Decode.map GradientValue Gradient.decoder

        "typography" ->
            Decode.map TypographyValue Typography.decoder

        "transition" ->
            Decode.map TransitionValue Transition.decoder

        _ ->
            Decode.fail ("Unknown token type: " ++ typeName)


{-| Encode a token value to JSON.
-}
encodeTokenValue : TokenValue -> Encode.Value
encodeTokenValue tokenValue =
    case tokenValue of
        ColorValue v ->
            Color.encode v

        DimensionValue v ->
            Dimension.encode v

        FontFamilyValue v ->
            FontFamily.encode v

        FontWeightValue v ->
            FontWeight.encode v

        DurationValue v ->
            Duration.encode v

        CubicBezierValue v ->
            CubicBezier.encode v

        NumberValue v ->
            Encode.float v

        StringValue v ->
            Encode.string v

        BooleanValue v ->
            Encode.bool v

        ShadowValue v ->
            Shadow.encode v

        BorderValue v ->
            Border.encode v

        StrokeStyleValue v ->
            StrokeStyle.encode v

        GradientValue v ->
            Gradient.encode v

        TypographyValue v ->
            Typography.encode v

        TransitionValue v ->
            Transition.encode v


{-| Convert a token value to its CSS string representation.
-}
tokenValueToCssString : TokenValue -> String
tokenValueToCssString tokenValue =
    case tokenValue of
        ColorValue v ->
            Color.toCssString v

        DimensionValue v ->
            Dimension.toCssString v

        FontFamilyValue v ->
            FontFamily.toCssString v

        FontWeightValue v ->
            FontWeight.toCssString v

        DurationValue v ->
            Duration.toCssString v

        CubicBezierValue v ->
            CubicBezier.toCssString v

        NumberValue v ->
            String.fromFloat v

        StringValue v ->
            v

        BooleanValue v ->
            if v then
                "true"

            else
                "false"

        ShadowValue v ->
            Shadow.toCssString v

        BorderValue v ->
            Border.toCssString v

        StrokeStyleValue v ->
            StrokeStyle.toCssString v

        GradientValue v ->
            Gradient.toCssString v

        TypographyValue v ->
            Typography.toCssString v

        TransitionValue v ->
            Transition.toCssString v


{-| Get the DTCG type name string for a token value.
-}
tokenTypeName : TokenValue -> String
tokenTypeName tokenValue =
    case tokenValue of
        ColorValue _ ->
            "color"

        DimensionValue _ ->
            "dimension"

        FontFamilyValue _ ->
            "fontFamily"

        FontWeightValue _ ->
            "fontWeight"

        DurationValue _ ->
            "duration"

        CubicBezierValue _ ->
            "cubicBezier"

        NumberValue _ ->
            "number"

        StringValue _ ->
            "string"

        BooleanValue _ ->
            "boolean"

        ShadowValue _ ->
            "shadow"

        BorderValue _ ->
            "border"

        StrokeStyleValue _ ->
            "strokeStyle"

        GradientValue _ ->
            "gradient"

        TypographyValue _ ->
            "typography"

        TransitionValue _ ->
            "transition"


{-| Decode a `$deprecated` value (boolean or string).
-}
deprecatedDecoder : Decoder Deprecated
deprecatedDecoder =
    Decode.oneOf
        [ Decode.map DeprecatedBool Decode.bool
        , Decode.map DeprecatedMessage Decode.string
        ]


{-| Encode a `Deprecated` value.
-}
encodeDeprecated : Deprecated -> Encode.Value
encodeDeprecated deprecated =
    case deprecated of
        DeprecatedBool b ->
            Encode.bool b

        DeprecatedMessage s ->
            Encode.string s
