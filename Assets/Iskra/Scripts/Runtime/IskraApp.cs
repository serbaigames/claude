// «Искра» — точка входа: создаёт камеру, панель UI Toolkit и игру, крутит кадр и сохраняет прогресс.
// Сцену настраивать не нужно: IskraBootstrap добавляет этот компонент сам при запуске любой сцены.
using System;
using System.IO;
using Iskra.Core;
using Iskra.UI;
using UnityEngine;
using UnityEngine.UIElements;

namespace Iskra
{
    public sealed class IskraApp : MonoBehaviour
    {
        Game game;
        IskraUI ui;
        PanelSettings panel;
        float saveT;
        Vector2Int screen;

        void Awake()
        {
            Application.targetFrameRate = 60;
            if (Camera.main == null)
            {
                var cam = new GameObject("Camera").AddComponent<Camera>();
                cam.tag = "MainCamera";
                cam.clearFlags = CameraClearFlags.SolidColor;
                cam.backgroundColor = new Color32(20, 16, 38, 255);
                cam.orthographic = true;
                cam.cullingMask = 0;
                cam.transform.SetParent(transform, false);
            }
        }

        void Start()
        {
            game = new Game();
            var st = SaveStore.Load();
            if (st == null || !game.Attach(st)) game.NewGame();

            // Настройки панели: ассет из «Искра → Настроить проект», иначе создаём на лету
            var asset = Resources.Load<PanelSettings>("Iskra/IskraPanel");
            panel = asset != null ? Instantiate(asset) : ScriptableObject.CreateInstance<PanelSettings>();
            panel.name = "IskraPanel";
            if (panel.themeStyleSheet == null) panel.themeStyleSheet = Resources.Load<ThemeStyleSheet>("Iskra/IskraTheme");
            panel.scaleMode = PanelScaleMode.ConstantPixelSize;
            panel.scale = ComputeScale();
            screen = new Vector2Int(Screen.width, Screen.height);

            var go = new GameObject("IskraUI");
            go.SetActive(false);
            go.transform.SetParent(transform, false);
            var doc = go.AddComponent<UIDocument>();
            doc.panelSettings = panel;
            doc.visualTreeAsset = Resources.Load<VisualTreeAsset>("Iskra/Main");
            go.SetActive(true);

            ui = new IskraUI(game, doc.rootVisualElement)
            {
                RequestSave = Save,
                WipeSave = SaveStore.Delete,
            };
            ApplySafeArea();
        }

        // Телефон (и симулятор телефона): короткая сторона ≈ 390 точек, как у iPhone в браузере;
        // компьютер — по плотности экрана
        static float ComputeScale()
        {
            float minSide = Mathf.Min(Screen.width, Screen.height);
            bool phone = Application.isMobilePlatform || Screen.dpi > 0 && minSide / Screen.dpi < 4.5f;
            if (phone) return Mathf.Max(1f, minSide / 390f);
            float s = Screen.dpi > 0 ? Screen.dpi / 96f : 1f;
            return Mathf.Clamp(s, 1f, Mathf.Max(1f, minSide / 560f));
        }

        // Вырез экрана и полоска жестов: отступы в логических точках панели
        void ApplySafeArea()
        {
            var sa = Screen.safeArea;
            float s = Mathf.Max(0.01f, panel.scale);
            ui.SetSafeArea((Screen.height - sa.yMax) / s, sa.yMin / s, sa.xMin / s, (Screen.width - sa.xMax) / s);
        }

        void Update()
        {
            if (ui == null) return;
            if (Screen.width != screen.x || Screen.height != screen.y)
            {
                screen = new Vector2Int(Screen.width, Screen.height);
                panel.scale = ComputeScale();
                ApplySafeArea();
            }
            float dt = Mathf.Min(0.25f, Time.unscaledDeltaTime);
            ui.Frame(dt, Time.realtimeSinceStartupAsDouble);
            saveT += dt;
            if (saveT > 5) { saveT = 0; Save(); }
        }

        void OnApplicationPause(bool paused)
        {
            if (paused) Save();
        }

        void OnApplicationQuit() => Save();

        void Save()
        {
            if (game?.S == null) return;
            game.S.saved = Game.NowMs();
            SaveStore.Save(game.S);
        }
    }

    // Сохранение — JSON-файл в папке данных приложения (на WebGL — запасной путь через PlayerPrefs)
    public static class SaveStore
    {
        const string Key = "iskra-save-v1";
        static string Path => System.IO.Path.Combine(Application.persistentDataPath, "iskra-save.json");

        public static void Save(GameState s)
        {
            string json = JsonUtility.ToJson(s);
            try
            {
                string tmp = Path + ".tmp";
                File.WriteAllText(tmp, json);
                if (File.Exists(Path)) File.Delete(Path);
                File.Move(tmp, Path);
            }
            catch (Exception)
            {
                PlayerPrefs.SetString(Key, json);
                PlayerPrefs.Save();
            }
        }

        public static GameState Load()
        {
            try
            {
                string json = File.Exists(Path) ? File.ReadAllText(Path) : PlayerPrefs.GetString(Key, "");
                if (string.IsNullOrEmpty(json)) return null;
                return JsonUtility.FromJson<GameState>(json);
            }
            catch (Exception e)
            {
                Debug.LogWarning("Искра: сохранение не прочитано — " + e.Message);
                return null;
            }
        }

        public static void Delete()
        {
            try { if (File.Exists(Path)) File.Delete(Path); } catch (Exception) { }
            PlayerPrefs.DeleteKey(Key);
        }
    }

    static class IskraBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (UnityEngine.Object.FindAnyObjectByType<IskraApp>() != null) return;
            var go = new GameObject("Iskra");
            go.AddComponent<IskraApp>();
            UnityEngine.Object.DontDestroyOnLoad(go);
        }
    }
}
