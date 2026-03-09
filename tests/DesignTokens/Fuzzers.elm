module DesignTokens.Fuzzers exposing
    ( color, colorSpace, components
    , cubicBezier
    , dimension, dimensionUnit
    , duration, durationUnit
    , fontFamily
    , fontWeight
    , gradient, gradientStop
    , lineCap
    )

import DesignTokens.Color as Color exposing (Color, ColorSpace(..))
import DesignTokens.CubicBezier as CubicBezier exposing (CubicBezier)
import DesignTokens.Dimension as Dimension exposing (Dimension, DimensionUnit(..))
import DesignTokens.Duration as Duration exposing (Duration, DurationUnit(..))
import DesignTokens.FontFamily as FontFamily exposing (FontFamily)
import DesignTokens.FontWeight as FontWeight exposing (FontWeight(..))
import DesignTokens.Gradient as Gradient exposing (GradientStop)
import DesignTokens.StrokeStyle exposing (LineCap(..))
import Fuzz exposing (Fuzzer)


colorSpace : Fuzzer ColorSpace
colorSpace =
    Fuzz.oneOfValues
        [ Srgb, SrgbLinear, DisplayP3, A98Rgb, ProphotoRgb, Rec2020
        , XyzD50, XyzD65, Lab, Lch, Oklab, Oklch, Hsl, Hwb
        ]


components : Fuzzer ( Float, Float, Float )
components =
    Fuzz.map3 (\a b c -> ( a, b, c ))
        (Fuzz.floatRange 0 1)
        (Fuzz.floatRange 0 1)
        (Fuzz.floatRange 0 1)


color : Fuzzer Color
color =
    Fuzz.map3 Color
        colorSpace
        components
        (Fuzz.floatRange 0 1)


dimensionUnit : Fuzzer DimensionUnit
dimensionUnit =
    Fuzz.oneOfValues [ Px, Rem ]


dimension : Fuzzer Dimension
dimension =
    Fuzz.map2 Dimension
        (Fuzz.floatRange 0 1000)
        dimensionUnit


durationUnit : Fuzzer DurationUnit
durationUnit =
    Fuzz.oneOfValues [ Ms, S ]


duration : Fuzzer Duration
duration =
    Fuzz.map2 Duration
        (Fuzz.floatRange 0 10000)
        durationUnit


cubicBezier : Fuzzer CubicBezier
cubicBezier =
    Fuzz.map4 CubicBezier
        (Fuzz.floatRange 0 1)
        (Fuzz.floatRange -5 5)
        (Fuzz.floatRange 0 1)
        (Fuzz.floatRange -5 5)


fontWeight : Fuzzer FontWeight
fontWeight =
    Fuzz.oneOf
        [ Fuzz.intRange 1 1000 |> Fuzz.map Numeric
        , Fuzz.oneOfValues
            [ Thin, ExtraLight, Light, Normal, Medium
            , SemiBold, Bold, ExtraBold, Black, ExtraBlack
            ]
        ]


fontFamily : Fuzzer FontFamily
fontFamily =
    Fuzz.oneOf
        [ Fuzz.map FontFamily.single fontName
        , Fuzz.map2 FontFamily.stack fontName (Fuzz.list fontName)
        ]


fontName : Fuzzer String
fontName =
    Fuzz.oneOfValues
        [ "Helvetica", "Arial", "sans-serif", "Georgia", "Times New Roman"
        , "Courier New", "monospace", "Inter", "Roboto", "system-ui"
        ]


gradientStop : Fuzzer GradientStop
gradientStop =
    Fuzz.map2 GradientStop
        color
        (Fuzz.floatRange 0 1)


gradient : Fuzzer (List GradientStop)
gradient =
    Fuzz.listOfLengthBetween 1 5 gradientStop


lineCap : Fuzzer LineCap
lineCap =
    Fuzz.oneOfValues [ Round, Butt, Square ]
