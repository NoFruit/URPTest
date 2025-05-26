Shader "Custom/GlassTest"
{
    Properties
    {
        [Header(Lighting)][Space(10)]
        [HDR] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SpecularRange("Specular Range", float) = 0.1
        [HDR]_SpecularColor("Specular Color", Color) = (1, 1, 1, 1)

        [Header(Refrection and Reflection)][Space(10)]
        _RefractRatioCenter ("Refraction Ratio Centre", float) = 1.53
        _RefractRatioSider ("Refraction Ratio Sider", float) = 1

        [Header(Fresnel)][Space(10)]
        _FresnelPow ("Fresnel Pow", float) = 0
    }

    // 最基础URP可用的玻璃Shader代码形式，但没有使用PBR光照
    SubShader
    {
        // 用透明物体逻辑渲染
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        LOD 0
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap); // = sample2D _BaseMap
            SAMPLER(sampler_BaseMap); // 上面的采样器，在URP中要显式编程

            TEXTURE2D(_CameraOpaqueTexture); // 取景相机内容
            SAMPLER(sampler_CameraOpaqueTexture);

            // 变量声明 材质共享
            CBUFFER_START(UnityPerMaterial)
                float _RefractRatioCenter;
                float _RefractRatioSider;
                float _FresnelPow;

                float _SpecularRange;
                half4 _SpecularColor;

                half4 _BaseColor;
                half4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // 裁剪空间位置
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                // 世界空间位置 世界向量位置
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionWS = positionInputs.positionWS;

                // 世界法线位置
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
                OUT.normalWS = normalInputs.normalWS;

                // 观察位置
                OUT.viewDir = GetWorldSpaceNormalizeViewDir(positionInputs.positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirWS = IN.viewDir;

                // ------ 漫反射 ------
                Light mainLight = GetMainLight();
                float3 lightDir = normalize( mainLight.direction );
                //half3 diffuseColor = mainLight.color * _BaseColor.rgb * max(0, dot(normalWS, lightDir));

                // ------ 高光 Blinn-Phong ------
                float3 halfDir = normalize( lightDir + viewDirWS );
                float3 reflectLightVec = reflect( -lightDir, normalWS );
                float specularBase = pow( saturate( dot(normalWS, lightDir) ), 1.0/_SpecularRange );
                half4 specularColor = saturate( _SpecularColor * specularBase );

                // ------ 折射 ------
                // 计算菲涅尔范围 内部和外部折射率不同
                float fresnelValue = pow(1 - max(0, dot(normalWS, viewDirWS)), 1.0 / _FresnelPow);
                float refractRadio = lerp(1.0/_RefractRatioCenter, 1.0/_RefractRatioSider, fresnelValue);

                // 折射 通过缩小采集贴图来近似效果
                float2 screenUV = GetNormalizedScreenSpaceUV(IN.positionHCS); // 左下角00 右上角11
                float2 refractUV = ( (screenUV-float2(0.5,0.5)) / refractRadio ) + float2(0.5, 0.5);

                // 折射像素
                half4 refractColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractUV);
                
                // ------ 反射 ------
                float3 reflectVec = reflect( -viewDirWS, normalWS );

                half4 outputColor = half4( lerp( refractColor.rgb, specularColor.rgb, specularColor.a) , 1);
                return outputColor;
            }
            ENDHLSL
        }
    }
}
