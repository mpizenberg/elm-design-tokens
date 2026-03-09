module Generate.ExpressionTest exposing (suite)

import DesignTokens.Color as Color
import DesignTokens.CubicBezier exposing (CubicBezier)
import DesignTokens.Dimension as Dimension
import DesignTokens.Duration as Duration
import DesignTokens.FontFamily as FontFamily
import DesignTokens.FontWeight exposing (FontWeight(..))
import DesignTokens.Gradient exposing (GradientStop)
import DesignTokens.StrokeStyle exposing (LineCap(..), StrokeStyle(..))
import DesignTokens.Token exposing (TokenValue(..))
import DesignTokens.Transition exposing (TimingFunction(..))
import Elm.CodeGen as CG
import Elm.Pretty
import Expect
import Generate.Expression as Expression
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Generate.Expression"
        [ colorTests
        , dimensionTests
        , fontFamilyTests
        , fontWeightTests
        , durationTests
        , cubicBezierTests
        , primitiveTests
        , shadowTests
        , borderTests
        , strokeStyleTests
        , gradientTests
        , typographyTests
        , transitionTests
        ]


colorTests : Test
colorTests =
    describe "color"
        [ test "srgb color" <|
            \_ ->
                ColorValue (Color.srgb 0.2 0.4 0.8)
                    |> exprToString
                    |> Expect.equal "Color.srgb 0.2 0.4 0.8"
        , test "color with alpha" <|
            \_ ->
                ColorValue (Color.srgb 1 0 0 |> Color.withAlpha 0.5)
                    |> exprToString
                    |> Expect.equal "Color.srgb 1 0 0 |> Color.withAlpha 0.5"
        , test "oklch color" <|
            \_ ->
                ColorValue (Color.oklch 0.7 0.15 180)
                    |> exprToString
                    |> Expect.equal "Color.oklch 0.7 0.15 180"
        ]


dimensionTests : Test
dimensionTests =
    describe "dimension"
        [ test "px" <|
            \_ ->
                DimensionValue (Dimension.px 16)
                    |> exprToString
                    |> Expect.equal "Dimension.px 16"
        , test "rem" <|
            \_ ->
                DimensionValue (Dimension.rem 1.5)
                    |> exprToString
                    |> Expect.equal "Dimension.rem 1.5"
        ]


fontFamilyTests : Test
fontFamilyTests =
    describe "fontFamily"
        [ test "single font" <|
            \_ ->
                FontFamilyValue (FontFamily.single "Helvetica")
                    |> exprToString
                    |> Expect.equal "FontFamily.single \"Helvetica\""
        , test "font stack" <|
            \_ ->
                FontFamilyValue (FontFamily.stack "Georgia" [ "serif" ])
                    |> exprToString
                    |> Expect.equal "FontFamily.stack \"Georgia\" [ \"serif\" ]"
        ]


fontWeightTests : Test
fontWeightTests =
    describe "fontWeight"
        [ test "named bold" <|
            \_ ->
                FontWeightValue Bold
                    |> exprToString
                    |> Expect.equal "FontWeight.Bold"
        , test "numeric" <|
            \_ ->
                FontWeightValue (Numeric 550)
                    |> exprToString
                    |> Expect.equal "FontWeight.Numeric 550"
        ]


durationTests : Test
durationTests =
    describe "duration"
        [ test "ms" <|
            \_ ->
                DurationValue (Duration.ms 200)
                    |> exprToString
                    |> Expect.equal "Duration.ms 200"
        , test "s" <|
            \_ ->
                DurationValue (Duration.s 1.5)
                    |> exprToString
                    |> Expect.equal "Duration.s 1.5"
        ]


cubicBezierTests : Test
cubicBezierTests =
    describe "cubicBezier"
        [ test "easeInOut" <|
            \_ ->
                CubicBezierValue { p1x = 0.42, p1y = 0, p2x = 0.58, p2y = 1 }
                    |> exprToString
                    |> Expect.equal "{ p1x = 0.42, p1y = 0, p2x = 0.58, p2y = 1 }"
        ]


primitiveTests : Test
primitiveTests =
    describe "primitives"
        [ test "number" <|
            \_ ->
                NumberValue 42.5
                    |> exprToString
                    |> Expect.equal "42.5"
        , test "string" <|
            \_ ->
                StringValue "hello"
                    |> exprToString
                    |> Expect.equal "\"hello\""
        , test "boolean true" <|
            \_ ->
                BooleanValue True
                    |> exprToString
                    |> Expect.equal "True"
        , test "boolean false" <|
            \_ ->
                BooleanValue False
                    |> exprToString
                    |> Expect.equal "False"
        ]


shadowTests : Test
shadowTests =
    describe "shadow"
        [ test "basic shadow" <|
            \_ ->
                ShadowValue
                    { color = Color.srgb 0 0 0
                    , offsetX = Dimension.px 2
                    , offsetY = Dimension.px 4
                    , blur = Dimension.px 8
                    , spread = Dimension.px 0
                    }
                    |> exprToString
                    |> String.contains "Color.srgb 0 0 0"
                    |> Expect.equal True
        ]


borderTests : Test
borderTests =
    describe "border"
        [ test "solid border" <|
            \_ ->
                BorderValue
                    { color = Color.srgb 0 0 0
                    , width = Dimension.px 1
                    , style = "solid"
                    }
                    |> exprToString
                    |> String.contains "\"solid\""
                    |> Expect.equal True
        ]


strokeStyleTests : Test
strokeStyleTests =
    describe "strokeStyle"
        [ test "string style" <|
            \_ ->
                StrokeStyleValue (StringStyle "dashed")
                    |> exprToString
                    |> Expect.equal "StrokeStyle.StringStyle \"dashed\""
        ]


gradientTests : Test
gradientTests =
    describe "gradient"
        [ test "two stops" <|
            \_ ->
                GradientValue
                    [ { color = Color.srgb 1 0 0, position = 0 }
                    , { color = Color.srgb 0 0 1, position = 1 }
                    ]
                    |> exprToString
                    |> String.contains "position = 0"
                    |> Expect.equal True
        ]


typographyTests : Test
typographyTests =
    describe "typography"
        [ test "basic typography" <|
            \_ ->
                TypographyValue
                    { fontFamily = FontFamily.stack "Georgia" [ "serif" ]
                    , fontSize = Dimension.px 24
                    , fontWeight = Bold
                    , lineHeight = 1.2
                    , letterSpacing = Nothing
                    , paragraphSpacing = Nothing
                    }
                    |> exprToString
                    |> String.contains "FontFamily.stack \"Georgia\""
                    |> Expect.equal True
        ]


transitionTests : Test
transitionTests =
    describe "transition"
        [ test "basic transition" <|
            \_ ->
                TransitionValue
                    { duration = Duration.ms 200
                    , delay = Nothing
                    , timingFunction = CubicBezierFunction { p1x = 0.42, p1y = 0, p2x = 0.58, p2y = 1 }
                    }
                    |> exprToString
                    |> String.contains "Duration.ms 200"
                    |> Expect.equal True
        ]



-- HELPER


exprToString : TokenValue -> String
exprToString tokenValue =
    let
        expr : CG.Expression
        expr =
            Expression.tokenValueToExpression tokenValue

        decl : CG.Declaration
        decl =
            CG.valDecl Nothing Nothing "_x" expr

        file : CG.File
        file =
            CG.file (CG.normalModule [ "X" ] []) [] [ decl ] Nothing

        rendered : String
        rendered =
            Elm.Pretty.pretty 120 file
    in
    -- Extract just the expression from the generated file
    -- The file looks like: "module X exposing (..)\n\n\n_x =\n    <expression>\n"
    rendered
        |> String.split "_x =\n    "
        |> List.drop 1
        |> String.join "_x =\n    "
        |> String.trimRight
