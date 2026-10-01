// «Искра» — прокачка (ОП, ОС), артефакты, прыжок искры
using System;
using System.Collections.Generic;
using System.Linq;

namespace Iskra.Core
{
    public struct BuyInfo
    {
        public long N;
        public double Cost, Next;
    }

    public sealed partial class Game
    {
        /* ---------- покупки за раз: ×1, ×10, ×100, MAX ---------- */
        public const int Max = -1;
        public static readonly int[] Mults = { 1, 10, 100, Max };
        public readonly Dictionary<string, int> M = new Dictionary<string, int> { ["opBuy"] = 1, ["par"] = 1, ["osBuy"] = 1, ["ab"] = 1 };

        public static string MultLabel(int m) => m == Max ? "MAX" : "×" + m;

        public void CycleMult(string key)
        {
            int i = Array.IndexOf(Mults, M[key]);
            M[key] = Mults[(i + 1) % Mults.Length];
        }

        static double LvlCost(long lvl, long n, double per) => per * (n * lvl + n * (n - 1) / 2.0);

        static long LvlCount(int mode, long lvl, double per, double budget)
        {
            if (mode != Max) return mode;
            long n = 0; double c = 0;
            while (n < 100000)
            {
                double nx = (lvl + n) * per;
                if (c + nx > budget) break;
                c += nx; n++;
            }
            return n;
        }

        // Каждое следующее очко дороже предыдущего на 1,5% (счёт за мир, сбрасывается при прыжке)
        static double PtCost(double b, long k, long n)
            => n <= 0 ? 0 : Math.Ceiling(b * Math.Pow(Defs.PtGrow, k) * (Math.Pow(Defs.PtGrow, n) - 1) / (Defs.PtGrow - 1));

        static long PtMax(double b, long k, double m)
            => Math.Max(0, (long)Math.Floor(Math.Log(1 + Math.Max(0, m) * (Defs.PtGrow - 1) / (b * Math.Pow(Defs.PtGrow, k))) / Math.Log(Defs.PtGrow)));

        BuyInfo PtInfo(double b, long k, int mode)
        {
            long maxN = PtMax(b, k, S.matter);
            long n = mode == Max ? maxN : mode;
            double cost = PtCost(b, k, n);
            if (mode != Max && cost > S.matter) { n = Math.Min(n, maxN); cost = PtCost(b, k, n); }
            return new BuyInfo { N = n, Cost = cost, Next = PtCost(b, k, 1) };
        }

        // Бонус прыжка удешевляет очки (цена ÷ √бонуса), эра может удешевить или удорожить их
        double PtBase(double b) => b * EraV("pt") / Math.Sqrt(BonusMul);
        public BuyInfo OpBuyInfo() => PtInfo(PtBase(20), S.opB, M["opBuy"]);
        public BuyInfo OsBuyInfo() => PtInfo(PtBase(10), S.osB, M["osBuy"]);

        public BuyInfo ParInfo(string k)
        {
            int lv = S.chr[k];
            long n = LvlCount(M["par"], lv, 1, S.op);
            return new BuyInfo { N = n, Cost = LvlCost(lv, n, 1) };
        }

        public BuyInfo AbInfo(int i)
        {
            var a = S.abilities[i];
            double per = Defs.Tiers[Defs.Abilities[a.id].Tier].Os;
            long n = LvlCount(M["ab"], a.lvl, per, S.os);
            return new BuyInfo { N = n, Cost = LvlCost(a.lvl, n, per) };
        }

        public void BuyOp()
        {
            var b = OpBuyInfo();
            if (b.N > 0 && S.matter >= b.Cost) { S.matter -= b.Cost; S.op += b.N; S.opB += b.N; }
        }

        public void BuyOs()
        {
            var b = OsBuyInfo();
            if (b.N > 0 && S.matter >= b.Cost) { S.matter -= b.Cost; S.os += b.N; S.osB += b.N; }
        }

        public void ParUp(string k)
        {
            var i = ParInfo(k);
            if (i.N > 0 && S.op >= i.Cost) { S.op -= (long)i.Cost; S.chr[k] += (int)i.N; }
        }

        public void AbUp(int idx)
        {
            if (S.abilities[idx].Empty) return;
            var i = AbInfo(idx);
            if (i.N > 0 && S.os >= i.Cost)
            {
                var a = S.abilities[idx];
                S.os -= (long)i.Cost; a.inv += (long)i.Cost; a.lvl += (int)i.N;
            }
        }

        /* ---------- артефакты ---------- */
        public bool ArtValid(Artifact a, Cell c)
        {
            string t = Defs.Arts[a.type].Target;
            if (t == "player") return true;
            if (c == null || !Vis.Contains(c.Key)) return false;
            if (t == "spark") return c.spark;
            return t == "own" ? c.own && !c.spark : !c.own;
        }

        public static string ArtTitle(Artifact a)
        {
            var d = Defs.Arts[a.type];
            if (d.Stat != null || a.type == "bulwark") return $"{d.Name} +{a.v}%";
            switch (a.type)
            {
                case "core": return $"{d.Name} ×{a.v}";
                case "bloom": return $"{d.Name} +{a.v} мин";
                case "tome": return $"{d.Name} +{a.v} ОП";
                case "rune": return $"{d.Name} +{a.v} ОС";
            }
            return d.Name;
        }

        public static string ArtBadge(Artifact a)
        {
            var d = Defs.Arts[a.type];
            if (d.Stat != null || a.type == "bulwark") return $"+{a.v}%";
            switch (a.type)
            {
                case "core": return "×" + a.v;
                case "clot": return "÷2";
                case "bloom": return $"+{a.v}м";
                case "frost": return "½";
                case "tome": return $"+{a.v}ОП";
                case "rune": return $"+{a.v}ОС";
            }
            return "эра";
        }

        public string ArtDesc(Artifact a)
        {
            var d = Defs.Arts[a.type];
            switch (a.type)
            {
                case "bulwark": return $"Навсегда усиливает защиту вашей клетки на {a.v}%.";
                case "bloom": return $"Добавляет вашей клетке {a.v} мин владения — она быстрее набирает уровни.";
                case "frost": return "Вдвое замедляет развитие клетки тьмы.";
                case "tome": return $"Даёт {a.v} очков параметров.";
                case "rune": return $"Даёт {a.v} очков способностей.";
                case "glass": return "Завершает текущую эру и начинает новую, случайную.";
                case "core":
                    return $"Множитель ×{a.v} прибавляется к множителям прежних ядер: базовая добыча искры навсегда станет 0,5 × {CoreAfter(a.v)} = {Fmt.X(0.5 * CoreAfter(a.v))} за клетку (сейчас ×{CoreMul}). Применяется к искре.";
            }
            return d.Stat != null ? $"Добавляет захваченной клетке {a.v}% {d.Word}." : "Вдвое снижает мощь не захваченной клетки.";
        }

        public void ApplyArt(int i)
        {
            if (i < 0 || i >= S.artifacts.Count) return;
            var a = S.artifacts[i];
            var c = Cell(S.sel);
            if (!ArtValid(a, c)) return;
            var d = Defs.Arts[a.type];
            if (d.Stat != null)
            {
                if (d.Stat == "m") c.m += a.v; else if (d.Stat == "e") c.e += a.v; else c.f += a.v;
                Log($"{d.Name}: клетка получила +{a.v}% {d.Word}.", "good");
            }
            else if (a.type == "bulwark") { c.defMul = (c.defMul > 0 ? c.defMul : 1) * (1 + a.v / 100.0); Log($"{d.Name}: защита клетки +{a.v}%.", "good"); }
            else if (a.type == "bloom") { c.held += a.v * 60; Log($"{d.Name}: клетка получила {a.v} мин владения.", "good"); }
            else if (a.type == "frost") { c.dev = 1 + (c.dev - 1) * 0.5; Log($"{d.Name}: развитие клетки тьмы замедлено вдвое.", "good"); }
            else if (a.type == "tome") { S.op += a.v; Log($"{d.Name}: +{a.v} ОП.", "good"); }
            else if (a.type == "rune") { S.os += a.v; Log($"{d.Name}: +{a.v} ОС.", "good"); }
            else if (a.type == "glass") NewEra(false);
            else if (a.type == "core")
            {
                double was = CoreMul;
                S.cores.Add(a.v);
                Log($"{d.Name} ×{a.v}: базовая добыча искры навсегда выросла с ×{was} до ×{CoreMul} ({Fmt.X(0.5 * CoreMul)} за клетку).", "good");
            }
            else
            {
                double was = Math.Ceiling(c.might);
                c.might /= 2;
                Log($"{d.Name}: мощь клетки тьмы упала с {was} до {Math.Ceiling(c.might)}.", "good");
            }
            S.artifacts.RemoveAt(i);
        }

        static Artifact RollCore()
        {
            double q = Rand.Value;
            return new Artifact { type = "core", v = q < 0.5 ? 2 : q < 0.8 ? 3 : q < 0.95 ? 4 : 5 };
        }

        string ArtDrop(string tier)
        {
            string msg = "";
            if (Rand.Value < Defs.PulsarChance[tier] * EraV("drop")) { S.pulsars++; msg += " Выпал пульсар!"; }
            // ядро: гарантировано за легендарную, 5% за эпическую
            if (tier == "legend" || (tier == "epic" && Rand.Value < 0.05 * Aggr))
            {
                var c = RollCore();
                S.artifacts.Add(c);
                msg += $" Выпало «{ArtTitle(c)}»!";
            }
            if (Rand.Value >= Defs.ArtChance[tier] * Aggr * EraV("drop")) return msg;
            // Ядро выпадает реже остальных видов (за легендарную — чаще)
            var w = new Dictionary<string, double>
            {
                ["energy"] = 1, ["force"] = 1, ["matter"] = 1, ["clot"] = 0.8, ["core"] = tier == "legend" ? 1.5 : 0.35,
                ["bulwark"] = 0.8, ["bloom"] = 0.8, ["frost"] = 0.6, ["tome"] = 0.7, ["rune"] = 0.7, ["glass"] = 0.4,
            };
            double r = Rand.Value * w.Values.Sum();
            string type = "energy";
            foreach (var k in Defs.ArtOrder) { r -= w[k]; if (r < 0) { type = k; break; } }
            int R(int a1, int b1) => a1 + Rand.Int(b1 - a1 + 1);
            var art = new Artifact { type = type };
            if (Defs.Arts[type].Stat != null) art.v = 5 + Rand.Int(46);
            if (type == "core") art.v = RollCore().v;
            if (type == "bulwark") art.v = R(10, 40);
            if (type == "bloom") art.v = R(1, 8);
            if (type == "tome" || type == "rune") art.v = R(5, 25);
            S.artifacts.Add(art);
            return msg + $" Выпал артефакт: «{ArtTitle(art)}»!";
        }

        /* ---------- прыжок искры ---------- */
        // Прибавка к бонусу: 0,02 × рекорд клеток^1,5 × агрессивность^2,5
        public double RebirthGain => JsRound(0.02 * Math.Pow(S.worldMax, 1.5) * Math.Pow(Aggr, 2.5) * 100) / 100;

        public void Rebirth()
        {
            S.lastWorld = S.worldTime;
            S.bonus = JsRound((S.bonus + RebirthGain) * 100) / 100;
            S.rebirths++;
            // Персонаж, очки и способности начинаются заново; остаются бонус, скорость искры, ядра и артефакты
            S.chr = new CharStats();
            S.op = 0; S.os = 0; S.opB = 0; S.osB = 0;
            S.abilities = GameState.NewSlots();
            FreshWorld();
            GameOver = false;
            Log($"Искра совершила прыжок в новую область вселенной. Агрессивность: {AggrText}.", "good");
        }

        public static int KillPts(Kills k) => k.low + 3 * k.rare + 10 * k.epic + 500 * k.legend;
    }
}
