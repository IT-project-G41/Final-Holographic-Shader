// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShader/HoloShaderWithTexture"
{
    Properties
    {
        _ScanTex ("scan line Texture", 2D) = "white" {}
        _MainTex ("Main Texture", 2D) = "white"{}
        _Gloss ("Gloss", Range(10, 200)) = 20
        _Speed ("Speed", Range(-5, 15)) = 1
        _RimPower("Rim Power", Range(0.00001, 20.0)) = 4
        _Size("Size", Range(0, 1)) = 0.5
        _OutLineWidth("width", float) = 1.05
        [IntRange]_addtionalEffecct("additional effect", Range(0, 3)) = 0
        _HolographicColor("holographic color", color) = (1, 1, 1, 1)   //Holographic projection color

    }
    SubShader
    {
        
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" "IgnoreProjector" = "True" "ForceNoShadowCasting" = "True"}
        LOD 100
       


        //Use a Pass block for deep writing but do not render any colors to the depth cache, The goal is to avoid rendering the texture from the back of the model to the front   
        Pass{
            ZWrite On  
            ColorMask 0
            
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag

            float4 _MainTex_ST;


            struct a2v{
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f{
                float4 position : SV_POSITION;
                float4 uv : TEXCOORD0;
            };

            v2f vert(a2v v){
                v2f f;
                f.position = UnityObjectToClipPos(v.vertex);
                //f.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                f.uv = v.texcoord;
                return f;
            }


            float4 frag(v2f f) : SV_Target{
                return 0;
            }


            ENDCG

        }
        


        Pass{
            Tags{"LightMode" = "ForwardBase"}
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite off  

            CGPROGRAM
            #include "Lighting.cginc"
            #include "UnityCG.cginc"

            #pragma vertex vert
            #pragma fragment frag


            float _Gloss;
            fixed _Speed;
            sampler2D _ScanTex;
            sampler2D _MainTex;
            fixed _RimPower;
            fixed _addtionalEffecct;
            fixed4 _HolographicColor;    //Declare holographic projection color
            float4 _MainTex_ST;   


            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };


            struct v2f{
                float4 position : SV_POSITION;
                float3 world_normal_dir : COLOR0;
                fixed3 world_light_dir : COLOR1;
                fixed3 world_view_dir : COLOR2;
                //float4 object_position : TEXCOORD0;
                float4 world_postion : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 uv2 : TEXCOORD3;
            };
            

            //Vertex fault effect
            float3 VertexJitterOffset(float3 vertex){
                half _JitterSpeedRedio = 2.5;    //Offset velocity factor
                half _JitterRangeY = 1.3;  //The range of Y values allowed to be offset
                half _JitterOffset = 30;  //Vertex offset

                float3 pos = UnityObjectToWorldDir(vertex);  // transform the vertex from object space to world space

                half optTime = sin(_Time.y * _JitterSpeedRedio);
                half timeTojitter = step(0.99, optTime);
                
                //The vertex Y that needs to be shaken is different each time
                half jitterPosY = pos.y + _SinTime.y;
                //half jitterPosY = sin(vertex.y + _Time.y);

                //Jitter area 0< y <_JitterRangeY
                half jitterPosYRange = step(0, jitterPosY) * step(jitterPosY, _JitterRangeY);
                half offset = jitterPosYRange * _JitterOffset * timeTojitter * _SinTime.y;
                return float3(offset, 0, 0);
            }



            //Fresnel reflection
            float3 FresnelReflection(fixed3 view, fixed3 normal, fixed alpha, fixed3 color){
                fixed _FresnelScale = 3;
                fixed _FresnelPower = 2.2;
                
                float3 fresnel = pow(1 - dot(view, normal), _FresnelPower) * _FresnelScale;
                //fresnel.a = clamp(fresnel.a, 0.0, 1.0);

                fixed3 fresnel_color = color * fresnel.rgb; 

                return fresnel_color;

            }


            //Realize scan line flow animation
            fixed4 ScanLineflow(fixed3 diffuse, v2f f){
                fixed scroll = _Speed * _Time;
                fixed4 col = (diffuse, 1);
                fixed scroll_project = abs(f.uv.y + scroll - round(f.uv.y + scroll));
                fixed4 cybercol = tex2D(_ScanTex, scroll_project);
                fixed alpha = 1;
                if(cybercol.r + cybercol.g + cybercol.b < 1){
                    alpha = 0;
                    col = max(cybercol, col);
                }
                return fixed4(col.rgb, alpha);
            }



            v2f vert(a2v v){
                v2f f;
                v.vertex.xyz += VertexJitterOffset(v.vertex.xyz);
                f.position = UnityObjectToClipPos(v.vertex);
                f.world_normal_dir = UnityObjectToWorldNormal(v.normal);
                f.world_light_dir = WorldSpaceLightDir(v.vertex);
                f.world_view_dir = WorldSpaceViewDir(v.vertex);
                //f.object_position = v.vertex;
                f.world_postion = mul(unity_ObjectToWorld, v.vertex);
                f.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                //v.texcoord.xyz += VertexJitterOffset(v.texcoord.xyz);
                f.uv2 = v.texcoord;

                return f;
            }


            float4 frag(v2f f) : SV_Target{
                fixed3 normalDir = normalize(f.world_normal_dir);   //acquire normal direction, under the world space
                fixed3 lightDir = normalize(f.world_light_dir);   //acquire light direction, under the world space
                fixed3 viewDir = normalize(f.world_view_dir);     //acquire view direction, under the world sapce
                fixed3 halfDir = normalize(lightDir + viewDir);   //acquire the half of the light direction and view direction, under the world space

                fixed3 tex_color = tex2D(_MainTex, f.uv);
                

                fixed4 col = ScanLineflow(_HolographicColor.rgb, f);

                //Controls the mask effect
                fixed alpha = lerp(1, tex_color.r, col.a);

                //Achieve edge light effect
                //Calculate the Angle between the Angle of view and the normal direction
                fixed rim =  max(1 - dot(normalDir, viewDir), 0);
                //Calculates edge light color
                fixed3 rim_color = _HolographicColor.rgb * pow(rim, 1 / _RimPower);



                fixed3 res_color = col.rgb * _HolographicColor.rgb + rim_color;
                fixed3 final_color = FresnelReflection(viewDir, normalDir, alpha, res_color);
                

                return fixed4(final_color, alpha);
            }


            ENDCG

            
        }


       



        



    }
    FallBack "Diffuse"
}
