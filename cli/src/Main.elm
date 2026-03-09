port module Main exposing (main)

{-| CLI entry point. Receives .tokens.json content as flags,
parses and resolves tokens, generates Elm source, outputs via port.

Supports two modes:

1.  Normal mode: `{ json, moduleName }` → flat constants module
2.  Theme mode: `{ variants: [{name, json}], moduleName }` → Theme record module

-}

import DesignTokens.Token exposing (ResolvedToken)
import DesignTokens.TokenTree as TokenTree
import DesignTokens.TokenTree.Resolve as Resolve exposing (ResolutionError(..))
import Generate
import Json.Decode as Decode


port output : String -> Cmd msg


port error : String -> Cmd msg


main : Program Decode.Value () ()
main =
    Platform.worker
        { init = init
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


init : Decode.Value -> ( (), Cmd () )
init flagsValue =
    let
        result : Result String String
        result =
            case decodeFlags flagsValue of
                Err decodeErr ->
                    Err ("Invalid flags: " ++ decodeErr)

                Ok (NormalMode { json, moduleName }) ->
                    processNormal moduleName json

                Ok (ThemeMode { variants, moduleName }) ->
                    processTheme moduleName variants
    in
    case result of
        Ok content ->
            ( (), output content )

        Err msg ->
            ( (), error msg )



-- FLAGS DECODING


type Flags
    = NormalMode { json : Decode.Value, moduleName : String }
    | ThemeMode { variants : List ( String, Decode.Value ), moduleName : String }


decodeFlags : Decode.Value -> Result String Flags
decodeFlags value =
    -- Try theme mode first (has "variants" key), then normal mode
    case Decode.decodeValue themeFlagsDecoder value of
        Ok flags ->
            Ok flags

        Err _ ->
            case Decode.decodeValue normalFlagsDecoder value of
                Ok flags ->
                    Ok flags

                Err err ->
                    Err (Decode.errorToString err)


normalFlagsDecoder : Decode.Decoder Flags
normalFlagsDecoder =
    Decode.map2 (\json modName -> NormalMode { json = json, moduleName = modName })
        (Decode.field "json" Decode.value)
        (Decode.field "moduleName" Decode.string)


themeFlagsDecoder : Decode.Decoder Flags
themeFlagsDecoder =
    Decode.map2 (\variants modName -> ThemeMode { variants = variants, moduleName = modName })
        (Decode.field "variants"
            (Decode.list
                (Decode.map2 Tuple.pair
                    (Decode.field "name" Decode.string)
                    (Decode.field "json" Decode.value)
                )
            )
        )
        (Decode.field "moduleName" Decode.string)



-- NORMAL MODE


processNormal : String -> Decode.Value -> Result String String
processNormal moduleName json =
    case parseAndResolve json of
        Err errMsg ->
            Err errMsg

        Ok tokens ->
            Ok (Generate.generateModule moduleName tokens)


parseAndResolve : Decode.Value -> Result String (List ResolvedToken)
parseAndResolve json =
    case TokenTree.fromJson json of
        Err parseErrors ->
            Err (formatParseErrors parseErrors)

        Ok tree ->
            case Resolve.resolve tree of
                Err resolveErrors ->
                    Err (formatResolveErrors resolveErrors)

                Ok tokens ->
                    Ok tokens



-- THEME MODE


processTheme : String -> List ( String, Decode.Value ) -> Result String String
processTheme moduleName variants =
    let
        resolvedVariants : Result String (List ( String, List ResolvedToken ))
        resolvedVariants =
            resolveAllVariants variants []
    in
    case resolvedVariants of
        Err errMsg ->
            Err errMsg

        Ok resolved ->
            Generate.generateThemeModule moduleName resolved


resolveAllVariants :
    List ( String, Decode.Value )
    -> List ( String, List ResolvedToken )
    -> Result String (List ( String, List ResolvedToken ))
resolveAllVariants remaining acc =
    case remaining of
        [] ->
            Ok (List.reverse acc)

        ( name, json ) :: rest ->
            case parseAndResolve json of
                Err errMsg ->
                    Err ("Error in variant \"" ++ name ++ "\":\n" ++ errMsg)

                Ok tokens ->
                    resolveAllVariants rest (( name, tokens ) :: acc)



-- ERROR FORMATTING


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

                        ExtendsTargetNotFound groupPath targetPath ->
                            "  $extends target not found: " ++ String.join "." groupPath ++ " extends " ++ String.join "." targetPath

                        CircularExtends paths ->
                            "  Circular $extends involving: " ++ String.join ", " (List.map (String.join ".") paths)
                )
                errors
            )
