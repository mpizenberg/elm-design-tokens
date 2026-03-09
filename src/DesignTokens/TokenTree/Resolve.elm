module DesignTokens.TokenTree.Resolve exposing (resolve, ResolutionError(..))

{-| Resolve an unresolved token tree into a flat list of typed tokens.

This module handles:

1.  Flattening the tree with `$type` inheritance from parent groups
2.  Decoding literal values using the appropriate type-specific decoder
3.  Resolving alias references (with cycle detection)

@docs resolve, ResolutionError

-}

import DesignTokens.Token as Token exposing (Path, ResolvedToken, TokenMeta)
import DesignTokens.TokenTree exposing (RawGroup, RawToken, TokenTree(..), TreeNode(..), ValueOrAlias(..))
import Dict exposing (Dict)
import Json.Decode as Decode


{-| Errors that can occur during resolution.
-}
type ResolutionError
    = MissingType Path
    | UnknownType Path String
    | DecodeError Path String String
    | UnresolvedAlias Path Path
    | CircularReference (List Path)
    | ExtendsTargetNotFound Path Path
    | CircularExtends (List Path)


{-| Resolve a token tree into a flat list of resolved tokens.

Inherits `$type` from parent groups, decodes literal values, and resolves
alias references. Returns all errors encountered rather than stopping at
the first.

-}
resolve : TokenTree -> Result (List ResolutionError) (List ResolvedToken)
resolve (TokenTree rootGroup) =
    case resolveExtends rootGroup of
        Err extendsErrors ->
            Err extendsErrors

        Ok resolvedRoot ->
            let
                -- Pass 1: Flatten tree, inherit types
                flatResult : { tokens : Dict String FlatToken, errors : List ResolutionError }
                flatResult =
                    flattenGroup [] Nothing resolvedRoot

                -- Pass 2: Decode literals and resolve aliases
                resolveResult : { resolved : Dict String ResolvedToken, errors : List ResolutionError }
                resolveResult =
                    resolveFlat flatResult.tokens

                allErrors : List ResolutionError
                allErrors =
                    flatResult.errors ++ resolveResult.errors
            in
            if List.isEmpty allErrors then
                Ok (Dict.values resolveResult.resolved)

            else
                Err allErrors



-- PASS 1: FLATTEN WITH TYPE INHERITANCE


type alias FlatToken =
    { value : ValueOrAlias
    , typeName : String
    , meta : TokenMeta
    }


flattenGroup :
    Path
    -> Maybe String
    -> RawGroup
    -> { tokens : Dict String FlatToken, errors : List ResolutionError }
flattenGroup parentPath inheritedType group =
    let
        effectiveType : Maybe String
        effectiveType =
            case group.type_ of
                Just t ->
                    Just t

                Nothing ->
                    inheritedType
    in
    Dict.foldl
        (\key node acc ->
            case node of
                TokenNode rawToken ->
                    let
                        tokenPath : Path
                        tokenPath =
                            parentPath ++ [ key ]

                        result : { token : Maybe ( String, FlatToken ), error : Maybe ResolutionError }
                        result =
                            flattenToken tokenPath effectiveType rawToken

                        tokensWithRoot : Dict String FlatToken
                        tokensWithRoot =
                            case result.token of
                                Just ( pathKey, flatToken ) ->
                                    let
                                        base : Dict String FlatToken
                                        base =
                                            Dict.insert pathKey flatToken acc.tokens
                                    in
                                    -- $root tokens are also accessible via the parent path
                                    if key == "$root" then
                                        Dict.insert (pathToKey parentPath) flatToken base

                                    else
                                        base

                                Nothing ->
                                    acc.tokens
                    in
                    { tokens = tokensWithRoot
                    , errors =
                        case result.error of
                            Just err ->
                                err :: acc.errors

                            Nothing ->
                                acc.errors
                    }

                GroupNode subGroup ->
                    let
                        subPath : Path
                        subPath =
                            parentPath ++ [ key ]

                        subResult :
                            { tokens : Dict String FlatToken
                            , errors : List ResolutionError
                            }
                        subResult =
                            flattenGroup subPath effectiveType subGroup
                    in
                    { tokens = Dict.union subResult.tokens acc.tokens
                    , errors = subResult.errors ++ acc.errors
                    }
        )
        { tokens = Dict.empty, errors = [] }
        group.children


flattenToken :
    Path
    -> Maybe String
    -> RawToken
    -> { token : Maybe ( String, FlatToken ), error : Maybe ResolutionError }
flattenToken path inheritedType rawToken =
    let
        effectiveType : Maybe String
        effectiveType =
            case rawToken.type_ of
                Just t ->
                    Just t

                Nothing ->
                    inheritedType
    in
    case effectiveType of
        Nothing ->
            { token = Nothing
            , error = Just (MissingType path)
            }

        Just typeName ->
            let
                meta : TokenMeta
                meta =
                    { description = rawToken.description
                    , extensions = rawToken.extensions
                    , deprecated = rawToken.deprecated
                    }

                pathKey : String
                pathKey =
                    pathToKey path
            in
            { token =
                Just
                    ( pathKey
                    , { value = rawToken.value
                      , typeName = typeName
                      , meta = meta
                      }
                    )
            , error = Nothing
            }



-- PASS 2: DECODE LITERALS AND RESOLVE ALIASES


resolveFlat :
    Dict String FlatToken
    -> { resolved : Dict String ResolvedToken, errors : List ResolutionError }
resolveFlat flatTokens =
    let
        -- Partition into literals and aliases
        partitioned :
            { literals : List ( String, FlatToken )
            , aliases : List ( String, FlatToken )
            }
        partitioned =
            Dict.foldl
                (\key token acc ->
                    case token.value of
                        Literal _ ->
                            { acc | literals = ( key, token ) :: acc.literals }

                        Alias _ ->
                            { acc | aliases = ( key, token ) :: acc.aliases }
                )
                { literals = [], aliases = [] }
                flatTokens

        -- Decode all literals
        decodedResult :
            { resolved : Dict String ResolvedToken
            , errors : List ResolutionError
            }
        decodedResult =
            List.foldl decodeLiteral
                { resolved = Dict.empty, errors = [] }
                partitioned.literals
    in
    -- Resolve aliases iteratively
    resolveAliases
        (Dict.fromList partitioned.aliases)
        flatTokens
        decodedResult


decodeLiteral :
    ( String, FlatToken )
    -> { resolved : Dict String ResolvedToken, errors : List ResolutionError }
    -> { resolved : Dict String ResolvedToken, errors : List ResolutionError }
decodeLiteral ( pathKey, flatToken ) acc =
    case flatToken.value of
        Literal jsonValue ->
            let
                path : Path
                path =
                    keyToPath pathKey
            in
            if not (isKnownType flatToken.typeName) then
                { resolved = acc.resolved
                , errors = UnknownType path flatToken.typeName :: acc.errors
                }

            else
                case Decode.decodeValue (Token.tokenValueDecoder flatToken.typeName) jsonValue of
                    Ok tokenValue ->
                        { resolved =
                            Dict.insert pathKey
                                { path = path
                                , typeName = flatToken.typeName
                                , value = tokenValue
                                , aliasOf = Nothing
                                , meta = flatToken.meta
                                }
                                acc.resolved
                        , errors = acc.errors
                        }

                    Err err ->
                        { resolved = acc.resolved
                        , errors = DecodeError path flatToken.typeName (Decode.errorToString err) :: acc.errors
                        }

        Alias _ ->
            acc


isKnownType : String -> Bool
isKnownType typeName =
    List.member typeName
        [ "color"
        , "dimension"
        , "fontFamily"
        , "fontWeight"
        , "duration"
        , "cubicBezier"
        , "number"
        , "string"
        , "boolean"
        , "shadow"
        , "border"
        , "strokeStyle"
        , "gradient"
        , "typography"
        , "transition"
        ]


resolveAliases :
    Dict String FlatToken
    -> Dict String FlatToken
    -> { resolved : Dict String ResolvedToken, errors : List ResolutionError }
    -> { resolved : Dict String ResolvedToken, errors : List ResolutionError }
resolveAliases unresolved allFlat acc =
    if Dict.isEmpty unresolved then
        acc

    else
        let
            iterResult :
                { stillUnresolved : Dict String FlatToken
                , resolved : Dict String ResolvedToken
                , errors : List ResolutionError
                , madeProgress : Bool
                }
            iterResult =
                Dict.foldl
                    (\pathKey flatToken iterAcc ->
                        case flatToken.value of
                            Alias targetPath ->
                                let
                                    targetKey : String
                                    targetKey =
                                        pathToKey targetPath
                                in
                                case Dict.get targetKey iterAcc.resolved of
                                    Just resolvedTarget ->
                                        { iterAcc
                                            | resolved =
                                                Dict.insert pathKey
                                                    { path = keyToPath pathKey
                                                    , typeName = flatToken.typeName
                                                    , value = resolvedTarget.value
                                                    , aliasOf = Just targetPath
                                                    , meta = flatToken.meta
                                                    }
                                                    iterAcc.resolved
                                            , madeProgress = True
                                        }

                                    Nothing ->
                                        if Dict.member targetKey allFlat then
                                            -- Target exists but not yet resolved
                                            { iterAcc
                                                | stillUnresolved =
                                                    Dict.insert pathKey flatToken iterAcc.stillUnresolved
                                            }

                                        else
                                            -- Target doesn't exist at all
                                            { iterAcc
                                                | errors =
                                                    UnresolvedAlias (keyToPath pathKey) targetPath :: iterAcc.errors
                                            }

                            Literal _ ->
                                -- Should not happen
                                iterAcc
                    )
                    { stillUnresolved = Dict.empty
                    , resolved = acc.resolved
                    , errors = acc.errors
                    , madeProgress = False
                    }
                    unresolved
        in
        if iterResult.madeProgress then
            -- Continue resolving
            resolveAliases iterResult.stillUnresolved
                allFlat
                { resolved = iterResult.resolved
                , errors = iterResult.errors
                }

        else
            -- No progress — remaining are circular references
            let
                cycleErrors : List ResolutionError
                cycleErrors =
                    detectCycles iterResult.stillUnresolved
            in
            { resolved = iterResult.resolved
            , errors = iterResult.errors ++ cycleErrors
            }


detectCycles : Dict String FlatToken -> List ResolutionError
detectCycles unresolved =
    if Dict.isEmpty unresolved then
        []

    else
        -- All remaining unresolved aliases form cycles
        -- Report one CircularReference error with all participants
        let
            cyclePaths : List Path
            cyclePaths =
                Dict.keys unresolved
                    |> List.map keyToPath
        in
        [ CircularReference cyclePaths ]



-- RESOLVE $EXTENDS PRE-PASS


{-| Resolve all `$extends` in the tree via iterative deep merge.

Groups with `$extends` inherit children (and metadata) from their target group.
The extending group's own values override the target's. Resolution is iterative
to support chained extends (A extends B extends C).

-}
resolveExtends : RawGroup -> Result (List ResolutionError) RawGroup
resolveExtends rootGroup =
    let
        pending : List ( Path, Path )
        pending =
            collectExtends [] rootGroup
    in
    resolveExtendsLoop rootGroup pending


resolveExtendsLoop :
    RawGroup
    -> List ( Path, Path )
    -> Result (List ResolutionError) RawGroup
resolveExtendsLoop rootGroup pending =
    if List.isEmpty pending then
        Ok rootGroup

    else
        let
            result :
                { newRoot : RawGroup
                , stillPending : List ( Path, Path )
                , errors : List ResolutionError
                , madeProgress : Bool
                }
            result =
                List.foldl
                    (\( groupPath, targetPath ) acc ->
                        case lookupGroup targetPath acc.newRoot of
                            Nothing ->
                                { acc
                                    | errors =
                                        ExtendsTargetNotFound groupPath targetPath :: acc.errors
                                }

                            Just targetGroup ->
                                if targetGroup.extends /= Nothing then
                                    -- Target still has unresolved $extends, defer
                                    { acc
                                        | stillPending =
                                            ( groupPath, targetPath ) :: acc.stillPending
                                    }

                                else
                                    case lookupGroup groupPath acc.newRoot of
                                        Nothing ->
                                            -- Extending group disappeared (shouldn't happen)
                                            acc

                                        Just extendingGroup ->
                                            let
                                                merged : RawGroup
                                                merged =
                                                    deepMerge targetGroup extendingGroup
                                            in
                                            { acc
                                                | newRoot = setGroup groupPath merged acc.newRoot
                                                , madeProgress = True
                                            }
                    )
                    { newRoot = rootGroup
                    , stillPending = []
                    , errors = []
                    , madeProgress = False
                    }
                    pending
        in
        if not (List.isEmpty result.errors) then
            Err result.errors

        else if result.madeProgress then
            resolveExtendsLoop result.newRoot result.stillPending

        else
            -- No progress — remaining are circular
            Err
                (List.map (\( groupPath, _ ) -> CircularExtends [ groupPath ]) result.stillPending)


{-| Collect all groups that have `$extends`, returning (groupPath, targetPath) pairs.
-}
collectExtends : Path -> RawGroup -> List ( Path, Path )
collectExtends parentPath group =
    Dict.foldl
        (\key node acc ->
            case node of
                GroupNode subGroup ->
                    let
                        subPath : Path
                        subPath =
                            parentPath ++ [ key ]

                        fromSub : List ( Path, Path )
                        fromSub =
                            collectExtends subPath subGroup
                    in
                    case subGroup.extends of
                        Just targetPath ->
                            ( subPath, targetPath ) :: fromSub ++ acc

                        Nothing ->
                            fromSub ++ acc

                TokenNode _ ->
                    acc
        )
        []
        group.children


{-| Look up a group at the given path in the tree.
-}
lookupGroup : Path -> RawGroup -> Maybe RawGroup
lookupGroup path root =
    case path of
        [] ->
            Just root

        segment :: rest ->
            case Dict.get segment root.children of
                Just (GroupNode subGroup) ->
                    lookupGroup rest subGroup

                _ ->
                    Nothing


{-| Replace the group at the given path in the tree.
-}
setGroup : Path -> RawGroup -> RawGroup -> RawGroup
setGroup path newGroup root =
    case path of
        [] ->
            newGroup

        [ segment ] ->
            { root | children = Dict.insert segment (GroupNode newGroup) root.children }

        segment :: rest ->
            case Dict.get segment root.children of
                Just (GroupNode subGroup) ->
                    { root
                        | children =
                            Dict.insert segment
                                (GroupNode (setGroup rest newGroup subGroup))
                                root.children
                    }

                _ ->
                    -- Path doesn't exist; shouldn't happen if collectExtends was correct
                    root


{-| Deep merge two groups: base (target) and override (extending group).

Override values win for metadata. Children are merged recursively:
both groups → recurse, otherwise override wins.

-}
deepMerge : RawGroup -> RawGroup -> RawGroup
deepMerge base override =
    { type_ =
        case override.type_ of
            Just _ ->
                override.type_

            Nothing ->
                base.type_
    , description =
        case override.description of
            Just _ ->
                override.description

            Nothing ->
                base.description
    , extensions =
        case override.extensions of
            Just _ ->
                override.extensions

            Nothing ->
                base.extensions
    , deprecated =
        case override.deprecated of
            Just _ ->
                override.deprecated

            Nothing ->
                base.deprecated
    , extends = Nothing
    , children =
        Dict.merge
            (\key baseNode acc -> Dict.insert key baseNode acc)
            (\key baseNode overrideNode acc ->
                case ( baseNode, overrideNode ) of
                    ( GroupNode baseGroup, GroupNode overrideGroup ) ->
                        Dict.insert key (GroupNode (deepMerge baseGroup overrideGroup)) acc

                    _ ->
                        -- Override wins (token overrides token, or token overrides group, etc.)
                        Dict.insert key overrideNode acc
            )
            (\key overrideNode acc -> Dict.insert key overrideNode acc)
            base.children
            override.children
            Dict.empty
    }



-- PATH KEY HELPERS
-- We use "." joined strings as Dict keys for convenience


pathToKey : Path -> String
pathToKey path =
    String.join "." path


keyToPath : String -> Path
keyToPath key =
    String.split "." key
