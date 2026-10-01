// Заглушки Unity API — только для проверки компиляции скриптов «Искры» вне Unity (dotnet build).
// Сигнатуры повторяют Unity 6; тела пустые. В сам проект Unity не входят.
#pragma warning disable CS0067, CS0649, CS0414
using System;
using System.Collections.Generic;

namespace UnityEngine
{
    public struct Vector2
    {
        public float x, y;
        public Vector2(float x, float y) { this.x = x; this.y = y; }
        public static Vector2 zero => default;
        public float magnitude => (float)Math.Sqrt(x * x + y * y);
        public static Vector2 operator +(Vector2 a, Vector2 b) => new Vector2(a.x + b.x, a.y + b.y);
        public static Vector2 operator -(Vector2 a, Vector2 b) => new Vector2(a.x - b.x, a.y - b.y);
        public static Vector2 operator -(Vector2 a) => new Vector2(-a.x, -a.y);
        public static Vector2 operator *(Vector2 a, float d) => new Vector2(a.x * d, a.y * d);
        public static Vector2 operator *(float d, Vector2 a) => new Vector2(a.x * d, a.y * d);
        public static Vector2 operator /(Vector2 a, float d) => new Vector2(a.x / d, a.y / d);
        public static bool operator ==(Vector2 a, Vector2 b) => a.x == b.x && a.y == b.y;
        public static bool operator !=(Vector2 a, Vector2 b) => !(a == b);
        public override bool Equals(object o) => o is Vector2 v && v == this;
        public override int GetHashCode() => 0;
        public static Vector2 Lerp(Vector2 a, Vector2 b, float t) => a + (b - a) * t;
        public static float Distance(Vector2 a, Vector2 b) => (a - b).magnitude;
        public static implicit operator Vector2(Vector3 v) => new Vector2(v.x, v.y);
        public static implicit operator Vector3(Vector2 v) => new Vector3(v.x, v.y, 0);
    }
    public struct Vector3 { public float x, y, z; public Vector3(float x, float y, float z) { this.x = x; this.y = y; this.z = z; } }
    public struct Vector2Int
    {
        public int x, y;
        public Vector2Int(int x, int y) { this.x = x; this.y = y; }
    }
    public struct Rect
    {
        public float x, y, width, height, xMin, xMax, yMin, yMax;
        public Vector2 center => default;
    }
    public struct Color
    {
        public float r, g, b, a;
        public Color(float r, float g, float b, float a = 1) { this.r = r; this.g = g; this.b = b; this.a = a; }
        public static Color white => new Color(1, 1, 1);
        public static Color magenta => new Color(1, 0, 1);
        public static Color clear => new Color(0, 0, 0, 0);
        public static Color Lerp(Color a, Color b, float t) => a;
        public static bool operator ==(Color a, Color b) => a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
        public static bool operator !=(Color a, Color b) => !(a == b);
        public override bool Equals(object o) => o is Color c && c == this;
        public override int GetHashCode() => 0;
        public static implicit operator Color(Color32 c) => new Color(c.r / 255f, c.g / 255f, c.b / 255f, c.a / 255f);
    }
    public struct Color32
    {
        public byte r, g, b, a;
        public Color32(byte r, byte g, byte b, byte a) { this.r = r; this.g = g; this.b = b; this.a = a; }
        public static implicit operator Color32(Color c) => default;
    }
    public static class ColorUtility { public static bool TryParseHtmlString(string s, out Color c) { c = default; return true; } }
    public static class Mathf
    {
        public const float PI = 3.14159265f, Deg2Rad = PI / 180;
        public static float Sin(float f) => (float)Math.Sin(f);
        public static float Cos(float f) => (float)Math.Cos(f);
        public static float Max(float a, float b) => Math.Max(a, b);
        public static int Max(int a, int b) => Math.Max(a, b);
        public static float Max(params float[] v) => v[0];
        public static float Min(float a, float b) => Math.Min(a, b);
        public static int Min(int a, int b) => Math.Min(a, b);
        public static float Clamp(float v, float a, float b) => v;
        public static int Clamp(int v, int a, int b) => v;
        public static float Clamp01(float v) => v;
        public static float Abs(float v) => Math.Abs(v);
        public static float Round(float v) => v;
        public static float Sqrt(float v) => v;
        public static float Pow(float a, float b) => a;
        public static float Repeat(float a, float b) => a;
        public static float Lerp(float a, float b, float t) => a;
        public static int RoundToInt(float v) => 0;
        public static int CeilToInt(float v) => 0;
        public static int FloorToInt(float v) => 0;
    }
    public static class Random { public static float value => 0; }
    public class Object
    {
        public string name;
        public static void Destroy(Object o) { }
        public static T Instantiate<T>(T o) where T : Object => o;
        public static void DontDestroyOnLoad(Object o) { }
        public static T FindAnyObjectByType<T>() where T : Object => null;
    }
    public class Transform : Component { public void SetParent(Transform p, bool w) { } }
    public class Component : Object
    {
        public GameObject gameObject;
        public Transform transform;
        public string tag;
    }
    public sealed class GameObject : Object
    {
        public GameObject(string n) { }
        public Transform transform;
        public string tag;
        public T AddComponent<T>() where T : Component => null;
        public void SetActive(bool v) { }
    }
    public class Behaviour : Component { public bool enabled; }
    public class MonoBehaviour : Behaviour { }
    public class ScriptableObject : Object { public static T CreateInstance<T>() where T : ScriptableObject => null; }
    public enum CameraClearFlags { Skybox, SolidColor }
    public sealed class Camera : Behaviour
    {
        public static Camera main;
        public CameraClearFlags clearFlags;
        public Color backgroundColor;
        public bool orthographic;
        public int cullingMask;
    }
    public enum TextureFormat { RGBA32 }
    public enum TextureWrapMode { Clamp }
    public enum FilterMode { Bilinear }
    public class Texture : Object { public TextureWrapMode wrapMode; public FilterMode filterMode; }
    public sealed class Texture2D : Texture
    {
        public Texture2D(int w, int h, TextureFormat f, bool mip) { }
        public void SetPixels32(Color32[] c) { }
        public void Apply(bool a, bool b) { }
    }
    public static class Resources { public static T Load<T>(string p) where T : Object => null; }
    public static class Application
    {
        public static int targetFrameRate;
        public static bool isMobilePlatform;
        public static string persistentDataPath;
    }
    public static class Screen { public static int width, height; public static float dpi; public static Rect safeArea; }
    public static class Time { public static float unscaledDeltaTime; public static double realtimeSinceStartupAsDouble; }
    public static class PlayerPrefs
    {
        public static void SetString(string k, string v) { }
        public static string GetString(string k, string d) => d;
        public static void DeleteKey(string k) { }
        public static void Save() { }
    }
    public static class JsonUtility
    {
        public static string ToJson(object o) => "";
        public static T FromJson<T>(string j) => default;
    }
    public static class Debug { public static void Log(object o) { } public static void LogWarning(object o) { } }
    public enum KeyCode { None = 0, Return = 13, Escape = 27, Space = 32, Alpha1 = 49, Alpha2, Alpha3, Alpha4, Keypad1 = 257, Keypad2, Keypad3, Keypad4, KeypadEnter = 271 }
    public enum RuntimeInitializeLoadType { AfterSceneLoad }
    public sealed class RuntimeInitializeOnLoadMethodAttribute : Attribute { public RuntimeInitializeOnLoadMethodAttribute(RuntimeInitializeLoadType t) { } }
}

namespace UnityEngine.SceneManagement
{
    public struct Scene { public string path; public int rootCount; public bool isDirty; }
    public static class SceneManager
    {
        public static Scene GetActiveScene() => default;
        public static void MoveGameObjectToScene(GameObject g, Scene s) { }
    }
}

namespace UnityEngine.UIElements
{
    public enum PickingMode { Position, Ignore }
    public enum TrickleDown { NoTrickleDown, TrickleDown }
    public enum ScrollerVisibility { Auto, AlwaysVisible, Hidden }
    public enum ScrollViewMode { Vertical }
    public enum DisplayStyle { Flex, None }
    public enum Position { Relative, Absolute }
    public enum StyleKeyword { Undefined, Null, Auto, None, Initial }
    public enum LineCap { Butt, Round }
    public enum LineJoin { Miter, Bevel, Round }
    public enum ArcDirection { Clockwise, CounterClockwise }
    public enum FillRule { NonZero, OddEven }
    public enum PanelScaleMode { ConstantPixelSize, ConstantPhysicalSize, ScaleWithScreenSize }
    public struct Length { public static Length Percent(float v) => default; public static implicit operator Length(float v) => default; }
    public struct Translate { public Translate(Length x, Length y) { } }
    public struct Background { public static Background FromTexture2D(Texture2D t) => default; }
    public struct Angle { public static Angle Degrees(float v) => default; public static Angle Radians(float v) => default; }
    public struct StyleLength
    {
        public static implicit operator StyleLength(float v) => default;
        public static implicit operator StyleLength(Length v) => default;
        public static implicit operator StyleLength(StyleKeyword v) => default;
    }
    public struct StyleFloat { public static implicit operator StyleFloat(float v) => default; }
    public struct StyleColor { public static implicit operator StyleColor(Color v) => default; }
    public struct StyleEnum<T> where T : struct, IConvertible { public static implicit operator StyleEnum<T>(T v) => default; }
    public struct StyleTranslate { public static implicit operator StyleTranslate(Translate v) => default; }
    public struct StyleBackground { public static implicit operator StyleBackground(Background v) => default; }
    public interface IStyle
    {
        StyleLength width { get; set; }
        StyleLength height { get; set; }
        StyleLength left { get; set; }
        StyleLength top { get; set; }
        StyleLength right { get; set; }
        StyleLength bottom { get; set; }
        StyleLength fontSize { get; set; }
        StyleColor color { get; set; }
        StyleColor backgroundColor { get; set; }
        StyleColor borderLeftColor { get; set; }
        StyleColor unityTextOutlineColor { get; set; }
        StyleFloat unityTextOutlineWidth { get; set; }
        StyleFloat flexGrow { get; set; }
        StyleLength paddingTop { get; set; }
        StyleLength paddingBottom { get; set; }
        StyleLength paddingLeft { get; set; }
        StyleLength paddingRight { get; set; }
        StyleEnum<DisplayStyle> display { get; set; }
        StyleEnum<Position> position { get; set; }
        StyleTranslate translate { get; set; }
        StyleBackground backgroundImage { get; set; }
    }
    public interface IResolvedStyle { Color color { get; } }
    public sealed class Painter2D
    {
        public Color fillColor, strokeColor;
        public float lineWidth;
        public LineCap lineCap;
        public LineJoin lineJoin;
        public void BeginPath() { }
        public void MoveTo(Vector2 p) { }
        public void LineTo(Vector2 p) { }
        public void Arc(Vector2 c, float r, Angle a0, Angle a1, ArcDirection d = ArcDirection.Clockwise) { }
        public void ArcTo(Vector2 p1, Vector2 p2, float r) { }
        public void QuadraticCurveTo(Vector2 c, Vector2 p) { }
        public void BezierCurveTo(Vector2 c1, Vector2 c2, Vector2 p) { }
        public void ClosePath() { }
        public void Fill(FillRule r = FillRule.NonZero) { }
        public void Stroke() { }
    }
    public sealed class MeshGenerationContext { public Painter2D painter2D => null; }
    public delegate void EventCallback<in T>(T evt);
    public class EventBase { public void StopPropagation() { } }
    public class EventBase<T> : EventBase { }
    public class PointerEventBase<T> : EventBase<T> { public int pointerId; public Vector3 localPosition, position; }
    public sealed class PointerDownEvent : PointerEventBase<PointerDownEvent> { public IEventHandler target; }
    public sealed class PointerMoveEvent : PointerEventBase<PointerMoveEvent> { }
    public sealed class PointerUpEvent : PointerEventBase<PointerUpEvent> { }
    public sealed class PointerCancelEvent : PointerEventBase<PointerCancelEvent> { }
    public sealed class WheelEvent : EventBase<WheelEvent> { public Vector3 delta; public Vector2 localMousePosition; }
    public sealed class KeyDownEvent : EventBase<KeyDownEvent> { public KeyCode keyCode; }
    public sealed class ClickEvent : EventBase<ClickEvent> { }
    public sealed class GeometryChangedEvent : EventBase<GeometryChangedEvent> { }
    public sealed class DetachFromPanelEvent : EventBase<DetachFromPanelEvent> { }
    public sealed class CustomStyleResolvedEvent : EventBase<CustomStyleResolvedEvent> { }
    public interface IEventHandler { }
    public interface IVisualElementScheduledItem { IVisualElementScheduledItem ExecuteLater(long ms); }
    public interface IVisualElementScheduler { IVisualElementScheduledItem Execute(Action a); }
    public class Focusable : IEventHandler
    {
        public bool focusable { get; set; }
        public void Focus() { }
    }
    public class VisualElement : Focusable
    {
        public string name;
        public IStyle style => null;
        public IResolvedStyle resolvedStyle => null;
        public Rect contentRect => default;
        public Rect layout => default;
        public PickingMode pickingMode { get; set; }
        public Action<MeshGenerationContext> generateVisualContent;
        public void MarkDirtyRepaint() { }
        public void Add(VisualElement c) { }
        public void Insert(int i, VisualElement c) { }
        public void Clear() { }
        public void RemoveAt(int i) { }
        public int childCount => 0;
        public VisualElement this[int i] => null;
        public void AddToClassList(string c) { }
        public void RemoveFromClassList(string c) { }
        public void EnableInClassList(string c, bool on) { }
        public void ToggleInClassList(string c) { }
        public bool ClassListContains(string c) => false;
        public void RegisterCallback<T>(EventCallback<T> cb, TrickleDown t = TrickleDown.NoTrickleDown) where T : EventBase<T>, new() { }
        public IVisualElementScheduler schedule => null;
        public void RemoveFromHierarchy() { }
        public void SetEnabled(bool v) { }
        public bool enabledSelf => true;
        public UsageHints usageHints { get; set; }
        public void UnregisterCallback<T>(EventCallback<T> cb, TrickleDown t = TrickleDown.NoTrickleDown) where T : EventBase<T>, new() { }
        public void AddManipulator(IManipulator m) { }
    }
    public enum UsageHints { None, DynamicTransform }
    public interface IManipulator { }
    public abstract class Manipulator : IManipulator
    {
        public VisualElement target { get; set; }
        protected abstract void RegisterCallbacksOnTarget();
        protected abstract void UnregisterCallbacksFromTarget();
    }
    public abstract class PointerManipulator : Manipulator { }
    public class TextElement : VisualElement { public string text { get; set; } }
    public class Label : TextElement { public Label() { } public Label(string t) { } }
    public class Button : TextElement
    {
        public Button() { }
        public Button(Action a) { }
        public event Action clicked;
    }
    public class ScrollView : VisualElement
    {
        public enum TouchScrollBehavior { Unrestricted, Elastic, Clamped }
        public ScrollerVisibility verticalScrollerVisibility, horizontalScrollerVisibility;
        public ScrollViewMode mode;
        public TouchScrollBehavior touchScrollBehavior;
        public Vector2 scrollOffset;
    }
    public struct UQueryBuilder<T> where T : VisualElement { public void ForEach(Action<T> a) { } }
    public static class UQueryExtensions
    {
        public static VisualElement Q(this VisualElement e, string name = null, string className = null) => null;
        public static T Q<T>(this VisualElement e, string name = null, string className = null) where T : VisualElement => null;
        public static UQueryBuilder<T> Query<T>(this VisualElement e, string name = null, string className = null) where T : VisualElement => default;
    }
    public static class PointerCaptureHelper
    {
        public static void CapturePointer(this IEventHandler h, int id) { }
        public static bool HasPointerCapture(this IEventHandler h, int id) => false;
        public static void ReleasePointer(this IEventHandler h, int id) { }
    }
    public class StyleSheet : ScriptableObject { }
    public class ThemeStyleSheet : StyleSheet { }
    public class VisualTreeAsset : ScriptableObject { }
    public class PanelSettings : ScriptableObject
    {
        public ThemeStyleSheet themeStyleSheet;
        public PanelScaleMode scaleMode;
        public float scale;
    }
    public sealed class UIDocument : MonoBehaviour
    {
        public PanelSettings panelSettings;
        public VisualTreeAsset visualTreeAsset;
        public VisualElement rootVisualElement => null;
    }
}

namespace UnityEditor
{
    public sealed class InitializeOnLoadAttribute : Attribute { }
    public sealed class MenuItem : Attribute { public MenuItem(string p) { } }
    public static class EditorApplication
    {
        public delegate void CallbackFunction();
        public static CallbackFunction delayCall;
        public static bool isPlayingOrWillChangePlaymode;
    }
    public sealed class EditorBuildSettingsScene { public EditorBuildSettingsScene(string p, bool e) { } }
    public static class EditorBuildSettings { public static EditorBuildSettingsScene[] scenes; }
    public enum UIOrientation { AutoRotation }
    public static class PlayerSettings
    {
        public static string productName;
        public static UIOrientation defaultInterfaceOrientation;
        public static bool allowedAutorotateToPortrait, allowedAutorotateToPortraitUpsideDown, allowedAutorotateToLandscapeLeft, allowedAutorotateToLandscapeRight;
    }
    public static class AssetDatabase
    {
        public static void SaveAssets() { }
        public static T LoadAssetAtPath<T>(string p) where T : UnityEngine.Object => null;
        public static void CreateAsset(UnityEngine.Object o, string p) { }
    }
}

namespace UnityEditor.SceneManagement
{
    using UnityEngine.SceneManagement;
    public enum NewSceneSetup { EmptyScene }
    public enum NewSceneMode { Single, Additive }
    public enum OpenSceneMode { Single }
    public static class EditorSceneManager
    {
        public static Scene NewScene(NewSceneSetup s, NewSceneMode m) => default;
        public static bool SaveScene(Scene s, string p) => true;
        public static bool CloseScene(Scene s, bool r) => true;
        public static Scene OpenScene(string p, OpenSceneMode m) => default;
        public static bool SaveCurrentModifiedScenesIfUserWantsTo() => true;
    }
}
