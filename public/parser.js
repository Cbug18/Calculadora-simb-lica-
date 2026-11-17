// parser.js — analizador de expresiones compartido por el navegador y los tests.
//
//   parse(texto)    -> AST          (acepta la entrada del usuario Y la salida de Prolog)
//   toLatex(ast)    -> cadena LaTeX (se dibuja con KaTeX)
//   toProlog(ast)   -> término Prolog que se envía a SWI-Prolog
//   evaluate(ast, vars) -> número
//
// Operadores de cálculo (como en una calculadora científica):
//   der(f, x)          derivada de f respecto a x      (x por defecto)
//   int(f, x)          integral indefinida             (x por defecto)
//   int(f, x, a, b)    integral definida de a a b
//
// Nodos del AST:
//   { type: 'num',  value: '3.5' }
//   { type: 'sym',  name: 'x' }
//   { type: 'neg',  arg }
//   { type: 'bin',  op: '+'|'-'|'*'|'/'|'^', left, right }
//   { type: 'call', name: 'sen', args: [...] }

(function (root) {
  'use strict';

  // Nombres aceptados -> nombre canónico que usa la base de conocimiento.
  const FUNCS = {
    sin: 'sen', sen: 'sen', cos: 'cos', tan: 'tan', sec: 'sec', csc: 'csc',
        cot: 'cot', log: 'log', ln: 'log', exp: 'exp', sqrt: 'sqrt', abs: 'abs',
    // Hiperbólicas
    senh: 'senh', sinh: 'senh', cosh: 'cosh', tanh: 'tanh',
    sech: 'sech', csch: 'csch', coth: 'coth',
    // Trigonométricas inversas
    arcsen: 'arcsen', arcsin: 'arcsen', asin: 'arcsen',
    arccos: 'arccos', acos: 'arccos', arctan: 'arctan', atan: 'arctan',
    // Hiperbólicas inversas
    arcsenh: 'arcsenh', arcsinh: 'arcsenh', asinh: 'arcsenh',
    arccosh: 'arccosh', acosh: 'arccosh', arctanh: 'arctanh', atanh: 'arctanh',
    der: 'der', int: 'int',
  };
  // Aridades permitidas.
  const ARITY = { der: [1, 2], int: [1, 2, 4] };
  const CALCULUS = new Set(['der', 'int']);
  const CONSTS = ['pi', 'e'];
  // Nombres más largos primero: "sqrt" antes que "s", "exp" antes que "e", etc.
  const KNOWN = [...Object.keys(FUNCS), 'pi'].sort((a, b) => b.length - a.length);

  class ParseError extends Error {}

  // ------------------------------------------------------------------
  // Tokenizador
  // ------------------------------------------------------------------
  function tokenize(src) {
    const s = src
      .replace(/\*\*/g, '^')
      .replace(/[·×⋅]/g, '*')
      .replace(/÷/g, '/')
      .replace(/[−–]/g, '-')
      .replace(/π/g, 'pi')
      .replace(/√/g, 'sqrt')
      .replace(/∫/g, 'int')
      .replace(/²/g, '^2')
      .replace(/³/g, '^3');
    const tokens = [];
    let i = 0;
    while (i < s.length) {
      const c = s[i];
      if (/\s/.test(c)) { i++; continue; }
      if (/[0-9.]/.test(c)) {
        const m = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(i));
        if (!m) throw new ParseError(`Carácter inesperado "${c}"`);
        tokens.push({ t: 'num', v: String(Number(m[1])) });
        i += m[1].length;
        continue;
      }
      if (/[a-zA-Z_]/.test(c)) {
        const m = /^[a-zA-Z_]+/.exec(s.slice(i));
        for (const id of splitIdent(m[0].toLowerCase())) tokens.push({ t: 'id', v: id });
        i += m[0].length;
        continue;
      }
      if ('+-*/^(),'.includes(c)) { tokens.push({ t: c }); i++; continue; }
      if (c === '[' || c === '{') { tokens.push({ t: '(' }); i++; continue; }
      if (c === ']' || c === '}') { tokens.push({ t: ')' }); i++; continue; }
      throw new ParseError(`Carácter inesperado "${c}"`);
    }
    return tokens;
  }

  // "sinx" -> ["sin","x"], "xy" -> ["x","y"], "pi" -> ["pi"]
  function splitIdent(word) {
    const out = [];
    let rest = word;
    while (rest) {
      const name = KNOWN.find((k) => rest.startsWith(k));
      if (name) { out.push(name); rest = rest.slice(name.length); }
      else { out.push(rest[0]); rest = rest.slice(1); }
    }
    return out;
  }

  // ------------------------------------------------------------------
  // Analizador Pratt
  // ------------------------------------------------------------------
  const BP = { '+': 10, '-': 10, '*': 20, '/': 20, '^': 30 };
  const IMPLICIT = 20;   // multiplicación implícita: 2x, 3sen(x), (x+1)(x-1)
  const UNARY = 25;      // -x^2 = -(x^2), pero -3*x = (-3)*x

  function parse(src) {
    const tokens = tokenize(src);
    if (!tokens.length) throw new ParseError('Expresión vacía');
    let pos = 0;
    const peek = () => tokens[pos];
    const next = () => tokens[pos++];
    const expect = (t) => {
      const tok = next();
      if (!tok || tok.t !== t) throw new ParseError(`Se esperaba "${t}"`);
    };

    function expr(rbp) {
      let left = nud(next());
      for (;;) {
        const tok = peek();
        if (!tok) break;
        if (BP[tok.t] !== undefined) {
          if (BP[tok.t] <= rbp) break;
          next();
          // ^ es asociativo por la derecha
          const right = expr(tok.t === '^' ? BP['^'] - 1 : BP[tok.t]);
          left = { type: 'bin', op: tok.t, left, right };
        } else if (tok.t === 'num' || tok.t === 'id' || tok.t === '(') {
          if (IMPLICIT <= rbp) break;
          left = { type: 'bin', op: '*', left, right: expr(IMPLICIT) };
        } else break;
      }
      return left;
    }

    function nud(tok) {
      if (!tok) throw new ParseError('La expresión está incompleta');
      switch (tok.t) {
        case 'num':
          return { type: 'num', value: tok.v };
        case 'id': {
          const name = FUNCS[tok.v];
          if (!name) return { type: 'sym', name: tok.v };
          let args;
          if (peek() && peek().t === '(') {
            next();
            args = [expr(0)];
            while (peek() && peek().t === ',') { next(); args.push(expr(0)); }
            expect(')');
          } else if (CALCULUS.has(name)) {
            throw new ParseError(`${name} necesita paréntesis: ${name}(f, x)`);
          } else {
            args = [expr(UNARY)];              // "sen x" -> sen(x)
          }
          return makeCall(name, args);
        }
        case '(': {
          const e = expr(0);
          expect(')');
          return e;
        }
        case '-':
          return { type: 'neg', arg: expr(UNARY) };
        case '+':
          return expr(UNARY);
        case ',':
          throw new ParseError('Falta un argumento antes de ","');
        default:
          throw new ParseError(`Inesperado "${tok.t}"`);
      }
    }

    const ast = expr(0);
    if (pos < tokens.length) throw new ParseError(`Inesperado "${tokens[pos].v || tokens[pos].t}"`);
    return normalize(ast);
  }

  function makeCall(name, args) {
    const allowed = ARITY[name] || [1];
    if (!allowed.includes(args.length)) {
      if (name === 'der') throw new ParseError('Uso: der(f, x)');
      if (name === 'int') throw new ParseError('Uso: int(f, x) o int(f, x, a, b)');
      throw new ParseError(`${name} recibe un solo argumento`);
    }
    if (CALCULUS.has(name)) {
      if (args.length === 1) args = [args[0], { type: 'sym', name: 'x' }];
      const v = args[1];
      if (v.type !== 'sym' || CONSTS.includes(v.name))
        throw new ParseError(`El 2º argumento de ${name} debe ser la variable, ej. ${name}(f, x)`);
    }
    return { type: 'call', name, args };
  }

  // e^X -> exp(X)
  function normalize(n) {
    switch (n.type) {
      case 'bin': {
        const left = normalize(n.left);
        const right = normalize(n.right);
        if (n.op === '^' && left.type === 'sym' && left.name === 'e')
          return { type: 'call', name: 'exp', args: [right] };
        return { ...n, left, right };
      }
      case 'neg': return { ...n, arg: normalize(n.arg) };
      case 'call': return { ...n, args: n.args.map(normalize) };
      default: return n;
    }
  }

  // ------------------------------------------------------------------
  // AST -> Prolog
  // ------------------------------------------------------------------
  const PL_PREC = { '+': 500, '-': 500, '*': 400, '/': 400, '^': 200 };

  function toProlog(n) {
    switch (n.type) {
      case 'num': return n.value;
      case 'sym': return n.name;
      case 'neg':
        // (-3) Prolog lo lee como el número -3, que es lo que esperan las reglas.
        return n.arg.type === 'num' ? `(-${n.arg.value})` : `-(${toProlog(n.arg)})`;
      case 'call': return `${n.name}(${n.args.map(toProlog).join(', ')})`;
      case 'bin': {
        const p = PL_PREC[n.op];
        const lp = plPrec(n.left);
        const rp = plPrec(n.right);
        // yfx (+ - * /): la izquierda puede ser igual; xfy (^): la derecha.
        const wrapL = n.op === '^' ? lp >= p : lp > p;
        const wrapR = n.op === '^' ? rp > p : rp >= p;
        const L = wrapL ? `(${toProlog(n.left)})` : toProlog(n.left);
        const R = wrapR ? `(${toProlog(n.right)})` : toProlog(n.right);
        return `${L} ${n.op} ${R}`;
      }
    }
  }
  const plPrec = (n) => (n.type === 'bin' ? PL_PREC[n.op] : 0);

  // ------------------------------------------------------------------
  // AST -> LaTeX
  // ------------------------------------------------------------------
  // Funciones que se escriben f^2(x) cuando van elevadas: sen^2(x), cosh^2(x).
  const TRIG = {
    sen: '\\operatorname{sen}', cos: '\\cos', tan: '\\tan', sec: '\\sec', csc: '\\csc', cot: '\\cot',
    senh: '\\operatorname{senh}', cosh: '\\cosh', tanh: '\\tanh',
    sech: '\\operatorname{sech}', csch: '\\operatorname{csch}', coth: '\\coth',
  };
  // Inversas: (arcsen(x))^2, nunca arcsen^2(x).
  const INVERSAS = {
    arcsen: '\\operatorname{arcsen}', arccos: '\\arccos', arctan: '\\arctan',
    arcsenh: '\\operatorname{arcsenh}', arccosh: '\\operatorname{arccosh}',
    arctanh: '\\operatorname{arctanh}',
  };
  const SYMS = { pi: '\\pi' };

  const isSum = (n) => n.type === 'bin' && (n.op === '+' || n.op === '-');
  const isCalculus = (n) => n.type === 'call' && CALCULUS.has(n.name);
  const paren = (s) => `\\left(${s}\\right)`;
  const isHalf = (n) =>
    n.type === 'bin' && n.op === '/' && n.left.type === 'num' && n.left.value === '1' &&
    n.right.type === 'num' && n.right.value === '2';

  function toLatex(n) {
    switch (n.type) {
      case 'num': return n.value;
      case 'sym': return SYMS[n.name] || (n.name.length > 1 ? `\\mathrm{${n.name}}` : n.name);
      case 'neg': {
        const a = toLatex(n.arg);
        return '-' + (isSum(n.arg) || isCalculus(n.arg) ? paren(a) : a);
      }
      case 'call': return callLatex(n);
      case 'bin': return binLatex(n);
    }
  }

  function callLatex(n, power) {
    const { name, args } = n;
    if (name === 'der') {
      return `\\frac{d}{d${toLatex(args[1])}}\\left[${toLatex(args[0])}\\right]`;
    }
    if (name === 'int') {
      const f = args[0];
      const body = isSum(f) ? paren(toLatex(f)) : toLatex(f);
      const lim = args.length === 4 ? `_{${toLatex(args[2])}}^{${toLatex(args[3])}}` : '';
      return `\\int${lim} ${body}\\,d${toLatex(args[1])}`;
    }
    const arg = args[0];
    const a = toLatex(arg);
    const simple = arg.type === 'sym' || arg.type === 'num';
    const wrapped = simple ? `(${a})` : paren(a);
    const pow = power ? `^{${power}}` : '';
    if (TRIG[name]) return `${TRIG[name]}${pow}${wrapped}`;
    if (name === 'log') return `\\ln${pow}${wrapped}`;
    let base;
    if (name === 'exp') base = `e^{${a}}`;
    else if (name === 'sqrt') base = `\\sqrt{${a}}`;
    else if (name === 'abs') base = `\\left|${a}\\right|`;
    else base = `${INVERSAS[name] || `\\operatorname{${name}}`}${wrapped}`;
    return power ? `${paren(base)}^{${power}}` : base;
  }

  function binLatex(n) {
    const { op, left, right } = n;
    if (op === '+') {
      if (right.type === 'neg') return `${toLatex(left)} - ${wrapIf(right.arg, isSum(right.arg))}`;
      return `${toLatex(left)} + ${toLatex(right)}`;
    }
    if (op === '-') return `${toLatex(left)} - ${wrapIf(right, isSum(right) || right.type === 'neg')}`;
    if (op === '/') return `\\frac{${toLatex(left)}}{${toLatex(right)}}`;
    if (op === '^') {
      if (isHalf(right)) return `\\sqrt{${toLatex(left)}}`;
      const exp = toLatex(right);
      // sen(x)^2 -> \operatorname{sen}^{2}(x)
      if (left.type === 'call' && (TRIG[left.name] || left.name === 'log'))
        return callLatex(left, exp);
      const needParen = left.type === 'bin' || left.type === 'neg' || left.type === 'call' ||
        (left.type === 'num' && left.value.includes('.'));
      const base = toLatex(left);
      return `${needParen ? paren(base) : base}^{${exp}}`;
    }
    // '*'
    const L = wrapIf(left, isSum(left));
    const R = wrapIf(right, isSum(right) || right.type === 'neg');
    // Punto donde yuxtaponer sería ambiguo: 2·3, 2·½ (no "2½"), ½·¾
    const leftIsNumOrFrac = left.type === 'num' || (left.type === 'bin' && left.op === '/');
    const needDot = /^[0-9.]/.test(R) || right.type === 'num' ||
      (leftIsNumOrFrac && R.startsWith('\\frac'));
    return needDot ? `${L} \\cdot ${R}` : `${L}\\,${R}`;
  }

  const wrapIf = (n, cond) => (cond ? paren(toLatex(n)) : toLatex(n));

  // ------------------------------------------------------------------
  // Evaluación numérica (solo para el campo "evaluar en")
  // ------------------------------------------------------------------
  const NUMF = {
    sen: Math.sin, cos: Math.cos, tan: Math.tan, sec: (x) => 1 / Math.cos(x),
    csc: (x) => 1 / Math.sin(x), cot: (x) => 1 / Math.tan(x), log: Math.log,
    exp: Math.exp, sqrt: Math.sqrt, abs: Math.abs,
    senh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh, sech: (x) => 1 / Math.cosh(x),
    csch: (x) => 1 / Math.sinh(x), coth: (x) => 1 / Math.tanh(x),
    arcsen: Math.asin, arccos: Math.acos, arctan: Math.atan,
    arcsenh: Math.asinh, arccosh: Math.acosh, arctanh: Math.atanh,
  };

  function evaluate(n, vars = {}) {
    switch (n.type) {
      case 'num': return Number(n.value);
      case 'sym':
        if (n.name in vars) return vars[n.name];
        if (n.name === 'pi') return Math.PI;
        if (n.name === 'e') return Math.E;
        throw new ParseError(`"${n.name}" no tiene valor`);
      case 'neg': return -evaluate(n.arg, vars);
      case 'call':
        if (!NUMF[n.name]) throw new ParseError(`${n.name} no se puede usar aquí`);
        return NUMF[n.name](evaluate(n.args[0], vars));
      case 'bin': {
        const a = evaluate(n.left, vars), b = evaluate(n.right, vars);
        return { '+': a + b, '-': a - b, '*': a * b, '/': a / b, '^': a ** b }[n.op];
      }
    }
  }

  const api = { parse, toLatex, toProlog, evaluate, ParseError, CONSTS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.MathParser = api;
})(typeof window !== 'undefined' ? window : globalThis);
