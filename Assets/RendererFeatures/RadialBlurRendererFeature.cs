using System.Collections;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RadialBlurRendererFeature : ScriptableRendererFeature
{
    public Material passMaterial;
    private RadialBlurPass m_RadialBlurPass;
    public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
    public ScriptableRenderPassInput requirements = ScriptableRenderPassInput.Color;

    public override void Create()
    {
        m_RadialBlurPass = new RadialBlurPass();
        m_RadialBlurPass.renderPassEvent = injectionPoint;
        m_RadialBlurPass.ConfigureInput(requirements);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (passMaterial == null)
        {
            Debug.LogWarningFormat("Missing Radiar Blur effect Material");
            return;
        }
        m_RadialBlurPass.Setup(passMaterial, "RadialBlurPassRendererFeature", renderingData);
        renderer.EnqueuePass(m_RadialBlurPass);
    }

    protected override void Dispose(bool disposing)
    {
        m_RadialBlurPass.Dispose();
    }


    class RadialBlurPass : ScriptableRenderPass
    {
        private Material m_PassMaterial;
        private PassData m_PassData;
        private ProfilingSampler m_ProfilingSampler;
        private RTHandle m_CopiedColor;
        private static readonly int m_BlitTextureShaderID = Shader.PropertyToID("_BlitTexture");


        public void Setup(Material mat, string featureName, in RenderingData renderingData)
        {
            m_PassMaterial = mat;
            m_ProfilingSampler = new ProfilingSampler(featureName);
            var colorCopyDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            colorCopyDescriptor.depthBufferBits = (int) DepthBits.None;
            RenderingUtils.ReAllocateIfNeeded(ref m_CopiedColor, colorCopyDescriptor, name: "_RadialBlurPassColorCopy");
            m_PassData ??= new PassData();
        }

        public void Dispose()
        {
            m_CopiedColor?.Release();
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            m_PassData.effectMaterial = m_PassMaterial;
            m_PassData.profilingSampler = m_ProfilingSampler;
            m_PassData.copiedColor = m_CopiedColor;

            ExecutePass(m_PassData, ref renderingData, ref context);
        }

        private static void ExecutePass(PassData passData, ref RenderingData renderingData, ref ScriptableRenderContext context)
        {
            if (passData.effectMaterial == null)
                return;

            if (renderingData.cameraData.isPreviewCamera)
                return;

            var cmd = CommandBufferPool.Get();
            var cameraData = renderingData.cameraData;

            using (new ProfilingScope(cmd, passData.profilingSampler))
            {
                var source = cameraData.renderer.cameraColorTargetHandle;
                Blitter.BlitCameraTexture(cmd, source, passData.copiedColor);
                passData.effectMaterial.SetTexture(m_BlitTextureShaderID, passData.copiedColor);

                CoreUtils.SetRenderTarget(cmd, cameraData.renderer.cameraColorTargetHandle);
                CoreUtils.DrawFullScreen(cmd, passData.effectMaterial);
            }
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        }


        private class PassData
        {
            internal Material effectMaterial;
            public ProfilingSampler profilingSampler;
            public RTHandle copiedColor;
        }
    }
}
