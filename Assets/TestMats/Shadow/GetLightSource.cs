using UnityEngine;
using System.Collections.Generic;
using UnityEditor;

//[ExecuteInEditMode]
public class GetLightSource : MonoBehaviour
{ 
    private List<Light> lights;
    public const int MOST_EFFECTED_LIGHT_NUMBER = 1;

    private void Start()
    {
        lights = new List<Light>();
        Light[] objs = FindObjectsByType<Light>(FindObjectsSortMode.None);

        foreach (Light obj in objs) { lights.Add(obj); }

        // ���ݵƹ�������Ӱ��̶�Ȩ�ؽ�������
    }

    private void Update()
    {
        foreach (Light light in lights)
        {
            //Debug.Log(light.transform.position);
        }
    }
}
