// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShader/MyAttemptShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)    //模型颜色
        _MainTex ("Main Texture", 2D) = "white" {}
        _Gloss ("Gloss", Range(10, 200)) = 20
        _Speed ("Speed", Range(-5, 15)) = 1
        _RimPower("Rim Power", Range(0.00001, 20.0)) = 4
        _RimColor("Rim Color", Color) = (1, 1, 1, 1)
        _Size("Size", Range(0, 1)) = 0.5
        _OutLineWidth("width", float) = 1.05
        [IntRange]_addtionalEffecct("additional effect", Range(0, 3)) = 0
    }
    SubShader
    {
        
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" "IgnoreProjector" = "True" "ForceNoShadowCasting" = "True"}
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha

        
        Pass{
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float _OutLineWidth;
            fixed4 _Color;
            fixed _RimPower;


            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 position : SV_POSITION;
                float3 world_normal_dir : COLOR0;
                fixed3 world_view_dir : COLOR2;
            };

            v2f vert(a2v v){
                v2f f;
                v.vertex *= _OutLineWidth;
                f.position = UnityObjectToClipPos(v.vertex);
                f.world_normal_dir = UnityObjectToWorldNormal(v.normal);
                f.world_view_dir = WorldSpaceViewDir(v.vertex);
                return f;
            }


            fixed4 frag(v2f f) : SV_Target{
                fixed3 viewDir = normalize(f.world_view_dir);
                fixed3 normalDir = normalize(f.world_normal_dir);

                //实现边缘光效果
                //计算视角方向与法线方向的夹角
                fixed rim =  max(dot(normalDir, viewDir), 0);
                //计算边缘光颜色
                fixed3 rim_color = _Color.rgb * pow(rim, 1 / _RimPower);
                
                return fixed4(rim_color, 0);
            }


            ENDCG

        }
        

        Pass{
            Tags{"LightMode" = "ForwardBase"}


            ZTest Always

            CGPROGRAM
            #include "Lighting.cginc"
            #include "UnityCG.cginc"

            #pragma vertex vert
            #pragma fragment frag

            fixed3 _Color;
            float _Gloss;
            fixed _Speed;
            sampler2D _MainTex;
            fixed _RimPower;
            fixed3 _RimColor;
            fixed _addtionalEffecct;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };


            struct v2f{
                float4 position : SV_POSITION;
                float3 world_normal_dir : COLOR0;
                fixed3 world_light_dir : COLOR1;
                fixed3 world_view_dir : COLOR2;
                float4 object_position : TEXCOORD0;
                float4 world_postion : TEXCOORD1;
            };
            

            //顶点故障效果
            float3 VertexJitterOffset(float3 vertex){
                half _JitterSpeedRedio = 2;    //抖动速度因子
                half _JitterRangeY = 1.2;  //允许抖动的Y值范围
                half _JitterOffset = 0.7;  //抖动时的顶点偏移
                
                half optTime = sin(_Time.w * _JitterSpeedRedio);
                half timeTojitter = step(0.99, optTime);
                
                //每次需要抖动的顶点Y是不一样的
                half jitterPosY = vertex.y + _SinTime.y;

                //抖动区域 0<y<_JitterRangeY
                half jitterPosYRange = step(0, jitterPosY) * step(jitterPosY, _JitterRangeY);
                half offset = jitterPosYRange * _JitterOffset * timeTojitter * _SinTime.y;
                return half3(offset, 0, offset);
            }



            //颜色故障效果
            fixed AlphaJitterOffset(fixed alpha){
                half _JitterSpeedRedio = 1;
                half _JitterRangeY = 10;
                half _JitterOffset = 1;

                half optTime = sin(_Time.w * _JitterSpeedRedio);
                half timeTojitter = step(0.99, optTime);

                half jitterPosY = _SinTime.y;
                
                half jitterPosYRange = step(0, jitterPosY) * step(jitterPosY, _JitterRangeY);
                half offset = jitterPosYRange * _JitterOffset * timeTojitter * _SinTime.y;

                return offset;
            }



            //菲涅尔反射
            float3 FresnelReflection(fixed3 view, fixed3 normal, fixed alpha, fixed3 color){
                fixed _FresnelScale = 0.9;
                fixed _FresnelPower = 0.95;
                
                float3 fresnel = pow(1 - dot(view, normal), _FresnelPower) * _FresnelScale;
                //fresnel.a = clamp(fresnel.a, 0.0, 1.0);

                fixed3 fresnel_color = color * fresnel.rgb; 

                return fresnel_color;

            }


            //实现扫描线流动动画(未完成)
            fixed4 ScanLineflow(fixed3 diffuse, v2f f){
                fixed scroll = _Speed * _Time;
                fixed4 col = (diffuse, 1);
                fixed scroll_project = abs(f.object_position.y + scroll - round(f.object_position.y + scroll));
                fixed4 cybercol = tex2D(_MainTex, scroll_project);
                fixed alpha = 0.6;
                if(cybercol.r + cybercol.g + cybercol.b < 1){
                    alpha = 0;
                    col = max(cybercol, col);
                }
                return fixed4(col.rgb, alpha);
            }



            //实现模型旋转效果
            float4 CalculateRotation(float4 pos)
			{
                fixed _RotationSpeed = 5;
			    float rotation=_RotationSpeed * _Time.y;
			    float s,c;
				sincos(radians(rotation), s, c);
			    float2x2 rotMatrix=float2x2(c,-s,s,c);
			    pos.xy=mul(pos.xy,rotMatrix);
			    
			    return pos;
			}



            v2f vert(a2v v){
                v2f f;
                if(_addtionalEffecct == 1){
                    v.vertex.xyz += VertexJitterOffset(v.vertex.xyz);
                };

                if(_addtionalEffecct == 2){
                    v.vertex.xz = CalculateRotation(float4(v.vertex.x, v.vertex.z, 1.0, 1.0));
                };

                if(_addtionalEffecct == 3){
                    v.vertex.xz = CalculateRotation(float4(v.vertex.x, v.vertex.z, 1.0, 1.0));
                    v.vertex.xyz += VertexJitterOffset(v.vertex.xyz);
                };
                
                f.position = UnityObjectToClipPos(v.vertex);
                f.world_normal_dir = UnityObjectToWorldNormal(v.normal);
                f.world_light_dir = WorldSpaceLightDir(v.vertex);
                f.world_view_dir = WorldSpaceViewDir(v.vertex);
                f.object_position = v.vertex;
                f.world_postion = mul(unity_ObjectToWorld, v.vertex);
                return f;
            }


            float4 frag(v2f f) : SV_Target{
                fixed3 normalDir = normalize(f.world_normal_dir);   //acquire normal direction, under the world space
                fixed3 lightDir = normalize(f.world_light_dir);   //acquire light direction, under the world space
                fixed3 viewDir = normalize(f.world_view_dir);     //acquire view direction, under the world sapce
                fixed3 halfDir = normalize(lightDir + viewDir);   //acquire the half of the light direction and view direction, under the world space


                //compute diffuse 直射光颜色 * （cos(直射光和法线的夹角) * 0.5 + 0.5）
                fixed3 diffuse = _LightColor0.rgb * (dot(lightDir, normalDir) * 0.5 + 0.5) * _Color.rgb;

                //compute specular 直射光颜色 * pow( max(cos(平行光和视野方向的平分线和法线的夹角), 0), 高光参数 )
                fixed3 specular = _LightColor0.rgb * pow(max(dot(halfDir, normalDir), 0), _Gloss);
                

                //实现扫描线流动动画
                /*
                fixed scroll = _Speed * _Time;
                fixed4 col = (diffuse, 1);
                fixed scroll_project = abs(f.object_position.y + scroll - round(f.object_position.y + scroll));
                fixed4 cybercol = tex2D(_MainTex, scroll_project);
                fixed alpha = 0.6;
                if(cybercol.r + cybercol.g + cybercol.b < 1){
                    alpha = 0;
                    col = max(cybercol, col);
                }
                */


                fixed4 col = ScanLineflow(diffuse, f);
                fixed alpha = col.a;

                //实现边缘光效果
                //计算视角方向与法线方向的夹角
                fixed rim =  max(dot(normalDir, viewDir), 0);
                //计算边缘光颜色
                fixed3 rim_color = _Color.rgb * pow(rim, 1 / _RimPower);



                fixed3 res_color = col.rgb * _Color.rgb + rim_color;
                fixed3 final_color = FresnelReflection(viewDir, normalDir, alpha, res_color);
                

                return fixed4(final_color, alpha);
            }


            ENDCG

            
        }


       



        



    }
    FallBack "Diffuse"
}
