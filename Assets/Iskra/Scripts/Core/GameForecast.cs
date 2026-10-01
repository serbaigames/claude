// «Искра» — прогноз боя (120 быстрых прогонов) и оценка состояния мира
using System;
using System.Collections.Generic;
using System.Linq;

namespace Iskra.Core
{
    public sealed class Forecast
    {
        public double P, Cap, Spent, Dur, CapCost, Need;
        public bool Winnable;
    }

    public sealed class WorldTrend
    {
        public string Kind = "stall";   // grow / stall / warn / dark
        public string Text = "оценка…";
        public string Info = "";
    }

    public sealed partial class Game
    {
        string fcKey = "";
        double fcAt = -9;
        Forecast fcVal;

        public Forecast FightForecast(Cell c)
        {
            var f = FoeFromCell(c);
            string key = string.Join("|", c.Key, c.tier, Aggr, string.Join(",", f.Traits), JsRound(c.might), Math.Floor(S.matter),
                S.chr.life, S.chr.defense, S.chr.power, S.chr.meditation, S.chr.speed, S.chr.control,
                string.Join(",", S.abilities.Select(a => a.Empty ? "-" : a.id + a.lvl)), S.era?.i);
            if (fcKey == key && Now - fcAt < 2 && fcVal != null) return fcVal;

            double hp0 = MaxHp(), dd = DefDiv(), pm = PowMul(), atkC = Math.Max(1, Math.Ceiling(4 * Med())), tc = TurnCd(), capCost = Math.Ceiling(c.might);
            var ab = S.abilities.Select(a => a.Empty ? null : new { d = Defs.Abilities[a.id], v = AbVal(a), cost = AbCost(a) }).ToArray();
            double lch = LeechAmt(), med = Med();
            var tr = f.Traits;
            const double dt = 0.1;

            (int wins, int capOk, double spent, double dur) Run(double mat0, int N)
            {
                int wins = 0, capOk = 0; double spent = 0, dur = 0;
                var acd = new double[ab.Length];
                for (int n = 0; n < N; n++)
                {
                    double hp = hp0, fh = f.MaxHp, m = mat0, cd = 0, ft = 0, sh = 0, im = 0, ha = 0, t = 0, wt = 0, dot = 0, dotV = 0, mend = 0, mendV = 0, wk = 0, rf = 0, dsp = 0;
                    int res = 0, hits = 0;
                    Array.Clear(acd, 0, acd.Length);
                    bool T(string k) => dsp <= 0 && tr.Contains(k);
                    double Hit(double d, bool pc)
                    {
                        if (!pc && T("ward") && (wt % 10) >= 8) return 0;
                        if (!pc && T("shell") && fh > f.MaxHp * 0.5) d *= 0.65;
                        fh -= d;
                        return d;
                    }
                    while (t < 600)
                    {
                        t += dt; cd -= dt; ft += dt; wt += dt; sh -= dt; im -= dt; ha -= dt; wk -= dt; rf -= dt; dsp -= dt;
                        for (int i = 0; i < acd.Length; i++) acd[i] -= dt;
                        if (dot > 0) { dot -= dt; fh -= dotV * dt * (T("shell") && fh > f.MaxHp * 0.5 ? 0.65 : 1); }
                        if (mend > 0) { mend -= dt; hp = Math.Min(hp0, hp + mendV * dt); }
                        if (T("regen")) fh = Math.Min(f.MaxHp, fh + f.MaxHp * 0.015 * dt);
                        if (ft >= (T("rage") && fh < f.MaxHp * 0.4 ? f.Cd / 1.6 : f.Cd))
                        {
                            ft = 0; hits++;
                            if (im <= 0)
                            {
                                double d = f.Atk * Rand.Range(.85, 1.15) / dd;
                                if (sh > 0) d *= 0.5;
                                if (wk > 0) d *= 0.6;
                                d = JsRound(d);
                                hp -= d;
                                if (rf > 0) fh -= JsRound(d * 0.6);
                                if (T("leech")) m -= Math.Min(Math.Max(0, m), lch);
                                if (T("stun") && hits % 4 == 0) cd += 1;
                            }
                        }
                        if (hp <= 0) { res = -1; break; }
                        int pick = -1;
                        double hpp = hp / hp0;
                        for (int i = 0; i < ab.Length; i++)
                        {
                            var a = ab[i];
                            if (a == null || acd[i] > 0 || m < a.cost) continue;
                            string k = a.d.Kind;
                            if (k == "heal" && hpp < 0.5 || k == "regenme" && hpp < 0.75 && mend <= 0
                                || (k == "immune" || k == "shield" || k == "reflect" || k == "weaken") && hpp < 0.8 && ft > f.Cd * 0.5
                                || k == "stunfoe" && ft > f.Cd * 0.6 || k == "dispel" && tr.Count > 0 && dsp <= 0 || k == "dot" && dot <= 0
                                || k == "execute" && fh < f.MaxHp * 0.3
                                || k == "dmg" || k == "drain" || k == "absorb" || k == "haste" || k == "pierce" || k == "harvest")
                            { pick = i; break; }
                        }
                        if (pick >= 0)
                        {
                            var a = ab[pick];
                            string k = a.d.Kind;
                            m -= a.cost; acd[pick] = a.d.Cd;
                            switch (k)
                            {
                                case "dmg": Hit(a.v * pm * Rand.Range(.9, 1.1), false); break;
                                case "heal": hp = Math.Min(hp0, hp + a.v); break;
                                case "shield": sh = a.v; break;
                                case "drain": { double x = Hit(a.v * pm, false); hp = Math.Min(hp0, hp + x * 0.6); break; }
                                case "haste": ha = a.v; break;
                                case "immune": im = a.v; break;
                                case "absorb": { double x = Hit(f.MaxHp * a.v, false); hp = Math.Min(hp0, hp + x * 0.5); break; }
                                case "dot": dot = Defs.DotT; dotV = a.v * pm; break;
                                case "stunfoe": ft -= a.v; break;
                                case "regenme": mend = Defs.MendT; mendV = a.v; break;
                                case "pierce": Hit(a.v * pm * Rand.Range(.9, 1.1), true); break;
                                case "weaken": wk = a.v; break;
                                case "reflect": rf = a.v; break;
                                case "dispel": dsp = a.v; break;
                                case "harvest": if (Hit(a.v * pm * Rand.Range(.9, 1.1), false) > 0) m += a.cost * 2; break;
                                case "execute": Hit(a.v * pm * Rand.Range(.9, 1.1) * (fh < f.MaxHp * 0.3 ? 3 : 1), false); break;
                            }
                        }
                        if (cd <= 0)
                        {
                            if (m >= atkC) { m -= atkC; Hit(10 * med * pm * Rand.Range(.9, 1.1), false); cd = tc * (ha > 0 ? 0.5 : 1); }
                            else if (pick < 0) { res = -1; break; }   // материя кончилась
                        }
                        if (fh <= 0) { res = 1; break; }
                    }
                    if (res == 1) { wins++; spent += mat0 - m; dur += t; if (m >= capCost) capOk++; }
                }
                return (wins, capOk, spent, dur);
            }

            const int Nr = 120;
            var r = Run(S.matter, Nr);
            // сколько материи нужно на победу: если с текущим запасом побед мало — считаем «с неограниченным запасом»
            var ri = r.wins >= Nr * 0.6 ? r : Run(1e12, 40);
            fcVal = new Forecast
            {
                P = r.wins / (double)Nr, Cap = r.wins > 0 ? r.capOk / (double)r.wins : 0, Spent = r.wins > 0 ? r.spent / r.wins : 0,
                Dur = ri.wins > 0 ? ri.dur / ri.wins : 0, CapCost = capCost, Need = ri.wins > 0 ? ri.spent / ri.wins : 0, Winnable = ri.wins > 0,
            };
            fcKey = key; fcAt = Now;
            return fcVal;
        }

        // Подпись прогноза и её цвет: bad / warn / ok / good
        public static (string label, string cls) ForecastLabel(double p)
        {
            if (p <= 0) return ("победа невозможна", "bad");
            if (p < 0.15) return ("почти без шансов", "bad");
            if (p < 0.35) return ("маловероятная победа", "warn");
            if (p < 0.6) return ("исход неясен", "warn");
            if (p < 0.85) return ("вероятная победа", "ok");
            if (p < 0.98) return ("уверенная победа", "good");
            return ("безоговорочная победа", "good");
        }

        // Строка о материи: сколько нужно на победу и хватает ли
        public (string text, string cls) ForecastMatter(Forecast fc)
        {
            if (!fc.Winnable) return ("даже с любым запасом материи не победить", "bad");
            double need = Math.Ceiling(fc.Need), total = need + fc.CapCost;
            if (S.matter < need) return ($"нужно ~{Fmt.N(need)} материи — не хватает {Fmt.N(Math.Ceiling(need - S.matter))}", "bad");
            if (S.matter < total) return ($"~{Fmt.N(need)} на бой, на захват ({Fmt.N(fc.CapCost)}) может не хватить", "warn");
            return ($"~{Fmt.N(need)} материи на бой · ~{JsRound(fc.Dur)} с", "");
        }

        /* ---------- состояние мира ---------- */
        readonly List<(double t, int n)> trendHist = new List<(double, int)>();
        double trendAcc;

        // По клеткам за последние 2 минуты игрового времени
        void TrendSample(double dt)
        {
            trendAcc += dt;
            if (trendAcc < 5) return;
            trendAcc = 0;
            double t = S.worldTime;
            trendHist.Add((t, Own.Count));
            while (trendHist.Count > 0 && trendHist[0].t < t - 120) trendHist.RemoveAt(0);
        }

        // Быстрая оценка боя без прогона: урон в секунду игрока и сущности с учётом особенностей
        (bool beat, double tKill, double cost) QuickFight(Cell c)
        {
            var f = FoeFromCell(c);
            var tr = f.Traits;
            double pm = PowMul(), tc = TurnCd(), atkC = Math.Max(1, Math.Ceiling(4 * Med()));
            double dps = 10 * Med() * pm / tc, abCostPs = 0;
            foreach (var a in S.abilities)
            {
                if (a.Empty) continue;
                var d = Defs.Abilities[a.id];
                double v = AbVal(a);
                string k = d.Kind;
                double dm = k == "dmg" || k == "drain" || k == "pierce" || k == "harvest" ? v * pm
                    : k == "execute" ? v * pm * 1.4 : k == "dot" ? v * pm * Defs.DotT : k == "absorb" ? f.MaxHp * v : 0;
                if (dm > 0) { dps += dm / d.Cd; abCostPs += AbCost(a) / d.Cd; }
            }
            if (tr.Contains("shell")) dps *= 0.82;
            if (tr.Contains("ward")) dps *= 0.8;
            if (tr.Contains("regen")) dps -= f.MaxHp * 0.015;
            double tKill = dps > 0 ? f.MaxHp / dps : double.PositiveInfinity;
            double foeDps = f.Atk / DefDiv() / f.Cd * (tr.Contains("rage") ? 1.2 : 1), tDie = MaxHp() / Math.Max(1e-6, foeDps);
            double cost = !double.IsInfinity(tKill)
                ? tKill / tc * atkC + tKill * abCostPs + (tr.Contains("leech") ? tKill / f.Cd * LeechAmt() : 0)
                : double.PositiveInfinity;
            return (tKill < tDie * 0.8, tKill, cost + Math.Ceiling(c.might));
        }

        double wtAt = -9;
        readonly WorldTrend wt = new WorldTrend();

        // Может ли игрок побеждать соседей, успевает ли добыча за ростом тьмы, есть ли угрозы и потери
        public WorldTrend Trend()
        {
            if (Now - wtAt < 2) return wt;
            wtAt = Now;
            double inc = Math.Max(1e-6, Income());
            var front = Vis.Select(Cell).Where(c => c != null && !c.own).ToList();
            int beat = 0;
            double best = double.PositiveInfinity;
            var rates = new List<double>();
            foreach (var c in front)
            {
                if (!c.alive)
                {
                    best = Math.Min(best, Math.Max(0, (Math.Ceiling(c.might) - S.matter) / inc));
                    beat++;
                    continue;
                }
                var q = QuickFight(c);
                if (q.beat) { beat++; best = Math.Min(best, Math.Max(0, (q.cost - S.matter) / inc) + q.tKill); }
                rates.Add(GrowRate(c) / c.growth * Math.Log(1 + (c.dev - 1) * DarkF));
            }
            rates.Sort();
            double r = rates.Count > 0 ? rates[rates.Count >> 1] : 0, Td = r > 0 ? Math.Log(2) / r : double.PositiveInfinity;   // время удвоения мощи тьмы, с
            bool lost = trendHist.Count > 0 && Own.Count < trendHist[0].n;
            int thr = ThreatCount;
            bool heavy = thr >= Math.Max(2, Own.Count * 0.25);
            string m(double s) => double.IsInfinity(s) ? "—" : s < 90 ? JsRound(s) + " с" : JsRound(s / 60) + " мин";
            wt.Info = $"Можно победить соседей: {beat} из {front.Count}. Ближайшая победа и захват: {(double.IsInfinity(best) ? "нет" : best < 1 ? "сейчас" : "через " + m(best))}. Мощь тьмы удваивается за {m(Td)}. Клеток под угрозой: {thr}.";
            if (beat == 0)
            {
                if (lost || heavy) { wt.Kind = "dark"; wt.Text = "тьма поглощает мир"; }
                else { wt.Kind = "warn"; wt.Text = "соседи сильнее — нужно усилиться"; }
            }
            else if (lost && best > Td * 0.5) { wt.Kind = "dark"; wt.Text = "тьма наступает быстрее добычи"; }
            else if (best <= Td * 0.25 && !heavy) { wt.Kind = "grow"; wt.Text = "мир растёт"; }
            else if (best <= Td) { wt.Kind = "stall"; wt.Text = heavy ? "рост замедляется, тьма давит" : "рост замедляется"; }
            else { wt.Kind = "warn"; wt.Text = "тьма развивается быстрее добычи"; }
            return wt;
        }
    }
}
