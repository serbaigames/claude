// «Искра» — арена боя: искра против сущности, ауры навыков, снаряды, вспышки и рассыпание проигравшего
using System.Collections.Generic;
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class BattleArena : VisualElement
    {
        public Game G;
        readonly LabelLayer labels = new LabelLayer();
        readonly LabelBuffer buffer = new LabelBuffer();
        float t;

        struct Part
        {
            public Vector2 P, V;
            public float S, Life;
            public Color C;
        }

        readonly List<Part> parts = new List<Part>();
        double partsFor = -1;

        public BattleArena()
        {
            AddToClassList("arena");
            var canvas = new VisualElement { pickingMode = PickingMode.Ignore };
            canvas.AddToClassList("hexmap-canvas");
            canvas.generateVisualContent += Paint;
            Add(canvas);
            Add(labels);
        }

        public void Tick(float time)
        {
            t = time;
            labels.Apply(buffer.Ready);
            this[0].MarkDirtyRepaint();
        }

        void Paint(MeshGenerationContext ctx)
        {
            buffer.Begin();
            var B = G?.B;
            float w = contentRect.width, h = contentRect.height;
            if (B == null || w < 2 || h < 2) { buffer.End(); return; }
            var p = ctx.painter2D;

            var rs = Rand.Seeded(99);
            for (int k = 0; k < 90; k++)
                Draw.Circle(p, new Vector2((float)rs() * w, (float)rs() * h), 0.4f + (float)rs() * 0.9f, Draw.Hex("#fff5e1", 0.1f + (float)rs() * 0.5f));

            float R = Mathf.Min(h * 0.3f, w * 0.14f);
            Vector2 P = new Vector2(w * 0.26f, h * 0.52f), F = new Vector2(w * 0.74f, h * 0.52f);
            Vector2 Pos(char a) => a == 'p' ? P : F;

            // туманность за противником
            Draw.Glow(p, F + new Vector2(-R * 0.4f, R * 0.2f), R * 0.2f, R * 1.8f, Draw.Hex("#462d8c"), 0.35f, 5);
            Draw.Glow(p, F + new Vector2(R * 0.5f, -R * 0.3f), R * 0.2f, R * 1.5f, Draw.Hex("#6e286e"), 0.3f, 5);

            float Shake(double until) => until > G.Now ? (Random.value - 0.5f) * R * 0.12f : 0;
            float dAge = B.DisWho != 0 ? (float)(G.Now - B.DisT0) : 0;
            float AlphaOf(char who) => B.DisWho == who ? Mathf.Max(0, 1 - dAge / 0.45f) : 1;

            // искра
            float pa = AlphaOf('p');
            if (pa > 0)
            {
                var sp = P + new Vector2(Shake(B.ShP), Shake(B.ShP));
                if (pa >= 0.99f) CellArt.Obj(p, "spark", sp, R * 1.25f, t, 0, 0.15f);
                else Draw.Glow(p, sp, R * 0.1f, R * 1.4f, Draw.Hex("#ffcd78"), 0.7f * pa, 5);
            }
            // ауры искры
            if (B.Shield > 0)
            {
                Draw.Glow(p, P, R * 0.6f, R * 1.1f, Draw.Hex("#78beff"), 0.25f, 4);
                Draw.DashedRing(p, P, R * 1.05f, 2.5f, Draw.Hex("#78beff", 0.5f + 0.3f * Mathf.Sin(t * 6)), 6, 5, t * 20 / R);
            }
            if (B.Immune > 0) Draw.PolyStroke(p, Draw.Ngon(P, 6, R * 1.15f, t * 0.6f), 3, Draw.Hex("#ffd778", 0.6f + 0.3f * Mathf.Sin(t * 8)));
            if (B.Mend > 0) { float ph = t % 1f; Draw.Ring(p, P, R * (0.8f + ph * 0.5f), 2, Draw.Hex("#7be0a8", 0.6f * (1 - ph))); }
            if (B.Refl > 0)
                for (int i = 0; i < 4; i++)
                {
                    float a0 = -t * 0.8f + i * Mathf.PI / 2;
                    Draw.ArcStroke(p, P, R * 1.08f, a0, a0 + 0.9f, 2.5f, Draw.Hex("#dfe8ff", 0.55f + 0.3f * Mathf.Sin(t * 9)));
                }
            if (B.Haste > 0)
                for (int i = 0; i < 8; i++) Draw.Circle(p, Draw.Polar(P, t * 5 + i * Mathf.PI / 4, R * 0.95f), 2.2f, Draw.Hex("#fff0b4", 0.8f));

            // противник
            float fa = AlphaOf('f');
            if (fa > 0)
            {
                var fp = F + new Vector2(Shake(B.ShF), Shake(B.ShF));
                var foe = B.Foe;
                if (G.Has("rage") && foe.Hp < foe.MaxHp * 0.4) Draw.Glow(p, fp, R * 0.5f, R * 1.6f, Draw.Hex("#ff3c3c"), 0.25f + 0.2f * Mathf.Sin(t * 10), 4);
                if (fa >= 0.99f) CellArt.Obj(p, foe.Tier, fp, R, t, 1.3f, foe.Tier == "legend" ? 0.3f : 0.18f);
                else Draw.Glow(p, fp, R * 0.1f, R * 1.3f, CellArt.FlameOf(foe.Tier), 0.7f * fa, 5);
                if (G.Has("shell") && foe.Hp > foe.MaxHp * 0.5) Draw.PolyStroke(p, Draw.Ngon(fp, 6, R * 1.12f, -t * 0.3f), 2, Draw.Hex("#a0d2ff", 0.55f));
                if (G.WardOn()) Draw.Glow(p, fp, R * 0.8f, R * 1.3f, Draw.Hex("#b89bff"), 0.45f, 4);
                if (B.Dot > 0)
                    for (int i = 0; i < 7; i++)
                    {
                        float a = t * 2 + i * 0.9f, yy = fp.y + R * 0.6f - (t * 40 + i * 13) % (R * 1.4f);
                        Draw.Circle(p, new Vector2(fp.x + Mathf.Sin(a) * R * 0.6f, yy), 2.2f, Draw.Hex("#ff963c", 0.75f));
                    }
                if (B.Weak > 0) Draw.DashedRing(p, fp, R * 1.2f, 2, Draw.Hex("#9b7bff", 0.6f), 3, 4, t);
                if (B.Dispel > 0)
                {
                    Draw.Ring(p, fp, R * 1.25f, 2, Draw.Hex("#cfd6ff", 0.7f));
                    Draw.Line(p, fp + new Vector2(-R * 0.9f, R * 0.9f), fp + new Vector2(R * 0.9f, -R * 0.9f), 2, Draw.Hex("#cfd6ff", 0.7f));
                }
                if (G.Has("regen")) { float ph = t % 1.2f / 1.2f; Draw.Ring(p, fp, R * (0.9f + ph * 0.5f), 2, Draw.Hex("#5cc28d", 0.5f * (1 - ph))); }
            }

            // рассыпание проигравшего
            if (B.DisWho != 0)
            {
                var o = Pos(B.DisWho);
                if (partsFor != B.DisT0)
                {
                    partsFor = B.DisT0;
                    parts.Clear();
                    var rr = Rand.Seeded((long)(B.DisT0 * 1000) + 7);
                    Color[] cols = B.DisWho == 'p'
                        ? new[] { Draw.Hex("#ffe6a0"), Color.white, Draw.Hex("#ffbe5a") }
                        : new[] { CellArt.FlameOf(B.Foe.Tier), Draw.Hex("#fff0dc"), Draw.Hex("#a08cdc") };
                    for (int k = 0; k < 150; k++)
                    {
                        float a = (float)rr() * Mathf.PI * 2, r = Mathf.Sqrt((float)rr()) * R;
                        parts.Add(new Part
                        {
                            P = Draw.Polar(o, a, r),
                            V = new Vector2(Mathf.Cos(a) * (15 + (float)rr() * 55), Mathf.Sin(a) * (15 + (float)rr() * 55) - 20 - (float)rr() * 25),
                            S = 0.8f + (float)rr() * 2.2f, Life = 1.1f + (float)rr() * 1.1f, C = cols[(int)(rr() * cols.Length) % cols.Length],
                        });
                    }
                }
                foreach (var q in parts)
                {
                    float a = Mathf.Max(0, 1 - dAge / q.Life);
                    if (a <= 0) continue;
                    Draw.Circle(p, q.P + q.V * dAge + new Vector2(0, 8 * dAge * dAge), q.S * (0.6f + 0.4f * a), Draw.A(q.C, a));
                }
            }

            // быстрые эффекты
            foreach (var e in B.Fx)
            {
                float pr = Mathf.Clamp01((float)((G.Now - e.T0) / e.Dur));
                if (G.Now - e.T0 >= e.Dur) continue;
                Color col = Draw.Hex(e.Col);
                switch (e.Kind)
                {
                    case "bolt":
                    {
                        Vector2 A = Pos(e.From), Z = Pos(e.From == 'p' ? 'f' : 'p');
                        var x = Vector2.Lerp(A, Z, pr) - new Vector2(0, Mathf.Sin(pr * Mathf.PI) * R * 0.25f);
                        float br = R * 0.35f * (float)e.W;
                        Draw.Glow(p, x, br * 0.2f, br, col, 0.85f, 4);
                        Draw.Circle(p, x, br * 0.25f, Color.white);
                        Draw.Line(p, Vector2.Lerp(A, Z, Mathf.Max(0, pr - 0.25f)), x, 2 * (float)e.W, Draw.A(col, 0.6f));
                        if (pr > 0.9f) { float q = (pr - 0.9f) / 0.1f; Draw.Ring(p, Z, R * (0.5f + q * 0.8f), 3, Draw.A(col, 1 - q)); }
                        break;
                    }
                    case "beam":
                    {
                        Vector2 A = Pos(e.From), Z = Pos(e.From == 'p' ? 'f' : 'p');
                        p.strokeColor = Draw.A(col, 1 - pr);
                        p.lineWidth = 6 * (1 - pr) + 1;
                        p.lineCap = LineCap.Round;
                        p.BeginPath(); p.MoveTo(A); p.QuadraticCurveTo(new Vector2((A.x + Z.x) / 2, A.y - R * 0.6f), Z); p.Stroke();
                        p.lineCap = LineCap.Butt;
                        break;
                    }
                    case "spiral":
                    {
                        Vector2 A = Pos(e.From), Z = Pos(e.From == 'p' ? 'f' : 'p');
                        for (int i = 0; i < 12; i++)
                        {
                            float q = Mathf.Clamp01(pr * 1.3f - i * 0.025f), a = q * Mathf.PI * 3 + i;
                            var x = Vector2.Lerp(A, Z, q) + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * R * 0.3f * (1 - q);
                            Draw.Circle(p, x, 2.4f, Draw.A(col, 0.8f * (1 - q * 0.5f)));
                        }
                        break;
                    }
                    case "heal":
                    {
                        var A = Pos(e.At);
                        for (int i = 0; i < 10; i++)
                            Draw.Circle(p, new Vector2(A.x + Mathf.Sin(i * 2.3f) * R * 0.7f, A.y + R * 0.5f - pr * R * 1.3f - i * 3), 2.2f, Draw.Hex("#7be0a8", 1 - pr));
                        break;
                    }
                    case "flash":
                        Draw.Glow(p, Pos(e.At), R * 0.1f, R * (0.8f + pr * 0.9f), col, 0.8f * (1 - pr), 5);
                        break;
                    case "stun":
                    {
                        var A = Pos(e.At);
                        for (int i = 0; i < 5; i++)
                        {
                            float a = t * 6 + i * 1.26f;
                            Draw.Circle(p, new Vector2(A.x + Mathf.Cos(a) * R * 0.6f, A.y - R * 0.9f + Mathf.Sin(a) * R * 0.15f), 2.4f, Draw.Hex("#ffe678", 1 - pr));
                        }
                        break;
                    }
                    case "num":
                    {
                        var A = Pos(e.At);
                        buffer.Text(e.Txt, new Vector2(A.x, A.y - R * 0.9f - pr * R * 0.6f), Mathf.Round(R * 0.32f), Draw.A(col, 1 - pr * pr), true, Draw.Hex("#080514", 0.9f * (1 - pr * pr)));
                        break;
                    }
                }
            }
            buffer.End();
        }
    }
}
