module DesignTokens.Border exposing
    ( Border
    , decoder, encode
    , toCssString
    )

{-| DTCG Border token type.

A border combines a width dimension, a style string, and a color.

@docs Border
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Color as Color exposing (Color)
import DesignTokens.Dimension as Dimension exposing (Dimension)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A border value.

The `style` field is a plain string (e.g. `"solid"`, `"dashed"`)
because the DTCG spec does not enumerate valid border styles.

-}
type alias Border =
    { color : Color
    , width : Dimension
    , style : String
    }


{-| Decode a DTCG border value.
-}
decoder : Decoder Border
decoder =
    Decode.map3 Border
        (Decode.field "color" Color.decoder)
        (Decode.field "width" Dimension.decoder)
        (Decode.field "style" Decode.string)


{-| Encode a border to DTCG JSON.
-}
encode : Border -> Encode.Value
encode border =
    Encode.object
        [ ( "color", Color.encode border.color )
        , ( "width", Dimension.encode border.width )
        , ( "style", Encode.string border.style )
        ]


{-| Convert a border to a CSS `border` shorthand string.

    toCssString { color = Color.srgb 0 0 0, width = Dimension.px 1, style = "solid" }
        == "1px solid color(srgb 0 0 0)"

-}
toCssString : Border -> String
toCssString border =
    Dimension.toCssString border.width
        ++ " "
        ++ border.style
        ++ " "
        ++ Color.toCssString border.color
