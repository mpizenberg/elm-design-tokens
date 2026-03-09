module DesignTokens.TransitionTest exposing (suite)

import DesignTokens.CubicBezier as CubicBezier
import DesignTokens.Duration as Duration
import DesignTokens.Transition as Transition exposing (TimingFunction(..), Transition)
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "DesignTokens.Transition"
        [ decoderTests
        , roundTripTests
        , cssTests
        ]


sampleWithCubicBezier : Transition
sampleWithCubicBezier =
    { duration = Duration.ms 200
    , delay = Nothing
    , timingFunction = CubicBezierFunction { p1x = 0.5, p1y = 0, p2x = 1, p2y = 1 }
    }


sampleWithStep : Transition
sampleWithStep =
    { duration = Duration.ms 300
    , delay = Just (Duration.ms 50)
    , timingFunction = StepFunction "ease-in"
    }


decoderTests : Test
decoderTests =
    describe "decoder"
        [ test "decodes with cubic bezier" <|
            \_ ->
                """{"duration":{"value":200,"unit":"ms"},"timingFunction":[0.5,0,1,1]}"""
                    |> Decode.decodeString Transition.decoder
                    |> Expect.equal (Ok sampleWithCubicBezier)
        , test "decodes with string timing function" <|
            \_ ->
                """{"duration":{"value":300,"unit":"ms"},"delay":{"value":50,"unit":"ms"},"timingFunction":"ease-in"}"""
                    |> Decode.decodeString Transition.decoder
                    |> Expect.equal (Ok sampleWithStep)
        ]


roundTripTests : Test
roundTripTests =
    describe "round-trip"
        [ test "cubic bezier round-trips" <|
            \_ ->
                sampleWithCubicBezier
                    |> Transition.encode
                    |> Decode.decodeValue Transition.decoder
                    |> Expect.equal (Ok sampleWithCubicBezier)
        , test "step function round-trips" <|
            \_ ->
                sampleWithStep
                    |> Transition.encode
                    |> Decode.decodeValue Transition.decoder
                    |> Expect.equal (Ok sampleWithStep)
        ]


cssTests : Test
cssTests =
    describe "toCssString"
        [ test "with cubic bezier, no delay" <|
            \_ ->
                Transition.toCssString sampleWithCubicBezier
                    |> Expect.equal "200ms cubic-bezier(0.5, 0, 1, 1)"
        , test "with step function and delay" <|
            \_ ->
                Transition.toCssString sampleWithStep
                    |> Expect.equal "300ms ease-in 50ms"
        ]
