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

    // �����URP���õĲ���Shader������ʽ����û��ʹ��PBR����
    SubShader
    {
        // ��͸�������߼���Ⱦ
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
            SAMPLER(sampler_BaseMap); // ����Ĳ���������URP��Ҫ��ʽ���

            TEXTURE2D(_CameraOpaqueTexture); // ȡ���������
            SAMPLER(sampler_CameraOpaqueTexture);

            // �������� ���ʹ���
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

                // �ü��ռ�λ��
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                // ����ռ�λ�� ��������λ��
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionWS = positionInputs.positionWS;

                // ���編��λ��
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
                OUT.normalWS = normalInputs.normalWS;

                // �۲�λ��
                OUT.viewDir = GetWorldSpaceNormalizeViewDir(positionInputs.positionWS);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirWS = IN.viewDir;

                // ------ ������ ------
                Light mainLight = GetMainLight();
                float3 lightDir = normalize( mainLight.direction );
                //half3 diffuseColor = mainLight.color * _BaseColor.rgb * max(0, dot(normalWS, lightDir));

                // ------ �߹� Blinn-Phong ------
                float3 halfDir = normalize( lightDir + viewDirWS );
                float3 reflectLightVec = reflect( -lightDir, normalWS );
                float specularBase = pow( saturate( dot(normalWS, lightDir) ), 1.0/_SpecularRange );
                half4 specularColor = saturate( _SpecularColor * specularBase );

                // ------ ���� ------
                // �����������Χ �ڲ����ⲿ�����ʲ�ͬ
                float fresnelValue = pow(1 - max(0, dot(normalWS, viewDirWS)), 1.0 / _FresnelPow);
                float refractRadio = lerp(1.0/_RefractRatioCenter, 1.0/_RefractRatioSider, fresnelValue);

                // ���� ͨ����С�ɼ���ͼ������Ч��
                float2 screenUV = GetNormalizedScreenSpaceUV(IN.positionHCS); // ���½�00 ���Ͻ�11
                float2 refractUV = ( (screenUV-float2(0.5,0.5)) / refractRadio ) + float2(0.5, 0.5);

                // ��������
                half4 refractColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refractUV);
                
                // ------ ���� ------
                float3 reflectVec = reflect( -viewDirWS, normalWS );

                half4 outputColor = half4( lerp( refractColor.rgb, specularColor.rgb, specularColor.a) , 1);
                return outputColor;
            }
            ENDHLSL
        }
    }
}
