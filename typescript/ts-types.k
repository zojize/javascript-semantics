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
              | UnionType
              | Id

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

syntax UnionType ::= Type "|" Type  [left]

syntax TypeAliasDeclaration ::= "type" Id "=" Type ";"
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
  <tenv> .Map </tenv>
  <results> .List </results>

// Schedule: turn a flat list of statements into K sequence
rule <k> S:Stmt P:Pgm => S ~> P </k>
rule <k> .Pgm => .K </k>
rule <k> K:K ~> .Pgm => K </k>

// results are collected as a List of Bool in <results>
// Pretty unparse + constructor for results
syntax Result ::= Type "<:" Type "=" Bool [symbol(Result)]
syntax KItem ::= "pushResult" "(" Type "," Type "," Bool ")"
syntax KItem ::= "check" "(" Type "," Type ")"
syntax KItem ::= "resolveL" "(" Type "," Type ")"
syntax KItem ::= "resolveR" "(" Type "," Type ")"

// Type aliasing: update env and drop the statement
rule <k> type Name = Type ; ~> K:K => K </k>
  <tenv> M:Map => M [ Name <- Type ] </tenv>

syntax TypeAnnotations ::= "optional" [token]
                         | "readonly" [token]
syntax Type ::= "AnnotatedType" "(" Type "," Set ")"
syntax Type ::= "PropertySignatureType" "(" Type "," Set ")"
//                                          ^Type    ^Modifiers
syntax Type ::= "ObjectType" "(" Map ")" // TODO: index signatures

// Normalization to internal representation
syntax Type ::= "normalize" "(" Type ")" [function]
rule normalize(T:Type) => T [owise]
// Normalize object literal types by folding property signatures
syntax Map ::= "foldProps" "(" PropertySignatures "," Map ")" [function]
rule normalize({ PS:PropertySignatures }) => ObjectType(foldProps(PS, .Map))
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
  => toPropSig(N, ppType(T), Mods)
// Multiple entries: emit head, then recurse
rule props((N:Id |-> PropertySignatureType(T:Type, Mods:Set)) M:Map)
  => toPropSig(N, ppType(T), Mods), props(M)
  requires M =/=K .Map

syntax PropertySignature ::= "toPropSig" "(" Id "," Type "," Set ")" [function]
rule toPropSig(N:Id, T:Type, Mods:Set) => readonly N ?: T
  requires hasModifier(Mods, readonly) andBool hasModifier(Mods, optional)
rule toPropSig(N:Id, T:Type, Mods:Set) => readonly N : T
  requires hasModifier(Mods, readonly) andBool notBool hasModifier(Mods, optional)
rule toPropSig(N:Id, T:Type, Mods:Set) => N ?: T
  requires notBool hasModifier(Mods, readonly) andBool hasModifier(Mods, optional)
rule toPropSig(N:Id, T:Type, Mods:Set) => N : T
  requires notBool hasModifier(Mods, readonly) andBool notBool hasModifier(Mods, optional)


// Structured capture of boolean results with their LHS/RHS types (prettified)
rule <k> pushResult(T1:Type, T2:Type, B:Bool) ~> K:K => K </k>
  <results> R:List => R ListItem(ppType(T1) <: ppType(T2) = B) </results>

// Resolve type aliases on either side before checking
rule <k> Name:Id <: T:Type ; ~> K:K => T1:Type <: T ; ~> K </k>
  <tenv> ... Name |-> T1 ... </tenv>
rule <k> T:Type <: Name:Id ; ~> K:K => T <: T1:Type ; ~> K </k>
  <tenv> ... Name |-> T1 ... </tenv>

rule <k> T1:Type <: T2:Type ; ~> K:K => resolveL(T1, T2) ~> K </k>

// Resolve left side aliases and object literals
rule <k> resolveL(Name:Id, T:Type) ~> K:K => resolveL(T1:Type, T) ~> K </k>
  <tenv> ... Name |-> T1 ... </tenv>
rule <k> resolveL({ PS:PropertySignatures }, T:Type) ~> K:K => resolveL(ObjectType(foldProps(PS, .Map)), T) ~> K </k>
// Once left is resolved, move to resolving right
rule <k> resolveL(T1:Type, T2:Type) ~> K:K => resolveR(T1, T2) ~> K </k>

// Resolve right side aliases and object literals
rule <k> resolveR(T:Type, Name:Id) ~> K:K => resolveR(T, T1:Type) ~> K </k>
  <tenv> ... Name |-> T1 ... </tenv>
rule <k> resolveR(T:Type, { PS:PropertySignatures }) ~> K:K => resolveR(T, ObjectType(foldProps(PS, .Map))) ~> K </k>
// Both sides resolved => compute and record
rule <k> resolveR(T1:Type, T2:Type) ~> K:K => pushResult(normalize(T1), normalize(T2), isAssignable(T1, T2)) ~> K </k>

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
rule isAssignable({ PS:PropertySignatures }, T:Type) => isAssignable(ObjectType(foldProps(PS, .Map)), T)
rule isAssignable(T:Type, { PS:PropertySignatures }) => isAssignable(T, ObjectType(foldProps(PS, .Map)))

// Object literal types: structural subtyping
syntax Bool ::= "objectAssignable" "(" Map "," Map ")" [function]

// hasKey over a Map
syntax Bool ::= "hasKey" "(" Map "," Id ")" [function]
rule hasKey((N:Id |-> _) _MRest:Map, N:Id) => true
rule hasKey((N1:Id |-> _) MRest:Map, N:Id) => hasKey(MRest, N) requires N =/=K N1
rule hasKey(.Map, _:Id) => false

// Extract property info (assumes presence)
syntax Type ::= "propTypeOf" "(" Map "," Id ")" [function]
rule propTypeOf((N:Id |-> PropertySignatureType(T:Type, _:Set)) _:Map, N:Id) => T
rule propTypeOf((N1:Id |-> _) MRest:Map, N:Id) => propTypeOf(MRest, N) requires N =/=K N1
syntax Set  ::= "propModsOf" "(" Map "," Id ")" [function]
rule propModsOf((N:Id |-> PropertySignatureType(_T:Type, Mods:Set)) _:Map, N:Id) => Mods
rule propModsOf((N1:Id |-> _) MRest:Map, N:Id) => propModsOf(MRest, N) requires N =/=K N1

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
  requires notBool(hasModifier(ModsT, optional))

// Object structural check: every target property must be satisfied by source
rule objectAssignable(_:Map, .Map) => true

// Target property present in source
rule objectAssignable(MS:Map, (N:Id |-> PropertySignatureType(Tt:Type, ModsT:Set)) MTail:Map)
  => propAssignable(propTypeOf(MS, N), propModsOf(MS, N), Tt, ModsT)
     andBool objectAssignable(MS, MTail)
  requires hasKey(MS, N) ==K true

// Target optional property missing in source is OK
rule objectAssignable(MS:Map, (N:Id |-> PropertySignatureType(_Tt:Type, ModsT:Set)) MTail:Map)
  => objectAssignable(MS, MTail)
  requires hasKey(MS, N) ==K false andBool hasModifier(ModsT, optional)

// Target required property missing in source is NOT OK
rule objectAssignable(MS:Map, (N:Id |-> PropertySignatureType(_Tt:Type, ModsT:Set)) _MTail:Map)
  => false
  requires hasKey(MS, N) ==K false andBool notBool hasModifier(ModsT, optional)

// Apply object assignability
rule isAssignable(ObjectType(MS:Map), ObjectType(MT:Map)) => objectAssignable(MS, MT)

// Fallback
rule isAssignable(_:Type, _:Type) => false [owise]

endmodule
