module DesignTokens.Duration exposing
    ( Duration, DurationUnit(..)
    , ms, s
    , decoder, encode
    , toCssString
    )

{-| DTCG Duration token type.

A duration represents a time value with a unit.
The DTCG spec supports `ms` (milliseconds) and `s` (seconds).

@docs Duration, DurationUnit
@docs ms, s
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Internal.CssFormat as CssFormat
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A duration value with a unit.
-}
type alias Duration =
    { value : Float
    , unit : DurationUnit
    }


{-| The unit of a duration.
-}
type DurationUnit
    = Ms
    | S


{-| Create a millisecond duration.
-}
ms : Float -> Duration
ms value =
    { value = value, unit = Ms }


{-| Create a second duration.
-}
s : Float -> Duration
s value =
    { value = value, unit = S }


{-| Decode a DTCG duration value.

    -- { "value": 200, "unit": "ms" }



-}
decoder : Decoder Duration
decoder =
    Decode.map2 Duration
        (Decode.field "value" Decode.float)
        (Decode.field "unit" unitDecoder)


unitDecoder : Decoder DurationUnit
unitDecoder =
    Decode.string
        |> Decode.andThen
            (\u ->
                case u of
                    "ms" ->
                        Decode.succeed Ms

                    "s" ->
                        Decode.succeed S

                    _ ->
                        Decode.fail ("Unknown duration unit: " ++ u)
            )


{-| Encode a duration to DTCG JSON.
-}
encode : Duration -> Encode.Value
encode dur =
    Encode.object
        [ ( "value", Encode.float dur.value )
        , ( "unit", encodeUnit dur.unit )
        ]


encodeUnit : DurationUnit -> Encode.Value
encodeUnit unit =
    Encode.string
        (case unit of
            Ms ->
                "ms"

            S ->
                "s"
        )


{-| Convert a duration to a CSS string.

    toCssString (ms 200) == "200ms"

    toCssString (s 0.5) == "0.5s"

-}
toCssString : Duration -> String
toCssString dur =
    CssFormat.formatFloat dur.value
        ++ (case dur.unit of
                Ms ->
                    "ms"

                S ->
                    "s"
           )
