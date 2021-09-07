// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "MyShader/HoloShaderWithTexture"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)    //模型颜色
        _ScanTex ("scan line Texture", 2D) = "white" {}
        _MainTex ("Main Texture", 2D) = "white"{}
        _Gloss ("Gloss", Range(10, 200)) = 20
        _Speed ("Speed", Range(-5, 15)) = 1
        _RimPower("Rim Power", Range(0.00001, 20.0)) = 4
        //_RimColor("Rim Color", Color) = (1, 1, 1, 1)
        _Size("Size", Range(0, 1)) = 0.5
        _OutLineWidth("width", float) = 1.05
        [IntRange]_addtionalEffecct("additional effect", Range(0, 3)) = 0
        _HolographicColor("holographic color", color) = (1, 1, 1, 1)   //全息投影颜色

    }
    SubShader
    {
        
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" "IgnoreProjector" = "True" "ForceNoShadowCasting" = "True"}
        LOD 100
       

        //该Pass块的功能是法线外扩
        /*
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
        */


        //另使用一个Pass块进行深度写入但不渲染任何颜色到深度缓存
        
        Pass{
            ZWrite On  //打开深度写入
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
            ZWrite off  //关闭深度写入

            CGPROGRAM
            #include "Lighting.cginc"
            #include "UnityCG.cginc"

            #pragma vertex vert
            #pragma fragment frag

            fixed3 _Color;
            float _Gloss;
            fixed _Speed;
            sampler2D _ScanTex;
            sampler2D _MainTex;
            fixed _RimPower;
            fixed _addtionalEffecct;
            fixed4 _HolographicColor;    //声明全息投影颜色
            float4 _MainTex_ST;   //获取纹理的Tiling 和 Offset


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
                float4 object_position : TEXCOORD0;
                float4 world_postion : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 uv2 : TEXCOORD3;
            };
            

            //顶点故障效果
            float3 VertexJitterOffset(float3 vertex){
                half _JitterSpeedRedio = 2;    //抖动速度因子
                half _JitterRangeY = 500;  //允许抖动的Y值范围
                half _JitterOffset = 15;  //抖动时的顶点偏移
                
                half optTime = sin(_Time.y * _JitterSpeedRedio);
                half timeTojitter = step(0.99, optTime);
                
                //每次需要抖动的顶点Y是不一样的
                half jitterPosY = vertex.y + _SinTime.y;
                //half jitterPosY = sin(vertex.y + _Time.y);

                //抖动区域 0<y<_JitterRangeY
                half jitterPosYRange = step(0, jitterPosY) * step(jitterPosY, _JitterRangeY);
                half offset = jitterPosYRange * _JitterOffset * timeTojitter * _SinTime.y;
                return float3(offset, 0, 0);
                //return mul((float3x3)UNITY_MATRIX_T_MV, float3(offset, 0, 0));
            }



            //颜色故障效果(未完成)
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
                fixed _FresnelScale = 3;
                fixed _FresnelPower = 2.2;
                
                float3 fresnel = pow(1 - dot(view, normal), _FresnelPower) * _FresnelScale;
                //fresnel.a = clamp(fresnel.a, 0.0, 1.0);

                fixed3 fresnel_color = color * fresnel.rgb; 

                return fresnel_color;

            }


            //实现扫描线流动动画
            fixed4 ScanLineflow(fixed3 diffuse, v2f f){
                fixed scroll = _Speed * _Time;
                fixed4 col = (diffuse, 1);
                fixed scroll_project = abs(f.uv2.y + scroll - round(f.uv2.y + scroll));
                fixed4 cybercol = tex2D(_ScanTex, scroll_project);
                fixed alpha = 1;
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
                /*
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
                */
                v.vertex.xyz += VertexJitterOffset(v.vertex.xyz);


                f.position = UnityObjectToClipPos(v.vertex);
                f.world_normal_dir = UnityObjectToWorldNormal(v.normal);
                f.world_light_dir = WorldSpaceLightDir(v.vertex);
                f.world_view_dir = WorldSpaceViewDir(v.vertex);
                f.object_position = v.vertex;
                f.world_postion = mul(unity_ObjectToWorld, v.vertex);
                f.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                f.uv2 = v.texcoord;

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


                fixed3 tex_color = tex2D(_MainTex, f.uv);
                
                



                fixed4 col = ScanLineflow(_HolographicColor.rgb, f);

                //控制遮罩效果
                fixed alpha = lerp(1, tex_color.r, col.a);

                //实现边缘光效果
                //计算视角方向与法线方向的夹角
                fixed rim =  max(dot(normalDir, viewDir), 0);
                //计算边缘光颜色
                fixed3 rim_color = _HolographicColor.rgb * pow(rim, 1 / _RimPower);



                fixed3 res_color = col.rgb * _Color.rgb + rim_color;
                //fixed3 final_color = FresnelReflection(viewDir, normalDir, alpha, res_color);
                fixed3 final_color = FresnelReflection(viewDir, normalDir, alpha, _HolographicColor.rgb);
                

                return fixed4(final_color, alpha);

                //return fixed4(_HolographicColor.rgb, 0.5);
            }


            ENDCG

            
        }


       



        



    }
    FallBack "Diffuse"
}
