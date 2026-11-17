:- encoding(utf8).
% Tests de prolog/derivadas.pl (base de conocimiento de derivadas elementales).
%
% Los tests marcados con fixme describen lo que pide el reparto de trabajo
% y la base todavía no hace (regla del producto, de la cadena, el error de
% las cláusulas "para evaluación"). Se ejecutan y se informan como FIXME,
% pero no hacen fallar la suite; cuando la regla exista pasarán solos.
% (Dentro de un fixme se usan objetivos normales: assertion/1 no cuenta.)

% Se carga antes de begin_tests para que d/3 y libre_de/2 queden en el
% módulo user y no choquen con otros ficheros de tests.
:- ensure_loaded('../prolog/derivadas').
:- begin_tests(derivadas).

% ------------------------------------------------------------------
% Variable atómica: d(x, Exp, D)
% ------------------------------------------------------------------

test(constante) :- d(x, 5, 0).
test(constante_simbolica) :- d(x, sen(a)+b, 0).
test(entrada_sin_ligar) :- d(x, E, D), assertion(var(E)), assertion(D == 0).
test(variable) :- d(x, x, 1).
test(constante_por_variable) :- d(x, 2*x, 2).
test(variable_por_constante) :- d(x, x*3, 3).
test(potencia) :- d(x, x^3, 3*x^2).
test(potencia_negativa) :- d(x, x^(-1), D), assertion(D == -1*x^(-2)).
test(constante_por_potencia) :- d(x, 3*x^2, 6*x^1).
test(k_entre_variable) :- d(x, 5/x, D), assertion(valor(x, D, 1.3, -5/1.3^2)).
test(k_entre_potencia) :- d(x, 3/x^2, D), assertion(valor(x, D, 1.3, -6/1.3^3)).
test(log) :- d(x, log(x), 1/x).
test(ln) :- d(x, ln(x), 1/x).
test(sen) :- d(x, sen(x), cos(x)).
test(sin) :- d(x, sin(x), cos(x)).
test(cos) :- d(x, cos(x), -sen(x)).
test(tan) :- d(x, tan(x), sec(x)^2).
test(exp) :- d(x, exp(x), exp(x)).
test(sqrt) :- d(x, sqrt(x), 1/(2*sqrt(x))).
test(multiplo_izquierda) :- d(x, 4*sen(x), 4*cos(x)).
test(multiplo_derecha) :- d(x, sen(x)*3, cos(x)*3).
test(entre_constante) :- d(x, sen(x)/2, cos(x)/2).
test(negativo) :- d(x, -x^2, D), assertion(D == -(2*x^1)).
test(suma) :- d(x, x^3+x, 3*x^2+1).
test(resta) :- d(x, x^3-x, 3*x^2-1).
test(polinomio) :- d(x, 4*x^4+sen(x), 16*x^3+cos(x)).
test(regla_cadena) :-
    d(x, sen(x^2), D),
    assertion(valor(x, D, 1.3, cos(1.3^2)*2*1.3)).
test(coseno_compuesto) :-
    d(x, cos(2*x), D),
    assertion(valor(x, D, 1.3, -2*sin(2.6))).
test(cadena_log) :-
    d(x, log(x^2+1), D),
    assertion(valor(x, D, 1.3, 2*1.3/(1.3^2+1))).
test(cadena_exp) :-
    d(x, exp(3*x), D),
    assertion(valor(x, D, 1.3, 3*exp(3.9))).
test(cadena_potencia) :-
    d(x, (x^2+1)^3, D),
    assertion(valor(x, D, 1.3, 3*(1.3^2+1)^2*2*1.3)).
test(regla_producto) :-
    d(x, x*sen(x), D),
    assertion(valor(x, D, 1.3, sin(1.3)+1.3*cos(1.3))).
test(producto_triple) :-
    d(x, x*x*x, D),
    assertion(valor(x, D, 1.3, 3*1.3^2)).
test(regla_cociente) :-
    d(x, x/(x+1), D),
    assertion(valor(x, D, 1.3, 1/(2.3^2))).
test(cociente_funciones) :-
    d(x, sen(x)/x, D),
    assertion(valor(x, D, 1.3, (cos(1.3)*1.3 - sin(1.3))/1.3^2)).
test(sec) :- d(x, sec(x), sec(x)*tan(x)).
test(csc) :- d(x, csc(x), D), assertion(D == -csc(x)*cot(x)).
test(cot) :- d(x, cot(x), D), assertion(D == -csc(x)^2).
test(cadena_sec_csc_cot) :-
    d(x, sec(2*x) + csc(x^2) + cot(3*x), D),
    assertion(valor(x, D, 1.3,
        2*tan(2.6)/cos(2.6) - 2*1.3*cos(1.69)/sin(1.69)^2 - 3/sin(3.9)^2)).
test(cadena_doble) :-
    d(x, sen(cos(x)), D),
    assertion(valor(x, D, 1.3, cos(cos(1.3))*(-sin(1.3)))).
test(funcion_no_soportada, [fail]) :- d(x, desconocida(x), _).

% ------------------------------------------------------------------
% Variable de Prolog sin ligar ("para evaluación"): d(X, Exp, D)
% ------------------------------------------------------------------

test(evaluacion) :- d(X, X^2, D), X = 3, R is D, assertion(R =:= 6).
test(variable_prolog) :-
    d(X, X^3, D), assertion(D == 3*X^2), assertion(var(X)).
test(variable_independiente) :-
    d(X, Y*X, D), assertion(D == Y), assertion(var(X)), assertion(var(Y)).
test(coeficiente_prolog) :- d(X, 4*X^2, D), assertion(D == 8*X^1).
test(suma_prolog) :- d(X, sen(X)+X, D), assertion(D == cos(X)+1).
test(coseno_prolog) :- d(X, cos(X), D), assertion(D == -sen(X)).

% ------------------------------------------------------------------
% Verificación numérica: la derivada coincide con el cociente incremental
% ------------------------------------------------------------------

test(verificacion_numerica) :-
    forall(member(F, [x^3, 3*x^2, x^(-1), 5/x, 3/x^2, log(x), ln(x),
                      sen(x), cos(x), tan(x), exp(x), sqrt(x),
                      4*sen(x), sen(x)/2, -x^2, x^3-x+2, 4*x^4+sen(x)]),
           comprobar_derivada(F)).

comprobar_derivada(F) :-
    d(x, F, D),
    en(F, 1.300001, F1), en(F, 1.299999, F2),
    Aproximada is (F1-F2)/0.000002,
    en(D, 1.3, Exacta),
    assertion(abs(Exacta-Aproximada) < 0.0001).

% valor(Var, Exp, Punto, Esperado): Exp vale Esperado en Var = Punto.
valor(_, Exp, Punto, Esperado) :-
    en(Exp, Punto, V), E is Esperado,
    abs(V-E) < 1.0e-9.

% en(Exp, Punto, V): valor numérico de Exp con x = Punto.
en(Exp, Punto, V) :-
    sustituir_x(Exp, Punto, E),
    V is E.

sustituir_x(x, P, P) :- !.
sustituir_x(E, _, E) :- atomic(E), !.
sustituir_x(sen(A), P, sin(R)) :- !, sustituir_x(A, P, R).
sustituir_x(sec(A), P, 1/cos(R)) :- !, sustituir_x(A, P, R).
sustituir_x(csc(A), P, 1/sin(R)) :- !, sustituir_x(A, P, R).
sustituir_x(cot(A), P, cos(R)/sin(R)) :- !, sustituir_x(A, P, R).
sustituir_x(ln(A), P, log(R)) :- !, sustituir_x(A, P, R).
sustituir_x(E, P, R) :-
    E =.. [F|Args],
    maplist([A, B]>>sustituir_x(A, P, B), Args, RArgs),
    R =.. [F|RArgs].

% ------------------------------------------------------------------
% Pendiente (reparto de trabajo, persona 1)
% ------------------------------------------------------------------



test(exponente_simbolico, [fixme('falta x^y con exponente simbólico')]) :-
    d(x, x^y, D), D == y*x^(y-1).
test(evaluacion_constante, [fixme('las cláusulas para evaluación ligan la variable')]) :-
    d(X, 3*5, D), var(X), D == 0.
test(coeficiente_simbolico_prolog, [fixme('K*X^N con K simbólico lanza un error de is/2')]) :-
    d(X, a*X^2, D), D == a*(2*X).
test(resta_prolog, [fixme('falta la resta en modo evaluación')]) :-
    d(X, X^2-X, D), X = 3, R is D, R =:= 5.
test(exp_prolog, [fixme('falta exp en modo evaluación')]) :-
    d(X, exp(X), D), D == exp(X).

:- end_tests(derivadas).
