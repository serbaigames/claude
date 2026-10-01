// «Искра» — прокрутка содержимого перетаскиванием и колесом. Своя, чтобы не зависеть от темы ScrollView:
// контейнер обрезает, содержимое сдвигается через translate. Нажатие на кнопку не теряется,
// пока палец не сдвинулся больше чем на 8 точек.
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed class DragScroll : PointerManipulator
    {
        readonly VisualElement content;
        float offset, startOffset, startY;
        int pointer = -1;
        bool dragging;

        public bool Dragging => dragging;

        public DragScroll(VisualElement content) => this.content = content;

        protected override void RegisterCallbacksOnTarget()
        {
            target.RegisterCallback<PointerDownEvent>(OnDown, TrickleDown.TrickleDown);
            target.RegisterCallback<PointerMoveEvent>(OnMove, TrickleDown.TrickleDown);
            target.RegisterCallback<PointerUpEvent>(OnUp, TrickleDown.TrickleDown);
            target.RegisterCallback<PointerCancelEvent>(OnCancel);
            target.RegisterCallback<WheelEvent>(OnWheel);
            target.RegisterCallback<GeometryChangedEvent>(_ => Apply());
            content.RegisterCallback<GeometryChangedEvent>(_ => Apply());
            content.usageHints = UsageHints.DynamicTransform;
        }

        protected override void UnregisterCallbacksFromTarget()
        {
            target.UnregisterCallback<PointerDownEvent>(OnDown, TrickleDown.TrickleDown);
            target.UnregisterCallback<PointerMoveEvent>(OnMove, TrickleDown.TrickleDown);
            target.UnregisterCallback<PointerUpEvent>(OnUp, TrickleDown.TrickleDown);
            target.UnregisterCallback<PointerCancelEvent>(OnCancel);
            target.UnregisterCallback<WheelEvent>(OnWheel);
        }

        float MaxOffset => Mathf.Max(0, content.layout.height - target.layout.height);

        void Apply()
        {
            offset = Mathf.Clamp(offset, 0, MaxOffset);
            content.style.translate = new Translate(0, -offset);
        }

        public void ToTop()
        {
            offset = 0;
            Apply();
        }

        void OnDown(PointerDownEvent e)
        {
            pointer = e.pointerId;
            startY = e.position.y;
            startOffset = offset;
            dragging = false;
        }

        void OnMove(PointerMoveEvent e)
        {
            if (e.pointerId != pointer) return;
            float dy = e.position.y - startY;
            if (!dragging && Mathf.Abs(dy) > 8 && MaxOffset > 0)
            {
                dragging = true;
                // забираем указатель у кнопки под пальцем: отпускание уже не будет нажатием
                target.CapturePointer(pointer);
            }
            if (!dragging) return;
            offset = startOffset - dy;
            Apply();
            e.StopPropagation();
        }

        void OnUp(PointerUpEvent e)
        {
            if (e.pointerId != pointer) return;
            if (dragging)
            {
                if (target.HasPointerCapture(pointer)) target.ReleasePointer(pointer);
                e.StopPropagation();
            }
            dragging = false;
            pointer = -1;
        }

        void OnCancel(PointerCancelEvent e)
        {
            if (e.pointerId != pointer) return;
            dragging = false;
            pointer = -1;
        }

        void OnWheel(WheelEvent e)
        {
            if (MaxOffset <= 0) return;
            offset += e.delta.y * 30;
            Apply();
            e.StopPropagation();
        }
    }
}
