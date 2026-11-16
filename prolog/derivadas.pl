:- ensure_loaded(utilidades).

d(Var, Exp, D) :-
    (var(Var) -> true; atom(Var)),
    ( Exp == Var -> D = 1
    ; libre_de(Exp, Var) -> D = 0
    ; nonvar(Exp), once(derivar(Exp, Var, D))
    ).

derivar(F+G, V, D) :-
    d(V, F, DF), d(V, G, DG), sumar_derivadas(DF, DG, D).
derivar(F-G, V, D) :-
    d(V, F, DF), d(V, G, DG), restar_derivadas(DF, DG, D).
derivar(-F, V, D) :-
    d(V, F, DF), multiplicar_derivadas(-1, DF, D).
derivar(F*G, V, D) :-
    d(V, F, DF), d(V, G, DG),
    multiplicar_derivadas(DF, G, A),
    multiplicar_derivadas(F, DG, B), sumar_derivadas(A, B, D).
derivar(F/G, V, D) :-
    d(V, F, DF), d(V, G, DG),
    ( DG == 0 -> dividir_derivadas(DF, G, D)
    ; multiplicar_derivadas(DF, G, A),
      multiplicar_derivadas(F, DG, B),
      restar_derivadas(A, B, N), dividir_derivadas(N, G^2, D)
    ).
derivar(F^G, V, D) :-
    ( libre_de(G, V) ->
        d(V, F, DF), restar_derivadas(G, 1, E),
        potencia_derivadas(F, E, P),
        multiplicar_derivadas(G, P, A), multiplicar_derivadas(A, DF, D)
    ; libre_de(F, V) ->
        d(V, G, DG), multiplicar_derivadas(F^G, log(F), A),
        multiplicar_derivadas(A, DG, D)
    ; d(V, F, DF), d(V, G, DG),
      multiplicar_derivadas(DG, log(F), A),
      multiplicar_derivadas(G, DF, B), dividir_derivadas(B, F, C),
      sumar_derivadas(A, C, S), multiplicar_derivadas(F^G, S, D)
    ).
derivar(Exp, V, D) :-
    Exp =.. [Funcion, F],
    derivada_elemental(Funcion, F, Exterior),
    d(V, F, DF), multiplicar_derivadas(Exterior, DF, D).

derivada_elemental(log, F, 1/F).
derivada_elemental(ln, F, 1/F).
derivada_elemental(sen, F, cos(F)).
derivada_elemental(sin, F, cos(F)).
derivada_elemental(cos, F, -sen(F)).
derivada_elemental(tan, F, sec(F)^2).
derivada_elemental(sec, F, sec(F)*tan(F)).
derivada_elemental(csc, F, -(csc(F)*cot(F))).
derivada_elemental(cot, F, -(csc(F)^2)).
derivada_elemental(exp, F, exp(F)).
derivada_elemental(sqrt, F, 1/(2*sqrt(F))).

sumar_derivadas(A, B, D) :-
    ( A == 0 -> D = B
    ; B == 0 -> D = A
    ; number(A), number(B) -> D is A+B
    ; D = A+B
    ).

restar_derivadas(A, B, D) :-
    ( B == 0 -> D = A
    ; number(A), number(B) -> D is A-B
    ; A == B -> D = 0
    ; A == 0 -> D = -B
    ; D = A-B
    ).

multiplicar_derivadas(A, B, D) :-
    ( A == 0 -> D = 0
    ; B == 0 -> D = 0
    ; A == 1 -> D = B
    ; B == 1 -> D = A
    ; number(A), number(B) -> D is A*B
    ; D = A*B
    ).

dividir_derivadas(A, B, D) :-
    B \== 0,
    ( A == 0 -> D = 0
    ; B == 1 -> D = A
    ; D = A/B
    ).

potencia_derivadas(A, B, D) :-
    ( B == 0 -> D = 1
    ; B == 1 -> D = A
    ; D = A^B
    ).
