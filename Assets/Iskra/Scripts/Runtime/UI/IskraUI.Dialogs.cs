// «Искра» — окна: клетка под ударом, бой, прыжок искры
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
        BattleArena arena;
        bool jumpDefeat;
        DragScroll jumpDrag;

        bool BattleOpen => !Q("battle").ClassListContains("hidden");
        bool JumpOpen => !Q("jump").ClassListContains("hidden");
        bool DefendOpen => !Q("defend").ClassListContains("hidden");

        Ui Dlg => dlg ?? (dlg = new Ui(OnAct));
        Ui dlg;

        /* ---------- клетка под ударом ---------- */
        void OpenDefend()
        {
            if (!g.DefendValid()) return;
            var n = g.Cell(g.Def.Own);
            var c = g.Cell(g.Def.Att);
            var t = Defs.Tiers[c.tier];
            var fc = g.FightForecast(c);
            var (lab, cls) = Game.ForecastLabel(fc.P);
            var (mt, mcls) = g.ForecastMatter(fc);
            var u = Dlg;
            u.Reset();
            var box = Q("defBox");
            box.Clear();
            box.AddToClassList("defbox");
            box.Add(u.H2("Клетка под ударом!"));
            box.Add(u.El("row", u.L(t.Foe, "b"), u.Tier(c.tier, t.Name.ToLower())));
            box.Add(u.P($"Мощь {Fmt.N(Math.Ceiling(c.might))} прорывает защиту вашей клетки ({Fmt.N(Math.Floor(g.CellDef(n)))}). Игра на паузе."));
            box.Add(u.P("Защитите клетку в бою — при победе сущность будет побеждена. Если отступить или проиграть, клетка перейдёт к тьме."));
            box.Add(u.El("fc", u.L(lab, "fc-main " + cls), u.L(mt, "fc-sub " + mcls)));
            box.Add(u.El("facts", u.Btn("Бежать", "def:flee", "btn danger"), u.Btn("Защитить", "def:fight", "btn primary")));
            Q("defend").RemoveFromClassList("hidden");
        }

        void DefendAnswer(string v)
        {
            Q("defend").AddToClassList("hidden");
            if (g.Def == null) return;
            if (v == "flee") g.DefendFlee();
            else
            {
                g.DefendFight();
                if (g.B != null) OpenBattle();
            }
        }

        /* ---------- бой ---------- */
        sealed class AbTile
        {
            public Button B;
            public Label Cost, Cdt;
            public RingIcon Ring;
            public string Icon;
            public Color Col;
            public int Idx;
        }

        readonly List<AbTile> tiles = new List<AbTile>();
        int logCount = -1;
        string fxSig, choiceSig;

        void WireBattle()
        {
            arena = new BattleArena { G = g };
            Q("arenaHost").Insert(0, arena);
            Q<Button>("bStart").clicked += StartFight;
            Q<Button>("bFlee").clicked += CloseBattle;
            Q<Button>("bLogToggle").clicked += () =>
            {
                var lg = Q("bLogScroll");
                lg.ToggleInClassList("hidden");
                Q<Button>("bLogToggle").text = lg.ClassListContains("hidden") ? "› Ход боя" : "Ход боя — новые записи сверху";
            };
            jumpDrag = new DragScroll(Q("jumpContent"));
            Q("jumpBox").AddManipulator(jumpDrag);
        }

        void StartFight()
        {
            g.BattleBegin();
            Q("bStartRow").AddToClassList("hidden");
        }

        void OpenBattle()
        {
            var B = g.B;
            if (B == null) return;
            var u = Dlg;
            u.Reset();
            var nm = Q("bFoeName");
            nm.Clear();
            nm.Add(u.L(B.Foe.Name, "fname b"));
            nm.Add(u.Tier(B.Foe.Tier, Defs.Tiers[B.Foe.Tier].Name.ToLower()));
            if (B.Foe.Dist > 1) nm.Add(u.Tier("dist", "×" + B.Foe.Dist));
            Q("bStartRow").RemoveFromClassList("hidden");
            var fcBox = Q("bFc");
            fcBox.Clear();
            var c = g.Cell(B.CellKey);
            if (c != null)
            {
                var fc = g.FightForecast(c);
                var (lab, cls) = Game.ForecastLabel(fc.P);
                var (mt, mcls) = g.ForecastMatter(fc);
                fcBox.Add(u.L(lab, "fc-main " + cls));
                fcBox.Add(u.L(mt, "fc-sub " + mcls));
            }
            Q("battleBox").RemoveFromClassList("ended");
            Q<Button>("bFlee").text = "Отступить";
            logCount = -1; fxSig = null; choiceSig = null;
            BuildTiles();
            Q("battle").RemoveFromClassList("hidden");
            UpdateBattle();
        }

        void BuildTiles()
        {
            var acts = Q("bActions");
            acts.Clear();
            tiles.Clear();
            for (int i = 0; i < g.S.abilities.Length; i++)
            {
                var a = g.S.abilities[i];
                int idx = i;
                var b = new Button(() => g.DoAction(idx)) { focusable = false };
                b.AddToClassList("abi");
                var cost = new Label(" ");
                cost.AddToClassList("cost");
                var dial = new VisualElement();
                dial.AddToClassList("dial");
                var cdt = new Label();
                cdt.AddToClassList("cdt");
                var name = new Label(a.Empty ? "пусто" : Defs.Abilities[a.id].Name);
                name.AddToClassList("nm");
                // кольцо отката вокруг иконки, цвет — ранг способности
                var ring = new RingIcon();
                ring.style.position = Position.Absolute;
                ring.style.left = 0; ring.style.top = 0; ring.style.right = 0; ring.style.bottom = 0;
                dial.Add(ring);
                string icon = null;
                Color col = Draw.Hex("#342b55");
                if (!a.Empty)
                {
                    var d = Defs.Abilities[a.id];
                    icon = d.Icon;
                    col = Draw.Hex(Game.TierCol[d.Tier]);
                }
                ring.Set(a.Empty ? 0 : 1, icon, col);
                dial.Add(cdt);
                if (!a.Empty)
                {
                    var kk = new Label((i + 1).ToString());
                    kk.AddToClassList("kk");
                    dial.Add(kk);
                }
                b.Add(cost);
                b.Add(dial);
                b.Add(name);
                if (a.Empty) b.SetEnabled(false);
                acts.Add(b);
                tiles.Add(new AbTile { B = b, Cost = cost, Cdt = cdt, Ring = ring, Icon = icon, Col = col, Idx = i });
            }
        }

        void UpdateBattle()
        {
            var B = g.B;
            if (B == null) return;
            Q("bPhp").style.width = Length.Percent(Mathf.Clamp((float)(B.Hp / B.MaxHp * 100), 0, 100));
            SetText(Q<Label>("bPhpT"), $"{Math.Max(0, Math.Ceiling(B.Hp))} / {Game.JsRound(B.MaxHp)}");
            Q("bFhp").style.width = Length.Percent(Mathf.Clamp((float)(B.Foe.Hp / B.Foe.MaxHp * 100), 0, 100));
            SetText(Q<Label>("bFhpT"), $"{Fmt.N(Math.Max(0, Math.Ceiling(B.Foe.Hp)))} / {Fmt.N(Game.JsRound(B.Foe.MaxHp))}");
            double full = g.FullTurn;
            Q("bCd").style.width = Length.Percent(B.Cd > 0 ? Mathf.Clamp((float)((full - B.Cd) / full * 100), 0, 100) : 100);
            Q("bFcd").style.width = Length.Percent(Mathf.Clamp((float)(B.Foe.T / B.Foe.Cd * 100), 0, 100));
            SetText(Q<Label>("bMatter"), $"Свободная материя: {Fmt.N(g.S.matter)}");
            SetText(Q<Label>("bStatus"), B.Status);

            // эффекты на искре и особенности врага
            var fx = new List<string>();
            if (B.Shield > 0) fx.Add("покров");
            if (B.Immune > 0) fx.Add("неуязвимость");
            if (B.Haste > 0) fx.Add("ускорение");
            if (B.Mend > 0) fx.Add("восстановление");
            if (B.Refl > 0) fx.Add("зеркало");
            if (B.Weak > 0) fx.Add("враг ослаблен");
            if (B.Dot > 0) fx.Add("метка");
            if (B.Dispel > 0) fx.Add("особенности отключены");
            var tr = B.Foe.Traits.Select(k =>
            {
                string st = B.Dispel > 0 ? " off" : k == "ward" && g.WardOn() ? " on" : k == "shell" && B.Foe.Hp <= B.Foe.MaxHp * 0.5 ? " off" : k == "rage" && B.Foe.Hp < B.Foe.MaxHp * 0.4 ? " on" : "";
                return (k, st);
            }).ToList();
            string sig = string.Join(",", fx) + "|" + string.Join(",", tr.Select(x => x.k + x.st));
            if (sig != fxSig)
            {
                fxSig = sig;
                var pf = Q("bFx");
                pf.Clear();
                foreach (var x in fx) { var l = new Label(x); l.AddToClassList("fxtag"); pf.Add(l); }
                var ff = Q("bFfx");
                ff.Clear();
                foreach (var (k, st) in tr)
                {
                    var l = new Label(Defs.Traits[k].Name);
                    l.AddToClassList("fxtag");
                    l.AddToClassList("trait");
                    if (st.Length > 0) l.AddToClassList(st.Trim());
                    ff.Add(l);
                }
            }

            if (B.LogLines.Count != logCount)
            {
                logCount = B.LogLines.Count;
                SetText(Q<Label>("bLog"), string.Join("\n", B.LogLines.Take(8)));
            }

            if (B.Over)
            {
                Q("battleBox").AddToClassList("ended");
                Q<Button>("bFlee").text = "Закрыть";
                if (B.Choice != null) { RenderChoice(); return; }
                if (choiceSig != null) { choiceSig = null; Q("bActions").Clear(); tiles.Clear(); }
            }

            foreach (var t in tiles)
            {
                var a = g.S.abilities[t.Idx];
                if (a.Empty) continue;
                var info = g.ActionInfo(t.Idx);
                double tot = Defs.Abilities[a.id].Cd, left = B.AbCd[t.Idx];
                SetText(t.Cost, $"{info.Cost} мат.");
                t.B.EnableInClassList("poor", g.S.matter < info.Cost);
                t.B.EnableInClassList("cooling", !info.Ready);
                SetText(t.Cdt, info.Ready ? "" : Fmt.X(left));
                t.Ring.Set(info.Ready ? 1 : (float)Math.Max(0, 1 - left / tot), info.Ready ? t.Icon : null, t.Col);
                bool en = !B.Over && B.Started && info.Ready && g.S.matter >= info.Cost;
                if (t.B.enabledSelf != en) t.B.SetEnabled(en);
            }
        }

        // Выпала способность: заменить, повысить или взять ОС (второе нажатие подтверждает)
        void RenderChoice()
        {
            var B = g.B;
            var acts = Q("bActions");
            if (B?.Choice == null)
            {
                if (choiceSig != null) { acts.Clear(); tiles.Clear(); choiceSig = null; }
                return;
            }
            var ch = B.Choice;
            var d = Defs.Abilities[ch.Id];
            var u = Dlg;
            u.Reset();
            var list = new List<VisualElement>();
            string arm = B.ChArm;
            int os = Defs.Tiers[ch.Tier].Os;
            if (ch.Dup)
            {
                int i = Array.FindIndex(g.S.abilities, x => x.id == ch.Id);
                var a = g.S.abilities[i];
                list.Add(u.El("choice", u.El("row", u.L(d.Name, "b"), u.Tier(d.Tier, Defs.Tiers[d.Tier].Name.ToLower())),
                    u.P($"Уже есть в ячейке {i + 1}. Можно повысить её уровень бесплатно или взять очки способностей.")));
                list.Add(u.Btn2(arm == "up" ? "Нажмите ещё раз: повысить" : $"Повысить «{d.Name}» до ур. {a.lvl + 1}",
                    g.AbDesc(new AbilitySlot { id = a.id, lvl = a.lvl + 1 }), "choice:up", "btn btn-col" + (arm == "up" ? " danger" : " primary")));
                list.Add(u.Btn2(arm == "skip" ? "Нажмите ещё раз: взять ОС" : "Взять очки способностей", $"+{os} ОС", "choice:skip", "btn btn-col" + (arm == "skip" ? " danger" : "")));
            }
            else
            {
                list.Add(u.El("choice", u.El("row", u.L(d.Name, "b"), u.Tier(d.Tier, Defs.Tiers[d.Tier].Name.ToLower())),
                    u.P($"{g.AbDesc(new AbilitySlot { id = ch.Id, lvl = 1 })}. Все ячейки заняты: выберите, какую способность заменить.")));
                for (int i = 0; i < g.S.abilities.Length; i++)
                {
                    var a = g.S.abilities[i];
                    bool on = arm == i.ToString();
                    string old = a.Empty ? "пусто" : Defs.Abilities[a.id].Name;
                    list.Add(u.Btn2(on ? $"Нажмите ещё раз: заменить «{old}»" : $"Заменить «{old}», ур. {a.lvl}", $"вернётся {a.inv / 2} ОС", "choice:" + i, "btn btn-col" + (on ? " danger" : "")));
                }
                list.Add(u.Btn2(arm == "skip" ? "Нажмите ещё раз: не брать" : "Не брать", $"+{os} ОС", "choice:skip", "btn btn-col" + (arm == "skip" ? " danger" : "")));
            }
            string sig = u.Sig.ToString();
            if (sig == choiceSig) return;
            choiceSig = sig;
            acts.Clear();
            tiles.Clear();
            foreach (var e in list) acts.Add(e);
        }

        void CloseBattle()
        {
            g.CloseBattle();
            if (g.B == null)
            {
                Q("battle").AddToClassList("hidden");
                Q("bActions").Clear();
                tiles.Clear();
                RequestSave?.Invoke();
            }
            RenderPanel(true);
        }

        /* ---------- прыжок ---------- */
        void OpenJump(bool defeat)
        {
            jumpDefeat = defeat;
            double gain = g.RebirthGain, b0 = g.BonusMul, b1 = b0 + gain, sp0 = g.SparkSpeed, sp1 = 1 + 0.15 * (g.S.rebirths + 1);
            double Inc(double x) => Math.Pow(x, Defs.BonusPow);
            var s = g.S;
            var u = Dlg;
            u.Reset();
            var box = Q("jumpContent");
            box.Clear();
            jumpDrag.ToTop();
            box.Add(u.H2(defeat ? "Искра угасает — прыжок неизбежен" : "Прыжок искры"));
            if (defeat) box.Add(u.P("Материя ушла в минус: в этой области вселенной искре больше не на что опереться.", "bad"));
            box.Add(u.P("Искра прыгает в новую область вселенной, сжигая все накопленные ресурсы на своё развитие. Рост начнётся сначала, но уже с бонусами от текущего воплощения."));
            var left = u.El(null, u.H3("Итоги этого мира"), u.Kv(
                Ui.R("Время в мире", Fmt.Time(s.worldTime)),
                Ui.R("Рекорд клеток", s.worldMax.ToString()),
                Ui.R("Клеток сейчас", g.Own.Count.ToString()),
                Ui.R("Побеждено сущностей", s.wk.ToString()),
                Ui.R("Добыто материи", Fmt.N(s.we)),
                Ui.R("Агрессивность", "×" + Fmt.X2(g.Aggr))));
            var right = u.El(null, u.H3("Что даст прыжок"), u.Kv(
                Ui.R("Бонус искры", $"×{Fmt.X2(b0)} » ×{Fmt.X2(b1)}", "good"),
                Ui.R("Добыча от бонуса", $"×{Fmt.X2(Inc(b0))} » ×{Fmt.X2(Inc(b1))}", "good"),
                Ui.R("Цена ОП и ОС", $"÷{Fmt.X2(Math.Sqrt(b0))} » ÷{Fmt.X2(Math.Sqrt(b1))}", "good"),
                Ui.R("Рост тьмы", $"÷{Fmt.X2(Math.Sqrt(b0))} » ÷{Fmt.X2(Math.Sqrt(b1))}", "good"),
                Ui.R("Скорость искры", $"×{Fmt.X2(sp0)} » ×{Fmt.X2(sp1)}", "good"),
                Ui.R("Новая область", $"×{Fmt.X2(s.nextAggr)} — {Game.AggrName(s.nextAggr)}")));
            box.Add(u.El("jcols", left, right));
            box.Add(u.P("Сгорит: клетки, материя, параметры персонажа, ОП, ОС и навыки (кроме Искрового удара). Останется: бонус искры, ядра, артефакты, технологии, пульсары и рекорды.", "muted small"));
            var facts = u.El("facts");
            if (!defeat) facts.Add(u.Btn("Остаться", "jump:stay", "btn"));
            facts.Add(u.Btn("Прыгнуть", "jump:go", "btn primary"));
            box.Add(facts);
            Q("jump").RemoveFromClassList("hidden");
        }

        void CloseJump()
        {
            if (jumpDefeat) return;
            Q("jump").AddToClassList("hidden");
        }

        void JumpAnswer(string v)
        {
            if (v == "stay") { CloseJump(); return; }
            Q("jump").AddToClassList("hidden");
            jumpDefeat = false;
            if (g.B != null) { g.B = null; Q("battle").AddToClassList("hidden"); }
            g.Def = null;
            Q("defend").AddToClassList("hidden");
            g.Rebirth();
            map.Home();
            RequestSave?.Invoke();
        }
    }
}
