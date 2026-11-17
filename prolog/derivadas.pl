:- encoding(utf8).

% =====================================================================
% Base de conocimiento de derivadas elementales (sin regla de la cadena).
%
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


% [AGREGADO] Derivada de la exponencial:

d(Var, exp(Var), exp(Var)):-
    atomic(Var), !.


% [AGREGADO] Derivada de la raíz cuadrada:

d(Var, sqrt(Var), 1/(2*sqrt(Var))):-
    atomic(Var), !.


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


% Derivada de la suma de pos funcione:

d(Var, F+G, DF+DG):-
    atomic(Var), d(Var, F, DF), d(Var, G, DG).


% [AGREGADO] Derivada de la resta de dos funciones:

d(Var, F-G, DF-DG):-
    atomic(Var), d(Var, F, DF), d(Var, G, DG).


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
