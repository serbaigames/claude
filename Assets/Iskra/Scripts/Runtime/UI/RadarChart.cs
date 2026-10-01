// «Искра» — диаграмма параметров персонажа: сектор — уровень, пунктирные кольца — пороги штрафа (2×, 3×, 4× от среднего)
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class RadarChart : VisualElement
    {
        public static readonly string[] ParamCol = { "#ef6b90", "#5fb2e6", "#ff8a3d", "#b98bff", "#7be0a8", "#f2b441" };
        public Game G;

        public RadarChart()
        {
            AddToClassList("radar-canvas");
            pickingMode = PickingMode.Ignore;
            generateVisualContent += Paint;
        }

        void Paint(MeshGenerationContext ctx)
        {
            float w = contentRect.width, h = contentRect.height;
            if (G?.S == null || w < 2 || h < 2) return;
            var p = ctx.painter2D;
            var c = new Vector2(w / 2, h / 2);
            float R = Mathf.Min(w, h) * 0.4f;
            int n = Defs.Params.Length;
            float avg = 0;
            foreach (var x in Defs.Params) avg += G.S.chr[x.Id];
            avg /= n;
            // шкала привязана к среднему уровню: пороги стоят на месте
            float scale = avg * 4.4f;
            Draw.Circle(p, c, R, Draw.Hex("#120d24"));
            Draw.Ring(p, c, R, 1, Draw.Hex("#f2b441", 0.35f));
            Draw.Ring(p, c, R / 4.4f, 1, Draw.Hex("#ece6fa", 0.14f));
            for (int i = 0; i < n; i++)
            {
                float a0 = (-90 + 60 * i - 30) * Mathf.Deg2Rad, a1 = a0 + Mathf.PI / 3;
                float r = R * Mathf.Min(1, G.S.chr[Defs.Params[i].Id] / scale);
                var col = Draw.Hex(ParamCol[i]);
                p.fillColor = Draw.A(col, 0.5f);
                p.BeginPath();
                p.MoveTo(c);
                p.Arc(c, r, Angle.Radians(a0), Angle.Radians(a1));
                p.ClosePath();
                p.Fill();
                p.strokeColor = col;
                p.lineWidth = 1.2f;
                p.Stroke();
                Draw.Line(p, c, Draw.Polar(c, a0, R), 1, Draw.Hex("#ece6fa", 0.16f), LineCap.Butt);
            }
            for (int j = 0; j < 3; j++)
            {
                float r = R * (j + 2) / 4.4f;
                Draw.DashedRing(p, c, r, 1.5f - j * 0.3f, Draw.Hex("#ff5c7a", 0.9f - j * 0.2f), 3, 2.5f);
            }
        }
    }
}
