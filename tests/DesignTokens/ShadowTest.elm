module DesignTokens.ShadowTest exposing (suite)

import DesignTokens.Color as Color
import DesignTokens.Dimension as Dimension
import DesignTokens.Shadow as Shadow exposing (Shadow)
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.Shadow"
        [ decoderTests
        , roundTripTests
        , cssTests
        ]


sampleShadow : Shadow
sampleShadow =
    { color = Color.srgb 0 0 0
    , offsetX = Dimension.px 2
    , offsetY = Dimension.px 4
    , blur = Dimension.px 8
    , spread = Dimension.px 0
    }


sampleJson : String
sampleJson =
    """{"color":{"colorSpace":"srgb","components":[0,0,0]},"offsetX":{"value":2,"unit":"px"},"offsetY":{"value":4,"unit":"px"},"blur":{"value":8,"unit":"px"},"spread":{"value":0,"unit":"px"}}"""


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes shadow" <|
            \_ ->
                sampleJson
                    |> Decode.decodeString Shadow.decoder
                    |> Expect.equal (Ok sampleShadow)
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "encode >> decode is identity" <|
            \_ ->
                sampleShadow
                    |> Shadow.encode
                    |> Decode.decodeValue Shadow.decoder
                    |> Expect.equal (Ok sampleShadow)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "formats as box-shadow" <|
            \_ ->
                Shadow.toCssString sampleShadow
                    |> Expect.equal "2px 4px 8px 0px color(srgb 0 0 0)"
        ]
