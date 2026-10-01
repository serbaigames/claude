// «Искра» — карта шестигранников: звёздный фон, туманности неоткрытых клеток, связи соседей,
// анимированные объекты. Перетаскивание одним пальцем/мышью, щипок и колесо — масштаб.
using System;
using System.Collections.Generic;
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class HexMap : VisualElement
    {
        const float SIZE = 34, GRID = SIZE * 2;   // объекты размера ~SIZE стоят на сетке вдвое шире
        static readonly float SQ3 = Mathf.Sqrt(3);

        public Game G;
        public Vector2 Cam;
        public float Zoom = 0.8f;
        public bool UserZoom;
        public event Action<string> CellClicked;   // ключ клетки или null — клик мимо

        readonly VisualElement canvas;
        readonly LabelLayer labels = new LabelLayer();
        readonly LabelBuffer buffer = new LabelBuffer();
        float t;
        Texture2D stars;
        Vector2Int starsSize;

        public HexMap()
        {
            AddToClassList("hexmap");
            canvas = new VisualElement { pickingMode = PickingMode.Ignore };
            canvas.AddToClassList("hexmap-canvas");
            canvas.generateVisualContent += Paint;
            Add(canvas);
            Add(labels);
            RegisterCallback<GeometryChangedEvent>(_ => Resize());
            RegisterCallback<PointerDownEvent>(OnDown);
            RegisterCallback<PointerMoveEvent>(OnMove);
            RegisterCallback<PointerUpEvent>(OnUp);
            RegisterCallback<PointerCancelEvent>(OnCancel);
            RegisterCallback<WheelEvent>(OnWheel);
            RegisterCallback<DetachFromPanelEvent>(_ => { if (stars != null) UnityEngine.Object.Destroy(stars); });
        }

        float W => contentRect.width;
        float H => contentRect.height;

        // Пока игрок сам не менял масштаб, по короткой стороне поля помещается около четырёх рядов объектов
        void Resize()
        {
            if (W < 2 || H < 2) return;
            if (!UserZoom) Zoom = Mathf.Clamp(Mathf.Min(W, H) / (GRID * SQ3 * 4.2f), 0.45f, 1.6f);
            var want = new Vector2Int(Mathf.CeilToInt(W), Mathf.CeilToInt(H));
            if (stars == null || Mathf.Abs(want.x - starsSize.x) > 64 || Mathf.Abs(want.y - starsSize.y) > 64) MakeStars(want);
        }

        // Звёздный фон рисуется один раз в текстуру
        void MakeStars(Vector2Int size)
        {
            if (stars != null) UnityEngine.Object.Destroy(stars);
            int w = Mathf.Clamp(size.x, 64, 2048), h = Mathf.Clamp(size.y, 64, 2048);
            stars = new Texture2D(w, h, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            var px = new Color32[w * h];
            Color a = Draw.Hex("#1a1432"), b = Draw.Hex("#07050f");
            float cx = w / 2f, cy = h / 2f, rmax = Mathf.Max(w, h) * 0.7f;
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    float d = Mathf.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / rmax;
                    px[y * w + x] = Color.Lerp(a, b, Mathf.Clamp01(d));
                }
            var r = Rand.Seeded(4242);
            int n = Mathf.RoundToInt(w * h / 2500f);
            for (int k = 0; k < n; k++)
            {
                bool cold = r() < 0.2;
                float al = 0.15f + (float)r() * 0.55f;
                int sx = (int)(r() * w), sy = (int)(r() * h);
                float rad = 0.5f + (float)r() * 1.1f;
                var col = cold ? new Color(190 / 255f, 210 / 255f, 1f) : new Color(1f, 245 / 255f, 225 / 255f);
                for (int dy = -2; dy <= 2; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        int xx = sx + dx, yy = sy + dy;
                        if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
                        float f = Mathf.Clamp01(rad + 0.5f - Mathf.Sqrt(dx * dx + dy * dy)) * al;
                        if (f <= 0) continue;
                        int i = yy * w + xx;
                        px[i] = Color.Lerp(px[i], col, f);
                    }
            }
            stars.SetPixels32(px);
            stars.Apply(false, true);
            starsSize = size;
            style.backgroundImage = Background.FromTexture2D(stars);
        }

        public Vector2 ToScreen(int q, int r)
        {
            float wx = GRID * SQ3 * (q + r / 2f), wy = GRID * 1.5f * r;
            return new Vector2((wx - Cam.x) * Zoom + W / 2, (wy - Cam.y) * Zoom + H / 2);
        }

        Vector2 WorldAt(Vector2 s) => new Vector2((s.x - W / 2) / Zoom + Cam.x, (s.y - H / 2) / Zoom + Cam.y);

        (int q, int r) FromScreen(Vector2 s)
        {
            var w = WorldAt(s);
            float q = (SQ3 / 3 * w.x - w.y / 3) / GRID, r = 2f / 3 * w.y / GRID;
            float x = q, z = r, y = -x - z;
            float rx = Mathf.Round(x), ry = Mathf.Round(y), rz = Mathf.Round(z);
            float dx = Mathf.Abs(rx - x), dy = Mathf.Abs(ry - y), dz = Mathf.Abs(rz - z);
            if (dx > dy && dx > dz) rx = -ry - rz;
            else if (dy <= dz) rz = -rx - ry;
            return ((int)rx, (int)rz);
        }

        public void ZoomBy(float f)
        {
            UserZoom = true;
            Zoom = Mathf.Clamp(Zoom * f, 0.3f, 2.2f);
        }

        public void Home()
        {
            UserZoom = false;
            Cam = Vector2.zero;
            Resize();
        }

        // Кадр: обновить подписи из прошлой отрисовки и перерисовать поле
        public void Tick(float time)
        {
            t = time;
            labels.Apply(buffer.Ready);
            canvas.MarkDirtyRepaint();
        }

        /* ---------- ввод ---------- */
        readonly Dictionary<int, Vector2> ptrs = new Dictionary<int, Vector2>();
        bool dragging, moved;
        Vector2 dragStart, camStart;
        float pinchD, pinchZ;
        Vector2 pinchW;
        bool pinching;

        void OnDown(PointerDownEvent e)
        {
            ptrs[e.pointerId] = e.localPosition;
            this.CapturePointer(e.pointerId);
            if (ptrs.Count == 2)
            {
                var a = Two(out var b);
                pinching = true;
                pinchD = Mathf.Max(1, Vector2.Distance(a, b));
                pinchZ = Zoom;
                pinchW = WorldAt((a + b) / 2);
                moved = true;
            }
            else if (ptrs.Count == 1)
            {
                dragging = true; moved = false;
                dragStart = e.localPosition; camStart = Cam;
            }
            e.StopPropagation();
        }

        Vector2 Two(out Vector2 b)
        {
            Vector2 a = default; b = default;
            int i = 0;
            foreach (var v in ptrs.Values) { if (i == 0) a = v; else if (i == 1) b = v; i++; }
            return a;
        }

        void OnMove(PointerMoveEvent e)
        {
            if (!ptrs.ContainsKey(e.pointerId)) return;
            ptrs[e.pointerId] = e.localPosition;
            if (pinching && ptrs.Count >= 2)
            {
                var a = Two(out var b);
                float d = Mathf.Max(1, Vector2.Distance(a, b));
                var m = (a + b) / 2;
                UserZoom = true;
                Zoom = Mathf.Clamp(pinchZ * d / pinchD, 0.3f, 2.2f);
                Cam = new Vector2(pinchW.x - (m.x - W / 2) / Zoom, pinchW.y - (m.y - H / 2) / Zoom);
                return;
            }
            if (!dragging) return;
            Vector2 dl = (Vector2)e.localPosition - dragStart;
            if (Mathf.Abs(dl.x) + Mathf.Abs(dl.y) > 6) moved = true;
            if (moved) Cam = camStart - dl / Zoom;
        }

        void OnUp(PointerUpEvent e)
        {
            End(e.pointerId, e.localPosition, true);
            e.StopPropagation();
        }

        void OnCancel(PointerCancelEvent e) => End(e.pointerId, e.localPosition, false);

        void End(int id, Vector2 pos, bool up)
        {
            if (!ptrs.Remove(id)) return;
            if (this.HasPointerCapture(id)) this.ReleasePointer(id);
            if (pinching)
            {
                if (ptrs.Count < 2) pinching = false;
                if (ptrs.Count == 1)
                {
                    foreach (var v in ptrs.Values) dragStart = v;
                    camStart = Cam; dragging = true; moved = true;
                }
                else dragging = false;
                return;
            }
            if (up && dragging && !moved && G != null)
            {
                var (q, r) = FromScreen(pos);
                string k = Game.K(q, r);
                CellClicked?.Invoke(G.Vis.Contains(k) ? k : null);
            }
            dragging = false;
        }

        void OnWheel(WheelEvent e)
        {
            Vector2 m = e.localMousePosition, w = WorldAt(m);
            UserZoom = true;
            Zoom = Mathf.Clamp(Zoom * (e.delta.y < 0 ? 1.1f : 0.9f), 0.3f, 2.2f);
            Cam = new Vector2(w.x - (m.x - W / 2) / Zoom, w.y - (m.y - H / 2) / Zoom);
            e.StopPropagation();
        }

        /* ---------- отрисовка ---------- */
        // Будущие клетки: всё в пределах двух шагов от сущностей, что ещё не открыто, — силуэты в туманностях
        readonly List<(int q, int r, bool near)> future = new List<(int, int, bool)>();
        string futKey = "";

        void Future()
        {
            string key = G.S.cells.Count + ":" + G.Vis.Count;
            if (key == futKey) return;
            futKey = key;
            future.Clear();
            var seen = new Dictionary<string, bool>();
            foreach (var c in G.S.cells)
            {
                if (c.own) continue;
                for (int i = 0; i < 6; i++)
                {
                    int q1 = c.q + Defs.Dirs[i, 0], r1 = c.r + Defs.Dirs[i, 1];
                    string k1 = Game.K(q1, r1);
                    if (G.Cell(k1) == null) seen[k1] = true;
                    for (int j = 0; j < 6; j++)
                    {
                        string k2 = Game.K(q1 + Defs.Dirs[j, 0], r1 + Defs.Dirs[j, 1]);
                        if (G.Cell(k2) != null || seen.ContainsKey(k2)) continue;
                        seen[k2] = false;
                    }
                }
            }
            foreach (var c in G.S.cells) if (!G.Vis.Contains(c.Key)) seen[c.Key] = true;
            foreach (var kv in seen)
            {
                var parts = kv.Key.Split(',');
                future.Add((int.Parse(parts[0]), int.Parse(parts[1]), kv.Value));
            }
        }

        void Paint(MeshGenerationContext ctx)
        {
            buffer.Begin();
            if (G?.S == null || W < 2 || H < 2) { buffer.End(); return; }
            var p = ctx.painter2D;
            float z = Zoom, R = SIZE * 0.95f * z;
            bool On(Vector2 v) => v.x > -R * 3 && v.y > -R * 3 && v.x < W + R * 3 && v.y < H + R * 3;

            Future();
            foreach (var f in future)
            {
                var x = ToScreen(f.q, f.r);
                if (!On(x)) continue;
                CellArt.Future(p, x, R, z, t, ((f.q * 7 + f.r * 13) % 4 + 4) % 4, f.near);
            }

            // связи между соседями: так видно, какие объекты граничат
            foreach (var k in G.Vis)
            {
                var c = G.Cell(k);
                if (c == null) continue;
                var x = ToScreen(c.q, c.r);
                if (!On(x)) continue;
                for (int i = 0; i < 3; i++)
                {
                    string k2 = Game.K(c.q + Defs.Dirs[i, 0], c.r + Defs.Dirs[i, 1]);
                    if (!G.Vis.Contains(k2)) continue;
                    var n = G.Cell(k2);
                    if (n == null) continue;
                    var x2 = ToScreen(n.q, n.r);
                    bool both = c.own && n.own, any = c.own || n.own;
                    var col = both ? Draw.Hex("#f2b441", 0.45f) : any ? Draw.Hex("#a88be0", 0.35f) : Draw.Hex("#7864b4", 0.15f);
                    var u = x2 - x;
                    float L = Mathf.Max(0.001f, u.magnitude), cut = R * 0.95f / L;
                    Draw.Line(p, x + u * cut, x2 - u * cut, (both ? 2.2f : 1.2f) * z, col);
                }
            }

            foreach (var c in G.S.cells)
            {
                if (!G.Vis.Contains(c.Key)) continue;
                var x = ToScreen(c.q, c.r);
                if (!On(x)) continue;
                CellArt.DrawCell(p, buffer, G, c, x, R, t, z, false);
            }

            var sel = G.Sel;
            if (sel != null)
            {
                var x = ToScreen(sel.q, sel.r);
                float rr = R * (sel.spark ? 1.3f : sel.own ? 1.72f : 1.28f);
                Draw.DashedRing(p, x, rr, 2.5f * z, Color.white, 6 * z, 5 * z, -t * 12 / Mathf.Max(1, rr));
            }
            buffer.End();
        }
    }

    // Превью выбранной клетки в меню: тот же рисунок, что и на поле
    public sealed class CellPreview : VisualElement
    {
        public Game G;
        public string Key;
        readonly LabelLayer labels = new LabelLayer();
        readonly LabelBuffer buffer = new LabelBuffer();
        float t;

        public CellPreview()
        {
            AddToClassList("cell-preview");
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
            var c = G?.Cell(Key);
            float w = contentRect.width, h = contentRect.height;
            if (c != null && w >= 2 && h >= 2)
            {
                float R = Mathf.Min(w, h) / (c.own ? 3.6f : 2.7f), z = R / (34 * 0.95f);
                CellArt.DrawCell(ctx.painter2D, buffer, G, c, new Vector2(w / 2, h / 2), R, t, z, true);
            }
            buffer.End();
        }
    }
}
