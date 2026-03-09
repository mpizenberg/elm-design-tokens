module DesignTokens.Gradient exposing
    ( Gradient, GradientStop
    , decoder, encode
    , toCssString
    )

{-| DTCG Gradient token type.

A gradient is a list of color stops, each with a color and a position (0 to 1).
The DTCG spec does not specify gradient direction or type (linear, radial, etc.),
so `toCssString` outputs only the stops portion.

@docs Gradient, GradientStop
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Color as Color exposing (Color)
import DesignTokens.Internal.CssFormat as CssFormat
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A gradient as a list of color stops.
-}
type alias Gradient =
    List GradientStop


{-| A single gradient stop with a color and a position (0 to 1).
-}
type alias GradientStop =
    { color : Color
    , position : Float
    }


{-| Decode a DTCG gradient value.

Expects a JSON array of stop objects:

    -- [{ "color": {...}, "position": 0 }, { "color": {...}, "position": 1 }]



-}
decoder : Decoder Gradient
decoder =
    Decode.list stopDecoder


stopDecoder : Decoder GradientStop
stopDecoder =
    Decode.map2 GradientStop
        (Decode.field "color" Color.decoder)
        (Decode.field "position" Decode.float)


{-| Encode a gradient to DTCG JSON.
-}
encode : Gradient -> Encode.Value
encode gradient =
    Encode.list encodeStop gradient


encodeStop : GradientStop -> Encode.Value
encodeStop stop =
    Encode.object
        [ ( "color", Color.encode stop.color )
        , ( "position", Encode.float stop.position )
        ]


{-| Convert gradient stops to a CSS string.

Outputs a comma-separated list of color stops suitable for use
inside any CSS gradient function:

    toCssString [ { color = Color.srgb 1 0 0, position = 0 }, { color = Color.srgb 0 0 1, position = 1 } ]
        == "color(srgb 1 0 0) 0%, color(srgb 0 0 1) 100%"

-}
toCssString : Gradient -> String
toCssString gradient =
    gradient
        |> List.map
            (\stop ->
                Color.toCssString stop.color
                    ++ " "
                    ++ CssFormat.formatFloat (stop.position * 100)
                    ++ "%"
            )
        |> String.join ", "
