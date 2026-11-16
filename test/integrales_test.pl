:- encoding(utf8).
% Tests de prolog/integrales.pl (base de conocimiento de integrales
% indefinidas elementales). La constante C la agrega la UI.
%
% Los tests marcados con fixme describen lo que la base todavía no integra
% (partes, sustitución, tan, ...). Se ejecutan y se informan como FIXME,
% pero no hacen fallar la suite; cuando la regla exista pasarán solos.
% (Dentro de un fixme se usan objetivos normales: assertion/1 no cuenta.)

% Se carga antes de begin_tests para que s/3 y libre_de/2 queden en el
% módulo user y no choquen con otros ficheros de tests.
:- ensure_loaded('../prolog/integrales').
:- begin_tests(integrales).

% ------------------------------------------------------------------
% Variable atómica: s(x, Exp, I)
% ------------------------------------------------------------------

test(constante) :- s(x, 5, 5*x).
test(constante_simbolica) :- s(x, a, a*x).
test(constante_compuesta) :- s(x, sen(a)+b, I), assertion(I == (sen(a)+b)*x).
test(variable) :- s(x, x, 1/2*x^2).
test(potencia) :- s(x, x^3, 1/4*x^4).
test(potencia_cero) :- s(x, x^0, 1/1*x^1).
test(potencia_fraccionaria) :- s(x, x^(1/2), 1/1.5*x^1.5).
test(inversa_potencia_menos_uno) :- s(x, x^(-1), log(abs(x))).
test(inversa) :- s(x, 1/x, 1*log(abs(x))).
test(k_entre_variable) :- s(x, 5/x, 5*log(abs(x))).
test(k_entre_potencia_uno) :- s(x, 2/x^(2/2), 2*log(abs(x))).
test(k_entre_potencia) :- s(x, 3/x^2, I), assertion(valor(I, 1.3, -3/1.3)).
test(k_entre_potencia_negativa) :- s(x, 1/x^(-2), I), assertion(valor(I, 1.3, 1.3^3/3)).
test(coeficiente) :- s(x, 3*x^(-1), 3*log(abs(x))).
test(coeficiente_potencia) :- s(x, 3*x^2, I), assertion(I == 3*(1/3*x^3)).
test(sen) :- s(x, sen(x), I), assertion(I == -cos(x)).
test(sin) :- s(x, sin(x), I), assertion(I == -cos(x)).
test(cos) :- s(x, cos(x), sen(x)).
test(sec_cuadrado) :- s(x, sec(x)^2, tan(x)).
test(exp) :- s(x, exp(x), exp(x)).
test(sqrt) :- s(x, sqrt(x), 2/3*x^(3/2)).
test(log) :- s(x, log(x), I), assertion(I == x*log(x)-x).
test(ln) :- s(x, ln(x), I), assertion(I == x*log(x)-x).
test(multiplo_izquierda) :- s(x, 4*sen(x), I), assertion(I == 4*(-cos(x))).
test(multiplo_derecha) :- s(x, sen(x)*3, I), assertion(I == (-cos(x))*3).
test(multiplo_simbolico) :- s(x, a*x^2, I), assertion(I == a*(1/3*x^3)).
test(entre_constante) :- s(x, cos(x)/2, sen(x)/2).
test(negativo) :- s(x, -x, I), assertion(I == -(1/2*x^2)).
test(suma) :- s(x, x^2+sen(x), I), assertion(I == 1/3*x^3+(-cos(x))).
test(resta) :- s(x, x^3-x, I), assertion(I == 1/4*x^4-1/2*x^2).
test(polinomio) :-
    s(x, 4*x^3-2*cos(x), I), assertion(I == 4*(1/4*x^4)-2*sen(x)).

% Divisiones entre cero: no hay integral.
test(cero_literal, [fail]) :- s(x, x/0, _).
test(cero_calculado, [fail]) :- s(x, x/(2-2), _).
test(constante_indefinida, [fail]) :- s(x, 1/0, _).
test(cero_anidado, [fail]) :- s(x, sen(1/0), _).

% Fuera de la base de conocimiento.
test(funcion_no_soportada, [fail]) :- s(x, desconocida(x), _).
test(compuesta_no_soportada, [fail]) :- s(x, sen(2*x), _).
test(producto_no_soportado, [fail]) :- s(x, x*sen(x), _).
test(variable_numerica, [fail]) :- s(2, x, _).

% ------------------------------------------------------------------
% Variable de Prolog sin ligar ("para evaluación"): s(X, Exp, I)
% ------------------------------------------------------------------

test(variable_prolog) :-
    s(X, X, I), assertion(I == 1/2*X^2), assertion(var(X)).
test(inversa_variable_prolog) :-
    s(X, X^(-1), I), assertion(I == log(abs(X))), assertion(var(X)).
test(constante_independiente) :-
    s(X, Y, I), assertion(I == Y*X), assertion(var(X)), assertion(var(Y)).
test(constante_numerica_prolog) :-
    s(X, 3*5, I), assertion(I == 3*5*X), assertion(var(X)).
test(sen_prolog) :- s(X, sen(X), I), assertion(I == -cos(X)).
test(exp_prolog) :- s(X, exp(X), I), assertion(I == exp(X)).
test(suma_prolog) :- s(X, cos(X)+X, I), assertion(I == sen(X)+1/2*X^2).
test(coeficiente_simbolico_prolog) :-
    s(X, a*X^2, I), assertion(I == a*(1/3*X^3)).
test(evaluacion) :- s(X, X^2-X, I), X = 3, R is I, assertion(R =:= 4.5).
test(no_instanciar_funcion, [fail]) :- s(X, sen(Y)+X, _), X == Y.

% ------------------------------------------------------------------
% Verificación numérica: la derivada de la integral es el integrando
% ------------------------------------------------------------------

test(verificacion_numerica) :-
    forall(member(F, [7, x, x^3, x^0, x^(1/2), x^(-1), 3*x^2, 5/x, 3/x^2,
                      1/x^(-2), sen(x), sin(x), cos(x), sec(x)^2, exp(x),
                      sqrt(x), log(x), ln(x), 4*sen(x), sen(x)*3, cos(x)/2,
                      -x, x^3-x, 4*x^3-2*cos(x)]),
           comprobar_integral(F)).

test(verificacion_numerica_prolog) :-
    forall(member(F, [X^2, X^(1/2), X^(-1), 3/X^2, exp(X), sqrt(X)]),
           comprobar_integral_prolog(X, F)).

comprobar_integral(F) :-
    s(x, F, I),
    en(I, 1.300001, I1), en(I, 1.299999, I2),
    Aproximada is (I1-I2)/0.000002,
    en(F, 1.3, Exacta),
    assertion(abs(Exacta-Aproximada) < 0.0001).

comprobar_integral_prolog(X, F) :-
    s(X, F, I),
    copy_term(X-I, X1-I1), copy_term(X-I, X2-I2),
    X1 = 1.300001, X2 = 1.299999,
    Aproximada is (I1-I2)/0.000002,
    X = 1.3, Exacta is F,
    assertion(abs(Exacta-Aproximada) < 0.0001).

% valor(Exp, Punto, Esperado): Exp vale Esperado en x = Punto.
valor(Exp, Punto, Esperado) :-
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
sustituir_x(ln(A), P, log(R)) :- !, sustituir_x(A, P, R).
sustituir_x(E, P, R) :-
    E =.. [F|Args],
    maplist([A, B]>>sustituir_x(A, P, B), Args, RArgs),
    R =.. [F|RArgs].

% ------------------------------------------------------------------
% Pendiente (fuera de la base de conocimiento actual)
% ------------------------------------------------------------------

test(por_partes, [fixme('falta integración por partes')]) :-
    s(x, x*sen(x), I),
    valor(I, 1.3, sin(1.3)-1.3*cos(1.3)).
test(sustitucion, [fixme('falta sustitución (regla de la cadena)')]) :-
    s(x, sen(2*x), I),
    valor(I, 1.3, -cos(2.6)/2).
test(exp_compuesta, [fixme('falta sustitución (regla de la cadena)')]) :-
    s(x, exp(2*x), I),
    valor(I, 1.3, exp(2.6)/2).
test(inversa_desplazada, [fixme('falta 1/(x+K) = log|x+K|')]) :-
    s(x, 1/(x+1), I),
    valor(I, 1.3, log(2.3)).
test(tan, [fixme('falta la integral de tan')]) :-
    s(x, tan(x), I),
    valor(I, 1.3, -log(abs(cos(1.3)))).
test(exponente_simbolico, [fixme('falta x^y con exponente simbólico')]) :-
    s(x, x^y, I), I == x^(y+1)/(y+1).

:- end_tests(integrales).
