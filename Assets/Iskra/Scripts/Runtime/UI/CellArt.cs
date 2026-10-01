// «Искра» — рисунок объектов поля: искра, ваши клетки (плазменные сферы), сущности тьмы по рангам,
// побеждённые клетки, кольца характеристик и ячейки строений. Общий для карты и превью в меню.
using System;
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    // Куда выводить подписи (числа на клетках, плашки уровня)
    public interface ILabelSink
    {
        void Text(string s, Vector2 pos, float size, Color col, bool bold, Color outline, Color pill = default);
    }

    public static class CellArt
    {
        sealed class RingDef
        {
            public string Ring, Flame, Star;
            public int N;
            public float Len, Glow, Sz;
        }

        static readonly System.Collections.Generic.Dictionary<string, RingDef> Rings = new System.Collections.Generic.Dictionary<string, RingDef>
        {
            ["low"] = new RingDef { Ring = "#9d92c9", Flame = "#9682d2", Star = "#d9d3f2", N = 12, Len = .18f, Glow = .25f, Sz = .86f },
            ["rare"] = new RingDef { Ring = "#69c2ff", Flame = "#46a0ff", Star = "#bfe6ff", N = 16, Len = .26f, Glow = .4f, Sz = .92f },
            ["epic"] = new RingDef { Ring = "#ff5c9a", Flame = "#ff3c82", Star = "#ffc2e0", N = 22, Len = .36f, Glow = .55f, Sz = .98f },
            ["legend"] = new RingDef { Ring = "#ffb347", Flame = "#ff821e", Star = "#dff0ff", N = 30, Len = .5f, Glow = .9f, Sz = 1.06f },
        };

        public static readonly string[] SlotCol = { "#f2b441", "#69c2ff", "#ff6b9a" };   // шахта, завод, башня
        static readonly string[] StatCol = { "#f2b441", "#5fb2e6", "#ef6b90" };

        public static float SizeOf(string tier) => Rings.TryGetValue(tier, out var d) ? d.Sz : 1;
        public static Color FlameOf(string tier) => Draw.Hex(Rings.TryGetValue(tier, out var d) ? d.Flame : "#9682d2");

        // Длина языка пламени: сумма синусов по углу; фаза делает анимацию живой
        static float FlameN(float a, float ph, int k)
            => 0.5f + 0.25f * Mathf.Sin(a * k + ph) + 0.15f * Mathf.Sin(a * (k * 2 + 1) - ph * 2) + 0.1f * Mathf.Sin(a * (k + 3) + ph * 3);

        public static void Obj(Painter2D p, string kind, Vector2 c, float r, float t, float seed, float spin)
        {
            float ph = t * 4.7f + seed * 3.7f, rot = t * spin + seed;
            switch (kind)
            {
                case "spark": Spark(p, c, r, t, ph, rot); return;
                case "own": Own(p, c, r, ph, rot); return;
                case "dead": Dead(p, c, r, ph); return;
                default: Entity(p, kind, c, r, ph, rot); return;
            }
        }

        // Вспышка искры: ядро и звёздные лучи
        static void Spark(Painter2D p, Vector2 c, float r, float t, float ph, float rot)
        {
            Draw.Glow(p, c, r * 0.3f, r * 1.5f, Draw.Hex("#ffcd78"), 0.55f, 7);
            var rr = Rand.Seeded(99);
            for (int k = 0; k < 18; k++)
            {
                float a = (float)rr() * Mathf.PI * 2 + rot, b = 0.55f + (float)rr() * 0.9f;
                float len = r * b * (0.75f + 0.25f * Mathf.Sin(ph + k * 1.7f)), w = r * (0.025f + (float)rr() * 0.04f);
                bool cold = rr() < 0.35;
                Ray(p, c, a, len, w, Draw.Hex(cold ? "#aac8ff" : "#ffd282", 0.55f));
                Ray(p, c, a, len * 0.45f, w * 0.8f, Draw.Hex("#ffffff", 0.9f));
            }
            var rs = Rand.Seeded(1234);
            for (int k = 0; k < 12; k++)
            {
                float a = (float)rs() * Mathf.PI * 2, d = r * (0.5f + (float)rs() * 0.9f), al = 0.4f + 0.6f * Mathf.Abs(Mathf.Sin(ph + k));
                Draw.Circle(p, Draw.Polar(c, a + rot * 0.3f, d), Mathf.Max(0.6f, r * 0.025f), Draw.Hex("#fff0d2", al));
            }
            Draw.Glow(p, c, r * 0.12f, r * 0.34f, Color.white, 0.9f, 4);
            Draw.Circle(p, c, r * 0.16f, Color.white);
        }

        static void Ray(Painter2D p, Vector2 c, float a, float len, float w, Color col)
        {
            p.fillColor = col;
            p.BeginPath();
            p.MoveTo(Draw.Polar(c, a + 1.57f, w));
            p.LineTo(Draw.Polar(c, a, len));
            p.LineTo(Draw.Polar(c, a - 1.57f, w));
            p.ClosePath();
            p.Fill();
        }

        // Ваша клетка: плазменная сфера в огненной короне
        static void Own(Painter2D p, Vector2 c, float r, float ph, float rot)
        {
            float R = r * 0.72f;
            Draw.Glow(p, c, R * 0.8f, r * 1.35f, Draw.Hex("#ff9628"), 0.55f);
            for (int k = 0; k < 24; k++)
            {
                float a = k / 24f * Mathf.PI * 2 + rot, n = FlameN(a, ph, 3);
                Draw.Tongue(p, c, a, R * 0.9f, r * (0.12f + 0.38f * n), R * 0.13f, k % 3 != 0 ? Draw.Hex("#ff8c1e", 0.62f) : Draw.Hex("#ffc85a", 0.75f));
            }
            Draw.Circle(p, c, R, Draw.Hex("#ffd9a0"));
            Draw.Circle(p, c, R * 0.94f, Draw.Hex("#9aa2d8"));
            var off = new Vector2(-R * 0.12f, -R * 0.15f);
            Draw.Circle(p, c + off * 0.5f, R * 0.8f, Draw.Hex("#c4cbef"));
            Draw.Circle(p, c + off, R * 0.6f, Draw.Hex("#e8ecff"));
            Draw.Circle(p, c + off * 1.4f, R * 0.32f, Draw.Hex("#ffffff", 0.95f));
            // прожилки плазмы
            var vr = Rand.Seeded(77);
            p.lineCap = LineCap.Round;
            for (int k = 0; k < 6; k++)
            {
                float a0 = (float)vr() * Mathf.PI * 2 + ph * 0.03f, d0 = R * (0.3f + (float)vr() * 0.55f);
                p.strokeColor = Draw.Hex("#ffffff", 0.18f + 0.12f * Mathf.Sin(ph + k));
                p.lineWidth = Mathf.Max(0.7f, R * 0.035f);
                p.BeginPath();
                p.MoveTo(Draw.Polar(c, a0, d0));
                for (int m = 1; m < 5; m++)
                {
                    float a = a0 + m * 0.45f + Mathf.Sin(ph + k + m) * 0.15f, d = d0 * (0.7f + 0.3f * Mathf.Sin(m + k + ph));
                    p.LineTo(Draw.Polar(c, a, Mathf.Min(d, R * 0.92f)));
                }
                p.Stroke();
            }
            p.lineCap = LineCap.Butt;
            Draw.Ring(p, c, R, Mathf.Max(1, R * 0.07f), Draw.Hex("#ffecbe", 0.95f));
        }

        // Побеждённая сущность: остывшее кольцо, клетку можно взять
        static void Dead(Painter2D p, Vector2 c, float r, float ph)
        {
            float R = r * 0.8f;
            Draw.Circle(p, c, R * 0.92f, Draw.Hex("#07050f"));
            for (int k = 0; k < 14; k++)
            {
                float a = k / 14f * Mathf.PI * 2 + ph / 14, n = FlameN(a, ph, 2);
                Draw.Tongue(p, c, a, R, r * 0.12f * n, R * 0.07f, Draw.Hex("#968270", 0.5f));
            }
            Draw.DashedRing(p, c, R, Mathf.Max(1, R * 0.07f), Draw.Hex("#f2b441", 0.85f), R * 0.22f, R * 0.16f, ph / 6);
        }

        // Сущность тьмы: огненное кольцо с тёмным центром и звездой
        static void Entity(Painter2D p, string tier, Vector2 c, float r, float ph, float rot)
        {
            if (!Rings.TryGetValue(tier, out var P)) P = Rings["low"];
            float R = r * 0.78f * P.Sz;
            Color flame = Draw.Hex(P.Flame), ring = Draw.Hex(P.Ring);
            bool legend = tier == "legend";
            Draw.Glow(p, c, R * 0.85f, r * 1.5f, flame, P.Glow * 0.6f);
            for (int k = 0; k < P.N; k++)
            {
                float a = k / (float)P.N * Mathf.PI * 2 + rot, n = FlameN(a, ph + k * 0.3f, legend ? 4 : 3);
                Draw.Tongue(p, c, a, R * 0.97f, r * P.Len * (0.35f + n), R * (tier == "low" ? 0.1f : 0.14f), k % 4 != 0 ? Draw.A(flame, 0.55f) : Draw.Hex("#ffe6c8", 0.6f));
            }
            if (legend)
                for (int k = 0; k < 6; k++)
                {
                    float a = k / 6f * Mathf.PI * 2 + ph / 6;
                    Draw.Tongue(p, c, a, R * 1.05f, r * 0.7f * (0.6f + 0.4f * Mathf.Sin(ph * 2 + k)), R * 0.2f, Draw.Hex("#ffbe5a", 0.45f));
                }
            Draw.Circle(p, c, R * 0.93f, Draw.A(flame, 0.5f));
            Draw.Circle(p, c, R * 0.88f, Draw.Hex("#05030c"));
            Draw.Circle(p, c, R * 0.6f, Draw.Hex("#0d0a1f", 0.9f));
            Draw.Ring(p, c, R, Mathf.Max(3, R * 0.3f), Draw.A(ring, 0.12f));
            Draw.Ring(p, c, R, Mathf.Max(1, R * (legend ? 0.12f : 0.08f)), ring);
            // звезда в центре с горизонтальным бликом
            float sr = R * (legend ? 0.3f : tier == "epic" ? 0.22f : tier == "rare" ? 0.18f : 0.13f) * (0.85f + 0.15f * Mathf.Sin(ph * 2));
            Draw.Glow(p, c, sr * 0.3f, sr * 1.4f, Draw.Hex(P.Star), 0.9f, 4);
            Draw.Circle(p, c, sr * 0.35f, Color.white);
            float fl = R * (legend ? 1.9f : tier == "epic" ? 1.3f : 0.9f), fa = tier == "low" ? 0.35f : 0.8f, fw = Mathf.Max(1, R * 0.04f);
            Draw.Line(p, c - new Vector2(fl, 0), c + new Vector2(fl, 0), fw, Draw.Hex("#dcebff", fa * 0.35f));
            Draw.Line(p, c - new Vector2(fl * 0.5f, 0), c + new Vector2(fl * 0.5f, 0), fw, Draw.Hex("#dcebff", fa));
        }

        // Кольцевой индикатор: доли материи, энергии и силы клетки
        public static void StatRing(Painter2D p, Cell cell, Vector2 c, float rr, float w)
        {
            double[] v = { cell.m, cell.e, cell.f };
            double tot = v[0] + v[1] + v[2];
            if (tot <= 0) return;
            const float gap = 0.07f;
            Draw.Ring(p, c, rr, w + 2, Draw.Hex("#06040e", 0.75f));
            float a = -Mathf.PI / 2;
            for (int i = 0; i < 3; i++)
            {
                float sp = (float)(v[i] / tot) * Mathf.PI * 2;
                if (sp > gap * 1.5f) Draw.ArcStroke(p, c, rr, a + gap / 2, a + sp - gap / 2, w, Draw.Hex(StatCol[i]));
                a += sp;
            }
        }

        // Маленькая искра строения в ячейке
        static void SlotSpark(Painter2D p, Vector2 c, float b, Color col)
        {
            Draw.Glow(p, c, b * 0.2f, b * 1.8f, col, 0.8f, 4);
            var w = Color.white;
            Draw.Poly(p, Draw.Star(c, 4, b * 1.5f, b * 0.2f), w);
            Draw.Poly(p, Draw.Star(c, 4, b * 0.9f, b * 0.15f, Mathf.PI / 4), Draw.A(w, 0.8f));
            Draw.Circle(p, c, b * 0.28f, w);
        }

        // Ячейки под строения — полукругами слева и справа от сферы; занятые показывают строение
        static void Slots(Painter2D p, Cell cell, Vector2 c, float R, float z, float t)
        {
            int n = Game.Cap(cell);
            if (n <= 0) return;
            var items = new System.Collections.Generic.List<int>();
            for (int i = 0; i < cell.mine; i++) items.Add(0);
            for (int i = 0; i < cell.factory; i++) items.Add(1);
            for (int i = 0; i < cell.tower; i++) items.Add(2);
            int nL = (n + 1) / 2, nR = n - nL;
            float Ra = R * 1.36f, span = 2.35f;
            float ri = Mathf.Min(R * 0.2f, Ra * span / Mathf.Max(nL, 1) * 0.42f);
            for (int i = 0; i < n; i++)
            {
                float a;
                if (i < nL) a = Mathf.PI - span / 2 + span * (nL == 1 ? 0.5f : i / (float)(nL - 1));
                else { int j = i - nL; a = span / 2 - span * (nR == 1 ? 0.5f : j / (float)(nR - 1)); }
                var pos = new Vector2(c.x + Mathf.Cos(a) * Ra, c.y - Mathf.Sin(a) * Ra);
                if (i < items.Count)
                {
                    float tw = 0.85f + 0.15f * Mathf.Sin(t * 3.8f + i * 1.7f);
                    SlotSpark(p, pos, ri * 0.8f * tw, Draw.Hex(SlotCol[items[i]]));
                }
                else Draw.DashedRing(p, pos, ri, Mathf.Max(0.8f, z), Draw.Hex("#f2b441", 0.35f), Mathf.Max(1.5f, 2 * z), Mathf.Max(1.5f, 2 * z));
            }
        }

        static readonly Color Pill = new Color(20 / 255f, 14 / 255f, 40 / 255f, 0.8f);

        // Клетка целиком: объект, кольца, ячейки и подписи
        public static void DrawCell(Painter2D p, ILabelSink L, Game g, Cell c, Vector2 x, float R, float t, float z, bool preview)
        {
            float F(float n) => Mathf.Max(8, Mathf.Round(n * z));
            float seed = Mathf.Repeat(c.q * 7.13f + c.r * 3.71f, 6.28f), pulse = 0.5f + 0.5f * Mathf.Sin(t * 3);
            if (c.spark)
            {
                Obj(p, "spark", x, R * 1.25f, t, 0, 0.12f);
                return;
            }
            if (c.own)
            {
                bool threat = g.Threatened(c);
                if (threat) Draw.Ring(p, x, R * 1.02f, 3 * z, Draw.Hex("#ef6b90", 0.45f + 0.55f * pulse));
                Obj(p, "own", x, R, t, seed, 0.08f);
                StatRing(p, c, x, R * 0.8f, Mathf.Max(2, 3 * z));
                Slots(p, c, x, R, z, t);
                double dv = Math.Floor(g.CellDef(c));
                L?.Text(dv >= 1e5 ? Fmt.N(dv) : dv.ToString("0"), x, F(13), Draw.Hex(threat ? "#9b1840" : "#23163f"), true, Draw.Hex("#ffffff", 0.75f));
                int lv = Game.CellLvl(c);
                if (!preview) L?.Text($"ур. {lv} · {Fmt.Clock(c.held)}", x + new Vector2(0, R * 1.78f), F(9.5f), lv > 0 ? Draw.Hex("#ffd27a") : Draw.Hex("#f6dfa6", 0.7f), true, Color.clear, Pill);
                return;
            }
            // тьма
            if (!c.alive)
            {
                Obj(p, "dead", x, R, t, seed, 0);
                StatRing(p, c, x, R * 0.54f, Mathf.Max(2, 2.6f * z));
            }
            else
            {
                Obj(p, c.tier, x, R, t, seed, c.tier == "legend" ? 0.25f : 0.15f);
                StatRing(p, c, x, R * 0.6f * SizeOf(c.tier), Mathf.Max(2, 2.6f * z));
            }
            double mv = Math.Ceiling(c.might);
            var my = x + new Vector2(0, R * (c.alive ? 0.02f : -0.05f));
            L?.Text(mv >= 1e5 ? Fmt.N(mv) : mv.ToString("0"), my, F(c.alive ? 13 : 12), Draw.Hex(c.alive ? "#f1ecff" : "#f6dfa6"), true, Draw.Hex("#080514", 0.9f));
            if (!c.alive) L?.Text("свободна", x + new Vector2(0, R * 0.3f), F(8.5f), Draw.Hex("#f6dfa6"), false, Draw.Hex("#080514", 0.9f));
            // прогресс до шага роста — тонкая дуга слева от объекта
            float prog = (float)Math.Min(1, c.t / Math.Max(0.001, c.growth));
            Draw.ArcStroke(p, x, R * 1.12f, Mathf.PI * 0.65f, Mathf.PI * 1.35f, 2 * z, Draw.Hex("#a88be0", 0.25f));
            Draw.ArcStroke(p, x, R * 1.12f, Mathf.PI * 0.65f, Mathf.PI * 0.65f + prog * Mathf.PI * 0.7f, 2 * z,
                c.alive ? Draw.Hex(Game.TierCol[c.tier]) : Draw.Hex("#f2b441", 0.8f));
            if (!preview && g.NearLegend(c)) L?.Text("рост ×2", x - new Vector2(0, R * 1.12f), F(9), Draw.Hex("#ffb36b"), true, Color.clear, Draw.Hex("#3c1905", 0.85f));
        }

        // Неоткрытая клетка: силуэт в туманности
        public static void Future(Painter2D p, Vector2 x, float R, float z, float t, int seed, bool near)
        {
            float a = near ? 0.55f : 0.14f;
            var rr = Rand.Seeded(700 + seed * 31);
            string[] cols = { "#462d8c", "#23468c", "#6e286e", "#32286e" };
            float d = R * 1.7f * (1 + 0.04f * Mathf.Sin(t * 0.4f + seed));
            for (int k = 0; k < (near ? 3 : 2); k++)
            {
                var off = new Vector2((float)rr() - 0.5f, (float)rr() - 0.5f) * d * 0.5f;
                float rad = d * (0.45f + (float)rr() * 0.3f);
                Draw.Glow(p, x + off, rad * 0.1f, rad, Draw.Hex(cols[(int)(rr() * cols.Length) % cols.Length]), 0.55f * a, 4);
            }
            Draw.Circle(p, x, R * 0.72f, Draw.Hex("#080514", 0.75f * a * (near ? 0.9f : 0.6f)));
            if (near) Draw.DashedRing(p, x, R * 0.78f, Mathf.Max(1, 1.4f * z), Draw.Hex("#aa96e6", 0.5f * a), 3 * z, 4 * z, t * 0.05f);
        }
    }
}
