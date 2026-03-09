module DesignTokens.FontFamily exposing
    ( FontFamily
    , single, stack
    , toList
    , decoder, encode
    , toCssString
    )

{-| DTCG Font Family token type.

A font family is a non-empty list of font names. This type is opaque
to enforce the non-empty invariant.

@docs FontFamily
@docs single, stack
@docs toList
@docs decoder, encode
@docs toCssString

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| An opaque font family type guaranteeing at least one font name.
-}
type FontFamily
    = FontFamily String (List String)


{-| Create a font family with a single font name.

    single "Helvetica"

-}
single : String -> FontFamily
single name =
    FontFamily name []


{-| Create a font family with a primary font and fallbacks.

    stack "Helvetica" [ "Arial", "sans-serif" ]

-}
stack : String -> List String -> FontFamily
stack primary fallbacks =
    FontFamily primary fallbacks


{-| Get the list of font names.

    toList (stack "Helvetica" [ "Arial" ]) == [ "Helvetica", "Arial" ]

-}
toList : FontFamily -> List String
toList (FontFamily primary fallbacks) =
    primary :: fallbacks


{-| Decode a DTCG font family value.

Accepts a JSON string or a non-empty JSON array of strings.

-}
decoder : Decoder FontFamily
decoder =
    Decode.oneOf
        [ Decode.string
            |> Decode.map (\name -> FontFamily name [])
        , Decode.list Decode.string
            |> Decode.andThen
                (\names ->
                    case names of
                        [] ->
                            Decode.fail "Font family array must not be empty"

                        primary :: fallbacks ->
                            Decode.succeed (FontFamily primary fallbacks)
                )
        ]


{-| Encode a font family to DTCG JSON.

A single font encodes as a JSON string.
Multiple fonts encode as a JSON array.

-}
encode : FontFamily -> Encode.Value
encode (FontFamily primary fallbacks) =
    case fallbacks of
        [] ->
            Encode.string primary

        _ ->
            Encode.list Encode.string (primary :: fallbacks)


{-| Convert a font family to a CSS string.

    toCssString (stack "Helvetica Neue" [ "Arial" ])
        == "\"Helvetica Neue\", \"Arial\""

-}
toCssString : FontFamily -> String
toCssString (FontFamily primary fallbacks) =
    (primary :: fallbacks)
        |> List.map (\name -> "\"" ++ name ++ "\"")
        |> String.join ", "
