:- begin_tests(derivadas).
:- ensure_loaded('../prolog/derivadas').

test(constante_simbolica) :- d(x, sen(a)+b, 0).
test(variable) :- d(x, x, 1).
test(potencia) :- d(x, x^3, 3*x^2).
test(producto) :- d(x, x*x, x+x).
test(cadena) :- d(x, sen(x^2), cos(x^2)*(2*x)).
test(coseno_compuesto) :- d(x, cos(2*x), -sen(2*x)*2).
test(exponente_simbolico) :- d(x, x^y, y*x^(y-1)).
test(coeficiente_simbolico) :-
    d(X, a*X^2, D), assertion(D == a*(2*X)), assertion(var(X)).
test(variable_independiente) :-
    d(X, Y*X, D), assertion(D == Y), assertion(var(X)), assertion(var(Y)).
test(evaluacion) :- d(X, X^2, D), X=3, R is D, assertion(R =:= 6).
test(funcion_no_soportada, [fail]) :- d(x, desconocida(x), _).
test(entrada_sin_ligar) :- d(x, E, D), assertion(var(E)), assertion(D == 0).
test(verificacion_numerica) :-
    forall(member(F, [X/(X+1), exp(X^2), (X+1)^(X+2),
                      2^(X^2), sqrt(X^2+1), sin(X^2),
                      log(X+1), (X^2+1)^3]),
           comprobar_derivada(X, F)).

comprobar_derivada(X, F) :-
    d(X, F, D),
    copy_term(X-F, X1-F1), copy_term(X-F, X2-F2),
    X1=1.300001, X2=1.299999,
    Aproximada is (F1-F2)/0.000002,
    X=1.3, Exacta is D,
    assertion(abs(Exacta-Aproximada) < 0.0001).

:- end_tests(derivadas).
