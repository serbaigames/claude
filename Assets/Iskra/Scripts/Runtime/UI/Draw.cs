// «Искра» — примитивы Painter2D: круги, дуги, пунктир, свечение, языки пламени.
// Свечение собирается из полупрозрачных кругов, поэтому работает в любой версии Unity 6.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public static class Draw
    {
        static readonly Dictionary<string, Color> colors = new Dictionary<string, Color>();

        public static Color Hex(string hex)
        {
            if (colors.TryGetValue(hex, out var c)) return c;
            if (!ColorUtility.TryParseHtmlString(hex, out c)) c = Color.magenta;
            colors[hex] = c;
            return c;
        }

        public static Color Hex(string hex, float a)
        {
            var c = Hex(hex);
            c.a = a;
            return c;
        }

        public static Color A(Color c, float a)
        {
            c.a = a;
            return c;
        }

        public static Vector2 Polar(Vector2 c, float a, float r) => new Vector2(c.x + Mathf.Cos(a) * r, c.y + Mathf.Sin(a) * r);

        public static void Circle(Painter2D p, Vector2 c, float r, Color col)
        {
            if (r <= 0.05f || col.a <= 0.003f) return;
            p.fillColor = col;
            p.BeginPath();
            p.MoveTo(new Vector2(c.x + r, c.y));   // без MoveTo дуга тянет линию из (0,0)
            p.Arc(c, r, Angle.Degrees(0), Angle.Degrees(360));
            p.ClosePath();
            p.Fill();
        }

        public static void Ring(Painter2D p, Vector2 c, float r, float w, Color col)
        {
            if (r <= 0.05f || col.a <= 0.003f) return;
            p.strokeColor = col;
            p.lineWidth = w;
            p.BeginPath();
            p.MoveTo(new Vector2(c.x + r, c.y));   // без MoveTo дуга тянет линию из (0,0)
            p.Arc(c, r, Angle.Degrees(0), Angle.Degrees(360));
            p.ClosePath();
            p.Stroke();
        }

        // Дуга по часовой стрелке от a0 до a1 (радианы, 0 — вправо, как в canvas)
        public static void ArcStroke(Painter2D p, Vector2 c, float r, float a0, float a1, float w, Color col, LineCap cap = LineCap.Butt)
        {
            if (a1 <= a0 || col.a <= 0.003f) return;
            p.strokeColor = col;
            p.lineWidth = w;
            p.lineCap = cap;
            p.BeginPath();
            p.MoveTo(Polar(c, a0, r));
            p.Arc(c, r, Angle.Radians(a0), Angle.Radians(a1));
            p.Stroke();
            p.lineCap = LineCap.Butt;
        }

        // Пунктирное кольцо: штрих и промежуток — в пикселях по окружности
        public static void DashedRing(Painter2D p, Vector2 c, float r, float w, Color col, float dash, float gap, float offset = 0)
        {
            if (r <= 0.5f) return;
            float step = (dash + gap) / r, len = dash / r;
            int n = Mathf.Clamp(Mathf.FloorToInt(2 * Mathf.PI / step), 1, 120);
            step = 2 * Mathf.PI / n;
            len = Mathf.Min(len, step * 0.8f);
            p.strokeColor = col;
            p.lineWidth = w;
            for (int i = 0; i < n; i++)
            {
                float a = offset + i * step;
                p.BeginPath();
                p.MoveTo(Polar(c, a, r));
                p.Arc(c, r, Angle.Radians(a), Angle.Radians(a + len));
                p.Stroke();
            }
        }

        // Мягкое свечение: прозрачность падает от alpha на радиусе r0 до нуля на r1
        public static void Glow(Painter2D p, Vector2 c, float r0, float r1, Color col, float alpha, int steps = 6)
        {
            if (alpha <= 0.003f || r1 <= 0.5f) return;
            float each = 1 - Mathf.Pow(1 - Mathf.Clamp01(alpha), 1f / steps);
            for (int i = 0; i < steps; i++)
            {
                float r = Mathf.Lerp(r1, r0, i / (float)steps);
                Circle(p, c, r, A(col, each));
            }
        }

        // Язык пламени от окружности r0 наружу на len, ширина у основания w
        public static void Tongue(Painter2D p, Vector2 c, float a, float r0, float len, float w, Color col)
        {
            if (Mathf.Abs(len) < 0.3f || col.a <= 0.003f) return;
            Vector2 x0 = Polar(c, a, r0), x1 = Polar(c, a, r0 + len), n = new Vector2(-Mathf.Sin(a) * w, Mathf.Cos(a) * w);
            p.fillColor = col;
            p.BeginPath();
            p.MoveTo(x0 + n);
            QuadTo(p, x0 + n, Polar(c, a + 0.08f, r0 + len * 0.6f), x1, 5);
            QuadTo(p, x1, Polar(c, a - 0.08f, r0 + len * 0.6f), x0 - n, 5);
            p.ClosePath();
            p.Fill();
        }

        // Кривые раскладываем в ломаную сами: встроенные QuadraticCurveTo/BezierCurveTo в Unity
        // при заливке тянут треугольники из угла элемента (0,0) — отсюда были «лучи» через всё поле
        public static void QuadTo(Painter2D p, Vector2 from, Vector2 ctrl, Vector2 to, int n = 8)
        {
            for (int i = 1; i <= n; i++)
            {
                float t = i / (float)n, u = 1 - t;
                p.LineTo(u * u * from + 2 * u * t * ctrl + t * t * to);
            }
        }

        public static void CubicTo(Painter2D p, Vector2 from, Vector2 c1, Vector2 c2, Vector2 to, int n = 10)
        {
            for (int i = 1; i <= n; i++)
            {
                float t = i / (float)n, u = 1 - t;
                p.LineTo(u * u * u * from + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t * t * t * to);
            }
        }

        public static void Line(Painter2D p, Vector2 a, Vector2 b, float w, Color col, LineCap cap = LineCap.Round)
        {
            if (col.a <= 0.003f) return;
            p.strokeColor = col;
            p.lineWidth = w;
            p.lineCap = cap;
            p.BeginPath();
            p.MoveTo(a);
            p.LineTo(b);
            p.Stroke();
            p.lineCap = LineCap.Butt;
        }

        public static void Poly(Painter2D p, IList<Vector2> pts, Color col)
        {
            if (pts.Count < 3 || col.a <= 0.003f) return;
            p.fillColor = col;
            p.BeginPath();
            p.MoveTo(pts[0]);
            for (int i = 1; i < pts.Count; i++) p.LineTo(pts[i]);
            p.ClosePath();
            p.Fill();
        }

        public static void PolyStroke(Painter2D p, IList<Vector2> pts, float w, Color col, bool closed = true)
        {
            if (pts.Count < 2 || col.a <= 0.003f) return;
            p.strokeColor = col;
            p.lineWidth = w;
            p.lineJoin = LineJoin.Round;
            p.BeginPath();
            p.MoveTo(pts[0]);
            for (int i = 1; i < pts.Count; i++) p.LineTo(pts[i]);
            if (closed) p.ClosePath();
            p.Stroke();
        }

        // Правильный многоугольник
        public static List<Vector2> Ngon(Vector2 c, int n, float r, float rot = 0)
        {
            var o = new List<Vector2>(n);
            for (int i = 0; i < n; i++)
            {
                float a = rot + i * 2 * Mathf.PI / n - Mathf.PI / 2;
                o.Add(Polar(c, a, r));
            }
            return o;
        }

        // Звезда с n лучами: внешний радиус r1, внутренний r2
        public static List<Vector2> Star(Vector2 c, int n, float r1, float r2, float rot = 0)
        {
            var o = new List<Vector2>(n * 2);
            for (int i = 0; i < n * 2; i++)
            {
                float a = rot + i * Mathf.PI / n - Mathf.PI / 2;
                o.Add(Polar(c, a, i % 2 == 1 ? r2 : r1));
            }
            return o;
        }

        public static void RoundRect(Painter2D p, Rect r, float rad, Color col)
        {
            rad = Mathf.Min(rad, Mathf.Min(r.width, r.height) * 0.5f);
            p.fillColor = col;
            p.BeginPath();
            p.MoveTo(new Vector2(r.xMin + rad, r.yMin));
            p.LineTo(new Vector2(r.xMax - rad, r.yMin));
            p.ArcTo(new Vector2(r.xMax, r.yMin), new Vector2(r.xMax, r.yMin + rad), rad);
            p.LineTo(new Vector2(r.xMax, r.yMax - rad));
            p.ArcTo(new Vector2(r.xMax, r.yMax), new Vector2(r.xMax - rad, r.yMax), rad);
            p.LineTo(new Vector2(r.xMin + rad, r.yMax));
            p.ArcTo(new Vector2(r.xMin, r.yMax), new Vector2(r.xMin, r.yMax - rad), rad);
            p.LineTo(new Vector2(r.xMin, r.yMin + rad));
            p.ArcTo(new Vector2(r.xMin, r.yMin), new Vector2(r.xMin + rad, r.yMin), rad);
            p.ClosePath();
            p.Fill();
        }
    }
}
