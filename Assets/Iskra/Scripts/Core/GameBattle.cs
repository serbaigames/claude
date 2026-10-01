// «Искра» — бой с сущностью тьмы: автоматическая атака, навыки, особенности врага, награды
using System;
using System.Collections.Generic;
using System.Linq;

namespace Iskra.Core
{
    public sealed class Foe
    {
        public string Name, Tier;
        public int Dist;
        public double MaxHp, Atk, Cd, Matter, Pen;
        public List<string> Traits = new List<string>();
        public double Hp, T, Wt;
        public int Hits;
    }

    // Визуальный эффект на арене; интерфейс рисует, ядро только сообщает
    public sealed class Vfx
    {
        public string Kind;       // bolt, beam, spiral, heal, flash, stun, num
        public char From = 'p', At = 'p';
        public string Col = "#ffffff", Txt;
        public double W = 1, Dur, T0;
    }

    public sealed class BattleChoice
    {
        public string Id, Tier;
        public bool Dup;
    }

    public sealed class Battle
    {
        public Foe Foe;
        public string CellKey, Defend;
        public double Hp, MaxHp, Cd;
        public int Last = -2, Combo;
        public double Shield, Immune, Haste, Dot, DotV, Mend, MendV, Weak, Refl, Dispel;
        public readonly double[] AbCd = new double[Defs.AbilitySlots];
        public bool Over, Started, NoAtk;
        public readonly List<string> LogLines = new List<string>();
        public BattleChoice Choice;
        public string ChArm;           // какой вариант выбора «взведён» (второе нажатие подтверждает)
        public string Status = "";
        public char DisWho;            // кто рассыпается после боя: 'p' / 'f'
        public double DisT0;
        public double ShP, ShF;        // до какого времени трясти искру / врага
        public readonly List<Vfx> Fx = new List<Vfx>();
    }

    public sealed partial class Game
    {
        public const int Attack = -1;
        public Battle B;

        public void StartBattle(Foe foe, string cellKey)
        {
            S.paused = true;   // при начале боя мир встаёт на паузу
            if (B != null) return;
            foe.Hp = foe.MaxHp; foe.T = 0;
            B = new Battle
            {
                Foe = foe, CellKey = cellKey, Hp = MaxHp(), MaxHp = MaxHp(),
                Status = "Осмотрите противника и нажмите «Начать бой». Каждый ход тратит свободную материю.",
            };
        }

        public struct ActInfo
        {
            public double Cost;
            public bool Ready, Valid;
        }

        static double ActCost(double b) => Math.Max(1, Math.Ceiling(b));

        public ActInfo ActionInfo(int act)
        {
            if (act == Attack) return new ActInfo { Cost = ActCost(4 * Med()), Ready = true, Valid = true };
            if (act < 0 || act >= S.abilities.Length || S.abilities[act].Empty) return new ActInfo();
            return new ActInfo { Cost = ActCost(AbCost(S.abilities[act])), Ready = B == null || B.AbCd[act] <= 0, Valid = true };
        }

        void BLog(string t)
        {
            B.LogLines.Insert(0, t);
            if (B.LogLines.Count > 300) B.LogLines.RemoveAt(B.LogLines.Count - 1);
        }

        // «Рассеивание» отключает особенности
        public bool Has(string tr) => B != null && !(B.Dispel > 0) && B.Foe.Traits != null && B.Foe.Traits.Contains(tr);
        public bool WardOn() => Has("ward") && (B.Foe.Wt % 10) >= 8;

        public void AddVfx(string kind, char side, string col, double w = 1, double dur = 0, string txt = null)
        {
            if (B == null) return;
            if (dur <= 0)
                dur = kind == "num" ? 0.9 : kind == "heal" ? 0.9 : kind == "spiral" ? 0.7 : kind == "stun" ? 0.8 : kind == "bolt" ? 0.32 : 0.4;
            B.Fx.Add(new Vfx { Kind = kind, From = side, At = side, Col = col, W = w, Dur = dur, Txt = txt, T0 = Now });
            if (B.Fx.Count > 60) B.Fx.RemoveAt(0);
        }

        double HitFoe(double d, bool pierce = false)
        {
            if (!pierce && WardOn())
            {
                AddVfx("flash", 'f', "#b89bff", 1, 0.4);
                AddVfx("num", 'f', "#b89bff", txt: "завеса");
                return 0;
            }
            if (!pierce && Has("shell") && B.Foe.Hp > B.Foe.MaxHp * 0.5) d *= 0.65;
            d = JsRound(d);
            B.Foe.Hp -= d;
            B.ShF = Now + 0.25;
            AddVfx("num", 'f', "#ffe3a3", txt: "−" + d);
            return d;
        }

        double HealMe(double h)
        {
            double before = B.Hp;
            B.Hp = Math.Min(B.MaxHp, B.Hp + h);
            double x = JsRound(B.Hp - before);
            if (x > 0)
            {
                AddVfx("heal", 'p', "#7be0a8");
                AddVfx("num", 'p', "#7be0a8", txt: "+" + x);
            }
            return x;
        }

        public void BattleBegin()
        {
            if (B == null || B.Started || B.Over) return;
            B.Started = true;
            B.Status = "Бой идёт! Каждый ход тратит свободную материю.";
            AddVfx("flash", 'p', "#fff3c4", 1, 0.35);
        }

        void AbilityFx(string kind, string col)
        {
            switch (kind)
            {
                case "dmg": AddVfx("bolt", 'p', col, 2.2); break;
                case "drain": AddVfx("beam", 'f', "#ff6b9a", 1, 0.55); break;
                case "absorb": AddVfx("spiral", 'f', col, 1, 0.8); break;
                case "heal": AddVfx("flash", 'p', "#7be0a8"); break;
                case "dot": AddVfx("bolt", 'p', "#ff9a3c", 1.4); break;
                case "pierce": AddVfx("beam", 'p', "#ffe08a", 1, 0.4); break;
                case "harvest": AddVfx("bolt", 'p', "#f2b441", 1.6); break;
                case "execute": AddVfx("bolt", 'p', "#ff4d6d", 2.6); break;
                case "stunfoe": AddVfx("stun", 'f', "#ffe08a"); AddVfx("flash", 'f', "#ffe08a"); break;
                case "weaken": AddVfx("flash", 'f', "#9b7bff"); break;
                case "dispel": AddVfx("flash", 'f', "#cfd6ff"); break;
                default: AddVfx("flash", 'p', col); break;
            }
        }

        public static readonly Dictionary<string, string> TierCol = new Dictionary<string, string>
            { ["low"] = "#a49dbd", ["rare"] = "#5fb2e6", ["epic"] = "#ef6b90", ["legend"] = "#ff8a3d" };

        public void DoAction(int act)
        {
            if (B == null || B.Over || !B.Started) return;
            if (act == Attack && B.Cd > 0) return;   // навыки ждут только свой откат
            var info = ActionInfo(act);
            if (!info.Valid || !info.Ready || S.matter < info.Cost) return;
            S.matter -= info.Cost;
            if (act == Attack)
            {
                AddVfx("bolt", 'p', "#ffd27a", 1);
                BLog($"Атака: {HitFoe(10 * Med() * PowMul() * Rand.Range(.9, 1.1))} урона (−{info.Cost} материи)");
            }
            else
            {
                var a = S.abilities[act];
                var d = Defs.Abilities[a.id];
                double v = AbVal(a), pm = PowMul();
                B.AbCd[act] = d.Cd;
                AbilityFx(d.Kind, TierCol[d.Tier]);
                switch (d.Kind)
                {
                    case "dmg": BLog($"{d.Name}: {HitFoe(v * pm * Rand.Range(.9, 1.1))} урона"); break;
                    case "heal": BLog($"{d.Name}: +{HealMe(v)} здоровья"); break;
                    case "shield": B.Shield = v; BLog($"{d.Name}: урон по вам снижен"); break;
                    case "drain": { double x = HitFoe(v * pm); BLog($"{d.Name}: {x} урона, +{HealMe(x * 0.6)} здоровья"); break; }
                    case "haste": B.Haste = v; BLog($"{d.Name}: ходы ускорены"); break;
                    case "immune": B.Immune = v; BLog($"{d.Name}: вы неуязвимы"); break;
                    case "absorb": { double x = HitFoe(B.Foe.MaxHp * v); BLog($"{d.Name}: {x} урона, +{HealMe(x * 0.5)} здоровья"); break; }
                    case "dot": B.Dot = Defs.DotT; B.DotV = v * pm; BLog($"{d.Name}: враг горит"); break;
                    case "stunfoe": B.Foe.T -= v; BLog($"{d.Name}: удар врага отброшен"); break;
                    case "regenme": B.Mend = Defs.MendT; B.MendV = v; BLog($"{d.Name}: здоровье восстанавливается"); break;
                    case "pierce": BLog($"{d.Name}: {HitFoe(v * pm * Rand.Range(.9, 1.1), true)} урона"); break;
                    case "weaken": B.Weak = v; BLog($"{d.Name}: враг ослаблен"); break;
                    case "harvest":
                    {
                        double x = HitFoe(v * pm * Rand.Range(.9, 1.1)), g = 0;
                        if (x > 0) { g = AbCost(a) * 2; S.matter += g; AddVfx("spiral", 'f', "#f2b441"); }
                        BLog($"{d.Name}: {x} урона{(g > 0 ? $", +{g} материи" : "")}");
                        break;
                    }
                    case "reflect": B.Refl = v; BLog($"{d.Name}: удары отражаются"); break;
                    case "execute":
                    {
                        bool low = B.Foe.Hp < B.Foe.MaxHp * 0.3;
                        BLog($"{d.Name}: {HitFoe(v * pm * Rand.Range(.9, 1.1) * (low ? 3 : 1))} урона{(low ? " — добивание!" : "")}");
                        break;
                    }
                    case "dispel": B.Dispel = v; BLog($"{d.Name}: особенности врага отключены"); break;
                }
            }
            if (B.Last == act) B.Combo++; else B.Combo = 0;
            B.Last = act;
            if (act == Attack) B.Cd = TurnCd() * (B.Haste > 0 ? 0.5 : 1);
            CheckEnd();
        }

        public double FullTurn => TurnCd() * (B != null && B.Haste > 0 ? 0.5 : 1);

        void BattleTick(double dt)
        {
            if (B == null || B.Over || !B.Started) return;
            B.Cd = Math.Max(0, B.Cd - dt);
            for (int i = 0; i < B.AbCd.Length; i++) B.AbCd[i] = Math.Max(0, B.AbCd[i] - dt);
            B.Shield = Math.Max(0, B.Shield - dt); B.Immune = Math.Max(0, B.Immune - dt); B.Haste = Math.Max(0, B.Haste - dt);
            B.Weak = Math.Max(0, B.Weak - dt); B.Refl = Math.Max(0, B.Refl - dt); B.Dispel = Math.Max(0, B.Dispel - dt);
            if (B.Dot > 0)
            {
                B.Dot -= dt;
                double x = B.DotV * dt;
                if (Has("shell") && B.Foe.Hp > B.Foe.MaxHp * 0.5) x *= 0.65;
                B.Foe.Hp -= x;
            }
            if (B.Mend > 0) { B.Mend -= dt; B.Hp = Math.Min(B.MaxHp, B.Hp + B.MendV * dt); }
            B.Foe.T += dt; B.Foe.Wt += dt;
            if (Has("regen") && B.Foe.Hp > 0) B.Foe.Hp = Math.Min(B.Foe.MaxHp, B.Foe.Hp + B.Foe.MaxHp * 0.015 * dt);
            double fcd = Has("rage") && B.Foe.Hp < B.Foe.MaxHp * 0.4 ? B.Foe.Cd / 1.6 : B.Foe.Cd;
            if (B.Foe.T >= fcd)
            {
                B.Foe.T = 0; B.Foe.Hits++;
                double d = B.Foe.Atk * Rand.Range(.85, 1.15) / DefDiv();
                AddVfx("bolt", 'f', TierCol.TryGetValue(B.Foe.Tier, out var tc) ? tc : "#ef6b90", 1.2);
                if (B.Immune > 0)
                {
                    BLog($"{B.Foe.Name} бьёт, но вы неуязвимы");
                    AddVfx("num", 'p', "#ffd27a", txt: "0");
                }
                else
                {
                    if (B.Shield > 0) d *= 0.5;
                    if (B.Weak > 0) d *= 0.6;
                    d = JsRound(d);
                    B.Hp -= d;
                    if (B.Refl > 0 && d > 0)
                    {
                        double r = JsRound(d * 0.6);
                        B.Foe.Hp -= r;
                        AddVfx("bolt", 'p', "#dfe8ff", 0.8);
                        AddVfx("num", 'f', "#dfe8ff", txt: "−" + r);
                        BLog($"Зеркало: {r} урона обратно");
                    }
                    BLog($"{B.Foe.Name} наносит {d} урона");
                    B.ShP = Now + 0.3;
                    AddVfx("num", 'p', "#ff8aa8", txt: "−" + d);
                    if (Has("leech"))
                    {
                        double l = Math.Min(Math.Max(0, S.matter), LeechAmt());
                        S.matter -= l;
                        if (l > 0) { BLog($"Иссушение: −{l} материи"); AddVfx("spiral", 'p', "#f2b441"); }
                    }
                    if (Has("stun") && B.Foe.Hits % 4 == 0)
                    {
                        B.Cd += 1;
                        BLog("Оглушение: ваш ход задержан");
                        AddVfx("stun", 'p', "#ffe08a");
                    }
                }
            }
            CheckEnd();
            // атака — автоматически, как только готов ход и хватает материи
            if (!B.Over && B.Cd <= 0)
            {
                var ai = ActionInfo(Attack);
                if (S.matter >= ai.Cost) DoAction(Attack);
                else if (!B.NoAtk) { B.NoAtk = true; BLog("Не хватает материи на атаку"); }
            }
        }

        void CheckEnd()
        {
            if (B.Over) return;
            if (B.Foe.Hp <= 0) Finish(true, false);
            else if (B.Hp <= 0) Finish(false, false);
        }

        void Finish(bool win, bool fled)
        {
            B.Over = true;
            if (!fled) { B.DisWho = win ? 'f' : 'p'; B.DisT0 = Now; }
            var f = B.Foe;
            string msg;
            if (win)
            {
                double gain = Math.Floor(f.Matter * 0.5);
                AddMatter(gain);
                S.kills[f.Tier]++;
                S.wk++;
                var c = Cell(B.CellKey);
                string capMsg = "";
                if (c != null && !c.own)
                {
                    c.alive = false;
                    double cost = Math.Ceiling(c.might);
                    if (S.matter >= cost) { Capture(B.CellKey); capMsg = $" Клетка захвачена за {cost} материи."; }
                    else capMsg = $" На захват не хватило материи: нужно {cost}.";
                }
                msg = $"Победа! +{gain} материи. {Drop(f.Tier)}{ArtDrop(f.Tier)}{capMsg}";
                Log(msg, "good");
            }
            else
            {
                double p = Math.Floor(f.Pen * 0.5);
                msg = (fled ? "Вы отступили. " : "Поражение. ") + PayPenalty(p);
                Log(msg, "bad");
            }
            if (B.Defend != null)
            {
                var n = Cell(B.Defend); var c = Cell(B.CellKey);
                if (win) { msg += " Клетка удержана."; Log("Клетка удержана!", "good"); }
                else if (n != null && n.own && c != null) { LoseCell(n, c); msg += " Клетка потеряна."; }
            }
            B.Status = msg;
        }

        // Победа даёт случайную способность ранга сущности (за легендарную — эпическую)
        string Drop(string tier)
        {
            string want = tier == "legend" ? "epic" : tier;
            var pool = Defs.AbilityList.Where(a => a.Tier == want).ToList();
            var id = pool[Rand.Int(pool.Count)].Id;
            bool owned = S.abilities.Any(a => a.id == id);
            int free = Array.FindIndex(S.abilities, a => a.Empty);
            var d = Defs.Abilities[id];
            if (!owned && free >= 0)
            {
                S.abilities[free] = new AbilitySlot { id = id, lvl = 1 };
                return $"Новая способность: «{d.Name}».";
            }
            if (!owned)
            {
                B.Choice = new BattleChoice { Id = id, Tier = tier };
                return $"Выпала способность «{d.Name}» — выберите для неё ячейку.";
            }
            B.Choice = new BattleChoice { Id = id, Tier = tier, Dup = true };
            return $"Выпала «{d.Name}», она у вас уже есть — повысить её уровень или взять ОС?";
        }

        // v: "skip", "up" или номер заменяемой ячейки
        public void ResolveChoice(string v)
        {
            var ch = B?.Choice;
            if (ch == null) return;
            B.Choice = null; B.ChArm = null;
            string msg = "";
            int os = Defs.Tiers[ch.Tier].Os;
            var d = Defs.Abilities[ch.Id];
            if (v == "skip")
            {
                S.os += os;
                msg = $"Способность не взята: +{os} ОС.";
            }
            else if (v == "up")
            {
                var a = S.abilities.FirstOrDefault(x => x.id == ch.Id);
                if (a != null) { a.lvl++; msg = $"«{d.Name}» повышена до ур. {a.lvl}."; }
            }
            else if (int.TryParse(v, out int i) && i >= 0 && i < S.abilities.Length)
            {
                var old = S.abilities[i];
                long refund = old.inv / 2;
                S.os += refund;
                S.abilities[i] = new AbilitySlot { id = ch.Id, lvl = 1 };
                string oldName = old.Empty ? "пусто" : Defs.Abilities[old.id].Name;
                msg = $"«{d.Name}» заняла место «{oldName}»{(refund > 0 ? $", вернулось {refund} ОС" : "")}.";
            }
            B.Status += " " + msg;
            Log(msg, "info");
        }

        // Двойное нажатие: первое «взводит» вариант, второе подтверждает
        public void ChoiceClick(string v)
        {
            if (B == null || B.Choice == null) return;
            if (B.ChArm == v) ResolveChoice(v);
            else B.ChArm = v;
        }

        string PayPenalty(double p)
        {
            double rest = p;
            var parts = new List<string>();
            double fromM = Math.Min(Math.Max(S.matter, 0), rest);
            S.matter -= fromM; rest -= fromM;
            if (fromM > 0) parts.Add($"{Math.Floor(fromM)} материи");
            if (rest > 0 && S.os > 0)
            {
                long use = Math.Min((long)Math.Ceiling(rest / 5), S.os);
                S.os -= use; rest -= use * 5;
                parts.Add($"{use} ОС");
            }
            if (rest > 0) { S.matter -= rest; parts.Add($"не хватило {Math.Ceiling(rest)} материи"); }
            return $"Штраф {p}: {(parts.Count > 0 ? string.Join(", ", parts) : "нечего отдавать")}.";
        }

        // Закрыть окно боя: до старта — просто отказ без штрафа; во время боя — отступление
        public void CloseBattle()
        {
            if (B == null) return;
            if (!B.Started && !B.Over) { B = null; return; }
            if (!B.Over) { Finish(false, true); return; }
            if (B.Choice != null) ResolveChoice("skip");
            B = null;
        }

        public void Fight(string k)
        {
            var c = Cell(k);
            if (c != null && c.alive && !c.own) StartBattle(FoeFromCell(c), k);
        }
    }
}
