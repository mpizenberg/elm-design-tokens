module DesignTokens.TokenTree exposing
    ( TokenTree(..), RawGroup, RawToken, TreeNode(..), ValueOrAlias(..), Error(..)
    , fromJson
    )

{-| Parse raw DTCG JSON into an unresolved token tree.

This module handles the first stage of DTCG file processing: parsing the
JSON structure into groups and tokens, detecting alias references, and
validating names. Type inheritance and alias resolution happen in
`DesignTokens.TokenTree.Resolve`.

@docs TokenTree, RawGroup, RawToken, TreeNode, ValueOrAlias, Error
@docs fromJson

-}

import DesignTokens.Token exposing (Deprecated(..), Path)
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)


{-| A parsed but unresolved DTCG token tree.
-}
type TokenTree
    = TokenTree RawGroup


{-| A group node with optional metadata and child nodes.
-}
type alias RawGroup =
    { type_ : Maybe String
    , description : Maybe String
    , extensions : Maybe Decode.Value
    , deprecated : Maybe Deprecated
    , children : Dict String TreeNode
    }


{-| A child in the tree: either a token or a nested group.
-}
type TreeNode
    = TokenNode RawToken
    | GroupNode RawGroup


{-| A raw token with its value (literal or alias) and optional metadata.
-}
type alias RawToken =
    { value : ValueOrAlias
    , type_ : Maybe String
    , description : Maybe String
    , extensions : Maybe Decode.Value
    , deprecated : Maybe Deprecated
    }


{-| A token's value before resolution: either a literal JSON value
or an alias reference to another token.
-}
type ValueOrAlias
    = Literal Decode.Value
    | Alias Path


{-| Errors that can occur during parsing.
-}
type Error
    = InvalidJson String
    | InvalidName String String


{-| Parse a raw JSON value into an unresolved token tree.

    import Json.Decode as Decode
    import Json.Encode as Encode

    -- Simple token
    """{"brand":{"$type":"color","$value":{"colorSpace":"srgb","components":[1,0,0]}}}"""
        |> Decode.decodeString Decode.value
        |> Result.andThen fromJson

-}
fromJson : Decode.Value -> Result (List Error) TokenTree
fromJson json =
    case Decode.decodeValue groupDecoder json of
        Ok group ->
            Ok (TokenTree group)

        Err err ->
            Err [ InvalidJson (Decode.errorToString err) ]



-- INTERNAL DECODERS


groupDecoder : Decoder RawGroup
groupDecoder =
    Decode.keyValuePairs Decode.value
        |> Decode.andThen parseGroupEntries


parseGroupEntries : List ( String, Decode.Value ) -> Decoder RawGroup
parseGroupEntries entries =
    let
        fold :
            ( String, Decode.Value )
            -> Decoder { type_ : Maybe String, description : Maybe String, extensions : Maybe Decode.Value, deprecated : Maybe Deprecated, children : List ( String, TreeNode ) }
            -> Decoder { type_ : Maybe String, description : Maybe String, extensions : Maybe Decode.Value, deprecated : Maybe Deprecated, children : List ( String, TreeNode ) }
        fold ( key, val ) accDecoder =
            accDecoder
                |> Decode.andThen
                    (\acc ->
                        if key == "$type" then
                            case Decode.decodeValue Decode.string val of
                                Ok t ->
                                    Decode.succeed { acc | type_ = Just t }

                                Err _ ->
                                    Decode.fail "$type must be a string"

                        else if key == "$description" then
                            case Decode.decodeValue Decode.string val of
                                Ok d ->
                                    Decode.succeed { acc | description = Just d }

                                Err _ ->
                                    Decode.fail "$description must be a string"

                        else if key == "$extensions" then
                            Decode.succeed { acc | extensions = Just val }

                        else if key == "$deprecated" then
                            case Decode.decodeValue deprecatedDecoder_ val of
                                Ok d ->
                                    Decode.succeed { acc | deprecated = Just d }

                                Err _ ->
                                    Decode.fail "$deprecated must be a boolean or string"

                        else if key == "$extends" then
                            -- Store but don't resolve; Phase 3 handles $extends
                            Decode.succeed acc

                        else if key == "$root" then
                            -- $root allows a group to also be a token
                            parseNode val
                                |> Decode.map
                                    (\node ->
                                        { acc | children = ( "$root", node ) :: acc.children }
                                    )

                        else if String.startsWith "$" key then
                            -- Skip unknown $ properties (forward-compatible)
                            Decode.succeed acc

                        else
                            case validateName key of
                                Err reason ->
                                    Decode.fail ("Invalid name \"" ++ key ++ "\": " ++ reason)

                                Ok _ ->
                                    parseNode val
                                        |> Decode.map
                                            (\node ->
                                                { acc | children = ( key, node ) :: acc.children }
                                            )
                    )

        initial :
            Decoder
                { type_ : Maybe String
                , description : Maybe String
                , extensions : Maybe Decode.Value
                , deprecated : Maybe Deprecated
                , children : List ( String, TreeNode )
                }
        initial =
            Decode.succeed
                { type_ = Nothing
                , description = Nothing
                , extensions = Nothing
                , deprecated = Nothing
                , children = []
                }
    in
    List.foldl fold initial entries
        |> Decode.map
            (\acc ->
                { type_ = acc.type_
                , description = acc.description
                , extensions = acc.extensions
                , deprecated = acc.deprecated
                , children = Dict.fromList acc.children
                }
            )


parseNode : Decode.Value -> Decoder TreeNode
parseNode val =
    -- Check if the object has a $value key → token; otherwise → group
    case Decode.decodeValue (Decode.field "$value" Decode.value) val of
        Ok valueJson ->
            parseTokenFromParts val valueJson
                |> Decode.map TokenNode

        Err _ ->
            -- It's a group
            case Decode.decodeValue groupDecoder val of
                Ok group ->
                    Decode.succeed (GroupNode group)

                Err err ->
                    Decode.fail (Decode.errorToString err)


parseTokenFromParts : Decode.Value -> Decode.Value -> Decoder RawToken
parseTokenFromParts fullObj valueJson =
    let
        valueOrAlias : ValueOrAlias
        valueOrAlias =
            parseValueOrAlias valueJson

        type_ : Maybe String
        type_ =
            Decode.decodeValue (Decode.field "$type" Decode.string) fullObj
                |> Result.toMaybe

        description : Maybe String
        description =
            Decode.decodeValue (Decode.field "$description" Decode.string) fullObj
                |> Result.toMaybe

        extensions : Maybe Decode.Value
        extensions =
            Decode.decodeValue (Decode.field "$extensions" Decode.value) fullObj
                |> Result.toMaybe

        deprecated : Maybe Deprecated
        deprecated =
            Decode.decodeValue (Decode.field "$deprecated" deprecatedDecoder_) fullObj
                |> Result.toMaybe
    in
    Decode.succeed
        { value = valueOrAlias
        , type_ = type_
        , description = description
        , extensions = extensions
        , deprecated = deprecated
        }


parseValueOrAlias : Decode.Value -> ValueOrAlias
parseValueOrAlias val =
    case Decode.decodeValue Decode.string val of
        Ok s ->
            if isAliasString s then
                Alias (parseAliasPath s)

            else
                Literal val

        Err _ ->
            Literal val


isAliasString : String -> Bool
isAliasString s =
    String.startsWith "{" s
        && String.endsWith "}" s
        && (String.length s > 2)
        && not (String.contains "{" (String.dropLeft 1 (String.dropRight 1 s)))
        && not (String.contains "}" (String.dropLeft 1 (String.dropRight 1 s)))


parseAliasPath : String -> Path
parseAliasPath s =
    s
        |> String.dropLeft 1
        |> String.dropRight 1
        |> String.split "."


validateName : String -> Result String ()
validateName name =
    if String.startsWith "$" name then
        Err "name cannot start with $"

    else if String.contains "." name then
        Err "name cannot contain ."

    else if String.contains "{" name then
        Err "name cannot contain {"

    else if String.contains "}" name then
        Err "name cannot contain }"

    else
        Ok ()


deprecatedDecoder_ : Decoder Deprecated
deprecatedDecoder_ =
    Decode.oneOf
        [ Decode.map DeprecatedBool Decode.bool
        , Decode.map DeprecatedMessage Decode.string
        ]
