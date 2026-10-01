// «Искра» — настройка проекта в редакторе: сцена Main в списке сборки, имя игры, портретная/альбомная ориентация.
// Запускается один раз автоматически (если в сборке нет сцен) и вручную из меню «Искра».
using System.IO;
using Iskra;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UIElements;

namespace Iskra.Editor
{
    [InitializeOnLoad]
    static class IskraProjectSetup
    {
        const string ScenePath = "Assets/Iskra/Scenes/Main.unity";
        const string PanelPath = "Assets/Iskra/Resources/Iskra/IskraPanel.asset";
        const string ThemePath = "Assets/Iskra/Resources/Iskra/IskraTheme.tss";

        static IskraProjectSetup()
        {
            EditorApplication.delayCall += () =>
            {
                if (EditorApplication.isPlayingOrWillChangePlaymode) return;
                if (EditorBuildSettings.scenes.Length == 0) Setup(false);
            };
        }

        [MenuItem("Искра/Настроить проект (сцена и сборка)")]
        static void SetupMenu() => Setup(true);

        [MenuItem("Искра/Стереть сохранение")]
        static void Wipe()
        {
            SaveStore.Delete();
            Debug.Log("Искра: сохранение удалено.");
        }

        static void Setup(bool verbose)
        {
            if (AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelPath) == null)
            {
                var ps = ScriptableObject.CreateInstance<PanelSettings>();
                ps.themeStyleSheet = AssetDatabase.LoadAssetAtPath<ThemeStyleSheet>(ThemePath);
                ps.scaleMode = PanelScaleMode.ConstantPixelSize;
                AssetDatabase.CreateAsset(ps, PanelPath);
            }
            if (!File.Exists(ScenePath))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(ScenePath));
                var active = SceneManager.GetActiveScene();
                // Рядом с несохранённой безымянной сценой Unity не создаёт вторую — тогда заменяем её
                bool untitled = string.IsNullOrEmpty(active.path);
                if (untitled && active.isDirty && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, untitled ? NewSceneMode.Single : NewSceneMode.Additive);
                var cam = new GameObject("Camera").AddComponent<Camera>();
                cam.tag = "MainCamera";
                cam.clearFlags = CameraClearFlags.SolidColor;
                cam.backgroundColor = new Color32(20, 16, 38, 255);
                cam.orthographic = true;
                cam.cullingMask = 0;
                SceneManager.MoveGameObjectToScene(cam.gameObject, scene);
                var go = new GameObject("Iskra");
                go.AddComponent<IskraApp>();
                SceneManager.MoveGameObjectToScene(go, scene);
                EditorSceneManager.SaveScene(scene, ScenePath);
                if (!untitled) EditorSceneManager.CloseScene(scene, true);
            }
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            if (PlayerSettings.productName == "claude" || PlayerSettings.productName == "New Unity Project" || verbose)
                PlayerSettings.productName = "Искра";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
            PlayerSettings.allowedAutorotateToPortrait = true;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            AssetDatabase.SaveAssets();
            if (verbose) Debug.Log("Искра: сцена " + ScenePath + " добавлена в сборку.");
        }
    }
}
