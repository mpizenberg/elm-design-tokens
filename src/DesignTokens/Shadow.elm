module DesignTokens.Shadow exposing
    ( Shadow
    , decoder, encode
    , toCssString
    )

{-| DTCG Shadow token type.

A shadow combines a color with offset, blur, and spread dimensions.

@docs Shadow
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Color as Color exposing (Color)
import DesignTokens.Dimension as Dimension exposing (Dimension)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A shadow value.
-}
type alias Shadow =
    { color : Color
    , offsetX : Dimension
    , offsetY : Dimension
    , blur : Dimension
    , spread : Dimension
    }


{-| Decode a DTCG shadow value.
-}
decoder : Decoder Shadow
decoder =
    Decode.map5 Shadow
        (Decode.field "color" Color.decoder)
        (Decode.field "offsetX" Dimension.decoder)
        (Decode.field "offsetY" Dimension.decoder)
        (Decode.field "blur" Dimension.decoder)
        (Decode.field "spread" Dimension.decoder)


{-| Encode a shadow to DTCG JSON.
-}
encode : Shadow -> Encode.Value
encode shadow =
    Encode.object
        [ ( "color", Color.encode shadow.color )
        , ( "offsetX", Dimension.encode shadow.offsetX )
        , ( "offsetY", Dimension.encode shadow.offsetY )
        , ( "blur", Dimension.encode shadow.blur )
        , ( "spread", Dimension.encode shadow.spread )
        ]


{-| Convert a shadow to a CSS `box-shadow` value string.

    toCssString { color = Color.srgb 0 0 0, offsetX = Dimension.px 2, offsetY = Dimension.px 4, blur = Dimension.px 8, spread = Dimension.px 0 }
        == "2px 4px 8px 0px color(srgb 0 0 0)"

-}
toCssString : Shadow -> String
toCssString shadow =
    Dimension.toCssString shadow.offsetX
        ++ " "
        ++ Dimension.toCssString shadow.offsetY
        ++ " "
        ++ Dimension.toCssString shadow.blur
        ++ " "
        ++ Dimension.toCssString shadow.spread
        ++ " "
        ++ Color.toCssString shadow.color
