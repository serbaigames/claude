// «Искра» — процедурные иконки: каждая строится из звёзд, колец, лучей и огоньков (как SVG в веб-версии).
// Цвет берётся из USS-свойства color элемента, белые блики — всегда белые.
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    // Кисть в координатах иконки: поле −12…12
    public sealed class IconPen
    {
        public Painter2D P;
        public Vector2 C;
        public float S;
        public Color Cur;
        static readonly Color White = Color.white;

        public Vector2 V(float x, float y) => new Vector2(C.x + x * S, C.y + y * S);

        Color Col(bool white, float a) => Draw.A(white ? White : Cur, (white ? 1 : Cur.a) * a);

        List<Vector2> Map(List<Vector2> local)
        {
            for (int i = 0; i < local.Count; i++) local[i] = V(local[i].x, local[i].y);
            return local;
        }

        public List<Vector2> Pts(params float[] xy)
        {
            var o = new List<Vector2>(xy.Length / 2);
            for (int i = 0; i + 1 < xy.Length; i += 2) o.Add(V(xy[i], xy[i + 1]));
            return o;
        }

        public void Star(int n, float r1, float r2, float rot = 0, bool white = false, float a = 1, float cx = 0, float cy = 0)
            => Draw.Poly(P, Map(Draw.Star(new Vector2(cx, cy), n, r1, r2, rot)), Col(white, a));

        public void Ngon(int n, float r, float rot = 0, bool white = false, float a = 1, float cx = 0, float cy = 0)
            => Draw.Poly(P, Map(Draw.Ngon(new Vector2(cx, cy), n, r, rot)), Col(white, a));

        public void NgonStroke(int n, float r, float w, float rot = 0, bool white = false, float a = 1, float cx = 0, float cy = 0)
            => Draw.PolyStroke(P, Map(Draw.Ngon(new Vector2(cx, cy), n, r, rot)), w * S, Col(white, a));

        public void StarStroke(int n, float r1, float r2, float w, bool white = false, float a = 1)
            => Draw.PolyStroke(P, Map(Draw.Star(Vector2.zero, n, r1, r2)), w * S, Col(white, a));

        public void Dot(float r, bool white = false, float a = 1, float cx = 0, float cy = 0)
            => Draw.Circle(P, V(cx, cy), r * S, Col(white, a));

        public void Ring(float r, float w, bool white = false, float a = 1, float cx = 0, float cy = 0)
            => Draw.Ring(P, V(cx, cy), r * S, w * S, Col(white, a));

        public void DashRing(float r, float w, float dash, float gap, float a = 1)
            => Draw.DashedRing(P, C, r * S, w * S, Col(false, a), dash * S, gap * S);

        public void Line(float x1, float y1, float x2, float y2, float w, bool white = false, float a = 1)
            => Draw.Line(P, V(x1, y1), V(x2, y2), w * S, Col(white, a));

        public void Fill(List<Vector2> pts, bool white = false, float a = 1) => Draw.Poly(P, pts, Col(white, a));

        public void Polyline(List<Vector2> pts, float w, bool white = false, float a = 1) => Draw.PolyStroke(P, pts, w * S, Col(white, a), false);

        public void Arc(float r, float a0Deg, float a1Deg, float w, float a = 1, bool ccw = false)
        {
            P.strokeColor = Col(false, a);
            P.lineWidth = w * S;
            P.lineCap = LineCap.Round;
            P.BeginPath();
            P.MoveTo(Draw.Polar(C, a0Deg * Mathf.Deg2Rad, r * S));
            P.Arc(C, r * S, Angle.Degrees(a0Deg), Angle.Degrees(a1Deg), ccw ? ArcDirection.CounterClockwise : ArcDirection.Clockwise);
            P.Stroke();
            P.lineCap = LineCap.Butt;
        }

        public void Rays(int n, float r1, float r2, float w, float rot = 0, bool white = false, float a = 1)
        {
            for (int i = 0; i < n; i++)
            {
                float ang = rot + i * 2 * Mathf.PI / n;
                Line(Mathf.Cos(ang) * r1, Mathf.Sin(ang) * r1, Mathf.Cos(ang) * r2, Mathf.Sin(ang) * r2, w, white, a);
            }
        }

        // Путь из кубических кривых: начало и тройки точек (c1, c2, конец)
        public void Bezier(float[] start, float[][] segs, bool white = false, float a = 1)
        {
            P.fillColor = Col(white, a);
            P.BeginPath();
            var cur = V(start[0], start[1]);
            P.MoveTo(cur);
            foreach (var s in segs)
            {
                var end = V(s[4], s[5]);
                Draw.CubicTo(P, cur, V(s[0], s[1]), V(s[2], s[3]), end);
                cur = end;
            }
            P.ClosePath();
            P.Fill();
        }

        public void Ellipse(float rx, float ry, float rotDeg, float tx, float ty, bool stroke, float w = 1, bool white = false, float a = 1)
        {
            var pts = new List<Vector2>(24);
            float rot = rotDeg * Mathf.Deg2Rad;
            for (int i = 0; i < 24; i++)
            {
                float t = i * Mathf.PI * 2 / 24, x = Mathf.Cos(t) * rx + tx, y = Mathf.Sin(t) * ry + ty;
                pts.Add(V(x * Mathf.Cos(rot) - y * Mathf.Sin(rot), x * Mathf.Sin(rot) + y * Mathf.Cos(rot)));
            }
            if (stroke) Draw.PolyStroke(P, pts, w * S, Col(white, a));
            else Draw.Poly(P, pts, Col(white, a));
        }
    }

    public static class Icons
    {
        static readonly Dictionary<string, Action<IconPen>> map = new Dictionary<string, Action<IconPen>>
        {
            ["spark"] = g => { g.Star(4, 10, 2.6f); g.Star(4, 6, 1.6f, Mathf.PI / 4, a: .55f); g.Dot(2.2f, true); },
            ["matter"] = g => { g.Ngon(4, 10, a: .35f); g.NgonStroke(4, 10, 1.6f); g.Ngon(4, 4.5f, white: true, a: .85f); },
            ["might"] = g => { g.NgonStroke(4, 10.5f, 1.6f); g.Star(4, 6.5f, 2.2f); },
            ["sword"] = g =>
            {
                g.Line(-8, 8, 8, -8, 2.2f); g.Line(8, 8, -8, -8, 2.2f);
                g.Line(-8, 3, -3, 8, 1.6f); g.Line(8, 3, 3, 8, 1.6f); g.Dot(2, true);
            },
            ["heart"] = g =>
            {
                g.Bezier(new[] { 0f, 9 }, new[]
                {
                    new[] { -11f, 1, -9, -9, -3.5f, -8 }, new[] { -1f, -7.6f, 0, -5, 0, -4.5f },
                    new[] { 0f, -5, 1, -7.6f, 3.5f, -8 }, new[] { 9f, -9, 11, 1, 0, 9 },
                }, a: .85f);
                g.Polyline(g.Pts(-7, 0, -3, 0, -1.5f, -3.5f, 1, 3, 2.5f, 0, 7, 0), 1.3f, true);
            },
            ["timer"] = g =>
            {
                g.Ring(9, 1.6f); g.Line(0, 0, 0, -6.5f, 1.8f, true); g.Line(0, 0, 4.5f, 2.5f, 1.8f);
                g.Arc(9, -90, 0, 3, .6f);
            },
            ["artifact"] = g => { g.StarStroke(4, 10, 3, 1.5f); g.Dot(2.4f); g.Dot(1.2f, true, 1, 8, -8); g.Dot(1, true, .7f, -8, 8); },
            ["shield"] = g =>
            {
                var pts = ShieldPts(g);
                g.Fill(pts, a: .3f); Draw.PolyStroke(g.P, pts, 1.6f * g.S, g.Cur);
                g.Star(4, 5, 1.5f, white: true);
            },
            ["user"] = g =>
            {
                g.Dot(4.5f, cy: -3.5f);
                g.P.fillColor = Draw.A(g.Cur, g.Cur.a * .7f);
                g.P.BeginPath(); g.P.MoveTo(g.V(-9, 10)); Draw.QuadTo(g.P, g.V(-9, 10), g.V(-8, 2), g.V(0, 2)); Draw.QuadTo(g.P, g.V(0, 2), g.V(8, 2), g.V(9, 10)); g.P.ClosePath(); g.P.Fill();
                g.Dot(1.2f, true, .8f, -1.5f, -5);
            },
            ["rebirth"] = g => { g.Arc(9, -30, 19, 2, 1, true); g.Fill(g.Pts(9.5f, -9, 10, -2, 3.5f, -4)); g.Star(4, 4, 1.2f, white: true); },
            ["erase"] = g => { g.DashRing(9, 1.5f, 3, 2.2f); g.Line(-4.5f, -4.5f, 4.5f, 4.5f, 2); g.Line(4.5f, -4.5f, -4.5f, 4.5f, 2); },
            ["cells"] = g => { g.NgonStroke(6, 10, 1.6f, Mathf.PI / 6); g.Ngon(6, 5, Mathf.PI / 6, a: .6f); },
            ["comet"] = g =>
            {
                g.Line(-9, 9, 0, 0, 2.2f, a: .7f); g.Line(-10, 3, -1, -1, 1.2f, a: .7f); g.Line(-3, 10, 1, 1, 1.2f, a: .7f);
                g.Dot(5, cx: 3, cy: -3); g.Dot(2, true, 1, 4.5f, -4.5f);
            },
            ["target"] = g => { g.Ring(9, 1.4f); g.Ring(4.5f, 1.4f); g.Dot(1.6f, true); g.Rays(4, 9, 12, 1.4f); },
            ["regen"] = g => { g.Dot(10, a: .18f); g.Line(0, -7, 0, 7, 3.2f); g.Line(-7, 0, 7, 0, 3.2f); g.Dot(2, true); },
            ["shell"] = g => { g.Ngon(6, 10, a: .35f); g.NgonStroke(6, 10, 1.6f); g.NgonStroke(6, 5, 1, white: true, a: .8f); },
            ["rage"] = g =>
            {
                g.Bezier(new[] { 0f, 10 }, new[]
                {
                    new[] { -7f, 8, -8, 2, -5, -3 }, new[] { -4f, 0, -2, 1, -2, -2 }, new[] { -2f, -6, 1, -8, 0, -11 },
                    new[] { 5f, -7, 8, -2, 7, 3 }, new[] { 6f, 7, 3, 10, 0, 10 },
                });
                g.Bezier(new[] { 0f, 8 }, new[] { new[] { -3f, 7, -3, 3, -1, 1 }, new[] { 0f, 3, 2, 3, 1.5f, .5f }, new[] { 4f, 2, 4, 6, 0, 8 } }, true, .85f);
            },
            ["ward"] = g => { g.DashRing(9.5f, 1.8f, 2.5f, 2.5f); g.Dot(5, a: .35f); g.Dot(2, true); },
            ["leech"] = g =>
            {
                g.Dot(4.5f, a: .8f, cx: -5, cy: 3); g.Ring(3.2f, 1.6f, cx: 5.5f, cy: -4);
                Draw.Line(g.P, g.V(-1.5f, 0), g.V(3, -2), 1.4f * g.S, Color.white);
            },
            ["stun"] = g => { g.Rays(8, 3, 10.5f, 1.8f); g.Dot(3, true); },
            ["veil"] = g =>
            {
                g.Ring(9, 1.6f);
                g.P.fillColor = Draw.A(g.Cur, g.Cur.a * .75f);
                g.P.BeginPath(); g.P.MoveTo(g.V(0, -9)); g.P.Arc(g.C, 9 * g.S, Angle.Degrees(-90), Angle.Degrees(90)); g.P.ClosePath(); g.P.Fill();
                g.Dot(2, true);
            },
            ["bolt"] = g => { g.Fill(g.Pts(2, -11, -6, 1, -.5f, 1, -3, 11, 6, -2, .5f, -2, 4, -11)); g.Fill(g.Pts(1.5f, -8, -3, .5f, .5f, .5f), true, .8f); },
            ["fang"] = g =>
            {
                g.P.fillColor = g.Cur;
                g.P.BeginPath(); g.P.MoveTo(g.V(-8, -7)); Draw.QuadTo(g.P, g.V(-8, -7), g.V(0, -3), g.V(8, -7));
                foreach (var v in new[] { g.V(5, 2), g.V(3, -3), g.V(0, 7), g.V(-3, -3), g.V(-5, 2) }) g.P.LineTo(v);
                g.P.ClosePath(); g.P.Fill();
                g.Dot(1.8f, cy: 9);
            },
            ["haste"] = g => { g.Polyline(g.Pts(-8, -7, -1, 0, -8, 7), 2.4f); g.Polyline(g.Pts(1, -7, 8, 0, 1, 7), 2.4f, a: .7f); },
            ["nova"] = g => { g.Rays(12, 4, 11, 1.4f); g.Star(6, 6, 3); g.Dot(2.3f, true); },
            ["absorb"] = g =>
            {
                g.Ring(9.5f, 1.2f, a: .6f);
                g.Arc(6, -90, 180, 1.8f);
                g.P.BeginPath(); g.P.MoveTo(g.V(-6, 0)); Draw.QuadTo(g.P, g.V(-6, 0), g.V(-5.5f, -4.5f), g.V(0, -3.5f)); g.P.Stroke();
                g.Dot(1.7f, true);
            },
            ["tri"] = g => { g.Ngon(3, 10.5f, a: .4f); g.NgonStroke(3, 10.5f, 1.6f); g.Dot(2.2f, true, 1, 0, 1.5f); },
            ["orb"] = g => { g.Dot(9, a: .85f); g.Dot(3, true, .85f, -3, -3); g.Ring(10.5f, .8f, a: .5f); },
            ["clot"] = g => { g.Star(9, 10.5f, 5.5f, .2f, a: .8f); Draw.Circle(g.P, g.C, 3.5f * g.S, Draw.Hex("#1a1032")); g.Dot(1.4f, true); },
            ["core"] = g => { g.Star(8, 11, 3.5f); g.Dot(3.4f, true); },
            ["ember"] = g =>
            {
                g.Bezier(new[] { 0f, 9 }, new[]
                {
                    new[] { -6f, 8, -7, 2, -4, -2 }, new[] { -3f, 1, -1, 1, -1, -2 }, new[] { -1f, -6, 2, -8, 1, -10 },
                    new[] { 5f, -6, 7, -1, 6, 3 }, new[] { 5f, 7, 3, 9, 0, 9 },
                }, a: .9f);
                g.Dot(2.4f, true, 1, 0, 4); g.Rays(6, 10, 11.5f, 1);
            },
            ["daze"] = g =>
            {
                var pts = new List<Vector2>();
                for (int i = 0; i <= 40; i++) { float t = i / 40f * Mathf.PI * 3.2f, r = 1 + t * 0.75f; pts.Add(g.V(Mathf.Cos(t + Mathf.PI) * r, Mathf.Sin(t + Mathf.PI) * r)); }
                g.Polyline(pts, 1.6f);
                g.Star(4, 3, 1, white: true, cx: 7, cy: -8);
            },
            ["mend"] = g => { for (int i = 0; i < 5; i++) g.Ellipse(3, 6.5f, i * 72, 0, -5, false, a: .75f); g.Dot(2.6f, true); },
            ["lance"] = g => { g.Line(-10, 10, 7, -7, 2.4f); g.Fill(g.Pts(10, -10, 2, -8, 8, -2)); g.Line(-6, 10, -10, 6, 1.4f, true); },
            ["wither"] = g => { g.Ring(9.5f, 1.6f); g.Line(-6.5f, 6.5f, 6.5f, -6.5f, 2); g.Polyline(g.Pts(-3, -4, 0, -1, 3, -4), 1.4f, true); },
            ["harvest"] = g =>
            {
                g.Line(-8, 9, 4, -3, 2);
                g.Bezier(new[] { 4f, -3 }, new[] { new[] { 2f, -10, -6, -11, -10, -6 }, new[] { -5f, -8, 0, -6, 4, -3 } });
                g.Ngon(4, 2.6f, white: true, cx: 6, cy: 6);
            },
            ["mirror"] = g => { g.NgonStroke(4, 8, 1.6f, cx: -3); g.Ngon(4, 8, a: .45f, cx: 3); g.Line(0, -10, 0, 10, 1.2f, true); },
            ["finisher"] = g => { g.Ring(9.5f, 1.4f); g.Ring(4, 1.4f); g.Line(-11, 0, 11, 0, 1.3f, true); g.Line(0, -11, 0, 11, 1.3f, true); g.Dot(1.6f); },
            ["dispel"] = g => { g.Ring(9, 1.8f); g.Line(-6.3f, -6.3f, 6.3f, 6.3f, 2); g.Line(6.3f, -6.3f, -6.3f, 6.3f, 2); g.Dot(2, true); },
            ["pulsar"] = g => { g.Ring(10.5f, 1, a: .5f); g.Ellipse(11, 3.4f, -30, 0, 0, true, 1.4f); g.Star(4, 7, 1.8f); g.Dot(2.4f, true); },
            ["play"] = g => g.Fill(g.Pts(-5, -8, 9, 0, -5, 8)),
            ["pause"] = g => { g.Fill(g.Pts(-7, -8, -2.5f, -8, -2.5f, 8, -7, 8)); g.Fill(g.Pts(2.5f, -8, 7, -8, 7, 8, 2.5f, 8)); },
            ["close"] = g => { g.Line(-7, -7, 7, 7, 2.2f); g.Line(7, -7, -7, 7, 2.2f); },
            ["more"] = g => { g.Dot(2.2f, cx: -7); g.Dot(2.2f); g.Dot(2.2f, cx: 7); },
            ["plus"] = g => { g.Line(0, -8, 0, 8, 2.4f); g.Line(-8, 0, 8, 0, 2.4f); },
            ["minus"] = g => g.Line(-8, 0, 8, 0, 2.4f),
            ["up"] = g => g.Fill(g.Pts(0, -8, 8, 6, -8, 6)),
            ["down"] = g => g.Fill(g.Pts(-8, -6, 8, -6, 0, 8)),
            ["square"] = g => g.Fill(g.Pts(-6, -6, 6, -6, 6, 6, -6, 6)),
        };

        static List<Vector2> ShieldPts(IconPen g)
        {
            var p = new List<Vector2> { g.V(0, -10), g.V(8.5f, -6.5f), g.V(7.5f, 3) };
            // мягкий низ щита
            for (int i = 1; i <= 6; i++) { float t = i / 6f; p.Add(Q(g.V(7.5f, 3), g.V(5, 8), g.V(0, 10.5f), t)); }
            for (int i = 1; i <= 6; i++) { float t = i / 6f; p.Add(Q(g.V(0, 10.5f), g.V(-5, 8), g.V(-7.5f, 3), t)); }
            p.Add(g.V(-8.5f, -6.5f));
            return p;
        }

        static Vector2 Q(Vector2 a, Vector2 b, Vector2 c, float t) => (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c;

        public static bool Has(string key) => key != null && map.ContainsKey(key);

        public static void Paint(Painter2D p, string key, Vector2 center, float size, Color color)
        {
            if (key == null || !map.TryGetValue(key, out var f)) return;
            var pen = new IconPen { P = p, C = center, S = size / 24f, Cur = color };
            f(pen);
        }
    }

    // Иконка как элемент интерфейса: размер задаёт USS, цвет — свойство color
    public sealed class IconElement : VisualElement
    {
        string key;

        public string Key
        {
            get => key;
            set
            {
                if (key == value) return;
                key = value;
                MarkDirtyRepaint();
            }
        }

        public IconElement() : this(null) { }

        public IconElement(string key)
        {
            this.key = key;
            AddToClassList("icon");
            pickingMode = PickingMode.Ignore;
            generateVisualContent += OnGenerate;
            // цвет мог смениться вместе с классом — перерисовать
            RegisterCallback<CustomStyleResolvedEvent>(_ => MarkDirtyRepaint());
        }

        void OnGenerate(MeshGenerationContext ctx)
        {
            var r = contentRect;
            if (r.width < 1f || r.height < 1f || key == null) return;
            Icons.Paint(ctx.painter2D, key, r.center, Mathf.Min(r.width, r.height), resolvedStyle.color);
        }
    }
}
