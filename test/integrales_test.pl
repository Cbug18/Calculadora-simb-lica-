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

:- end_tests(integrales).
