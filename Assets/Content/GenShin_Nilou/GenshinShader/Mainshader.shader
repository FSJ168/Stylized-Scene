Shader "GenshinToon/MainShader"
{
    Properties
    {
        [Header(General)] 
        [KeywordEnum(Body, Face)] _RenderType("Render Type", Float) = 0.0
        // 面部光照贴图通道选择：R通道/A通道
        [KeywordEnum(R, A)] _UseFaceLightMapChannel("Use Face Lightmap Channel", Float) = 1.0
        // 开关：是否为背面启用UV2通道（默认关闭，修复背面纹理错位）
        [Toggle(_BACKFACEUV2_ON)] _UseBackFaceUV2("Use Back Face UV2 (Default NO)", Float) = 0
        // 正面基础色调（叠加到主纹理，默认白色）
        _FrontFaceTintColor("Front face tint color (Default white)", Color) = (1.0, 1.0, 1.0, 1.0)
        // 背面基础色调（仅背面可见时生效，默认白色）
        _BackFaceTintColor("Back face tint color (Default white)", Color) = (1.0, 1.0, 1.0, 1.0)
        // 主纹理Alpha通道用途：无/闪烁/自发光/透明度裁剪
        [KeywordEnum(None, Flicker, Emission, AlphaTest)] _MainTexAlphaUse("Diffuse Texture Alpha Use", Float) = 0.0
        // 整体透明度（全局Alpha，0-1）
        _Alpha("Alpha (Default 1)", Range(0, 1)) = 1
        // 透明度裁剪阈值（Alpha低于该值的像素被剔除）
        _AlphaClip("Alpha clip (Default 0.5)", Range(0.0, 1.0)) = 0.5
        // 主纹理专属Alpha裁剪阈值（优先级高于_AlphaClip）
        _MainTexCutOff("Alpha clip (MainTex)", Range(0.0, 1.0)) = 0.5

        [Header(Main Lighting)]
        // 基础漫反射纹理（角色贴图/皮肤/衣物）
        _MainTex("Diffuse Texture", 2D) = "white" { }
        // ilm纹理（原神专用，存储自发光/金属度/遮罩信息）
        _ilmTex("ilm Texture", 2D) = "white" { }
        // 色调映射纹理（Toon风格核心，将连续光照映射为阶梯化卡通色）
        _RampTex("Ramp Texture", 2D) = "white" { }
        // 高光区域亮度系数（控制最亮区域亮度）
        _BrightFac("Bright Factor", Float) = 0.99
        // 中间调区域亮度系数（控制半阴影区域亮度）
        _GreyFac("Gray Factor", Float) = 1.08
        // 阴影区域亮度系数（控制最暗区域亮度）
        _DarkFac("Dark Factor", Float) = 0.55
        // 开关：是否启用主光源阴影衰减（阴影随距离/强度渐变）
        [Toggle(_MAINLIGHT_SHADOWATTENUATION_ON)] _UseMainLightshadowAttenuation("Use mainLight shadow attenuation", Float) = 0

        [Header(Indirect Lighting)]
        // 间接光照法线扁平化系数（值越高，间接光越均匀）
        _IndirectLightFlattenNormal("Indirect light flatten normal (Default 0)", Range(0, 1)) = 0
        // 间接光强度（控制环境光整体亮度，0-2）
        _IndirectLightIntensity("Indirect light intensity (Default 1)", Range(0, 2)) = 1
        // 间接光颜色混合系数（0=场景环境色，1=自定义色）
        _IndirectLightUsage("Indirect light color usage (Default 0.5)", Range(0, 1)) = 0.5

        [Header(Environment Interaction)]
        
        //环境亮度对角色亮度的影响程度
        _EnvironmentBrightnessInfluence("Environment Brightness Influence",Range(0,1))=0.65
        //SH环境亮度整体曝光补偿
        _EnvironmentExposure("Environment Exposure",Range(0,4))=1.0
        //环境光最小亮度
        _EnvironmentMinBrightness("Environment Min Brightness",Range(0,1))=0.35
        //环境光最大亮度
        _EnvironmentMaxBrightness("Environment Max Brightness",Range(1,3))=1
        
        //环境颜色保留程度
        _EnvironmentColorInfluence("环境颜色影响",Range(0,1))=0.75

        [Header(Main Light Brightness)]
        _MainLightBrightnessInfluence("主光亮度影响",Range(0,1))=0.35
        //主光最小亮度
        _MainLightMinBrightness("主光最小亮度",Range(0,1))=0
        //主光最大亮度
        _MainLightMaxBrightness("主光最大亮度",Range(1,3))=1.5

        [Header(Additional Light Tint)]
        //所有额外灯的总强度
        _AdditionalLightIntensity("Additional Light总强度",Range(0,3))=1
        //越大染色区域越宽
        _AdditionalLightWrap("染色宽度",Range(0,1))=0.35
        //染色边缘锐度
        _AdditionalLightPower("染色边缘锐度",Range(0.25,4))=1.0
        //染色方式：0=覆盖式染色，1=混合染色
        _AdditionalLightBaseColorBlend("染色方式：0=覆盖式染色，1=混合染色",Range(0,1))=0.8
        //Ao是否抑制额外灯
        _AdditionalLightAOInfluence("Ao是否抑制额外灯",Range(0,1))=0.5


        [Header(Face Settings)] // 面部专属设置分组（仅RenderType=Face时生效）
        // 面部SDF（距离场）纹理（计算面部硬边界阴影：眼窝/鼻子等）
        _FaceShadowMap("Face SDF Texture", 2D) = "white" { }
        // 面部细节贴图（腮红/雀斑/高光等）
        _FaceMapTex("FaceMap Texture", 2D) = "white" { }
        // 面部阴影偏移（调整SDF阴影位置，避免穿模）
        _FaceShadowOffset("Face Shadow Offset", range(-1.0, 1.0)) = 0.0
        // 面部阴影过渡柔和度（0=硬边，1=最柔和）
        _FaceShadowTransitionSoftness("Face shadow transition softness (Default 0.05)", Range(0, 1)) = 0.05

        [Header(ColorGrading)]
        // 高光区域色调（叠加到最亮区域）
        _LightAreaColorTint("Light Area Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // 普通阴影色调（叠加到阴影区域）
        _DarkShadowColor("Dark Shadow Color Tint", Color) = (0.75, 0.75, 0.75, 1.0)
        // 冷色调阴影色调（仅UseCoolShadowColorOrTex开启时生效）
        _CoolDarkShadowColor("Cool Dark Shadow Color Tint", Color) = (0.5, 0.5, 0.65, 1.0)
        // 高光区域阴影混合系数（控制阴影向高光区域渗透）
        _BrightAreaShadowFac("Bright Area Shadow Factor", Range(0, 1)) = 1

        [Header(Ramp Settings)]

        // Ramp纹理采样索引：1.0（纯白/最亮）
        [IntRange] _RampIndex0("RampIndex_1.0", Range(1, 5)) = 1
        // Ramp纹理采样索引：0.7（高光）
        [IntRange] _RampIndex1("RampIndex_0.7", Range(1, 5)) = 4
        // Ramp纹理采样索引：0.5（中间调）
        [IntRange] _RampIndex2("RampIndex_0.5", Range(1, 5)) = 3
        // Ramp纹理采样索引：0.3（半阴影）
        [IntRange] _RampIndex3("RampIndex_0.3", Range(1, 5)) = 5
        // Ramp纹理采样索引：0.0（纯黑/最暗）
        [IntRange] _RampIndex4("RampIndex_0.0", Range(1, 5)) = 2

        [Header(Normal)]

        // 开关：是否启用法线贴图（凹凸光影）
        [Toggle(_NORMAL_MAP_ON)] _UseNormalMap("Use Normal Map (Default NO)", Float) = 0
        // 法线强度（值越高，凹凸感越强）
        _BumpFactor("Bump Scale (Default 1)", Float) = 1.0
        // 法线贴图（存储表面凹凸信息）
        [Normal] _NormalMap("Normal Map (Default black)", 2D) = "bump" { }

        [Header(Specular)]

        // 开关：是否启用高光系统（默认开启）
        [Toggle(_SPECULAR_ON)] _EnableSpecular ("Enable Specular (Default YES)", Float) = 1
        // 开关：是否启用金属材质逻辑
        [Toggle] _MetalMaterial ("Enable Metallic", Range(0.0, 1.0)) = 1.0
        // 金属Matcap纹理（模拟金属环境反射）
        _MTMap("Metallic Matcap", 2D)= "white"{ }
        // 开关：是否启用金属高光Ramp纹理
        [Toggle] _MTUseSpecularRamp ("Enable Metal Specular Ramp", Float) = 0.0
        // 金属高光色调映射纹理
        _MTSpecularRamp("Specular Ramp", 2D)= "white"{ }
        // 金属Matcap亮度
        _MTMapBrightness ("Metallic Matcap Brightness", Float) = 3.0
        // 金属高光锐度（值越高，高光越小越亮）
        _MTShininess ("Metallic Specular Shininess", Float) = 90.0
        // 金属高光强度
        _MTSpecularScale ("Metallic Specular Scale", Float) = 15.0
        // 金属Matcap纹理平铺缩放
        _MTMapTileScale ("Metallic Matcap Tile Scale", Range(0.0, 2.0)) = 1.0
        // 阴影中金属高光衰减系数（0=阴影无高光，1=无衰减）
        _MTSpecularAttenInShadow ("Metallic Specular Power in Shadow", Range(0.0, 1.0)) = 0.2
        // 金属锐化层偏移（控制金属边缘高光位置）
        _MTSharpLayerOffset ("Metallic Sharp Layer Offset", Range(0.001, 1.0)) = 1.0
        // 金属Matcap暗部色调
        _MTMapDarkColor ("Metallic Matcap Dark Color", Color) = (0.51, 0.3, 0.19, 1.0)
        // 金属Matcap亮部色调
        _MTMapLightColor ("Metallic Matcap Light Color", Color) = (1.0, 1.0, 1.0, 1.0)
        // 金属阴影混合色
        _MTShadowMultiColor ("Metallic Matcap Shadow Multiply Color", Color) = (0.78, 0.77, 0.82, 1.0)
        // 金属高光颜色
        _MTSpecularColor ("Metallic Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        // 金属锐化层颜色（边缘高光）
        _MTSharpLayerColor ("Metallic Sharp Layer Color", Color) = (1.0, 1.0, 1.0, 1.0)
        // 开关：是否启用通用高光
        [Toggle] _SpecularHighlights ("Enable Specular Highlights", Float) = 0.0
        // 通用高光锐度1（对应SpecularColor1）
        _Shininess ("Shininess 1", Float) = 10
        // 通用高光锐度2（对应SpecularColor2）
        _Shininess2 ("Shininess 2", Float) = 10
        // 通用高光锐度3（对应SpecularColor3）
        _Shininess3 ("Shininess 3", Float) = 10
        // 通用高光锐度4（对应SpecularColor4）
        _Shininess4 ("Shininess 4", Float) = 10
        // 通用高光锐度5（对应SpecularColor5）
        _Shininess5 ("Shininess 5", Float) = 10
        // 通用高光强度
        _SpecMulti ("Specular Multiplier 1", Float) = 0.1
        _SpecMulti2 ("Specular Multiplier 2", Float) = 0.1
        _SpecMulti3 ("Specular Multiplier 3", Float) = 0.1
        _SpecMulti4 ("Specular Multiplier 4", Float) = 0.1
        _SpecMulti5 ("Specular Multiplier 5", Float) = 0.1
        // 通用高光颜色
        _SpecularColor ("Specular Color 1", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularColor2 ("Specular Color 2", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularColor3 ("Specular Color 3", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularColor4 ("Specular Color 4", Color) = (1.0, 1.0, 1.0, 1.0)
        _SpecularColor5 ("Specular Color 5", Color) = (1.0, 1.0, 1.0, 1.0)

        [Header(Rim Lighting)]
        // 开关：是否启用边缘光（默认开启）
        [Toggle(_RIM_LIGHTING_ON)] _UseRimLight("Use Rim light (Default YES)",float) = 1
        // 边缘光宽度（值越高，轮廓辉光越宽）
        _RimLightWidth("Rim light width (Default 1)",Range(0, 10)) = 1
        // 边缘光阈值（控制边缘光出现的角度）
        _RimLightThreshold("Rin light threshold (Default 0.05)",Range(-1, 1)) = 0.05
        // 边缘光衰减（值越低，边缘光越柔和）
        _RimLightFadeout("Rim light fadeout (Default 1)",Range(0.01, 1)) = 1
        // 边缘光基础色调（HDR支持超亮辉光）
        [HDR] _RimLightTintColor("Rim light tint colar (Default white)",Color) = (1,1,1)
        // 边缘光亮度
        _RimLightBrightness("Rim light brightness (Default 1)",Range(0, 10)) = 1
        // 边缘光颜色（基础）
        _RimColor ("Rim Light Color", Color)   = (1, 1, 1, 1)
        // 边缘光颜色1（分层）
        _RimColor1 ("Rim Light Color 1", Color)  = (1, 1, 1, 1)
        // 边缘光颜色2（分层）
        _RimColor2 ("Rim Light Color 2", Color)  = (1, 1, 1, 1)
        // 边缘光颜色3（分层）
        _RimColor3 ("Rim Light Color 3", Color)  = (1, 1, 1, 1)
        // 边缘光颜色4（分层）
        _RimColor4 ("Rim Light Color 4", Color) = (1, 1, 1, 1)
        // 边缘光颜色5（分层）
        _RimColor5 ("Rim Light Color 5", Color) = (1, 1, 1, 1)

        [Header(Emission)]
        // 开关：是否启用自发光（默认关闭）
        [Toggle(_EMISSION_ON)] _UseEmission("Use emission (Default NO)", Float) = 0
        // 自发光与基础色混合系数（0=纯自发光，1=混合基础色）
        _EmissionMixBaseColorFac("Emission mix base color factor (Default 1)", Range(0, 1)) = 1
        // 自发光色调
        _EmissionTintColor("Emission tint color (Default white)", Color) = (1, 1, 1, 1)
        // 自发光强度缩放
        _EmissionScaler("Emission Scaler", Range(1.0, 10.0)) = 1.0

        [Header(Outline)]
        // 开关：是否启用描边（默认开启）
        [Toggle] _EnableOutline("Enable Outline (Default YES)", Float) = 1
        // 描边法线通道：Normal/Tangent/UV2（控制描边方向计算）
        [KeywordEnum(Normal, Tangent, UV2)] _OutlineNormalChannel("Outline Normal Channel", Float) = 0
        // 开关：是否使用自定义描边颜色
        [Toggle(_OUTLINE_CUSTOM_COLOR_ON)] _UseCustomOutlineCol("Use Custom outline Color", Float) = 0
        [Toggle(_OUTLINE_USE_SMOOTHNORMAL_ON)]_UseSmoothNormal("Use SmoothNormal",Float)=1
        // 默认描边颜色（未启用自定义时生效）
        _OutlineDefaultColor("Outline Default Color", Color) = (0.5, 0.5, 0.5, 1)
        // 自定义描边颜色（基础）
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        // 自定义描边颜色1（分层）
        _OutlineColor1("Outline Color 1", Color) = (0, 0, 0, 1)
        // 自定义描边颜色2（分层）
        _OutlineColor2("Outline Color 2", Color) = (0, 0, 0, 1)
        // 自定义描边颜色3（分层）
        _OutlineColor3("Outline Color 3", Color) = (0, 0, 0, 1)
        // 自定义描边颜色4（分层）
        _OutlineColor4("Outline Color 4", Color) = (0, 0, 0, 1)
        // 自定义描边颜色5（分层）
        _OutlineColor5("Outline Color 5", Color) = (0, 0, 0, 1)
        // 开关：是否为面部材质描边（面部描边更细/柔和）
        [Toggle] _FaceMaterial("Is Face Material Outline", Float) = 0
        // 描边宽度（世界空间单位）
        _OutlineWidth("OutlineWidth (World Space)", Range(0, 1)) = 0.1
        // 描边整体缩放
        _OutlineScale("OutlineScale (Default 1)", Float) = 1
        // 描边宽度参数（控制不同方向的描边宽度）
        _OutlineWidthParams("Outline Width Params", Vector) = (0, 1, 0, 1)
        // 描边Z轴偏移（避免描边与模型重叠）
        _OutlineZOffset("Outline Z Offset", Float) = 0
        // 描边屏幕空间偏移（微调描边位置）
        _ScreenOffset("Screen Offset", Vector) = (0, 0, 0, 0)

        [Header(Surface Options)]
        // 裁剪模式：Off(无)/Back(背面)/Front(正面)
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode (Default Back)", Float) = 2
        // 颜色源混合模式（默认One，不透明）
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendModeColor("Core Pass src blend mode color (Default One)", Float) = 1
        // 颜色目标混合模式（默认Zero，不透明）
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendModeColor("Core Pass dst blend mode color (Default Zero)", Float) = 0
        // Alpha源混合模式（默认One）
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendModeAlpha("Core Pass src blend mode alpha (Default One)", Float) = 1
        // Alpha目标混合模式（默认Zero）
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlendModeAlpha("Core Pass dst blend mode alpha (Default Zero)", Float) = 0
        // 是否写入深度缓冲区（默认开启，透明物体需关闭）
        [Enum(Off, 0, On, 1)] _ZWrite("ZWrite (Default On)", Float) = 1

        [Header(Custom Light)]
        // 开关：是否使用自定义主光源
        [Toggle(_USE_CUSTOM_MAIN_LIGHT)] _UseCustomMainLight("Use Custom Main Light", Float) = 0
        // 自定义光源类型：方向光/点光（这里先实现方向光）
        [KeywordEnum(Directional, Point)] _CustomLightType("Custom Light Type", Float) = 0
        // 自定义光源方向（世界空间）
        _CustomLightDir("Custom Light Direction (WS)", Vector) = (0, -1, 1, 0)
        // 自定义光源颜色
        _CustomLightColor("Custom Light Color", Color) = (1, 1, 1, 1)
        // 自定义光源强度
        _CustomLightIntensity("Custom Light Intensity", Range(0, 5)) = 1.0
        // 自定义光源位置（点光用，世界空间）
        _CustomLightPos("Custom Light Position (WS)", Vector) = (0, 2, 0, 0)
        // 自定义光源范围（点光用）
        _CustomLightRange("Custom Light Range", Range(1, 50)) = 10.0
        
        

    }

    SubShader
    {
        HLSLINCLUDE
        #include "DetailedShader/InputShader.hlsl"
        ENDHLSL

        Tags
        {
            "RenderPipeline" = "UniversalPipeline" // 指定使用URP渲染管线
            "RenderType" = "Opaque"                // 渲染类型：不透明
            "Queue" = "Geometry"                   // 渲染队列：几何体（默认）
        }

        // 核心渲染Pass（主光照/漫反射/高光/边缘光等核心效果）
        Pass
        {
            Name "GenshinCharacter_CorePass"
            Tags
            {
                "LightMode" = "UniversalForward" 
            }

            Cull[_CullMode]
            Blend[_SrcBlendModeColor] [_DstBlendModeColor], [_SrcBlendModeAlpha] [_DstBlendModeAlpha]

            ZWrite[_ZWrite]

            HLSLPROGRAM
            #pragma vertex GenshinStyleVertex
            #pragma fragment GenshinStyleFragment

            #pragma multi_compile _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _LIGHT_LAYERS

            #pragma shader_feature_local _ _MAINTEXALPHAUSE_NONE _MAINTEXALPHAUSE_FLICKER _MAINTEXALPHAUSE_EMISSION _MAINTEXALPHAUSE_ALPHATEST

            #pragma shader_feature_local _ _RENDERTYPE_BODY _RENDERTYPE_FACE

            #pragma shader_feature_fragment _ _USEFACELIGHTMAPCHANNEL_R _USEFACELIGHTMAPCHANNEL_A
       
            #pragma shader_feature_local _EMISSION_ON
    
            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
        
            #pragma shader_feature_local_fragment _ _BACKFACEUV2_ON
            
            #pragma shader_feature_local _MAINLIGHT_SHADOWATTENUATION_ON
  
            #pragma shader_feature_local_fragment _NORMAL_MAP_ON
       
            #pragma shader_feature_local _SPECULAR_ON
           
            #pragma shader_feature_local _RIM_LIGHTING_ON

            #pragma shader_feature _DITHER_MODE_IS_DISTANCE _DITHER_MODE_IS_ANGLE

            // 引入核心渲染逻辑头文件（包含顶点/片元着色器实现）
            #include "DetailedShader/CorePass.hlsl"
            ENDHLSL
        }

        // 描边Pass（背面扩张法描边）
        Pass
        {
            Name "GenshinCharacter_BackFacingOutline" // Pass名称
            Tags
            {
                "LightMode" = "SRPDefaultUnlit" // 光照模式：无光照（描边无需光照）
            }

            Cull Front // 裁剪正面（只渲染背面，实现轮廓扩张）
            ZWrite[_ZWrite] // 深度写入（由属性控制）

            HLSLPROGRAM
            #pragma vertex BackFaceOutlineVertex
            #pragma fragment BackFaceOutlineFragment
            // 着色器特性：自定义描边颜色
            #pragma shader_feature_local _OUTLINE_CUSTOM_COLOR_ON
            // 着色器特性：模型类型
            #pragma shader_feature_local _MODEL_GAME _MODEL_MMD
            // 着色器特性：背面UV2通道
            #pragma shader_feature_local_fragment _ _BACKFACEUV2_ON
            // 着色器特性：描边法线通道
            #pragma shader_feature_local _OUTLINENORMALCHANNEL_NORMAL _OUTLINENORMALCHANNEL_TANGENT _OUTLINENORMALCHANNEL_UV2
            #pragma shader_feature_local _OUTLINE_USE_SMOOTHNORMAL_ON
            // 引入描边渲染逻辑头文件
            #include "DetailedShader/OutlineShader.hlsl"

            ENDHLSL
        }

        // 阴影投射Pass
        Pass
        {
            Name "ShadowCaster" 
            Tags
            {
                "LightMode" = "ShadowCaster" 
            }

            ZWrite On         
            ZTest LEqual       
            ColorMask 0        
            Cull[_CullMode]   

            HLSLPROGRAM
            #pragma target 2.0 // 目标Shader模型版本

            // 顶点着色器入口：阴影投射顶点处理
            #pragma vertex ShadowPassVertex
            // 片元着色器入口：阴影投射片元处理
            #pragma fragment ShadowPassFragment

            // 着色器特性：透明度裁剪
            #pragma shader_feature_local _ALPHATEST_ON
            // 着色器特性：光滑度纹理（Alpha通道）
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // GPU实例化
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // 多编译指令：LOD淡入淡出
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // 多编译指令：点光源阴影投射
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // 引入URP阴影投射相关头文件
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        // 深度仅写Pass（生成深度纹理）
        Pass
        {
            Name "DepthOnly" // Pass名称
            Tags
            {
                "LightMode" = "DepthOnly" // 光照模式：仅深度
            }

            // 渲染状态
            ZWrite On    // 开启深度写入
            ColorMask R  // 仅写入红色通道（存储深度）

            HLSLPROGRAM
            #pragma target 2.0

            // 顶点着色器入口：深度顶点处理
            #pragma vertex DepthOnlyVertex
            // 片元着色器入口：深度片元处理
            #pragma fragment DepthOnlyFragment

            // 着色器特性：透明度裁剪
            #pragma shader_feature_local _ALPHATEST_ON

            // 多编译指令：LOD淡入淡出
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            // GPU实例化
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // 引入URP深度仅写相关头文件
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // 深度+法线Pass（生成深度法线纹理）
        Pass
        {
            Name "DepthNormalsOnly" // Pass名称
            Tags
            {
                "LightMode" = "DepthNormalsOnly" // 光照模式：深度+法线
            }

            // 渲染状态
            ZWrite On // 开启深度写入

            HLSLPROGRAM
            #pragma target 2.0

            // 顶点着色器入口：深度法线顶点处理
            #pragma vertex DepthNormalsVertex
            // 片元着色器入口：深度法线片元处理
            #pragma fragment DepthNormalsFragment

            // 着色器特性：透明度裁剪
            #pragma shader_feature_local _ALPHATEST_ON

            // 多编译指令：法线编码（八叉树）
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            // 多编译指令：LOD淡入淡出
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            // 渲染层
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // GPU实例化
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // 引入URP深度法线相关头文件
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }

    // 回退Shader（URP默认错误回退）
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
