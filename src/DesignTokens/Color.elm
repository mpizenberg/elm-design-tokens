module DesignTokens.Color exposing
    ( Color, ColorSpace(..)
    , srgb, srgbLinear, displayP3, a98Rgb, prophotoRgb, rec2020
    , xyzD50, xyzD65, lab, lch, oklab, oklch, hsl, hwb
    , withAlpha
    , decoder, encode
    , colorSpaceToString, colorSpaceFromString
    , toCssString
    )

{-| DTCG Color token type.

Colors are defined with an explicit color space, three components,
and an alpha value. The 14 supported color spaces come from CSS Color Module 4.

@docs Color, ColorSpace

@docs srgb, srgbLinear, displayP3, a98Rgb, prophotoRgb, rec2020
@docs xyzD50, xyzD65, lab, lch, oklab, oklch, hsl, hwb
@docs withAlpha

@docs decoder, encode
@docs colorSpaceToString, colorSpaceFromString
@docs toCssString

-}

import DesignTokens.Internal.CssFormat as CssFormat
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A color value with an explicit color space.
-}
type alias Color =
    { colorSpace : ColorSpace
    , components : ( Float, Float, Float )
    , alpha : Float
    }


{-| One of the 14 CSS Color Module 4 color spaces supported by the DTCG spec.
-}
type ColorSpace
    = Srgb
    | SrgbLinear
    | DisplayP3
    | A98Rgb
    | ProphotoRgb
    | Rec2020
    | XyzD50
    | XyzD65
    | Lab
    | Lch
    | Oklab
    | Oklch
    | Hsl
    | Hwb



-- CONSTRUCTORS


{-| Create an sRGB color.
-}
srgb : Float -> Float -> Float -> Color
srgb c1 c2 c3 =
    Color Srgb ( c1, c2, c3 ) 1


{-| Create an sRGB-linear color.
-}
srgbLinear : Float -> Float -> Float -> Color
srgbLinear c1 c2 c3 =
    Color SrgbLinear ( c1, c2, c3 ) 1


{-| Create a Display P3 color.
-}
displayP3 : Float -> Float -> Float -> Color
displayP3 c1 c2 c3 =
    Color DisplayP3 ( c1, c2, c3 ) 1


{-| Create an A98 RGB color.
-}
a98Rgb : Float -> Float -> Float -> Color
a98Rgb c1 c2 c3 =
    Color A98Rgb ( c1, c2, c3 ) 1


{-| Create a ProPhoto RGB color.
-}
prophotoRgb : Float -> Float -> Float -> Color
prophotoRgb c1 c2 c3 =
    Color ProphotoRgb ( c1, c2, c3 ) 1


{-| Create a Rec. 2020 color.
-}
rec2020 : Float -> Float -> Float -> Color
rec2020 c1 c2 c3 =
    Color Rec2020 ( c1, c2, c3 ) 1


{-| Create a CIE XYZ D50 color.
-}
xyzD50 : Float -> Float -> Float -> Color
xyzD50 c1 c2 c3 =
    Color XyzD50 ( c1, c2, c3 ) 1


{-| Create a CIE XYZ D65 color.
-}
xyzD65 : Float -> Float -> Float -> Color
xyzD65 c1 c2 c3 =
    Color XyzD65 ( c1, c2, c3 ) 1


{-| Create a CIE Lab color.
-}
lab : Float -> Float -> Float -> Color
lab c1 c2 c3 =
    Color Lab ( c1, c2, c3 ) 1


{-| Create a CIE LCH color.
-}
lch : Float -> Float -> Float -> Color
lch c1 c2 c3 =
    Color Lch ( c1, c2, c3 ) 1


{-| Create an OKLab color.
-}
oklab : Float -> Float -> Float -> Color
oklab c1 c2 c3 =
    Color Oklab ( c1, c2, c3 ) 1


{-| Create an OKLCH color.
-}
oklch : Float -> Float -> Float -> Color
oklch c1 c2 c3 =
    Color Oklch ( c1, c2, c3 ) 1


{-| Create an HSL color.
-}
hsl : Float -> Float -> Float -> Color
hsl c1 c2 c3 =
    Color Hsl ( c1, c2, c3 ) 1


{-| Create an HWB color.
-}
hwb : Float -> Float -> Float -> Color
hwb c1 c2 c3 =
    Color Hwb ( c1, c2, c3 ) 1


{-| Set the alpha value of a color.

    srgb 1 0 0 |> withAlpha 0.5

-}
withAlpha : Float -> Color -> Color
withAlpha a color =
    { color | alpha = a }



-- CODECS


{-| Decode a DTCG color value.

    -- { "colorSpace": "srgb", "components": [0.2, 0.4, 0.8], "alpha": 1 }



Alpha defaults to 1 when absent. The `hex` field is ignored.

-}
decoder : Decoder Color
decoder =
    Decode.map3 Color
        (Decode.field "colorSpace" colorSpaceDecoder)
        (Decode.field "components" componentsDecoder)
        (Decode.oneOf
            [ Decode.field "alpha" Decode.float
            , Decode.succeed 1
            ]
        )


colorSpaceDecoder : Decoder ColorSpace
colorSpaceDecoder =
    Decode.string
        |> Decode.andThen
            (\s ->
                case colorSpaceFromString s of
                    Just cs ->
                        Decode.succeed cs

                    Nothing ->
                        Decode.fail ("Unknown color space: " ++ s)
            )


componentsDecoder : Decoder ( Float, Float, Float )
componentsDecoder =
    Decode.list Decode.float
        |> Decode.andThen
            (\floats ->
                case floats of
                    [ c1, c2, c3 ] ->
                        Decode.succeed ( c1, c2, c3 )

                    _ ->
                        Decode.fail ("Expected array of 3 numbers, got " ++ String.fromInt (List.length floats))
            )


{-| Encode a color to DTCG JSON.
-}
encode : Color -> Encode.Value
encode color =
    let
        ( c1, c2, c3 ) =
            color.components
    in
    Encode.object
        ([ ( "colorSpace", Encode.string (colorSpaceToString color.colorSpace) )
         , ( "components", Encode.list Encode.float [ c1, c2, c3 ] )
         ]
            ++ (if color.alpha /= 1 then
                    [ ( "alpha", Encode.float color.alpha ) ]

                else
                    []
               )
        )



-- COLOR SPACE CONVERSION


{-| Convert a ColorSpace to its DTCG/CSS string identifier.

    colorSpaceToString Oklch == "oklch"

    colorSpaceToString DisplayP3 == "display-p3"

-}
colorSpaceToString : ColorSpace -> String
colorSpaceToString cs =
    case cs of
        Srgb ->
            "srgb"

        SrgbLinear ->
            "srgb-linear"

        DisplayP3 ->
            "display-p3"

        A98Rgb ->
            "a98-rgb"

        ProphotoRgb ->
            "prophoto-rgb"

        Rec2020 ->
            "rec2020"

        XyzD50 ->
            "xyz-d50"

        XyzD65 ->
            "xyz-d65"

        Lab ->
            "lab"

        Lch ->
            "lch"

        Oklab ->
            "oklab"

        Oklch ->
            "oklch"

        Hsl ->
            "hsl"

        Hwb ->
            "hwb"


{-| Parse a DTCG/CSS color space string.

    colorSpaceFromString "oklch" == Just Oklch

    colorSpaceFromString "unknown" == Nothing

-}
colorSpaceFromString : String -> Maybe ColorSpace
colorSpaceFromString s =
    case s of
        "srgb" ->
            Just Srgb

        "srgb-linear" ->
            Just SrgbLinear

        "display-p3" ->
            Just DisplayP3

        "a98-rgb" ->
            Just A98Rgb

        "prophoto-rgb" ->
            Just ProphotoRgb

        "rec2020" ->
            Just Rec2020

        "xyz-d50" ->
            Just XyzD50

        "xyz-d65" ->
            Just XyzD65

        "lab" ->
            Just Lab

        "lch" ->
            Just Lch

        "oklab" ->
            Just Oklab

        "oklch" ->
            Just Oklch

        "hsl" ->
            Just Hsl

        "hwb" ->
            Just Hwb

        _ ->
            Nothing



-- CSS


{-| Convert a color to a CSS string.

Color spaces with dedicated CSS functions use their own syntax:

    toCssString (oklch 0.65 0.15 250) == "oklch(0.65 0.15 250)"

Other color spaces use the `color()` function:

    toCssString (srgb 0.2 0.4 0.8) == "color(srgb 0.2 0.4 0.8)"

Alpha is appended when not equal to 1:

    toCssString (srgb 0.2 0.4 0.8 |> withAlpha 0.5)
        == "color(srgb 0.2 0.4 0.8 / 0.5)"

-}
toCssString : Color -> String
toCssString color =
    let
        ( c1, c2, c3 ) =
            color.components

        fc1 =
            CssFormat.formatFloat c1

        fc2 =
            CssFormat.formatFloat c2

        fc3 =
            CssFormat.formatFloat c3

        alphaPart =
            if color.alpha == 1 then
                ""

            else
                " / " ++ CssFormat.formatFloat color.alpha
    in
    if usesDedicatedFunction color.colorSpace then
        colorSpaceToString color.colorSpace
            ++ "("
            ++ fc1
            ++ " "
            ++ fc2
            ++ " "
            ++ fc3
            ++ alphaPart
            ++ ")"

    else
        "color("
            ++ colorSpaceToString color.colorSpace
            ++ " "
            ++ fc1
            ++ " "
            ++ fc2
            ++ " "
            ++ fc3
            ++ alphaPart
            ++ ")"


{-| Color spaces that have their own CSS function (not using `color()`).
-}
usesDedicatedFunction : ColorSpace -> Bool
usesDedicatedFunction cs =
    case cs of
        Hsl ->
            True

        Hwb ->
            True

        Lab ->
            True

        Lch ->
            True

        Oklab ->
            True

        Oklch ->
            True

        _ ->
            False
