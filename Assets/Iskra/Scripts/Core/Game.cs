// «Искра» — мир шестигранников: клетки, экономика, персонаж, рост тьмы.
// Вся игровая логика без зависимостей от Unity: её можно гонять в тестах и симуляциях.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Iskra.Core
{
    public struct IncomeParts
    {
        public double Base, Mines, FacSum, Fac, MinesEff, Total;
    }

    public struct Eff
    {
        public double V, Pen;
    }

    // Клетка под угрозой: игрок решает — защищать или отдать
    public sealed class DefendRequest
    {
        public string Own, Att;
        public bool WasPaused;
    }

    public sealed partial class Game
    {
        public GameState S;
        public readonly List<Cell> Own = new List<Cell>();
        public readonly HashSet<string> Vis = new HashSet<string>();
        readonly Dictionary<string, Cell> index = new Dictionary<string, Cell>();

        public DefendRequest Def;
        public bool GameOver;

        // Текущее время интерфейса, с (для эффектов боя и кэшей прогноза)
        public double Now;

        public event Action<string, string> Logged;   // текст, вид: good / bad / info
        public event Action DefendRequested;

        public void Log(string text, string kind = "info") => Logged?.Invoke(text, kind);

        public static string K(int q, int r) => q + "," + r;

        public static double HexDist(int q1, int r1, int q2, int r2)
            => (Math.Abs(q1 - q2) + Math.Abs(r1 - r2) + Math.Abs(q1 + r1 - q2 - r2)) / 2.0;

        // Math.round из JS: половины округляются вверх
        public static double JsRound(double v) => Math.Floor(v + 0.5);

        public Cell Cell(string k) => k != null && index.TryGetValue(k, out var c) ? c : null;
        public Cell Sel => S.sel != null && Vis.Contains(S.sel) ? Cell(S.sel) : null;
        public IEnumerable<Cell> AllCells => S.cells;

        /* ---------- эры ---------- */
        public EraDef EraNow
        {
            get
            {
                if (S.era == null || S.era.i < 0 || S.era.i >= Defs.Eras.Length) NewEra(true);
                return Defs.Eras[S.era.i];
            }
        }

        public double EraV(string k)
        {
            if (S?.era == null || S.era.i < 0 || S.era.i >= Defs.Eras.Length) return 1;
            return Defs.Eras[S.era.i].Fx.TryGetValue(k, out var v) ? v : 1;
        }

        // Эры меняются каждые 1–10 минут игрового времени, следующая — случайная (не та же)
        public void NewEra(bool silent)
        {
            int prev = S.era != null ? S.era.i : -1, i;
            do i = Rand.Int(Defs.Eras.Length); while (i == prev && Defs.Eras.Length > 1);
            double dur = 60 + Rand.Int(541);
            S.era = new EraState { i = i, left = dur, dur = dur };
            var e = Defs.Eras[i];
            if (!silent) Log($"Новая эра: «{e.Name}» — {e.Desc}.", e.Kind == "bad" ? "bad" : "good");
        }

        /* ---------- технологии ---------- */
        public bool HasTech(string id) => S.tech.Contains(id);
        public bool TechOpen(TechDef t) => t.Req.All(HasTech);

        public void ResearchTech(string id)
        {
            var t = Defs.Tech.FirstOrDefault(x => x.Id == id);
            if (t == null || t.Soon || HasTech(id) || !TechOpen(t) || S.pulsars < t.Cost) return;
            S.pulsars -= t.Cost;
            S.tech.Add(id);
            Log($"Изучена технология «{t.Name}».", "good");
        }

        /* ---------- агрессивность мира ---------- */
        // Случайна для каждого мира (заново при прыжке), от ×0,70 до ×1,60
        public static double RollAggr() => JsRound((Defs.AggrMin + Rand.Value * (Defs.AggrMax - Defs.AggrMin)) * 100) / 100;
        public double Aggr => S.aggr > 0 ? S.aggr : 1;
        public static string AggrName(double a) => a < 0.85 ? "спокойный" : a < 1.1 ? "обычный" : a < 1.35 ? "агрессивный" : "яростный";
        public string AggrText => $"×{Fmt.X(Aggr, 2)} — {AggrName(Aggr)}";
        public bool Paused => S.paused;
        public int Speed => S.speed > 0 ? S.speed : 1;

        /* ---------- состояние ---------- */
        static (double m, double e, double f) Split()
        {
            double a = Rand.Value, b = Rand.Value;
            if (a > b) (a, b) = (b, a);
            double m = JsRound(a * 100), e = JsRound((b - a) * 100);
            return (m, e, 100 - m - e);
        }

        public static double Mult(double p) => Math.Max(0.15, p / 33.3);

        // Уровень клетки: у своей — по времени владения, у клетки тьмы — по возрасту (1, 2, 4, 8… мин), +10% за уровень
        public static double CellAge(Cell c) => c.own ? c.held : c.age;
        public static int CellLvl(Cell c)
        {
            if (c.spark) return 0;
            double h = CellAge(c);
            return h < 60 ? 0 : (int)Math.Floor(Math.Log(h / 60, 2)) + 1;
        }
        public static double NextLvlAt(Cell c) => 60 * Math.Pow(2, CellLvl(c));
        public static double GMul(Cell c) => 1 + 0.1 * CellLvl(c);

        // «Управление» усиливает материю и энергию клеток (и их защиту — в CellDef)
        public double St(Cell c, char k)
        {
            double v = k == 'm' ? c.m : k == 'e' ? c.e : c.f;
            return v * GMul(c) * (k != 'f' && c.own ? CtrlMul() : 1);
        }

        public void NewGame()
        {
            S = new GameState { saved = NowMs() };
            FreshWorld();
            S.aggr = 1; // первый мир всегда обычный; случайная агрессивность — с первого прыжка
        }

        public static long NowMs() => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

        public void FreshWorld()
        {
            trendHist.Clear();
            S.wk = 0; S.we = 0; S.worldTime = 0;
            S.aggr = S.nextAggr > 0 && S.rebirths > 0 ? S.nextAggr : RollAggr();
            S.nextAggr = RollAggr();
            S.cells = new List<Cell>();
            index.Clear();
            S.worldStart = NowMs(); S.worldMax = 1; S.matter = 60; S.sel = ""; S.lostOnce = false;
            var (m, e, f) = Split();
            AddCell(new Cell { q = 0, r = 0, own = true, spark = true, m = m, e = e, f = f });
            Refresh(); EnsureNeighbors(0, 0); Refresh();
            if (S.era == null || S.era.i < 0) NewEra(true);
        }

        void AddCell(Cell c)
        {
            S.cells.Add(c);
            index[c.Key] = c;
        }

        // После загрузки: восстанавливает индексы и чинит старые/неполные сохранения
        public bool Attach(GameState st)
        {
            if (st?.cells == null || st.cells.Count == 0 || !st.cells.Any(c => c != null && c.spark)) return false;
            S = st;
            index.Clear();
            foreach (var c in S.cells) index[c.Key] = c;
            if (S.chr == null) S.chr = new CharStats();
            if (S.kills == null) S.kills = new Kills();
            if (S.artifacts == null) S.artifacts = new List<Artifact>();
            if (S.tech == null) S.tech = new List<string>();
            if (S.cores == null) S.cores = new List<int>();
            if (S.abilities == null || S.abilities.Length != Defs.AbilitySlots)
            {
                var old = S.abilities ?? new AbilitySlot[0];
                S.abilities = GameState.NewSlots();
                for (int i = 0; i < S.abilities.Length; i++) S.abilities[i] = i < old.Length && old[i] != null ? old[i] : new AbilitySlot();
            }
            for (int i = 0; i < S.abilities.Length; i++)
                if (S.abilities[i] == null || (!S.abilities[i].Empty && !Defs.Abilities.ContainsKey(S.abilities[i].id))) S.abilities[i] = new AbilitySlot();
            foreach (var c in S.cells) if (c.traits == null) c.traits = new List<string>();
            if (S.aggr <= 0) S.aggr = 1;
            if (S.nextAggr <= 0) S.nextAggr = RollAggr();
            if (S.speed < 1 || S.speed > 3) S.speed = 1;
            if (S.sel == null) S.sel = "";
            Refresh();
            if (S.era == null || S.era.i < 0 || S.era.i >= Defs.Eras.Length) NewEra(true);
            // Пока игрока нет, мир стоит на паузе и ничего не начисляется
            return true;
        }

        // Уровни персонажа слабо усиливают тьму; прыжки — никак
        double Strength() => (S.chr.Sum - 6) * 0.3 + Own.Count * 0.6;

        public double LegendChance => Defs.LegendChance * Aggr * Aggr * EraV("leg");

        string RollTier(double d)
        {
            if (d >= 2 && Rand.Value < LegendChance) return "legend";
            double r = Rand.Value;
            return r < 0.05 + Math.Min(0.1, d * 0.006) ? "epic" : r < 0.3 ? "rare" : "low";
        }

        Cell GenDark(int q, int r)
        {
            double d = HexDist(q, r, 0, 0);
            double b = (5 + Strength() * 1.5) * (1 + d * 0.09);
            string tier = RollTier(d);
            var (m, e, f) = Split();
            return new Cell
            {
                q = q, r = r, own = false, m = m, e = e, f = f,
                might = b * Rand.Range(0.7, 1.3), dev = Rand.Range(Defs.DevMin, Defs.DevMax), growth = Rand.Range(7, 18),
                t = Rand.Range(0, 5), tier = tier, traits = RollTraits(tier), alive = true,
            };
        }

        void EnsureNeighbors(int q, int r)
        {
            for (int i = 0; i < 6; i++)
            {
                int q1 = q + Defs.Dirs[i, 0], r1 = r + Defs.Dirs[i, 1];
                if (!index.ContainsKey(K(q1, r1))) AddCell(GenDark(q1, r1));
            }
        }

        public void Refresh()
        {
            Own.Clear(); Vis.Clear();
            foreach (var c in S.cells)
            {
                if (!c.own) continue;
                Own.Add(c);
                Vis.Add(c.Key);
                for (int i = 0; i < 6; i++) Vis.Add(K(c.q + Defs.Dirs[i, 0], c.r + Defs.Dirs[i, 1]));
            }
        }

        public IEnumerable<Cell> Neighbors(Cell c)
        {
            for (int i = 0; i < 6; i++)
            {
                var n = Cell(K(c.q + Defs.Dirs[i, 0], c.r + Defs.Dirs[i, 1]));
                if (n != null) yield return n;
            }
        }

        /* ---------- экономика ---------- */
        public double BonusMul => 1 + S.bonus;
        // Ядра искры: множители всех применённых ядер складываются. Без ядер ×1. Навсегда.
        public double CoreSum => S.cores.Sum();
        public double CoreMul => CoreSum > 0 ? CoreSum : 1;
        public double CoreAfter(int v) => CoreSum + v;
        public double IncBonus => Math.Pow(BonusMul, Defs.BonusPow);   // сила бонуса прыжка в добыче
        public double SparkMatter => Own.Count * IncBonus;
        public double SparkSpeed => 1 + 0.15 * S.rebirths;

        // (база + шахты × бонус) × (1 + заводы %) × эра
        public double Income() => IncomeParts().Total * EraV("inc");

        // Заводы: сумма процентов всех заводов делится на число клеток и даёт бонус ко всей добыче
        public IncomeParts IncomeParts()
        {
            double mines = 0, facSum = 0;
            foreach (var c in Own)
            {
                if (c.spark) continue;
                mines += MineRate(c, c.mine);
                facSum += FactPct(c, c.factory);
            }
            double fac = Own.Count > 0 ? facSum / Own.Count : 0;
            double b = SparkMatter * 0.5 * CoreMul * SparkSpeed;
            return new IncomeParts
            {
                Base = b, Mines = mines, FacSum = facSum, Fac = fac, MinesEff = mines * (1 + fac / 100),
                Total = (b + mines * IncBonus) * (1 + fac / 100),
            };
        }

        // «Управление»: коэффициент 1 на 1-м уровне, ×1,01 за каждый следующий
        public double CtrlMul() => Math.Pow(1.01, Math.Max(0, EffOf("control").V - 1));
        public double CtrlPct() => (CtrlMul() - 1) * 100;
        public double FortPct(Cell c) => 10 * Mult(St(c, 'f'));   // +10% защиты за уровень укрепления при силе 33%
        public double CellDef(Cell c) => c.spark ? double.PositiveInfinity
            : c.def * (c.defMul > 0 ? c.defMul : 1) * (1 + c.defLvl * FortPct(c) / 100) * (1 + TowerPct(c.tower) / 100) * CtrlMul();

        // Ячейки под строения: при захвате 3 + (материя+энергия)/40, дальше +2 × √(минут владения)
        public static int Cap(Cell c) => 3 + (int)JsRound((c.m + c.e) / 40) + (int)Math.Floor(2 * Math.Sqrt(c.held / 60));
        public static double NextSlotIn(Cell c)
        {
            double n = Math.Floor(2 * Math.Sqrt(c.held / 60)) + 1;
            return Math.Max(0, Math.Pow(n / 2, 2) * 60 - c.held);
        }

        public static int BL(Cell c, string t) => t == "mine" ? c.mine : t == "factory" ? c.factory : t == "tower" ? c.tower : 0;
        static void SetBL(Cell c, string t, int v)
        {
            if (t == "mine") c.mine = v;
            else if (t == "factory") c.factory = v;
            else if (t == "tower") c.tower = v;
        }
        public static int UsedCap(Cell c) => c.mine + c.factory + c.tower;

        public double BldCost(Cell c, string t)
        {
            int L = BL(c, t);
            if (t == "tower") return Math.Ceiling(Defs.TowerCost * Math.Pow(Defs.TowerGrow, L) * EraV("def"));
            double b = t == "mine" ? Defs.MineCost * Math.Pow(Defs.MineGrow, L) : Defs.FacCost * Math.Pow(Defs.FacGrow, L);
            return Math.Ceiling(b * EraV("bld"));
        }

        public static double TowerPct(int L) => L > 0 ? 25 * Math.Pow(2, L - 1) : 0;   // 25%, 50%, 100%, 200%…
        // Комплекс: каждое следующее одинаковое строение на клетке +10% ко всем таким строениям
        static double Syn(int L) => L > 0 ? 1 + 0.1 * (L - 1) : 0;
        public double MineRate(Cell c, int L) => L * 1.2 * Mult(St(c, 'm')) * Syn(L);
        public double FactPct(Cell c, int L) => L * 8 * Mult(St(c, 'e')) * Syn(L);
        public double DefCostOf(Cell c) => Math.Ceiling(Defs.DefCost * Math.Pow(Defs.DefGrow, c.defLvl) * EraV("def"));

        public void AddMatter(double x)
        {
            S.matter += x;
            if (x > 0) { S.earned += x; S.we += x; }
        }

        // Незахваченные клетки рядом с живой легендарной сущностью растут вдвое быстрее
        public bool NearLegend(Cell c) => !c.own && Neighbors(c).Any(n => !n.own && n.alive && n.tier == "legend");
        public double GrowMul(Cell c) => NearLegend(c) ? 2 : 1;
        // Чем больше клеток у игрока, тем быстрее растёт тьма
        public double DarkF => 1 + 0.1 * Math.Sqrt(Math.Max(0, Own.Count - 1));
        // Бонус прыжка замедляет тьму
        public double GrowRate(Cell c) => Defs.GrowthRate * GrowMul(c) * Aggr * EraV("grow") * DarkF / Math.Sqrt(BonusMul);

        public double MaxAdjMight(Cell c)
        {
            double m = 0;
            foreach (var n in Neighbors(c)) if (!n.own && n.alive) m = Math.Max(m, n.might);
            return m;
        }

        public bool Threatened(Cell c) => !c.spark && MaxAdjMight(c) >= CellDef(c) * 0.8;
        public int ThreatCount => Own.Count(Threatened);

        /* ---------- персонаж ---------- */
        // Перекос: если параметр вдвое выше среднего по остальным, он теряет 10% силы, втрое — 20%…
        public Eff EffOf(string p)
        {
            double sum = 0;
            foreach (var x in Defs.Params) if (x.Id != p) sum += S.chr[x.Id];
            double ratio = S.chr[p] / (sum / 5);
            double pen = ratio >= 2 ? Math.Min(0.6, 0.1 * (Math.Floor(ratio) - 1)) : 0;
            return new Eff { V = S.chr[p] * (1 - pen), Pen = pen };
        }

        public double MaxHp() => 60 + 40 * EffOf("life").V;
        public double DefDiv() => 1 + 0.125 * (EffOf("defense").V - 1);
        public double PowMul() => (1 + 0.125 * (EffOf("power").V - 1)) * EraV("pAtk");
        public double Med() => 1 + 0.5 * (EffOf("meditation").V - 1);
        public double TurnCd() => 1.4 / (1 + 0.06 * (EffOf("speed").V - 1)) * EraV("cd");

        // Стоимость навыка: база × (низш. 1 / ред. 1,25 / эпич. 1,5) × (1 + 12% за уровень)
        public static double AbCost(AbilitySlot a)
        {
            var d = Defs.Abilities[a.id];
            return Math.Max(1, JsRound(d.Cost * Defs.GradeCost[d.Tier] * (1 + 0.12 * (a.lvl - 1))));
        }

        public double AbVal(AbilitySlot a)
        {
            var d = Defs.Abilities[a.id];
            int L = a.lvl - 1;
            switch (d.Kind)
            {
                case "dmg": case "drain": case "dot": case "pierce": case "harvest": case "execute":
                    return d.Base * (1 + 0.15 * L) * Med();   // урон навыков растёт от Медитации
                case "heal": case "regenme":
                    return MaxHp() * d.Base / 100 * (1 + 0.15 * L);
                case "absorb":
                    return d.Base + 0.01 * L;
                default:
                    return d.Base + 0.2 * L;
            }
        }

        public string AbDesc(AbilitySlot a)
        {
            double v = AbVal(a), pm = PowMul();
            string r(double x) => Fmt.N(JsRound(x));
            switch (Defs.Abilities[a.id].Kind)
            {
                case "dmg": return $"Урон {r(v * pm)}";
                case "heal": return $"Лечит {r(v)}";
                case "shield": return $"Урон по вам вдвое меньше {Fmt.X(v)} с";
                case "drain": return $"Урон {r(v * pm)}, лечит 60% от него";
                case "haste": return $"Сбрасывает откат, ходы вдвое быстрее {Fmt.X(v)} с";
                case "immune": return $"Неуязвимость {Fmt.X(v)} с";
                case "absorb": return $"Забирает {r(v * 100)}% здоровья врага, лечит половину";
                case "dot": return $"Жжёт {r(v * pm)} урона в секунду {Defs.DotT} с";
                case "stunfoe": return $"Отбрасывает удар врага на {Fmt.X(v)} с";
                case "regenme": return $"Лечит {r(v)} в секунду {Defs.MendT} с";
                case "pierce": return $"Урон {r(v * pm)} сквозь панцирь и завесу";
                case "weaken": return $"Враг бьёт на 40% слабее {Fmt.X(v)} с";
                case "harvest": return $"Урон {r(v * pm)}, при попадании возвращает вдвое больше материи, чем стоит";
                case "reflect": return $"{Fmt.X(v)} с отражает 60% удара врага обратно";
                case "execute": return $"Урон {r(v * pm)}, втрое больше по врагу с здоровьем ниже 30%";
                case "dispel": return $"Отключает особенности врага на {Fmt.X(v)} с";
            }
            return "";
        }

        /* ---------- ход мира ---------- */
        public void Tick(double dt)
        {
            if (S.paused) return;
            AddMatter(Income() * dt);
            if (S.era != null)
            {
                S.era.left -= dt;
                if (S.era.left <= 0) NewEra(false);
            }
            TrendSample(dt);
            foreach (var c in Own)
            {
                if (c.spark) continue;
                c.held += dt * EraV("held");
                int L = CellLvl(c);
                if (c.lv0 < 0) c.lv0 = L;
                else if (L > c.lv0)
                {
                    c.lv0 = L;
                    if (c.Key == S.sel || Own.Count < 12) Log($"Клетка достигла уровня {L}: +10% к её силе.", "good");
                }
            }
            foreach (var k in Vis.ToList())
            {
                var c = Cell(k);
                if (c == null || c.own) continue;
                c.t += dt * GrowRate(c);
                c.age += dt * EraV("held");
                if (c.t >= c.growth)
                {
                    c.t -= c.growth;
                    c.might = c.might * (1 + (c.dev - 1) * DarkF) + 0.2;
                    if (c.alive) Threaten(c);
                }
            }
        }

        // Главный кадр: время мира, бой, проверка банкротства
        public void Frame(double dt)
        {
            Refresh();
            if (!GameOver && S.matter < 0 && B == null) { GameOver = true; return; }
            if (GameOver) return;
            double wd = dt * Speed;
            Tick(wd);
            BattleTick(dt);
            if (!S.paused) S.worldTime += wd;
        }

        public void LoseCell(Cell n, Cell c)
        {
            n.own = false; n.might = c.might + 1; n.dev = Rand.Range(Defs.DevMin, Defs.DevMax); n.growth = Rand.Range(7, 18); n.t = 0;
            n.tier = RollTier(HexDist(n.q, n.r, 0, 0)); n.alive = true;
            n.mine = n.factory = n.tower = 0; n.inv = 0; n.def = 0; n.defLvl = 0; n.defMul = 1; n.held = 0; n.age = 0; n.lv0 = -1;
            n.traits = RollTraits(n.tier);
            S.lostOnce = true;
            Log($"Тьма захватила клетку. Её мощь теперь {Math.Ceiling(n.might)}.", "bad");
            Refresh();
        }

        // Тьма догнала защиту клетки: не забираем сразу, а спрашиваем игрока
        void Threaten(Cell c)
        {
            if (Def != null || B != null || !c.alive) return;   // одна угроза за раз; во время боя проверим позже
            foreach (var n in Neighbors(c))
            {
                if (n.own && !n.spark && c.might >= CellDef(n))
                {
                    Def = new DefendRequest { Own = n.Key, Att = c.Key, WasPaused = S.paused };
                    S.paused = true;
                    S.sel = Def.Own;
                    DefendRequested?.Invoke();
                    return;
                }
            }
        }

        public bool DefendValid()
        {
            if (Def == null) return false;
            var n = Cell(Def.Own); var c = Cell(Def.Att);
            if (n == null || c == null || !n.own) { Def = null; return false; }
            return true;
        }

        public void DefendFlee()
        {
            var d = Def; Def = null;
            if (d == null) return;
            var n = Cell(d.Own); var c = Cell(d.Att);
            if (n != null && c != null && n.own) LoseCell(n, c);
            S.paused = d.WasPaused;
        }

        public void DefendFight()
        {
            var d = Def; Def = null;
            if (d == null) return;
            var c = Cell(d.Att);
            if (c == null) return;
            S.sel = d.Att;
            StartBattle(FoeFromCell(c), d.Att);
            B.Defend = d.Own;
        }

        /* ---------- действия с клетками ---------- */
        // Сложность кратна удалённости от искры
        public static int FoeDist(Cell c) => Math.Max(1, (int)HexDist(c.q, c.r, 0, 0));

        // Особенности: низшая — иногда одна, редкая — одна, эпическая — одна-две, легендарная — две
        static List<string> RollTraits(string tier)
        {
            List<string> pick(int n)
            {
                var o = new List<string>();
                while (o.Count < n)
                {
                    var k = Defs.TraitOrder[Rand.Int(Defs.TraitOrder.Length)];
                    if (!o.Contains(k)) o.Add(k);
                }
                return o;
            }
            if (tier == "low") return Rand.Value < 0.35 ? new List<string> { new[] { "regen", "shell", "leech" }[Rand.Int(3)] } : new List<string>();
            if (tier == "rare") return pick(1);
            if (tier == "epic") return pick(Rand.Value < 0.5 ? 2 : 1);
            return pick(2);
        }

        public double LeechAmt() => Math.Ceiling(3 * Med());

        public Foe FoeFromCell(Cell c)
        {
            var t = Defs.Tiers[c.tier];
            int dm = FoeDist(c);
            double b = c.might * t.Mult * Aggr * Defs.EarlyMul;
            return new Foe
            {
                Name = t.Foe, Tier = c.tier, Dist = dm,
                MaxHp = b * 8 * dm * Defs.FoeHpK * EraV("foeHp"),
                Atk = (b * 0.55 * dm + 2) * Defs.FoeAtkK * EraV("foeAtk"),
                Cd = t.Cd,
                Matter = b * 10 * dm * Defs.FoeRewardK * EraV("reward"),
                Pen = b * 10,
                Traits = c.traits ?? new List<string>(),
            };
        }

        public bool Capture(string k)
        {
            var c = Cell(k);
            if (c == null || c.own || c.alive) return false;
            double cost = Math.Ceiling(c.might);
            if (S.matter < cost) return false;
            S.matter -= cost;
            c.own = true; c.def = 0; c.defLvl = 0; c.defMul = 1; c.mine = c.factory = c.tower = 0; c.inv = 0; c.held = 0; c.age = 0; c.lv0 = -1;
            Refresh(); EnsureNeighbors(c.q, c.r); Refresh();
            c.def = Math.Ceiling(Math.Max(cost, MaxAdjMight(c))) + 1;
            S.worldMax = Math.Max(S.worldMax, Own.Count);
            S.bestCells = Math.Max(S.bestCells, Own.Count);
            Log($"Клетка захвачена. Защита {c.def}.", "good");
            return true;
        }

        public void Build(string k, string t)
        {
            var c = Cell(k);
            if (c == null || !c.own || c.spark || Array.IndexOf(Defs.Buildings, t) < 0) return;
            if (UsedCap(c) >= Cap(c)) return;
            double cost = BldCost(c, t);
            if (S.matter < cost) return;
            S.matter -= cost;
            SetBL(c, t, BL(c, t) + 1);
        }

        public void Lower(string k, string t)
        {
            var c = Cell(k);
            if (c == null || !c.own || BL(c, t) <= 0) return;
            SetBL(c, t, BL(c, t) - 1);
        }

        public void Fortify(string k)
        {
            var c = Cell(k);
            if (c == null || !c.own || c.spark) return;
            double cost = DefCostOf(c);
            if (S.matter < cost) return;
            S.matter -= cost;
            c.defLvl++;
        }

        // Прибавка за укрепление: столько защиты даст следующий уровень
        public double FortGain(Cell c) => c.def * FortPct(c) / 100 * (1 + TowerPct(c.tower) / 100) * CtrlMul();
    }
}
