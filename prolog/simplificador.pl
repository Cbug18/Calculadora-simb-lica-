:- encoding(utf8).
% simplificador.pl — simplificación algebraica de las expresiones.
%
%   simplificar(Exp, S)          agrupa términos semejantes, opera las
%                                constantes, aplica identidades
%                                (sen² + cos² = 1, sen/cos = tan) y
%                                valores exactos (sen(pi/6) = 1/2, log(e) = 1).
%   expandir(Exp, S)             igual, pero además desarrolla las potencias
%                                enteras de sumas y reparte las divisiones.
%   factorizar(Exp, F)           saca el factor común de una suma.
%   evaluar(Exp, Var, Valor, R)  sustituye Var por Valor y simplifica.
%   valor_numerico(Exp, N)       aproximación decimal (falla si no es numérica).
%
% Representación interna: un polinomio es una lista de monomios m(C, Fs).
% C es el coeficiente (entero, racional o flotante) y Fs una lista ordenada
% de factores Base-Exponente. Las bases son átomos, funciones o sumas ya
% simplificadas; el exponente es un número o un término simbólico.
%
% Si algo no está definido (división entre cero, log(0), tan(pi/2)) se
% lanza error_calculo(Mensaje).

simplificar(Exp, S) :-
    simplificar_modo(normal, Exp, S).

expandir(Exp, S) :-
    simplificar_modo(expandir, Exp, S).

simplificar_modo(Modo, Exp, S) :-
    repetir_simplificacion(Modo, Exp, 3, S).

% Una pasada puede dejar algo que la siguiente todavía reduce
% (por ejemplo, una identidad que aparece al agrupar).
repetir_simplificacion(Modo, Exp, N, S) :-
    a_polinomio(Exp, Modo, P0),
    identidad_pitagorica(P0, P),
    polinomio_termino(P, S0),
    ( S0 == Exp -> S = S0
    ; N =< 1 -> S = S0
    ; N1 is N-1, repetir_simplificacion(Modo, S0, N1, S)
    ).

factorizar(Exp, F) :-
    a_polinomio(Exp, normal, P0),
    identidad_pitagorica(P0, P),
    ( P = [_, _|_] ->
        contenido(P, true, K, R),
        polinomio_termino([K], TK), polinomio_termino(R, TR),
        ( TK == 1 -> F = TR
        ; TK == -1 -> F = -TR
        ; F = TK*TR
        )
    ; polinomio_termino(P, F)
    ).

evaluar(Exp, Var, Valor, R) :-
    sustituir(Exp, Var, Valor, E),
    simplificar(E, R).

sustituir(Exp, Var, Valor, R) :-
    ( Exp == Var -> R = Valor
    ; var(Exp) -> R = Exp
    ; atomic(Exp) -> R = Exp
    ; Exp =.. [F|Args],
      maplist(sustituir_argumento(Var, Valor), Args, RArgs),
      R =.. [F|RArgs]
    ).

sustituir_argumento(Var, Valor, Arg, R) :-
    sustituir(Arg, Var, Valor, R).

% ------------------------------------------------------------------
% Expresión -> polinomio
% ------------------------------------------------------------------

a_polinomio(E, _, [m(1, [E-1])]) :-
    var(E), !.
a_polinomio(E, _, P) :-
    number(E), !, numero_polinomio(E, P).
a_polinomio(E, _, [m(1, [E-1])]) :-
    atom(E), !.
a_polinomio(A+B, Modo, P) :- !,
    a_polinomio(A, Modo, PA), a_polinomio(B, Modo, PB),
    sumar_polinomios(PA, PB, P).
a_polinomio(A-B, Modo, P) :- !,
    a_polinomio(A, Modo, PA), a_polinomio(B, Modo, PB),
    negar_polinomio(PB, NB), sumar_polinomios(PA, NB, P).
a_polinomio(-A, Modo, P) :- !,
    a_polinomio(A, Modo, PA), negar_polinomio(PA, P).
a_polinomio(A*B, Modo, P) :- !,
    a_polinomio(A, Modo, PA), a_polinomio(B, Modo, PB),
    multiplicar_polinomios(PA, PB, P).
a_polinomio(A/B, Modo, P) :- !,
    a_polinomio(A, Modo, PA), a_polinomio(B, Modo, PB),
    dividir_polinomios(PA, PB, Modo, P).
a_polinomio(A^B, Modo, P) :-
    A == e, !,
    a_polinomio(exp(B), Modo, P).
a_polinomio(A^B, Modo, P) :- !,
    a_polinomio(A, Modo, PA), a_polinomio(B, Modo, PB),
    potencia_polinomio(PA, PB, Modo, P).
a_polinomio(sqrt(A), Modo, P) :- !,
    a_polinomio(A, Modo, PA), Medio is 1 rdiv 2,
    potencia_polinomio(PA, [m(Medio, [])], Modo, P).
a_polinomio(F, Modo, P) :-
    F =.. [Nombre0|Args],
    maplist(simplificar_modo(Modo), Args, SArgs),
    nombre_canonico(Nombre0, Nombre),
    funcion_polinomio(Nombre, SArgs, P).

nombre_canonico(sin, sen) :- !.
nombre_canonico(ln, log) :- !.
nombre_canonico(N, N).

% Los decimales "redondos" se pasan a fracción: 0.5 -> 1/2, 1.5 -> 3/2.
numero_polinomio(N, P) :-
    numero_exacto(N, Q),
    ( Q =:= 0 -> P = [] ; P = [m(Q, [])] ).

numero_exacto(N, Q) :-
    ( float(N), catch(R is rationalize(N), _, fail),
      rational(R, _, D), D =< 1000 -> Q = R
    ; Q = N
    ).

% ------------------------------------------------------------------
% Suma y producto
% ------------------------------------------------------------------

sumar_polinomios(PA, PB, P) :-
    append(PA, PB, Ms),
    juntar_semejantes(Ms, P).

% Agrupa los monomios con los mismos factores sumando sus coeficientes.
juntar_semejantes(Ms, P) :-
    maplist(monomio_par, Ms, Pares),
    keysort(Pares, Ordenados),
    juntar_pares(Ordenados, Juntos),
    exclude(coeficiente_cero, Juntos, Utiles),
    maplist(monomio_par, P, Utiles).

monomio_par(m(C, Fs), Fs-C).

coeficiente_cero(_-C) :-
    C =:= 0.

juntar_pares([], []).
juntar_pares([F1-C1, F2-C2|R], J) :-
    F1 == F2, !,
    C is C1+C2,
    juntar_pares([F1-C|R], J).
juntar_pares([X|R], [X|J]) :-
    juntar_pares(R, J).

negar_polinomio(P, N) :-
    maplist(negar_monomio, P, N).

negar_monomio(m(C, Fs), m(C1, Fs)) :-
    C1 is -C.

multiplicar_polinomios(PA, PB, P) :-
    productos(PA, PB, Ms),
    juntar_semejantes(Ms, P).

productos([], _, []).
productos([MA|RA], PB, Ms) :-
    maplist(multiplicar_monomios(MA), PB, Ms1),
    productos(RA, PB, Ms2),
    append(Ms1, Ms2, Ms).

multiplicar_monomios(m(C1, F1), m(C2, F2), M) :-
    C is C1*C2,
    append(F1, F2, Fs),
    normalizar_monomio(m(C, Fs), M).

% Ordena los factores, suma los exponentes de las bases repetidas,
% pasa al coeficiente las potencias numéricas exactas y aplica sen/cos = tan.
normalizar_monomio(m(C0, Fs0), m(C, Fs)) :-
    msort(Fs0, Ordenados),
    agrupar_factores(Ordenados, Agrupados),
    plegar_numericos(Agrupados, C0, C1, Fs1),
    identidad_cociente(Fs1, Fs2),
    ( C1 =:= 0 -> C = 0, Fs = []
    ; C = C1, Fs = Fs2
    ).

agrupar_factores([], []).
agrupar_factores([B1-E1, B2-E2|R], G) :-
    B1 == B2, !,
    sumar_exponentes(E1, E2, E),
    agrupar_factores([B1-E|R], G).
agrupar_factores([B-E|R], G) :-
    ( number(E), E =:= 0 -> G = G1 ; G = [B-E|G1] ),
    agrupar_factores(R, G1).

sumar_exponentes(E1, E2, E) :-
    ( number(E1), number(E2) -> E is E1+E2
    ; exponente_de(E1+E2, E)
    ).

multiplicar_exponente(N, B-E, B-E1) :-
    ( number(E), number(N) -> E1 is E*N
    ; exponente_de(E*N, E1)
    ).

negar_exponente(B-E, B-E1) :-
    ( number(E) -> E1 is -E
    ; exponente_de(-E, E1)
    ).

% Un exponente es un número o, si no, el término simplificado.
exponente_de(T, E) :-
    a_polinomio(T, normal, P),
    ( P == [] -> E = 0
    ; P = [m(C, [])] -> E = C
    ; polinomio_termino(P, E)
    ).

plegar_numericos([], C, C, []).
plegar_numericos([B-E|R], C0, C, Fs) :-
    ( number(B), number(E), potencia_numerica(B, E, V) ->
        C1 is C0*V, plegar_numericos(R, C1, C, Fs)
    ; number(B), number(E), sacar_potencia(B, E, V, B1) ->
        C1 is C0*V, Fs = [B1-E|Fs1], plegar_numericos(R, C1, C, Fs1)
    ; Fs = [B-E|Fs1], plegar_numericos(R, C0, C, Fs1)
    ).

% Saca de la raíz la mayor potencia exacta: 8^(1/2) = 2*2^(1/2).
sacar_potencia(B, E, V, B1) :-
    integer(B), B > 1, B =< 1000000,
    rational(E, N, D), D > 1, D =< 100,
    Max is floor(B ** (1/D)),
    between(2, Max, I), K is Max+2-I,
    B mod K^D =:= 0, !,
    B1 is B // K^D,
    ( N >= 0 -> V is K^N
    ; V0 is K^(-N), dividir_numeros(1, V0, V)
    ).

% Valor exacto de B^E, si existe: 2^3 = 8, 4^(1/2) = 2, (1/8)^(1/3) = 1/2.
potencia_numerica(B, E, V) :-
    ( B =:= 0 ->
        ( E > 0 -> V = 0
        ; throw(error_calculo("División entre cero"))
        )
    ; integer(E) ->
        abs(E) =< 10000,
        ( E >= 0 -> V is B^E
        ; V0 is B^(-E), dividir_numeros(1, V0, V)
        )
    ; ( float(B) ; float(E) ) ->
        B > 0, V is B**E
    ; rational(E, N, D), B > 0, D =< 100,
      rational(B, NB, DB),
      raiz_entera(NB, D, RN), raiz_entera(DB, D, RD),
      R is RN rdiv RD,
      ( N >= 0 -> V is R^N
      ; V0 is R^(-N), dividir_numeros(1, V0, V)
      )
    ).

raiz_entera(N, D, R) :-
    R is round(N ** (1/D)),
    R^D =:= N.

dividir_numeros(A, B, C) :-
    ( B =:= 0 -> throw(error_calculo("División entre cero"))
    ; ( float(A) ; float(B) ) -> C is A/B
    ; C is A rdiv B
    ).

invertir_monomio(m(C, Fs), m(IC, IFs)) :-
    dividir_numeros(1, C, IC),
    maplist(negar_exponente, Fs, IFs).

% ------------------------------------------------------------------
% División y potencia
% ------------------------------------------------------------------

dividir_polinomios(PA, PB, Modo, P) :-
    ( PB == [] -> throw(error_calculo("División entre cero"))
    ; PA == [] -> P = []
    ; PB = [MB] ->
        invertir_monomio(MB, Inv),
        multiplicar_polinomios(PA, [Inv], Q),
        ( Modo == expandir -> P = Q
        ; reparto_limpio(PA, Inv, Q) -> P = Q
        ; contenido(PA, true, KA, RA),
          multiplicar_monomios(KA, Inv, K),
          monomio_de_suma(RA, 1, MA),
          multiplicar_polinomios([K], [MA], P)
        )
    ; contenido(PA, true, KA, RA),
      contenido(PB, true, KB, RB),
      invertir_monomio(KB, InvKB),
      multiplicar_monomios(KA, InvKB, K),
      ( RA == RB -> P = [K]
      ; monomio_de_suma(RA, 1, MA),
        monomio_de_suma(RB, -1, MB),
        multiplicar_polinomios([K], [MA], P1),
        multiplicar_polinomios(P1, [MB], P)
      )
    ).

% (x^2 + x)/x se reparte (x + 1); (x + 1)/x se deja como fracción.
reparto_limpio(PA, Inv, Q) :-
    ( Inv = m(_, []) -> true
    ; exponente_negativo(PA) -> true
    ; \+ exponente_negativo(Q)
    ).

exponente_negativo(P) :-
    member(m(_, Fs), P), member(_-E, Fs), number(E), E < 0, !.

potencia_polinomio(PA, PB, Modo, P) :-
    ( PB == [] -> P = [m(1, [])]
    ; PA == [] ->
        ( PB = [m(N, [])], N > 0 -> P = []
        ; PB = [m(_, [])] -> throw(error_calculo("División entre cero"))
        ; throw(error_calculo("0 elevado a un exponente simbólico no está definido"))
        )
    ; PB = [m(N, [])] -> potencia_numerica_polinomio(PA, N, Modo, P)
    ; polinomio_termino(PB, E),
      ( PA = [M] -> potencia_monomio(M, E, P)
      ; contenido(PA, false, K, R),
        potencia_monomio(K, E, PK),
        monomio_de_suma(R, E, MR),
        multiplicar_polinomios(PK, [MR], P)
      )
    ).

potencia_numerica_polinomio(PA, N, Modo, P) :-
    ( PA = [M] -> potencia_monomio(M, N, P)
    ; Modo == expandir, integer(N), N >= 2, N =< 8 ->
        potencia_entera(PA, N, P)
    ; ( integer(N) -> Signo = true ; Signo = false ),
      contenido(PA, Signo, K, R),
      potencia_monomio(K, N, PK),
      monomio_de_suma(R, N, MR),
      multiplicar_polinomios(PK, [MR], P)
    ).

potencia_entera(P, 1, P) :- !.
potencia_entera(P, N, R) :-
    N1 is N-1,
    potencia_entera(P, N1, R1),
    multiplicar_polinomios(P, R1, R).

potencia_monomio(m(C, Fs), N, P) :-
    ( number(N), potencia_numerica(C, N, V) -> C1 = V, Extra = []
    ; C =:= 1 -> C1 = 1, Extra = []
    ; C1 = 1, Extra = [C-N]
    ),
    maplist(multiplicar_exponente(N), Fs, Fs1),
    append(Extra, Fs1, Fs2),
    normalizar_monomio(m(C1, Fs2), M),
    ( M = m(0, _) -> P = [] ; P = [M] ).

% Una suma que no se puede repartir pasa a ser la base de un factor.
monomio_de_suma(R, E, M) :-
    ( R = [m(1, [])] -> M = m(1, [])
    ; polinomio_termino(R, T), M = m(1, [T-E])
    ).

% contenido(P, Signo, K, R): P = K*R, con K el factor común (coeficiente
% y potencias comunes). Con Signo = true el primer término de R es positivo.
contenido(P, Signo, K, R) :-
    ( P = [M] -> K = M, R = [m(1, [])]
    ; coeficiente_comun(P, C0),
      factores_comunes(P, Fs),
      ( Signo == true, polinomio_ordenado(P, [m(C1, _)|_]), C1 < 0 -> C is -C0
      ; C = C0
      ),
      K = m(C, Fs),
      invertir_monomio(K, Inv),
      maplist(multiplicar_monomios(Inv), P, R0),
      juntar_semejantes(R0, R)
    ).

coeficiente_comun(P, C) :-
    maplist(coeficiente, P, Cs),
    ( member(X, Cs), float(X) -> C = 1
    ; maplist(numerador_denominador, Cs, Ns, Ds),
      foldl(mcd, Ns, 0, G), foldl(mcm, Ds, 1, L),
      C is G rdiv L
    ).

coeficiente(m(C, _), C).

numerador_denominador(C, N, D) :-
    ( float(C) -> N = C, D = 1
    ; rational(C, N0, D), N is abs(N0)
    ).

mcd(A, B, G) :- G is gcd(A, B).
mcm(A, B, L) :- L is A*B // gcd(A, B).

factores_comunes([m(_, Fs0)|Resto], Comunes) :-
    include(exponente_numerico, Fs0, Numericos),
    foldl(comunes_con, Resto, Numericos, Comunes).

exponente_numerico(_-E) :-
    number(E).

comunes_con(m(_, Fs), Acc, Comunes) :-
    foldl(comun_en(Fs), Acc, [], Inverso),
    reverse(Inverso, Comunes).

comun_en(Fs, B-E, Acc, Acc1) :-
    ( member(B2-E2, Fs), B2 == B, number(E2) ->
        Min is min(E, E2), Acc1 = [B-Min|Acc]
    ; Acc1 = Acc
    ).

% ------------------------------------------------------------------
% Funciones, valores exactos e identidades
% ------------------------------------------------------------------

funcion_polinomio(Nombre, [A], P) :-
    valor_exacto(Nombre, A, V), !,
    a_polinomio(V, normal, P).
funcion_polinomio(Nombre, [A], P) :-
    funcion_impar(Nombre), argumento_negativo(A, A1), !,
    F =.. [Nombre, A1], P = [m(-1, [F-1])].
funcion_polinomio(Nombre, [A], [m(1, [F-1])]) :-
    funcion_par(Nombre), argumento_negativo(A, A1), !,
    F =.. [Nombre, A1].
funcion_polinomio(Nombre, Args, [m(1, [F-1])]) :-
    F =.. [Nombre|Args].

funcion_impar(sen).
funcion_impar(tan).
funcion_impar(csc).
funcion_impar(cot).
funcion_impar(senh).
funcion_impar(tanh).
funcion_impar(csch).
funcion_impar(coth).
funcion_impar(arcsen).
funcion_impar(arctan).
funcion_impar(arcsenh).
funcion_impar(arctanh).

funcion_par(cos).
funcion_par(sec).
funcion_par(abs).
funcion_par(cosh).
funcion_par(sech).

% sen(-x) -> -sen(x): solo cuando el argumento es un monomio negativo.
argumento_negativo(A, A1) :-
    a_polinomio(A, normal, [m(C, Fs)]),
    C < 0, C1 is -C,
    polinomio_termino([m(C1, Fs)], A1).

constante(A, C) :-
    a_polinomio(A, normal, P),
    ( P == [] -> C = 0 ; P = [m(C, [])] ).

valor_exacto(exp, A, 1) :-
    A == 0.
valor_exacto(exp, A, B) :-
    nonvar(A), A = log(B).
valor_exacto(log, A, V) :-
    constante(A, C),
    ( C =< 0 -> throw(error_calculo("log solo está definido para valores positivos"))
    ; C =:= 1 -> V = 0
    ).
valor_exacto(log, A, 1) :-
    A == e.
valor_exacto(log, A, B) :-
    nonvar(A), A = exp(B).
valor_exacto(log, A, B) :-
    nonvar(A), A = E^B, E == e.
valor_exacto(abs, A, V) :-
    constante(A, C), V is abs(C).
valor_exacto(abs, A, A) :-
    nonvar(A), ( A = abs(_) ; A = exp(_) ; A == pi ; A == e ).
valor_exacto(abs, A, A) :-
    valor_numerico(A, V), V > 0.
valor_exacto(abs, A, -A) :-
    valor_numerico(A, V), V < 0.
valor_exacto(Trig, A, V) :-
    angulo_pi(A, K),
    trig_exacto(Trig, K, V).
valor_exacto(F, A, V) :-
    constante(A, C), rational(C),
    exacto_nuevas(F, C, V).

% Valores exactos y dominios de las hiperbólicas y las inversas.
% (Los negativos ya los resuelve funcion_impar: arcsen(-1/2) = -arcsen(1/2).)
exacto_nuevas(senh, 0, 0).
exacto_nuevas(tanh, 0, 0).
exacto_nuevas(cosh, 0, 1).
exacto_nuevas(sech, 0, 1).
exacto_nuevas(csch, 0, _) :-
    throw(error_calculo("csch no está definida en 0")).
exacto_nuevas(coth, 0, _) :-
    throw(error_calculo("coth no está definida en 0")).
exacto_nuevas(arcsenh, 0, 0).
exacto_nuevas(arcsen, C, _) :-
    abs(C) > 1, throw(error_calculo("arcsen solo está definido en [-1, 1]")).
exacto_nuevas(arcsen, C, V) :-
    once(( member(N/D-V, [0/1-0, 1/2-pi/6, 1/1-pi/2]), C =:= N rdiv D )).
exacto_nuevas(arccos, C, _) :-
    abs(C) > 1, throw(error_calculo("arccos solo está definido en [-1, 1]")).
exacto_nuevas(arccos, C, V) :-
    once(( member(N/D-V, [-1/1-pi, -1/2-2*pi/3, 0/1-pi/2, 1/2-pi/3, 1/1-0]),
           C =:= N rdiv D )).
exacto_nuevas(arctan, C, V) :-
    once(( member(N/D-V, [0/1-0, 1/1-pi/4]), C =:= N rdiv D )).
exacto_nuevas(arccosh, C, _) :-
    C < 1, throw(error_calculo("arccosh solo está definido para valores >= 1")).
exacto_nuevas(arccosh, 1, 0).
exacto_nuevas(arctanh, C, _) :-
    abs(C) >= 1, throw(error_calculo("arctanh solo está definido en (-1, 1)")).
exacto_nuevas(arctanh, 0, 0).

% A = K*pi con K racional.
angulo_pi(A, K) :-
    a_polinomio(A, normal, P),
    ( P == [] -> K = 0
    ; P = [m(K, [Pi-1])], Pi == pi, rational(K)
    ).

trig_exacto(sen, K, V) :-
    seno_exacto(K, V).
trig_exacto(cos, K, V) :-
    coseno_exacto(K, V).
trig_exacto(tan, K, S/C) :-
    seno_exacto(K, S), coseno_exacto(K, C),
    no_es_cero(C, "tan").
trig_exacto(sec, K, 1/C) :-
    coseno_exacto(K, C),
    no_es_cero(C, "sec").
trig_exacto(csc, K, 1/S) :-
    seno_exacto(K, S),
    no_es_cero(S, "csc").
trig_exacto(cot, K, C/S) :-
    seno_exacto(K, S), coseno_exacto(K, C),
    no_es_cero(S, "cot").

no_es_cero(V, Funcion) :-
    ( V == 0 ->
        format(string(M), "~w no está definida en ese ángulo", [Funcion]),
        throw(error_calculo(M))
    ; true
    ).

coseno_exacto(K, V) :-
    K1 is K + 1 rdiv 2,
    seno_exacto(K1, V).

seno_exacto(K0, V) :-
    K is K0 - 2*floor(K0 rdiv 2),
    ( K >= 1 ->
        K1 is K-1, seno_semiciclo(K1, V1),
        ( V1 == 0 -> V = 0 ; V = -V1 )
    ; seno_semiciclo(K, V)
    ).

% sen(K*pi) para 0 =< K < 1.
seno_semiciclo(K0, V) :-
    ( K0 > 1 rdiv 2 -> K is 1-K0 ; K = K0 ),
    once(( member(N/D-V, [0/1-0, 1/6-1/2, 1/4-sqrt(2)/2,
                          1/3-sqrt(3)/2, 1/2-1]),
           K =:= N rdiv D )).

% sen(A)^P / cos(A)^P -> tan(A)^P  y  cos(A)^P / sen(A)^P -> cot(A)^P.
identidad_cociente(Fs0, Fs) :-
    ( select(B1-P, Fs0, R1), nonvar(B1), B1 = sen(A), number(P), P > 0,
      select(B2-Q, R1, R2), nonvar(B2), B2 = cos(A2), A2 == A,
      number(Q), Q =:= -P ->
        msort([tan(A)-P|R2], Fs)
    ; select(B1-P, Fs0, R1), nonvar(B1), B1 = cos(A), number(P), P > 0,
      select(B2-Q, R1, R2), nonvar(B2), B2 = sen(A2), A2 == A,
      number(Q), Q =:= -P ->
        msort([cot(A)-P|R2], Fs)
    ; Fs = Fs0
    ).

% C*sen(A)^2*F + C*cos(A)^2*F -> C*F
identidad_pitagorica(P0, P) :-
    ( select(m(C, Fs), P0, R1),
      select(B-E, Fs, Resto), nonvar(B), B = sen(A), E == 2,
      msort([cos(A)-2|Resto], FsCos),
      select(m(C2, Fs2), R1, R2), Fs2 == FsCos, C2 =:= C ->
        sumar_polinomios([m(C, Resto)], R2, P1),
        identidad_pitagorica(P1, P)
    ; P = P0
    ).

% ------------------------------------------------------------------
% Polinomio -> expresión
% ------------------------------------------------------------------

polinomio_termino(P, T) :-
    ( P == [] -> T = 0
    ; polinomio_ordenado(P, [M|Ms]),
      monomio_inicial(M, T0),
      foldl(anadir_monomio, Ms, T0, T)
    ).

% Primero los términos de mayor grado y las constantes al final.
polinomio_ordenado(P, Ordenado) :-
    map_list_to_pairs(clave_orden, P, Pares),
    keysort(Pares, Ordenados),
    pairs_values(Ordenados, Ordenado).

clave_orden(m(_, Fs), k(G, Constante, Fs)) :-
    foldl(sumar_grado, Fs, 0, G0), G is -G0,
    ( Fs == [] -> Constante = 1 ; Constante = 0 ).

sumar_grado(B-E, G0, G) :-
    ( number(E), ( var(B) ; atom(B), B \== pi, B \== e ) -> G is G0+E
    ; G = G0
    ).

monomio_inicial(m(C, Fs), T) :-
    ( C < 0 ->
        C1 is -C, monomio_termino(m(C1, Fs), T1), negativo(T1, T)
    ; monomio_termino(m(C, Fs), T)
    ).

anadir_monomio(m(C, Fs), Acc, T) :-
    ( C < 0 ->
        C1 is -C, monomio_termino(m(C1, Fs), T1), T = Acc-T1
    ; monomio_termino(m(C, Fs), T1), T = Acc+T1
    ).

% El signo va en el número de más a la izquierda (-2*x) o delante de
% toda la fracción (-(1/x), así el LaTeX es -\frac{1}{x} y no \frac{-1}{x}).
negativo(T, N) :-
    ( number(T) -> N is -T
    ; T = A*B -> negativo(A, NA), N = NA*B
    ; N = -T
    ).

% C es positivo. Los exponentes negativos van al denominador.
monomio_termino(m(C, Fs), T) :-
    partir_factores(Fs, Num, Den),
    numerador_denominador(C, N, D),
    ( N =:= 1, Num \== [] -> NumL = Num ; NumL = [N|Num] ),
    ( D =:= 1 -> DenL = Den ; DenL = [D|Den] ),
    producto(NumL, TN),
    ( DenL == [] -> T = TN
    ; producto(DenL, TD), T = TN/TD
    ).

partir_factores([], [], []).
partir_factores([B-E|R], Num, Den) :-
    ( number(E), E < 0 ->
        E1 is -E, factor_termino(B, E1, F), Den = [F|Den1], Num = Num1
    ; nonvar(E), E = -E1 ->
        factor_termino(B, E1, F), Den = [F|Den1], Num = Num1
    ; factor_termino(B, E, F), Num = [F|Num1], Den = Den1
    ),
    partir_factores(R, Num1, Den1).

factor_termino(B0, E, T) :-
    ( number(B0) -> numero_termino(B0, B) ; B = B0 ),
    ( number(E), E =:= 1 -> T = B
    ; number(E), E =:= 1 rdiv 2 -> T = sqrt(B)
    ; number(E) -> numero_termino(E, ET), T = B^ET
    ; T = B^E
    ).

% Los racionales internos se escriben como fracción: 3r2 -> 3/2.
numero_termino(Q, T) :-
    ( rational(Q, N, D), D =\= 1 -> T = N/D
    ; T = Q
    ).

producto([X|Xs], T) :-
    foldl(multiplicar_termino, Xs, X, T).

multiplicar_termino(Y, Acc, Acc*Y).

% ------------------------------------------------------------------
% Evaluación numérica
% ------------------------------------------------------------------

valor_numerico(Exp, N) :-
    a_aritmetica(Exp, A),
    catch(N0 is A, _, fail),
    number(N0),
    N is float(N0).

a_aritmetica(E, A) :-
    ( var(E) -> fail
    ; number(E) -> A = E
    ; E == pi -> A = pi
    ; E == e -> A = e
    ; atom(E) -> fail
    ; E = X+Y -> a_aritmetica(X, AX), a_aritmetica(Y, AY), A = AX+AY
    ; E = X-Y -> a_aritmetica(X, AX), a_aritmetica(Y, AY), A = AX-AY
    ; E = X*Y -> a_aritmetica(X, AX), a_aritmetica(Y, AY), A = AX*AY
    ; E = X/Y -> a_aritmetica(X, AX), a_aritmetica(Y, AY), A = AX/AY
    ; E = X^Y -> a_aritmetica(X, AX), a_aritmetica(Y, AY), A = float(AX)**AY
    ; E = -X -> a_aritmetica(X, AX), A = -AX
    ; E =.. [F, X] -> a_aritmetica(X, AX), funcion_aritmetica(F, AX, A)
    ).

funcion_aritmetica(sen, X, sin(X)).
funcion_aritmetica(sin, X, sin(X)).
funcion_aritmetica(cos, X, cos(X)).
funcion_aritmetica(tan, X, tan(X)).
funcion_aritmetica(sec, X, 1/cos(X)).
funcion_aritmetica(csc, X, 1/sin(X)).
funcion_aritmetica(cot, X, cos(X)/sin(X)).
funcion_aritmetica(log, X, log(X)).
funcion_aritmetica(ln, X, log(X)).
funcion_aritmetica(exp, X, exp(X)).
funcion_aritmetica(sqrt, X, sqrt(X)).
funcion_aritmetica(abs, X, abs(X)).
funcion_aritmetica(senh, X, sinh(X)).
funcion_aritmetica(cosh, X, cosh(X)).
funcion_aritmetica(tanh, X, tanh(X)).
funcion_aritmetica(sech, X, 1/cosh(X)).
funcion_aritmetica(csch, X, 1/sinh(X)).
funcion_aritmetica(coth, X, cosh(X)/sinh(X)).
funcion_aritmetica(arcsen, X, asin(X)).
funcion_aritmetica(arccos, X, acos(X)).
funcion_aritmetica(arctan, X, atan(X)).
funcion_aritmetica(arcsenh, X, asinh(X)).
funcion_aritmetica(arccosh, X, acosh(X)).
funcion_aritmetica(arctanh, X, atanh(X)).