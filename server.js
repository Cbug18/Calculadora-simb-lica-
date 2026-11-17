// server.js — serves public/ and forwards calculations to one long-running
// SWI-Prolog process (prolog/main.pl), which reads one JSON request per
// line on stdin and writes one JSON response per line on stdout.
//
//   npm start            http://localhost:3000
//   PORT=8080 npm start
//
// API
//   POST /api/calc   {expr, evalVar?, evalAt?}  ->  {ok, result, steps, constant, decimal, evaluation}
//                                                    or {ok: false, error}
//   GET  /api/health {ok, prolog}

const path = require('node:path');
const readline = require('node:readline');
const { spawn } = require('node:child_process');
const express = require('express');

const PORT = Number(process.env.PORT) || 3000;
const SWIPL = process.env.SWIPL || 'swipl';
const MAIN_PL = process.env.PROLOG_MAIN || path.join(__dirname, 'prolog', 'main.pl');

const LIMITS = {
  bodyBytes: '10kb',
  exprChars: 1000,
  fieldChars: 100,
  timeoutMs: 10000,       // main.pl stops by itself after 5 s; this is the safety net
  maxQueue: 50,           // requests waiting for Prolog
  perMinute: 120,         // requests per IP
};

// ------------------------------------------------------------------
// Prolog process
// ------------------------------------------------------------------
class PrologEngine {
  constructor() {
    this.child = null;
    this.pending = [];     // FIFO: Prolog answers in order
    this.restarts = 0;
  }

  start() {
    const child = spawn(SWIPL, [MAIN_PL], { stdio: ['pipe', 'pipe', 'pipe'] });
    this.child = child;

    readline.createInterface({ input: child.stdout }).on('line', (line) => {
      const job = this.pending.shift();
      if (!job) return;
      clearTimeout(job.timer);
      try {
        job.resolve(JSON.parse(line));
      } catch {
        job.reject(new Error('Respuesta de Prolog no válida'));
      }
    });

    child.stderr.on('data', (d) => {
      const msg = d.toString().trim();
      if (msg) console.error(`[swipl] ${msg}`);
    });

    child.on('error', (err) => {
      console.error(`No se pudo iniciar ${SWIPL}: ${err.message}`);
    });

    child.on('exit', (code, signal) => {
      if (this.child !== child) return;          // already replaced
      this.child = null;
      this.failAll(new Error('El proceso de Prolog terminó'));
      if (!this.stopping) {
        this.restarts++;
        const delay = Math.min(5000, 200 * this.restarts);
        console.error(`swipl salió (${signal || code}); reiniciando en ${delay} ms`);
        setTimeout(() => this.start(), delay);
      }
    });
  }

  get alive() {
    return Boolean(this.child && this.child.exitCode === null && this.child.pid);
  }

  query(request) {
    if (!this.alive) return Promise.reject(new Error('Prolog no está disponible'));
    if (this.pending.length >= LIMITS.maxQueue) {
      return Promise.reject(Object.assign(new Error('Servidor ocupado, intenta de nuevo'), { status: 503 }));
    }
    return new Promise((resolve, reject) => {
      const job = { resolve, reject };
      job.timer = setTimeout(() => {
        // The answers are matched by order, so a stuck request poisons the
        // queue: kill the process and let it restart.
        this.failAll(new Error('El cálculo tardó demasiado'));
        if (this.child) this.child.kill('SIGKILL');
      }, LIMITS.timeoutMs);
      this.pending.push(job);
      this.child.stdin.write(JSON.stringify(request) + '\n');
    });
  }

  failAll(err) {
    const jobs = this.pending;
    this.pending = [];
    for (const job of jobs) {
      clearTimeout(job.timer);
      job.reject(err);
    }
  }

  stop() {
    this.stopping = true;
    if (this.child) this.child.kill();
  }
}

// ------------------------------------------------------------------
// HTTP
// ------------------------------------------------------------------
function rateLimit(perMinute) {
  const hits = new Map();
  setInterval(() => hits.clear(), 60000).unref();
  return (req, res, next) => {
    const n = (hits.get(req.ip) || 0) + 1;
    hits.set(req.ip, n);
    if (n > perMinute) {
      return res.status(429).json({ ok: false, error: 'Demasiadas peticiones, espera un momento' });
    }
    next();
  };
}

function validate(body) {
  if (!body || typeof body !== 'object') return 'Petición no válida';
  const { expr, evalVar, evalAt } = body;
  if (typeof expr !== 'string' || !expr.trim()) return 'Falta la expresión';
  if (expr.length > LIMITS.exprChars) return `La expresión es demasiado larga (máximo ${LIMITS.exprChars} caracteres)`;
  for (const [name, v] of [['evalVar', evalVar], ['evalAt', evalAt]]) {
    if (v === undefined || v === null) continue;
    if (typeof v !== 'string') return `${name} debe ser texto`;
    if (v.length > LIMITS.fieldChars) return `${name} es demasiado largo`;
  }
  return null;
}

function createApp(engine) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: LIMITS.bodyBytes }));
  app.use(express.static(path.join(__dirname, 'public')));

  app.get('/api/health', (req, res) => {
    res.json({ ok: true, prolog: engine.alive });
  });

  app.post('/api/calc', rateLimit(LIMITS.perMinute), async (req, res) => {
    const error = validate(req.body);
    if (error) return res.status(400).json({ ok: false, error });
    const { expr, evalVar, evalAt } = req.body;
    const request = { expr };
    if (evalAt && evalAt.trim()) {
      request.evalAt = evalAt;
      request.evalVar = evalVar && evalVar.trim() ? evalVar : 'x';
    }
    try {
      res.json(await engine.query(request));
    } catch (err) {
      res.status(err.status || 500).json({ ok: false, error: err.message });
    }
  });

  // Bad JSON body, body too large, etc.
  app.use((err, req, res, next) => {
    if (res.headersSent) return next(err);
    const status = err.status || 500;
    const error = err.type === 'entity.too.large' ? 'La petición es demasiado grande'
      : err.type === 'entity.parse.failed' ? 'La petición no es JSON válido'
      : 'Error interno del servidor';
    res.status(status).json({ ok: false, error });
  });

  return app;
}

if (require.main === module) {
  const engine = new PrologEngine();
  engine.start();
  const server = createApp(engine).listen(PORT, () => {
    console.log(`Calculadora Prolog en http://localhost:${PORT}`);
  });
  const shutdown = () => {
    engine.stop();
    server.close(() => process.exit(0));
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

module.exports = { createApp, PrologEngine, LIMITS };
