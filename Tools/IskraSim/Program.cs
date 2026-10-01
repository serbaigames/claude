// Бот играет в «Искру» без интерфейса: атакует самых слабых соседей, строит шахты и заводы,
// укрепляет клетки под угрозой, качает параметры и прыгает, когда рост встаёт.
using System;
using System.Linq;
using Iskra.Core;

static class Program
{
    static int Main(string[] args)
    {
        int seed = args.Length > 0 ? int.Parse(args[0]) : 1;
        double minutes = args.Length > 1 ? double.Parse(args[1]) : 120;
        Rand.Seed(seed);
        var g = new Game();
        int logs = 0, defends = 0, battles = 0, wins = 0;
        g.Logged += (t, k) => logs++;
        g.DefendRequested += () => defends++;
        g.NewGame();
        g.S.introSeen = true;
        g.S.tech.Add("jump");
        double dt = 0.1, t = 0;
        bool rich = args.Length > 2 && args[2] == "rich";
        long frames = 0;
        while (t < minutes * 60)
        {
            g.Now = t;
            g.Frame(dt);
            t += dt; frames++;
            if (g.GameOver) { g.Rebirth(); continue; }
            if (g.Def != null)
            {
                var c = g.Cell(g.Def.Att);
                var fc = g.FightForecast(c);
                if (fc.P > 0.5) { g.DefendFight(); battles++; } else g.DefendFlee();
            }
            if (g.B != null)
            {
                if (!g.B.Started) g.BattleBegin();
                for (int i = 0; i < 4; i++) g.DoAction(i);
                if (g.B.Over)
                {
                    if (g.B.Status.StartsWith("Победа")) wins++;
                    if (g.B.Choice != null) g.ResolveChoice(g.B.Choice.Dup ? "up" : "0");
                    g.CloseBattle();
                    g.S.paused = false;
                }
                continue;
            }
            if (rich && frames % 600 == 0) g.S.matter += 1e5 * (1 + t / 600);
            if (frames % 10 != 0) continue;
            g.S.paused = false;
            // покупки
            foreach (var c in g.Own.ToList())
            {
                if (c.spark) continue;
                if (g.Threatened(c)) g.Fortify(c.Key);
                if (Game.UsedCap(c) < Game.Cap(c)) g.Build(c.Key, c.mine <= c.factory ? "mine" : "factory");
            }
            g.M["opBuy"] = 10; if (g.OpBuyInfo().Cost < g.S.matter * 0.3) g.BuyOp();
            g.M["par"] = Game.Max; foreach (var p in Defs.Params) g.ParUp(p.Id);
            g.M["osBuy"] = 1; if (g.OsBuyInfo().Cost < g.S.matter * 0.1) g.BuyOs();
            for (int i = 0; i < 4; i++) if (!g.S.abilities[i].Empty) g.AbUp(i);
            for (int i = g.S.artifacts.Count - 1; i >= 0; i--)
            {
                var a = g.S.artifacts[i];
                var tgt = Defs.Arts[a.type].Target;
                var cell = tgt == "spark" ? g.Own.First(c => c.spark) : tgt == "own" ? g.Own.FirstOrDefault(c => !c.spark)
                    : tgt == "dark" ? g.Vis.Select(g.Cell).FirstOrDefault(c => c != null && !c.own) : null;
                if (cell != null) g.S.sel = cell.Key;
                g.ApplyArt(i);
            }
            // захват свободных и атака самых слабых
            var front = g.Vis.Select(g.Cell).Where(c => c != null && !c.own).OrderBy(c => c.might).ToList();
            var free = front.FirstOrDefault(c => !c.alive && g.S.matter >= Math.Ceiling(c.might));
            if (free != null) { g.Capture(free.Key); continue; }
            var target = front.FirstOrDefault(c => c.alive);
            if (target != null && frames % 50 == 0)
            {
                var fc = g.FightForecast(target);
                if (fc.P >= 0.85 && g.S.matter >= fc.Need + fc.CapCost) { g.S.sel = target.Key; g.Fight(target.Key); battles++; }
            }
            if (frames % 600 == 0)
            {
                var tr = g.Trend();
                if (tr.Kind == "dark" && g.Own.Count > 3) g.Rebirth();
            }
        }
        var s = g.S;
        Console.WriteLine($"seed {seed}: {minutes} min, matter {Fmt.N(s.matter)}, earned {Fmt.N(s.earned)}, cells {g.Own.Count}, best {s.bestCells}, rebirths {s.rebirths}, bonus {s.bonus}, battles {battles}, wins {wins}, defends {defends}, kills {s.kills.low}/{s.kills.rare}/{s.kills.epic}/{s.kills.legend}, arts {s.artifacts.Count}, cores {s.cores.Count}, pulsars {s.pulsars}, logs {logs}");
        Console.WriteLine($"  char {s.chr.life}/{s.chr.defense}/{s.chr.power}/{s.chr.meditation}/{s.chr.speed}/{s.chr.control}, abilities {string.Join(",", s.abilities.Select(a => a.Empty ? "-" : a.id + ":" + a.lvl))}, era {g.EraNow.Name}, trend {g.Trend().Text}");
        return 0;
    }
}
