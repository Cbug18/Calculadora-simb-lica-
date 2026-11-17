:- encoding(utf8).

% =====================================================================
% Base de conocimiento de integrales indefinidas elementales.
%
% Uso:  s(Var, Expresion, Integral)        (la constante C la agrega la UI)
%   ?- s(x, 4*x^4 + sen(x), I).      I = 4/5*x^5+ -cos(x)
% =====================================================================

:- ensure_loaded(utilidades).


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

s(Var, Var^N, log(Var)):-
    atomic(Var), number(N), N =:= -1, !.


% Integral de una variable elevada a la N:

s(Var, Var^N, 1/M*Var^M):-
    atomic(Var), number(N), is(M, +(N,1)), !.


% Integral de una constante por una variable elevada a la N:
% [CORREGIDO] N =\= -1 (antes K*x^-1 producía una división entre cero).

s(Var, K*Var^N, K/M*Var^M):-
    atomic(Var), number(K), number(N), N =\= -1, is(M, +(N,1)), !.


% [AGREGADO] Integral de K/x = K*log(x):

s(Var, K/Var, K*log(Var)):-
    atomic(Var), libre_de(K, Var), !.


% [AGREGADO] Integral de K/x^N  (K/x^N = K*x^-N):

s(Var, K/Var^N, K*log(Var)):-
    atomic(Var), number(N), N =:= 1, libre_de(K, Var), !.

s(Var, K/Var^N, K/M*Var^M):-
    atomic(Var), number(N), libre_de(K, Var), is(M, 1 - N), !.


% [AGREGADO] Funciones elementales:

s(Var, sen(Var), -cos(Var)):-
    atomic(Var), !.

s(Var, sin(Var), -cos(Var)):-
    atomic(Var), !.

s(Var, cos(Var), sen(Var)):-
    atomic(Var), !.

s(Var, sec(Var)^2, tan(Var)):-
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


% INTEGRALES PARA EVALUACION:

% Integral de una variable elevada a la N:

s(Var, Var^N, 1/M*Var^M):-
    var(Var), number(N), is(M, +(N,1)), !.
