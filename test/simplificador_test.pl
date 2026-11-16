:- encoding(utf8).
:- ensure_loaded('../prolog/simplificador').
:- begin_tests(simplificador).

% Términos semejantes y constantes
test(semejantes) :- simplificar(x*x+2*x*x, 3*x^2).
test(conmutativo) :- simplificar(y*x+x*y, 2*x*y).
test(resta_cero) :- simplificar(x-x, 0).
test(constantes) :- simplificar(3-5, -2).
test(fraccion_exacta) :- simplificar(1/2+1/3, 5/6).
test(decimal_redondo) :- simplificar(0.5*x, x/2).
test(salida_prolog) :- simplificar(1/ -1*x^ -1, -(1/x)).
test(salida_integral) :- simplificar(1/1.5*x^1.5, 2*x^(3/2)/3).
test(regla_producto) :- simplificar(4*(4*x^3)+cos(x), 16*x^3+cos(x)).
test(orden_por_grado) :- simplificar(1+x+x^2, x^2+x+1).

% Potencias
test(misma_base) :- simplificar(x^(1/2)*x, x^(3/2)).
test(exponente_simbolico) :- simplificar(x^a*x^b, x^(a+b)).
test(potencia_de_producto) :- simplificar((x*y)^n, x^n*y^n).
test(raiz_exacta) :- simplificar(sqrt(4), 2).
test(raiz_parcial) :- simplificar(sqrt(8), 2*sqrt(2)).
test(raiz_denominador) :- simplificar(x^(-1/2), 1/sqrt(x)).
test(potencia_de_suma) :- simplificar((2*x+2)^2, 4*(x+1)^2).
test(potencia_signo) :- simplificar((1-x)^2, (x-1)^2).
test(base_e) :- simplificar(e^x, exp(x)).

% Cocientes
test(reparte_division) :- simplificar((x^2+x)/x, x+1).
test(deja_fraccion) :- simplificar((x+1)/x, (x+1)/x).
test(cancela_suma) :- simplificar(2*(x+1)/(2*x+2), 1).
test(regla_cociente) :- simplificar((x+1-x)/(x+1)^2, 1/(x+1)^2).
test(division_doble) :- simplificar(a/b/c, a/(b*c)).
test(division_cero, [throws(error_calculo(_))]) :- simplificar(x/0, _).
test(division_cero_calculada, [throws(error_calculo(_))]) :- simplificar(1/(2-2), _).

% Identidades y valores exactos
test(pitagorica) :- simplificar(sen(x)^2+cos(x)^2, 1).
test(pitagorica_con_factor) :- simplificar(3*x*sen(x)^2+3*x*cos(x)^2+1, 3*x+1).
test(tangente) :- simplificar(sen(x)/cos(x), tan(x)).
test(cotangente) :- simplificar(cos(x)^2/sen(x)^2, cot(x)^2).
test(seno_impar) :- simplificar(sen(-x), -sen(x)).
test(coseno_par) :- simplificar(cos(-2*x), cos(2*x)).
test(sen_pi_sexto) :- simplificar(sen(pi/6), 1/2).
test(sen_pi_cuarto) :- simplificar(sen(pi/4), sqrt(2)/2).
test(cos_pi) :- simplificar(cos(pi), -1).
test(cos_dos_tercios) :- simplificar(cos(2*pi/3), -(1/2)).
test(sen_periodo) :- simplificar(sen(13*pi/6), 1/2).
test(tan_pi_cuarto) :- simplificar(tan(pi/4), 1).
test(tan_no_definida, [throws(error_calculo(_))]) :- simplificar(tan(pi/2), _).
test(log_e) :- simplificar(log(e), 1).
test(ln_uno) :- simplificar(ln(1), 0).
test(log_cero, [throws(error_calculo(_))]) :- simplificar(log(0), _).
test(exp_log) :- simplificar(exp(log(x)), x).
test(log_exp) :- simplificar(log(exp(x)), x).
test(abs_numero) :- simplificar(abs(-3), 3).
test(sin_a_sen) :- simplificar(sin(x), sen(x)).

% Variables de Prolog como símbolos
test(variable_prolog) :-
    simplificar(X*X+X, S), assertion(S == X^2+X), assertion(var(X)).

% expandir/2, factorizar/2, evaluar/4, valor_numerico/2
test(expandir_cuadrado) :- expandir((x+1)^2, x^2+2*x+1).
test(expandir_division) :- expandir((x+1)/x, 1+1/x).
test(factor_comun) :- factorizar(2*x^2+4*x, 2*x*(x+2)).
test(fraccion_negativa) :- simplificar(-x/2, -(x/2)).
test(factor_negativo) :- factorizar(-x-1, -(x+1)).
test(evaluar) :- evaluar(x^2+1, x, 3, 10).
test(evaluar_simbolico) :- evaluar(sen(x), x, pi/2, 1).
test(evaluar_otra_variable) :- evaluar(x*y, y, 2, 2*x).
test(numerico) :- valor_numerico(pi/2, N), assertion(abs(N-1.5707963) < 1.0e-6).
test(numerico_funciones) :- valor_numerico(sen(pi/2)+log(e)+sqrt(4), N), assertion(abs(N-4) < 1.0e-9).
test(numerico_simbolo, [fail]) :- valor_numerico(x+1, _).
test(numerico_indefinido, [fail]) :- valor_numerico(log(0), _).

% Simplificar no cambia el valor numérico
test(verificacion_numerica) :-
    forall(member(F, [(X+1)^2/(X+1), X*X-2*X*X+3, sen(X)^2+cos(X)^2+X,
                      (X^2+X)/X, sqrt(8)*X^(1/2)*X, 2*(X+1)/(X+2),
                      tan(X)*cos(X), exp(X)*exp(X)]),
           comprobar_simplificacion(X, F)).

comprobar_simplificacion(X, F) :-
    simplificar(F, S),
    copy_term(X-F, 1.3-F1), copy_term(X-S, 1.3-S1),
    valor_numerico(F1, VF), valor_numerico(S1, VS),
    assertion(abs(VF-VS) < 1.0e-9).

:- end_tests(simplificador).
