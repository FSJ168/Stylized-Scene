using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class MissingScriptCleaner
{
    [MenuItem("Tools/Missing Script/清理当前场景")]
    private static void CleanCurrentScene()
    {
        Scene scene = SceneManager.GetActiveScene();
        GameObject[] roots = scene.GetRootGameObjects();

        int objectCount = 0;
        int scriptCount = 0;

        foreach (GameObject root in roots)
        {
            Transform[] transforms = root.GetComponentsInChildren<Transform>(true);

            foreach (Transform transform in transforms)
            {
                GameObject go = transform.gameObject;
                int count = GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(go);

                if (count <= 0)
                    continue;

                Undo.RegisterCompleteObjectUndo(go, "Remove Missing Scripts");
                GameObjectUtility.RemoveMonoBehavioursWithMissingScript(go);

                objectCount++;
                scriptCount += count;

                Debug.Log($"删除 Missing Script：{go.name}，数量：{count}", go);
            }
        }

        if (scriptCount > 0)
            EditorSceneManager.MarkSceneDirty(scene);

        Debug.Log($"场景清理完成：共处理 {objectCount} 个物体，删除 {scriptCount} 个 Missing Script。");
    }

    [MenuItem("Tools/Missing Script/清理项目全部 Prefab")]
    private static void CleanAllPrefabs()
    {
        string[] guids = AssetDatabase.FindAssets("t:Prefab");

        int prefabCount = 0;
        int objectCount = 0;
        int scriptCount = 0;

        foreach (string guid in guids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            GameObject prefabRoot = PrefabUtility.LoadPrefabContents(path);
            bool changed = false;

            Transform[] transforms = prefabRoot.GetComponentsInChildren<Transform>(true);

            foreach (Transform transform in transforms)
            {
                GameObject go = transform.gameObject;
                int count = GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(go);

                if (count <= 0)
                    continue;

                GameObjectUtility.RemoveMonoBehavioursWithMissingScript(go);

                changed = true;
                objectCount++;
                scriptCount += count;

                Debug.Log($"Prefab Missing Script：{path} / {go.name}，数量：{count}");
            }

            if (changed)
            {
                PrefabUtility.SaveAsPrefabAsset(prefabRoot, path);
                prefabCount++;
            }

            PrefabUtility.UnloadPrefabContents(prefabRoot);
        }

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log($"Prefab 清理完成：修改 {prefabCount} 个 Prefab，处理 {objectCount} 个物体，删除 {scriptCount} 个 Missing Script。");
    }
}