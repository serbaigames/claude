// «Искра» — содержимое меню: клетка, персонаж, способности, технологии, артефакты, эры, профиль;
// панель действий над полем.
using System;
using System.Collections.Generic;
using System.Linq;
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed partial class IskraUI
    {
        static readonly string[] StatName = { "Материя", "Энергия", "Сила" };
        static readonly char[] StatKey = { 'm', 'e', 'f' };
        static readonly string[] StatCol = { "#f2b441", "#5fb2e6", "#ef6b90" };

        static string Pct(double v) => Game.JsRound(v) + "%";

        /* ---------- панель действий над полем ---------- */
        void RenderActbar(bool force)
        {
            uiAct.Reset();
            var items = new List<VisualElement>();
            var c = g.Sel;
            var u = uiAct;
            if (c != null && !c.own)
            {
                if (c.alive)
                {
                    var fc = g.FightForecast(c);
                    var (lab, cls) = Game.ForecastLabel(fc.P);
                    var (mt, mcls) = g.ForecastMatter(fc);
                    items.Add(u.Btn("Атаковать", "fight:" + c.Key, "actbtn", false, u.I("sword")));
                    items.Add(u.El("fc", u.L(lab, "fc-main " + cls), u.L(mt, "fc-sub " + mcls)));
                    items.Add(u.Btn(null, "open:main", "actmini", false, u.I("more")));
                }
                else
                {
                    double cost = Math.Ceiling(c.might);
                    bool lack = g.S.matter < cost;
                    items.Add(u.Btn($"Захватить за {Fmt.N(cost)}", "cap:" + c.Key, "actbtn", lack));
                    items.Add(u.El("fc", u.L(lack ? "нужно ещё " + Fmt.N(Math.Ceiling(cost - g.S.matter)) : "хватает", "fc-main " + (lack ? "bad" : "good")), u.L("защитник побеждён", "fc-sub")));
                    items.Add(u.Btn(null, "open:main", "actmini", false, u.I("more")));
                }
            }
            else if (c != null && c.spark)
            {
                items.Add(u.Btn("Искра", "open:main", "actbtn", false, u.I("spark")));
                items.Add(u.El("fc", u.L($"+{Fmt.N1(g.IncomeParts().Base)}/с", "fc-main good"), u.L($"ядро ×{g.CoreMul}", "fc-sub")));
            }
            else if (c != null)
            {
                double def = g.CellDef(c), th = g.MaxAdjMight(c), dc = g.DefCostOf(c);
                bool danger = th >= def * 0.8;
                int free = Game.Cap(c) - Game.UsedCap(c);
                items.Add(u.Btn("Управление клеткой", "open:main", "actbtn"));
                var row = u.El("row", u.I("shield"), u.L(Fmt.N(Math.Floor(def)), "fc-main " + (danger ? "bad" : "good")), u.L(danger ? "  угроза" : "  защищена", "fc-sub"));
                items.Add(u.El("fc", row, u.L((th > 0 ? $"сосед {Fmt.N(Math.Ceiling(th))} · " : "") + $"ячеек {free}", "fc-sub")));
                items.Add(u.Btn(null, "fort:" + c.Key, "actmini", g.S.matter < dc, u.I("shield"), u.L("+" + Fmt.N(dc))));
            }
            string sig = uiAct.Sig.ToString();
            if (!force && sig == lastAct) return;
            lastAct = sig;
            actbar.Clear();
            foreach (var e in items) actbar.Add(e);
            actbar.EnableInClassList("hidden", items.Count == 0);
        }

        /* ---------- вкладка «Клетка» ---------- */
        List<VisualElement> QuickMain()
        {
            var c = g.Sel;
            if (c == null || c.spark) return OverviewQuick(c != null && c.spark);
            return c.own ? OwnQuick(c) : DarkQuick(c);
        }

        CellPreview Preview(Cell c)
        {
            ui.Sig.Append("pv").Append(c.Key);
            return new CellPreview { G = g, Key = c.Key };
        }

        List<VisualElement> OwnQuick(Cell c)
        {
            string k = c.Key;
            double def = g.CellDef(c), th = g.MaxAdjMight(c), gain = g.FortGain(c), dc = g.DefCostOf(c);
            bool danger = th >= def * 0.8;
            int used = Game.UsedCap(c), cp = Game.Cap(c);
            bool full = used >= cp;
            var side = ui.El("cellside");
            var dg = ui.Q("shield", Fmt.N(Math.Floor(def)), null, "wide" + (danger ? " warnq" : ""));
            dg.Add(ui.L(th > 0 ? $"сосед {Fmt.N(Math.Ceiling(th))} · {Game.JsRound(th / def * 100)}%" : "сосед нет", "qe" + (danger ? " bad" : "")));
            dg.Add(ui.L($"укрепл. {c.defLvl} ур. · башни +{Game.TowerPct(c.tower)}%", "qe"));
            dg.Add(ui.L($"ячеек: свободно {cp - used}, занято {used} · новая через {Fmt.Clock(Game.NextSlotIn(c))}", "qe"));
            var row = ui.El("qb");
            row.Add(ui.Btn($"Укрепить +{Fmt.N1(gain)} · {Fmt.N(dc)}", "fort:" + k, "qup grow" + (danger ? " primary" : ""), g.S.matter < dc));
            dg.Add(row);
            side.Add(dg);
            for (int i = 0; i < 3; i++)
            {
                string t = Defs.Buildings[i];
                int L = Game.BL(c, t);
                double cost = g.BldCost(c, t);
                string nowTxt = t == "mine" ? $"+{Fmt.N1(g.MineRate(c, L))}/с" : t == "factory" ? $"+{Fmt.N1(g.FactPct(c, L))}%" : $"+{Game.TowerPct(L)}% защ.";
                string syn = L > 1 && t != "tower" ? $" · комплекс +{(L - 1) * 10}%" : "";
                var card = ui.El("qg qbld");
                var head = ui.El("qh");
                var dot = ui.El("spk");
                dot.style.backgroundColor = Draw.Hex(CellArt.SlotCol[i]);
                head.Add(dot);
                head.Add(ui.L(L.ToString()));
                head.Add(ui.L(Defs.BuildingShort[t], "qh-small"));
                card.Add(head);
                card.Add(ui.L(L > 0 ? nowTxt + syn : "не построено", "qe"));
                var br = ui.El("qb");
                br.Add(ui.Btn("+" + Fmt.N(cost), $"build:{k}:{t}", "qup grow", full || g.S.matter < cost));
                if (L > 0)
                {
                    bool arm = Armed($"lower:{k}:{t}");
                    br.Add(ui.Btn(arm ? "?" : "−", $"lower:{k}:{t}", "qdn" + (arm ? " armed" : "")));
                }
                card.Add(br);
                side.Add(card);
            }
            return new List<VisualElement> { ui.El("cellwin", Preview(c), side) };
        }

        List<VisualElement> DarkQuick(Cell c)
        {
            var side = ui.El("cellside");
            double rate = g.GrowRate(c), step = c.growth / rate, left = Math.Max(0, (c.growth - c.t) / rate), gm = g.GrowMul(c);
            string tm = g.Paused ? "пауза" : $"через {Game.JsRound(left)} с";
            var mightG = ui.Q("might", Fmt.N(Math.Ceiling(c.might)), $"затем {Fmt.N(Math.Ceiling(c.might * c.dev + 0.2))} {tm}");
            var growG = ui.Q("timer", Fmt.X(step), $"×{Fmt.X(1 + (c.dev - 1) * g.DarkF, 3)} за шаг{(gm > 1 ? " · ×2" : "")}", null, "с");
            if (c.alive)
            {
                var f = g.FoeFromCell(c);
                double rw = Math.Floor(f.Matter * 0.5), pn = Math.Floor(f.Pen * 0.5), hit = f.Atk / g.DefDiv();
                double art = Math.Min(100, Defs.ArtChance[c.tier] * g.Aggr * 100), core = c.tier == "legend" ? 100 : c.tier == "epic" ? Math.Min(100, 5 * g.Aggr) : 0;
                side.Add(ui.Q("heart", Fmt.N(Game.JsRound(f.MaxHp)), "здоровье"));
                side.Add(ui.Q("sword", Fmt.N(Game.JsRound(hit)), $"раз в {Fmt.X(f.Cd)} с · {Fmt.N(Game.JsRound(hit / f.Cd))}/с", hit * 6 > g.MaxHp() ? "warnq" : null));
                side.Add(mightG);
                side.Add(growG);
                side.Add(ui.Q("matter", "+" + Fmt.N(rw), $"штраф −{Fmt.N(pn)}"));
                side.Add(ui.Q("artifact", Fmt.X(art) + "%", core > 0 ? $"ядро {Fmt.X(core, 0)}%" : "артефакт"));
                if (f.Traits.Count > 0)
                {
                    var tg = ui.El("qg wide");
                    var h = ui.El("qh");
                    foreach (var k in f.Traits) h.Add(ui.I(Defs.Traits[k].Icon));
                    tg.Add(h);
                    tg.Add(ui.L(string.Join(", ", f.Traits.Select(k => Defs.Traits[k].Name)), "qe"));
                    foreach (var k in f.Traits) tg.Add(ui.L($"{Defs.Traits[k].Name}: {Defs.Traits[k].Desc}", "qe"));
                    side.Add(tg);
                }
                else side.Add(ui.Q(null, "·", "без особенностей"));
            }
            else
            {
                double cost = Math.Ceiling(c.might);
                bool lack = g.S.matter < cost;
                side.Add(mightG);
                side.Add(growG);
                side.Add(ui.Q("matter", Fmt.N(cost), lack ? "нужно ещё " + Fmt.N(Math.Ceiling(cost - g.S.matter)) : "цена захвата", lack ? "warnq" : null));
            }
            return new List<VisualElement> { ui.El("cellwin", Preview(c), side) };
        }

        List<VisualElement> OverviewQuick(bool spark)
        {
            var x = g.IncomeParts();
            int thr = g.ThreatCount;
            return new List<VisualElement>
            {
                spark ? ui.Q("spark", "Искра", $"ядро ×{g.CoreMul} · {Fmt.N1(x.Base)}/с", "wide") : ui.Q("target", "Клетка", "нажмите на карте", "wide"),
                ui.Q("cells", g.Own.Count.ToString(), "клеток"),
                ui.Q("stun", thr.ToString(), "под угрозой", thr > 0 ? "warnq" : null),
                ui.Q("matter", Fmt.N1(x.Mines * g.BonusMul), "шахты/с"),
                ui.Q("core", "+" + Fmt.N1(x.Fac) + "%", "заводы"),
                ui.Q("comet", "×" + Fmt.X2(g.Aggr), Game.AggrName(g.Aggr)),
            };
        }

        VisualElement Bars(Cell c)
        {
            bool own = c.own && !c.spark;
            string[] what = own ? new[] { "выработка шахт", "сила заводов", "прибавка укреплений" } : new[] { "материя клетки", "энергия клетки", "сила клетки" };
            var box = ui.El("stats3");
            for (int i = 0; i < 3; i++)
            {
                double v = g.St(c, StatKey[i]), m = Game.Mult(v);
                var r = ui.El("srow");
                r.Add(ui.L(StatName[i], "n"));
                r.Add(ui.Track((float)Math.Min(100, v), StatCol[i]));
                r.Add(ui.L(Pct(v), "v"));
                r.Add(ui.L("×" + Fmt.X2(m), "m"));
                box.Add(r);
            }
            box.Add(ui.L($"Множитель — {what[0]}, {what[1]}, {what[2]}.", "qe"));
            return box;
        }

        void Overview(List<VisualElement> b)
        {
            int thr = g.ThreatCount;
            var x = g.IncomeParts();
            b.Add(ui.H2("Владения"));
            b.Add(ui.Kv(
                Ui.R("Агрессивность мира", g.AggrText),
                Ui.R("База искры", Fmt.N1(x.Base) + "/с"),
                Ui.R("Шахты", Fmt.N1(x.Mines * g.BonusMul) + "/с"),
                Ui.R("Заводы ко всей добыче", "+" + Fmt.N1(x.Fac) + "%"),
                Ui.R("Под угрозой", thr.ToString(), thr > 0 ? "bad" : null)));
            if (thr > 0) b.Add(ui.L("Клетки с красной рамкой может забрать тьма.", "note bad"));
            else if (g.Own.Count == 1 && g.S.lostOnce) b.Add(ui.L("Соседей не одолеть? Совершите прыжок — кнопка справа вверху.", "note"));
        }

        VisualElement GrowKv(Cell c)
        {
            double left = Math.Max(0, (c.growth - c.t) / g.GrowRate(c));
            int lv = Game.CellLvl(c);
            return ui.Kv(
                Ui.R("Мощь", Math.Ceiling(c.might).ToString("0")),
                Ui.R("После шага", "~" + Math.Ceiling(c.might * (1 + (c.dev - 1) * g.DarkF) + 0.2).ToString("0")),
                Ui.R("До шага", g.Paused ? "пауза" : Game.JsRound(left) + " с"),
                Ui.R("Уровень клетки", $"{lv} (+{lv * 10}%)"),
                Ui.R($"До уровня {lv + 1}", Fmt.Clock(60 * Math.Pow(2, lv) - Game.CellAge(c))));
        }

        void ColsMain(List<VisualElement> a, List<VisualElement> b)
        {
            var c = g.Sel;
            if (c == null)
            {
                a.Add(ui.H2("Клетка не выбрана"));
                a.Add(ui.P("Нажмите на клетку на карте: золотые — ваши, фиолетовые — тьма.", "muted"));
                Overview(b);
                return;
            }
            if (c.spark)
            {
                a.Add(ui.H2("Искра"));
                int n = g.S.cores.Count;
                a.Add(ui.Kv(
                    Ui.R("Клетки × бонус", Fmt.N1(g.SparkMatter)),
                    Ui.R("Ядра искры" + (n > 0 ? $" ({n})" : ""), $"×{g.CoreMul} ({Fmt.X(0.5 * g.CoreMul)} за клетку)"),
                    Ui.R("Скорость", "×" + Fmt.X2(g.SparkSpeed)),
                    Ui.R("Даёт", Fmt.N1(g.IncomeParts().Base) + "/с")));
                a.Add(ui.L("Добыча базы = 0,5 × ядро × клетки × бонус × скорость", "qe"));
                Overview(b);
                return;
            }
            if (c.own)
            {
                double def = g.CellDef(c), th = g.MaxAdjMight(c);
                a.Add(ui.H2("Ваша клетка"));
                a.Add(Bars(c));
                if (th >= def * 0.8) a.Add(ui.L("Сосед почти сравнялся с защитой.", "note bad"));
                int lv = Game.CellLvl(c);
                double held = c.held, nx = Game.NextLvlAt(c), from = lv > 0 ? nx / 2 : 0;
                b.Add(ui.H2("Рост клетки"));
                b.Add(ui.Kv(Ui.R("Во владении", Fmt.Clock(held)), Ui.R("Уровень", $"{lv} (+{lv * 10}%)"), Ui.R($"До уровня {lv + 1}", Fmt.Clock(nx - held))));
                b.Add(ui.Track((float)Math.Min(100, (held - from) / (nx - from) * 100), null, "prog", "prog-fill"));
                b.Add(ui.L("Материя, энергия и сила клетки растут на 10% через 1, 2, 4, 8… минут владения. При потере клетки рост сбрасывается.", "qe"));
                return;
            }
            a.Add(ui.H2("Клетка тьмы"));
            a.Add(Bars(c));
            if (c.alive)
            {
                var f = g.FoeFromCell(c);
                b.Add(ui.H2(f.Name));
                var tr = ui.El("row", ui.Tier(c.tier, Defs.Tiers[c.tier].Name.ToLower()));
                if (c.tier == "epic") tr.Add(ui.L("  очень опасна", "pen"));
                if (c.tier == "legend") tr.Add(ui.L("  смертельно опасна, соседи растут ×2", "pen"));
                b.Add(tr);
                b.Add(ui.Kv(Ui.R("Удалённость от искры", $"{f.Dist} (×{f.Dist})"), Ui.R("Агрессивность мира", "×" + Fmt.X2(g.Aggr))));
            }
            else
            {
                b.Add(ui.H2("Защитник побеждён"));
                b.Add(ui.P("Клетку можно взять за материю, равную мощи.", "muted"));
            }
            b.Add(GrowKv(c));
        }

        /* ---------- персонаж ---------- */
        List<VisualElement> QuickChar()
        {
            var ob = g.OpBuyInfo();
            var row = ui.El("oprow");
            row.Add(ui.I("spark"));
            row.Add(ui.L(g.S.op.ToString(), "b"));
            row.Add(ui.L("ОП"));
            row.Add(ui.L("· купить", "muted"));
            row.Add(ui.Btn(Game.MultLabel(g.M["opBuy"]), "mcyc:opBuy", "qup qcyc"));
            row.Add(ui.Btn("+" + ob.N, "op", "qup primary", ob.N < 1 || g.S.matter < ob.Cost));
            row.Add(ui.L(Fmt.N(ob.Cost) + " мат.", "muted small"));
            row.Add(ui.L("· уровней за раз", "muted"));
            row.Add(ui.Btn(Game.MultLabel(g.M["par"]), "mcyc:par", "qup qcyc"));

            var radar = ui.El("radar");
            radar.Add(new RadarChart { G = g });
            ui.Sig.Append("radar").Append(g.S.chr.Sum);
            for (int i = 0; i < Defs.Params.Length; i++)
            {
                var pd = Defs.Params[i];
                float an = (-90 + 60 * i) * Mathf.Deg2Rad;
                var e = g.EffOf(pd.Id);
                var pi = g.ParInfo(pd.Id);
                var lab = ui.El("rlab");
                lab.style.left = Length.Percent(50 + 40 * Mathf.Cos(an));
                lab.style.top = Length.Percent(50 + 41 * Mathf.Sin(an));
                var nm = ui.L(pd.Name);
                nm.style.color = Draw.Hex(RadarChart.ParamCol[i]);
                lab.Add(nm);
                lab.Add(ui.L(g.S.chr[pd.Id] + (e.Pen > 0 ? $"  −{Game.JsRound(e.Pen * 100)}%" : ""), "rlv" + (e.Pen > 0 ? " pen" : "")));
                lab.Add(ui.Btn("+" + pi.N, "par:" + pd.Id, "qup", pi.N < 1 || g.S.op < pi.Cost));
                lab.Add(ui.L(Fmt.N(pi.Cost) + " ОП", "muted"));
                radar.Add(lab);
            }
            var note = ui.L("Пунктир — общие пороги штрафа: параметр выше 2×, 3×, 4× среднего теряет 10%, 20%, 30% силы.", "qe");
            return new List<VisualElement> { row, radar, note };
        }

        void ColsChar(List<VisualElement> a, List<VisualElement> b)
        {
            a.Add(ui.H2("Параметры"));
            foreach (var pd in Defs.Params)
            {
                var e = g.EffOf(pd.Id);
                var it = ui.El("list-item");
                it.Add(ui.L($"{pd.Name} {g.S.chr[pd.Id]}", "b"));
                it.Add(ui.L(pd.Short + (e.Pen > 0 ? $" · штраф −{Game.JsRound(e.Pen * 100)}%" : ""), "sub"));
                a.Add(it);
            }
            a.Add(ui.L("Если один параметр вдвое выше среднего по остальным, он теряет 10% силы, втрое — 20%, и так далее.", "qe"));
            b.Add(ui.H2("В бою"));
            b.Add(ui.Kv(
                Ui.R("Здоровье", Fmt.N(Game.JsRound(g.MaxHp()))),
                Ui.R("Урон по вам делится на", Fmt.X2(g.DefDiv())),
                Ui.R("Множитель атаки", "×" + Fmt.X2(g.PowMul())),
                Ui.R("Материи за ход", Math.Ceiling(4 * g.Med()).ToString("0")),
                Ui.R("Урон атаки", "~" + Game.JsRound(10 * g.Med() * g.PowMul())),
                Ui.R("Откат хода", Fmt.X2(g.TurnCd()) + " с"),
                Ui.R("Клетки: защ., мат., эн.", "×" + Fmt.X(g.CtrlMul(), 4))));
        }

        /* ---------- способности ---------- */
        List<VisualElement> QuickAbil()
        {
            var ob = g.OsBuyInfo();
            var side = ui.Q("artifact", g.S.os.ToString(), $"купить: {Fmt.N(ob.Cost)} материи", "wide", "ОС",
                ui.Btn(Game.MultLabel(g.M["osBuy"]), "mcyc:osBuy", "qup qcyc"),
                ui.Btn("+" + ob.N, "os", "qup primary grow", ob.N < 1 || g.S.matter < ob.Cost));
            side.Add(ui.L("уровней за раз", "qe"));
            var r2 = ui.El("qb");
            r2.Add(ui.Btn(Game.MultLabel(g.M["ab"]), "mcyc:ab", "qup qcyc"));
            side.Add(r2);
            var list = new List<VisualElement> { side };
            for (int i = 0; i < g.S.abilities.Length; i++)
            {
                var a = g.S.abilities[i];
                if (a.Empty)
                {
                    var e = ui.El("ab-row empty");
                    e.Add(ui.I("target"));
                    e.Add(ui.El("ab-text", ui.L($"Ячейка {i + 1} пуста", "muted"), ui.L("способность выпадет в бою", "qe")));
                    list.Add(e);
                    continue;
                }
                var d = Defs.Abilities[a.id];
                var up = g.AbInfo(i);
                var row = ui.El("ab-row");
                var col = Draw.Hex(Game.TierCol[d.Tier]);
                row.style.borderLeftColor = col;
                var ic = ui.I(d.Icon);
                ic.style.color = col;
                row.Add(ic);
                row.Add(ui.El("ab-text",
                    ui.El("row", ui.L(d.Name, "b"), ui.L($"  ур. {a.lvl}", "muted")),
                    ui.L($"{g.AbDesc(a)} · {Game.AbCost(a)} мат. за применение, откат {Fmt.X(d.Cd)} с · {Fmt.N(up.Cost)} ОС", "qe")));
                row.Add(ui.Btn("+" + up.N, "abup:" + i, "qup", up.N < 1 || g.S.os < up.Cost));
                list.Add(row);
            }
            return list;
        }

        void ColsAbil(List<VisualElement> a, List<VisualElement> b)
        {
            a.Add(ui.H2("Ячейки"));
            for (int i = 0; i < g.S.abilities.Length; i++)
            {
                var s = g.S.abilities[i];
                var it = ui.El("list-item");
                if (s.Empty)
                {
                    it.Add(ui.L($"{i + 1}. пусто", "muted"));
                    it.Add(ui.L("способность выпадет в бою", "sub"));
                }
                else
                {
                    var d = Defs.Abilities[s.id];
                    it.Add(ui.El("row", ui.L($"{i + 1}. {d.Name}", "b"), ui.Tier(d.Tier, "ур. " + s.lvl)));
                    it.Add(ui.L($"{g.AbDesc(s)}; {Game.AbCost(s)} мат. за применение, откат {Fmt.X(d.Cd)} с", "sub"));
                }
                a.Add(it);
            }
            a.Add(ui.L("Победа над сущностью даёт случайную способность её ранга; если ячейки заняты — можно заменить одну или взять очки способностей.", "qe"));
            b.Add(ui.H2("Очки способностей"));
            b.Add(ui.Kv(Ui.R("Есть ОС", g.S.os.ToString()), Ui.R("Следующее ОС", Fmt.N(g.OsBuyInfo().Next) + " материи"),
                Ui.R("Ячеек", $"{g.S.abilities.Count(x => !x.Empty)} из {g.S.abilities.Length}")));
            b.Add(ui.P("Уровень стоит столько ОС, сколько уже набрано уровней, × ранг: низшая 1, редкая 3, эпическая 10.", "muted small"));
        }

        /* ---------- технологии ---------- */
        List<VisualElement> QuickTech()
        {
            var tree = ui.El("ttree");
            tree.Add(ui.El("row", ui.I("pulsar"), ui.L(" " + g.S.pulsars, "b"), ui.L(" пульсаров")));
            foreach (int lvl in new[] { 1, 2 })
            {
                tree.Add(ui.L($"Уровень {lvl}", "muted small"));
                var row = ui.El("tlvl");
                foreach (var t in Defs.Tech.Where(x => x.Lvl == lvl))
                {
                    bool done = g.HasTech(t.Id), open = g.TechOpen(t), can = !t.Soon && !done && open && g.S.pulsars >= t.Cost;
                    string st = done ? "done" : t.Soon ? "soon" : open ? "open" : "locked";
                    var n = ui.El("tnode " + st, ui.I(t.Soon ? "target" : t.Icon), ui.L(t.Name, "b"), ui.L(t.Desc, "qe"));
                    if (done) n.Add(ui.L("изучено", "good"));
                    else if (t.Soon) n.Add(ui.L("скоро", "muted"));
                    else if (!open) n.Add(ui.L("закрыто", "muted"));
                    else n.Add(ui.Btn($"Изучить · {t.Cost} пульсар", "tech:" + t.Id, "qup primary", !can));
                    row.Add(n);
                }
                tree.Add(row);
            }
            return new List<VisualElement> { tree };
        }

        void ColsTech(List<VisualElement> a, List<VisualElement> b)
        {
            a.Add(ui.H2("Пульсары"));
            a.Add(ui.P("Пульсары — редкая валюта для изучения технологий. Новая игра начинается с одного пульсара. Ещё пульсары изредка выпадают после побед над сущностями: 0,5% за низшую, 1,5% за редкую, 4% за эпическую, 25% за легендарную (эра «Звездопад» увеличивает шанс).", "muted"));
            b.Add(ui.H2("Дерево технологий"));
            b.Add(ui.P("Изученные технологии и пульсары сохраняются при прыжке. «Прыжок» открывает второй уровень дерева — его технологии появятся в следующих версиях.", "muted"));
        }

        /* ---------- артефакты ---------- */
        List<VisualElement> QuickArt()
        {
            var c = g.Cell(g.S.sel);
            int n = g.S.artifacts.Count, slots = (n / 6 + 1) * 6;
            var box = ui.El("aslots");
            for (int i = 0; i < slots; i++)
            {
                if (i >= n) { box.Add(ui.El("aslot empty")); continue; }
                var a = g.S.artifacts[i];
                var d = Defs.Arts[a.type];
                var ic = ui.I(d.Icon);
                ic.style.color = Draw.Hex(ArtCol[a.type]);
                box.Add(ui.Btn(null, "art:" + i, "aslot", !g.ArtValid(a, c), ic, ui.L(Game.ArtBadge(a))));
            }
            var list = new List<VisualElement> { box };
            if (n > 0)
            {
                // описание первого подходящего артефакта, чтобы было понятно, что произойдёт
                int k = g.S.artifacts.FindIndex(a => g.ArtValid(a, c));
                if (k >= 0) list.Add(ui.L($"Нажмите, чтобы применить. Например: {Game.ArtTitle(g.S.artifacts[k])} — {g.ArtDesc(g.S.artifacts[k])}", "qe"));
                else list.Add(ui.L("Выберите на карте подходящую клетку: подсвеченные артефакты можно применить.", "qe"));
            }
            return list;
        }

        static readonly Dictionary<string, string> ArtCol = new Dictionary<string, string>
        {
            ["energy"] = "#5fb2e6", ["force"] = "#ef6b90", ["matter"] = "#f2b441", ["clot"] = "#a88be0", ["core"] = "#ff8a3d", ["bulwark"] = "#9fd3ff",
            ["bloom"] = "#7be0a8", ["frost"] = "#c7d6ff", ["tome"] = "#ffd27a", ["rune"] = "#d89bff", ["glass"] = "#ffe8b0",
        };

        string ArtTarget()
        {
            var c = g.Sel;
            if (c == null) return "ничего";
            return c.spark ? "искра" : c.own ? "ваша клетка" : c.alive ? $"тьма, мощь {Math.Ceiling(c.might)}" : $"свободная, мощь {Math.Ceiling(c.might)}";
        }

        void ColsArt(List<VisualElement> a, List<VisualElement> b)
        {
            var c = g.Sel;
            string fit = (c == null ? "для клеток выберите клетку на карте" : c.spark ? $"ядро искры (сейчас ×{g.CoreMul})" : c.own ? "кристаллы, осколки, зёрна, бастион, семя роста" : "сгусток, иней")
                + "; свиток, руна и часы — в любой момент";
            int n = g.S.artifacts.Count, slots = (n / 6 + 1) * 6;
            a.Add(ui.H2("Применение"));
            a.Add(ui.Kv(Ui.R("Выбрано", ArtTarget()), Ui.R("Занято ячеек", $"{n} из {slots}")));
            a.Add(ui.P("Подходят: " + fit));
            a.Add(ui.P("Нажмите на артефакт в ячейке сверху, чтобы применить его. Когда все ячейки заполнены, появляется новый ряд.", "muted small"));
            b.Add(ui.H2("Виды"));
            foreach (var k in Defs.ArtOrder)
            {
                var ic = ui.I(Defs.Arts[k].Icon);
                ic.style.color = Draw.Hex(ArtCol[k]);
                b.Add(ui.El("eli", ic, ui.El("eli-text", ui.L(Defs.Arts[k].Name, "b"), ui.L(Defs.ArtShort[k], "qe"))));
            }
            b.Add(ui.P("Шанс артефакта за победу: 4% / 12% / 25% / 100% по рангу сущности, умноженный на агрессивность мира и эру.", "muted small"));
        }

        /* ---------- эры ---------- */
        List<VisualElement> QuickEra()
        {
            var e = g.EraNow;
            int l = (int)Math.Ceiling(g.S.era.left);
            return new List<VisualElement>
            {
                ui.Q(e.Icon, e.Name, $"{e.Desc} · осталось {l / 60}:{l % 60:00} из {Game.JsRound(g.S.era.dur / 60)} мин", "wide era-" + e.Kind),
                ui.Q("timer", "1–10 мин", "длительность эры; следующая — случайная", "wide"),
            };
        }

        void EraList(List<VisualElement> to, int from, int count)
        {
            for (int i = from; i < from + count && i < Defs.Eras.Length; i++)
            {
                var e = Defs.Eras[i];
                bool cur = g.S.era.i == i;
                to.Add(ui.El("eli " + e.Kind + (cur ? " now" : ""), ui.I(e.Icon), ui.El("eli-text",
                    ui.El("row", ui.L(e.Name, "b"), cur ? ui.L("  сейчас", "good small") : null), ui.L(e.Desc, "qe"))));
            }
        }

        void ColsEra(List<VisualElement> a, List<VisualElement> b)
        {
            a.Add(ui.H2("Эры 1–12"));
            EraList(a, 0, 12);
            b.Add(ui.H2("Эры 13–24"));
            EraList(b, 12, 12);
            b.Add(ui.P("Эра длится от 1 до 10 минут игрового времени (на паузе не идёт). Зелёные помогают вам, красные — тьме, золотые — смешанные.", "muted small"));
        }

        /* ---------- профиль ---------- */
        List<VisualElement> QuickStats()
        {
            bool aw = Armed("wipe");
            return new List<VisualElement>
            {
                ui.Q("erase", "Сброс", "всё с нуля: мир, персонаж, бонусы", "wide", null,
                    ui.Btn(aw ? "Точно? Нажмите ещё раз" : "Стереть", "wipe", "qup grow" + (aw ? " danger" : ""))),
            };
        }

        void ColsStats(List<VisualElement> a, List<VisualElement> b)
        {
            var s = g.S;
            a.Add(ui.H2("Профиль"));
            a.Add(ui.Kv(
                Ui.R("Прогресс хранится", "на этом устройстве"),
                Ui.R("В этом мире", Fmt.Time(s.worldTime)),
                Ui.R("В прошлом мире", s.lastWorld > 0 ? Fmt.Time(s.lastWorld) : "—"),
                Ui.R("Заработано материи", Fmt.N(s.earned)),
                Ui.R("Прыжков", s.rebirths.ToString()),
                Ui.R("Рекорд клеток", s.bestCells.ToString()),
                Ui.R("Агрессивность мира", g.AggrText)));
            a.Add(ui.L($"Сила сущностей и скорость роста тьмы ×{Fmt.X2(g.Aggr)}, шанс легендарной {Fmt.X(g.LegendChance * 100)}%.", "qe"));
            var k = s.kills;
            b.Add(ui.H2("Побеждено"));
            b.Add(ui.Kv(Ui.R("Низших · редких · эпических · легендарных", $"{k.low} · {k.rare} · {k.epic} · {k.legend}"), Ui.R("Очки за сущности", Fmt.N(Game.KillPts(k)))));
            b.Add(ui.H3("После прыжка"));
            b.Add(ui.Kv(
                Ui.R("Бонус", $"×{Fmt.X2(g.BonusMul)} » ×{Fmt.X2(g.BonusMul + g.RebirthGain)}"),
                Ui.R("Скорость искры", "×" + Fmt.X2(1 + 0.15 * (s.rebirths + 1))),
                Ui.R("Агрессивность нового мира", $"×{Fmt.X2(s.nextAggr)} — {Game.AggrName(s.nextAggr)}")));
            b.Add(ui.P("Мир, клетки, материя, параметры персонажа, ОП, ОС и способности сбросятся. Сохранятся бонус, скорость искры, ядра, артефакты, технологии и пульсары.", "muted small"));
        }
    }
}
