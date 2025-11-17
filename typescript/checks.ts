// Type-level helpers to assert assignability using tsc
type Expect<T extends true> = T;
type ExpectFalse<T extends false> = T;
type Assignable<From, To> = [From] extends [To] ? true : false;

// Aliases
type A = number;
type B = string | number;
type P = { x: number };

// Primitives and unions
type T1  = Expect<Assignable<string, string | number>>;
type T2  = Expect<Assignable<number, B>>;
type T3  = ExpectFalse<Assignable<boolean, B>>;

// Top/bottom, unknown/any
type T4  = Expect<Assignable<never, A>>;
type T5  = ExpectFalse<Assignable<A, never>>;
type T6  = Expect<Assignable<unknown, any>>;
type T7  = Expect<Assignable<any, unknown>>;
type T8  = ExpectFalse<Assignable<unknown, number>>;

// Object structural assignability
type T9  = Expect<Assignable<{ x: number }, { x: number }>>;
type T10 = Expect<Assignable<{ x: number, y: string }, { x: number }>>;
type T11 = Expect<Assignable<{ x: number }, { x: number, y?: string }>>;
type T12 = ExpectFalse<Assignable<{ x?: number }, { x: number }>>;
type T13 = Expect<Assignable<{ readonly x: number }, { x: number }>>;
type T14 = Expect<Assignable<{ x: number }, { readonly x: number }>>;

// Property unions
type T15 = ExpectFalse<Assignable<{ a: string | number }, { a: number }>>;
type T16 = Expect<Assignable<{ a: number }, { a: string | number }>>;

// Alias targets
type T17 = Expect<Assignable<{ x: number, y: string }, P>>;
type T18 = Expect<Assignable<P, { x: number }>>;

// Union of object types to wider object type
type T19 = Expect<Assignable<{ a: number } | { a: string }, { a: number | string }>>;