module DesignTokens.TypographyTest exposing (suite)

import DesignTokens.Dimension as Dimension
import DesignTokens.FontFamily as FontFamily
import DesignTokens.FontWeight as FontWeight
import DesignTokens.Typography as Typography exposing (Typography)
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.Typography"
        [ decoderTests
        , roundTripTests
        , cssTests
        ]


sampleTypography : Typography
sampleTypography =
    { fontFamily = FontFamily.stack "Helvetica" [ "Arial", "sans-serif" ]
    , fontSize = Dimension.px 16
    , fontWeight = FontWeight.Normal
    , lineHeight = 1.5
    , letterSpacing = Nothing
    , paragraphSpacing = Nothing
    }


sampleWithSpacing : Typography
sampleWithSpacing =
    { sampleTypography
        | letterSpacing = Just (Dimension.px 0.5)
        , paragraphSpacing = Just (Dimension.px 16)
    }


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes typography without optional fields" <|
            \_ ->
                """{"fontFamily":["Helvetica","Arial","sans-serif"],"fontSize":{"value":16,"unit":"px"},"fontWeight":"normal","lineHeight":1.5}"""
                    |> Decode.decodeString Typography.decoder
                    |> Result.map (\t -> { family = FontFamily.toList t.fontFamily, size = t.fontSize, weight = t.fontWeight, lh = t.lineHeight, ls = t.letterSpacing, ps = t.paragraphSpacing })
                    |> Expect.equal
                        (Ok
                            { family = [ "Helvetica", "Arial", "sans-serif" ]
                            , size = Dimension.px 16
                            , weight = FontWeight.Normal
                            , lh = 1.5
                            , ls = Nothing
                            , ps = Nothing
                            }
                        )
        , test "decodes with optional spacing" <|
            \_ ->
                """{"fontFamily":"Helvetica","fontSize":{"value":16,"unit":"px"},"fontWeight":400,"lineHeight":1.5,"letterSpacing":{"value":0.5,"unit":"px"}}"""
                    |> Decode.decodeString Typography.decoder
                    |> Result.map .letterSpacing
                    |> Expect.equal (Ok (Just (Dimension.px 0.5)))
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "without spacing" <|
            \_ ->
                sampleTypography
                    |> Typography.encode
                    |> Decode.decodeValue Typography.decoder
                    |> Result.map (\t -> ( FontFamily.toList t.fontFamily, t.fontSize, t.lineHeight ))
                    |> Expect.equal (Ok ( [ "Helvetica", "Arial", "sans-serif" ], Dimension.px 16, 1.5 ))
        , test "with spacing" <|
            \_ ->
                sampleWithSpacing
                    |> Typography.encode
                    |> Decode.decodeValue Typography.decoder
                    |> Result.map (\t -> ( t.letterSpacing, t.paragraphSpacing ))
                    |> Expect.equal (Ok ( Just (Dimension.px 0.5), Just (Dimension.px 16) ))
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "font shorthand" <|
            \_ ->
                Typography.toCssString sampleTypography
                    |> Expect.equal "400 16px/1.5 \"Helvetica\", \"Arial\", \"sans-serif\""
        ]
