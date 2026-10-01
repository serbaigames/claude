// «Искра» — подписи поверх рисунка Painter2D. Во время отрисовки элементы менять нельзя,
// поэтому запросы копятся в буфере, а метки обновляются в следующем кадре (задержка в один кадр не видна).
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class LabelBuffer : ILabelSink
    {
        public struct Item
        {
            public string S;
            public Vector2 Pos;
            public float Size;
            public Color Col, Outline, Pill;
            public bool Bold;
        }

        public readonly List<Item> Items = new List<Item>();
        public readonly List<Item> Ready = new List<Item>();

        public void Begin() => Items.Clear();

        public void End()
        {
            Ready.Clear();
            Ready.AddRange(Items);
        }

        public void Text(string s, Vector2 pos, float size, Color col, bool bold, Color outline, Color pill = default)
            => Items.Add(new Item { S = s, Pos = pos, Size = size, Col = col, Bold = bold, Outline = outline, Pill = pill });
    }

    public sealed class LabelLayer : VisualElement
    {
        sealed class Slot
        {
            public Label L;
            public LabelBuffer.Item Last;
            public bool Shown;
        }

        readonly List<Slot> pool = new List<Slot>();

        public LabelLayer()
        {
            AddToClassList("map-labels");
            pickingMode = PickingMode.Ignore;
        }

        public void Apply(List<LabelBuffer.Item> items)
        {
            for (int i = 0; i < items.Count; i++)
            {
                if (i >= pool.Count)
                {
                    var l = new Label { pickingMode = PickingMode.Ignore };
                    l.AddToClassList("map-label");
                    l.style.translate = new Translate(Length.Percent(-50), Length.Percent(-50));
                    Add(l);
                    pool.Add(new Slot { L = l });
                }
                var s = pool[i];
                var it = items[i];
                var lb = s.L;
                if (!s.Shown) { lb.style.display = DisplayStyle.Flex; s.Shown = true; }
                if (s.Last.S != it.S) lb.text = it.S;
                if (s.Last.Pos != it.Pos) { lb.style.left = it.Pos.x; lb.style.top = it.Pos.y; }
                if (s.Last.Size != it.Size) lb.style.fontSize = it.Size;
                if (s.Last.Col != it.Col) lb.style.color = it.Col;
                if (s.Last.Outline != it.Outline)
                {
                    lb.style.unityTextOutlineColor = it.Outline;
                    lb.style.unityTextOutlineWidth = it.Outline.a > 0 ? 1.2f : 0;
                }
                if (s.Last.Pill != it.Pill)
                {
                    lb.style.backgroundColor = it.Pill;
                    lb.EnableInClassList("map-pill", it.Pill.a > 0);
                }
                if (s.Last.Bold != it.Bold || s.Last.S == null) lb.EnableInClassList("b", it.Bold);
                s.Last = it;
            }
            for (int i = items.Count; i < pool.Count; i++)
            {
                if (!pool[i].Shown) continue;
                pool[i].L.style.display = DisplayStyle.None;
                pool[i].Shown = false;
            }
        }
    }
}
