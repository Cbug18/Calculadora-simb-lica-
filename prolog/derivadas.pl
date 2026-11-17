:- encoding(utf8).

% =====================================================================
% Base de conocimiento de derivadas elementales.
%**Integrantes:**
%
% Andrea Beatriz Orellana Jiménez 00106123
% Pablo Enrique Vides Zavala 00080323
% Raúl Napoleón Caprile Ramos 00006422
% Alex Eduardo Ramirez Guevara 00009423
% Uso:  d(Var, Expresion, Derivada)
%   ?- d(x, 4*x^4 + sen(x), D).      D = 16*x^3+cos(x)
%

% =====================================================================

:- ensure_loaded(utilidades).


% DERIVADAS PLENAMENTE SIMBOLICAS:

% Derivada de una constante:

d(Var, Exp1, 0):-
    atomic(Var), number(Exp1),  !.


% [AGREGADO] Derivada de una constante simbólica
% (cualquier expresión que no contenga a Var: y, pi, sen(a), 2*b, ...):

d(Var, Exp1, 0):-
    atomic(Var), libre_de(Exp1, Var), !.


% Derivara de una variable respecto a sí misma:

d(Var, Exp1, 1):-
    atomic(Var), ==(Exp1, Var), !.


% Derivada de una constante por una variable:
% [CORREGIDO] se exige que N sea constante (antes d(x, x*x, R) daba R = x).

d(Var, N*Var, N):-
    atomic(Var), libre_de(N, Var), !.


% [AGREGADO] Derivada de una variable por una constante (x*N):

d(Var, Var*N, N):-
    atomic(Var), libre_de(N, Var), !.


% Derivada de una variable elevada a la N:
% [CORREGIDO] number(N): evita un error de is/2 con exponentes simbólicos (x^y).

d(Var, Var^N, N*Var^Nm1):-
    atomic(Var), number(N), is(Nm1, -(N, 1)), !.



% [AGREGADO] Derivada de una variable elevada a un exponente simbólico

d(Var, Var^N, N*Var^(N-1)):-
    atomic(Var), libre_de(N, Var), !.


% [AGREGADO] Derivada de la exponencial de base A (A constante, A > 0)

d(Var, A^Var, A^Var*log(A)):-
    atomic(Var), libre_de(A, Var), !.

% Derivada de una constante por una variable elevada a la N:

d(Var, K*Var^N, C*Var^Nm1):-
    atomic(Var), number(K), number(N), is(C, K*N), is(Nm1, -(N, 1)), !.


% [AGREGADO] Derivada de K/Var  (K/x = K*x^-1):

d(Var, K/Var, -K/Var^2):-
    atomic(Var), libre_de(K, Var), !.


% [AGREGADO] Derivada de K/Var^N  (K/x^N = K*x^-N):

d(Var, K/Var^N, -(N*K)/Var^M):-
    atomic(Var), number(N), libre_de(K, Var), is(M, N + 1), !.


% Derivada del logaritmo natural de una variable:

d(Var, log(Var), 1/Var):-
    atomic(Var), !.


% [AGREGADO] ln como sinónimo de log:

d(Var, ln(Var), 1/Var):-
    atomic(Var), !.


% Drivada del seno de una varable:

d(Var, sen(Var), cos(Var)):-
    atomic(Var), !.


% [AGREGADO] sin como sinónimo de sen:

d(Var, sin(Var), cos(Var)):-
    atomic(Var), !.


% Drivada del coseno de una varable:

d(Var, cos(Var), -sen(Var)):-
    atomic(Var), !.


% Drivada de la tagente de una varable:

d(Var, tan(Var), (sec(Var))^2):-
    atomic(Var), !.


% [AGREGADO] Derivadas de la secante, la cosecante y la cotangente:

d(Var, sec(Var), sec(Var)*tan(Var)):-
    atomic(Var), !.

d(Var, csc(Var), -csc(Var)*cot(Var)):-
    atomic(Var), !.

d(Var, cot(Var), -csc(Var)^2):-
    atomic(Var), !.

% [AGREGADO] Derivadas de las funciones hiperbólicas:

d(Var, senh(Var), cosh(Var)):-
    atomic(Var), !.

d(Var, cosh(Var), senh(Var)):-
    atomic(Var), !.

d(Var, tanh(Var), sech(Var)^2):-
    atomic(Var), !.

d(Var, sech(Var), -sech(Var)*tanh(Var)):-
    atomic(Var), !.

d(Var, csch(Var), -csch(Var)*coth(Var)):-
    atomic(Var), !.

d(Var, coth(Var), -csch(Var)^2):-
    atomic(Var), !.

% [AGREGADO] Derivadas de las trigonométricas inversas:

d(Var, arcsen(Var), 1/sqrt(1-Var^2)):-
    atomic(Var), !.

d(Var, arccos(Var), -1/sqrt(1-Var^2)):-
    atomic(Var), !.

d(Var, arctan(Var), 1/(1+Var^2)):-
    atomic(Var), !.

% [AGREGADO] Derivadas de las hiperbólicas inversas:

d(Var, arcsenh(Var), 1/sqrt(Var^2+1)):-
    atomic(Var), !.

d(Var, arccosh(Var), 1/sqrt(Var^2-1)):-
    atomic(Var), !.

d(Var, arctanh(Var), 1/(1-Var^2)):-
    atomic(Var), !.

% [AGREGADO] Derivada de la exponencial:

d(Var, exp(Var), exp(Var)):-
    atomic(Var), !.


% [AGREGADO] Derivada de la raíz cuadrada:

d(Var, sqrt(Var), 1/(2*sqrt(Var))):-
    atomic(Var), !.

% [AGREGADO] Regla de la cadena: f(U)' = f'(U) * U'

d(Var, Exp, DExt*DU):-
    atomic(Var), compound(Exp), Exp =.. [F, U],
    derivada_externa(F, U, DExt), d(Var, U, DU), !.


% [AGREGADO] Regla de la cadena para potencias: (U^N)' = N*U^(N-1) * U'

d(Var, U^N, N*U^Nm1*DU):-
    atomic(Var), number(N), is(Nm1, -(N, 1)), d(Var, U, DU), !.

d(Var, U^N, N*U^(N-1)*DU):-
    atomic(Var), libre_de(N, Var), d(Var, U, DU), !.


% [AGREGADO] Regla de la cadena para la exponencial de base A

d(Var, A^U, A^U*log(A)*DU):-
    atomic(Var), libre_de(A, Var), d(Var, U, DU), !.

% [AGREGADO] Regla del múltiplo constante: (K*F)' = K*F', (F*K)' = F'*K, (F/K)' = F'/K

d(Var, K*F, K*DF):-
    atomic(Var), libre_de(K, Var), d(Var, F, DF), !.

d(Var, F*K, DF*K):-
    atomic(Var), libre_de(K, Var), d(Var, F, DF), !.

d(Var, F/K, DF/K):-
    atomic(Var), libre_de(K, Var), d(Var, F, DF), !.


% [AGREGADO] Derivada del negativo de una función:

d(Var, -F, -DF):-
    atomic(Var), d(Var, F, DF), !.


% [AGREGADO] Regla del producto: (F*G)' = F'*G + F*G'

d(Var, F*G, DF*G + F*DG):-
    atomic(Var), d(Var, F, DF), d(Var, G, DG), !.

% [AGREGADO] Regla del cociente: (F/G)' = (F'*G - F*G') / G^2

d(Var, F/G, (DF*G - F*DG)/G^2):-
    atomic(Var), d(Var, F, DF), d(Var, G, DG), !.

% Derivada de la suma de pos funcione:

d(Var, F+G, DF+DG):-
    atomic(Var), d(Var, F, DF), d(Var, G, DG), !.


% [AGREGADO] Derivada de la resta de dos funciones:

d(Var, F-G, DF-DG):-
    atomic(Var), d(Var, F, DF), d(Var, G, DG), !.


% DERIVADAS PARA SU POSTERIOR EVALUACION:
% (Var es una variable de Prolog sin ligar; ej: d(X, X^2, D), X = 3, V is D.)

% Derivada de una constante:

d(Var, N, 0):-
    var(Var), number(N),  !.


% Derivara de una variable respecto a sí misma:

d(Var, Var, 1):-
    var(Var), !.


% Derivada de una constante por una variable:
% [CORREGIDO] se exige que N sea constante.

d(Var, N*Var, N):-
    var(Var), libre_de(N, Var), !.


% Derivada de una variable elevada a la N:
% [CORREGIDO] number(N).

d(Var, Var^N, N*Var^Nm1):-
    var(Var), number(N), is(Nm1, -(N, 1)), !.


% Derivada de una constante por una variable elevada a la N:

d(Var, K*Var^N, C*Var^Nm1):-
    var(Var), number(N), is(C, K*N), is(Nm1, -(N, 1)), !.


% Derivada del logaritmo natural de una variable:

d(Var, log(Var), 1/Var):-
    var(Var), !.


% Drivada del seno de una varable:

d(Var, sen(Var), cos(Var)):-
    var(Var), !.


% Drivada del coseno de una varable:

d(Var, cos(Var), -sen(Var)):-
    var(Var), !.


% Drivada de la tagente de una varable:

d(Var, tan(Var), (sec(Var))^2):-
    var(Var), !.


% Derivada de la suma de pos funcione:

d(Var, F+G, DF+DG):-
    var(Var), d(Var, F, DF), d(Var, G, DG).


% DERIVADAS DE LAS FUNCIONES (para la regla de la cadena):
% derivada_externa(F, U, D): la derivada de F(U) respecto a U es D.

derivada_externa(log, U, 1/U).
derivada_externa(ln, U, 1/U).
derivada_externa(sen, U, cos(U)).
derivada_externa(sin, U, cos(U)).
derivada_externa(cos, U, -sen(U)).
derivada_externa(tan, U, sec(U)^2).
derivada_externa(exp, U, exp(U)).
derivada_externa(sqrt, U, 1/(2*sqrt(U))).
derivada_externa(sec, U, sec(U)*tan(U)).
derivada_externa(csc, U, -csc(U)*cot(U)).
derivada_externa(cot, U, -csc(U)^2).
derivada_externa(senh, U, cosh(U)).
derivada_externa(cosh, U, senh(U)).
derivada_externa(tanh, U, sech(U)^2).
derivada_externa(sech, U, -sech(U)*tanh(U)).
derivada_externa(csch, U, -csch(U)*coth(U)).
derivada_externa(coth, U, -csch(U)^2).
derivada_externa(arcsen, U, 1/sqrt(1-U^2)).
derivada_externa(arccos, U, -1/sqrt(1-U^2)).
derivada_externa(arctan, U, 1/(1+U^2)).
derivada_externa(arcsenh, U, 1/sqrt(U^2+1)).
derivada_externa(arccosh, U, 1/sqrt(U^2-1)).
derivada_externa(arctanh, U, 1/(1-U^2)).