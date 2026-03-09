port module Main exposing (main)

{-| CLI entry point. Receives .tokens.json content as flags,
parses and resolves tokens, generates Elm source, outputs via port.
-}

import DesignTokens.TokenTree as TokenTree
import DesignTokens.TokenTree.Resolve as Resolve exposing (ResolutionError(..))
import Generate
import Json.Decode as Decode


port output : String -> Cmd msg


port error : String -> Cmd msg


type alias Flags =
    { json : Decode.Value
    , moduleName : String
    }


main : Program Flags () ()
main =
    Platform.worker
        { init = init
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


init : Flags -> ( (), Cmd () )
init flags =
    let
        result : Result String String
        result =
            case TokenTree.fromJson flags.json of
                Err parseErrors ->
                    Err (formatParseErrors parseErrors)

                Ok tree ->
                    case Resolve.resolve tree of
                        Err resolveErrors ->
                            Err (formatResolveErrors resolveErrors)

                        Ok tokens ->
                            Ok (Generate.generateModule flags.moduleName tokens)
    in
    case result of
        Ok content ->
            ( (), output content )

        Err msg ->
            ( (), error msg )


formatParseErrors : List TokenTree.Error -> String
formatParseErrors errors =
    "Parse errors:\n"
        ++ String.join "\n"
            (List.map
                (\e ->
                    case e of
                        TokenTree.InvalidJson msg ->
                            "  Invalid JSON: " ++ msg

                        TokenTree.InvalidName name reason ->
                            "  Invalid name \"" ++ name ++ "\": " ++ reason
                )
                errors
            )


formatResolveErrors : List ResolutionError -> String
formatResolveErrors errors =
    "Resolution errors:\n"
        ++ String.join "\n"
            (List.map
                (\e ->
                    case e of
                        MissingType path ->
                            "  Missing $type for token: " ++ String.join "." path

                        UnknownType path typeName ->
                            "  Unknown type \"" ++ typeName ++ "\" for token: " ++ String.join "." path

                        DecodeError path typeName msg ->
                            "  Decode error for " ++ String.join "." path ++ " (type " ++ typeName ++ "): " ++ msg

                        UnresolvedAlias path targetPath ->
                            "  Unresolved alias: " ++ String.join "." path ++ " → " ++ String.join "." targetPath

                        CircularReference paths ->
                            "  Circular reference involving: " ++ String.join ", " (List.map (String.join ".") paths)
                )
                errors
            )
