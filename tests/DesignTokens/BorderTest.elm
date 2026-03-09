module DesignTokens.BorderTest exposing (suite)

import DesignTokens.Border as Border exposing (Border)
import DesignTokens.Color as Color
import DesignTokens.Dimension as Dimension
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.Border"
        [ decoderTests
        , roundTripTests
        , cssTests
        ]


sampleBorder : Border
sampleBorder =
    { color = Color.srgb 0 0 0
    , width = Dimension.px 1
    , style = "solid"
    }


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes border" <|
            \_ ->
                """{"color":{"colorSpace":"srgb","components":[0,0,0]},"width":{"value":1,"unit":"px"},"style":"solid"}"""
                    |> Decode.decodeString Border.decoder
                    |> Expect.equal (Ok sampleBorder)
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "encode >> decode is identity" <|
            \_ ->
                sampleBorder
                    |> Border.encode
                    |> Decode.decodeValue Border.decoder
                    |> Expect.equal (Ok sampleBorder)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "formats as border shorthand" <|
            \_ ->
                Border.toCssString sampleBorder
                    |> Expect.equal "1px solid color(srgb 0 0 0)"
        ]
