# CustomURPShaders
The shader file can be found in Assets/Shaders/CustomLit.shader


## 1. Custom Lit derived from URP Default Unlit shader
### a. Apply BRDF (BlinnPhong)

Diffuse, Amibent, Specular, BlinnPhong

![BlinnPhong](/Images/BlinnPhong.png)


### b. MainLight + Env Lighting + Static GI + AdditionalLights

(No shadow, Metalic: 0.5, Smoothness: 0.5)

![URPPBR](/Images/URPPBR.png)


### Custom Lit vs URP Lit
![Comparison](/Images/Comparison.png)


## 2. Custom Render Pass
### Radial Blur Renderer Feature
Custom Renderer Feature based on FullScreenPassRendererFeature

![RadialBlur](/Images/RadialBlur.png)
