// «Искра» — построитель интерфейса. Каждый элемент дописывает себя в «подпись»: если подпись
// не изменилась, новое дерево не подменяет старое (как сравнение innerHTML в веб-версии).
using System;
using System.Text;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class Ui
    {
        public readonly StringBuilder Sig = new StringBuilder(2048);
        readonly Action<string> act;

        public Ui(Action<string> onAct) => act = onAct;

        public void Reset() => Sig.Clear();

        static void Cls(VisualElement e, string cls)
        {
            if (string.IsNullOrEmpty(cls)) return;
            foreach (var c in cls.Split(' '))
                if (c.Length > 0) e.AddToClassList(c);
        }

        public VisualElement El(string cls = null, params VisualElement[] kids)
        {
            var e = new VisualElement();
            Cls(e, cls);
            Sig.Append('<').Append(cls);
            foreach (var k in kids) if (k != null) e.Add(k);
            Sig.Append('>');
            return e;
        }

        public Label L(string text, string cls = null)
        {
            var l = new Label(text);
            Cls(l, cls);
            Sig.Append('[').Append(cls).Append('|').Append(text).Append(']');
            return l;
        }

        public IconElement I(string key, string cls = null)
        {
            var i = new IconElement(key);
            Cls(i, cls);
            Sig.Append('{').Append(key).Append(cls).Append('}');
            return i;
        }

        // Кнопка с действием: «build:3,-1:mine» и т. п., разбирается в IskraUI.OnAct
        public Button Btn(string text, string action, string cls = "btn", bool disabled = false, params VisualElement[] kids)
        {
            var b = new Button(() => act(action)) { text = text ?? "", focusable = false };
            Cls(b, cls);
            foreach (var k in kids) if (k != null) b.Add(k);
            b.SetEnabled(!disabled);
            Sig.Append("(b:").Append(action).Append('|').Append(text).Append('|').Append(cls).Append(disabled ? "-" : "+").Append(')');
            return b;
        }

        // Кнопка с основной строкой и подписью под ней
        public Button Btn2(string text, string sub, string action, string cls = "btn btn-col", bool disabled = false)
            => Btn(null, action, cls, disabled, L(text, null), sub != null ? L(sub, "btn-sub") : null);

        public VisualElement Kv(params (string k, string v, string cls)[] rows)
        {
            var box = El("kv");
            foreach (var (k, v, cls) in rows)
            {
                var r = El("kv-row");
                r.Add(L(k, "kv-k"));
                r.Add(L(v, "kv-v " + cls));
                box.Add(r);
            }
            return box;
        }

        public static (string k, string v, string cls) R(string k, string v, string cls = null) => (k, v, cls);

        public VisualElement H2(string t) => L(t, "h2");
        public VisualElement H3(string t) => L(t, "h3");
        public VisualElement P(string t, string cls = null) => L(t, "p " + cls);

        // Карточка быстрого меню: заголовок с иконкой, подпись, кнопки
        public VisualElement Q(string icon, string head, string sub, string cls = null, string headSmall = null, params VisualElement[] buttons)
        {
            var g = El("qg " + cls);
            var h = El("qh");
            if (icon != null) h.Add(I(icon));
            h.Add(L(head, null));
            if (headSmall != null) h.Add(L(headSmall, "qh-small"));
            g.Add(h);
            if (sub != null) g.Add(L(sub, "qe"));
            if (buttons.Length > 0)
            {
                var row = El("qb");
                foreach (var b in buttons) if (b != null) row.Add(b);
                g.Add(row);
            }
            return g;
        }

        public VisualElement Track(float pct, string col, string trackCls = "track", string fillCls = "track-fill")
        {
            var t = El(trackCls);
            var f = El(fillCls);
            f.style.width = Length.Percent(Mathf.Clamp(pct, 0, 100));
            if (col != null) f.style.backgroundColor = Draw.Hex(col);
            Sig.Append('%').Append(Mathf.RoundToInt(pct));
            t.Add(f);
            return t;
        }

        public Label Tier(string tier, string text)
        {
            return L(text, "tier-tag " + tier);
        }
    }

    // Кольцо прогресса с иконкой в центре (эра, прыжок)
    public sealed class RingIcon : VisualElement
    {
        float p = 1;
        string key;
        Color ringCol = new Color(0.95f, 0.71f, 0.25f);

        public RingIcon()
        {
            pickingMode = PickingMode.Ignore;
            generateVisualContent += Paint;
        }

        public void Set(float progress, string iconKey, Color col)
        {
            if (Mathf.Abs(progress - p) < 0.002f && iconKey == key && col == ringCol) return;
            p = progress; key = iconKey; ringCol = col;
            MarkDirtyRepaint();
        }

        void Paint(MeshGenerationContext ctx)
        {
            var r = contentRect;
            if (r.width < 2) return;
            var pt = ctx.painter2D;
            var c = r.center;
            float rad = Mathf.Min(r.width, r.height) / 2 - 2;
            Draw.Circle(pt, c, rad, Draw.Hex("#120d24"));
            Draw.Ring(pt, c, rad, 3, Draw.Hex("#342b55"));
            if (p > 0.001f) Draw.ArcStroke(pt, c, rad, -Mathf.PI / 2, -Mathf.PI / 2 + Mathf.PI * 2 * Mathf.Clamp01(p), 3, ringCol, LineCap.Round);
            Icons.Paint(pt, key, c, rad * 1.15f, ringCol);
        }
    }
}
