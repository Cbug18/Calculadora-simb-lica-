:- ensure_loaded('../prolog/integrales').
:- begin_tests(integrales).

test(variable_atomica) :- s(x, x, 1/2*x^2).
test(variable_prolog) :-
    s(X, X, I), assertion(I == 1/2*X^2), assertion(var(X)).
test(inversa_variable_prolog) :-
    s(X, X^(-1), I), assertion(I == log(abs(X))), assertion(var(X)).
test(constante_independiente) :-
    s(X, Y, I), assertion(I == Y*X), assertion(var(X)), assertion(var(Y)).
test(potencia_fraccionaria) :- s(x, x^(1/2), 1/1.5*x^1.5).
test(inversa) :- s(x, 1/x, 1*log(abs(x))).
test(inversa_potencia) :- s(x, 2/x^(2/2), 2*log(abs(x))).
test(coeficiente) :- s(x, 3*x^(-1), 3*log(abs(x))).
test(suma) :- s(x, x^2+sen(x), 1/3*x^3+ -cos(x)).
test(cero_literal, [fail]) :- s(x, x/0, _).
test(cero_calculado, [fail]) :- s(x, x/(2-2), _).
test(constante_indefinida, [fail]) :- s(x, 1/0, _).
test(cero_anidado, [fail]) :- s(x, sen(1/0), _).
test(no_instanciar_funcion, [fail]) :- s(X, sen(Y)+X, _), X == Y.
test(no_soportada, [fail]) :- s(x, sen(2*x), _).
test(verificacion_numerica) :-
    forall(member(F, [X^2, X^(1/2), X^(-1), 3/X^2, exp(X), sqrt(X)]),
           comprobar_integral(X, F)).

comprobar_integral(X, F) :-
    s(X, F, I),
    copy_term(X-I, X1-I1), copy_term(X-I, X2-I2),
    X1=1.300001, X2=1.299999,
    Aproximada is (I1-I2)/0.000002,
    X=1.3, Exacta is F,
    assertion(abs(Exacta-Aproximada) < 0.0001).

% Integrales trigonométricas: la derivada numérica de la integral
% tiene que dar la función original.
test(tan) :- s(x, tan(x), I), assertion(I == -log(abs(cos(x)))).
test(cot) :- s(x, cot(x), I), assertion(I == log(abs(sen(x)))).
test(tan_variable_prolog) :-
    s(X, tan(X), I), assertion(I == -log(abs(cos(X)))), assertion(var(X)).
test(sec) :- s(x, sec(x), I), assertion(I == log(abs(sec(x)+tan(x)))).
test(csc) :- s(x, csc(x), I), assertion(I == -log(abs(csc(x)+cot(x)))).
test(trig_numerica) :-
    forall(member(F, [tan(x), cot(x), sec(x), csc(x), 3*tan(x),
                      tan(x)-cot(x), sec(x)+csc(x)/2]),
           comprobar_trig(F)).

comprobar_trig(F) :-
    s(x, F, I),
    en_x(I, 1.300001, I1), en_x(I, 1.299999, I2),
    Aproximada is (I1-I2)/0.000002,
    en_x(F, 1.3, Exacta),
    assertion(abs(Exacta-Aproximada) < 0.0001).

% en_x(Exp, Punto, V): valor de Exp con x = Punto (sen, sec, csc y cot
% se pasan a sin y cos, que son los que entiende is/2).
en_x(Exp, Punto, V) :- a_numero(Exp, Punto, A), V is A.

a_numero(x, P, P) :- !.
a_numero(E, _, E) :- atomic(E), !.
a_numero(sen(A), P, sin(R)) :- !, a_numero(A, P, R).
a_numero(sec(A), P, 1/cos(R)) :- !, a_numero(A, P, R).
a_numero(csc(A), P, 1/sin(R)) :- !, a_numero(A, P, R).
a_numero(cot(A), P, cos(R)/sin(R)) :- !, a_numero(A, P, R).
a_numero(E, P, R) :-
    E =.. [F|Args], a_numero_lista(Args, P, RArgs), R =.. [F|RArgs].

a_numero_lista([], _, []).
a_numero_lista([A|As], P, [B|Bs]) :- a_numero(A, P, B), a_numero_lista(As, P, Bs).

:- end_tests(integrales).
