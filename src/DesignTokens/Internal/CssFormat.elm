module DesignTokens.Internal.CssFormat exposing (formatFloat)

{-| Internal helper for formatting floats in CSS output.
-}


{-| Format a float for CSS output, trimming trailing zeros
and limiting to 6 decimal places.

    formatFloat 16 == "16"

    formatFloat 1.5 == "1.5"

    formatFloat 0.30000000000000004 == "0.3"

-}
formatFloat : Float -> String
formatFloat f =
    if f == toFloat (round f) then
        String.fromInt (round f)

    else
        let
            -- Multiply by 1e6, round, then work back
            scaled =
                round (f * 1000000)

            isNegative =
                scaled < 0

            absScaled =
                abs scaled

            intPart =
                absScaled // 1000000

            fracPart =
                remainderBy 1000000 absScaled

            fracStr =
                String.fromInt fracPart
                    |> String.padLeft 6 '0'
                    |> trimTrailingZeros

            sign =
                if isNegative then
                    "-"

                else
                    ""
        in
        if fracStr == "" then
            sign ++ String.fromInt intPart

        else
            sign ++ String.fromInt intPart ++ "." ++ fracStr


trimTrailingZeros : String -> String
trimTrailingZeros s =
    if String.endsWith "0" s then
        trimTrailingZeros (String.dropRight 1 s)

    else
        s
