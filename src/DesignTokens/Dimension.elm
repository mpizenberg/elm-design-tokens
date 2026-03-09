module DesignTokens.Dimension exposing
    ( Dimension, DimensionUnit(..)
    , px, rem
    , decoder, encode
    , toCssString
    )

{-| DTCG Dimension token type.

A dimension represents a length value with a unit.
The DTCG spec supports `px` and `rem` units.

@docs Dimension, DimensionUnit
@docs px, rem
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Internal.CssFormat as CssFormat
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A dimension value with a unit.
-}
type alias Dimension =
    { value : Float
    , unit : DimensionUnit
    }


{-| The unit of a dimension.
-}
type DimensionUnit
    = Px
    | Rem


{-| Create a pixel dimension.
-}
px : Float -> Dimension
px value =
    { value = value, unit = Px }


{-| Create a rem dimension.
-}
rem : Float -> Dimension
rem value =
    { value = value, unit = Rem }


{-| Decode a DTCG dimension value.

    -- { "value": 16, "unit": "px" }



-}
decoder : Decoder Dimension
decoder =
    Decode.map2 Dimension
        (Decode.field "value" Decode.float)
        (Decode.field "unit" unitDecoder)


unitDecoder : Decoder DimensionUnit
unitDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "px" ->
                        Decode.succeed Px

                    "rem" ->
                        Decode.succeed Rem

                    _ ->
                        Decode.fail ("Unknown dimension unit: " ++ s)
            )


{-| Encode a dimension to DTCG JSON.
-}
encode : Dimension -> Encode.Value
encode dim =
    Encode.object
        [ ( "value", Encode.float dim.value )
        , ( "unit", encodeUnit dim.unit )
        ]


encodeUnit : DimensionUnit -> Encode.Value
encodeUnit unit =
    Encode.string
        (case unit of
            Px ->
                "px"

            Rem ->
                "rem"
        )


{-| Convert a dimension to a CSS string.

    toCssString (px 16) == "16px"

    toCssString (rem 1.5) == "1.5rem"

-}
toCssString : Dimension -> String
toCssString dim =
    CssFormat.formatFloat dim.value
        ++ (case dim.unit of
                Px ->
                    "px"

                Rem ->
                    "rem"
           )
