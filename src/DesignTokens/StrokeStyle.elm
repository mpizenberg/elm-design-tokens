module DesignTokens.StrokeStyle exposing
    ( StrokeStyle(..), LineCap(..)
    , decoder, encode
    , toCssString
    )

{-| DTCG Stroke Style token type.

A stroke style is either a simple string (e.g. `"solid"`, `"dashed"`)
or a detailed object with a dash array and line cap.

@docs StrokeStyle, LineCap
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.Dimension as Dimension exposing (Dimension)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A stroke style value.
-}
type StrokeStyle
    = StringStyle String
    | DetailedStyle
        { dashArray : List Dimension
        , lineCap : LineCap
        }


{-| Line cap style for stroke endpoints.
-}
type LineCap
    = Round
    | Butt
    | Square


{-| Decode a DTCG stroke style value.

Accepts a JSON string or an object with `dashArray` and `lineCap` fields.

-}
decoder : Decoder StrokeStyle
decoder =
    Decode.oneOf
        [ Decode.string |> Decode.map StringStyle
        , Decode.map2 (\da lc -> DetailedStyle { dashArray = da, lineCap = lc })
            (Decode.field "dashArray" (Decode.list Dimension.decoder))
            (Decode.field "lineCap" lineCapDecoder)
        ]


lineCapDecoder : Decoder LineCap
lineCapDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "round" ->
                        Decode.succeed Round

                    "butt" ->
                        Decode.succeed Butt

                    "square" ->
                        Decode.succeed Square

                    _ ->
                        Decode.fail ("Unknown line cap: " ++ s)
            )


{-| Encode a stroke style to DTCG JSON.
-}
encode : StrokeStyle -> Encode.Value
encode strokeStyle =
    case strokeStyle of
        StringStyle s ->
            Encode.string s

        DetailedStyle detail ->
            Encode.object
                [ ( "dashArray", Encode.list Dimension.encode detail.dashArray )
                , ( "lineCap", encodeLineCap detail.lineCap )
                ]


encodeLineCap : LineCap -> Encode.Value
encodeLineCap cap =
    Encode.string
        (case cap of
            Round ->
                "round"

            Butt ->
                "butt"

            Square ->
                "square"
        )


{-| Convert a stroke style to a CSS string.

For string styles, returns the string directly.
The detailed form has no direct CSS equivalent; it returns
a diagnostic representation.

-}
toCssString : StrokeStyle -> String
toCssString strokeStyle =
    case strokeStyle of
        StringStyle s ->
            s

        DetailedStyle detail ->
            let
                dashStr =
                    detail.dashArray
                        |> List.map Dimension.toCssString
                        |> String.join " "

                capStr =
                    case detail.lineCap of
                        Round ->
                            "round"

                        Butt ->
                            "butt"

                        Square ->
                            "square"
            in
            dashStr ++ " " ++ capStr
