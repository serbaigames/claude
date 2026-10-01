// «Искра» — главный экран: верхняя панель, поле, кнопки поверх поля, меню, лента событий, клавиши.
using System;
using System.Collections.Generic;
using System.Linq;
using Iskra.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra.UI
{
    public sealed partial class IskraUI
    {
        readonly Game g;
        readonly VisualElement root, app, stage, menu, quick, colA, colB, feed, actbar;
        readonly DragScroll menuDrag;
        readonly Label sheetTitle;
        readonly HexMap map;
        readonly Ui ui, uiAct;
        readonly Dictionary<string, Label> res = new Dictionary<string, Label>();
        readonly Dictionary<string, Button> tabs = new Dictionary<string, Button>();
        readonly List<CellPreview> previews = new List<CellPreview>();

        string tab = "main";
        string pending;
        double pendingT, now, busyUntil;
        bool touching;
        float panelT;
        string lastQuick, lastCols, lastAct;

        public Action RequestSave;   // сохранить сейчас (после важных действий)
        public Action WipeSave;      // стереть сохранение

        public bool IntroOpen => !Q("intro").ClassListContains("hidden");

        public IskraUI(Game game, VisualElement rootElement)
        {
            g = game;
            root = rootElement;
            app = Q("app");
            stage = Q("stage");
            menu = Q("menu");
            quick = Q("quick");
            colA = Q("colA");
            colB = Q("colB");
            feed = Q("feed");
            actbar = Q("actbar");
            menuDrag = new DragScroll(Q("menuContent"));
            Q("menuScroll").AddManipulator(menuDrag);
            sheetTitle = Q<Label>("sheetTitle");
            ui = new Ui(OnAct);
            uiAct = new Ui(OnAct);

            map = new HexMap { G = g };
            Q("mapHost").Add(map);
            map.style.flexGrow = 1;
            map.CellClicked += k =>
            {
                g.S.sel = k ?? "";
                pending = null;
                tab = "main";
                RenderPanel(true);
                app.Focus();
            };

            BuildTop();
            WireStage();
            WireMenu();
            WireBattle();
            Q("introGo").RegisterCallback<ClickEvent>(_ =>
            {
                g.S.introSeen = true;
                Q("intro").AddToClassList("hidden");
                RequestSave?.Invoke();
            });

            // Кнопки не забирают фокус: клавиши (пробел, 1–4, Esc) ловит корневой элемент
            root.Query<Button>().ForEach(b => b.focusable = false);
            app.RegisterCallback<KeyDownEvent>(OnKey, TrickleDown.TrickleDown);
            app.RegisterCallback<GeometryChangedEvent>(_ => Layout());

            // Пока палец/мышь на меню, оно не перестраивается — иначе нажатие может «потеряться»
            menu.RegisterCallback<PointerDownEvent>(_ => touching = true, TrickleDown.TrickleDown);
            root.RegisterCallback<PointerUpEvent>(_ =>
            {
                if (touching) { touching = false; busyUntil = now + 0.4; }
                app.Focus();
            }, TrickleDown.TrickleDown);
            menu.RegisterCallback<WheelEvent>(_ => busyUntil = now + 0.5, TrickleDown.TrickleDown);

            g.Logged += AddFeed;
            g.DefendRequested += OpenDefend;

            if (!g.S.introSeen) Q("intro").RemoveFromClassList("hidden");
            app.Focus();
            RenderPanel(true);
        }

        // Элементы из UXML не пересоздаются, поэтому поиск по имени кэшируется
        readonly Dictionary<string, VisualElement> named = new Dictionary<string, VisualElement>();

        VisualElement Q(string name)
        {
            if (!named.TryGetValue(name, out var e) || e == null) named[name] = e = root.Q(name);
            return e;
        }

        T Q<T>(string name) where T : VisualElement => Q(name) as T;

        /* ---------- кадр ---------- */
        public void Frame(float dt, double t)
        {
            now = t;
            g.Now = t;
            g.Frame(dt);
            if (g.GameOver && !JumpOpen) OpenJump(true);
            SyncTime();
            SyncEra();
            float ft = (float)t;
            if (g.B != null && BattleOpen) { arena.Tick(ft); UpdateBattle(); }
            foreach (var pv in previews) pv.Tick(ft);
            map.Tick(ft);
            UpdateTop();
            panelT += dt;
            if (panelT > 0.3f) { panelT = 0; RenderPanel(false); }
            if (g.B != null) g.B.Fx.RemoveAll(e => t - e.T0 > e.Dur + 0.1);
        }

        /* ---------- раскладка: портрет — поле сверху, альбом — слева ---------- */
        void Layout()
        {
            float W = app.layout.width, H = app.layout.height;
            if (W < 10 || H < 10) return;
            bool land = W > H * 1.1f;
            app.EnableInClassList("landscape", land);
            float topH = Q("top").layout.height;
            if (land)
            {
                stage.style.width = Mathf.Min(H - topH, W * 0.6f);
                stage.style.height = StyleKeyword.Auto;
            }
            else
            {
                stage.style.width = StyleKeyword.Auto;
                stage.style.height = Mathf.Min(W, (H - topH) * 0.58f);
            }
        }

        /* ---------- верхняя панель ---------- */
        void BuildTop()
        {
            var box = Q("res");
            foreach (var (id, k) in new[] { ("m", "Материя"), ("i", "Добыча"), ("f", "Заводы"), ("c", "Клетки"), ("b", "Бонус"), ("p", "Пульсары") })
            {
                var item = new VisualElement();
                item.AddToClassList("res-item");
                var kl = new Label(k);
                kl.AddToClassList("k");
                var vl = new Label();
                vl.AddToClassList("v");
                item.Add(kl);
                item.Add(vl);
                box.Add(item);
                res[id] = vl;
            }
        }

        static void SetText(Label l, string s)
        {
            if (l.text != s) l.text = s;
        }

        void UpdateTop()
        {
            SetText(res["m"], Fmt.N(g.S.matter));
            bool paused = g.Paused;
            SetText(res["i"], paused ? $"{Fmt.N1(g.Income())}/с · пауза" : $"+{Fmt.N1(g.Income())}/с");
            res["i"].EnableInClassList("inc", !paused);
            res["i"].EnableInClassList("paused", paused);
            SetText(res["f"], "+" + Fmt.N1(g.IncomeParts().Fac) + "%");
            int thr = g.ThreatCount;
            SetText(res["c"], $"{g.Own.Count} ({thr})");
            res["c"].EnableInClassList("bad", thr > 0);
            SetText(res["b"], "×" + Fmt.X2(g.BonusMul));
            SetText(res["p"], g.S.pulsars.ToString());
        }

        /* ---------- кнопки поверх поля ---------- */
        IconElement playIcon;
        RingIcon eraRing, jumpRing;

        void WireStage()
        {
            var tPlay = Q<Button>("tPlay");
            playIcon = new IconElement("pause");
            tPlay.Add(playIcon);
            tPlay.clicked += () => SetPaused(!g.S.paused);
            for (int i = 1; i <= 3; i++)
            {
                int sp = i;
                Q<Button>("sp" + i).clicked += () =>
                {
                    g.S.speed = sp;
                    if (g.S.paused && g.B == null && g.Def == null) g.S.paused = false;
                    RenderPanel(true);
                };
            }
            AddIcon("zIn", "plus", () => map.ZoomBy(1.2f));
            AddIcon("zOut", "minus", () => map.ZoomBy(1 / 1.2f));
            AddIcon("zHome", "target", () => map.Home());

            eraRing = new RingIcon();
            Q("eraRing").Add(eraRing);
            jumpRing = new RingIcon();
            Q("jumpRing").Add(jumpRing);
            foreach (var r in new[] { eraRing, jumpRing })
            {
                r.style.position = Position.Absolute;
                r.style.left = 0; r.style.top = 0; r.style.right = 0; r.style.bottom = 0;
            }
            Q<Button>("eraBtn").clicked += () => OpenTab("era");
            Q<Button>("jumpBtn").clicked += () =>
            {
                if (!g.HasTech("jump"))
                {
                    g.Log("Прыжок закрыт: изучите технологию «Прыжок» во вкладке «Технологии».", "info");
                    OpenTab("tech");
                    return;
                }
                OpenJump(false);
            };
        }

        void AddIcon(string btn, string icon, Action onClick)
        {
            var b = Q<Button>(btn);
            b.Add(new IconElement(icon));
            b.clicked += onClick;
        }

        void SetPaused(bool v)
        {
            if (g.B != null || g.Def != null) return;
            g.S.paused = v;
            RenderPanel(true);
        }

        void SyncTime()
        {
            var tPlay = Q<Button>("tPlay");
            bool p = g.S.paused;
            tPlay.EnableInClassList("paused", p);
            playIcon.Key = p ? "play" : "pause";
            for (int i = 1; i <= 3; i++) Q<Button>("sp" + i).EnableInClassList("on", g.Speed == i);
        }

        void SyncEra()
        {
            var tr = g.Trend();
            var wt = Q<Label>("wTrend");
            SetText(wt, tr.Text);
            foreach (var k in new[] { "grow", "stall", "warn", "dark" }) wt.EnableInClassList(k, tr.Kind == k);
            bool locked = !g.HasTech("jump");
            SetText(Q<Label>("jumpGain"), locked ? "нужна технология" : $"+{Fmt.X2(g.RebirthGain)} к бонусу");
            Q("jumpBtn").EnableInClassList("locked", locked);
            jumpRing.Set(1, "rebirth", Draw.Hex(locked ? "#a79fc2" : "#f2b441"));

            var e = g.EraNow;
            var eb = Q("eraBtn");
            foreach (var k in new[] { "good", "bad", "mixed" }) eb.EnableInClassList(k, e.Kind == k);
            int l = (int)Math.Max(0, Math.Ceiling(g.S.era.left));
            SetText(Q<Label>("eraName"), $"{e.Name} · {l / 60}:{l % 60:00}");
            SetText(Q<Label>("eraDesc"), e.Desc);
            string col = e.Kind == "good" ? "#5cc28d" : e.Kind == "bad" ? "#ef6b90" : "#f2b441";
            eraRing.Set((float)(g.S.era.left / Math.Max(1, g.S.era.dur)), e.Icon, Draw.Hex(col));
        }

        /* ---------- лента событий ---------- */
        void AddFeed(string text, string kind)
        {
            var d = new Label(text);
            d.AddToClassList("feed-item");
            d.AddToClassList(kind ?? "info");
            d.pickingMode = PickingMode.Ignore;
            feed.Insert(0, d);
            while (feed.childCount > 4) feed.RemoveAt(feed.childCount - 1);
            d.schedule.Execute(() => d.AddToClassList("fade")).ExecuteLater(6500);
            d.schedule.Execute(() => d.RemoveFromHierarchy()).ExecuteLater(7200);
        }

        /* ---------- клавиши ---------- */
        void OnKey(KeyDownEvent e)
        {
            var k = e.keyCode;
            if (k == KeyCode.None) return;
            bool handled = true;
            if (IntroOpen)
            {
                if (k == KeyCode.Escape || k == KeyCode.Return || k == KeyCode.Space)
                {
                    g.S.introSeen = true;
                    Q("intro").AddToClassList("hidden");
                }
            }
            else if (JumpOpen)
            {
                if (k == KeyCode.Escape) CloseJump();
            }
            else if (DefendOpen)
            {
                handled = false;
            }
            else if (g.B == null)
            {
                if (k == KeyCode.Space) SetPaused(!g.S.paused);
                else handled = false;
            }
            else if (k == KeyCode.Escape) CloseBattle();
            else if (!g.B.Started && !g.B.Over)
            {
                if (k == KeyCode.Return || k == KeyCode.KeypadEnter || k == KeyCode.Space) StartFight();
            }
            else
            {
                int n = k >= KeyCode.Alpha1 && k <= KeyCode.Alpha4 ? k - KeyCode.Alpha1 : k >= KeyCode.Keypad1 && k <= KeyCode.Keypad4 ? k - KeyCode.Keypad1 : -1;
                if (n >= 0) g.DoAction(n);
                else handled = false;
            }
            if (handled) e.StopPropagation();
        }

        // Системная кнопка «Назад» на Android: закрыть окно; false — закрывать нечего
        public bool Back()
        {
            if (IntroOpen) { g.S.introSeen = true; Q("intro").AddToClassList("hidden"); return true; }
            if (BattleOpen) { CloseBattle(); return true; }
            if (JumpOpen && !jumpDefeat) { CloseJump(); return true; }
            return false;
        }

        /* ---------- действия ---------- */
        bool Armed(string id) => pending == id && now - pendingT < 3.5;

        void Arm(string id)
        {
            pending = id;
            pendingT = now;
        }

        void OnAct(string action)
        {
            if (g.GameOver && !action.StartsWith("jump")) return;
            var a = action.Split(':');
            string x = a.Length > 1 ? a[1] : null, y = a.Length > 2 ? a[2] : null;
            switch (a[0])
            {
                case "fight": g.Fight(x); if (g.B != null) OpenBattle(); break;
                case "cap": g.Capture(x); break;
                case "build": g.Build(x, y); break;
                case "lower":
                    if (Armed("lower:" + x + ":" + y)) { g.Lower(x, y); pending = null; }
                    else Arm("lower:" + x + ":" + y);
                    break;
                case "fort": g.Fortify(x); break;
                case "mcyc": g.CycleMult(x); break;
                case "op": g.BuyOp(); break;
                case "par": g.ParUp(x); break;
                case "os": g.BuyOs(); break;
                case "abup": g.AbUp(int.Parse(x)); break;
                case "art": g.ApplyArt(int.Parse(x)); break;
                case "tech": g.ResearchTech(x); break;
                case "open": OpenTab(x); return;
                case "wipe":
                    if (Armed("wipe"))
                    {
                        pending = null;
                        WipeSave?.Invoke();
                        g.B = null;
                        g.Def = null;
                        g.NewGame();
                        g.S.introSeen = true;
                        HideAllOverlays();
                        g.Log("Новая искра зажглась.", "info");
                    }
                    else Arm("wipe");
                    break;
                case "choice": g.ChoiceClick(x); RenderChoice(); break;
                case "def": DefendAnswer(x); break;
                case "jump": JumpAnswer(x); break;
            }
            g.Refresh();
            RenderPanel(true);
        }

        void OpenTab(string t)
        {
            tab = t;
            pending = null;
            menuDrag.ToTop();
            RenderPanel(true);
        }

        void HideAllOverlays()
        {
            foreach (var n in new[] { "defend", "battle", "jump", "intro" }) Q(n).AddToClassList("hidden");
            jumpDefeat = false;
        }

        /* ---------- меню ---------- */
        void WireMenu()
        {
            foreach (var t in new[] { "main", "char", "abil", "tech", "art", "era", "stats" })
            {
                var b = Q<Button>("tab-" + t);
                tabs[t] = b;
                string id = t;
                b.clicked += () => OpenTab(id);
            }
        }

        bool MenuBusy => touching || menuDrag.Dragging || now < busyUntil;

        static readonly Dictionary<string, string> TabTitle = new Dictionary<string, string>
        {
            ["tech"] = "Технологии", ["era"] = "Эры", ["char"] = "Персонаж", ["abil"] = "Способности",
            ["art"] = "Артефакты", ["stats"] = "Профиль",
        };

        string SheetTitle()
        {
            if (tab != "main") return TabTitle[tab];
            var c = g.Sel;
            return c == null ? "Владения" : c.spark ? "Искра" : c.own ? "Ваша клетка" : c.alive ? "Клетка тьмы" : "Свободная клетка";
        }

        public void RenderPanel(bool force)
        {
            foreach (var kv in tabs) kv.Value.EnableInClassList("on", kv.Key == tab);
            SetText(sheetTitle, SheetTitle());
            RenderActbar(force);
            if (!force && MenuBusy) return;

            ui.Reset();
            var q = BuildQuick();
            string qs = ui.Sig.ToString();
            ui.Reset();
            var (a, b) = BuildCols();
            string cs = ui.Sig.ToString();

            if (force || qs != lastQuick)
            {
                quick.Clear();
                foreach (var e in q) quick.Add(e);
                lastQuick = qs;
                quick.EnableInClassList("hidden", q.Count == 0);
                previews.Clear();
                quick.Query<CellPreview>().ForEach(previews.Add);
            }
            if (force || cs != lastCols)
            {
                colA.Clear();
                foreach (var e in a) colA.Add(e);
                colB.Clear();
                foreach (var e in b) colB.Add(e);
                lastCols = cs;
            }
        }

        List<VisualElement> BuildQuick()
        {
            switch (tab)
            {
                case "main": return QuickMain();
                case "char": return QuickChar();
                case "abil": return QuickAbil();
                case "tech": return QuickTech();
                case "art": return QuickArt();
                case "era": return QuickEra();
                default: return QuickStats();
            }
        }

        (List<VisualElement>, List<VisualElement>) BuildCols()
        {
            var a = new List<VisualElement>();
            var b = new List<VisualElement>();
            switch (tab)
            {
                case "main": ColsMain(a, b); break;
                case "char": ColsChar(a, b); break;
                case "abil": ColsAbil(a, b); break;
                case "tech": ColsTech(a, b); break;
                case "art": ColsArt(a, b); break;
                case "era": ColsEra(a, b); break;
                default: ColsStats(a, b); break;
            }
            return (a, b);
        }
    }
}
