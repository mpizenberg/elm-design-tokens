module DesignTokens.Typography exposing
    ( Typography
    , decoder, encode
    , toCssString
    )

{-| DTCG Typography token type.

A composite type combining font family, size, weight, line height,
and optional letter/paragraph spacing.

@docs Typography
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Dimension as Dimension exposing (Dimension)
import DesignTokens.FontFamily as FontFamily exposing (FontFamily)
import DesignTokens.FontWeight as FontWeight exposing (FontWeight)
import DesignTokens.Internal.CssFormat as CssFormat
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A typography value.
-}
type alias Typography =
    { fontFamily : FontFamily
    , fontSize : Dimension
    , fontWeight : FontWeight
    , lineHeight : Float
    , letterSpacing : Maybe Dimension
    , paragraphSpacing : Maybe Dimension
    }


{-| Decode a DTCG typography value.
-}
decoder : Decoder Typography
decoder =
    Decode.map6 Typography
        (Decode.field "fontFamily" FontFamily.decoder)
        (Decode.field "fontSize" Dimension.decoder)
        (Decode.field "fontWeight" FontWeight.decoder)
        (Decode.field "lineHeight" Decode.float)
        (Decode.maybe (Decode.field "letterSpacing" Dimension.decoder))
        (Decode.maybe (Decode.field "paragraphSpacing" Dimension.decoder))


{-| Encode a typography to DTCG JSON.
-}
encode : Typography -> Encode.Value
encode typo =
    Encode.object
        ([ ( "fontFamily", FontFamily.encode typo.fontFamily )
         , ( "fontSize", Dimension.encode typo.fontSize )
         , ( "fontWeight", FontWeight.encode typo.fontWeight )
         , ( "lineHeight", Encode.float typo.lineHeight )
         ]
            ++ encodeMaybe "letterSpacing" Dimension.encode typo.letterSpacing
            ++ encodeMaybe "paragraphSpacing" Dimension.encode typo.paragraphSpacing
        )


encodeMaybe : String -> (a -> Encode.Value) -> Maybe a -> List ( String, Encode.Value )
encodeMaybe key enc maybeVal =
    case maybeVal of
        Just val ->
            [ ( key, enc val ) ]

        Nothing ->
            []


{-| Convert a typography to a CSS `font` shorthand string.

    toCssString { fontFamily = FontFamily.stack "Helvetica" [ "Arial" ], fontSize = Dimension.px 16, fontWeight = FontWeight.Normal, lineHeight = 1.5, letterSpacing = Nothing, paragraphSpacing = Nothing }
        == "400 16px/1.5 \"Helvetica\", \"Arial\""

Note: `letterSpacing` and `paragraphSpacing` are not part of the CSS
`font` shorthand and are omitted from this output.

-}
toCssString : Typography -> String
toCssString typo =
    FontWeight.toCssString typo.fontWeight
        ++ " "
        ++ Dimension.toCssString typo.fontSize
        ++ "/"
        ++ CssFormat.formatFloat typo.lineHeight
        ++ " "
        ++ FontFamily.toCssString typo.fontFamily
