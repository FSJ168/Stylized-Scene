#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace ArtistTools
{
    /// <summary>Unity 2022+，无第三方依赖。PNG 的每一行使用相同的横向 Ramp。</summary>
    public sealed class RampGeneratorWindow : EditorWindow
    {
        [Serializable]
        private sealed class Stop
        {
            public float position;
            public Color color;
            public Stop(float position, Color color) { this.position = position; this.color = color; }
        }

        [Serializable]
        private sealed class Channel
        {
            public float[] samples;
            public float fallback;
            public Channel(float fallback) { this.fallback = fallback; }
            public float Evaluate(float t)
            {
                if (samples == null || samples.Length < 2) return fallback;
                float index = Mathf.Clamp01(t) * (samples.Length - 1);
                int left = Mathf.FloorToInt(index);
                return Mathf.Lerp(samples[left], samples[Mathf.Min(left + 1, samples.Length - 1)], index - left);
            }
        }

        [SerializeField] private int mode; // 0: 灰度点，1: RGB 点，2: 灰度曲线，3: 通道合并
        [SerializeField] private Channel[] channels = { new Channel(0), new Channel(0), new Channel(0), new Channel(1) };
        [SerializeField] private int extractChannel;
        private readonly string[] channelNames = { "R", "G", "B", "A" };
        private readonly Texture2D[] channelPreviews = new Texture2D[4];
        [SerializeField] private List<Stop> gray = new List<Stop> { new Stop(0, Color.black), new Stop(1, Color.white) };
        [SerializeField] private List<Stop> rgb = new List<Stop> { new Stop(0, Color.black), new Stop(1, Color.white) };
        [SerializeField] private AnimationCurve curve = AnimationCurve.Linear(0, 0, 1, 1);
        [SerializeField] private int interpolation;
        [SerializeField] private bool reverse;
        [SerializeField] private int width = 256;
        [SerializeField] private int height = 16;
        [SerializeField] private string rampName = "NewRamp";
        [SerializeField] private string folder = "Assets/Ramps";
        [SerializeField] private bool srgb;
        [SerializeField] private bool pointFilter;
        [SerializeField] private bool uniqueName = true;
        private Texture2D preview;
        private bool dirty = true;
        private Vector2 scroll;
        private int selected;
        private int dragging = -1;
        private string lastExport;
        private string status;
        private MessageType statusType;
        private List<Stop> Stops { get { return mode == 1 ? rgb : gray; } }
        private string PrefKey { get { return "ArtistTools.RampGenerator.v1." + Application.dataPath; } }

        [MenuItem("Tools/美术工具/Ramp 生成器")]
        public static void Open()
        {
            var window = GetWindow<RampGeneratorWindow>();
            window.titleContent = new GUIContent("Ramp 生成器");
            window.minSize = new Vector2(460, 620);
            window.Show();
        }

        private void OnEnable()
        {
            if (EditorPrefs.HasKey(PrefKey))
            {
                try { EditorJsonUtility.FromJsonOverwrite(EditorPrefs.GetString(PrefKey), this); }
                catch (Exception) { EditorPrefs.DeleteKey(PrefKey); }
            }
            Undo.undoRedoPerformed += OnUndo;
            dirty = true;
        }

        private void OnDisable()
        {
            EditorPrefs.SetString(PrefKey, EditorJsonUtility.ToJson(this));
            Undo.undoRedoPerformed -= OnUndo;
            if (preview != null) DestroyImmediate(preview);
            foreach (var item in channelPreviews) if (item != null) DestroyImmediate(item);
        }

        private void OnUndo() { dirty = true; selected = 0; dragging = -1; Repaint(); }
        private void Change(string label)
        {
            Undo.RecordObject(this, label);
            dirty = true;
        }

        private void OnGUI()
        {
            float previousLabelWidth = EditorGUIUtility.labelWidth;
            EditorGUIUtility.labelWidth = 112;
            scroll = EditorGUILayout.BeginScrollView(scroll);
            GUILayout.Space(10);
            GUILayout.Label("RAMP  /  渐变贴图生成器", EditorStyles.boldLabel);
            EditorGUILayout.LabelField("控制明暗层次与颜色过渡 · 修改后实时更新", EditorStyles.miniLabel);
            GUILayout.Space(8);

            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("01  制作方式", EditorStyles.boldLabel);
            int nextMode = GUILayout.Toolbar(mode, new[] { "灰度点", "RGB 点", "灰度曲线", "通道合并" }, GUILayout.Height(28));
            if (nextMode != mode) { Change("切换 Ramp 模式"); mode = nextMode; selected = 0; }
            GUILayout.Space(8);
            if (mode == 2) DrawCurve();
            else if (mode != 3) DrawStops();
            else EditorGUILayout.HelpBox("下方 R / G / B / A 槽分别储存独立的灰度结果，按相同的横向位置合并为 RGBA。未生成的通道使用默认值。", MessageType.Info);
            EditorGUILayout.EndVertical();

            GUILayout.Space(8);
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("02  实时预览", EditorStyles.boldLabel);
            DrawPreview();
            if (mode != 3)
            {
                bool nextReverse = EditorGUILayout.Toggle("反向输出", reverse);
                if (nextReverse != reverse) { Change("反向 Ramp"); reverse = nextReverse; }
            }
            EditorGUILayout.LabelField("预览显示原始数值；材质最终效果取决于采样与色彩空间。", EditorStyles.wordWrappedMiniLabel);
            EditorGUILayout.EndVertical();

            GUILayout.Space(8);
            DrawChannels();
            GUILayout.Space(8);
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("04  导出 PNG", EditorStyles.boldLabel);
            DrawExportSettings();
            EditorGUILayout.EndVertical();
            if (!string.IsNullOrEmpty(status)) EditorGUILayout.HelpBox(status, statusType);
            GUILayout.Space(8);
            EditorGUILayout.EndScrollView();
            EditorGUIUtility.labelWidth = previousLabelWidth;
        }

        private void DrawCurve()
        {
            EditorGUILayout.HelpBox("点击曲线打开编辑器；双击添加关键帧，右键调整切线。X 为位置，Y 为灰度，输出限制在 0–1。", MessageType.Info);
            // CurveField 可原地修改对象，因此修改前保留 Undo 快照。
            Undo.RecordObject(this, "编辑灰度曲线");
            EditorGUI.BeginChangeCheck();
            curve = EditorGUILayout.CurveField(new GUIContent("灰度曲线"), curve, new Color(0.4f, 0.85f, 1f), new Rect(0, 0, 1, 1), GUILayout.Height(100));
            if (EditorGUI.EndChangeCheck()) dirty = true;
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("线性")) { Change("线性曲线"); curve = AnimationCurve.Linear(0, 0, 1, 1); }
            if (GUILayout.Button("柔和过渡")) { Change("柔和曲线"); curve = AnimationCurve.EaseInOut(0, 0, 1, 1); }
            if (GUILayout.Button("中间提亮")) { Change("中间提亮"); curve = new AnimationCurve(new Keyframe(0, 0), new Keyframe(0.5f, 1), new Keyframe(1, 0)); }
            EditorGUILayout.EndHorizontal();
        }

        private void DrawStops()
        {
            int next = EditorGUILayout.Popup("过渡方式", interpolation, new[] { "线性", "平滑", "阶梯（左侧颜色）" });
            if (next != interpolation) { Change("修改过渡方式"); interpolation = next; }
            EditorGUILayout.LabelField("点击色条添加点；拖动下方色块移动点；下方可精确编辑。", EditorStyles.wordWrappedMiniLabel);
            DrawStopBar();
            selected = Mathf.Clamp(selected, 0, Stops.Count - 1);
            var stop = Stops[selected];
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("◀", GUILayout.Width(28))) selected = (selected + Stops.Count - 1) % Stops.Count;
            GUILayout.Label("选中点 " + (selected + 1) + " / " + Stops.Count, EditorStyles.centeredGreyMiniLabel);
            if (GUILayout.Button("▶", GUILayout.Width(28))) selected = (selected + 1) % Stops.Count;
            EditorGUILayout.EndHorizontal();
            stop = Stops[selected];
            float pos = EditorGUILayout.Slider("位置", stop.position, 0, 1);
            if (pos != stop.position) { Change("移动渐变点"); MoveStop(stop, pos); }
            if (mode == 0)
            {
                float value = EditorGUILayout.Slider("灰度", stop.color.r, 0, 1);
                if (value != stop.color.r) { Change("修改灰度"); stop.color = new Color(value, value, value, 1); }
            }
            else
            {
                Color color = EditorGUILayout.ColorField(new GUIContent("颜色"), stop.color, true, false, false);
                if (color != stop.color) { Change("修改颜色"); color.a = 1; stop.color = color; }
            }
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button("＋ 添加点")) AddStop(FindGapMidpoint());
            using (new EditorGUI.DisabledScope(Stops.Count <= 2))
            {
                if (GUILayout.Button("删除选中点")) { Change("删除渐变点"); Stops.RemoveAt(selected); selected = Mathf.Min(selected, Stops.Count - 1); }
            }
            EditorGUILayout.EndHorizontal();
        }

        private void DrawStopBar()
        {
            Rect area = GUILayoutUtility.GetRect(1, 60, GUILayout.ExpandWidth(true));
            Rect bar = new Rect(area.x + 7, area.y + 4, area.width - 14, 30);
            EnsurePreview();
            // 编辑色条始终保持原始方向；反向仅影响输出预览。
            GUI.DrawTextureWithTexCoords(bar, preview, reverse ? new Rect(1, 0, -1, 1) : new Rect(0, 0, 1, 1));
            int id = GUIUtility.GetControlID("RampStops".GetHashCode(), FocusType.Passive, area);
            Event e = Event.current;
            int hit = -1;
            for (int i = 0; i < Stops.Count; ++i)
            {
                Rect handle = new Rect(bar.x + Stops[i].position * bar.width - 6, bar.yMax + 3, 12, 18);
                EditorGUI.DrawRect(handle, i == selected ? new Color(0.2f, 0.65f, 1) : Color.gray);
                EditorGUI.DrawRect(new Rect(handle.x + 2, handle.y + 2, 8, 14), Stops[i].color);
                if (handle.Contains(e.mousePosition)) hit = i;
            }
            if (e.type == EventType.MouseDown && e.button == 0)
            {
                if (hit >= 0)
                {
                    selected = dragging = hit;
                    GUIUtility.hotControl = id;
                    Change("拖动渐变点");
                    e.Use(); Repaint();
                }
                else if (bar.Contains(e.mousePosition)) { AddStop(Mathf.InverseLerp(bar.x, bar.xMax, e.mousePosition.x)); e.Use(); }
            }
            else if (e.type == EventType.MouseDrag && GUIUtility.hotControl == id && dragging >= 0)
            {
                MoveStop(Stops[dragging], Mathf.InverseLerp(bar.x, bar.xMax, e.mousePosition.x));
                dragging = selected;
                dirty = true; e.Use(); Repaint();
            }
            else if (e.type == EventType.MouseUp && GUIUtility.hotControl == id)
            {
                GUIUtility.hotControl = 0; dragging = -1; e.Use();
            }
        }

        private void MoveStop(Stop stop, float pos)
        {
            // 保持唯一位置，避免重叠点在排序后产生不确定的颜色。
            foreach (var other in Stops)
                if (other != stop && Mathf.Abs(other.position - pos) < 0.0001f) return;
            stop.position = Mathf.Clamp01(pos);
            Stops.Sort((a, b) => a.position.CompareTo(b.position));
            selected = Stops.IndexOf(stop);
        }

        private float FindGapMidpoint()
        {
            float start = 0, length = Stops[0].position;
            for (int i = 1; i < Stops.Count; i++)
                if (Stops[i].position - Stops[i - 1].position > length)
                { start = Stops[i - 1].position; length = Stops[i].position - start; }
            float end = Stops[Stops.Count - 1].position;
            if (1 - end > length) { start = end; length = 1 - end; }
            return start + length * 0.5f;
        }

        private void AddStop(float pos)
        {
            for (int i = 0; i < Stops.Count; i++)
                if (Mathf.Abs(Stops[i].position - pos) < 0.0001f) { selected = i; return; }
            Color color = EvaluateStops(pos);
            Change("添加渐变点");
            var stop = new Stop(pos, color);
            Stops.Add(stop);
            MoveStop(stop, pos);
        }

        private Color EvaluateStops(float t)
        {
            var stops = Stops;
            if (t <= stops[0].position) return stops[0].color;
            for (int i = 1; i < stops.Count; i++)
            {
                if (t < stops[i].position)
                {
                    float u = Mathf.InverseLerp(stops[i - 1].position, stops[i].position, t);
                    if (interpolation == 2) u = 0;
                    else if (interpolation == 1) u = u * u * (3 - 2 * u);
                    return Color.Lerp(stops[i - 1].color, stops[i].color, u);
                }
            }
            return stops[stops.Count - 1].color;
        }

        private Color Evaluate(float t)
        {
            if (mode == 3) return new Color(channels[0].Evaluate(t), channels[1].Evaluate(t), channels[2].Evaluate(t), channels[3].Evaluate(t));
            if (reverse) t = 1 - t;
            if (mode != 2) return EvaluateStops(t);
            float value = curve == null || curve.length == 0 ? t : curve.Evaluate(t);
            value = float.IsNaN(value) ? 0 : Mathf.Clamp01(value);
            return new Color(value, value, value, 1);
        }

        private Color32[] CreatePixels(int w, int h)
        {
            var pixels = new Color32[w * h];
            for (int x = 0; x < w; x++) pixels[x] = Evaluate(x / (float)(w - 1));
            for (int y = 1; y < h; y++) Array.Copy(pixels, 0, pixels, y * w, w);
            return pixels;
        }

        private void EnsurePreview()
        {
            if (preview != null && preview.width != width) { DestroyImmediate(preview); preview = null; }
            if (preview == null)
            {
                preview = new Texture2D(width, 1, TextureFormat.RGBA32, false, true);
                preview.hideFlags = HideFlags.HideAndDontSave;
                preview.wrapMode = TextureWrapMode.Clamp;
                dirty = true;
            }
            preview.filterMode = pointFilter ? FilterMode.Point : FilterMode.Bilinear;
            if (!dirty) return;
            preview.SetPixels32(CreatePixels(width, 1));
            preview.Apply(false, false);
            dirty = false;
        }

        private void DrawPreview()
        {
            EnsurePreview();
            Rect rect = GUILayoutUtility.GetRect(1, 72, GUILayout.ExpandWidth(true));
            GUI.DrawTexture(rect, preview, ScaleMode.StretchToFill, false);
            EditorGUILayout.BeginHorizontal();
            GUILayout.Label("0", EditorStyles.miniLabel);
            GUILayout.FlexibleSpace();
            GUILayout.Label(width + " × " + height + " px   /   " + (mode == 3 ? "RGBA" : "RGB") + " 8-bit", EditorStyles.miniLabel);
            GUILayout.FlexibleSpace();
            GUILayout.Label("1", EditorStyles.miniLabel);
            EditorGUILayout.EndHorizontal();
        }

        private void DrawChannels()
        {
            EditorGUILayout.BeginVertical(EditorStyles.helpBox);
            GUILayout.Label("03  单通道生成 / 合并", EditorStyles.boldLabel);
            if (mode == 1)
                extractChannel = EditorGUILayout.Popup("提取灰度来源", extractChannel, new[] { "R · 红通道", "G · 绿通道", "B · 蓝通道", "亮度 · 0.299R + 0.587G + 0.114B" });
            EditorGUILayout.LabelField("先编辑上方 Ramp，再点击目标通道的“生成”。各槽独立保留，不随源 Ramp 改动。", EditorStyles.wordWrappedMiniLabel);
            for (int i = 0; i < 4; i++)
            {
                Channel channel = channels[i];
                bool hasData = channel.samples != null && channel.samples.Length >= 2;
                EditorGUILayout.BeginHorizontal();
                GUILayout.Label(channelNames[i], EditorStyles.boldLabel, GUILayout.Width(18));
                Rect rect = GUILayoutUtility.GetRect(60, 24, GUILayout.ExpandWidth(true));
                if (Event.current.type == EventType.Repaint)
                {
                    if (channelPreviews[i] == null)
                    {
                        channelPreviews[i] = new Texture2D(256, 1, TextureFormat.RGB24, false, true);
                        channelPreviews[i].hideFlags = HideFlags.HideAndDontSave;
                        channelPreviews[i].wrapMode = TextureWrapMode.Clamp;
                    }
                    var pixels = new Color32[256];
                    for (int x = 0; x < pixels.Length; x++)
                    {
                        float v = channel.Evaluate(x / 255f);
                        pixels[x] = new Color(v, v, v, 1);
                    }
                    channelPreviews[i].SetPixels32(pixels);
                    channelPreviews[i].Apply(false, false);
                    GUI.DrawTexture(rect, channelPreviews[i], ScaleMode.StretchToFill, false);
                }
                GUILayout.Label(hasData ? channel.samples.Length + " 点" : "默认 " + channel.fallback, EditorStyles.miniLabel, GUILayout.Width(55));
                using (new EditorGUI.DisabledScope(mode == 3))
                {
                    if (GUILayout.Button("生成", GUILayout.Width(46)))
                    {
                        Change("生成 " + channelNames[i] + " 通道");
                        channel.samples = new float[width];
                        for (int x = 0; x < width; x++)
                        {
                            Color c = Evaluate(x / (float)(width - 1));
                            channel.samples[x] = mode != 1 ? c.r : extractChannel == 3 ? c.grayscale : c[extractChannel];
                        }
                        status = "已生成 " + channelNames[i] + " 通道灰度，可继续编辑其它通道或合并导出。";
                        statusType = MessageType.Info;
                    }
                }
                if (GUILayout.Button("保存", GUILayout.Width(46)))
                {
                    string path, error;
                    if (TryGetOutputPath(out path, out error)) Export(path.Substring(0, path.Length - 4) + "_" + channelNames[i] + ".png", i);
                    else { status = error; statusType = MessageType.Warning; }
                }
                using (new EditorGUI.DisabledScope(!hasData))
                    if (GUILayout.Button("清空", GUILayout.Width(46))) { Change("清空通道"); channel.samples = null; }
                EditorGUILayout.EndHorizontal();
            }
            EditorGUILayout.LabelField("保存：独立灰度 PNG；合并：R/G/B 默认 0，A 默认 1。不同采样数按 0–1 位置线性重采样。", EditorStyles.wordWrappedMiniLabel);
            if (GUILayout.Button("合并 R / G / B / A 并预览", GUILayout.Height(26))) { Change("合并通道"); mode = 3; }
            if (mode == 3) EditorGUILayout.LabelField("上方预览显示合并 RGB（忽略透明度）；A 的实际内容请查看 A 槽。", EditorStyles.wordWrappedMiniLabel);
            EditorGUILayout.EndVertical();
        }

        private void DrawExportSettings()
        {
            rampName = EditorGUILayout.TextField("贴图名称", rampName);
            EditorGUILayout.BeginHorizontal();
            folder = EditorGUILayout.TextField("生成文件夹", folder);
            if (GUILayout.Button("选择…", GUILayout.Width(60)))
            {
                string picked = EditorUtility.OpenFolderPanel("选择 Assets 内的文件夹", Application.dataPath, "");
                if (!string.IsNullOrEmpty(picked))
                {
                    string relative = FileUtil.GetProjectRelativePath(picked.Replace('\\', '/'));
                    if (relative == "Assets" || relative.StartsWith("Assets/", StringComparison.Ordinal)) folder = relative;
                    else { status = "请选择当前项目 Assets 内的文件夹。"; statusType = MessageType.Warning; }
                }
            }
            EditorGUILayout.EndHorizontal();
            EditorGUI.BeginChangeCheck();
            int newWidth = EditorGUILayout.IntPopup("宽度 / 采样数", width, new[] { "64", "128", "256", "512", "1024", "2048", "4096" }, new[] { 64, 128, 256, 512, 1024, 2048, 4096 });
            int newHeight = EditorGUILayout.IntSlider("高度", height, 1, 256);
            bool newFilter = EditorGUILayout.Popup("纹理过滤", pointFilter ? 1 : 0, new[] { "Bilinear · 平滑采样", "Point · 像素 / 硬阶梯" }) == 1;
            if (EditorGUI.EndChangeCheck()) { Change("修改贴图尺寸与过滤"); width = newWidth; height = newHeight; pointFilter = newFilter; }
            using (new EditorGUI.DisabledScope(mode == 3))
                srgb = EditorGUILayout.Popup("采样色彩空间", mode == 3 ? 0 : srgb ? 1 : 0, new[] { "Linear · 灰度 / 数值数据", "sRGB · 颜色贴图" }) == 1;
            uniqueName = EditorGUILayout.Toggle("重名时自动编号", uniqueName);
            EditorGUILayout.LabelField("PNG 保存原始通道数值；色彩空间选项仅设置导入时的 sRGB 标记。", EditorStyles.wordWrappedMiniLabel);
            EditorGUILayout.LabelField("自动设置：Clamp · 无 Mipmap · 无压缩" + (mode == 3 ? " · RGBA 线性数据" : " · RGB"), EditorStyles.wordWrappedMiniLabel);
            string error;
            string path;
            bool valid = TryGetOutputPath(out path, out error);
            if (!valid) EditorGUILayout.HelpBox(error, MessageType.Warning);
            else EditorGUILayout.LabelField(path, EditorStyles.wordWrappedMiniLabel);
            using (new EditorGUI.DisabledScope(!valid))
                if (GUILayout.Button(mode == 3 ? "生成并保存合并 RGBA" : "生成并保存 Ramp", GUILayout.Height(34))) Export(path);
            using (new EditorGUI.DisabledScope(string.IsNullOrEmpty(lastExport)))
                if (GUILayout.Button("在 Project 中定位上次生成的贴图")) EditorGUIUtility.PingObject(AssetDatabase.LoadAssetAtPath<Texture2D>(lastExport));
        }

        private bool TryGetOutputPath(out string path, out string error)
        {
            path = null; error = null;
            string name = (rampName ?? "").Trim();
            if (name.EndsWith(".png", StringComparison.OrdinalIgnoreCase)) name = name.Substring(0, name.Length - 4);
            if (string.IsNullOrWhiteSpace(name) || name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || name.IndexOfAny(new[] { '/', '\\', ':', '*', '?', '"', '<', '>', '|' }) >= 0 || name.EndsWith(".") || name.EndsWith(" "))
            { error = "请输入有效文件名，不要包含路径或特殊字符。"; return false; }
            string stem = name.Split('.')[0].ToUpperInvariant();
            if (System.Text.RegularExpressions.Regex.IsMatch(stem, @"^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$"))
            { error = "文件名不能使用系统保留名称。"; return false; }
            try
            {
                string dir = (folder ?? "").Trim().Replace('\\', '/').TrimEnd('/');
                if (dir != "Assets" && !dir.StartsWith("Assets/", StringComparison.Ordinal))
                    throw new ArgumentException("生成文件夹必须位于当前项目 Assets 内，例如 Assets/Art/Ramps。");
                string root = Path.GetFullPath(Application.dataPath);
                string absolute = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(root), dir));
                if (absolute != root && !absolute.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
                    throw new ArgumentException("生成文件夹不能超出 Assets。");
                path = "Assets" + absolute.Substring(root.Length).Replace('\\', '/') + "/" + name + ".png";
                return true;
            }
            catch (Exception ex) { error = "路径无效：" + ex.Message; return false; }
        }

        private void Export(string path, int singleChannel = -1)
        {
            Texture2D texture = null;
            try
            {
                if (uniqueName) path = AssetDatabase.GenerateUniqueAssetPath(path);
                else if (File.Exists(path) && !EditorUtility.DisplayDialog("覆盖 Ramp？", "将覆盖 " + path + "，此操作不能撤销。", "覆盖", "取消")) return;
                bool packed = mode == 3 && singleChannel < 0;
                texture = new Texture2D(width, height, packed ? TextureFormat.RGBA32 : TextureFormat.RGB24, false, true);
                Color32[] pixels;
                if (singleChannel < 0) pixels = CreatePixels(width, height);
                else
                {
                    pixels = new Color32[width * height];
                    for (int x = 0; x < width; x++)
                    {
                        float value = channels[singleChannel].Evaluate(x / (float)(width - 1));
                        pixels[x] = new Color(value, value, value, 1);
                    }
                    for (int y = 1; y < height; y++) Array.Copy(pixels, 0, pixels, y * width, width);
                }
                texture.SetPixels32(pixels);
                texture.Apply(false, false);
                byte[] bytes = texture.EncodeToPNG();
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                File.WriteAllBytes(path, bytes);
                AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceSynchronousImport);
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) throw new IOException("PNG 已写入，但 Unity 未能取得纹理导入器。");
                importer.textureType = TextureImporterType.Default;
                importer.textureShape = TextureImporterShape.Texture2D;
                importer.sRGBTexture = singleChannel < 0 && !packed && srgb;
                importer.alphaSource = packed ? TextureImporterAlphaSource.FromInput : TextureImporterAlphaSource.None;
                importer.alphaIsTransparency = false;
                importer.mipmapEnabled = false;
                importer.streamingMipmaps = false;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.filterMode = pointFilter ? FilterMode.Point : FilterMode.Bilinear;
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                importer.crunchedCompression = false;
                importer.npotScale = TextureImporterNPOTScale.None;
                importer.maxTextureSize = Mathf.Max(32, Mathf.NextPowerOfTwo(Mathf.Max(width, height)));
                importer.isReadable = false;
                importer.SaveAndReimport();
                lastExport = path;
                status = "已生成：" + path;
                statusType = MessageType.Info;
                EditorGUIUtility.PingObject(AssetDatabase.LoadAssetAtPath<Texture2D>(path));
                EditorPrefs.SetString(PrefKey, EditorJsonUtility.ToJson(this));
            }
            catch (Exception ex)
            {
                status = "生成失败：" + ex.Message + "\n若 PNG 已写入，请检查目标文件和导入设置。";
                statusType = MessageType.Error;
                Debug.LogException(ex);
            }
            finally { if (texture != null) DestroyImmediate(texture); }
        }
    }
}
#endif
