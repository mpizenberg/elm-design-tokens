module Generate.Expression exposing (tokenValueToExpression)

{-| Convert token values to elm-syntax-dsl expressions.
-}

import DesignTokens.Border exposing (Border)
import DesignTokens.Color exposing (Color, ColorSpace(..))
import DesignTokens.CubicBezier exposing (CubicBezier)
import DesignTokens.Dimension exposing (Dimension, DimensionUnit(..))
import DesignTokens.Duration exposing (Duration, DurationUnit(..))
import DesignTokens.FontFamily as FontFamily exposing (FontFamily)
import DesignTokens.FontWeight exposing (FontWeight(..))
import DesignTokens.Gradient exposing (Gradient, GradientStop)
import DesignTokens.Shadow exposing (Shadow)
import DesignTokens.StrokeStyle exposing (LineCap(..), StrokeStyle(..))
import DesignTokens.Token exposing (TokenValue(..))
import DesignTokens.Transition exposing (TimingFunction(..), Transition)
import DesignTokens.Typography exposing (Typography)
import Elm.CodeGen as CG exposing (Expression)


{-| Convert a TokenValue to an Elm.CodeGen Expression.
-}
tokenValueToExpression : TokenValue -> Expression
tokenValueToExpression tokenValue =
    case tokenValue of
        ColorValue color ->
            colorExpression color

        DimensionValue dim ->
            dimensionExpression dim

        FontFamilyValue ff ->
            fontFamilyExpression ff

        FontWeightValue fw ->
            fontWeightExpression fw

        DurationValue dur ->
            durationExpression dur

        CubicBezierValue cb ->
            cubicBezierExpression cb

        NumberValue n ->
            CG.float n

        StringValue s ->
            CG.string s

        BooleanValue b ->
            if b then
                CG.val "True"

            else
                CG.val "False"

        ShadowValue shadow ->
            shadowExpression shadow

        BorderValue border ->
            borderExpression border

        StrokeStyleValue ss ->
            strokeStyleExpression ss

        GradientValue gradient ->
            gradientExpression gradient

        TypographyValue typo ->
            typographyExpression typo

        TransitionValue trans ->
            transitionExpression trans



-- INDIVIDUAL TYPE EXPRESSIONS


colorExpression : Color -> Expression
colorExpression color =
    let
        ( c1, c2, c3 ) =
            color.components

        constructorName : String
        constructorName =
            colorSpaceToConstructorName color.colorSpace

        baseExpr : Expression
        baseExpr =
            CG.apply
                [ CG.fqVal [ "Color" ] constructorName
                , CG.float c1
                , CG.float c2
                , CG.float c3
                ]
    in
    if color.alpha == 1 then
        baseExpr

    else
        CG.pipe baseExpr
            [ CG.apply [ CG.fqVal [ "Color" ] "withAlpha", CG.float color.alpha ] ]


colorSpaceToConstructorName : ColorSpace -> String
colorSpaceToConstructorName cs =
    case cs of
        Srgb ->
            "srgb"

        SrgbLinear ->
            "srgbLinear"

        DisplayP3 ->
            "displayP3"

        A98Rgb ->
            "a98Rgb"

        ProphotoRgb ->
            "prophotoRgb"

        Rec2020 ->
            "rec2020"

        XyzD50 ->
            "xyzD50"

        XyzD65 ->
            "xyzD65"

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


dimensionExpression : Dimension -> Expression
dimensionExpression dim =
    case dim.unit of
        Px ->
            CG.apply [ CG.fqVal [ "Dimension" ] "px", CG.float dim.value ]

        Rem ->
            CG.apply [ CG.fqVal [ "Dimension" ] "rem", CG.float dim.value ]


fontFamilyExpression : FontFamily -> Expression
fontFamilyExpression ff =
    case FontFamily.toList ff of
        [] ->
            -- Should not happen (FontFamily is non-empty)
            CG.apply [ CG.fqVal [ "FontFamily" ] "single", CG.string "" ]

        [ name ] ->
            CG.apply [ CG.fqVal [ "FontFamily" ] "single", CG.string name ]

        first :: rest ->
            CG.apply
                [ CG.fqVal [ "FontFamily" ] "stack"
                , CG.string first
                , CG.list (List.map CG.string rest)
                ]


fontWeightExpression : FontWeight -> Expression
fontWeightExpression fw =
    case fw of
        Numeric n ->
            CG.fqConstruct [ "FontWeight" ] "Numeric" [ CG.int n ]

        Thin ->
            CG.fqVal [ "FontWeight" ] "Thin"

        ExtraLight ->
            CG.fqVal [ "FontWeight" ] "ExtraLight"

        Light ->
            CG.fqVal [ "FontWeight" ] "Light"

        Normal ->
            CG.fqVal [ "FontWeight" ] "Normal"

        Medium ->
            CG.fqVal [ "FontWeight" ] "Medium"

        SemiBold ->
            CG.fqVal [ "FontWeight" ] "SemiBold"

        Bold ->
            CG.fqVal [ "FontWeight" ] "Bold"

        ExtraBold ->
            CG.fqVal [ "FontWeight" ] "ExtraBold"

        Black ->
            CG.fqVal [ "FontWeight" ] "Black"

        ExtraBlack ->
            CG.fqVal [ "FontWeight" ] "ExtraBlack"


durationExpression : Duration -> Expression
durationExpression dur =
    case dur.unit of
        Ms ->
            CG.apply [ CG.fqVal [ "Duration" ] "ms", CG.float dur.value ]

        S ->
            CG.apply [ CG.fqVal [ "Duration" ] "s", CG.float dur.value ]


cubicBezierExpression : CubicBezier -> Expression
cubicBezierExpression cb =
    CG.record
        [ ( "p1x", CG.float cb.p1x )
        , ( "p1y", CG.float cb.p1y )
        , ( "p2x", CG.float cb.p2x )
        , ( "p2y", CG.float cb.p2y )
        ]


shadowExpression : Shadow -> Expression
shadowExpression shadow =
    CG.record
        [ ( "color", colorExpression shadow.color )
        , ( "offsetX", dimensionExpression shadow.offsetX )
        , ( "offsetY", dimensionExpression shadow.offsetY )
        , ( "blur", dimensionExpression shadow.blur )
        , ( "spread", dimensionExpression shadow.spread )
        ]


borderExpression : Border -> Expression
borderExpression border =
    CG.record
        [ ( "color", colorExpression border.color )
        , ( "width", dimensionExpression border.width )
        , ( "style", CG.string border.style )
        ]


strokeStyleExpression : StrokeStyle -> Expression
strokeStyleExpression ss =
    case ss of
        StringStyle s ->
            CG.fqConstruct [ "StrokeStyle" ] "StringStyle" [ CG.string s ]

        DetailedStyle detail ->
            CG.fqConstruct [ "StrokeStyle" ]
                "DetailedStyle"
                [ CG.record
                    [ ( "dashArray", CG.list (List.map dimensionExpression detail.dashArray) )
                    , ( "lineCap", lineCapExpression detail.lineCap )
                    ]
                ]


lineCapExpression : LineCap -> Expression
lineCapExpression lc =
    case lc of
        Round ->
            CG.fqVal [ "StrokeStyle" ] "Round"

        Butt ->
            CG.fqVal [ "StrokeStyle" ] "Butt"

        Square ->
            CG.fqVal [ "StrokeStyle" ] "Square"


gradientExpression : Gradient -> Expression
gradientExpression stops =
    CG.list (List.map gradientStopExpression stops)


gradientStopExpression : GradientStop -> Expression
gradientStopExpression stop =
    CG.record
        [ ( "color", colorExpression stop.color )
        , ( "position", CG.float stop.position )
        ]


typographyExpression : Typography -> Expression
typographyExpression typo =
    let
        requiredFields : List ( String, Expression )
        requiredFields =
            [ ( "fontFamily", fontFamilyExpression typo.fontFamily )
            , ( "fontSize", dimensionExpression typo.fontSize )
            , ( "fontWeight", fontWeightExpression typo.fontWeight )
            , ( "lineHeight", CG.float typo.lineHeight )
            , ( "letterSpacing", maybeExpression dimensionExpression typo.letterSpacing )
            , ( "paragraphSpacing", maybeExpression dimensionExpression typo.paragraphSpacing )
            ]
    in
    CG.record requiredFields


transitionExpression : Transition -> Expression
transitionExpression trans =
    CG.record
        [ ( "duration", durationExpression trans.duration )
        , ( "delay", maybeExpression durationExpression trans.delay )
        , ( "timingFunction", timingFunctionExpression trans.timingFunction )
        ]


timingFunctionExpression : TimingFunction -> Expression
timingFunctionExpression tf =
    case tf of
        CubicBezierFunction cb ->
            CG.fqConstruct [ "Transition" ] "CubicBezierFunction" [ cubicBezierExpression cb ]

        StepFunction s ->
            CG.fqConstruct [ "Transition" ] "StepFunction" [ CG.string s ]


maybeExpression : (a -> Expression) -> Maybe a -> Expression
maybeExpression toExpr maybe =
    case maybe of
        Nothing ->
            CG.val "Nothing"

        Just value ->
            CG.apply [ CG.val "Just", toExpr value ]
