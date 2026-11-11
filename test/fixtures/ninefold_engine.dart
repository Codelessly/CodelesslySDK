// Ninefold v2's puzzle engine (references/ninefold_v2/tool/engine.js as the
// `engine` library script): a heavy, real script for the engine benchmark.
// Generated; do not edit.
// ignore_for_file: prefer_single_quotes
const ninefoldEngine = r'''// Ninefold engine (JavaScript). The canonical puzzle logic: a seeded RNG, the
// uniqueness solver, the generator, the human-style solver that grades
// puzzles and explains hints, validation and the undo stack.
//
// lib/engine/*.dart is a line-for-line port: the same seed gives the same
// puzzle, grade and hint text in both (tool/engine_test.mjs checks the JS;
// test/engine_parity_test.dart compares Dart against tool/parity.json).
// The editor recreation stores this file's functions as project scripts.
//
// Cells are 0..80 (row * 9 + col). Rows are named A..I, columns 1..9.
// Houses are 0..8 rows, 9..17 columns, 18..26 boxes (boxes 1..9 in text).
// Candidates are 9-bit masks: bit d-1 is digit d.


// ---------------------------------------------------------------- RNG

/** mulberry32: a small seeded PRNG that both Dart and JS can match bit for bit. */
function makeRng(seed) {
  let a = seed >>> 0;
  const next = function next() {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a) >>> 0;
    t = ((t + Math.imul(t ^ (t >>> 7), 61 | t)) >>> 0) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  // The generator's state: makeRng(next.state()) continues the sequence.
  next.state = () => a;
  return next;
}

function randInt(rng, n) {
  return Math.floor(rng() * n);
}

function shuffle(rng, list) {
  for (let i = list.length - 1; i > 0; i--) {
    const j = randInt(rng, i + 1);
    const t = list[i];
    list[i] = list[j];
    list[j] = t;
  }
  return list;
}

/** A daily seed from an ISO date (yyyy-mm-dd): the same puzzle for everyone. */
function dailySeed(isoDate) {
  let h = 2166136261;
  const s = 'ninefold:' + isoDate;
  for (let i = 0; i < s.length; i++) {
    h = Math.imul(h ^ s.charCodeAt(i), 16777619) >>> 0;
  }
  return h >>> 0;
}

// ---------------------------------------------------------------- Geometry

const ROWS = 'ABCDEFGHI';
const LEVELS = ['easy', 'medium', 'hard', 'expert'];
const LEVEL_NAMES = ['Easy', 'Medium', 'Hard', 'Expert'];

const rowOf = (i) => Math.floor(i / 9);
const colOf = (i) => i % 9;
const boxOf = (i) => Math.floor(rowOf(i) / 3) * 3 + Math.floor(colOf(i) / 3);
const cellName = (i) => ROWS[rowOf(i)] + (colOf(i) + 1);

/** The 27 houses, each a list of 9 cells. */
const HOUSES = (() => {
  const h = [];
  for (let r = 0; r < 9; r++) h.push([0, 1, 2, 3, 4, 5, 6, 7, 8].map((c) => r * 9 + c));
  for (let c = 0; c < 9; c++) h.push([0, 1, 2, 3, 4, 5, 6, 7, 8].map((r) => r * 9 + c));
  for (let b = 0; b < 9; b++) {
    const r0 = Math.floor(b / 3) * 3;
    const c0 = (b % 3) * 3;
    const cells = [];
    for (let k = 0; k < 9; k++) cells.push((r0 + Math.floor(k / 3)) * 9 + c0 + (k % 3));
    h.push(cells);
  }
  return h;
})();

function houseName(h) {
  if (h < 9) return 'row ' + ROWS[h];
  if (h < 18) return 'column ' + (h - 8);
  return 'box ' + (h - 17);
}

/** The 20 peers of each cell. */
const PEERS = (() => {
  const p = [];
  for (let i = 0; i < 81; i++) {
    const s = [];
    for (let j = 0; j < 81; j++) {
      if (j !== i && (rowOf(j) === rowOf(i) || colOf(j) === colOf(i) || boxOf(j) === boxOf(i))) s.push(j);
    }
    p.push(s);
  }
  return p;
})();

const sees = (a, b) => a !== b && (rowOf(a) === rowOf(b) || colOf(a) === colOf(b) || boxOf(a) === boxOf(b));

function popcount(m) {
  let n = 0;
  while (m) {
    m &= m - 1;
    n++;
  }
  return n;
}

function digitsOf(m) {
  const out = [];
  for (let d = 1; d <= 9; d++) if (m & (1 << (d - 1))) out.push(d);
  return out;
}

const ALL = 0x1ff;

function joinNames(list) {
  if (list.length <= 1) return list.join('');
  if (list.length === 2) return list[0] + ' and ' + list[1];
  return list.slice(0, -1).join(', ') + ' and ' + list[list.length - 1];
}

const cellsText = (cells) => joinNames(cells.map(cellName));
const digitsText = (ds) => joinNames(ds.map(String));

// ---------------------------------------------------------------- Parsing

/** 81 chars, digits with 0 or . for empty. */
function parseGrid(text) {
  const g = [];
  for (const ch of text) {
    if (ch >= '1' && ch <= '9') g.push(ch.charCodeAt(0) - 48);
    else if (ch === '0' || ch === '.') g.push(0);
  }
  if (g.length !== 81) throw new Error('A grid needs 81 squares, got ' + g.length);
  return g;
}

const gridText = (g) => g.map((v) => (v ? String(v) : '.')).join('');

// ---------------------------------------------------------------- Exact solver

/** Counts solutions up to `limit` (bitmask DFS, fewest candidates first). */
function countSolutions(grid, limit) {
  const g = grid.slice();
  const rows = new Array(9).fill(0);
  const cols = new Array(9).fill(0);
  const boxes = new Array(9).fill(0);
  for (let i = 0; i < 81; i++) {
    const v = g[i];
    if (!v) continue;
    const bit = 1 << (v - 1);
    const r = rowOf(i), c = colOf(i), b = boxOf(i);
    if ((rows[r] | cols[c] | boxes[b]) & bit) return { count: 0, solution: null };
    rows[r] |= bit;
    cols[c] |= bit;
    boxes[b] |= bit;
  }
  let count = 0;
  let solution = null;
  function dfs() {
    let best = -1;
    let bestMask = 0;
    let bestCount = 10;
    for (let i = 0; i < 81; i++) {
      if (g[i]) continue;
      const m = ALL & ~(rows[rowOf(i)] | cols[colOf(i)] | boxes[boxOf(i)]);
      const n = popcount(m);
      if (n < bestCount) {
        best = i;
        bestMask = m;
        bestCount = n;
        if (n <= 1) break;
      }
    }
    if (best < 0) {
      count++;
      if (!solution) solution = g.slice();
      return count >= limit;
    }
    if (bestCount === 0) return false;
    const r = rowOf(best), c = colOf(best), b = boxOf(best);
    for (let d = 1; d <= 9; d++) {
      const bit = 1 << (d - 1);
      if (!(bestMask & bit)) continue;
      g[best] = d;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
      if (dfs()) return true;
      rows[r] &= ~bit;
      cols[c] &= ~bit;
      boxes[b] &= ~bit;
      g[best] = 0;
    }
    return false;
  }
  dfs();
  return { count, solution };
}

/** A complete random grid, filled cell by cell with shuffled digits. */
function fullGrid(rng) {
  const g = new Array(81).fill(0);
  const rows = new Array(9).fill(0);
  const cols = new Array(9).fill(0);
  const boxes = new Array(9).fill(0);
  function fill(i) {
    if (i === 81) return true;
    const r = rowOf(i), c = colOf(i), b = boxOf(i);
    const order = shuffle(rng, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    for (const d of order) {
      const bit = 1 << (d - 1);
      if ((rows[r] | cols[c] | boxes[b]) & bit) continue;
      g[i] = d;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
      if (fill(i + 1)) return true;
      rows[r] &= ~bit;
      cols[c] &= ~bit;
      boxes[b] &= ~bit;
      g[i] = 0;
    }
    return false;
  }
  fill(0);
  return g;
}

// ---------------------------------------------------------------- Candidates

/** Candidate masks for every empty cell, from the placed digits only. */
function candidatesOf(values) {
  const c = new Array(81).fill(0);
  for (let i = 0; i < 81; i++) {
    if (values[i]) continue;
    let m = ALL;
    for (const p of PEERS[i]) if (values[p]) m &= ~(1 << (values[p] - 1));
    c[i] = m;
  }
  return c;
}

// ---------------------------------------------------------------- Human solver

// A step: {technique, level, house?, placements: [{cell, digit}],
// eliminations: [{cell, digit}], cells (the pattern), digits, houses, text,
// nudge}. `text` names cells like "E4"; the UI turns those into chips.

const TECHNIQUES = {
  fullHouse: { name: 'Full house', level: 1 },
  nakedSingle: { name: 'Naked single', level: 1 },
  hiddenSingle: { name: 'Hidden single', level: 1 },
  pointing: { name: 'Pointing', level: 3 },
  claiming: { name: 'Box–line', level: 3 },
  nakedPair: { name: 'Naked pair', level: 3 },
  hiddenPair: { name: 'Hidden pair', level: 3 },
  nakedTriple: { name: 'Naked triple', level: 3 },
  hiddenTriple: { name: 'Hidden triple', level: 3 },
  xWing: { name: 'X-Wing', level: 4 },
  xyWing: { name: 'XY-Wing', level: 4 },
  swordfish: { name: 'Swordfish', level: 4 },
};

function step(technique, fields) {
  return Object.assign(
    {
      technique,
      name: TECHNIQUES[technique].name,
      level: TECHNIQUES[technique].level,
      placements: [],
      eliminations: [],
      cells: [],
      digits: [],
      houses: [],
    },
    fields,
  );
}

function findFullHouse(v) {
  for (let h = 0; h < 27; h++) {
    const empty = HOUSES[h].filter((i) => !v[i]);
    if (empty.length !== 1) continue;
    let m = ALL;
    for (const i of HOUSES[h]) if (v[i]) m &= ~(1 << (v[i] - 1));
    const d = digitsOf(m)[0];
    const cell = empty[0];
    return step('fullHouse', {
      placements: [{ cell, digit: d }],
      cells: [cell],
      digits: [d],
      houses: [h],
      nudge: `Look at ${houseName(h)}: it is nearly full.`,
      text: `${cap(houseName(h))} has one empty square left. Only ${d} is missing, so ${cellName(cell)} is ${d}.`,
    });
  }
  return null;
}

function findNakedSingle(v, c) {
  for (let i = 0; i < 81; i++) {
    if (v[i] || popcount(c[i]) !== 1) continue;
    const d = digitsOf(c[i])[0];
    return step('nakedSingle', {
      placements: [{ cell: i, digit: d }],
      cells: [i],
      digits: [d],
      houses: [rowOf(i), 9 + colOf(i), 18 + boxOf(i)],
      nudge: `Look at ${cellName(i)} and everything it can see.`,
      text: `${cellName(i)} sees every digit but ${d} in its row, column and box, so it must be ${d}.`,
    });
  }
  return null;
}

function findHiddenSingle(v, c) {
  // Boxes first: that is where people look for them.
  const order = [];
  for (let h = 18; h < 27; h++) order.push(h);
  for (let h = 0; h < 18; h++) order.push(h);
  for (const h of order) {
    for (let d = 1; d <= 9; d++) {
      const bit = 1 << (d - 1);
      const spots = HOUSES[h].filter((i) => !v[i] && c[i] & bit);
      if (spots.length !== 1) continue;
      if (HOUSES[h].some((i) => v[i] === d)) continue;
      const cell = spots[0];
      return step('hiddenSingle', {
        placements: [{ cell, digit: d }],
        cells: [cell],
        digits: [d],
        houses: [h],
        nudge: `Look for where ${d} can go in ${houseName(h)}.`,
        text: `In ${houseName(h)}, ${d} fits in only one square: ${cellName(cell)}. Every other square is blocked by a ${d} it can see.`,
      });
    }
  }
  return null;
}

function eliminationsFrom(v, c, targets, digits, exclude) {
  const out = [];
  for (const i of targets) {
    if (v[i] || exclude.includes(i)) continue;
    for (const d of digits) if (c[i] & (1 << (d - 1))) out.push({ cell: i, digit: d });
  }
  return out;
}

const uniqueCells = (elims) => [...new Set(elims.map((e) => e.cell))];

function findPointing(v, c) {
  for (let b = 0; b < 9; b++) {
    const box = HOUSES[18 + b];
    for (let d = 1; d <= 9; d++) {
      const bit = 1 << (d - 1);
      const spots = box.filter((i) => !v[i] && c[i] & bit);
      if (spots.length < 2 || spots.length > 3) continue;
      for (const line of ['row', 'col']) {
        const key = line === 'row' ? rowOf : colOf;
        if (!spots.every((i) => key(i) === key(spots[0]))) continue;
        const h = line === 'row' ? key(spots[0]) : 9 + key(spots[0]);
        const elims = eliminationsFrom(v, c, HOUSES[h], [d], box);
        if (!elims.length) continue;
        return step('pointing', {
          eliminations: elims,
          cells: spots,
          digits: [d],
          houses: [18 + b, h],
          nudge: `Look at where ${d} can go in box ${b + 1}.`,
          text: `In box ${b + 1}, every ${d} sits in ${houseName(h)} (${cellsText(spots)}). Box ${b + 1} needs its ${d} there, so ${d} comes off ${cellsText(uniqueCells(elims))}.`,
        });
      }
    }
  }
  return null;
}

function findClaiming(v, c) {
  for (let h = 0; h < 18; h++) {
    for (let d = 1; d <= 9; d++) {
      const bit = 1 << (d - 1);
      const spots = HOUSES[h].filter((i) => !v[i] && c[i] & bit);
      if (spots.length < 2 || spots.length > 3) continue;
      const b = boxOf(spots[0]);
      if (!spots.every((i) => boxOf(i) === b)) continue;
      const elims = eliminationsFrom(v, c, HOUSES[18 + b], [d], HOUSES[h]);
      if (!elims.length) continue;
      return step('claiming', {
        eliminations: elims,
        cells: spots,
        digits: [d],
        houses: [h, 18 + b],
        nudge: `Look at where ${d} can go in ${houseName(h)}.`,
        text: `In ${houseName(h)}, every ${d} sits inside box ${b + 1} (${cellsText(spots)}). That is ${houseName(h)}'s ${d}, so no other square of box ${b + 1} can be ${d}: it comes off ${cellsText(uniqueCells(elims))}.`,
      });
    }
  }
  return null;
}

/** k cells of a house whose candidates together are exactly k digits. */
function findNakedSubset(v, c, k, technique) {
  for (let h = 0; h < 27; h++) {
    const empty = HOUSES[h].filter((i) => !v[i] && popcount(c[i]) >= 2 && popcount(c[i]) <= k);
    const combos = combinations(empty, k);
    for (const set of combos) {
      let m = 0;
      for (const i of set) m |= c[i];
      if (popcount(m) !== k) continue;
      const ds = digitsOf(m);
      const elims = eliminationsFrom(v, c, HOUSES[h], ds, set);
      if (!elims.length) continue;
      const names = cellsText(set);
      const what = k === 2 ? 'two' : 'three';
      const all = k === 2 ? 'both' : 'all three';
      return step(technique, {
        eliminations: elims,
        cells: set,
        digits: ds,
        houses: [h],
        nudge: `Look at the candidates in ${houseName(h)}.`,
        text: `${names} can only hold ${digitsText(ds)}. Those ${what} squares take ${all} digits for ${houseName(h)}, so ${digitsText(ds)} come off ${cellsText(uniqueCells(elims))}.`,
      });
    }
  }
  return null;
}

/** k digits of a house that fit in exactly the same k cells. */
function findHiddenSubset(v, c, k, technique) {
  for (let h = 0; h < 27; h++) {
    const cells = HOUSES[h];
    const placed = new Set(cells.filter((i) => v[i]).map((i) => v[i]));
    const open = [];
    for (let d = 1; d <= 9; d++) {
      if (placed.has(d)) continue;
      const n = cells.filter((i) => !v[i] && c[i] & (1 << (d - 1))).length;
      if (n >= 2 && n <= k) open.push(d);
    }
    for (const ds of combinations(open, k)) {
      let mask = 0;
      for (const d of ds) mask |= 1 << (d - 1);
      const spots = cells.filter((i) => !v[i] && c[i] & mask);
      if (spots.length !== k) continue;
      const elims = [];
      for (const i of spots) {
        for (const d of digitsOf(c[i] & ~mask)) elims.push({ cell: i, digit: d });
      }
      if (!elims.length) continue;
      const others = digitsOf(spots.reduce((m, i) => m | (c[i] & ~mask), 0));
      return step(technique, {
        eliminations: elims,
        cells: spots,
        digits: ds,
        houses: [h],
        nudge: `Look at where ${digitsText(ds)} can go in ${houseName(h)}.`,
        text: `In ${houseName(h)}, ${digitsText(ds)} fit only in ${cellsText(spots)}. Those squares must hold ${digitsText(ds)}, so their other candidates (${digitsText(others)}) can go.`,
      });
    }
  }
  return null;
}

/** X-Wing (size 2) and Swordfish (size 3), rows then columns as the base. */
function findFish(v, c, size, technique) {
  for (const base of ['row', 'col']) {
    for (let d = 1; d <= 9; d++) {
      const bit = 1 << (d - 1);
      const lines = [];
      for (let k = 0; k < 9; k++) {
        const h = base === 'row' ? k : 9 + k;
        if (HOUSES[h].some((i) => v[i] === d)) continue;
        const spots = HOUSES[h].filter((i) => !v[i] && c[i] & bit);
        if (spots.length >= 2 && spots.length <= size) lines.push({ k, spots });
      }
      for (const set of combinations(lines, size)) {
        const cover = new Set();
        for (const l of set) for (const i of l.spots) cover.add(base === 'row' ? colOf(i) : rowOf(i));
        if (cover.size !== size) continue;
        const coverHouses = [...cover].sort((a, b) => a - b).map((x) => (base === 'row' ? 9 + x : x));
        const baseHouses = set.map((l) => (base === 'row' ? l.k : 9 + l.k));
        const pattern = [];
        for (const l of set) for (const i of l.spots) pattern.push(i);
        const elims = [];
        for (const h of coverHouses) {
          for (const i of HOUSES[h]) {
            if (v[i] || pattern.includes(i)) continue;
            if (c[i] & bit) elims.push({ cell: i, digit: d });
          }
        }
        if (!elims.length) continue;
        const baseText = joinNames(baseHouses.map((h) => (h < 9 ? ROWS[h] : String(h - 8))));
        const coverText = joinNames(coverHouses.map((h) => (h < 9 ? ROWS[h] : String(h - 8))));
        const baseWord = base === 'row' ? 'rows' : 'columns';
        const coverWord = base === 'row' ? 'columns' : 'rows';
        return step(technique, {
          eliminations: elims,
          cells: pattern.sort((a, b) => a - b),
          digits: [d],
          houses: baseHouses.concat(coverHouses),
          nudge: `Look at where ${d} can go in each ${base === 'row' ? 'row' : 'column'}.`,
          text: `In ${baseWord} ${baseText}, ${d} fits only in ${coverWord} ${coverText}. Whichever way the ${d}s fall, they fill ${coverWord} ${coverText}, so ${d} comes off ${cellsText(uniqueCells(elims))}.`,
        });
      }
    }
  }
  return null;
}

function findXyWing(v, c) {
  const bivalue = [];
  for (let i = 0; i < 81; i++) if (!v[i] && popcount(c[i]) === 2) bivalue.push(i);
  for (const pivot of bivalue) {
    const [x, y] = digitsOf(c[pivot]);
    const wings = bivalue.filter((w) => w !== pivot && sees(w, pivot));
    for (const a of wings) {
      if (!(c[a] & (1 << (x - 1))) || c[a] & (1 << (y - 1))) continue;
      const z = digitsOf(c[a] & ~(1 << (x - 1)))[0];
      for (const b of wings) {
        if (b === a) continue;
        if (c[b] !== ((1 << (y - 1)) | (1 << (z - 1)))) continue;
        const zbit = 1 << (z - 1);
        const elims = [];
        for (let i = 0; i < 81; i++) {
          if (v[i] || i === pivot || i === a || i === b) continue;
          if (c[i] & zbit && sees(i, a) && sees(i, b)) elims.push({ cell: i, digit: z });
        }
        if (!elims.length) continue;
        return step('xyWing', {
          eliminations: elims,
          cells: [pivot, a, b],
          digits: [x, y, z],
          houses: [],
          nudge: `Look at the squares with two candidates around ${cellName(pivot)}.`,
          text: `${cellName(pivot)} is ${x} or ${y}. If it is ${x}, ${cellName(a)} is ${z}; if it is ${y}, ${cellName(b)} is ${z}. Either way one of them is ${z}, so ${z} comes off ${cellsText(uniqueCells(elims))}, which ${uniqueCells(elims).length === 1 ? 'sees' : 'see'} both.`,
        });
      }
    }
  }
  return null;
}

function combinations(list, k) {
  const out = [];
  const pick = [];
  function rec(start) {
    if (pick.length === k) {
      out.push(pick.slice());
      return;
    }
    for (let i = start; i < list.length; i++) {
      pick.push(list[i]);
      rec(i + 1);
      pick.pop();
    }
  }
  rec(0);
  return out;
}

function cap(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** The easiest next step from values `v` and candidates `c`, or null. */
function findStep(v, c) {
  return (
    findFullHouse(v) ||
    findNakedSingle(v, c) ||
    findHiddenSingle(v, c) ||
    findPointing(v, c) ||
    findClaiming(v, c) ||
    findNakedSubset(v, c, 2, 'nakedPair') ||
    findHiddenSubset(v, c, 2, 'hiddenPair') ||
    findNakedSubset(v, c, 3, 'nakedTriple') ||
    findHiddenSubset(v, c, 3, 'hiddenTriple') ||
    findFish(v, c, 2, 'xWing') ||
    findXyWing(v, c) ||
    findFish(v, c, 3, 'swordfish')
  );
}

function applyStep(v, c, s) {
  for (const p of s.placements) {
    v[p.cell] = p.digit;
    c[p.cell] = 0;
    const bit = 1 << (p.digit - 1);
    for (const q of PEERS[p.cell]) c[q] &= ~bit;
  }
  for (const e of s.eliminations) c[e.cell] &= ~(1 << (e.digit - 1));
}

/**
 * Solves like a person. Returns {solved, level (1..4, the hardest technique
 * needed), steps, techniques: {name: count}}.
 */
function solveHuman(grid) {
  const v = grid.slice();
  const c = candidatesOf(v);
  let level = 1;
  let steps = 0;
  const techniques = {};
  for (;;) {
    if (v.every((x) => x)) break;
    const s = findStep(v, c);
    if (!s) break;
    applyStep(v, c, s);
    steps++;
    level = Math.max(level, s.level);
    techniques[s.technique] = (techniques[s.technique] || 0) + 1;
  }
  return { solved: v.every((x) => x), level, steps, techniques, values: v };
}

// ---------------------------------------------------------------- Generator

/** Givens to stop digging at, per level (1..4): easy keeps extra clues. */
const MIN_GIVENS = [0, 36, 22, 22, 22];

/**
 * A puzzle's level (1 easy .. 4 expert) from its human solve, or 0 when the
 * solver can't finish it. Techniques carry levels 1 (singles), 3 (pointing,
 * box-line, pairs and triples) and 4 (X-Wing, XY-Wing, Swordfish); a
 * singles-only puzzle is easy with 34 or more givens and medium below that.
 */
function gradeOf(solve, givens) {
  if (!solve.solved) return 0;
  if (solve.level >= 3) return solve.level;
  return givens >= 34 ? 1 : 2;
}

/** Removes symmetric pairs while the solution stays unique. */
function dig(solution, rng, level) {
  const p = solution.slice();
  const order = shuffle(rng, Array.from({ length: 41 }, (_, i) => i));
  let givens = 81;
  for (const i of order) {
    if (givens <= MIN_GIVENS[level]) break;
    const j = 80 - i;
    const a = p[i];
    const b = p[j];
    p[i] = 0;
    p[j] = 0;
    if (countSolutions(p, 2).count !== 1) {
      p[i] = a;
      p[j] = b;
    } else {
      givens -= i === j ? 1 : 2;
    }
  }
  return p;
}

/**
 * Generates a puzzle of `level` (1 easy .. 4 expert) from `seed`. Tries up to
 * `maxAttempts` grids; each is dug to a unique-solution puzzle and graded.
 * Returns {ok, puzzle, solution, level, attempts, givens, techniques} or
 * {ok: false, attempts, closest} when no grid hit the level.
 */
function generate(seed, level, maxAttempts) {
  const rng = makeRng(seed);
  let closest = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const solution = fullGrid(rng);
    const puzzle = dig(solution, rng, level);
    const g = solveHuman(puzzle);
    const givens = puzzle.filter((x) => x).length;
    const grade = gradeOf(g, givens);
    const result = { puzzle, solution, level: grade, attempts: attempt, givens, techniques: g.techniques };
    if (grade === level) return Object.assign({ ok: true }, result);
    if (grade && grade < level && (!closest || grade > closest.level)) closest = result;
  }
  return { ok: false, attempts: maxAttempts, closest };
}

/**
 * Generation in steps, for callers with a CPU limit per call (scripts): the
 * state is plain JSON, so it can be stored between calls. genStep runs up to
 * `budget` attempts and returns the new state; when `done`, `result` is
 * what generate(seed, level, max) returns. Run to the end, it gives exactly
 * generate's result.
 */
function genStart(seed, level, maxAttempts) {
  return { rng: seed >>> 0, level, max: maxAttempts, attempt: 0, closest: null, done: false, result: null };
}

function genStep(state, budget) {
  const st = Object.assign({}, state);
  const rng = makeRng(st.rng);
  for (let k = 0; k < budget && !st.done; k++) {
    st.attempt++;
    const solution = fullGrid(rng);
    const puzzle = dig(solution, rng, st.level);
    const g = solveHuman(puzzle);
    const givens = puzzle.filter((x) => x).length;
    const grade = gradeOf(g, givens);
    const result = { puzzle, solution, level: grade, attempts: st.attempt, givens, techniques: g.techniques };
    if (grade === st.level) {
      st.done = true;
      st.result = Object.assign({ ok: true }, result);
    } else {
      if (grade && grade < st.level && (!st.closest || grade > st.closest.level)) st.closest = result;
      if (st.attempt >= st.max) {
        st.done = true;
        st.result = { ok: false, attempts: st.max, closest: st.closest };
      }
    }
  }
  st.rng = rng.state();
  return st;
}

// ---------------------------------------------------------------- Game state

// A game: {puzzle, solution, values, notes, level, seed, daily, elapsed,
// mistakes, hints, undo: [move], redo: [move]}. A move is a list of
// changes {cell, v0, n0, v1, n1} (value and notes before and after).

function newGame(gen, seed, daily) {
  return {
    puzzle: gen.puzzle.slice(),
    solution: gen.solution.slice(),
    values: gen.puzzle.slice(),
    notes: new Array(81).fill(0),
    level: gen.level,
    seed,
    daily: daily || null,
    elapsed: 0,
    mistakes: 0,
    hints: 0,
    undo: [],
    redo: [],
  };
}

const UNDO_LIMIT = 200;

function cloneGame(g) {
  return Object.assign({}, g, {
    values: g.values.slice(),
    notes: g.notes.slice(),
    undo: g.undo.slice(),
    redo: g.redo.slice(),
  });
}

function commit(g, changes) {
  const real = changes.filter((ch) => ch.v0 !== ch.v1 || ch.n0 !== ch.n1);
  if (!real.length) return false;
  for (const ch of real) {
    g.values[ch.cell] = ch.v1;
    g.notes[ch.cell] = ch.n1;
  }
  g.undo.push(real);
  if (g.undo.length > UNDO_LIMIT) g.undo.shift();
  g.redo = [];
  return true;
}

/**
 * Places `digit` in `cell` (or clears it with 0). With autoNotes, the digit
 * comes off the notes of every peer. Returns {game, wrong}: wrong is true
 * when the digit isn't the solution's (the caller counts it as a mistake
 * only when mistake checking is on).
 */
function place(game, cell, digit, autoNotes) {
  const g = cloneGame(game);
  if (g.puzzle[cell]) return { game: g, changed: false, wrong: false };
  const changes = [];
  const v0 = g.values[cell];
  const n0 = g.notes[cell];
  const v1 = v0 === digit ? 0 : digit;
  changes.push({ cell, v0, n0, v1, n1: v1 ? 0 : n0 });
  if (v1 && autoNotes) {
    const bit = 1 << (v1 - 1);
    for (const p of PEERS[cell]) {
      if (g.notes[p] & bit) changes.push({ cell: p, v0: g.values[p], n0: g.notes[p], v1: g.values[p], n1: g.notes[p] & ~bit });
    }
  }
  const changed = commit(g, changes);
  const wrong = !!v1 && v1 !== g.solution[cell];
  return { game: g, changed, wrong };
}

/** Toggles pencil mark `digit` in an empty cell. */
function toggleNote(game, cell, digit) {
  const g = cloneGame(game);
  if (g.puzzle[cell] || g.values[cell]) return { game: g, changed: false };
  const n0 = g.notes[cell];
  const changed = commit(g, [{ cell, v0: 0, n0, v1: 0, n1: n0 ^ (1 << (digit - 1)) }]);
  return { game: g, changed };
}

function erase(game, cell) {
  const g = cloneGame(game);
  if (g.puzzle[cell]) return { game: g, changed: false };
  const changed = commit(g, [{ cell, v0: g.values[cell], n0: g.notes[cell], v1: 0, n1: 0 }]);
  return { game: g, changed };
}

/** Pencils every candidate into every empty square (one undoable move). */
function fillNotes(game) {
  const g = cloneGame(game);
  const c = candidatesOf(g.values);
  const changes = [];
  for (let i = 0; i < 81; i++) {
    if (g.values[i]) continue;
    changes.push({ cell: i, v0: 0, n0: g.notes[i], v1: 0, n1: c[i] });
  }
  const changed = commit(g, changes);
  return { game: g, changed };
}

function undo(game) {
  const g = cloneGame(game);
  const move = g.undo.pop();
  if (!move) return { game: g, changed: false, cells: [] };
  for (let k = move.length - 1; k >= 0; k--) {
    const ch = move[k];
    g.values[ch.cell] = ch.v0;
    g.notes[ch.cell] = ch.n0;
  }
  g.redo.push(move);
  return { game: g, changed: true, cells: move.map((ch) => ch.cell) };
}

function redo(game) {
  const g = cloneGame(game);
  const move = g.redo.pop();
  if (!move) return { game: g, changed: false, cells: [] };
  for (const ch of move) {
    g.values[ch.cell] = ch.v1;
    g.notes[ch.cell] = ch.n1;
  }
  g.undo.push(move);
  return { game: g, changed: true, cells: move.map((ch) => ch.cell) };
}

// ---------------------------------------------------------------- Validation

/** Cells whose digit repeats in a row, column or box. */
function conflicts(values) {
  const out = new Set();
  for (const house of HOUSES) {
    for (let d = 1; d <= 9; d++) {
      const at = house.filter((i) => values[i] === d);
      if (at.length > 1) for (const i of at) out.add(i);
    }
  }
  return [...out].sort((a, b) => a - b);
}

/** Entered cells that disagree with the solution. */
function wrongCells(game) {
  const out = [];
  for (let i = 0; i < 81; i++) {
    if (!game.puzzle[i] && game.values[i] && game.values[i] !== game.solution[i]) out.push(i);
  }
  return out;
}

const isFull = (values) => values.every((x) => x);
const isSolved = (game) => game.values.every((x, i) => x === game.solution[i]);

/** How many of each digit are still to place (index 0 is digit 1). */
function remaining(values) {
  const r = new Array(9).fill(9);
  for (const x of values) if (x) r[x - 1]--;
  return r;
}

// ---------------------------------------------------------------- Hints

/**
 * The next hint for a game. Mistakes come first (an entered digit that isn't
 * the solution's). Otherwise the solver runs on the board with the player's
 * notes taken into account, where they keep the solution's digit. When no
 * technique applies, it reveals the square with the fewest candidates.
 */
function hint(game) {
  const wrong = wrongCells(game);
  if (wrong.length) {
    const cell = wrong[0];
    return {
      technique: 'mistake',
      name: 'Mistake',
      level: 0,
      placements: [],
      eliminations: [],
      clear: [cell],
      cells: [cell],
      digits: [game.values[cell]],
      houses: [],
      nudge: `Something on the board doesn't fit. Check ${cellName(cell)}.`,
      text: `The ${game.values[cell]} in ${cellName(cell)} isn't right. Clear it, then carry on from there.`,
    };
  }
  const v = game.values.slice();
  const c = candidatesOf(v);
  for (let i = 0; i < 81; i++) {
    const n = game.notes[i];
    if (v[i] || !n) continue;
    if (n & (1 << (game.solution[i] - 1))) c[i] &= n;
  }
  const s = findStep(v, c);
  if (s) return Object.assign({ clear: [] }, s);
  let best = -1;
  for (let i = 0; i < 81; i++) {
    if (v[i]) continue;
    if (best < 0 || popcount(c[i]) < popcount(c[best])) best = i;
  }
  if (best < 0) return null;
  const d = game.solution[best];
  return {
    technique: 'reveal',
    name: 'Reveal',
    level: 0,
    placements: [{ cell: best, digit: d }],
    eliminations: [],
    clear: [],
    cells: [best],
    digits: [d],
    houses: [],
    nudge: `There's no simple step from here. ${cellName(best)} is the place to start.`,
    text: `No technique in the guide finds the next step from here, so here is one square: ${cellName(best)} is ${d}.`,
  };
}

/** Applies a hint to a game as one undoable move. */
function applyHint(game, h) {
  const g = cloneGame(game);
  const changes = [];
  for (const cell of h.clear) changes.push({ cell, v0: g.values[cell], n0: g.notes[cell], v1: 0, n1: g.notes[cell] });
  for (const p of h.placements) {
    changes.push({ cell: p.cell, v0: g.values[p.cell], n0: g.notes[p.cell], v1: p.digit, n1: 0 });
    const bit = 1 << (p.digit - 1);
    for (const q of PEERS[p.cell]) {
      if (g.notes[q] & bit) changes.push({ cell: q, v0: g.values[q], n0: g.notes[q], v1: g.values[q], n1: g.notes[q] & ~bit });
    }
  }
  if (h.eliminations.length) {
    const c = candidatesOf(g.values);
    const byCell = new Map();
    for (const e of h.eliminations) byCell.set(e.cell, (byCell.get(e.cell) || 0) | (1 << (e.digit - 1)));
    for (const [cell, mask] of byCell) {
      const n0 = g.notes[cell];
      const base = n0 || c[cell];
      changes.push({ cell, v0: g.values[cell], n0, v1: g.values[cell], n1: base & ~mask });
    }
  }
  commit(g, changes);
  return { game: g };
}

// ---------------------------------------------------------------- Exports

const Ninefold = {
  makeRng, randInt, shuffle, dailySeed,
  ROWS, LEVELS, LEVEL_NAMES, HOUSES, PEERS, TECHNIQUES, MIN_GIVENS,
  rowOf, colOf, boxOf, cellName, houseName, popcount, digitsOf,
  parseGrid, gridText, countSolutions, fullGrid, candidatesOf,
  findStep, applyStep, solveHuman, gradeOf, dig, generate, genStart, genStep,
  UNDO_LIMIT, newGame, place, toggleNote, erase, fillNotes, undo, redo,
  conflicts, wrongCells, isFull, isSolved, remaining, hint, applyHint,
};

// In the editor this is the `engine` script: other scripts load it with
// `const N = await script.engine();`.
function main() {
  return Ninefold;
}
''';
