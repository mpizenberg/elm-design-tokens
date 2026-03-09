module DesignTokens.Transition exposing
    ( Transition, TimingFunction(..)
    , decoder, encode
    , toCssString
    )

{-| DTCG Transition token type.

A transition combines a duration, an optional delay, and a timing function.

@docs Transition, TimingFunction
@docs decoder, encode
@docs toCssString

-}

import DesignTokens.CubicBezier as CubicBezier exposing (CubicBezier)
import DesignTokens.Duration as Duration exposing (Duration)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| A transition value.
-}
type alias Transition =
    { duration : Duration
    , delay : Maybe Duration
    , timingFunction : TimingFunction
    }


{-| A timing function for transitions.
-}
type TimingFunction
    = CubicBezierFunction CubicBezier
    | StepFunction String


{-| Decode a DTCG transition value.

The `timingFunction` field is decoded as a cubic bézier array first,
falling back to a string.

-}
decoder : Decoder Transition
decoder =
    Decode.map3 Transition
        (Decode.field "duration" Duration.decoder)
        (Decode.maybe (Decode.field "delay" Duration.decoder))
        (Decode.field "timingFunction" timingFunctionDecoder)


timingFunctionDecoder : Decoder TimingFunction
timingFunctionDecoder =
    Decode.oneOf
        [ CubicBezier.decoder |> Decode.map CubicBezierFunction
        , Decode.string |> Decode.map StepFunction
        ]


{-| Encode a transition to DTCG JSON.
-}
encode : Transition -> Encode.Value
encode transition =
    Encode.object
        ([ ( "duration", Duration.encode transition.duration )
         , ( "timingFunction", encodeTimingFunction transition.timingFunction )
         ]
            ++ (case transition.delay of
                    Just delay ->
                        [ ( "delay", Duration.encode delay ) ]

                    Nothing ->
                        []
               )
        )


encodeTimingFunction : TimingFunction -> Encode.Value
encodeTimingFunction tf =
    case tf of
        CubicBezierFunction cb ->
            CubicBezier.encode cb

        StepFunction s ->
            Encode.string s


{-| Convert a transition to a CSS string.

    toCssString { duration = Duration.ms 200, delay = Nothing, timingFunction = StepFunction "ease-in" }
        == "200ms ease-in"

    toCssString { duration = Duration.ms 200, delay = Just (Duration.ms 50), timingFunction = CubicBezierFunction { p1x = 0.5, p1y = 0, p2x = 1, p2y = 1 } }
        == "200ms cubic-bezier(0.5, 0, 1, 1) 50ms"

-}
toCssString : Transition -> String
toCssString transition =
    let
        durationStr =
            Duration.toCssString transition.duration

        tfStr =
            case transition.timingFunction of
                CubicBezierFunction cb ->
                    CubicBezier.toCssString cb

                StepFunction s ->
                    s

        delayStr =
            case transition.delay of
                Just delay ->
                    " " ++ Duration.toCssString delay

                Nothing ->
                    ""
    in
    durationStr ++ " " ++ tfStr ++ delayStr
