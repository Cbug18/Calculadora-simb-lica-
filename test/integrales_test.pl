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
test(producto_no_soportado, [fail]) :- s(x, x*tan(x), _).
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
a_numero(senh(A), P, sinh(R)) :- !, a_numero(A, P, R).
a_numero(sec(A), P, 1/cos(R)) :- !, a_numero(A, P, R).
a_numero(csc(A), P, 1/sin(R)) :- !, a_numero(A, P, R).
a_numero(cot(A), P, cos(R)/sin(R)) :- !, a_numero(A, P, R).
a_numero(E, P, R) :-
    E =.. [F|Args], a_numero_lista(Args, P, RArgs), R =.. [F|RArgs].

a_numero_lista([], _, []).
a_numero_lista([A|As], P, [B|Bs]) :- a_numero(A, P, B), a_numero_lista(As, P, Bs).

% ------------------------------------------------------------------
% Fórmulas de reducción: ∫x^n f(x) dx con f = sen, cos, senh, cosh, exp
% ------------------------------------------------------------------

test(senh) :- s(x, senh(x), cosh(x)).
test(cosh) :- s(x, cosh(x), senh(x)).
test(reduccion_x_sen) :-
    s(x, x*sen(x), I), assertion(I == -(x*cos(x))+1*sen(x)).
test(reduccion_x_cos) :-
    s(x, x*cos(x), I), assertion(I == x*sen(x)-1*(-cos(x))).
test(reduccion_x2_sen) :-
    s(x, x^2*sen(x), I),
    assertion(I == -(x^2*cos(x))+2*(x*sen(x)-1*(-cos(x)))).
test(reduccion_x_exp) :- s(x, x*exp(x), I), assertion(I == x*exp(x)-1*exp(x)).
test(reduccion_orden_inverso) :-
    s(x, sen(x)*x^2, I), s(x, x^2*sen(x), I2), assertion(I == I2).
test(reduccion_sin) :- s(x, x*sin(x), I), s(x, x*sen(x), I2), assertion(I == I2).
test(reduccion_coeficiente) :-
    s(x, 3*x^2*cos(x), I), s(x, x^2*cos(x), I2), assertion(I == 3*I2).
test(reduccion_prolog) :-
    s(X, X*cos(X), I), assertion(I == X*sen(X)-1*(-cos(X))), assertion(var(X)).

test(reduccion_verificacion_numerica) :-
    forall(( member(G, [sen(x), sin(x), cos(x), senh(x), cosh(x), exp(x)]),
             member(P, [x, x^2, x^3, x^5]),
             member(F, [P*G, G*P, 4*P*G]) ),
           comprobar_trig(F)).

test(reduccion_exponente_negativo, [fail]) :- s(x, x^(-1)*sen(x), _).
test(reduccion_exponente_fraccionario, [fail]) :- s(x, x^(1/2)*cos(x), _).
test(reduccion_exponente_simbolico, [fail]) :- s(x, x^n*sen(x), _).
test(reduccion_argumento_compuesto, [fail]) :- s(x, x^2*sen(2*x), _).

:- end_tests(integrales).
