# Calculadora Prolog

Calculadora web de **derivadas**, **integrales** y **simplificación** simbólicas. Las cuentas las hace una base de conocimiento en Prolog y los resultados se muestran en LaTeX (KaTeX).

## Cómo ejecutarla

Necesita [Node.js](https://nodejs.org) y [SWI-Prolog](https://www.swi-prolog.org/download/stable) (`swipl` tiene que estar en el PATH).

```bash
brew install swi-prolog   # macOS, una vez (Windows: el instalador de swi-prolog.org)
npm install               # una vez
npm start                 # http://localhost:3000
npm test                  # tests del parser, de la API JSON y de Prolog
npm run test:prolog       # solo los tests de Prolog (plunit)
```

## Cómo funciona

```
navegador (public/)                  server.js                 prolog/
 texto ──parser.js──► término Prolog ──► POST /api/calc ──► swipl main.pl ──► d/3, s/3, simplificar/2
 LaTeX ◄──parser.js── texto del resultado ◄──── JSON ◄─────────────┘
```

| Archivo | Función |
|---|---|
| `prolog/derivadas.pl` | reglas de derivación `d(Var, Exp, D)`, con las reglas del producto, del cociente y de la cadena |
| `prolog/integrales.pl` | reglas de integración `s(Var, Exp, I)`, con fórmulas de reducción |
| `prolog/simplificador.pl` | `simplificar/2` (agrupa términos semejantes, opera constantes, aplica identidades trigonométricas e hiperbólicas y valores exactos como `sen(pi/6) = 1/2`) y `evaluar/4` |
| `prolog/utilidades.pl` | `libre_de/2` (¿la expresión es constante respecto a la variable?), `constante_numerica/2`, `divide_entre_cero/1` |
| `prolog/main.pl` | lee una petición JSON por línea de stdin, consulta la base y escribe una respuesta JSON por línea |
| `server.js` | sirve `public/` y mantiene un proceso `swipl main.pl` (10 kB por petición, 120 peticiones por minuto por IP) |
| `public/parser.js` | texto ⇄ AST ⇄ LaTeX / Prolog |
| `public/app.js` | teclado, pantalla de resultados, historial y el panel "Detalles de Prolog" |
| `test/*.test.js` | tests del parser y de la API JSON (Node) |
| `test/*_test.pl` | tests unitarios de cada archivo Prolog (plunit) |

El servidor consulta primero la base con la expresión tal como se escribió. Si ninguna regla aplica (por ejemplo `int(x*x, x)`), simplifica la entrada (`x^2`) y vuelve a consultar; después prueba con la forma expandida (`(x+1)^2` → `x^2+2*x+1`). La interfaz avisa cuando pasa esto.

Prueba manual sin la interfaz:

```bash
echo '{"expr":"der(x^3, x) + int(sen(x), x, 0, pi)"}' | swipl prolog/main.pl
```

## Sintaxis de entrada

Como en una calculadora científica, una misma expresión puede mezclarlo todo y la tecla **=** la calcula:

| Teclado | Texto | Significado |
|---|---|---|
| d/dx | `der(f, x)` | derivada (usa `d/3`) |
| ∫dx | `int(f, x)` | integral indefinida (usa `s/3` y agrega `+ C`) |
| ∫ₐᵇdx | `int(f, x, a, b)` | integral definida, exacta `F(b) - F(a)` |

Los operadores se pueden anidar y combinar: `der(int(x^2, x), x)`, `2*der(x^3, x) + int(cos(x), x, 0, pi/2)`.
Si el resultado es un número también se muestra su aproximación decimal. **Ans** inserta el resultado anterior.

`4x^4 + sin x`, `3/x^2`, `sqrt(x)`, `e^x`, `2^x`, `ln(x)`, `pi`. La multiplicación implícita funciona. `sin` se envía como `sen`, `ln` como `log` y `e^x` como `exp(x)`.

### Funciones

La tecla **f(x)** abre un segundo teclado con las funciones que no caben en el primero.

| Familia | Nombres (como se envían a Prolog) | También se acepta |
|---|---|---|
| Trigonométricas | `sen`, `cos`, `tan`, `sec`, `csc`, `cot` | `sin` |
| Hiperbólicas | `senh`, `cosh`, `tanh`, `sech`, `csch`, `coth` | `sinh` |
| Trigonométricas inversas | `arcsen`, `arccos`, `arctan` | `asin`, `arcsin`, `acos`, `atan` |
| Hiperbólicas inversas | `arcsenh`, `arccosh`, `arctanh` | `asinh`, `arcsinh`, `acosh`, `atanh` |
| Otras | `log`, `exp`, `sqrt`, `abs`, `a^x` | `ln`, `e^x`, `√`, `\|x\|` |

## Qué sabe la base de conocimiento

**Derivadas** (`d/3` en `prolog/derivadas.pl`): constantes, `x^n` (también con exponente fraccionario o simbólico), `a^x`, `e^x`, `ln`, `√`, las seis funciones trigonométricas, las seis hiperbólicas, `arcsen`, `arccos`, `arctan`, `arcsenh`, `arccosh` y `arctanh`, además de sumas, restas, múltiplos constantes y las reglas del **producto**, del **cociente** y de la **cadena**. La regla de la cadena toma la derivada exterior de la tabla `derivada_externa/3`, así que una función nueva necesita una regla y una línea en esa tabla.

**Integrales** (`s/3` en `prolog/integrales.pl`): constantes, `x^n` (con `∫ 1/x = ln|x|`), `K/x^n`, `sen`, `cos`, `tan`, `cot`, `sec`, `csc`, `sec²`, `senh`, `cosh`, `e^x`, `√x`, `ln x`, linealidad (sumas, restas, múltiplos constantes) y las fórmulas de reducción de la sección siguiente.

### Fórmulas de reducción

Para `xⁿ·f(x)` con `n` entero positivo, la base aplica integración por partes de forma recursiva:

```
∫ xⁿ sen x  dx = -xⁿ cos x  + n ∫ xⁿ⁻¹ cos x  dx
∫ xⁿ cos x  dx =  xⁿ sen x  - n ∫ xⁿ⁻¹ sen x  dx
∫ xⁿ senh x dx =  xⁿ cosh x - n ∫ xⁿ⁻¹ cosh x dx
∫ xⁿ cosh x dx =  xⁿ senh x - n ∫ xⁿ⁻¹ senh x dx
∫ xⁿ eˣ     dx =  xⁿ eˣ     - n ∫ xⁿ⁻¹ eˣ     dx
```

- **Caso base** (`n = 0`): la integral elemental de la función (`∫sen = -cos`, `∫cosh = senh`, ...).
- **Paso recursivo**: si `∫f = s·g` (con `s = ±1`), entonces `∫xⁿ·f = s·xⁿ·g − s·n·∫xⁿ⁻¹·g`, y se vuelve a aplicar con `n − 1`.
- Las primitivas salen de la tabla `primitiva/3`; para agregar otra función basta una línea.
- Funciona con los factores en cualquier orden (`x²·sen x` o `sen x·x²`), con un coeficiente delante (`3x²·cos x`) y en el modo de evaluación.

```
int(x^2*sen(x), x)    →  -x^2*cos(x) + 2*x*sen(x) + 2*cos(x) + C
int(x^3*e^x, x)       →  x^3*exp(x) - 3*x^2*exp(x) + 6*x*exp(x) - 6*exp(x) + C
int(x*sen(x), x, 0, pi)  →  pi
```

### Identidades de la simplificación

`simplificar/2` aplica las identidades de cociente dentro de un producto:

| Trigonométricas | Hiperbólicas |
|---|---|
| `tan = sen/cos` | `tanh = senh/cosh` |
| `cot = cos/sen` | `coth = cosh/senh` |
| `sec = 1/cos` | `sech = 1/cosh` |
| `csc = 1/sen` | `csch = 1/senh` |

Pasa estas funciones a `sen` y `cos` (o `senh` y `cosh`), junta los exponentes y vuelve a escribir el resultado con la función más corta cuando coincide exactamente con una de ellas. Las identidades están en la tabla `cociente/5`. Ejemplos: `tan(x)*cos(x)` → `sen(x)`, `tan(x)*cot(x)` → `1`, `sen(x)*sec(x)` → `tan(x)`, `1/cos(x)^2` → `sec(x)^2`. Si no coincide, la expresión se deja igual (`sen(x)*cos(x)`).

También aplica las identidades pitagóricas `sen² + cos² = 1` y `cosh² − senh² = 1`, incluso con un factor común (`3x·cosh² − 3x·senh² + 1` → `3x + 1`).

Gracias a estas identidades y al reintento con la entrada simplificada, `der(sen(x)/cos(x), x)` y `int(1/cos(x)^2, x)` también funcionan.

### Modo de evaluación

`d/3` y `s/3` también aceptan una variable de Prolog sin ligar, para evaluar el resultado después:

```prolog
?- d(X, X^2, D), X = 3, V is D.      % V = 6
```

## Limitaciones conocidas

- No hay reglas para `x^x` (una función elevada a otra función) ni para la derivada de `|x|`.
- No hay integración por sustitución: `int(sen(2x), x)` se rechaza.
- Las fórmulas de reducción solo cubren `xⁿ` (con `n` entero positivo) por `sen`, `cos`, `senh`, `cosh` o `eˣ` de la propia variable: `int(x*tan(x), x)` o `int(x^2*sen(2x), x)` se rechazan.
- Algunas cláusulas del modo de evaluación de `derivadas.pl` todavía pueden ligar la variable (`d(X, 3*5, D)` da `X = 5`). Los tests que lo describen están marcados `fixme` en `test/derivadas_test.pl`.
