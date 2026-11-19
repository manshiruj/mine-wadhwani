// Pure aggregation over completed inspections (kept separate so it can be unit-tested without Mongo).
const pct = (yes, no) => (yes + no === 0 ? null : Math.round((yes / (yes + no)) * 1000) / 10);

export const summarize = (inspections, actions = [], now = new Date()) => {
  const mines = new Map();
  const shifts = { 1: { yes: 0, no: 0, count: 0 }, 2: { yes: 0, no: 0, count: 0 }, 3: { yes: 0, no: 0, count: 0 } };
  const days = new Map();
  let yes = 0;
  let no = 0;

  for (const ins of inspections) {
    let y = 0;
    let n = 0;
    for (const q of ins.checklistData ?? []) {
      const a = String(q.answer || "").trim().toUpperCase();
      if (a === "YES") y++;
      else if (a === "NO") n++;
    }
    yes += y;
    no += n;
    const m = mines.get(ins.mine_name) ?? { mine_name: ins.mine_name, inspections: 0, yes: 0, no: 0, openActions: 0, overdueActions: 0, lastInspection: null };
    m.inspections++;
    m.yes += y;
    m.no += n;
    const d = new Date(ins.date);
    if (!m.lastInspection || d > m.lastInspection) m.lastInspection = d;
    mines.set(ins.mine_name, m);
    const s = shifts[ins.shift];
    if (s) {
      s.yes += y;
      s.no += n;
      s.count++;
    }
    const key = d.toISOString().slice(0, 10);
    const day = days.get(key) ?? { date: key, yes: 0, no: 0, inspections: 0 };
    day.yes += y;
    day.no += n;
    day.inspections++;
    days.set(key, day);
  }

  for (const a of actions) {
    if (a.status !== "open") continue;
    const m = mines.get(a.mine_name) ?? { mine_name: a.mine_name, inspections: 0, yes: 0, no: 0, openActions: 0, overdueActions: 0, lastInspection: null };
    m.openActions++;
    if (a.dueAt && new Date(a.dueAt) < now) m.overdueActions++;
    mines.set(a.mine_name, m);
  }

  return {
    totals: {
      inspections: inspections.length,
      compliance: pct(yes, no),
      nonCompliant: no,
      openActions: actions.filter((a) => a.status === "open").length,
      overdueActions: actions.filter((a) => a.status === "open" && a.dueAt && new Date(a.dueAt) < now).length,
    },
    mines: [...mines.values()]
      .map((m) => ({ ...m, compliance: pct(m.yes, m.no) }))
      .sort((a, b) => (a.compliance ?? 101) - (b.compliance ?? 101)), // worst first
    shifts: Object.entries(shifts).map(([shift, s]) => ({ shift: Number(shift), inspections: s.count, compliance: pct(s.yes, s.no) })),
    trend: [...days.values()].sort((a, b) => a.date.localeCompare(b.date)).map((d) => ({ date: d.date, inspections: d.inspections, compliance: pct(d.yes, d.no) })),
  };
};
