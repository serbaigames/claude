// «Искра» — диаграмма параметров персонажа. Самый прокачанный параметр занимает весь радиус,
// остальные — пропорционально. Пунктирные кольца штрафа (2×, 3×, 4× среднего по остальным)
// рисуются, только если параметр до них дотягивается.
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class RadarChart : VisualElement
    {
        public static readonly string[] ParamCol = { "#ef6b90", "#5fb2e6", "#ff8a3d", "#b98bff", "#7be0a8", "#f2b441" };
        // Доля короткой стороны элемента под радиус круга: подписи параметров стоят снаружи
        public const float RadiusK = 0.22f;

        readonly Game g;
        readonly Label[] ringLabels = new Label[3];

        public RadarChart(Game game)
        {
            g = game;
            AddToClassList("radar-canvas");
            pickingMode = PickingMode.Ignore;
            generateVisualContent += Paint;
            for (int j = 0; j < 3; j++)
            {
                var l = new Label($"−{(j + 1) * 10}%") { pickingMode = PickingMode.Ignore };
                l.AddToClassList("rring");
                ringLabels[j] = l;
                Add(l);
            }
            RegisterCallback<GeometryChangedEvent>(_ => PlaceLabels());
        }

        float Max
        {
            get
            {
                int m = 1;
                foreach (var p in Defs.Params) m = Mathf.Max(m, g.S.chr[p.Id]);
                return m;
            }
        }

        // Порог штрафа для самого прокачанного параметра: m × среднее по остальным
        float Threshold(int m)
        {
            float max = Max, others = (g.S.chr.Sum - max) / (Defs.Params.Length - 1f);
            return m * others;
        }

        void PlaceLabels()
        {
            float w = contentRect.width, h = contentRect.height, R = Mathf.Min(w, h) * RadiusK, max = Max;
            for (int j = 0; j < 3; j++)
            {
                float t = Threshold(j + 2);
                var l = ringLabels[j];
                bool show = t <= max + 0.001f;
                l.style.display = show ? DisplayStyle.Flex : DisplayStyle.None;
                if (!show) continue;
                l.style.left = w / 2;
                l.style.top = h / 2 - R * t / max - 2;
            }
        }

        void Paint(MeshGenerationContext ctx)
        {
            float w = contentRect.width, h = contentRect.height;
            if (g?.S == null || w < 2 || h < 2) return;
            var p = ctx.painter2D;
            var c = new Vector2(w / 2, h / 2);
            float R = Mathf.Min(w, h) * RadiusK, max = Max;
            int n = Defs.Params.Length;
            Draw.Circle(p, c, R, Draw.Hex("#120d24"));
            Draw.Ring(p, c, R, 1.2f, Draw.Hex("#f2b441", 0.35f));
            for (int i = 0; i < n; i++)
            {
                float a0 = (-90 + 60 * i - 30) * Mathf.Deg2Rad, a1 = a0 + Mathf.PI / 3;
                float r = R * g.S.chr[Defs.Params[i].Id] / max;
                var col = Draw.Hex(ParamCol[i]);
                var pts = new System.Collections.Generic.List<Vector2> { c };
                for (int k = 0; k <= 12; k++) pts.Add(Draw.Polar(c, Mathf.Lerp(a0, a1, k / 12f), r));
                Draw.Poly(p, pts, Draw.A(col, 0.55f));
                Draw.PolyStroke(p, pts, 1.2f, col);
                Draw.Line(p, c, Draw.Polar(c, a0, R), 1, Draw.Hex("#ece6fa", 0.16f), LineCap.Butt);
            }
            for (int j = 0; j < 3; j++)
            {
                float t = Threshold(j + 2);
                if (t > max + 0.001f) continue;
                Draw.DashedRing(p, c, R * t / max, 1.6f - j * 0.3f, Draw.Hex("#ff5c7a", 0.9f - j * 0.2f), 4, 3);
            }
        }
    }
}
