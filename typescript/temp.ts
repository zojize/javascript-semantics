type A = number;
type B = string | number;
type P = { x: number };

// Primitives and unions
string <: string | number;
number <: B;
boolean <: B;

// Top/bottom, unknown/any
never <: A;
A <: never;
unknown <: any;
any <: unknown;
unknown <: number;

// Object structural assignability
{ x: number } <: { x: number };
{ x: number, y: string } <: { x: number };
{ x: number } <: { x: number, y?: string };
{ x?: number } <: { x: number };
{ readonly x: number } <: { x: number };
{ x: number } <: { readonly x: number };

// Property unions
{ a: string | number } <: { a: number };
{ a: number } <: { a: string | number };

// Alias targets
{ x: number, y: string } <: P;
P <: { x: number };

// Union of object types to wider object type
{ a: number } | { a: string } <: { a: number | string };