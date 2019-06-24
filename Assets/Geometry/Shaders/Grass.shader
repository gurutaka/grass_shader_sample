Shader "Grass"
{
    Properties
    {
        //頂点の色
        _TopColor("Top Color", Color) = (1.0, 1.0, 1.0, 1.0)
        //根本の色
        _BottomColor("Bottom Color", Color) = (0.0, 0.0, 0.0, 1.0)
        //VFX用の高さのテクスチャ
        _HeightMap ("HeightMap", 2D) = "white" {}
        //VFX用の幅のテクスチャ
        _WidthMap ("WidthMap", 2D) = "white" {}
        //VFX用の風の向きのテクスチャ
        _WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
        //高さの基準値
        _Height("Height", Range(0., 20)) = 10
        //幅の基準値
        _Width("Width", Range(0., 5)) = 1 //基準値
        //高さの比率@bottom, middle, high
        _HeightRate ("HeightRate", Vector) = (0.3,0.4,0.5,0)//
        //幅の比率@bottom, middle, high
        _WidthRate ("WidthRate", Vector) = (0.5,0.4,0.25,0)
        //風の揺れ率@bottom, middle, high
        _WindPowerRate ("WidthPowerRate", Vector) = (0.3, 1.0, 2.0, 0)
        //風の強さ
        _WindPower("WindPower", Range(0., 10.0)) = 2.0
        //風の吹く周期
        _WindFrequency("WindFrequency'", Range(0., 0.1)) = 0.05
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #include "UnityCG.cginc"

            struct v2g
            {
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 height : TEXCOORD1;
                float2 width : TEXCOORD2;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                fixed4 col : COLOR;
            };

            // https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
            float rand(float3 co)
            {
                return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
            }

            sampler2D _HeightMap, _WidthMap,_WindDistortionMap;
            float4 _WindDistortionMap_ST;
            float4 _TopColor, _BottomColor, _HeightRate, _WidthRate, _WindPowerRate;
            float _Height, _Width,_WindPower,_WindFrequency;

            v2g vert (appdata_base v)
            {
                v2g o;
                float4 uv = float4(v.texcoord.xy, 0.0f, 0.0f);
                o.pos = v.vertex;
                o.uv = v.texcoord.xy;
                o.normal = v.normal;

                //VFX
                o.height = tex2Dlod(_HeightMap,uv);
                o.width = tex2Dlod(_WidthMap,uv);
                return o;
            }


            [maxvertexcount(7)]
            void geom(triangle v2g IN[3], inout TriangleStream<g2f> tristream)
            {

                float4 pos0 = IN[0].pos;
                float4 pos1 = IN[1].pos;
                float4 pos2 = IN[2].pos;

                float2 uv0 = IN[0].uv;
                float2 uv1 = IN[1].uv;
                float2 uv2 = IN[2].uv;

                float3 nor0 = IN[0].normal;
                float3 nor1 = IN[1].normal;
                float3 nor2 = IN[2].normal;

                //入力された三角メッシュの頂点座標の平均値
                float4 centerPos = (pos0 + pos1 + pos2 ) / 3;
                //法線ベクトルの平均値
                float4 centerNor = float4( (nor0 + nor1 + nor2).xyz / 3, 1.0f);
                //uv座標
                float2 centerUv = (uv2 + uv1 + uv0) / 3.0f;

                // VFX用の高さ、幅の調整
                float height = (IN[0].height.r + IN[1].height.r + IN[2].height.r) / 3.0f;
                float width = (IN[0].width.r + IN[1].width.r + IN[2].width.r) / 3.0f;

                //草の傾き
                float4 dir = float4(normalize(pos2 * rand(pos2)- pos0 * rand(pos1)).xyz * width, 1.0f);

                //風向きマッピング用のテクスチャ

                //追記;計算が複雑なのでuv平均値に変更
                //テクスチャの名前 + _STをつけたfloat4のuniformを定義することでそのTextureのtilingやoffset情報を取ってくることができます
                //https://qiita.com/ShirakawaMaru/items/ec8c049c72ff854e36ea
                //Tilingを1→0.01に変更する必要あり
                //tilitn, offsetを加味したuv座標＋uvスクロール
                //実際は入力メッシュのUV座標をバラけさせるため
                //xz平面がuv座標となるので注意
                // float2 uv = pos0.xz * _WindDistortionMap_ST.xy  + _WindDistortionMap_ST.zw  + _WindFrequency * _Time.y;

                float2 uv = centerUv + _WindFrequency * _Time.y;
                //風向きはRG情報＠パーリンノイズ
		        float2 windDir_xy = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindPower;
                float4 wind = float4(windDir_xy, 0,0);

                g2f o[7];

                //bottom
                o[0].pos = centerPos - dir * _Width * _WidthRate.x;
                o[0].col = _BottomColor;

                o[1].pos = centerPos + dir * _Width * _WidthRate.x;
                o[1].col = _BottomColor;

                //bottom2middle
                o[2].pos = centerPos - dir * _Width * _WidthRate.y + centerNor * height * _Height * _HeightRate.x;
                o[2].col = lerp(_BottomColor, _TopColor, 0.33333f);

                o[3].pos = centerPos + dir * _Width * _WidthRate.y + centerNor * height * _Height * _HeightRate.x;
                o[3].col = lerp(_BottomColor, _TopColor, 0.33333f);

                //middley2high
                o[4].pos = o[3].pos - dir * _Width * _WidthRate.z + centerNor * height * _Height * _HeightRate.y;
                o[4].col = lerp(_BottomColor, _TopColor, 0.6666f);

                o[5].pos = o[3].pos + dir * _Width * _WidthRate.z + centerNor * height * _Height * _HeightRate.y;
                o[5].col = lerp(_BottomColor, _TopColor, 0.6666f);


                //top
                o[6].pos = o[5].pos + centerNor * height * _Height * _HeightRate.z;
                o[6].col = _TopColor;

                // wind
                o[2].pos += wind * _WindPowerRate.x;
                o[3].pos += wind * _WindPowerRate.x;
                o[4].pos += wind * _WindPowerRate.y;
                o[5].pos += wind * _WindPowerRate.y;
                o[6].pos += wind * _WindPowerRate.z;

                [unroll]//解説：https://wlog.flatlib.jp/item/1012 , http://blog.livedoor.jp/akinow/archives/52404331.html
                for (int i = 0; i < 7; i++) {
                    o[i].pos = UnityObjectToClipPos(o[i].pos);
                    tristream.Append(o[i]);
                }

            }

            fixed4 frag (g2f i) : SV_Target
            {
                fixed4 col = i.col;
                return col;
            }
            ENDCG
        }
    }
}