:- encoding(utf8).
% main.pl — orquesta la base de conocimiento y habla JSON con el servidor.
%
% Protocolo: una petición JSON por línea en la entrada estándar y una
% respuesta JSON por línea en la salida. El proceso atiende peticiones
% hasta que se cierra la entrada, así que el servidor puede mantener un
% solo swipl abierto o lanzar uno por petición:
%
%   echo '{"expr":"der(x^3, x) + int(sen(x), x, 0, pi)"}' | swipl prolog/main.pl
%
% Petición:  {"expr": "...", "evalVar": "x", "evalAt": "pi/2"}
%            (evalVar y evalAt son opcionales)
% Respuesta: {"ok": true, "result": "...", "steps": [...], "constant": bool,
%             "decimal": número | null, "evaluation": {...} | null}
%            {"ok": false, "error": "mensaje"}
%
% Cada paso de "steps" es un objeto con "op" (der, int, simplificar) y lo
% que hizo la base de conocimiento: la consulta, el resultado tal cual
% ("raw"), el resultado simplificado y "retry" si hubo que reintentar con
% la entrada simplificada o expandida.

% SWI-Prolog 10 movió library(http/json) a library(json).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(readutil)).
:- use_module(library(time)).
:- ensure_loaded(derivadas).
:- ensure_loaded(integrales).
:- ensure_loaded(simplificador).

% Solo atiende peticiones cuando main.pl es el script (swipl prolog/main.pl);
% si lo carga otro fichero (p. ej. los tests) no se queda leyendo la entrada.
:- initialization(iniciar, main).

iniciar :-
    ( es_el_script -> main ; true ).

es_el_script :-
    current_prolog_flag(os_argv, Argumentos),
    member(A, Argumentos),
    file_base_name(A, 'main.pl'), !.

limite_segundos(5).
limite_caracteres(1000).

main :-
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    atender_lineas.

atender_lineas :-
    read_line_to_string(user_input, Linea),
    ( Linea == end_of_file -> true
    ; normalize_space(string(""), Linea) -> atender_lineas
    ; atender_linea(Linea, Respuesta),
      json_write_dict(user_output, Respuesta, [width(0)]),
      nl(user_output), flush_output(user_output),
      atender_lineas
    ).

atender_linea(Linea, Respuesta) :-
    ( catch(atom_json_dict(Linea, Peticion, []), _, fail), is_dict(Peticion) ->
        atender(Peticion, Respuesta)
    ; Respuesta = _{ok: false, error: "La petición no es un objeto JSON válido"}
    ).

% atender(+Peticion, -Respuesta): dict -> dict, sin entrada/salida.
atender(Peticion, Respuesta) :-
    limite_segundos(S),
    catch(call_with_time_limit(S, responder(Peticion, Respuesta)),
          Error, respuesta_error(Error, Respuesta)).

respuesta_error(Error, _{ok: false, error: Mensaje}) :-
    mensaje_error(Error, Mensaje).

mensaje_error(error_calculo(M), M) :- !.
mensaje_error(time_limit_exceeded, M) :- !,
    limite_segundos(S),
    format(string(M), "El cálculo tardó demasiado (más de ~w s)", [S]).
mensaje_error(error(resource_error(_), _), "El cálculo necesita demasiada memoria") :- !.
mensaje_error(Error, M) :-
    format(string(M), "Error interno: ~q", [Error]).

responder(Peticion, Respuesta) :-
    campo_texto(Peticion, expr, Texto),
    leer_expresion(Texto, Exp),
    calcular(Exp, R, Pasos, Constante),
    texto(R, Resultado),
    decimal(R, Decimal),
    evaluacion(Peticion, R, Evaluacion),
    Respuesta = _{ok: true, result: Resultado, steps: Pasos,
                  constant: Constante, decimal: Decimal,
                  evaluation: Evaluacion}.

campo_texto(Peticion, Campo, Texto) :-
    ( get_dict(Campo, Peticion, Texto0) -> true
    ; format(string(M), "Falta el campo \"~w\"", [Campo]),
      throw(error_calculo(M))
    ),
    ( string(Texto0) -> Texto = Texto0
    ; format(string(M), "El campo \"~w\" debe ser texto", [Campo]),
      throw(error_calculo(M))
    ).

campo_opcional(Peticion, Campo, Texto) :-
    get_dict(Campo, Peticion, Texto0),
    string(Texto0),
    normalize_space(string(Texto), Texto0),
    Texto \== "".

decimal(R, D) :-
    ( valor_numerico(R, D0) -> D = D0 ; D = null ).

evaluacion(Peticion, R, Evaluacion) :-
    ( campo_opcional(Peticion, evalAt, TextoValor) ->
        ( campo_opcional(Peticion, evalVar, TextoVar) -> true ; TextoVar = "x" ),
        leer_expresion(TextoVar, Var),
        ( variable_valida(Var) -> true
        ; throw(error_calculo("La variable a evaluar debe ser un nombre, ej. x"))
        ),
        leer_expresion(TextoValor, Valor0),
        calcular(Valor0, Valor),
        evaluar(R, Var, Valor, RE),
        texto(RE, Exacto),
        decimal(RE, Decimal),
        texto(Var, NombreVar), texto(Valor, TextoValorFinal),
        Evaluacion = _{var: NombreVar, at: TextoValorFinal,
                       result: Exacto, decimal: Decimal}
    ; Evaluacion = null
    ).

% ------------------------------------------------------------------
% Lectura y validación
% ------------------------------------------------------------------

leer_expresion(Texto, Exp) :-
    string_length(Texto, L), limite_caracteres(Max),
    ( L > Max ->
        format(string(M), "La expresión es demasiado larga (máximo ~w caracteres)", [Max]),
        throw(error_calculo(M))
    ; true
    ),
    ( catch(term_string(Exp, Texto, [variable_names(Vs)]), _, fail) -> true
    ; throw(error_calculo("Error de sintaxis en la expresión"))
    ),
    ( Vs = [Nombre=_|_] ->
        format(string(M), "Las variables van en minúscula: ~w", [Nombre]),
        throw(error_calculo(M))
    ; true
    ),
    valida(Exp).

% valida(+Exp): acepta exactamente lo que emite el parser (public/parser.js);
% si no, lanza error_calculo con el motivo.
valida(Exp) :-
    ( var(Exp) -> throw(error_calculo("La expresión está incompleta"))
    ; number(Exp) -> true
    ; atom(Exp) ->
        ( simbolo_valido(Exp) -> true
        ; invalida("Símbolo no válido: ~w", [Exp])
        )
    ; Exp = der(F, X) ->
        variable_de(der, X), valida(F)
    ; Exp = int(F, X) ->
        variable_de(int, X), valida(F)
    ; Exp = int(F, X, A, B) ->
        variable_de(int, X), valida(F), valida(A), valida(B)
    ; operador(Exp) ->
        Exp =.. [_|Args], maplist(valida, Args)
    ; compound(Exp), compound_name_arity(Exp, Nombre, 1), funcion(Nombre) ->
        arg(1, Exp, A), valida(A)
    ; compound(Exp), compound_name_arity(Exp, Nombre, N), funcion_calculo(Nombre, Aridades) ->
        invalida("~w no admite ~w argumentos (~w)", [Nombre, N, Aridades])
    ; compound(Exp), compound_name_arity(Exp, Nombre, N), funcion(Nombre) ->
        invalida("~w recibe un solo argumento, no ~w", [Nombre, N])
    ; compound(Exp), compound_name_arity(Exp, Nombre, N) ->
        invalida("Función desconocida: ~w/~w", [Nombre, N])
    ; invalida("Expresión no válida: ~q", [Exp])
    ).

invalida(Formato, Args) :-
    format(string(M), Formato, Args),
    throw(error_calculo(M)).

operador(_+_).
operador(_-_).
operador(_*_).
operador(_/_).
operador(_^_).
operador(-(_)).

funcion(sen).
funcion(sin).
funcion(cos).
funcion(tan).
funcion(sec).
funcion(csc).
funcion(cot).
funcion(log).
funcion(ln).
funcion(exp).
funcion(sqrt).
funcion(abs).
funcion(senh).
funcion(cosh).
funcion(tanh).
funcion(sech).
funcion(csch).
funcion(coth).
funcion(arcsen).
funcion(arccos).
funcion(arctan).
funcion(arcsenh).
funcion(arccosh).
funcion(arctanh).

funcion_calculo(der, "der(f, x)").
funcion_calculo(int, "int(f, x) o int(f, x, a, b)").

simbolo_valido(A) :-
    atom_codes(A, [C|Cs]),
    code_type(C, lower),
    forall(member(D, Cs), code_type(D, csym)),
    \+ funcion(A), \+ funcion_calculo(A, _).

variable_valida(X) :-
    atom(X), simbolo_valido(X), X \== pi, X \== e.

variable_de(Op, X) :-
    ( variable_valida(X) -> true
    ; invalida("El 2º argumento de ~w debe ser la variable, ej. ~w(f, x)", [Op, Op])
    ).

% ------------------------------------------------------------------
% calcular/2: resuelve der/int (anidados) y simplifica el resultado
% ------------------------------------------------------------------

calcular(Exp, R) :-
    calcular(Exp, R, _, _).

calcular(Exp, R, Pasos, Constante) :-
    resolver(Exp, R0, Pasos0, Constante),
    simplificar(R0, R),
    ( R0 == R -> Pasos = Pasos0
    ; texto(R0, T0), texto(R, T),
      append(Pasos0, [_{op: "simplificar", input: T0, result: T}], Pasos)
    ).

% resolver(Exp, R, Pasos, Constante): Constante es true si el resultado
% viene de una integral indefinida (la UI añade + C).
resolver(Exp, R, Pasos, Constante) :-
    ( var(Exp) -> R = Exp, Pasos = [], Constante = false
    ; Exp = der(F, X) ->
        resolver(F, F1, P1, _),
        derivar_con_reintento(X, F1, R, Paso),
        append(P1, [Paso], Pasos), Constante = false
    ; Exp = int(F, X) ->
        resolver(F, F1, P1, _),
        integrar_con_reintento(X, F1, R, Paso),
        append(P1, [Paso], Pasos), Constante = true
    ; Exp = int(F, X, A, B) ->
        resolver(F, F1, P1, _), resolver(A, A1, P2, _), resolver(B, B1, P3, _),
        integral_definida(X, F1, A1, B1, R, Paso),
        append([P1, P2, P3, [Paso]], Pasos), Constante = false
    ; compound(Exp) ->
        Exp =.. [Op|Args],
        maplist(resolver, Args, RArgs, PasosArgs, Constantes),
        R =.. [Op|RArgs],
        append(PasosArgs, Pasos),
        ( memberchk(true, Constantes) -> Constante = true ; Constante = false )
    ; R = Exp, Pasos = [], Constante = false
    ).

derivar_con_reintento(X, F, R, Paso) :-
    consultar_con_reintento(d, X, F, D, Usada, Reintento),
    simplificar(D, R),
    paso(der, X, F, Usada, Reintento, D, R, Paso).

integrar_con_reintento(X, F, R, Paso) :-
    consultar_con_reintento(s, X, F, I, Usada, Reintento),
    simplificar(I, R),
    paso(int, X, F, Usada, Reintento, I, R, Paso).

% Primero con la expresión tal como llega; si ninguna regla la reconoce,
% con la expresión simplificada (x*x -> x^2) y luego expandida
% ((x+1)^2 -> x^2+2*x+1).
consultar_con_reintento(Pred, X, F, R, Usada, Reintento) :-
    ( consultar(Pred, X, F, R) -> Usada = F, Reintento = null
    ; simplificar(F, FS), FS \== F, consultar(Pred, X, FS, R) ->
        Usada = FS, Reintento = "simplificada"
    ; expandir(F, FE), FE \== F, consultar(Pred, X, FE, R) ->
        Usada = FE, Reintento = "expandida"
    ; texto(F, TF),
      ( Pred == d ->
          format(string(M), "No hay regla para derivar ~w respecto a ~w", [TF, X])
      ; format(string(M), "No hay regla para integrar ~w respecto a ~w", [TF, X])
      ),
      throw(error_calculo(M))
    ).

consultar(d, X, F, R) :-
    once(d(X, F, R)).
consultar(s, X, F, R) :-
    once(s(X, F, R)).

paso(Op, X, F, Usada, Reintento, Crudo, R, Paso) :-
    texto(X, TX), texto(F, TF), texto(Usada, TU),
    texto(Crudo, TC), texto(R, TR),
    ( Op == der -> Pred = d ; Pred = s ),
    format(string(Consulta), "~w(~w, ~w, ~w)", [Pred, TX, TU, 'R']),
    Paso = _{op: Op, var: TX, input: TF, query: Consulta,
             raw: TC, result: TR, retry: Reintento}.

% int(F, X, A, B) = G(B) - G(A), con G la primitiva.
integral_definida(X, F, A, B, R, Paso) :-
    consultar_con_reintento(s, X, F, G0, Usada, Reintento),
    simplificar(G0, G),
    comprobar_intervalo(X, F, A, B),
    valor_en_limite(G, X, B, GB),
    valor_en_limite(G, X, A, GA),
    simplificar(GB-GA, R),
    ( valor_numerico(A, _), valor_numerico(B, _), \+ valor_numerico(R, _) ->
        throw(error_calculo("La integral definida no da un valor finito"))
    ; true
    ),
    paso(int, X, F, Usada, Reintento, G0, G, Paso0),
    texto(A, TA), texto(B, TB), texto(R, TR),
    Paso = Paso0.put(_{from: TA, to: TB, antiderivative: Paso0.result, result: TR}).

valor_en_limite(G, X, Limite, V) :-
    catch(evaluar(G, X, Limite, V), error_calculo(_),
          ( texto(G, TG), texto(Limite, TL),
            format(string(M), "La primitiva ~w no está definida en ~w = ~w", [TG, X, TL]),
            throw(error_calculo(M)) )).

% Si los límites son números, la función tiene que estar definida en todo
% [A, B]; si no, es una integral impropia (p. ej. 1/x entre -1 y 1).
comprobar_intervalo(X, F, A, B) :-
    ( valor_numerico(A, NA), valor_numerico(B, NB), solo_variable(F, X) ->
        ( forall(between(0, 100, I),
                 ( V is NA + (NB-NA)*I/100,
                   sustituir(F, X, V, FV),
                   valor_numerico(FV, _) )) -> true
        ; texto(F, TF), texto(A, TA), texto(B, TB),
          format(string(M), "~w no está definida en todo el intervalo [~w, ~w] (integral impropia)", [TF, TA, TB]),
          throw(error_calculo(M))
        )
    ; true
    ).

solo_variable(E, X) :-
    ( E == X -> true
    ; number(E) -> true
    ; atom(E) -> memberchk(E, [pi, e])
    ; compound(E) -> E =.. [_|Args], forall(member(A, Args), solo_variable(A, X))
    ).

texto(T, S) :-
    with_output_to(string(S),
                   write_term(T, [quoted(true), spacing(next_argument)])).
