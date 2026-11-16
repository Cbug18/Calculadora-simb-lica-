// app.js — keypad, live preview, calls to /api/calc, result screen and history.
(function () {
  'use strict';

  const { parse, toLatex, toProlog, ParseError } = window.MathParser;
  const $ = (id) => document.getElementById(id);
  const exprInput = $('expr');
  const evarInput = $('evar');
  const eatInput = $('eat');
  const preview = $('preview');
  const resultBox = $('result');
  const historyList = $('history');
  const statusBadge = $('status');

  const HISTORY_KEY = 'calculadora-prolog:historial';
  const HISTORY_MAX = 20;
  let lastResult = null;   // Prolog text of the last result, for Ans
  let busy = false;

  // ------------------------------------------------------------------
  // KaTeX (falls back to plain text if the CDN did not load)
  // ------------------------------------------------------------------
  function renderTex(el, tex, display = false) {
    if (window.katex) {
      window.katex.render(tex, el, { throwOnError: false, displayMode: display });
    } else {
      el.textContent = tex;
    }
  }

  function texSpan(tex, display = false) {
    const span = document.createElement('span');
    renderTex(span, tex, display);
    return span;
  }

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  // Prolog result text -> LaTeX (falls back to the raw text).
  function prologToTex(text) {
    try {
      return toLatex(parse(text));
    } catch {
      return `\\texttt{${text.replace(/[\\{}]/g, '')}}`;
    }
  }

  // ------------------------------------------------------------------
  // Keypad
  // ------------------------------------------------------------------
  // [label (LaTeX unless text: true), action, class, aria-label]
  // action: string to insert; '|' marks where the cursor goes.
  const KEYS = [
    ['\\tfrac{d}{dx}', 'der(|, x)', 'calc', 'derivada'],
    ['\\int dx', 'int(|, x)', 'calc', 'integral indefinida'],
    ['\\int_a^b', 'int(|, x, 0, 1)', 'calc', 'integral definida'],
    ['(', '(', 'fn', 'abrir paréntesis'],
    [')', ')', 'fn', 'cerrar paréntesis'],
    ['⌫', 'back', 'ctl', 'borrar', true],

    ['\\operatorname{sen}', 'sen(|)', 'fn', 'seno'],
    ['\\cos', 'cos(|)', 'fn', 'coseno'],
    ['\\tan', 'tan(|)', 'fn', 'tangente'],
    ['\\ln', 'ln(|)', 'fn', 'logaritmo natural'],
    ['e^{x}', 'e^(|)', 'fn', 'exponencial'],
    ['\\sqrt{x}', 'sqrt(|)', 'fn', 'raíz cuadrada'],

    ['7', '7'], ['8', '8'], ['9', '9'],
    ['\\div', '/', 'fn', 'dividir'],
    ['x^{y}', '^', 'fn', 'potencia'],
    ['x', 'x', 'fn', 'x'],

    ['4', '4'], ['5', '5'], ['6', '6'],
    ['\\times', '*', 'fn', 'multiplicar'],
    ['+', '+', 'fn', 'sumar'],
    ['\\pi', 'pi', 'fn', 'pi'],

    ['1', '1'], ['2', '2'], ['3', '3'],
    ['-', '-', 'fn', 'restar'],
    [',', ', ', 'fn', 'coma'],
    ['Ans', 'ans', 'fn', 'resultado anterior', true],

    ['0', '0'], ['.', '.'],
    ['AC', 'clear', 'ctl', 'borrar todo', true],
    ['=', 'go', 'go', 'calcular', true],
  ];

  function buildKeypad() {
    const pad = $('keypad');
    for (const [label, action, cls, aria, plain] of KEYS) {
      const b = el('button', `key${cls ? ' ' + cls : ''}`);
      b.type = 'button';
      b.setAttribute('aria-label', aria || label);
      if (plain || /^[0-9.]$/.test(label)) b.textContent = label;
      else renderTex(b, label);
      // Keep the focus (and cursor) in the input on desktop.
      b.addEventListener('mousedown', (e) => e.preventDefault());
      b.addEventListener('click', () => press(action));
      pad.appendChild(b);
    }
  }

  function press(action) {
    if (action === 'go') return calculate();
    if (action === 'clear') {
      exprInput.value = '';
    } else if (action === 'back') {
      const { selectionStart: s, selectionEnd: e, value } = exprInput;
      if (s !== e) replaceSelection('');
      else if (s > 0) {
        exprInput.value = value.slice(0, s - 1) + value.slice(e);
        exprInput.setSelectionRange(s - 1, s - 1);
      }
    } else if (action === 'ans') {
      if (lastResult) insert(`(${lastResult})`);
    } else {
      insert(action);
    }
    exprInput.focus();
    updatePreview();
  }

  // Inserts text at the cursor. A selection goes inside the template:
  // select "x^2" and press d/dx -> der(x^2, x).
  function insert(template) {
    const { selectionStart: s, selectionEnd: e, value } = exprInput;
    const selected = value.slice(s, e);
    const cut = template.indexOf('|');
    const text = cut < 0 ? template : template.slice(0, cut) + selected + template.slice(cut + 1);
    exprInput.value = value.slice(0, s) + text + value.slice(e);
    const caret = cut < 0 ? s + text.length : s + cut + selected.length;
    exprInput.setSelectionRange(caret, caret);
  }

  function replaceSelection(text) {
    const { selectionStart: s, selectionEnd: e, value } = exprInput;
    exprInput.value = value.slice(0, s) + text + value.slice(e);
    exprInput.setSelectionRange(s + text.length, s + text.length);
  }

  // ------------------------------------------------------------------
  // Live preview
  // ------------------------------------------------------------------
  function updatePreview() {
    const src = exprInput.value.trim();
    preview.replaceChildren();
    if (!src) {
      preview.appendChild(el('span', 'placeholder', 'Escribe una expresión o usa el teclado'));
      return;
    }
    try {
      renderTex(preview, toLatex(parse(src)), true);
    } catch (e) {
      preview.appendChild(el('span', 'perr', e instanceof ParseError ? e.message : 'Expresión no válida'));
    }
  }

  // ------------------------------------------------------------------
  // Calculation
  // ------------------------------------------------------------------
  async function calculate() {
    if (busy) return;
    const src = exprInput.value.trim();
    if (!src) return;

    let ast, request;
    try {
      ast = parse(src);
      request = { expr: toProlog(ast) };
      const at = eatInput.value.trim();
      if (at) {
        request.evalAt = toProlog(parse(at));
        request.evalVar = evarInput.value.trim() || 'x';
      }
    } catch (e) {
      return showError(e instanceof ParseError ? e.message : 'Expresión no válida');
    }

    busy = true;
    showLoading();
    let data;
    try {
      const res = await fetch('/api/calc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(request),
      });
      data = await res.json();
    } catch {
      data = { ok: false, error: 'No se pudo conectar con el servidor' };
    } finally {
      busy = false;
    }

    if (!data.ok) return showError(data.error, request);
    lastResult = data.result;
    const inputTex = toLatex(ast);
    const resultTex = prologToTex(data.result) + (data.constant ? ' + C' : '');
    showResult(data, request, inputTex, resultTex);
    addHistory({ expr: src, tex: `${inputTex} = ${resultTex}` });
  }

  function showLoading() {
    resultBox.className = 'card result loading';
    resultBox.replaceChildren(el('p', '', 'Consultando la base de conocimiento…'));
  }

  function showError(message, request) {
    resultBox.className = 'card result error';
    resultBox.replaceChildren(el('p', 'msg', message || 'Error desconocido'));
    if (/^No hay regla para derivar/.test(message || '')) {
      // The derivative KB (prolog/derivadas.pl) only has rules for elementary
      // functions of the variable itself: no product or chain rule.
      resultBox.appendChild(el('p', 'note',
        'La base de conocimiento deriva sumas, restas, constantes por funciones y ' +
        'x^n, K/x^n, sen, cos, tan, ln, e^x y √ aplicadas directamente a la variable ' +
        '(sin regla del producto ni de la cadena: sen(2x) o x·sen(x) no se pueden derivar).'));
    } else if (/^No hay regla para integrar/.test(message || '')) {
      // Same limits in prolog/integrales.pl: linearity plus elementary forms.
      resultBox.appendChild(el('p', 'note',
        'La base de conocimiento integra sumas, restas, constantes por funciones y ' +
        'x^n, K/x^n, sen, cos, sec², ln, e^x y √ aplicadas directamente a la variable ' +
        '(sin integración por partes ni sustitución: sen(2x) o x·sen(x) no se pueden integrar).'));
    }
    if (request) resultBox.appendChild(prologDetails(request, null));
  }

  function showResult(data, request, inputTex, resultTex) {
    resultBox.className = 'card result';
    resultBox.replaceChildren();

    const eq = el('div', 'eq');
    renderTex(eq, `${inputTex} = ${resultTex}`, true);
    resultBox.appendChild(eq);

    if (data.decimal !== null && data.decimal !== undefined && String(data.decimal) !== data.result) {
      const v = el('div', 'value approx');
      v.appendChild(texSpan(`\\approx ${formatNumber(data.decimal)}`));
      resultBox.appendChild(v);
    }

    if (data.evaluation) {
      const ev = data.evaluation;
      const v = el('div', 'value');
      let tex = `${prologToTex(ev.var)} = ${prologToTex(ev.at)}:\\quad ${prologToTex(ev.result)}`;
      if (ev.decimal !== null && String(ev.decimal) !== ev.result) tex += ` \\approx ${formatNumber(ev.decimal)}`;
      v.appendChild(texSpan(tex));
      resultBox.appendChild(v);
    }

    const retried = data.steps.filter((s) => s.retry);
    for (const s of retried) {
      resultBox.appendChild(el('p', 'note',
        `Ninguna regla reconocía ${s.input} tal como se escribió; se consultó la forma ${s.retry}: ${s.query.replace(/^\w\(\w+, (.*), R\)$/, '$1')}.`));
    }
    if (data.constant) resultBox.appendChild(el('p', 'note', 'C es la constante de integración.'));

    resultBox.appendChild(prologDetails(request, data));
  }

  function formatNumber(n) {
    return Number.isInteger(n) ? String(n) : String(Number(n.toPrecision(12)));
  }

  // "Detalles de Prolog" panel: what was sent and what each rule answered.
  function prologDetails(request, data) {
    const details = el('details', 'prolog');
    details.appendChild(el('summary', '', 'Detalles de Prolog'));

    const kv = el('dl', 'kv');
    const row = (k, v) => {
      kv.appendChild(el('dt', '', k));
      const dd = el('dd');
      dd.appendChild(el('code', '', v));
      kv.appendChild(dd);
    };
    row('Término enviado', request.expr);
    if (request.evalAt) row('Evaluar en', `${request.evalVar} = ${request.evalAt}`);
    if (data) row('Resultado', data.result);
    details.appendChild(kv);

    if (data && data.steps.length) {
      const ol = el('ol', 'steps');
      for (const s of data.steps) ol.appendChild(stepItem(s));
      details.appendChild(ol);
    }
    return details;
  }

  function stepItem(s) {
    const li = el('li');
    if (s.op === 'simplificar') {
      li.append('simplificar/2: ', el('code', '', s.input), ' → ', el('code', '', s.result));
      return li;
    }
    li.append(el('code', '', s.query.replace(/R\)$/, `${s.raw})`)));
    if (s.retry) li.append(el('div', 'via', `reintento con la entrada ${s.retry} (original: ${s.input})`));
    if (s.raw !== (s.antiderivative || s.result)) {
      li.append(el('div', 'via', `simplificado: ${s.antiderivative || s.result}`));
    }
    if (s.from !== undefined) {
      li.append(el('div', 'via', `F(${s.to}) − F(${s.from}) = ${s.result}`));
    }
    return li;
  }

  // ------------------------------------------------------------------
  // History (kept in this browser only)
  // ------------------------------------------------------------------
  function loadHistory() {
    try {
      const items = JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]');
      return Array.isArray(items) ? items : [];
    } catch {
      return [];
    }
  }

  function saveHistory(items) {
    try {
      localStorage.setItem(HISTORY_KEY, JSON.stringify(items));
    } catch { /* private mode, storage full: history just isn't kept */ }
  }

  let history = loadHistory();

  function addHistory(item) {
    history = [item, ...history.filter((h) => h.expr !== item.expr)].slice(0, HISTORY_MAX);
    saveHistory(history);
    renderHistory();
  }

  function renderHistory() {
    historyList.replaceChildren();
    if (!history.length) {
      historyList.appendChild(el('li', 'empty', 'Aún no hay cálculos.'));
      return;
    }
    for (const h of history) {
      const li = el('li');
      li.tabIndex = 0;
      li.setAttribute('role', 'button');
      li.setAttribute('aria-label', `Usar de nuevo: ${h.expr}`);
      li.title = h.expr;
      renderTex(li, h.tex);
      const use = () => {
        exprInput.value = h.expr;
        updatePreview();
        exprInput.focus();
      };
      li.addEventListener('click', use);
      li.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); use(); }
      });
      historyList.appendChild(li);
    }
  }

  // ------------------------------------------------------------------
  // Server status
  // ------------------------------------------------------------------
  async function checkStatus() {
    try {
      const res = await fetch('/api/health');
      const data = await res.json();
      statusBadge.textContent = data.prolog ? 'Prolog listo' : 'Prolog no disponible';
      statusBadge.className = `status ${data.prolog ? 'ok' : 'err'}`;
    } catch {
      statusBadge.textContent = 'sin conexión';
      statusBadge.className = 'status err';
    }
  }

  // ------------------------------------------------------------------
  // Start
  // ------------------------------------------------------------------
  buildKeypad();
  resultBox.setAttribute('aria-live', 'polite');
  exprInput.setAttribute('aria-label', 'Expresión');
  exprInput.addEventListener('input', updatePreview);
  for (const input of [exprInput, evarInput, eatInput]) {
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); calculate(); }
    });
  }
  updatePreview();
  renderHistory();
  checkStatus();
})();
