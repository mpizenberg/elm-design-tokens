module DesignTokens.FontWeight exposing
    ( FontWeight(..)
    , toInt
    , decoder, encode
    , toCssString
    )

{-| DTCG Font Weight token type.

Font weight can be a numeric value (1-1000) or a named weight.
Named weights have standard numeric equivalents defined by the DTCG spec.

@docs FontWeight
@docs toInt
@docs decoder, encode
@docs toCssString

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A font weight value.
-}
type FontWeight
    = Numeric Int
    | Thin
    | ExtraLight
    | Light
    | Normal
    | Medium
    | SemiBold
    | Bold
    | ExtraBold
    | Black
    | ExtraBlack


{-| Convert a font weight to its numeric value.

    toInt Bold == 700
    toInt (Numeric 450) == 450

-}
toInt : FontWeight -> Int
toInt weight =
    case weight of
        Numeric n ->
            n

        Thin ->
            100

        ExtraLight ->
            200

        Light ->
            300

        Normal ->
            400

        Medium ->
            500

        SemiBold ->
            600

        Bold ->
            700

        ExtraBold ->
            800

        Black ->
            900

        ExtraBlack ->
            950


{-| Decode a DTCG font weight value.

Accepts a JSON number (1-1000) or a named weight string.
String aliases like `"hairline"`, `"regular"`, `"heavy"` etc.
are normalized to their canonical variant.

-}
decoder : Decoder FontWeight
decoder =
    Decode.oneOf
        [ Decode.int
            |> Decode.andThen
                (\n ->
                    if n >= 1 && n <= 1000 then
                        Decode.succeed (Numeric n)

                    else
                        Decode.fail ("Font weight must be between 1 and 1000, got " ++ String.fromInt n)
                )
        , Decode.string
            |> Decode.andThen
                (\s ->
                    case s of
                        "thin" ->
                            Decode.succeed Thin

                        "hairline" ->
                            Decode.succeed Thin

                        "extra-light" ->
                            Decode.succeed ExtraLight

                        "ultra-light" ->
                            Decode.succeed ExtraLight

                        "light" ->
                            Decode.succeed Light

                        "normal" ->
                            Decode.succeed Normal

                        "regular" ->
                            Decode.succeed Normal

                        "book" ->
                            Decode.succeed Normal

                        "medium" ->
                            Decode.succeed Medium

                        "semi-bold" ->
                            Decode.succeed SemiBold

                        "demi-bold" ->
                            Decode.succeed SemiBold

                        "bold" ->
                            Decode.succeed Bold

                        "extra-bold" ->
                            Decode.succeed ExtraBold

                        "ultra-bold" ->
                            Decode.succeed ExtraBold

                        "black" ->
                            Decode.succeed Black

                        "heavy" ->
                            Decode.succeed Black

                        "extra-black" ->
                            Decode.succeed ExtraBlack

                        "ultra-black" ->
                            Decode.succeed ExtraBlack

                        _ ->
                            Decode.fail ("Unknown font weight: " ++ s)
                )
        ]


{-| Encode a font weight to DTCG JSON.

Named variants encode as their primary string name.
`Numeric` values encode as JSON integers.

-}
encode : FontWeight -> Encode.Value
encode weight =
    case weight of
        Numeric n ->
            Encode.int n

        Thin ->
            Encode.string "thin"

        ExtraLight ->
            Encode.string "extra-light"

        Light ->
            Encode.string "light"

        Normal ->
            Encode.string "normal"

        Medium ->
            Encode.string "medium"

        SemiBold ->
            Encode.string "semi-bold"

        Bold ->
            Encode.string "bold"

        ExtraBold ->
            Encode.string "extra-bold"

        Black ->
            Encode.string "black"

        ExtraBlack ->
            Encode.string "extra-black"


{-| Convert a font weight to a CSS string (always numeric).

    toCssString Bold == "700"
    toCssString (Numeric 450) == "450"

-}
toCssString : FontWeight -> String
toCssString weight =
    String.fromInt (toInt weight)
