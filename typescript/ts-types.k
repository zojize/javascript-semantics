module TS-TYPES-SYNTAX

imports ID-SYNTAX

syntax Type ::= AnyType
              | UnknownType
              | NeverType
              | VoidType
              | ObjectType
              | StringType
              | NumberType
              | BooleanType
              | SymbolType
              | BigIntType
              | ObjectLiteralType
              | Id
              | Id "<" TypeArgs ">"
              | "(" Type ")" [bracket]
              > left:
                Type "&" Type
              > Type "|" Type

syntax AnyType     ::= "any"
syntax UnknownType ::= "unknown"
syntax NeverType   ::= "never"
syntax VoidType    ::= "void"
syntax ObjectType  ::= "object"
syntax StringType  ::= "string"
syntax NumberType  ::= "number"
syntax BooleanType ::= "boolean"
syntax SymbolType  ::= "symbol"
syntax BigIntType  ::= "bigint"

syntax ObjectLiteralType ::= "{" PropertySignatures "}"
syntax PropertySignature ::= Id ":" Type
                           | Id "?" ":" Type
                           | "readonly" Id ":" Type
                           | "readonly" Id "?" ":" Type
syntax PropertySignatures ::= List{PropertySignature, ","}

syntax TypeVars ::= NeList{Id, ","}
syntax TypeArgs ::= NeList{Type, ","}
syntax TypeAliasDeclaration ::= "type" Id "=" Type ";"
                              | "type" Id "<" TypeVars ">" "=" Type ";"

syntax IsAssignableTo ::= Type "<:" Type ";"
syntax Stmt ::= TypeAliasDeclaration
              | IsAssignableTo
syntax Pgm ::= List{Stmt, ""}
endmodule

module TS-TYPES

imports BOOL
imports private MAP
imports private SET
imports LIST
imports private K-EQUAL
imports TS-TYPES-SYNTAX

configuration
  <k> $PGM:Pgm </k>
  // List<Record<Id, Type>>
  <tenv> ListItem(.Map) </tenv>
  <results> .List </results>

// Schedule: turn a flat list of statements into K sequence
rule <k> S:Stmt P:Pgm => S ~> P </k>
rule <k> .Pgm => .K </k>
rule <k> K:K ~> .Pgm => K </k>

// results are collected as a List of Bool in <results>
// Pretty unparse + constructor for results
syntax KItem ::= Type "<:" Type "=" Bool
syntax KItem ::= "check" "(" Type "," Type ")"
syntax KItem ::= "resolveL" "(" Type "," Type ")"
syntax KItem ::= "resolveR" "(" Type "," Type ")"

// Type aliasing: update env and drop the statement
rule <k> type Name = Type ; ~> K:K => K </k>
  <tenv> ListItem(M:Map) => ListItem(M [ Name <- Type ]) ... </tenv>
rule <k> type Name < Vars:TypeVars > = Type ; ~> K:K => K </k>
  <tenv> ListItem(M:Map) => ListItem(M [ Name <- GenericType(Vars, Type) ]) ... </tenv>

syntax TypeAnnotations ::= "optional" [token]
                         | "readonly" [token]
syntax Type ::= "AnnotatedType" "(" Type "," Set ")"
syntax Type ::= "PropertySignatureType" "(" Type "," Set ")"
//                                          ^Type    ^Modifiers
syntax Type ::= "ObjectType" "(" Map ")" // TODO: index signatures
syntax Type ::= "GenericType" "(" TypeVars "," Type ")"

// TODO: implement normalization of union and intersection types, see below
// function getNormalizedUnionOrIntersectionType(type: UnionOrIntersectionType, writing: boolean) {
//     const reduced = getReducedType(type);
//     if (reduced !== type) {
//         return reduced;
//     }
//     if (type.flags & TypeFlags.Intersection && shouldNormalizeIntersection(type as IntersectionType)) {
//         // Normalization handles cases like
//         // Partial<T>[K] & ({} | null) ==>
//         // Partial<T>[K] & {} | Partial<T>[K] & null ==>
//         // (T[K] | undefined) & {} | (T[K] | undefined) & null ==>
//         // T[K] & {} | undefined & {} | T[K] & null | undefined & null ==>
//         // T[K] & {} | T[K] & null
//         const normalizedTypes = sameMap(type.types, t => getNormalizedType(t, writing));
//         if (normalizedTypes !== type.types) {
//             return getIntersectionType(normalizedTypes);
//         }
//     }
//     return type;
// }
// Normalization to internal representation
syntax Type ::= "normalize" "(" Type ")" [function]
rule normalize(T:Type) => T [owise]
rule normalize({ PS:PropertySignatures }) => ObjectType(foldProps(PS, .Map))

// Normalize object literal types by folding property signatures
syntax Map ::= "foldProps" "(" PropertySignatures "," Map ")" [function]
rule foldProps(.PropertySignatures, M:Map) => M
rule foldProps(P:PropertySignature, PS:PropertySignatures, M:Map) => foldProps(PS, addProp(P, M))

// Build ObjectType from up to two properties for now (enough for basic tests)
syntax Map ::= "addProp" "(" PropertySignature "," Map ")" [function]
rule addProp(          N:Id  : T:Type, M:Map) => M [ N <- PropertySignatureType(T, .Set) ]
rule addProp( readonly N:Id  : T:Type, M:Map) => M [ N <- PropertySignatureType(T, SetItem(readonly)) ]
rule addProp(          N:Id ?: T:Type, M:Map) => M [ N <- PropertySignatureType(T, SetItem(optional)) ]
rule addProp( readonly N:Id ?: T:Type, M:Map) => M [ N <- PropertySignatureType(T, SetItem(optional) |Set SetItem(readonly)) ]

// Pretty printing helpers: convert internal ObjectType(Map) back to { ... }
syntax Type ::= "ppType" "(" Type ")" [function]
rule ppType(ObjectType(M:Map)) => { props(M) }
rule ppType(T:Type) => T [owise]

syntax PropertySignatures ::= "props" "(" Map ")" [function]
rule props(.Map) => .PropertySignatures
// Single-entry map: emit just one property without a trailing unit
rule props((N:Id |-> PropertySignatureType(T:Type, Mods:Set)) .Map)
  => toPropSignature(N, ppType(T), Mods)
// Multiple entries: emit head, then recurse
rule props((N:Id |-> PropertySignatureType(T:Type, Mods:Set)) M:Map)
  => toPropSignature(N, ppType(T), Mods), props(M)
  requires M =/=K .Map

syntax PropertySignature ::= "toPropSignature" "(" Id "," Type "," Set ")" [function]
rule toPropSignature(N:Id, T:Type, Mods:Set) => readonly N ?: T
  requires hasModifier(Mods, readonly) andBool hasModifier(Mods, optional)
rule toPropSignature(N:Id, T:Type, Mods:Set) => readonly N : T
  requires hasModifier(Mods, readonly) andBool notBool hasModifier(Mods, optional)
rule toPropSignature(N:Id, T:Type, Mods:Set) => N ?: T
  requires notBool hasModifier(Mods, readonly) andBool hasModifier(Mods, optional)
rule toPropSignature(N:Id, T:Type, Mods:Set) => N : T
  requires notBool hasModifier(Mods, readonly) andBool notBool hasModifier(Mods, optional)


// Structured capture of boolean results with their LHS/RHS types (prettified)
syntax KItem ::= "pushResult" "(" Type "," Type "," Bool ")"
rule <k> pushResult(T1:Type, T2:Type, B:Bool) ~> K:K => K </k>
  <results> R:List => R ListItem(ppType(T1) <: ppType(T2) = B) </results>

syntax Type ::= "lookupType" "(" Id "," List ")" [function]
rule lookupType(Name:Id, ListItem(Name |-> T) _) => T 
rule lookupType(Name:Id, ListItem(_:Map) Tail:List) => lookupType(Name, Tail)

rule <k> Name:Id => lookupType(Name, Env) ... </k>
  <tenv> Env:List </tenv>

rule <k> T1:Type <: T2:Type ; ~> K:K => pushResult(normalize(T1), normalize(T2), isAssignable(normalize(T1), normalize(T2))) ~> K </k>


// Functional assignability relation
syntax Bool ::= "isAssignable" "(" Type "," Type ")" [function]

// Base equal types
rule isAssignable(T:Type, T:Type) => true

// any: top (and effectively bottom) in TS assignability
rule isAssignable(any, _T:Type) => true
rule isAssignable(_:Type, any) => true

// unknown: target top, source only to any/unknown
rule isAssignable(_:Type, unknown) => true
rule isAssignable(unknown, any) => true
rule isAssignable(unknown, unknown) => true
rule isAssignable(unknown, _T:Type) => false [owise]

// never: bottom — assignable to all, only assignable from itself
rule isAssignable(never, _:Type) => true
rule isAssignable(_:Type, never) => false [owise]

// Unions
rule isAssignable(S:Type, T1:Type | T2:Type) => isAssignable(S, T1) orBool isAssignable(S, T2)
rule isAssignable(S1:Type | S2:Type, T:Type) => isAssignable(S1, T) andBool isAssignable(S2, T)
rule isAssignable(ObjectType(MS:Map), ObjectType(MT:Map)) => objectAssignable(MS, MT)

rule isAssignable(S1:Type & S2:Type, T:Type) => isAssignable(S1, T) andBool isAssignable(S2, T)
rule isAssignable(S:Type, T1:Type & T2:Type) => isAssignable(S, T1) orBool isAssignable(S, T2)

// Fallback
rule isAssignable(_:Type, _:Type) => false [owise]

// hasKey over a Map
syntax Bool ::= "hasKey" "(" Map "," Id ")" [function]
rule hasKey((N:Id |-> _) _MRest:Map, N:Id) => true
rule hasKey((N1:Id |-> _) MRest:Map, N:Id) => hasKey(MRest, N) requires N =/=K N1
rule hasKey(.Map, _:Id) => false

// Check modifier presence in a Set of modifiers
syntax Bool ::= "hasModifier" "(" Set "," TypeAnnotations ")" [function]
rule hasModifier(SetItem(A:TypeAnnotations) _:Set, A:TypeAnnotations) => true
rule hasModifier(SetItem(A1:TypeAnnotations) S:Set, A2:TypeAnnotations) => hasModifier(S, A2) requires A1 =/=K A2
rule hasModifier(.Set, _:TypeAnnotations) => false

// Property assignability, considering optional/readonly and type relation
// Returns false if source is readonly but target is mutable
// Returns false if target is required but source is optional
// In TypeScript, readonly does not prevent assignability in either direction.
// Only optionality and inner type relation are enforced here.
syntax Bool ::= "propAssignable" "(" Type "," Set "," Type "," Set ")" [function]
rule propAssignable(Ts:Type, _:Set, Tt:Type, ModsT:Set)
  => isAssignable(Ts, Tt)
  requires hasModifier(ModsT, optional)

rule propAssignable(Ts:Type, ModsS:Set, Tt:Type, ModsT:Set)
  => notBool(hasModifier(ModsS, optional))
     andBool isAssignable(Ts, Tt)
  requires notBool hasModifier(ModsT, optional)


// Object literal types: structural subtyping
syntax Bool ::= "objectAssignable" "(" Map "," Map ")" [function]
rule objectAssignable(_:Map, .Map) => true
// Target property present in source
rule objectAssignable((N:Id |-> PropertySignatureType(Ts:Type, ModsS:Set)) STail:Map, (N:Id |-> PropertySignatureType(Tt:Type, ModsT:Set)) TTail:Map)
  => propAssignable(Ts, ModsS, Tt, ModsT)
     andThenBool objectAssignable(STail, TTail)
// Target optional property missing in source is OK
rule objectAssignable(MS:Map, (N:Id |-> PropertySignatureType(_:Type, ModsT:Set)) MTail:Map)
  => objectAssignable(MS, MTail)
  requires notBool hasKey(MS, N) andBool hasModifier(ModsT, optional)
// Target required property missing in source is NOT OK
rule objectAssignable(MS:Map, (N:Id |-> PropertySignatureType(_:Type, ModsT:Set)) _MTail:Map)
  => false
  requires notBool hasKey(MS, N) andBool notBool hasModifier(ModsT, optional)

endmodule
