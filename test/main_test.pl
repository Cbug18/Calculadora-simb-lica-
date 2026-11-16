:- encoding(utf8).
:- ensure_loaded('../prolog/main').
:- begin_tests(main).

% calcular/2
test(derivada) :- calcular(der(x^3, x), 3*x^2).
test(integral) :- calcular(int(x^2, x), x^3/3).
test(definida) :- calcular(int(sen(x), x, 0, pi), 2).
test(definida_pi_medios) :- calcular(int(cos(x), x, 0, pi/2), 1).
test(definida_simbolica) :- calcular(int(x, x, 0, a), a^2/2).
test(anidada) :- calcular(der(int(x^2, x), x), x^2).
test(combinada) :- calcular(der(x^3, x) + int(sen(x), x, 0, pi), 3*x^2+2).
test(solo_simplificar) :- calcular(x*x+x*x, 2*x^2).
test(regla_producto) :- calcular(der(x*sen(x), x), x*cos(x)+sen(x)).

% Reintentos
test(reintento_simplificada) :-
    calcular(int(x*x, x), R, [Paso], true),
    assertion(R == x^3/3),
    assertion(Paso.retry == "simplificada").
test(reintento_expandida) :-
    calcular(int((x+1)^2, x), R, [Paso], true),
    assertion(R == x^3/3+x^2+x),
    assertion(Paso.retry == "expandida").
test(sin_reintento) :-
    calcular(der(x^2, x), _, [Paso], false),
    assertion(Paso.retry == null).

% +C: solo si queda una integral indefinida sin derivar
test(constante_indefinida) :- calcular(int(x, x), _, _, true).
test(constante_derivada) :- calcular(der(int(x, x), x), _, _, false).
test(constante_definida) :- calcular(int(x, x, 0, 1), _, _, false).

% Errores
test(sin_regla, [throws(error_calculo(_))]) :- calcular(int(sen(2*x), x), _).
test(impropia, [throws(error_calculo(_))]) :- calcular(int(1/x, x, -1, 1), _).
test(log_en_cero, [throws(error_calculo(_))]) :- calcular(int(log(x), x, 0, 1), _).
test(division_cero, [throws(error_calculo(_))]) :- calcular(x/0, _).

% valida/1
test(valida_parser) :- valida(der(4*x^4+sen(x), x) + int(x, x, 0, pi/2) - (-3)).
test(valida_funcion, [throws(error_calculo(_))]) :- valida(foo(x)).
test(valida_aridad, [throws(error_calculo(_))]) :- valida(sen(x, y)).
test(valida_der_variable, [throws(error_calculo(_))]) :- valida(der(x^2, 2)).
test(valida_der_pi, [throws(error_calculo(_))]) :- valida(der(x^2, pi)).
test(valida_int_aridad, [throws(error_calculo(_))]) :- valida(int(x, x, 0)).
test(valida_variable_prolog, [throws(error_calculo(_))]) :- valida(_ + 1).
test(valida_lista, [throws(error_calculo(_))]) :- valida([1, 2]).

% atender/2: el protocolo JSON sin entrada/salida
test(atender_ok) :-
    atender(_{expr: "der(x^2, x)", evalVar: "x", evalAt: "3"}, R),
    assertion(R.ok == true),
    assertion(R.result == "2*x"),
    assertion(R.constant == false),
    assertion(R.decimal == null),
    assertion(R.evaluation.result == "6").
test(atender_decimal) :-
    atender(_{expr: "int(1/x, x, 1, 2)"}, R),
    assertion(R.result == "log(2)"),
    assertion(abs(R.decimal - 0.693147) < 1.0e-6).
test(atender_sintaxis) :-
    atender(_{expr: "der(x^2, x"}, R),
    assertion(R.ok == false), assertion(string(R.error)).
test(atender_mayuscula) :-
    atender(_{expr: "X + 1"}, R),
    assertion(R.ok == false).
test(atender_sin_expr) :-
    atender(_{}, R),
    assertion(R.ok == false).

:- end_tests(main).
