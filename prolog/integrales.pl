:- encoding(utf8).

% =====================================================================
% Base de conocimiento de integrales indefinidas elementales.
%
% Uso:  s(Var, Expresion, Integral)        (la constante C la agrega la UI)
%   ?- s(x, 4*x^4 + sen(x), I).      I = 4/5*x^5+ -cos(x)
% =====================================================================
%**Integrantes:**
%
% Andrea Beatriz Orellana Jiménez 00106123
% Pablo Enrique Vides Zavala 00080323
% Raúl Napoleón Caprile Ramos 00006422
% Alex Eduardo Ramirez Guevara 00009423

:- ensure_loaded(utilidades).

% [AGREGADO] Una expresión que divide entre cero (x/0, 1/(2-2), sen(1/0))
% no tiene integral: esta regla va primero y corta con fallo.

s(_, Exp, _):-
    divide_entre_cero(Exp), !, fail.

% Integral de una constante:

s(Var, K, K*Var):-
    atomic(Var), number(K), !.


% [AGREGADO] Integral de una constante simbólica (y, pi, sen(a), ...):

s(Var, K, K*Var):-
    atomic(Var), libre_de(K, Var), !.


% Integral de una variable respecto a sí misma:

s(Var, Var, 1/2*Var^2):-
    atomic(Var), !.


% [AGREGADO] Integral de x^-1 = log(x)  (debe ir antes de la regla de x^N):

s(Var, Var^N, log(abs(Var))):-
    atomic(Var), constante_numerica(N, V), V =:= -1, !.


% Integral de una variable elevada a la N:

s(Var, Var^N, 1/M*Var^M):-
    atomic(Var), constante_numerica(N, V), is(M, +(V,1)), !.


% Integral de una constante por una variable elevada a la N:
% [CORREGIDO] N =\= -1 (antes K*x^-1 producía una división entre cero).

s(Var, K*Var^N, K/M*Var^M):-
    atomic(Var), number(K), constante_numerica(N, V), V =\= -1, is(M, +(V,1)), !.


% [AGREGADO] Integral de K/x = K*log(x):

s(Var, K/Var, K*log(abs(Var))):-
    atomic(Var), libre_de(K, Var), !.


% [AGREGADO] Integral de K/x^N  (K/x^N = K*x^-N):

s(Var, K/Var^N, K*log(abs(Var))):-
    atomic(Var), constante_numerica(N, V), V =:= 1, libre_de(K, Var), !.

s(Var, K/Var^N, K/M*Var^M):-
    atomic(Var), constante_numerica(N, V), libre_de(K, Var), is(M, 1 - V), !.

% [AGREGADO] Funciones elementales:

s(Var, sen(Var), -cos(Var)):-
    atomic(Var), !.

s(Var, sin(Var), -cos(Var)):-
    atomic(Var), !.

s(Var, cos(Var), sen(Var)):-
    atomic(Var), !.

s(Var, sec(Var)^2, tan(Var)):-
    atomic(Var), !.

s(Var, tan(Var), -log(abs(cos(Var)))):-
    atomic(Var), !.

s(Var, cot(Var), log(abs(sen(Var)))):-
    atomic(Var), !.

s(Var, sec(Var), log(abs(sec(Var) + tan(Var)))):-
    atomic(Var), !.

s(Var, csc(Var), -log(abs(csc(Var) + cot(Var)))):-
    atomic(Var), !.

s(Var, senh(Var), cosh(Var)):-
    atomic(Var), !.

s(Var, cosh(Var), senh(Var)):-
    atomic(Var), !.

s(Var, exp(Var), exp(Var)):-
    atomic(Var), !.

s(Var, sqrt(Var), 2/3*Var^(3/2)):-
    atomic(Var), !.

s(Var, log(Var), Var*log(Var) - Var):-
    atomic(Var), !.

s(Var, ln(Var), Var*log(Var) - Var):-
    atomic(Var), !.


% [AGREGADO] Linealidad: constante por función, negativo, suma y resta.

s(Var, K*F, K*SF):-
    atomic(Var), libre_de(K, Var), s(Var, F, SF), !.

s(Var, F*K, SF*K):-
    atomic(Var), libre_de(K, Var), s(Var, F, SF), !.

s(Var, F/K, SF/K):-
    atomic(Var), libre_de(K, Var), s(Var, F, SF), !.

s(Var, -F, -SF):-
    atomic(Var), s(Var, F, SF), !.

s(Var, F+G, SF+SG):-
    atomic(Var), s(Var, F, SF), s(Var, G, SG), !.

s(Var, F-G, SF-SG):-
    atomic(Var), s(Var, F, SF), s(Var, G, SG), !.


% [AGREGADO] Fórmulas de reducción (integración por partes repetida),
% con n entero positivo:
%   ∫x^n sen x  dx = -x^n cos x  + n ∫x^(n-1) cos x  dx
%   ∫x^n cos x  dx =  x^n sen x  - n ∫x^(n-1) sen x  dx
%   ∫x^n senh x dx =  x^n cosh x - n ∫x^(n-1) cosh x dx
%   ∫x^n cosh x dx =  x^n senh x - n ∫x^(n-1) senh x dx
%   ∫x^n e^x    dx =  x^n e^x    - n ∫x^(n-1) e^x    dx
% Sirve con la variable atómica o con una variable de Prolog.

s(Var, Exp, I):-
    potencia_por_funcion(Exp, Var, N, F), !,
    reduccion(F, Var, N, I).

% Con coeficiente: (K*x^n)*F(x), como lo escribe el parser para 3x²cos(x).
s(Var, (K*P)*G, K*I):-
    libre_de(K, Var), potencia_por_funcion(P*G, Var, N, F), !,
    reduccion(F, Var, N, I).

% INTEGRALES PARA EVALUACION:
% (Var es una variable de Prolog sin ligar)

% Integral de la variable respecto a sí misma:

s(Var, Exp, 1/2*Var^2):-
    var(Var), Exp == Var, !.


% Integral de una constante (número o expresión sin Var: 3, Y, sen(Y), ...):

s(Var, K, K*Var):-
    var(Var), libre_de(K, Var), !.


% Integral de X^-1 = ln|X|  (antes de la regla de X^N):

s(Var, B^N, log(abs(Var))):-
    var(Var), B == Var, constante_numerica(N, V), V =:= -1, !.


% Integral de una variable elevada a la N:

s(Var, B^N, 1/M*Var^M):-
    var(Var), B == Var, constante_numerica(N, V), is(M, +(V,1)), !.


% Integral de K/X y de K/X^N:

s(Var, K/B, K*log(abs(Var))):-
    var(Var), B == Var, libre_de(K, Var), !.

s(Var, K/(B^N), K*log(abs(Var))):-
    var(Var), B == Var, constante_numerica(N, V), V =:= 1, libre_de(K, Var), !.

s(Var, K/(B^N), K/M*Var^M):-
    var(Var), B == Var, constante_numerica(N, V), libre_de(K, Var), is(M, 1 - V), !.


% Funciones elementales:

s(Var, sen(F), -cos(Var)):-
    var(Var), F == Var, !.

s(Var, sin(F), -cos(Var)):-
    var(Var), F == Var, !.

s(Var, cos(F), sen(Var)):-
    var(Var), F == Var, !.

s(Var, sec(F)^2, tan(Var)):-
    var(Var), F == Var, !.

s(Var, tan(F), -log(abs(cos(Var)))):-
    var(Var), F == Var, !.

s(Var, cot(F), log(abs(sen(Var)))):-
    var(Var), F == Var, !.

s(Var, sec(F), log(abs(sec(Var) + tan(Var)))):-
    var(Var), F == Var, !.

s(Var, csc(F), -log(abs(csc(Var) + cot(Var)))):-
    var(Var), F == Var, !.

s(Var, senh(F), cosh(Var)):-
    var(Var), F == Var, !.

s(Var, cosh(F), senh(Var)):-
    var(Var), F == Var, !.

s(Var, exp(F), exp(Var)):-
    var(Var), F == Var, !.

s(Var, sqrt(F), 2/3*Var^(3/2)):-
    var(Var), F == Var, !.

s(Var, log(F), Var*log(Var) - Var):-
    var(Var), F == Var, !.

s(Var, ln(F), Var*log(Var) - Var):-
    var(Var), F == Var, !.


% Linealidad: constante por función, negativo, suma y resta.

s(Var, K*F, K*SF):-
    var(Var), libre_de(K, Var), s(Var, F, SF), !.

s(Var, F*K, SF*K):-
    var(Var), libre_de(K, Var), s(Var, F, SF), !.

s(Var, F/K, SF/K):-
    var(Var), libre_de(K, Var), s(Var, F, SF), !.

s(Var, -F, -SF):-
    var(Var), s(Var, F, SF), !.

s(Var, F+G, SF+SG):-
    var(Var), s(Var, F, SF), s(Var, G, SG), !.

s(Var, F-G, SF-SG):-
    var(Var), s(Var, F, SF), s(Var, G, SG), !.


% ---------------------------------------------------------------------
% Auxiliares de las fórmulas de reducción
% ---------------------------------------------------------------------

% potencia_por_funcion(Exp, Var, N, F): Exp es Var^N * F(Var) (en
% cualquier orden), con N entero positivo y F una función de la tabla.
potencia_por_funcion(A*B, Var, N, F):-
    (   potencia_de(A, Var, N), funcion_reducible(B, Var, F)
    ;   potencia_de(B, Var, N), funcion_reducible(A, Var, F)
    ), !.

potencia_de(P, Var, 1):-
    P == Var, !.
potencia_de(P, Var, N):-
    nonvar(P), P = B^N, B == Var, integer(N), N > 0.

funcion_reducible(G, Var, F):-
    nonvar(G), G =.. [Nombre, A], A == Var,
    nombre_reducible(Nombre, F).

nombre_reducible(sen, sen).
nombre_reducible(sin, sen).
nombre_reducible(cos, cos).
nombre_reducible(senh, senh).
nombre_reducible(sinh, senh).
nombre_reducible(cosh, cosh).
nombre_reducible(exp, exp).

% primitiva(F, Signo, G): ∫F(x) dx = Signo * G(x).
primitiva(sen,  -1, cos).
primitiva(cos,   1, sen).
primitiva(senh,  1, cosh).
primitiva(cosh,  1, senh).
primitiva(exp,   1, exp).

% Caso base: n = 0, la integral elemental.
reduccion(F, Var, 0, I):- !,
    primitiva(F, Signo, G),
    T =.. [G, Var],
    ( Signo =:= 1 -> I = T ; I = -T ).

% Paso recursivo: ∫x^n F = Signo*x^n*G - Signo*n*∫x^(n-1) G.
reduccion(F, Var, N, I):-
    N > 0,
    primitiva(F, Signo, G),
    T =.. [G, Var],
    N1 is N - 1,
    reduccion(G, Var, N1, R),
    ( N =:= 1 -> XN = Var ; XN = Var^N ),
    ( Signo =:= 1 -> I = XN*T - N*R ; I = -(XN*T) + N*R ).
