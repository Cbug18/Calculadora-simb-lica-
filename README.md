# Prolog Calculator

A web calculator for symbolic **derivatives**, **integrals** and **simplification**. The math is done by a Prolog knowledge base, and the results are shown in LaTeX (KaTeX).

## Run

Needs [Node.js](https://nodejs.org) and [SWI-Prolog](https://www.swi-prolog.org/download/stable) (`swipl` must be on the PATH).

```bash
brew install swi-prolog   # macOS, once (Windows: use the installer from swi-prolog.org)
npm install               # once
npm start                 # http://localhost:3000
npm test                  # parser, JSON API and Prolog unit tests
npm run test:prolog       # only the Prolog unit tests (plunit)
```

## How it works

```
browser (public/)                    server.js                 prolog/
 text ──parser.js──► Prolog term ──► POST /api/calc ──► swipl main.pl ──► d/3, s/3, simplificar/2
 LaTeX ◄──parser.js── result text ◄──────── JSON ◄──────────────┘
```

| File | Role |
|---|---|
| `prolog/derivadas.pl` | derivative rules `d(Var, Exp, D)`, including the product, quotient and chain rules |
| `prolog/integrales.pl` | integral rules `s(Var, Exp, I)` |
| `prolog/simplificador.pl` | `simplificar/2` (collects like terms, folds constants, exact values such as `sen(pi/6) = 1/2`) and `evaluar/4` |
| `prolog/utilidades.pl` | `libre_de/2` (is an expression constant w.r.t. the variable?), `constante_numerica/2`, `divide_entre_cero/1` |
| `prolog/main.pl` | reads one JSON request per line on stdin, queries the KB, writes one JSON response per line |
| `server.js` | serves `public/` and keeps one `swipl main.pl` process running (10 kB per request, 120 requests per minute per IP) |
| `public/parser.js` | text ⇄ AST ⇄ LaTeX / Prolog |
| `public/app.js` | keypad, result screen, history and the "Prolog details" panel |
| `test/*.test.js` | parser and JSON API tests (Node) |
| `test/*_test.pl` | unit tests for each Prolog file (plunit) |

The server first queries the KB with the expression exactly as it was typed. If no rule matches (for example `int(x*x, x)`), it simplifies the input (`x^2`) and queries again, and then tries the expanded form (`(x+1)^2` → `x^2+2*x+1`). The UI tells you when this happens.

Manual test without the UI:

```bash
echo '{"expr":"der(x^3, x) + int(sen(x), x, 0, pi)"}' | swipl prolog/main.pl
```

## Input syntax

Like a scientific calculator, one expression can mix everything, and the **=** key computes it:

| Keypad | Text | Meaning |
|---|---|---|
| d/dx | `der(f, x)` | derivative (uses `d/3`) |
| ∫dx | `int(f, x)` | indefinite integral (uses `s/3`, adds `+ C`) |
| ∫ₐᵇdx | `int(f, x, a, b)` | definite integral, exact `F(b) - F(a)` |

Operators can be nested and combined: `der(int(x^2, x), x)`, `2*der(x^3, x) + int(cos(x), x, 0, pi/2)`.
If the result is a number, a decimal approximation is shown too. **Ans** inserts the previous result.

`4x^4 + sin x`, `3/x^2`, `sqrt(x)`, `e^x`, `2^x`, `ln(x)`, `pi`. Implicit multiplication works. `sin` is sent as `sen`, `ln` as `log`, and `e^x` as `exp(x)`.

### Functions

The **f(x)** key opens a second keypad with the functions that do not fit on the first one.

| Family | Names (as sent to Prolog) | Also accepted |
|---|---|---|
| Trigonometric | `sen`, `cos`, `tan`, `sec`, `csc`, `cot` | `sin` |
| Hyperbolic | `senh`, `cosh`, `tanh`, `sech`, `csch`, `coth` | `sinh` |
| Inverse trigonometric | `arcsen`, `arccos`, `arctan` | `asin`, `arcsin`, `acos`, `atan` |
| Inverse hyperbolic | `arcsenh`, `arccosh`, `arctanh` | `asinh`, `arcsinh`, `acosh`, `atanh` |
| Other | `log`, `exp`, `sqrt`, `abs`, `a^x` | `ln`, `e^x`, `√`, `\|x\|` |

## What the knowledge base knows

**Derivatives** (`d/3` in `prolog/derivadas.pl`): constants, `x^n` (also with a fractional or symbolic exponent), `a^x`, `e^x`, `ln`, `√`, the six trigonometric functions, the six hyperbolic ones, `arcsen`, `arccos`, `arctan`, `arcsenh`, `arccosh` and `arctanh`, plus sums, differences, constant multiples, the **product**, **quotient** and **chain** rules. The chain rule reads the outer derivative from the table `derivada_externa/3`, so a new function needs one rule and one line in that table.

**Integrals** (`s/3` in `prolog/integrales.pl`): constants, `x^n` (with `∫ 1/x = ln|x|`), `K/x^n`, `sen`, `cos`, `tan`, `cot`, `sec`, `csc`, `sec²`, `e^x`, `√x`, `ln x`, and linearity (sums, differences, constant multiples). There is no integration by parts or substitution.

**Evaluation mode**: both `d/3` and `s/3` also accept an unbound Prolog variable, so the result can be evaluated later:

```prolog
?- d(X, X^2, D), X = 3, V is D.      % V = 6
```

## Known limitations

- No rules for `x^x` (a function raised to a function) or for the derivative of `|x|`.
- No integration by parts or substitution: `int(sen(2x), x)` and `int(x*sen(x), x)` are rejected.
- Some evaluation-mode clauses in `derivadas.pl` can still bind the variable (`d(X, 3*5, D)` gives `X = 5`). The four tests that describe this are marked `fixme` in `test/derivadas_test.pl`.
