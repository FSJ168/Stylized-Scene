using UnityEngine;
using UnityEngine.Rendering;

public class OutdoorDynamicEnvironment : MonoBehaviour
{
    [Header("动态天空环境")]
    //全局环境光刷新间隔
    [Min(0.1f)] public float environmentUpdateInterval=0.5f;

    [Header("实时反射探针")]
    public ReflectionProbe[] reflectionProbes;
    //探针轮询时间间隔
    [Min(0.1f)] public float probeUpdateInterval=0.5f;

    private float environmentTimer; //环境光计时器
    private float probeTimer; //探针轮询计时器
    private int probeIndex; //轮询下标
    private ReflectionProbe renderingProbe; //当前正在渲染的探针引用
    private int renderId=-1; //返回的渲染任务ID
    private bool probeRendering; //标记当前是否有探针正在渲染

    private void Start()
    {
        ConfigureProbes(); //批量设置数组内所有反射探针参数
        DynamicGI.UpdateEnvironment(); //立刻采样一次当前天空，初始化全局环境 GI。
    }

    private void Update()
    {
        UpdateEnvironmentLighting();
        UpdateReflectionProbes();
    }

    private void ConfigureProbes()
    {
        if(reflectionProbes==null)return;

        for(int i=0;i<reflectionProbes.Length;i++)
        {
            ReflectionProbe probe=reflectionProbes[i];
            if(probe==null)continue;
            probe.mode=ReflectionProbeMode.Realtime; //实时反射探针
            probe.refreshMode=ReflectionProbeRefreshMode.ViaScripting; //由脚本控制渲染
            probe.timeSlicingMode=ReflectionProbeTimeSlicingMode.IndividualFaces; //多帧渲染

        }
    }

    //动态天空刷新
    private void UpdateEnvironmentLighting()
    {
        environmentTimer+=Time.deltaTime;
        if(environmentTimer<environmentUpdateInterval)return;
        environmentTimer=0.0f;

        //重新采样当前程序化天空
        DynamicGI.UpdateEnvironment();
    }
    
    //反射探针轮询渲染
    private void UpdateReflectionProbes()
    {
        if(reflectionProbes==null||reflectionProbes.Length==0)return;

        if(probeRendering)
        {
            //当前有探针正在渲染返回
            if(renderingProbe!=null&&!renderingProbe.IsFinishedRendering(renderId))return;
            
            probeRendering=false;
            renderingProbe=null;
            renderId=-1;
        }
        
        //计时器累加
        probeTimer+=Time.deltaTime;
        if(probeTimer<probeUpdateInterval)return;
        probeTimer=0.0f;
        
        
        for(int i=0;i<reflectionProbes.Length;i++)
        {
            ReflectionProbe probe=reflectionProbes[probeIndex];
            probeIndex=(probeIndex+1)%reflectionProbes.Length;
            if(probe==null||!probe.isActiveAndEnabled)continue;

            //一次只更新一个Probe
            renderingProbe=probe;
            renderId=probe.RenderProbe();
            probeRendering=true;
            break;
        }
    }
}