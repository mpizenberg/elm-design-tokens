module DesignTokens.CubicBezier exposing
    ( CubicBezier
    , decoder, encode
    , toCssString
    )

{-| DTCG Cubic Bézier token type.

Represents a cubic bézier easing curve with two control points.
Per the DTCG spec, `p1x` and `p2x` must be in the range [0, 1],
while `p1y` and `p2y` are unconstrained.

Note: The decoder validates these constraints, but since the type
is a record alias, values constructed directly are not validated.

@docs CubicBezier
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Internal.CssFormat as CssFormat
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A cubic bézier curve defined by two control points.
-}
type alias CubicBezier =
    { p1x : Float
    , p1y : Float
    , p2x : Float
    , p2y : Float
    }


{-| Decode a DTCG cubic bézier value.

Expects a JSON array of exactly 4 numbers: `[p1x, p1y, p2x, p2y]`.
Fails if `p1x` or `p2x` is outside the range [0, 1].

-}
decoder : Decoder CubicBezier
decoder =
    Decode.list Decode.float
        |> Decode.andThen
            (\floats ->
                case floats of
                    [ p1x, p1y, p2x, p2y ] ->
                        if p1x < 0 || p1x > 1 then
                            Decode.fail ("p1x must be between 0 and 1, got " ++ String.fromFloat p1x)

                        else if p2x < 0 || p2x > 1 then
                            Decode.fail ("p2x must be between 0 and 1, got " ++ String.fromFloat p2x)

                        else
                            Decode.succeed (CubicBezier p1x p1y p2x p2y)

                    _ ->
                        Decode.fail ("Expected array of 4 numbers, got " ++ String.fromInt (List.length floats))
            )


{-| Encode a cubic bézier to DTCG JSON.
-}
encode : CubicBezier -> Encode.Value
encode cb =
    Encode.list Encode.float [ cb.p1x, cb.p1y, cb.p2x, cb.p2y ]


{-| Convert a cubic bézier to a CSS string.

    toCssString { p1x = 0.5, p1y = 0, p2x = 1, p2y = 1 }
        == "cubic-bezier(0.5, 0, 1, 1)"

-}
toCssString : CubicBezier -> String
toCssString cb =
    "cubic-bezier("
        ++ CssFormat.formatFloat cb.p1x
        ++ ", "
        ++ CssFormat.formatFloat cb.p1y
        ++ ", "
        ++ CssFormat.formatFloat cb.p2x
        ++ ", "
        ++ CssFormat.formatFloat cb.p2y
        ++ ")"
